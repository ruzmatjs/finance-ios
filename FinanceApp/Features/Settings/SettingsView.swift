import SwiftUI
import SwiftData

/// Sozlamalar — tema, valyuta, xavfsizlik, bildirishnomalar + boshqaruv ekranlari.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.container) private var container
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Query private var recurringRules: [RecurringTransaction]

    var body: some View {
        @Bindable var settings = settings
        Form {
            // Boshqaruv boʻlimlari
            Section("Boshqaruv") {
                NavigationLink { AccountsView() } label: { Label("Hisoblar", systemImage: "creditcard.fill") }
                NavigationLink { DebtsView() } label: { Label("Qarzlar (Berdilar / Oldilar)", systemImage: "hand.raised.fill") }
                NavigationLink { CategoriesView() } label: { Label("Kategoriyalar", systemImage: "square.grid.2x2.fill") }
                NavigationLink { BudgetsView() } label: { Label("Byudjetlar", systemImage: "chart.bar.fill") }
                NavigationLink { GoalsView() } label: { Label("Maqsadlar", systemImage: "target") }
                NavigationLink { RecurringView() } label: { Label("Takrorlanuvchi toʻlovlar", systemImage: "arrow.triangle.2.circlepath") }
                NavigationLink { CalendarView() } label: { Label("Kalendar", systemImage: "calendar") }
                NavigationLink { StatisticsView() } label: { Label("Statistika", systemImage: "chart.xyaxis.line") }
            }

            // Integratsiyalar
            Section("Integratsiyalar") {
                NavigationLink {
                    TelegramSettingsView()
                } label: {
                    HStack {
                        Label("Telegram Bot hisoboti", systemImage: "paperplane.fill")
                        Spacer()
                        if settings.isTelegramConfigured {
                            Text("Ulangan")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.income)
                        }
                    }
                }
            }

            // Koʻrinish
            Section("Koʻrinish") {
                Picker("Tema", selection: $settings.themeMode) {
                    ForEach(AppSettings.ThemeMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Valyuta", selection: $settings.currencyCode) {
                    ForEach(CurrencyFormatter.supportedCodes, id: \.self) {
                        Text("\($0) (\(CurrencyFormatter.symbol(for: $0)))").tag($0)
                    }
                }
            }

            // Xavfsizlik
            Section("Xavfsizlik") {
                Toggle(isOn: $settings.appLockEnabled) {
                    Label("Ilova qulfi", systemImage: "lock.fill")
                }
                Toggle(isOn: $settings.biometricsEnabled) {
                    Label("Face ID / Touch ID", systemImage: "faceid")
                }.disabled(!settings.appLockEnabled)
            }

            // Zaxira & Sinxronizatsiya (bepul hisobda mavjud emas)
            #if !FREE_TIER
            Section {
                Toggle(isOn: $settings.iCloudSyncEnabled) {
                    Label("iCloud sinxronizatsiya", systemImage: "icloud.fill")
                }
                if settings.iCloudSyncEnabled {
                    HStack {
                        Label(syncMonitor.status.title, systemImage: syncMonitor.status.systemImage)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                        if case .syncing = syncMonitor.status {
                            ProgressView()
                        } else if case .synced(let date) = syncMonitor.status {
                            Text(date.formatted(.dateTime.hour().minute()))
                                .font(.caption).foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                    .font(.subheadline)
                }
            } header: {
                Text("Zaxira & Sinxronizatsiya")
            } footer: {
                Text("Maʼlumotlaringiz barcha qurilmalaringizda iCloud orqali xavfsiz sinxronlanadi. Oʻzgarish ilova qayta ishga tushirilganda kuchga kiradi.")
            }
            #endif

            // Bildirishnomalar
            Section("Bildirishnomalar") {
                Toggle(isOn: $settings.notificationsEnabled) {
                    Label("Bildirishnomalar", systemImage: "bell.fill")
                }
                .onChange(of: settings.notificationsEnabled) { _, enabled in
                    Task {
                        if enabled { _ = await NotificationManager.shared.requestAuthorization() }
                        syncNotifications()
                    }
                }

                if settings.notificationsEnabled {
                    DatePicker("Kunlik eslatma", selection: dailyReminderBinding,
                               displayedComponents: .hourAndMinute)
                    Toggle(isOn: $settings.monthlyReportEnabled) {
                        Label("Oylik hisobot eslatmasi", systemImage: "calendar.badge.clock")
                    }
                    .onChange(of: settings.monthlyReportEnabled) { _, _ in syncNotifications() }
                }
            }

            // Umumiy
            Section("Umumiy") {
                Toggle(isOn: $settings.hapticsEnabled) {
                    Label("Haptik fikr-mulohaza", systemImage: "hand.tap.fill")
                }
                .onChange(of: settings.hapticsEnabled) { _, new in
                    container?.haptics.isEnabled = new
                }
            }

            // Maʼlumot
            Section {
                LabeledContent("Versiya", value: "1.0.0")
            } footer: {
                Text("Oflayn-birinchi: barcha maʼlumot avval qurilmada saqlanadi, soʻng iCloud'ga sinxronlanadi.")
            }
        }
        .navigationTitle("Sozlamalar")
    }

    /// Kunlik eslatma vaqtini soat sifatida bogʻlaydi (faqat soat muhim).
    private var dailyReminderBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: settings.dailyReminderHour,
                                      minute: 0, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                settings.dailyReminderHour = Calendar.current.component(.hour, from: newValue)
                syncNotifications()
            }
        )
    }

    private func syncNotifications() {
        NotificationManager.shared.syncSchedules(settings: settings, recurring: recurringRules)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
        .environment(CloudSyncMonitor())
}
