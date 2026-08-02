import WidgetKit
import SwiftUI

// MARK: - Entry & Provider

struct BudgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FinanceStore.BudgetSnapshot?
    let currency: String
}

struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now,
                    snapshot: .init(name: "Oziq-ovqat", limit: 2_000_000, spent: 1_250_000),
                    currency: "UZS")
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> BudgetEntry {
        BudgetEntry(date: .now, snapshot: FinanceStore.primaryBudget(), currency: FinanceStore.currencyCode())
    }
}

// MARK: - View

struct RemainingBudgetWidgetView: View {
    var entry: BudgetEntry

    var body: some View {
        Group {
            if let s = entry.snapshot {
                HStack(spacing: 14) {
                    ProgressRing(progress: s.progress,
                                 color: s.isOver ? Theme.Colors.expense : Theme.Colors.warning,
                                 size: 66)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("Qolgan").font(.caption2).foregroundStyle(.secondary)
                        Text(CurrencyFormatter.string(s.remaining, code: entry.currency))
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(s.isOver ? Theme.Colors.expense : Theme.Colors.income)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        if s.isOver {
                            Label("Byudjetdan oshdi", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.expense)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar").font(.title2).foregroundStyle(.secondary)
                    Text("Byudjet yoʻq").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Theme.Colors.card }
    }
}

// MARK: - Configuration

struct RemainingBudgetWidget: Widget {
    let kind = "RemainingBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            RemainingBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Qolgan byudjet")
        .description("Asosiy byudjetingizdan qolgan mablagʻ.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
