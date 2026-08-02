import AppIntents

/// "50000 food xarajat qoʻsh" — strukturaviy intent (summa + kategoriya).
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Xarajat qoʻshish"
    static var description = IntentDescription("Tez xarajat qoʻshadi (summa va kategoriya).")

    // Ilovani ochmasdan fonda bajariladi.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Summa")
    var amount: Double

    @Parameter(title: "Kategoriya", default: "Other")
    var category: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) miqdorida \(\.$category) xarajat qoʻshish")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = FinanceStore.addExpense(amount: amount, categoryName: category)
        guard ok else {
            return .result(dialog: "Xarajatni qoʻshib boʻlmadi. Summani tekshiring.")
        }
        let formatted = CurrencyFormatter.string(amount, code: FinanceStore.currencyCode())
        let cat = (category?.isEmpty == false) ? category! : "Boshqa"
        return .result(dialog: "\(cat) uchun \(formatted) xarajat qoʻshildi ✅")
    }
}
