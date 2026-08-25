import SwiftUI
import SwiftData

/// Byudjetlar — progress, sarflangan/qolgan, prognoz, ogohlantirish.
struct BudgetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]
    @State private var showAdd = false
    @State private var editing: Budget?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if budgets.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "Byudjet yoʻq",
                                   message: "Sarflaringizni nazorat qilish uchun byudjet tuzing.",
                                   actionTitle: "Byudjet qoʻshish") { showAdd = true }
                } else {
                    ForEach(budgets) { budget in
                        budgetCard(budget).onTapGesture { editing = budget }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Byudjetlar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { BudgetEditorView() }
        .sheet(item: $editing) { BudgetEditorView(budget: $0) }
    }

    private func spent(for budget: Budget) -> Double {
        let interval = budget.currentInterval
        let names = Set((budget.categories ?? []).map { $0.name })
        return transactions
            .filter { $0.type == .expense && interval.contains($0.date) && names.contains($0.category?.name ?? "") }
            .reduce(0) { $0 + $1.amount }
    }

    /// Davr oxirigacha bashoratli sarf (chiziqli ekstrapolyatsiya).
    private func predicted(for budget: Budget, spent: Double) -> Double {
        let interval = budget.currentInterval
        let elapsed = Date().timeIntervalSince(interval.start)
        let total = interval.duration
        guard elapsed > 0, total > 0 else { return spent }
        return min(spent / elapsed * total, spent * 3)
    }

    private func budgetCard(_ budget: Budget) -> some View {
        let s = spent(for: budget)
        let progress = budget.limitAmount > 0 ? s / budget.limitAmount : 0
        let isOver = s > budget.limitAmount
        let pred = predicted(for: budget, spent: s)

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name).font(.headline)
                    Text(budget.period.title).font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                }
                Spacer()
                ProgressRing(progress: progress, color: isOver ? Theme.Colors.expense : budget.color, size: 54)
            }
            if let categories = budget.categories, !categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(categories.prefix(5)) { cat in
                        CategoryIconView(symbol: cat.symbol, color: cat.color, size: 26)
                    }
                    if categories.count > 5 {
                        Text("+\(categories.count - 5)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
            ProgressView(value: min(progress, 1))
                .tint(isOver ? Theme.Colors.expense : budget.color)
            HStack {
                label("Sarflangan", CurrencyFormatter.compact(s, code: settings.currencyCode), Theme.Colors.expense)
                Spacer()
                label("Qolgan", CurrencyFormatter.compact(max(budget.limitAmount - s, 0), code: settings.currencyCode), Theme.Colors.income)
                Spacer()
                label("Prognoz", CurrencyFormatter.compact(pred, code: settings.currencyCode), Theme.Colors.warning)
            }
            if isOver {
                Label("Byudjetdan \(CurrencyFormatter.compact(s - budget.limitAmount, code: settings.currencyCode)) oshdi",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.expense)
            } else if pred > budget.limitAmount {
                Label("Prognoz boʻyicha byudjet oshishi mumkin", systemImage: "info.circle.fill")
                    .font(.caption).foregroundStyle(Theme.Colors.warning)
            }
        }
        .cardStyle()
    }

    private func label(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(Theme.Colors.secondaryText)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color)
        }
    }
}

/// Byudjet qoʻshish/tahrirlash.
struct BudgetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortIndex) private var categories: [Category]

    private let existing: Budget?
    @State private var name = ""
    @State private var limitText = ""
    @State private var period: PeriodType = .monthly
    @State private var selected: Set<UUID> = []
    @State private var colorHex = "#FF9500"

    init(budget: Budget? = nil) { self.existing = budget }
    private var expenseCategories: [Category] { categories.filter { $0.kind == .expense } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nomi") { TextField("Masalan: Oziq-ovqat", text: $name) }
                Section("Limit") { TextField("0", text: $limitText).keyboardType(.decimalPad) }
                Section("Davr") {
                    Picker("Davr", selection: $period) {
                        ForEach(PeriodType.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Kategoriyalar") {
                    ForEach(expenseCategories) { cat in
                        Button {
                            if selected.contains(cat.id) { selected.remove(cat.id) } else { selected.insert(cat.id) }
                        } label: {
                            HStack {
                                CategoryIconView(symbol: cat.symbol, color: cat.color, size: 30)
                                Text(cat.name).foregroundStyle(Theme.Colors.primaryText)
                                Spacer()
                                if selected.contains(cat.id) {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.Colors.accent)
                                }
                            }
                        }
                    }
                }
                Section("Rang") { ColorPalettePicker(selection: $colorHex) }
            }
            .navigationTitle(existing == nil ? "Yangi byudjet" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Saqlash") { save() }.disabled(name.isEmpty) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let b = existing else { return }
        name = b.name; limitText = String(Int(b.limitAmount)); period = b.period
        colorHex = b.colorHex; selected = Set((b.categories ?? []).map { $0.id })
    }

    private func save() {
        let limit = Double(limitText.filter { $0.isNumber || $0 == "." }) ?? 0
        let cats = expenseCategories.filter { selected.contains($0.id) }
        if let b = existing {
            b.name = name; b.limitAmount = limit; b.period = period; b.colorHex = colorHex; b.categories = cats
        } else {
            context.insert(Budget(name: name, limitAmount: limit, period: period, colorHex: colorHex, categories: cats))
        }
        try? context.save()
        dismiss()
    }
}
