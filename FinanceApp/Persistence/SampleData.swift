import Foundation
import SwiftData

/// Preview va demo uchun realistik namuna maʼlumot generatori.
/// Ishlab chiqarishda ishlatilmaydi — faqat in-memory konteynerlarda.
enum SampleData {

    @MainActor
    static func populate(_ context: ModelContext) {
        PersistenceController.seedIfNeeded(context)

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        guard let cash = accounts.first, !categories.isEmpty else { return }
        let card = accounts.count > 1 ? accounts[1] : cash

        func cat(_ name: String) -> Category? { categories.first { $0.name == name } }

        let calendar = Calendar.current
        let now = Date()

        // Soʻnggi 45 kun uchun tasodifiy realistik tranzaksiyalar.
        let expenseSamples: [(String, ClosedRange<Double>, String)] = [
            ("Food", 25_000...90_000, "Korzinka"),
            ("Jarimalar", 50_000...200_000, "YHXH"),
            ("Taxi", 12_000...40_000, "Yandex Go"),
            ("Fuel", 80_000...200_000, "UNG"),
            ("Shopping", 50_000...400_000, "Mediapark"),
            ("Mobile", 25_000...55_000, "Ucell"),
            ("Restaurant", 90_000...350_000, "Afsona")
        ]

        for dayOffset in 0..<45 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let count = Int.random(in: 0...3)
            for _ in 0..<count {
                let sample = expenseSamples.randomElement()!
                let tx = Transaction(
                    type: .expense,
                    amount: Double.random(in: sample.1).rounded(),
                    date: day,
                    merchant: sample.2,
                    category: cat(sample.0),
                    account: Bool.random() ? cash : card
                )
                context.insert(tx)
            }
        }

        // Oylik maosh (daromad)
        for monthOffset in 0..<2 {
            if let day = calendar.date(byAdding: .month, value: -monthOffset, to: now) {
                let salary = Transaction(type: .income, amount: 15_000_000, date: day,
                                         merchant: "Ish joyi", category: cat("Salary"), account: card)
                context.insert(salary)
            }
        }

        // Byudjet
        if let food = cat("Food"), let jarima = cat("Jarimalar") {
            context.insert(Budget(name: "Oziq-ovqat va Jarima", limitAmount: 2_000_000,
                                  period: .monthly, colorHex: "#FF9500",
                                  categories: [food, jarima]))
        }

        // Maqsad
        context.insert(Goal(name: "Sayohat — Turkiya", targetAmount: 20_000_000,
                            currentAmount: 7_500_000, symbol: "airplane.departure",
                            colorHex: "#64D2FF",
                            targetDate: calendar.date(byAdding: .month, value: 6, to: now)))
        context.insert(Goal(name: "Yangi noutbuk", targetAmount: 18_000_000,
                            currentAmount: 12_000_000, symbol: "laptopcomputer",
                            colorHex: "#5856D6"))

        // Takrorlanuvchi
        if let jarima = cat("Jarimalar") {
            context.insert(RecurringTransaction(title: "Avto Jarima", type: .expense,
                                                amount: 250_000, period: .monthly,
                                                category: jarima, account: card))
        }

        try? context.save()
    }
}
