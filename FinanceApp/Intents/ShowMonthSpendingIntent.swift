import AppIntents

/// "Bu oygi xarajatimni koʻrsat" — joriy oy jami sarfini aytadi.
struct ShowMonthSpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Bu oygi xarajat"
    static var description = IntentDescription("Joriy oydagi umumiy xarajatni koʻrsatadi.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let total = FinanceStore.monthSpending()
        let formatted = CurrencyFormatter.string(total, code: FinanceStore.currencyCode())
        return .result(dialog: "Bu oy jami \(formatted) sarfladingiz.")
    }
}
