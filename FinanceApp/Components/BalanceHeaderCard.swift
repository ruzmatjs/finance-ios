import SwiftUI

/// Dashboard'ning yuqori qismidagi katta balans kartochkasi — glass/gradient premium koʻrinish.
struct BalanceHeaderCard: View {
    let totalBalance: Double
    let todayChange: Double
    let currencyCode: String
    var isHidden: Bool = false
    var onToggleHidden: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Umumiy balans")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if let onToggle = onToggleHidden {
                    Button {
                        onToggle()
                        Haptics.light()
                    } label: {
                        Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(isHidden ? "******" : CurrencyFormatter.string(totalBalance, code: currencyCode))
                .font(Theme.Font.largeAmount)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: 6) {
                if isHidden {
                    Text("***")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Image(systemName: todayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(CurrencyFormatter.signed(todayChange, code: currencyCode))
                    Text("bugun")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: totalBalance >= 0
                            ? [Color(hex: "#5E5CE6"), Color(hex: "#0A84FF")]
                            : [Color(hex: "#FF3B30"), Color(hex: "#C0392B")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Nozik glass "sheen" effekt
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .blur(radius: 20)
                        .padding(2)
                )
        }
        .shadow(color: (totalBalance >= 0 ? Color(hex: "#5E5CE6") : Color(hex: "#FF3B30")).opacity(0.35), radius: 18, y: 10)
    }
}
