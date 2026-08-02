import WidgetKit
import SwiftUI

// MARK: - Entry & Provider

struct TodaySpendingEntry: TimelineEntry {
    let date: Date
    let amount: Double
    let currency: String
}

struct TodaySpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySpendingEntry {
        TodaySpendingEntry(date: .now, amount: 125_000, currency: "UZS")
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySpendingEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySpendingEntry>) -> Void) {
        let entry = makeEntry()
        // Har 30 daqiqada yangilanadi.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> TodaySpendingEntry {
        TodaySpendingEntry(date: .now,
                           amount: FinanceStore.todaySpending(),
                           currency: FinanceStore.currencyCode())
    }
}

// MARK: - View

struct TodaySpendingWidgetView: View {
    var entry: TodaySpendingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill")
                Text("Bugungi sarf")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(CurrencyFormatter.string(entry.amount, code: entry.currency))
                .font(.system(family == .systemSmall ? .title3 : .title, design: .rounded).bold())
                .foregroundStyle(Theme.Colors.expense)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(entry.date.formatted(.dateTime.weekday(.wide).day().month()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Theme.Colors.card }
        .widgetURL(URL(string: "financeapp://add"))
    }
}

// MARK: - Configuration

struct TodaySpendingWidget: Widget {
    let kind = "TodaySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySpendingProvider()) { entry in
            TodaySpendingWidgetView(entry: entry)
        }
        .configurationDisplayName("Bugungi sarf")
        .description("Bugun qancha sarflaganingizni koʻrsatadi.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
