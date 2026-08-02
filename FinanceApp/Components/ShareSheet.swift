import SwiftUI
import UIKit

/// Fayl ulashiladigan URL'ni Identifiable qilib `.sheet(item:)`da ishlatish uchun oʻram.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// `UIActivityViewController`ni SwiftUI'ga oʻrab beruvchi komponent (fayl ulashish).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
