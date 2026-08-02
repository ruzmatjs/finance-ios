import Foundation
import SwiftData
import SwiftUI

/// Foydalanuvchi hisobi (Naqd, Karta, Jamgʻarma, ...).
@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.cash.rawValue
    /// Boshlangʻich balans. Joriy balans = openingBalance + tranzaksiyalar yigʻindisi.
    var openingBalance: Double = 0
    var currencyCode: String = "UZS"
    var symbol: String = "banknote.fill"
    var colorHex: String = "#34C759"
    var isArchived: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    // Bu hisobdan qilingan tranzaksiyalar (manba).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    // Bu hisobga kelgan oʻtkazmalar (qabul qiluvchi). CloudKit inverse talabi + transfer balansi.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction]? = []

    // Bu hisobga bogʻlangan takrorlanuvchi qoidalar.
    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.account)
    var recurringRules: [RecurringTransaction]? = []

    init(
        name: String,
        type: AccountType,
        openingBalance: Double = 0,
        currencyCode: String = "UZS",
        symbol: String? = nil,
        colorHex: String = "#34C759",
        sortIndex: Int = 0
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalance = openingBalance
        self.currencyCode = currencyCode
        self.symbol = symbol ?? type.systemImage
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    /// Joriy balans — bogʻliq tranzaksiyalar asosida hisoblanadi.
    /// `account` = manba (chiqim), `toAccount` = qabul (kirim).
    var currentBalance: Double {
        let outgoing = (transactions ?? []).reduce(0.0) { partial, tx in
            switch tx.type {
            case .income: return partial + tx.amount
            case .expense: return partial - tx.amount
            case .transfer: return partial - tx.amount // bu hisobdan chiqdi
            }
        }
        // Boshqa hisoblardan bu hisobga kelgan oʻtkazmalar (kirim).
        let incoming = (incomingTransfers ?? [])
            .filter { $0.type == .transfer }
            .reduce(0.0) { $0 + $1.amount }
        return openingBalance + outgoing + incoming
    }
}
