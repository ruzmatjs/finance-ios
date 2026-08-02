import SwiftUI

/// Kategoriya/hisob ikonkasi — rangli doira ichida SF Symbol.
/// Butun ilova boʻylab qayta ishlatiladi (DRY).
struct CategoryIconView: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: Circle())
    }
}

#Preview {
    HStack(spacing: 16) {
        CategoryIconView(symbol: "fork.knife", color: .orange)
        CategoryIconView(symbol: "car.fill", color: .blue, size: 52)
        CategoryIconView(symbol: "airplane", color: .cyan, size: 32)
    }
    .padding()
}
