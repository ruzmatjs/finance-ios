import Foundation

/// App Group — ilova, Widget va App Intents jarayonlari oʻrtasida
/// umumiy SwiftData store va UserDefaults'ni ulaydi.
///
/// MUHIM: bu identifikator Xcode'da har bir target'ning "Signing & Capabilities >
/// App Groups" boʻlimida yoqilgan boʻlishi shart (project.yml entitlements bilan sozlangan).
enum AppGroup {
    static let identifier = "group.com.ruzmat.finance"

    /// Umumiy sozlamalar. App Group yoqilgan boʻlsa umumiy suite, aks holda standart
    /// (bepul hisobda App Group entitlement boʻlmagani uchun).
    static let defaults: UserDefaults = {
        guard AppConfig.useAppGroup, let shared = UserDefaults(suiteName: identifier) else {
            return .standard
        }
        return shared
    }()
}
