import Foundation
import SwiftData
import SwiftUI

/// Takrorlanuvchi tranzaksiya qoidasi (Oylik maosh, ijara, Netflix, ...).
/// Ilova ochilganda `RecurringEngine` shu qoidalarni tekshirib,
/// muddati kelgan tranzaksiyalarni avtomatik yaratadi.
@Model
final class RecurringTransaction {
    var id: UUID = UUID()
    var title: String = ""
    var typeRaw: String = TransactionType.expense.rawValue
    var amount: Double = 0
    var periodRaw: String = PeriodType.monthly.rawValue
    /// Har necha davrda bir marta (masalan har 2 haftada => interval=2, period=.weekly).
    var interval: Int = 1
    var startDate: Date = Date()
    var endDate: Date?
    /// Oxirgi marta tranzaksiya yaratilgan sana — keyingisini hisoblash uchun.
    var lastRunDate: Date?
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var note: String = ""
    var createdAt: Date = Date()

    var category: Category?
    var account: Account?

    // Bu qoidadan yaratilgan tranzaksiyalar (CloudKit inverse talabi).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringRule)
    var generatedTransactions: [Transaction]? = []

    init(
        title: String,
        type: TransactionType,
        amount: Double,
        period: PeriodType = .monthly,
        interval: Int = 1,
        startDate: Date = Date(),
        category: Category? = nil,
        account: Account? = nil,
        note: String = ""
    ) {
        self.title = title
        self.typeRaw = type.rawValue
        self.amount = abs(amount)
        self.periodRaw = period.rawValue
        self.interval = interval
        self.startDate = startDate
        self.nextDueDate = startDate
        self.category = category
        self.account = account
        self.note = note
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var period: PeriodType {
        get { PeriodType(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    /// Berilgan sanadan keyingi navbatdagi muddatni hisoblaydi.
    func advance(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: period.calendarComponent, value: interval, to: date) ?? date
    }
}
