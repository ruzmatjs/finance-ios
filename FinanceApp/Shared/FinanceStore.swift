import Foundation
import SwiftData
import WidgetKit

/// Widget va App Intents uchun yengil, DI'siz maʼlumot qatlami.
///
/// Nega alohida? Widget/Intent ilovaning `AppContainer` (DI) yoki `mainContext`iga
/// kira olmaydi — ular boshqa jarayonda. Shu sabab bu yerda umumiy konteynerdan
/// mustaqil `ModelContext` ochib, kerakli hisob-kitoblarni bajaramiz.
enum FinanceStore {

    private static var container: ModelContainer { PersistenceController.shared }

    /// Har chaqiruvda yangi lokal kontekst — jarayonlararo eng yangi maʼlumotni oʻqiydi.
    private static func context() -> ModelContext { ModelContext(container) }

    static func currencyCode() -> String {
        AppGroup.defaults.string(forKey: "settings.currencyCode") ?? "UZS"
    }

    // MARK: - Oʻqish (Widgetlar uchun)

    /// Bugungi jami xarajat.
    static func todaySpending() -> Double {
        sumExpenses(since: Calendar.current.startOfDay(for: Date()))
    }

    /// Joriy oy jami xarajati.
    static func monthSpending() -> Double {
        sumExpenses(since: Date().startOfMonth)
    }

    private static func sumExpenses(since start: Date) -> Double {
        let ctx = context()
        let expenseRaw = TransactionType.expense.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.typeRaw == expenseRaw && $0.date >= start }
        )
        let txs = (try? ctx.fetch(descriptor)) ?? []
        return txs.reduce(0) { $0 + $1.amount }
    }

    struct BudgetSnapshot {
        let name: String
        let limit: Double
        let spent: Double
        var remaining: Double { max(limit - spent, 0) }
        var progress: Double { limit > 0 ? spent / limit : 0 }
        var isOver: Bool { spent > limit }
    }

    /// Birinchi byudjet uchun qolgan mablagʻ (widget'da koʻrsatiladi).
    static func primaryBudget() -> BudgetSnapshot? {
        let ctx = context()
        guard let budget = (try? ctx.fetch(FetchDescriptor<Budget>()))?.first else { return nil }
        let interval = budget.currentInterval
        let names = Set((budget.categories ?? []).map { $0.name })
        let expenseRaw = TransactionType.expense.rawValue
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.typeRaw == expenseRaw && $0.date >= start && $0.date < end }
        )
        let txs = (try? ctx.fetch(descriptor)) ?? []
        let spent = txs
            .filter { names.isEmpty || names.contains($0.category?.name ?? "") }
            .reduce(0) { $0 + $1.amount }
        return BudgetSnapshot(name: budget.name, limit: budget.limitAmount, spent: spent)
    }

    // MARK: - Yozish (App Intents uchun)

    /// Siri/Intent orqali tez xarajat qoʻshadi. Muvaffaqiyatda `true` qaytaradi.
    @discardableResult
    static func addExpense(amount: Double, categoryName: String?) -> Bool {
        guard amount > 0 else { return false }
        let ctx = context()

        let expenseKind = CategoryKind.expense.rawValue
        let categories = (try? ctx.fetch(FetchDescriptor<Category>(
            predicate: #Predicate { $0.kindRaw == expenseKind }
        ))) ?? []

        let target = categoryName?.lowercased()
        let category = categories.first { $0.name.lowercased() == target }
            ?? categories.first { $0.name == "Other" }
            ?? categories.first

        let account = (try? ctx.fetch(FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.sortIndex)]
        )))?.first

        let tx = Transaction(type: .expense, amount: amount,
                             category: category, account: account,
                             currencyCode: currencyCode())
        ctx.insert(tx)
        do {
            try ctx.save()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }
}
