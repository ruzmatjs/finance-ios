import SwiftUI
import SwiftData
import Charts

/// Asosiy ekran — balans, statistika, byudjet, trend va soʻnggi tranzaksiyalar.
struct DashboardView: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var viewModel: DashboardViewModel?
    @State private var showAllTransactions = false
    @State private var editingTransaction: Transaction?

    @State private var selectedPointDate: Date? = nil

    private func selectedWeeklyPoint(_ vm: DashboardViewModel) -> DashboardViewModel.WeeklyTrendPoint? {
        if let sel = selectedPointDate {
            return vm.weeklyPoints.first { Calendar.current.isDate($0.date, inSameDayAs: sel) }
        }
        return vm.weeklyPoints.last
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                if let vm = viewModel {
                    BalanceHeaderCard(
                        totalBalance: vm.totalBalance,
                        todayChange: vm.todayBalance,
                        currencyCode: vm.currencyCode,
                        isHidden: settings.hideBalance,
                        onToggleHidden: {
                            settings.hideBalance.toggle()
                        }
                    )

                    if !vm.weeklyPoints.isEmpty { spendingTrendCard(vm) }
                    if !vm.budgets.isEmpty { budgetSection(vm) }
                    if !vm.upcomingBills.isEmpty { upcomingSection(vm) }
                    recentSection(vm)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 120)
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { setupAndLoad() }
    }

    // MARK: Daromad va xarajat trendi (Swift Charts)
    private func spendingTrendCard(_ vm: DashboardViewModel) -> some View {
        let activePoint = selectedWeeklyPoint(vm)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let pt = activePoint {
                let diff = pt.income - pt.expense
                VStack(alignment: .leading, spacing: 4) {
                    Text(pt.date.formatted(.dateTime.weekday(.wide).day().month()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    HStack(spacing: 12) {
                        Text("🟢 +\(CurrencyFormatter.string(pt.income, code: vm.currencyCode))")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.Colors.income)
                        Text("🔴 −\(CurrencyFormatter.string(pt.expense, code: vm.currencyCode))")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.Colors.expense)
                        Text("📊 \(CurrencyFormatter.signed(diff, code: vm.currencyCode))")
                            .font(.caption2.bold())
                            .foregroundStyle(diff >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 10))
            }

            Chart(vm.chartEntries) { entry in
                BarMark(
                    x: .value("Kun", entry.date, unit: .day),
                    y: .value("Summa", entry.scaledAmount)
                )
                .foregroundStyle(entry.category == "Daromad" ? Theme.Colors.income : Theme.Colors.expense)
                .position(by: .value("Tur", entry.category))
                .cornerRadius(4)
            }
            .chartXSelection(value: $selectedPointDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 160)
        }
        .cardStyle()
    }

    // MARK: Byudjetlar
    private func budgetSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Byudjetlar")
            ForEach(vm.budgets) { bp in
                HStack(spacing: Theme.Spacing.md) {
                    ProgressRing(progress: bp.progress, color: bp.isOver ? Theme.Colors.expense : bp.budget.color, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bp.budget.name).font(.body.weight(.medium))
                        if let categories = bp.budget.categories, !categories.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(categories.prefix(4)) { cat in
                                    CategoryIconView(symbol: cat.symbol, color: cat.color, size: 20)
                                }
                                if categories.count > 4 {
                                    Text("+\(categories.count - 4)")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                            }
                        }
                        Text("\(CurrencyFormatter.compact(bp.spent, code: vm.currencyCode)) / \(CurrencyFormatter.compact(bp.budget.limitAmount, code: vm.currencyCode))")
                            .font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                        if bp.isOver {
                            Label("Byudjetdan oshdi", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.expense)
                        }
                    }
                    Spacer()
                }
            }
        }
        .cardStyle()
    }

    // MARK: Yaqinlashayotgan toʻlovlar
    private func upcomingSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Yaqinlashayotgan toʻlovlar")
            ForEach(vm.upcomingBills) { bill in
                HStack {
                    CategoryIconView(symbol: bill.category?.symbol ?? "calendar",
                                     color: bill.category?.color ?? Theme.Colors.warning, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.title).font(.body.weight(.medium))
                        Text(bill.nextDueDate.formatted(.dateTime.day().month()))
                            .font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                    }
                    Spacer()
                    AmountText(amount: bill.amount, currencyCode: vm.currencyCode,
                               type: bill.type, font: .callout.weight(.semibold))
                }
            }
        }
        .cardStyle()
    }

    // MARK: Soʻnggi tranzaksiyalar
    private func recentSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Soʻnggi tranzaksiyalar", actionTitle: "Barchasi") {
                showAllTransactions = true
            }
            if vm.recentTransactions.isEmpty {
                EmptyStateView(icon: "tray", title: "Hozircha boʻsh",
                               message: "Pastdagi + tugma orqali birinchi tranzaksiyani qoʻshing.")
            } else {
                ForEach(vm.recentTransactions) { tx in
                    Button {
                        editingTransaction = tx
                    } label: {
                        TransactionRow(transaction: tx)
                    }
                    .buttonStyle(.plain)
                    if tx.id != vm.recentTransactions.last?.id { Divider() }
                }
            }
        }
        .cardStyle()
        .sheet(item: $editingTransaction) { tx in
            AddTransactionView(transaction: tx)
                .onDisappear {
                    viewModel?.load()
                }
        }
        .navigationDestination(isPresented: $showAllTransactions) {
            TransactionsListView()
        }
    }

    private func setupAndLoad() {
        if viewModel == nil {
            let repo: FinanceRepositoryProtocol = container?.repository
                ?? FinanceRepository(context: modelContext)
            viewModel = DashboardViewModel(repository: repo, currencyCode: settings.currencyCode)
        }
        viewModel?.load()
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
}
