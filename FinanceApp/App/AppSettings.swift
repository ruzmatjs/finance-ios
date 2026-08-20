import Foundation
import SwiftUI
import Observation

/// Ilova sozlamalari — UserDefaults'da saqlanadi, `@Observable` orqali reaktiv.
/// Spec: Dark/Light/System, valyuta, til, haptika, App Lock, Face ID.
@Observable
final class AppSettings {

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "Tizim"
            case .light: return "Yorugʻ"
            case .dark: return "Qorongʻu"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.theme) }
    }
    var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: Keys.currency) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    var appLockEnabled: Bool {
        didSet { defaults.set(appLockEnabled, forKey: Keys.appLock) }
    }
    var biometricsEnabled: Bool {
        didSet { defaults.set(biometricsEnabled, forKey: Keys.biometrics) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }
    var hideBalance: Bool {
        didSet { defaults.set(hideBalance, forKey: Keys.hideBalance) }
    }

    // Bildirishnomalar
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }
    var dailyReminderHour: Int {
        didSet { defaults.set(dailyReminderHour, forKey: Keys.dailyHour) }
    }
    var monthlyReportEnabled: Bool {
        didSet { defaults.set(monthlyReportEnabled, forKey: Keys.monthlyReport) }
    }

    /// iCloud sync — oʻzgartirilsa ilova qayta ishga tushirilganda kuchga kiradi.
    var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSync) }
    }

    private let defaults: UserDefaults

    // Standart emas, App Group defaults — shunda Widget ham valyutani koʻradi.
    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        self.currencyCode = defaults.string(forKey: Keys.currency) ?? "UZS"
        self.hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        self.appLockEnabled = defaults.bool(forKey: Keys.appLock)
        self.biometricsEnabled = defaults.bool(forKey: Keys.biometrics)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        self.hideBalance = defaults.bool(forKey: Keys.hideBalance)
        self.notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        self.dailyReminderHour = defaults.object(forKey: Keys.dailyHour) as? Int ?? 21
        self.monthlyReportEnabled = defaults.object(forKey: Keys.monthlyReport) as? Bool ?? true
        self.iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSync) as? Bool ?? true
    }

    private enum Keys {
        static let theme = "settings.themeMode"
        static let currency = "settings.currencyCode"
        static let haptics = "settings.haptics"
        static let appLock = "settings.appLock"
        static let biometrics = "settings.biometrics"
        static let onboarding = "settings.onboarding"
        static let hideBalance = "settings.hideBalance"
        static let notifications = "settings.notifications"
        static let dailyHour = "settings.dailyReminderHour"
        static let monthlyReport = "settings.monthlyReport"
        static let iCloudSync = "settings.iCloudSync"
    }
}
