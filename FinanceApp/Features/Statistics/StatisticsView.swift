import SwiftUI
import SwiftData
import Charts

/// Statistika — oʻrtacha sarf, eng katta xarajat/daromad, eng koʻp ishlatilgan kategoriya,
/// oylar taqqoslash va sarf "heatmap".
struct StatisticsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var transactions: [Transaction]

    private var expenses: [Transaction] { transactions.filter { $0.type == .expense } }
    private var incomes: [Transaction] { transactions.filter { $0.type == .income } }

    private var avgDaily: Double {
        guard !expenses.isEmpty else { return 0 }
        let days = Set(expenses.map { $0.date.startOfDay }).count
        return expenses.reduce(0) { $0 + $1.amount } / Double(max(days, 1))
    }
    private var avgMonthly: Double { avgDaily * 30 }
    private var highestExpense: Transaction? { expenses.max { $0.amount < $1.amount } }
    private var highestIncome: Transaction? { incomes.max { $0.amount < $1.amount } }
    private var mostUsedCategory: (name: String, count: Int)? {
        let counts = Dictionary(grouping: expenses) { $0.category?.name ?? "Boshqa" }.mapValues { $0.count }
        return counts.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatCard(title: "Oʻrtacha kunlik", amount: avgDaily, currencyCode: settings.currencyCode, icon: "calendar", tint: Theme.Colors.expense)
                    StatCard(title: "Oʻrtacha oylik", amount: avgMonthly, currencyCode: settings.currencyCode, icon: "calendar.circle", tint: Theme.Colors.warning)
                    StatCard(title: "Eng katta xarajat", amount: highestExpense?.amount ?? 0, currencyCode: settings.currencyCode, icon: "arrow.up.right", tint: Theme.Colors.expense)
                    StatCard(title: "Eng katta daromad", amount: highestIncome?.amount ?? 0, currencyCode: settings.currencyCode, icon: "arrow.down.left", tint: Theme.Colors.income)
                }

                if let most = mostUsedCategory {
                    HStack {
                        Label("Eng koʻp ishlatilgan", systemImage: "star.fill").font(.subheadline)
                        Spacer()
                        Text("\(most.name) (\(most.count))").font(.subheadline.weight(.semibold))
                    }.cardStyle()
                }

                monthlyComparison
                heatmap
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Statistika")
    }

    // Oylar taqqoslash (soʻnggi 6 oy)
    private var monthlyComparison: some View {
        let cal = Calendar.current
        let now = Date()
        let data: [(month: Date, income: Double, expense: Double)] = (0..<6).reversed().compactMap { offset in
            guard let m = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let interval = cal.currentInterval(for: .monthly, reference: m)
            let txs = transactions.filter { interval.contains($0.date) }
            return (m,
                    txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                    txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount })
        }
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Oylar taqqoslash")
            Chart {
                ForEach(data, id: \.month) { d in
                    BarMark(x: .value("Oy", d.month, unit: .month), y: .value("Daromad", d.income))
                        .foregroundStyle(Theme.Colors.income).position(by: .value("Tur", "Daromad"))
                    BarMark(x: .value("Oy", d.month, unit: .month), y: .value("Xarajat", d.expense))
                        .foregroundStyle(Theme.Colors.expense).position(by: .value("Tur", "Xarajat"))
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .frame(height: 200)
        }
        .cardStyle()
    }

    // Sarf heatmap (soʻnggi ~15 hafta, GitHub uslubida)
    private var heatmap: some View {
        let cal = Calendar.current
        let now = Date()
        let dailyExpense: [Date: Double] = Dictionary(grouping: expenses) { $0.date.startOfDay }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let maxVal = dailyExpense.values.max() ?? 1
        let weeks = 15
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Sarf issiqlik xaritasi")
            HStack(spacing: 3) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { d in
                            let offset = (weeks - 1 - w) * 7 + (6 - d)
                            let day = cal.date(byAdding: .day, value: -offset, to: now)!.startOfDay
                            let value = dailyExpense[day] ?? 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.accent.opacity(value == 0 ? 0.08 : 0.2 + 0.8 * min(value / maxVal, 1)))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            Text("Toʻq rang — koʻproq sarf").font(.caption2).foregroundStyle(Theme.Colors.secondaryText)
        }
        .cardStyle()
    }
}
