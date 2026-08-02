import Foundation
import UserNotifications

/// Lokal bildirishnomalarni markazlashtirilgan boshqaruvi (`UNUserNotificationCenter`).
///
/// Spec: Byudjet ogohlantirishi, Takrorlanuvchi toʻlov eslatmasi,
/// Oylik hisobot eslatmasi, Kunlik xarajat eslatmasi.
///
/// Reja sinxronlash **idempotent** — avval hammasini oʻchirib, qaytadan ekadi,
/// shuning uchun bir necha marta chaqirilsa ham dublikat yaratmaydi.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    // Identifikator prefikslari
    private enum ID {
        static let daily = "daily.expense"
        static let monthly = "monthly.report"
        static let recurringPrefix = "recurring."
        static let budgetPrefix = "budget.warn."
    }

    /// Ruxsat soʻraydi (alert + sound + badge).
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Barcha rejalarni sozlamalar va takrorlanuvchi qoidalarga qarab qayta ekadi.
    func syncSchedules(settings: AppSettings, recurring: [RecurringTransaction]) {
        // Faqat rejalashtirilganlarni oʻchiramiz (yetkazilganlarga tegmaydi).
        center.removeAllPendingNotificationRequests()
        guard settings.notificationsEnabled else { return }

        scheduleDailyReminder(hour: settings.dailyReminderHour)
        if settings.monthlyReportEnabled { scheduleMonthlyReport() }

        for rule in recurring where rule.isActive {
            scheduleRecurringReminder(rule)
        }
    }

    // MARK: - Individual rejalar

    private func scheduleDailyReminder(hour: Int) {
        var dc = DateComponents(); dc.hour = hour; dc.minute = 0
        add(id: ID.daily,
            title: "Kunlik eslatma",
            body: "Bugungi xarajatlaringizni yozib qoʻyishni unutmang 💸",
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
    }

    private func scheduleMonthlyReport() {
        var dc = DateComponents(); dc.day = 1; dc.hour = 10; dc.minute = 0
        add(id: ID.monthly,
            title: "Oylik hisobot tayyor 📊",
            body: "Oʻtgan oy moliyaviy hisobotingizni koʻrib chiqing.",
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
    }

    private func scheduleRecurringReminder(_ rule: RecurringTransaction) {
        guard rule.nextDueDate > Date() else { return }
        var dc = Calendar.current.dateComponents([.year, .month, .day], from: rule.nextDueDate)
        dc.hour = 9
        add(id: ID.recurringPrefix + rule.id.uuidString,
            title: "\(rule.title) toʻlovi",
            body: "\(CurrencyFormatter.string(rule.amount, code: FinanceStore.currencyCode())) toʻlov muddati bugun.",
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false))
    }

    /// Byudjet ogohlantirishi — darhol yetkaziladi (hodisaga bogʻliq).
    func sendBudgetWarning(name: String, spent: Double, limit: Double, currency: String) {
        let body = "\(name): \(CurrencyFormatter.compact(spent, code: currency)) / \(CurrencyFormatter.compact(limit, code: currency)) sarflandi."
        add(id: ID.budgetPrefix + name,
            title: "⚠️ Byudjet ogohlantirishi",
            body: body,
            trigger: nil) // trigger == nil => hoziroq
    }

    // MARK: - Yordamchi

    private func add(id: String, title: String, body: String, trigger: UNNotificationTrigger?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
