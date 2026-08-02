import SwiftUI

/// Chek rasmini toʻliq ekranda koʻrish — zoom va surish bilan.
struct ReceiptViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = max(1, $0.magnification) }
                            .onEnded { _ in withAnimation(.spring) { if scale < 1 { scale = 1 } } }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { offset = $0.translation }
                            .onEnded { _ in if scale <= 1 { withAnimation(.spring) { offset = .zero } } }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring) { scale = scale > 1 ? 1 : 2; offset = .zero }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                        .tint(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
