import SwiftUI

/// Chiroyli boʻsh holat (empty state) — spec talabi.
/// Ikonka + sarlavha + tavsif + ixtiyoriy tugma.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String = ""
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Colors.accent.gradient)
                .symbolEffect(.pulse)
                .padding(.bottom, Theme.Spacing.xs)

            Text(title)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Colors.primaryText)

            if !message.isEmpty {
                Text(message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "Hozircha tranzaksiya yoʻq",
        message: "Birinchi daromad yoki xarajatingizni qoʻshing.",
        actionTitle: "Qoʻshish",
        action: {}
    )
}
