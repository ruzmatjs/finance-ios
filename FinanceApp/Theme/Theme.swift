import SwiftUI

/// Markazlashtirilgan dizayn tokenlari.
/// Barcha rang, spacing, radius va shrift shu yerdan olinadi —
/// bu izchil, premium va oson maintenance qilinadigan UI beradi (DRY).
enum Theme {

    // MARK: - Spacing (8pt grid tizimi)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 44
    }

    // MARK: - Corner radius
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Ranglar (semantik)
    enum Colors {
        static let accent = Color.accentColor
        static let income = Color(hex: "#34C759")
        static let expense = Color(hex: "#FF3B30")
        static let transfer = Color(hex: "#0A84FF")
        static let warning = Color(hex: "#FF9500")

        static let background = Color(.systemGroupedBackground)
        static let secondaryBackground = Color(.tertiarySystemGroupedBackground)
        static let card = Color(.secondarySystemGroupedBackground)
        static let separator = Color(.separator)
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)

        /// Kategoriya rangli paletta (yangi kategoriya yaratishda tavsiya).
        static let palette: [String] = [
            "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
            "#30B0C7", "#0A84FF", "#5856D6", "#AF52DE", "#FF2D55",
            "#A2845E", "#8E8E93"
        ]
    }

    // MARK: - Shrift (semantik typografiya)
    enum Font {
        static let largeAmount = SwiftUI.Font.system(size: 40, weight: .bold, design: .rounded)
        static let amount = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title = SwiftUI.Font.system(.title2, design: .rounded).weight(.bold)
        static let sectionTitle = SwiftUI.Font.system(.headline, design: .rounded)
        static let body = SwiftUI.Font.system(.body)
        static let caption = SwiftUI.Font.system(.caption)
    }

    // MARK: - Soya (premium chuqurlik)
    enum Shadow {
        static let card = (color: Color.black.opacity(0.06), radius: 12.0, y: 4.0)
    }
}

// MARK: - Umumiy modifierlar
extension View {
    /// Standart kartochka koʻrinishi — glass/soft material bilan.
    func cardStyle(padding: CGFloat = Theme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, y: Theme.Shadow.card.y)
    }

    /// Ultra-thin glass effekt (HIG'ga mos, appropriate joylarda).
    func glassStyle(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
