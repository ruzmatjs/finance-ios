import AppIntents

/// Interaktiv widget tugmasi bosilganda ishlaydigan intent.
/// Ilovani OCHMASDAN, fon rejimida preset xarajatni yozadi (iOS 17 interactive widgets).
///
/// `Shared/`da joylashgan — chunki intent widget target'iga ham kompilyatsiya boʻlishi shart.
struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Tez xarajat qoʻshish"
    /// Shortcuts galereyasida koʻrinmasin — faqat widget uchun.
    static var isDiscoverable: Bool = false

    @Parameter(title: "Summa")
    var amount: Double

    @Parameter(title: "Kategoriya")
    var categoryName: String

    init() {}

    init(amount: Double, categoryName: String) {
        self.amount = amount
        self.categoryName = categoryName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        FinanceStore.addExpense(amount: amount, categoryName: categoryName)
        // FinanceStore.addExpense ichida WidgetCenter.reloadAllTimelines() chaqiriladi.
        return .result()
    }
}
