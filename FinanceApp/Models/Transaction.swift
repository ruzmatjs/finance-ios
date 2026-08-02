import Foundation
import SwiftData
import SwiftUI

/// Asosiy tranzaksiya modeli — daromad, xarajat yoki oʻtkazma.
@Model
final class Transaction {
    var id: UUID = UUID()
    var typeRaw: String = TransactionType.expense.rawValue
    /// Doim musbat saqlanadi; ishora `type` orqali aniqlanadi.
    var amount: Double = 0
    var currencyCode: String = "UZS"
    var date: Date = Date()
    var note: String = ""
    var merchant: String = ""

    // Qoʻshimcha metadata
    var isFavorite: Bool = false
    var isPinned: Bool = false
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    /// Chek rasmi (SwiftData'da tashqi faylga saqlanadi — katta blob'lar uchun optimal).
    @Attribute(.externalStorage) var receiptImage: Data?
    /// Yengil bayroq — roʻyxatda blob'ni yuklamasdan chek borligini tekshirish uchun (performance).
    var hasReceipt: Bool = false
    var createdAt: Date = Date()

    // Relationshiplar
    var category: Category?
    var account: Account?
    /// Transfer uchun qabul qiluvchi hisob.
    @Relationship var toAccount: Account?
    var tags: [Tag]? = []
    /// Agar takrorlanuvchi qoidadan yaratilgan boʻlsa.
    var recurringRule: RecurringTransaction?

    init(
        type: TransactionType,
        amount: Double,
        date: Date = Date(),
        note: String = "",
        merchant: String = "",
        category: Category? = nil,
        account: Account? = nil,
        toAccount: Account? = nil,
        currencyCode: String = "UZS"
    ) {
        self.typeRaw = type.rawValue
        self.amount = abs(amount)
        self.date = date
        self.note = note
        self.merchant = merchant
        self.category = category
        self.account = account
        self.toAccount = toAccount
        self.currencyCode = currencyCode
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    /// Balansga taʼsir qiluvchi ishorali qiymat (+/-).
    var signedAmount: Double { amount * type.sign }

    var hasLocation: Bool { latitude != nil && longitude != nil }
}
