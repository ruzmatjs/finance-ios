import SwiftUI

/// Kichik statistika kartochkasi (Daromad, Xarajat, Jamgʻarma, ...).
struct StatCard: View {
    let title: String
    let amount: Double
    var currencyCode: String = "UZS"
    let icon: String
    let tint: Color
    var trend: Double? = nil   // foizdagi oʻzgarish, ixtiyoriy

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.15), in: Circle())
                Spacer()
                if let trend {
                    Label("\(abs(Int(trend)))%", systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(trend >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text(CurrencyFormatter.compact(amount, code: currencyCode))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.Colors.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
