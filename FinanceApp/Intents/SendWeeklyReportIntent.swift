import Foundation
import AppIntents
import SwiftData

/// Siri va iOS Shortcuts avtomatizatsiyasi orqali haftalik hisobotni Telegramga yuboruvchi Intent.
/// Fon rejimida (`openAppWhenRun: false`) ilovani ochmasdan ishlay oladi.
struct SendWeeklyReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Haftalik hisobotni Telegramga yuborish"
    static var description = IntentDescription("Oxirgi 7 kunlik moliyaviy hisobotni (matn va fayl) Telegram botingizga yuboradi.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = AppGroup.defaults
        let token = defaults.string(forKey: "settings.telegramBotToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chatId = defaults.string(forKey: "settings.telegramChatId")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let formatStr = defaults.string(forKey: "settings.telegramReportFormat") ?? "pdf"
        let currency = defaults.string(forKey: "settings.currencyCode") ?? "UZS"

        guard !token.isEmpty && !chatId.isEmpty else {
            return .result(dialog: "Telegram Bot sozlanmagan. Ilova ichidagi Sozlamalar -> Telegram Bot boʻlimiga kirib Token va Chat ID kiriting.")
        }

        // Oxirgi 7 kunlik tranzaksiyalarni olish
        let container = PersistenceController.shared
        let context = ModelContext(container)

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= weekAgo },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let transactions = (try? context.fetch(descriptor)) ?? []

        let format: ExportFormat?
        switch formatStr {
        case "pdf": format = .pdf
        case "excel": format = .excel
        default: format = nil
        }

        do {
            try await TelegramService.sendWeeklyReport(
                transactions: transactions,
                format: format,
                currency: currency,
                token: token,
                chatId: chatId
            )
            return .result(dialog: "Haftalik moliya hisobotingiz Telegram chatingizga yuborildi! 📊")
        } catch {
            return .result(dialog: "Telegramga yuborishda xatolik yuz berdi: \(error.localizedDescription)")
        }
    }
}
