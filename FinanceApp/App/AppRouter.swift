import Foundation
import Observation

/// Ilova darajasidagi navigatsiya holati — asosan deep-link (widget bosilishi) uchun.
/// `financeapp://add` ochilganda Quick Add oynasini koʻrsatadi.
@MainActor
@Observable
final class AppRouter {
    var showQuickAdd = false

    /// Widget yoki tashqi havoladan kelgan URL'ni qayta ishlaydi.
    func handle(url: URL) {
        switch url.host {
        case "add":
            showQuickAdd = true
        default:
            break
        }
    }
}
