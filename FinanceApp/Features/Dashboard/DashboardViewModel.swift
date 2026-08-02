import Foundation
import SwiftData
import Observation

/// Dashboard biznes-logikasi — barcha hisob-kitoblar shu yerda (View "yupqa" qoladi).
@MainActor
@Observable
final class DashboardViewModel {
    private let repository: FinanceRepositoryProtocol
    let currencyCode: String

    // Chiqadigan qiymatlar
    var totalBalance: Double = 0
    var todayBalance: Double = 0
    var monthlyIncome: Double = 0
    var monthlyExpense: Double = 0
    var savings: Double = 0
    var recentTransactions: [Transaction] = []
    var upcomingBills: [RecurringTransaction] = []
    var budgets: [BudgetProgress] = []
    var weeklySpending: [DailyPoint] = []

    struct DailyPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    struct BudgetProgress: Identifiable {
        let id: UUID
        let budget: Budget
        let spent: Double
        var progress: Double { budget.limitAmount > 0 ? spent / budget.limitAmount : 0 }
        var isOver: Bool { spent > budget.limitAmount }
    }

    init(repository: FinanceRepositoryProtocol, currencyCode: String) {
        self.repository = repository
        self.currencyCode = currencyCode
    }

    func load() {
        let all = repository.fetchTransactions(descriptor: FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
        let accounts = repository.fetchAccounts()
        let cal = Calendar.current
        let now = Date()

        // Umumiy balans — barcha hisoblar joriy balansi.
        totalBalance = accounts.reduce(0) { $0 + $1.currentBalance }

        // Bugungi oʻzgarish
        todayBalance = all
            .filter { cal.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.signedAmount }

        // Oylik daromad/xarajat
        let monthInterval = cal.currentInterval(for: .monthly, reference: now)
        let monthTx = all.filter { monthInterval.contains($0.date) }
        monthlyIncome = monthTx.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        monthlyExpense = monthTx.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        savings = monthlyIncome - monthlyExpense

        // Soʻnggi tranzaksiyalar
        recentTransactions = Array(all.prefix(6))

        // Haftalik sarf trendi (soʻnggi 7 kun)
        weeklySpending = (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let sum = all
                .filter { $0.type == .expense && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return DailyPoint(date: day, amount: sum)
        }

        // Byudjet progressi
        budgets = repository.fetchBudgets().map { budget in
            let interval = budget.currentInterval
            let catNames = Set((budget.categories ?? []).map { $0.name })
            let spent = all
                .filter { $0.type == .expense
                    && interval.contains($0.date)
                    && catNames.contains($0.category?.name ?? "") }
                .reduce(0) { $0 + $1.amount }
            return BudgetProgress(id: budget.id, budget: budget, spent: spent)
        }

        // Yaqinlashayotgan toʻlovlar (7 kun ichida)
        let weekAhead = cal.date(byAdding: .day, value: 7, to: now) ?? now
        upcomingBills = repository.fetchRecurring()
            .filter { $0.isActive && $0.nextDueDate <= weekAhead }
    }
}
