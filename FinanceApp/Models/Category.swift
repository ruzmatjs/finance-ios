import Foundation
import SwiftData
import SwiftUI

/// Tranzaksiya kategoriyasi (Salary, Food, Taxi, ...).
///
/// CloudKit-ready qoidalari:
/// - Har bir property'da default qiymat bor (CloudKit optional talab qiladi).
/// - Relationship inverse bilan belgilangan.
@Model
final class Category {
    /// Barqaror ID — export/sync va widget uchun.
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = CategoryKind.expense.rawValue
    var symbol: String = "tag.fill"           // SF Symbol nomi
    var colorHex: String = "#8E8E93"
    var isFavorite: Bool = false
    var isDefault: Bool = false               // default kategoriyalar oʻchirilmaydi
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    /// Bitta kategoriyaga tegishli tranzaksiyalar (o'chirilganda nil bo'ladi).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    // CloudKit inverse talabi — takrorlanuvchi qoidalar va byudjetlar.
    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringRules: [RecurringTransaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Budget.categories)
    var budgets: [Budget]? = []

    init(
        name: String,
        kind: CategoryKind,
        symbol: String,
        colorHex: String,
        isFavorite: Bool = false,
        isDefault: Bool = false,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.symbol = symbol
        self.colorHex = colorHex
        self.isFavorite = isFavorite
        self.isDefault = isDefault
        self.sortIndex = sortIndex
    }

    // Computed helpers (SwiftData'da enum'ni to'g'ridan-to'g'ri saqlamaymiz)
    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }
}
