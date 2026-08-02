import SwiftUI

/// Pul summasini izchil formatlab, ishoraga qarab ranglaydigan matn.
struct AmountText: View {
    let amount: Double
    var currencyCode: String = "UZS"
    var type: TransactionType = .expense
    var font: Font = Theme.Font.amount
    var showsSign: Bool = true

    private var color: Color {
        switch type {
        case .income: return Theme.Colors.income
        case .expense: return Theme.Colors.expense
        case .transfer: return Theme.Colors.transfer
        }
    }

    private var text: String {
        let prefix = showsSign ? (type == .income ? "+" : (type == .expense ? "−" : "")) : ""
        return prefix + CurrencyFormatter.string(amount, code: currencyCode)
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
