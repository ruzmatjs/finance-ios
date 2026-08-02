import Foundation
import SwiftData

/// Takrorlanuvchi qoidalarni tekshirib, muddati kelgan tranzaksiyalarni yaratadi.
/// Ilova har ochilganda `run()` chaqiriladi (offline, backend'siz avtomatlashtirish).
@MainActor
struct RecurringEngine {
    let context: ModelContext

    func run(reference: Date = Date()) {
        let rules = (try? context.fetch(FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isActive }
        ))) ?? []

        for rule in rules {
            var due = rule.nextDueDate
            // Muddati kelgan barcha davrlarni "quvib yetish".
            while due <= reference {
                if let end = rule.endDate, due > end { break }

                let tx = Transaction(
                    type: rule.type,
                    amount: rule.amount,
                    date: due,
                    note: rule.note,
                    merchant: rule.title,
                    category: rule.category,
                    account: rule.account
                )
                tx.recurringRule = rule
                context.insert(tx)

                rule.lastRunDate = due
                due = rule.advance(from: due)
                rule.nextDueDate = due
            }
        }
        try? context.save()
    }
}
