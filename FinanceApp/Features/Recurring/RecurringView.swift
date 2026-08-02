import SwiftUI
import SwiftData

/// Takrorlanuvchi toʻlovlar — maosh, ijara, obunalar (Netflix, Gym...).
struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RecurringTransaction.nextDueDate) private var rules: [RecurringTransaction]
    @State private var showAdd = false
    @State private var editing: RecurringTransaction?

    var body: some View {
        List {
            ForEach(rules) { rule in
                Button { editing = rule } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        CategoryIconView(symbol: rule.category?.symbol ?? "arrow.triangle.2.circlepath",
                                         color: rule.category?.color ?? Theme.Colors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.title).font(.body.weight(.medium)).foregroundStyle(Theme.Colors.primaryText)
                            Text("\(rule.period.title) · keyingi: \(rule.nextDueDate.formatted(.dateTime.day().month()))")
                                .font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                        }
                        Spacer()
                        AmountText(amount: rule.amount, currencyCode: settings.currencyCode,
                                   type: rule.type, font: .callout.weight(.semibold))
                    }
                }.buttonStyle(.plain)
            }
            .onDelete { for i in $0 { context.delete(rules[i]) }; try? context.save() }
        }
        .navigationTitle("Takrorlanuvchi")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } }
        }
        .overlay { if rules.isEmpty { EmptyStateView(icon: "arrow.triangle.2.circlepath", title: "Takrorlanuvchi toʻlov yoʻq", message: "Maosh, ijara yoki obunalarni avtomatlashtiring.", actionTitle: "Qoʻshish") { showAdd = true } } }
        .sheet(isPresented: $showAdd) { RecurringEditorView() }
        .sheet(item: $editing) { RecurringEditorView(rule: $0) }
    }
}

/// Takrorlanuvchi qoida qoʻshish/tahrirlash.
struct RecurringEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    private let existing: RecurringTransaction?
    @State private var title = ""
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var period: PeriodType = .monthly
    @State private var startDate = Date()
    @State private var category: Category?
    @State private var account: Account?

    init(rule: RecurringTransaction? = nil) { self.existing = rule }
    private var pickCategories: [Category] { categories.filter { $0.kind == (type == .income ? .income : .expense) } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nomi") { TextField("Masalan: Netflix", text: $title) }
                Section {
                    Picker("Tur", selection: $type) {
                        Text("Xarajat").tag(TransactionType.expense)
                        Text("Daromad").tag(TransactionType.income)
                    }.pickerStyle(.segmented)
                    TextField("Summa", text: $amountText).keyboardType(.decimalPad)
                }
                Section("Takrorlanish") {
                    Picker("Davr", selection: $period) {
                        ForEach(PeriodType.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Boshlanish", selection: $startDate, displayedComponents: .date)
                }
                Section {
                    Picker("Kategoriya", selection: $category) {
                        Text("Yoʻq").tag(Category?.none)
                        ForEach(pickCategories) { Text($0.name).tag(Category?.some($0)) }
                    }
                    Picker("Hisob", selection: $account) {
                        Text("Yoʻq").tag(Account?.none)
                        ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Yangi qoida" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Saqlash") { save() }.disabled(title.isEmpty) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        account = account ?? accounts.first
        guard let r = existing else { return }
        title = r.title; type = r.type; amountText = String(Int(r.amount))
        period = r.period; startDate = r.startDate; category = r.category; account = r.account
    }

    private func save() {
        let amount = Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
        if let r = existing {
            r.title = title; r.type = type; r.amount = amount; r.period = period
            r.startDate = startDate; r.category = category; r.account = account
        } else {
            context.insert(RecurringTransaction(title: title, type: type, amount: amount,
                                                period: period, startDate: startDate,
                                                category: category, account: account))
        }
        try? context.save()
        dismiss()
    }
}
