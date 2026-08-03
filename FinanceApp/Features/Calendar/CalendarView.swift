import SwiftUI
import SwiftData

/// Kalendar koʻrinishi — kunni bosib, oʻsha kungi daromad/xarajat/balansni koʻrish.
struct CalendarView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var transactions: [Transaction]

    @State private var month = Date()
    @State private var selectedDay = Date()
    @State private var editingTransaction: Transaction?

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var days: [Date] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start) - cal.firstWeekday
        let padding = (firstWeekday + 7) % 7
        var result: [Date] = []
        // Oldingi oydan boʻsh kataklar
        for i in stride(from: padding, to: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: interval.start) { result.append(d) }
        }
        var day = interval.start
        while day < interval.end {
            result.append(day)
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    private func dayTotals(_ day: Date) -> (income: Double, expense: Double) {
        let txs = transactions.filter { cal.isDate($0.date, inSameDayAs: day) }
        return (txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                monthHeader
                weekdayHeader
                grid
                dayDetail
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Kalendar")
        .sheet(item: $editingTransaction) { AddTransactionView(transaction: $0) }
    }

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(cal.shortWeekdaySymbols, id: \.self) { s in
                Text(s).font(.caption2).foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.self) { day in
                let totals = dayTotals(day)
                let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
                VStack(spacing: 2) {
                    Text("\(cal.component(.day, from: day))")
                        .font(.callout)
                        .foregroundStyle(inMonth ? Theme.Colors.primaryText : Theme.Colors.tertiaryText)
                    HStack(spacing: 2) {
                        if totals.income > 0 { Circle().fill(Theme.Colors.income).frame(width: 5, height: 5) }
                        if totals.expense > 0 { Circle().fill(Theme.Colors.expense).frame(width: 5, height: 5) }
                    }.frame(height: 6)
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(cal.isDate(day, inSameDayAs: selectedDay) ? Theme.Colors.accent.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .onTapGesture { withAnimation { selectedDay = day } }
            }
        }
    }

    private var dayDetail: some View {
        let totals = dayTotals(selectedDay)
        let dayTx = transactions.filter { cal.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
        let netBalance = totals.income - totals.expense
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: selectedDay.formatted(.dateTime.weekday(.wide).day().month()))
            HStack {
                miniStat("Daromad", totals.income, Theme.Colors.income)
                miniStat("Xarajat", totals.expense, Theme.Colors.expense)
                miniStat("Balans", netBalance, netBalance >= 0 ? Theme.Colors.income : Theme.Colors.expense)
            }
            if dayTx.isEmpty {
                Text("Bu kunda tranzaksiya yoʻq").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical)
            } else {
                ForEach(dayTx) { tx in
                    Button {
                        editingTransaction = tx
                    } label: {
                        TransactionRow(transaction: tx)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private func miniStat(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(Theme.Colors.secondaryText)
            Text(CurrencyFormatter.compact(value, code: settings.currencyCode))
                .font(.callout.weight(.semibold)).foregroundStyle(color)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shift(_ value: Int) {
        withAnimation { month = cal.date(byAdding: .month, value: value, to: month) ?? month }
    }
}
