import SwiftUI
import SwiftData
import Charts

/// Hisobotlar — davr tanlash, kategoriya taqsimoti (pie), trend (line/bar), top kategoriyalar.
struct ReportsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var transactions: [Transaction]

    @State private var range: ReportRange = .month
    @State private var typeFilter: TransactionType = .expense
    @State private var exportFile: ExportFile?

    private var interval: DateInterval {
        let period: PeriodType = switch range {
        case .day: .daily; case .week: .weekly; case .month: .monthly; case .year: .yearly
        }
        return Calendar.current.currentInterval(for: period, reference: Date())
    }

    private var scoped: [Transaction] {
        transactions.filter { interval.contains($0.date) && $0.type == typeFilter }
    }

    /// Kategoriya boʻyicha yigʻindi.
    private var byCategory: [(name: String, amount: Double, color: Color)] {
        let groups = Dictionary(grouping: scoped) { $0.category?.name ?? "Boshqa" }
        return groups.map { key, txs in
            (name: key,
             amount: txs.reduce(0) { $0 + $1.amount },
             color: txs.first?.category?.color ?? Theme.Colors.secondaryText)
        }.sorted { $0.amount > $1.amount }
    }

    private var total: Double { scoped.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Picker("Davr", selection: $range) {
                    ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)

                Picker("Tur", selection: $typeFilter) {
                    Text("Xarajat").tag(TransactionType.expense)
                    Text("Daromad").tag(TransactionType.income)
                }.pickerStyle(.segmented)

                if scoped.isEmpty {
                    EmptyStateView(icon: "chart.pie", title: "Maʼlumot yoʻq",
                                   message: "Bu davr uchun tranzaksiyalar mavjud emas.")
                } else {
                    donutCard
                    topCategoriesCard
                    trendCard
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 120)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Hisobotlar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            exportCurrent(as: format)
                        } label: {
                            Label(format.title, systemImage: format.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(scoped.isEmpty)
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
    }

    /// Joriy koʻrinishdagi tranzaksiyalarni tanlangan formatda eksport qiladi.
    private func exportCurrent(as format: ExportFormat) {
        let title = "\(typeFilter.title) hisoboti — \(range.title)"
        if let url = ExportManager.export(scoped, format: format,
                                          title: title, currency: settings.currencyCode) {
            exportFile = ExportFile(url: url)
        }
    }

    // MARK: Donut (Pie) chart
    private var donutCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Kategoriya taqsimoti")
            Chart(byCategory, id: \.name) { item in
                SectorMark(
                    angle: .value("Summa", item.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(item.color)
                .cornerRadius(4)
            }
            .frame(height: 220)
            .overlay {
                VStack {
                    Text("Jami").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                    Text(CurrencyFormatter.compact(total, code: settings.currencyCode))
                        .font(.system(.title3, design: .rounded).bold())
                }
            }
        }
        .cardStyle()
    }

    // MARK: Top kategoriyalar
    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Eng koʻp kategoriyalar")
            ForEach(byCategory.prefix(6), id: \.name) { item in
                HStack {
                    Circle().fill(item.color).frame(width: 10, height: 10)
                    Text(item.name)
                    Spacer()
                    Text("\(Int(item.amount / max(total,1) * 100))%")
                        .foregroundStyle(Theme.Colors.secondaryText).font(.caption)
                    Text(CurrencyFormatter.compact(item.amount, code: settings.currencyCode))
                        .font(.callout.weight(.medium))
                }
            }
        }
        .cardStyle()
    }

    // MARK: Trend (kunlik line/bar)
    private var trendCard: some View {
        let daily = dailySeries()
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Trend")
            Chart(daily, id: \.date) { p in
                LineMark(x: .value("Sana", p.date), y: .value("Summa", p.amount))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.accent)
                AreaMark(x: .value("Sana", p.date), y: .value("Summa", p.amount))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.15).gradient)
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    private func dailySeries() -> [(date: Date, amount: Double)] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: scoped) { cal.startOfDay(for: $0.date) }
        return groups.map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }
}

#Preview {
    NavigationStack { ReportsView() }
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
}
