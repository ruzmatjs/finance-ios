import Foundation
import SwiftData

/// Byudjet ostonasi (masalan 80%) buzilganda ogohlantirish yuboradi.
/// Xarajat qoʻshilgandan soʻng chaqiriladi.
///
/// Har bir byudjet uchun joriy davrda faqat **bir marta** ogohlantiradi —
/// takroriy bildirishnoma bermaslik uchun holat App Group UserDefaults'da saqlanadi.
@MainActor
enum BudgetAlertService {

    static func evaluate(context: ModelContext, currency: String) {
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let expenseRaw = TransactionType.expense.rawValue

        for budget in budgets where budget.limitAmount > 0 {
            let interval = budget.currentInterval
            let start = interval.start, end = interval.end
            let names = Set((budget.categories ?? []).map { $0.name })

            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.typeRaw == expenseRaw && $0.date >= start && $0.date < end }
            )
            let txs = (try? context.fetch(descriptor)) ?? []
            let spent = txs
                .filter { names.isEmpty || names.contains($0.category?.name ?? "") }
                .reduce(0) { $0 + $1.amount }

            let ratio = spent / budget.limitAmount
            guard ratio >= budget.notifyThreshold else { continue }

            // Davr uchun bir martalik kalit.
            let key = "budget.warned.\(budget.id.uuidString).\(Int(start.timeIntervalSince1970))"
            guard !AppGroup.defaults.bool(forKey: key) else { continue }

            NotificationManager.shared.sendBudgetWarning(
                name: budget.name, spent: spent, limit: budget.limitAmount, currency: currency
            )
            AppGroup.defaults.set(true, forKey: key)
        }
    }
}
