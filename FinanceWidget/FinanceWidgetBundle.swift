import WidgetKit
import SwiftUI

/// Widget Extension'ning kirish nuqtasi — uch widgetni birlashtiradi.
@main
struct FinanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaySpendingWidget()      // Bugungi sarf
        RemainingBudgetWidget()    // Qolgan byudjet
        QuickAddWidget()           // Tez qoʻshish (deep-link)
        QuickExpenseWidget()       // Tez xarajat (interaktiv tugmalar)
    }
}
