import SwiftUI
import PhotosUI

/// Chek rasmini biriktirish komponenti — kutubxona (`PhotosPicker`) yoki kamera.
/// Tanlangan rasm siqiladi va `Data?` binding'ga yoziladi.
struct ReceiptPicker: View {
    @Binding var data: Data?

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showViewer = false
    @State private var isLoading = false

    private var uiImage: UIImage? { data.flatMap { UIImage(data: $0) } }
    /// Qurilmada kamera mavjudmi (simulyatorda yoʻq).
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if let uiImage {
                attachedView(uiImage)
            } else {
                addButtons
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let raw = try? await newItem.loadTransferable(type: Data.self),
                   let compressed = ImageProcessor.compress(data: raw) {
                    data = compressed
                }
                isLoading = false
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                data = ImageProcessor.compress(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showViewer) {
            if let uiImage { ReceiptViewer(image: uiImage) }
        }
    }

    // MARK: Biriktirilgan rasm koʻrinishi
    private func attachedView(_ image: UIImage) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .onTapGesture { showViewer = true }

            VStack(alignment: .leading, spacing: 2) {
                Text("Chek biriktirilgan").font(.subheadline.weight(.medium))
                Text("Koʻrish uchun bosing").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation { data = nil; photoItem = nil }
            } label: {
                Image(systemName: "trash").foregroundStyle(Theme.Colors.expense)
            }
        }
    }

    // MARK: Qoʻshish tugmalari
    private var addButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                pickerLabel("Kutubxona", systemImage: "photo.on.rectangle")
            }

            if cameraAvailable {
                Button { showCamera = true } label: {
                    pickerLabel("Kamera", systemImage: "camera.fill")
                }
            }

            if isLoading { ProgressView() }
        }
    }

    private func pickerLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.Colors.accent)
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(Theme.Colors.accent.opacity(0.12), in: Capsule())
    }
}
