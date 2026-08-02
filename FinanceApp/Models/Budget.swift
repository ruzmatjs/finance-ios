import Foundation
import SwiftData
import SwiftUI

/// Kategoriya boʻyicha byudjet (oylik/haftalik/yillik).
@Model
final class Budget {
    var id: UUID = UUID()
    var name: String = ""
    var limitAmount: Double = 0
    var periodRaw: String = PeriodType.monthly.rawValue
    var colorHex: String = "#FF9500"
    var startDate: Date = Date()
    var notifyThreshold: Double = 0.8   // 80% da ogohlantirish
    var createdAt: Date = Date()

    /// Byudjet biriktirilgan kategoriyalar (bir nechta boʻlishi mumkin).
    @Relationship var categories: [Category]? = []

    init(
        name: String,
        limitAmount: Double,
        period: PeriodType = .monthly,
        colorHex: String = "#FF9500",
        startDate: Date = Date(),
        categories: [Category] = []
    ) {
        self.name = name
        self.limitAmount = limitAmount
        self.periodRaw = period.rawValue
        self.colorHex = colorHex
        self.startDate = startDate
        self.categories = categories
    }

    var period: PeriodType {
        get { PeriodType(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    /// Joriy davr oraligʻi [start, end).
    var currentInterval: DateInterval {
        Calendar.current.currentInterval(for: period, reference: Date())
    }
}
