import SwiftUI

/// Animatsion progress halqasi — byudjet va maqsadlar uchun.
struct ProgressRing<Content: View>: View {
    var progress: Double            // 0...1
    var color: Color
    var lineWidth: CGFloat = 10
    var size: CGFloat = 72
    @ViewBuilder var content: () -> Content

    init(
        progress: Double,
        color: Color,
        lineWidth: CGFloat = 10,
        size: CGFloat = 72,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            content()
        }
        .frame(width: size, height: size)
    }
}

extension ProgressRing where Content == Text {
    init(
        progress: Double,
        color: Color,
        lineWidth: CGFloat = 10,
        size: CGFloat = 72
    ) {
        self.init(progress: progress, color: color, lineWidth: lineWidth, size: size) {
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.primaryText)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ProgressRing(progress: 0.35, color: .orange)
        ProgressRing(progress: 0.8, color: .green)
        ProgressRing(progress: 1.1, color: .red)
    }
    .padding()
}
