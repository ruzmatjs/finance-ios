import Foundation
import SwiftData

/// Repository Pattern — SwiftData bilan yagona muloqot nuqtasi.
///
/// Nega protocol? ViewModel'lar konkret bazaga emas, abstraksiyaga bogʻlanadi
/// (Dependency Inversion). Bu unit-test'da mock bilan almashtirish imkonini beradi.
@MainActor
protocol FinanceRepositoryProtocol {
    // Transactions
    func fetchTransactions(descriptor: FetchDescriptor<Transaction>) -> [Transaction]
    func add(_ transaction: Transaction)
    func delete(_ transaction: Transaction)
    func duplicate(_ transaction: Transaction) -> Transaction

    // Accounts / Categories
    func fetchAccounts() -> [Account]
    func fetchCategories(kind: CategoryKind?) -> [Category]

    // Budgets / Goals / Recurring
    func fetchBudgets() -> [Budget]
    func fetchGoals() -> [Goal]
    func fetchRecurring() -> [RecurringTransaction]

    func save()
}

/// SwiftData asosidagi konkret implementatsiya.
@MainActor
final class FinanceRepository: FinanceRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Transactions
    func fetchTransactions(descriptor: FetchDescriptor<Transaction>) -> [Transaction] {
        (try? context.fetch(descriptor)) ?? []
    }

    func add(_ transaction: Transaction) {
        context.insert(transaction)
        save()
    }

    func delete(_ transaction: Transaction) {
        context.delete(transaction)
        save()
    }

    func duplicate(_ transaction: Transaction) -> Transaction {
        let copy = Transaction(
            type: transaction.type,
            amount: transaction.amount,
            date: Date(),
            note: transaction.note,
            merchant: transaction.merchant,
            category: transaction.category,
            account: transaction.account,
            toAccount: transaction.toAccount,
            currencyCode: transaction.currencyCode
        )
        copy.tags = transaction.tags
        context.insert(copy)
        save()
        return copy
    }

    // MARK: Accounts / Categories
    func fetchAccounts() -> [Account] {
        let d = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(d)) ?? []
    }

    func fetchCategories(kind: CategoryKind? = nil) -> [Category] {
        var d = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortIndex)])
        if let kind {
            let raw = kind.rawValue
            d.predicate = #Predicate { $0.kindRaw == raw }
        }
        return (try? context.fetch(d)) ?? []
    }

    // MARK: Budgets / Goals / Recurring
    func fetchBudgets() -> [Budget] {
        (try? context.fetch(FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func fetchGoals() -> [Goal] {
        (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func fetchRecurring() -> [RecurringTransaction] {
        (try? context.fetch(FetchDescriptor<RecurringTransaction>(sortBy: [SortDescriptor(\.nextDueDate)]))) ?? []
    }

    func save() {
        try? context.save()
    }
}
