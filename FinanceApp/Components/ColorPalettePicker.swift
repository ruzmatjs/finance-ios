import SwiftUI

/// Rang tanlash palettasi — kategoriya/hisob/byudjet uchun qayta ishlatiladi.
struct ColorPalettePicker: View {
    @Binding var selection: String   // hex

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Theme.Colors.palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if selection.caseInsensitiveCompare(hex) == .orderedSame {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold)).foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().strokeBorder(.primary.opacity(0.1)))
                    .onTapGesture { selection = hex }
            }
        }
        .padding(.vertical, 4)
    }
}

/// SF Symbol tanlash — kategoriya va maqsad ikonkasi uchun.
struct SymbolPicker: View {
    @Binding var selection: String

    private let symbols = [
        "target", "airplane", "car.fill", "house.fill", "laptopcomputer", "iphone",
        "tv.fill", "gamecontroller.fill", "graduationcap.fill", "heart.fill", "cross.case.fill",
        "figure.run", "bed.double.fill", "person.2.fill", "pawprint.fill", "gift.fill",
        "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "briefcase.fill", "banknote.fill",
        "creditcard.fill", "bag.fill", "fork.knife", "cup.and.saucer.fill", "bus.fill",
        "fuelpump.fill", "tshirt.fill", "bolt.fill", "wifi", "shield.lefthalf.filled",
        "building.columns.fill", "cart.fill", "sparkles"
    ]
    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(selection == symbol ? Theme.Colors.accent.opacity(0.2) : Theme.Colors.card,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(selection == symbol ? Theme.Colors.accent : Theme.Colors.primaryText)
                    .onTapGesture { selection = symbol }
            }
        }
        .padding(.vertical, 4)
    }
}
