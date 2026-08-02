import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Preset

/// Widgetdagi bitta tez-xarajat tugmasi konfiguratsiyasi.
private struct QuickPreset: Identifiable {
    let id = UUID()
    let label: String
    let category: String
    let amount: Double
    let symbol: String
    let color: Color
}

private let quickPresets: [QuickPreset] = [
    .init(label: "Kofe", category: "Cafe", amount: 25_000, symbol: "cup.and.saucer.fill", color: .orange),
    .init(label: "Taksi", category: "Taxi", amount: 20_000, symbol: "car.fill", color: .yellow),
    .init(label: "Ovqat", category: "Food", amount: 50_000, symbol: "fork.knife", color: .red),
    .init(label: "Transport", category: "Transport", amount: 5_000, symbol: "bus.fill", color: .blue)
]

// MARK: - Entry & Provider

struct QuickExpenseEntry: TimelineEntry {
    let date: Date
    let todaySpending: Double
    let currency: String
}

struct QuickExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickExpenseEntry {
        QuickExpenseEntry(date: .now, todaySpending: 95_000, currency: "UZS")
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickExpenseEntry) -> Void) {
        completion(makeEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickExpenseEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }
    private func makeEntry() -> QuickExpenseEntry {
        QuickExpenseEntry(date: .now,
                          todaySpending: FinanceStore.todaySpending(),
                          currency: FinanceStore.currencyCode())
    }
}

// MARK: - View

struct QuickExpenseWidgetView: View {
    var entry: QuickExpenseEntry
    @Environment(\.widgetFamily) private var family

    private var visiblePresets: [QuickPreset] {
        family == .systemSmall ? Array(quickPresets.prefix(4)) : quickPresets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if family == .systemSmall {
                // 2×2 grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(visiblePresets) { presetButton($0) }
                }
            } else {
                // Bir qatorda
                HStack(spacing: 10) {
                    ForEach(visiblePresets) { presetButton($0) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Theme.Colors.card }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Bugungi sarf").font(.caption2).foregroundStyle(.secondary)
                Text(CurrencyFormatter.compact(entry.todaySpending, code: entry.currency))
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Theme.Colors.expense)
            }
            Spacer()
            // Boʻsh joyni bosish ilovani "Tez qoʻshish" bilan ochadi.
            Link(destination: URL(string: "financeapp://add")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    /// Interaktiv tugma — bosilganda `QuickExpenseIntent` fon rejimida ishlaydi.
    private func presetButton(_ preset: QuickPreset) -> some View {
        Button(intent: QuickExpenseIntent(amount: preset.amount, categoryName: preset.category)) {
            VStack(spacing: 3) {
                Image(systemName: preset.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(preset.color)
                Text(preset.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryText)
                Text(CurrencyFormatter.compact(preset.amount, code: entry.currency))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(preset.color.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Configuration

struct QuickExpenseWidget: Widget {
    let kind = "QuickExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickExpenseProvider()) { entry in
            QuickExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("Tez xarajat (tugmali)")
        .description("Bir bosishda tez-tez uchraydigan xarajatlarni yozing.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
