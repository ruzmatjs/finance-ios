import Foundation
import SwiftUI
import SwiftData

/// Dependency Injection konteyneri.
/// Barcha umumiy servislar shu yerda yigʻiladi va `Environment` orqali tarqatiladi.
/// Nega? Global singleton'lardan qochish, testda almashtirish oson boʻlishi uchun.
@MainActor
@Observable
final class AppContainer {
    let settings: AppSettings
    let repository: FinanceRepositoryProtocol
    let haptics: HapticManager

    init(context: ModelContext, settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.repository = FinanceRepository(context: context)
        self.haptics = HapticManager(isEnabled: settings.hapticsEnabled)
    }
}

// Environment orqali ulash uchun kalit.
private struct AppContainerKey: EnvironmentKey {
    // Preview uchun default — real konteyner App entry'da beriladi.
    static let defaultValue: AppContainer? = nil
}

extension EnvironmentValues {
    var container: AppContainer? {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
