import SwiftUI
import SwiftData

/// Ilovaning kirish nuqtasi.
/// - SwiftData konteynerini ulaydi
/// - DI konteynerini yaratadi
/// - Tema (Dark/Light/System) ni qoʻllaydi
/// - Takrorlanuvchi tranzaksiyalarni ishga tushiradi
@main
struct FinanceApp: App {
    private let modelContainer: ModelContainer
    @State private var container: AppContainer
    @State private var settings: AppSettings
    @State private var router = AppRouter()
    @State private var auth = AuthenticationManager()
    @State private var syncMonitor = CloudSyncMonitor()

    init() {
        let settings = AppSettings()
        // App Group'dagi yagona umumiy konteyner (widget/intents bilan bir xil baza).
        let modelContainer = PersistenceController.shared
        self.modelContainer = modelContainer
        _settings = State(initialValue: settings)
        _container = State(initialValue: AppContainer(
            context: modelContainer.mainContext,
            settings: settings
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
                .environment(settings)
                .environment(router)
                .environment(auth)
                .environment(syncMonitor)
                .preferredColorScheme(settings.themeMode.colorScheme)
                .task {
                    // CloudKit sync holatini kuzatishni boshlash (bepul buildда o'chirilgan).
                    syncMonitor.start(enabled: AppConfig.useCloudKit && settings.iCloudSyncEnabled)
                    // Ilova ochilganda takrorlanuvchi tranzaksiyalarni yangilash.
                    RecurringEngine(context: modelContainer.mainContext).run()
                    // Bildirishnoma rejalarini sinxronlash.
                    if settings.notificationsEnabled {
                        let rules = (try? modelContainer.mainContext.fetch(
                            FetchDescriptor<RecurringTransaction>())) ?? []
                        NotificationManager.shared.syncSchedules(settings: settings, recurring: rules)
                    }
                }
                .onOpenURL { url in
                    // Widget "Tez qoʻshish" bosilganda: financeapp://add
                    router.handle(url: url)
                }
        }
        .modelContainer(modelContainer)
    }
}

/// Onboarding, asosiy interfeys va qulf ekrani oʻrtasida yoʻnaltiruvchi.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthenticationManager.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if settings.hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }

            // App-switcher maxfiyligi — ilova nofaol boʻlganda kontentni yashiramiz.
            if scenePhase == .inactive && settings.appLockEnabled {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            }

            // Qulf ekrani.
            if settings.appLockEnabled && auth.isLocked {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isLocked)
        .onAppear {
            if settings.appLockEnabled { auth.lock() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Ilova fonga oʻtganda qulflaymiz (keyingi kirishda qayta soʻraladi).
            if phase == .background && settings.appLockEnabled {
                auth.lock()
            }
        }
    }
}
