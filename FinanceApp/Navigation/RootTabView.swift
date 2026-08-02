import SwiftUI

/// Asosiy tab navigatsiyasi.
/// Markazda "+" tugmasi orqali tez qoʻshish (Quick Add).
struct RootTabView: View {
    @Environment(\.container) private var container
    @Environment(AppRouter.self) private var router
    @State private var selectedTab: Tab = .dashboard

    enum Tab: Hashable { case dashboard, transactions, reports, settings }

    var body: some View {
        @Bindable var router = router
        return TabView(selection: $selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Asosiy", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.dashboard)

            NavigationStack { TransactionsListView() }
                .tabItem { Label("Tranzaksiyalar", systemImage: "list.bullet.rectangle.fill") }
                .tag(Tab.transactions)

            NavigationStack { ReportsView() }
                .tabItem { Label("Hisobotlar", systemImage: "chart.pie.fill") }
                .tag(Tab.reports)

            NavigationStack { SettingsView() }
                .tabItem { Label("Sozlamalar", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.Colors.accent)
        .overlay(alignment: .bottom) {
            // Suzuvchi Quick Add tugmasi (tab bar ustida).
            quickAddButton
                .padding(.bottom, 54)
        }
        .sheet(isPresented: $router.showQuickAdd) {
            AddTransactionView()
        }
    }

    private var quickAddButton: some View {
        Button {
            container?.haptics.impact(.medium)
            router.showQuickAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [Color(hex: "#5E5CE6"), Color(hex: "#0A84FF")],
                                   startPoint: .top, endPoint: .bottom),
                    in: Circle()
                )
                .shadow(color: Color(hex: "#0A84FF").opacity(0.4), radius: 12, y: 6)
        }
        .accessibilityLabel("Tranzaksiya qoʻshish")
    }
}
