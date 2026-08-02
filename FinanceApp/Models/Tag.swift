import Foundation
import SwiftData
import SwiftUI

/// Tranzaksiyaga biriktiriladigan erkin teg (#oila, #safar, ...).
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Transaction.tags)
    var transactions: [Transaction]? = []

    init(name: String, colorHex: String = "#007AFF") {
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color { Color(hex: colorHex) }
}
