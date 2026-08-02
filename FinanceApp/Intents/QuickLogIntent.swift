import AppIntents

/// "Taxi 35000" kabi erkin matnni tabiiy til parseri orqali tushunadigan intent.
/// Spec'dagi AI parserni Siri bilan bogʻlaydi.
struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Tez yozib qoʻyish"
    static var description = IntentDescription("Matn orqali xarajat/daromad qoʻshadi. Masalan: \"Taxi 35000\".")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Nima sarfladingiz?", requestValueDialog: "Masalan: Taxi 35000")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text) yozib qoʻyish")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let result = NaturalLanguageParser().parse(text) else {
            return .result(dialog: "Matndan summani aniqlay olmadim. Masalan: \"Taxi 35000\".")
        }
        // Hozircha xarajatlar qoʻllab-quvvatlanadi (daromad ham qoʻshsa boʻladi).
        let ok = FinanceStore.addExpense(amount: result.amount, categoryName: result.categoryHint)
        guard ok else { return .result(dialog: "Saqlab boʻlmadi.") }
        let formatted = CurrencyFormatter.string(result.amount, code: FinanceStore.currencyCode())
        return .result(dialog: "\(result.categoryHint ?? "Xarajat") — \(formatted) qoʻshildi ✅")
    }
}
