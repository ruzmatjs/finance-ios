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
    var weeklyPoints: [WeeklyTrendPoint] = []
    var chartEntries: [ChartBarEntry] = []

    struct WeeklyTrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let income: Double
        let expense: Double
        let scaledIncome: Double
        let scaledExpense: Double
    }

    struct ChartBarEntry: Identifiable {
        let id = UUID()
        let date: Date
        let category: String
        let rawAmount: Double
        let scaledAmount: Double
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

        // Haftalik daromad va xarajat trendi (soʻnggi 7 kun)
        let rawPoints: [(date: Date, inc: Double, exp: Double)] = (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let inc = all
                .filter { $0.type == .income && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            let exp = all
                .filter { $0.type == .expense && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return (day, inc, exp)
        }

        let maxVal = rawPoints.map { max($0.inc, $0.exp) }.max() ?? 1.0
        let maxAmount = max(maxVal, 1.0)

        weeklyPoints = rawPoints.map { p in
            func scale(_ val: Double) -> Double {
                guard val > 0 else { return 0 }
                let ratio = val / maxAmount
                let scaledRatio = max(pow(ratio, 0.55), 0.10)
                return scaledRatio * maxAmount
            }
            return WeeklyTrendPoint(
                date: p.date,
                income: p.inc,
                expense: p.exp,
                scaledIncome: scale(p.inc),
                scaledExpense: scale(p.exp)
            )
        }

        chartEntries = weeklyPoints.flatMap { p in
            [
                ChartBarEntry(date: p.date, category: "Daromad", rawAmount: p.income, scaledAmount: p.scaledIncome),
                ChartBarEntry(date: p.date, category: "Xarajat", rawAmount: p.expense, scaledAmount: p.scaledExpense)
            ]
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
