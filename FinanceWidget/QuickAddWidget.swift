import WidgetKit
import SwiftUI

// MARK: - Provider (statik — maʼlumot kerak emas)

struct QuickAddEntry: TimelineEntry { let date: Date }

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

// MARK: - View

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: family == .systemSmall ? 34 : 40, weight: .semibold))
                .foregroundStyle(.white)
            Text("Tez qoʻshish")
                .font(.headline)
                .foregroundStyle(.white)
            if family != .systemSmall {
                Text("Yangi xarajat yoki daromad")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(hex: "#5E5CE6"), Color(hex: "#0A84FF")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        // Bosilganda ilova "Tez qoʻshish" oynasi bilan ochiladi.
        .widgetURL(URL(string: "financeapp://add"))
    }
}

// MARK: - Configuration

struct QuickAddWidget: Widget {
    let kind = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Tez qoʻshish")
        .description("Bir bosishda yangi tranzaksiya qoʻshish.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
