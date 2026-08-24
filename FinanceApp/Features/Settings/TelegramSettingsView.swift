import SwiftUI
import SwiftData

/// Telegram Bot orqali avtomatik haftalik hisobot yuborish sozlamalari ekrani.
struct TelegramSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var isTesting = false
    @State private var testSuccessMessage: String?
    @State private var testErrorMessage: String?

    @State private var isSendingReport = false
    @State private var reportSuccessMessage: String?
    @State private var reportErrorMessage: String?

    var body: some View {
        @Bindable var settings = settings

        Form {
            // 1. Bot ulanish maʼlumotlari
            Section {
                Link(destination: URL(string: "https://t.me/ruzmat_finance_bot")!) {
                    HStack {
                        Label("@ruzmat_finance_bot", systemImage: "paperplane.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.tint)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Bot Token")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    HStack {
                        TextField("123456789:ABCdefGhI...", text: $settings.telegramBotToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))

                        if let clip = UIPasteboard.general.string, !clip.isEmpty {
                            Button("Qoʻyish") {
                                settings.telegramBotToken = clip
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Chat ID")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    HStack {
                        TextField("987654321", text: $settings.telegramChatId)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))

                        if let clip = UIPasteboard.general.string, !clip.isEmpty {
                            Button("Qoʻyish") {
                                settings.telegramChatId = clip
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Telegram Bot (@ruzmat_finance_bot)")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. **@ruzmat_finance_bot** ga kiring va **/start** tugmasini bosing.")
                    Text("2. Botning **API Token**ini (BotFather'dan) va oʻz **Chat ID**ingizni (@userinfobot) kiriting.")
                }
                .font(.caption)
            }

            // 2. Test qilish va Holat
            Section {
                Button {
                    runTestConnection()
                } label: {
                    HStack {
                        Label("Ulanishni tekshirish", systemImage: "paperplane.fill")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(!settings.isTelegramConfigured || isTesting)

                if let success = testSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.income)
                        Text(success)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.income)
                    }
                }

                if let error = testErrorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Colors.expense)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.expense)
                    }
                }
            } header: {
                Text("Sinov")
            }

            // 3. Hisobot formati va qoʻlda yuborish
            Section {
                Picker("Biriktiriladigan fayl", selection: $settings.telegramReportFormat) {
                    Text("PDF hujjat").tag("pdf")
                    Text("Excel (.xlsx)").tag("excel")
                    Text("Faqat matn (faylsiz)").tag("text")
                }

                Button {
                    sendReportNow()
                } label: {
                    HStack {
                        Label("Hisobotni hozir yuborish", systemImage: "arrow.up.circle.fill")
                        Spacer()
                        if isSendingReport {
                            ProgressView()
                        }
                    }
                }
                .disabled(!settings.isTelegramConfigured || isSendingReport)

                if let success = reportSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.income)
                        Text(success)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.income)
                    }
                }

                if let error = reportErrorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Colors.expense)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.expense)
                    }
                }
            } header: {
                Text("Hisobot sozlamalari")
            }

            // 4. Avtomatlashtirish qoʻllanmasi
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Har hafta avtomatik yuborish", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.primaryText)

                    Text("iPhone har hafta belgilangan vaqtda fonda hisobotni yuborishi uchun:")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        StepRow(number: "1", text: "iPhone'da **\"Buyruqlar\" (Shortcuts)** ilovasini oching.")
                        StepRow(number: "2", text: "Pastdagi **\"Avtomatlashtirish\" (Automation)** tabiga oʻting va **+** bosing.")
                        StepRow(number: "3", text: "**\"Kun vaqti\" (Time of Day)** ni tanlang (masalan, Har dushanba 09:00).")
                        StepRow(number: "4", text: "Harakat sifatida **\"FinanceApp haftalik hisoboti\"** ni tanlang.")
                        StepRow(number: "5", text: "**\"Darhol ishga tushirish\"** (Run Immediately)ni belgilang.")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Avtomatlashtirish (Shortcuts)")
            }
        }
        .navigationTitle("Telegram Bot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runTestConnection() {
        testSuccessMessage = nil
        testErrorMessage = nil
        isTesting = true

        Task {
            let result = await TelegramService.testConnection(
                token: settings.telegramBotToken,
                chatId: settings.telegramChatId
            )
            await MainActor.run {
                isTesting = false
                switch result {
                case .success(let msg):
                    testSuccessMessage = msg
                case .failure(let err):
                    testErrorMessage = err.localizedDescription
                }
            }
        }
    }

    private func sendReportNow() {
        reportSuccessMessage = nil
        reportErrorMessage = nil
        isSendingReport = true

        let format: ExportFormat?
        switch settings.telegramReportFormat {
        case "pdf": format = .pdf
        case "excel": format = .excel
        default: format = nil
        }

        // Oxirgi 7 kunlik tranzaksiyalar
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyTxs = transactions.filter { $0.date >= weekAgo }

        Task {
            do {
                try await TelegramService.sendWeeklyReport(
                    transactions: weeklyTxs,
                    format: format,
                    currency: settings.currencyCode,
                    token: settings.telegramBotToken,
                    chatId: settings.telegramChatId
                )
                await MainActor.run {
                    isSendingReport = false
                    reportSuccessMessage = "Haftalik hisobot Telegram chatingizga muvaffaqiyatli yuborildi! 🚀"
                }
            } catch {
                await MainActor.run {
                    isSendingReport = false
                    reportErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct StepRow: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.Colors.tint))

            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}

#Preview {
    NavigationStack {
        TelegramSettingsView()
    }
    .environment(AppSettings())
    .modelContainer(PersistenceController.preview)
}
