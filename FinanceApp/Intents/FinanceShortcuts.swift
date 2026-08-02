import AppIntents

/// Siri Shortcuts'ga tayyor iboralar (App Shortcuts).
/// iOS ularni ilova oʻrnatilishi bilanoq avtomatik ekadi — foydalanuvchi
/// qoʻlda sozlamasa ham "Hey Siri, ..." bilan ishlaydi.
struct FinanceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogIntent(),
            phrases: [
                "\(.applicationName)da yozib qoʻy",
                "Log expense in \(.applicationName)"
            ],
            shortTitle: "Tez yozish",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "\(.applicationName)ga xarajat qoʻsh",
                "Add expense in \(.applicationName)"
            ],
            shortTitle: "Xarajat qoʻshish",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ShowMonthSpendingIntent(),
            phrases: [
                "\(.applicationName)da bu oygi xarajatim",
                "Show this month spending in \(.applicationName)"
            ],
            shortTitle: "Oylik xarajat",
            systemImageName: "chart.pie"
        )
    }
}
