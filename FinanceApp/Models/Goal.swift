import Foundation
import SwiftData
import SwiftUI

/// Jamgʻarma maqsadi (Yangi mashina, Sayohat, ...).
@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var targetAmount: Double = 0
    var currentAmount: Double = 0
    var symbol: String = "target"
    var colorHex: String = "#5856D6"
    var targetDate: Date?
    var createdAt: Date = Date()

    init(
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        symbol: String = "target",
        colorHex: String = "#5856D6",
        targetDate: Date? = nil
    ) {
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.symbol = symbol
        self.colorHex = colorHex
        self.targetDate = targetDate
    }

    var color: Color { Color(hex: colorHex) }

    /// 0...1 oraligʻidagi progress.
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1)
    }

    var isCompleted: Bool { currentAmount >= targetAmount && targetAmount > 0 }
    var remaining: Double { max(targetAmount - currentAmount, 0) }
}
