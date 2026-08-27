import Foundation
import SwiftData

/// Qarz modeli (Berdilar / Oldilar).
@Model
final class Debt {
    var id: UUID = UUID()
    var person: String = ""
    var amount: Double = 0
    var paid: Double = 0
    var typeRaw: String = DebtType.lend.rawValue
    var statusRaw: String = DebtStatus.active.rawValue
    var date: Date = Date()
    var dueDate: Date?
    var note: String = ""
    var createdAt: Date = Date()

    var account: Account?
    var transaction: Transaction?

    init(
        person: String,
        amount: Double,
        paid: Double = 0,
        type: DebtType = .lend,
        status: DebtStatus = .active,
        date: Date = Date(),
        dueDate: Date? = nil,
        note: String = "",
        account: Account? = nil,
        transaction: Transaction? = nil
    ) {
        self.person = person
        self.amount = abs(amount)
        self.paid = abs(paid)
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.date = date
        self.dueDate = dueDate
        self.note = note
        self.account = account
        self.transaction = transaction
    }

    var type: DebtType {
        get { DebtType(rawValue: typeRaw) ?? .lend }
        set { typeRaw = newValue.rawValue }
    }

    var status: DebtStatus {
        get { DebtStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var remaining: Double { max(amount - paid, 0) }
    var isSettled: Bool { status == .settled || remaining <= 0 }
    var progress: Double { amount > 0 ? min(paid / amount, 1.0) : 0 }
}
