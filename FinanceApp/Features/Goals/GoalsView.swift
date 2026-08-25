import SwiftUI
import SwiftData

/// Jamgʻarma maqsadlari — animatsion progress, pul qoʻshish.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @State private var showAdd = false
    @State private var editing: Goal?
    @State private var contributing: Goal?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                ForEach(goals) { goal in
                    goalCard(goal)
                        .onTapGesture { editing = goal }
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Maqsadlar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .overlay { if goals.isEmpty { EmptyStateView(icon: "target", title: "Maqsad yoʻq", message: "Sayohat, mashina yoki texnika uchun jamgʻarma boshlang.", actionTitle: "Maqsad qoʻshish") { showAdd = true } } }
        .sheet(isPresented: $showAdd) { GoalEditorView() }
        .sheet(item: $editing) { GoalEditorView(goal: $0) }
        .sheet(item: $contributing) { goal in ContributeSheet(goal: goal) }
    }

    private func goalCard(_ goal: Goal) -> some View {
        let sym = goal.symbol.isEmpty ? "target" : goal.symbol
        return VStack(spacing: Theme.Spacing.sm) {
            ProgressRing(progress: goal.progress, color: goal.color, lineWidth: 8, size: 92) {
                VStack(spacing: 4) {
                    Image(systemName: sym)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(goal.color)
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
            }
            Text(goal.name).font(.callout.weight(.semibold)).lineLimit(1)
            Text("\(CurrencyFormatter.compact(goal.currentAmount, code: settings.currencyCode)) / \(CurrencyFormatter.compact(goal.targetAmount, code: settings.currencyCode))")
                .font(.caption).foregroundStyle(Theme.Colors.secondaryText)
            Button {
                contributing = goal
            } label: {
                Label("Qoʻshish", systemImage: "plus.circle.fill").font(.caption.weight(.semibold))
            }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(goal.color)
            if goal.isCompleted {
                Label("Bajarildi!", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(Theme.Colors.income)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

/// Maqsadga pul qoʻshish oynasi.
struct ContributeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Qancha qoʻshasiz?") {
                    TextField("0", text: $amountText).keyboardType(.decimalPad).font(Theme.Font.amount)
                }
            }
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Qoʻshish") {
                        let a = Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
                        withAnimation(.spring) { goal.currentAmount += a }
                        try? context.save(); dismiss()
                    }
                }
            }
            .presentationDetents([.height(220)])
        }
    }
}

/// Maqsad qoʻshish/tahrirlash.
struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let existing: Goal?
    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = ""
    @State private var symbol = "target"
    @State private var colorHex = "#5856D6"
    @State private var hasDeadline = false
    @State private var targetDate = Date().addingTimeInterval(60*60*24*90)

    init(goal: Goal? = nil) { self.existing = goal }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ProgressRing(progress: 0.65, color: Color(hex: colorHex), lineWidth: 8, size: 84) {
                            VStack(spacing: 4) {
                                Image(systemName: symbol.isEmpty ? "target" : symbol)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Color(hex: colorHex))
                                Text("65%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.primaryText)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Nomi") { TextField("Masalan: Yangi mashina", text: $name) }
                Section("Maqsad summasi") { TextField("0", text: $targetText).keyboardType(.decimalPad) }
                Section("Hozirgi jamgʻarma") { TextField("0", text: $currentText).keyboardType(.decimalPad) }
                Section("Muddat") {
                    Toggle("Muddat belgilash", isOn: $hasDeadline)
                    if hasDeadline { DatePicker("Sana", selection: $targetDate, displayedComponents: .date) }
                }
                Section("Ikonka") { SymbolPicker(selection: $symbol) }
                Section("Rang") { ColorPalettePicker(selection: $colorHex) }
            }
            .navigationTitle(existing == nil ? "Yangi maqsad" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Saqlash") { save() }.disabled(name.isEmpty) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let g = existing else { return }
        name = g.name; targetText = String(Int(g.targetAmount)); currentText = String(Int(g.currentAmount))
        symbol = g.symbol; colorHex = g.colorHex
        if let d = g.targetDate { hasDeadline = true; targetDate = d }
    }

    private func save() {
        let target = Double(targetText.filter { $0.isNumber || $0 == "." }) ?? 0
        let current = Double(currentText.filter { $0.isNumber || $0 == "." }) ?? 0
        if let g = existing {
            g.name = name; g.targetAmount = target; g.currentAmount = current
            g.symbol = symbol; g.colorHex = colorHex; g.targetDate = hasDeadline ? targetDate : nil
        } else {
            context.insert(Goal(name: name, targetAmount: target, currentAmount: current,
                                symbol: symbol, colorHex: colorHex,
                                targetDate: hasDeadline ? targetDate : nil))
        }
        try? context.save()
        dismiss()
    }
}
