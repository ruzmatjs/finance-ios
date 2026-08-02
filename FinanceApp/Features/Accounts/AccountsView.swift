import SwiftUI
import SwiftData

/// Hisoblar roʻyxati — balans, qoʻshish, tahrirlash, oʻchirish.
struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.sortIndex) private var accounts: [Account]
    @State private var editing: Account?
    @State private var showAdd = false

    private var totalBalance: Double { accounts.reduce(0) { $0 + $1.currentBalance } }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Umumiy balans").font(.headline)
                    Spacer()
                    Text(CurrencyFormatter.string(totalBalance, code: settings.currencyCode))
                        .font(.headline).foregroundStyle(Theme.Colors.accent)
                }
            }
            Section {
                ForEach(accounts) { account in
                    Button { editing = account } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            CategoryIconView(symbol: account.symbol, color: account.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).font(.body.weight(.medium))
                                    .foregroundStyle(Theme.Colors.primaryText)
                                Text(account.type.title).font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            Spacer()
                            Text(CurrencyFormatter.string(account.currentBalance, code: account.currencyCode))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(account.currentBalance >= 0 ? Theme.Colors.primaryText : Theme.Colors.expense)
                        }
                    }.buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Hisoblar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AccountEditorView() }
        .sheet(item: $editing) { AccountEditorView(account: $0) }
        .overlay { if accounts.isEmpty { EmptyStateView(icon: "creditcard", title: "Hisob yoʻq", message: "Birinchi hisobingizni qoʻshing.", actionTitle: "Qoʻshish") { showAdd = true } } }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(accounts[i]) }
        try? context.save()
    }
}

/// Hisob qoʻshish/tahrirlash.
struct AccountEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let existing: Account?
    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var balanceText = ""
    @State private var colorHex = "#34C759"

    init(account: Account? = nil) { self.existing = account }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nomi") { TextField("Masalan: Naqd", text: $name) }
                Section("Turi") {
                    Picker("Turi", selection: $type) {
                        ForEach(AccountType.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                    }
                }
                Section("Boshlangʻich balans") {
                    TextField("0", text: $balanceText).keyboardType(.decimalPad)
                }
                Section("Rang") { ColorPalettePicker(selection: $colorHex) }
            }
            .navigationTitle(existing == nil ? "Yangi hisob" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Saqlash") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let a = existing else { return }
        name = a.name; type = a.type; balanceText = String(Int(a.openingBalance)); colorHex = a.colorHex
    }

    private func save() {
        let balance = Double(balanceText.filter { $0.isNumber || $0 == "." }) ?? 0
        if let a = existing {
            a.name = name; a.type = type; a.openingBalance = balance; a.colorHex = colorHex; a.symbol = type.systemImage
        } else {
            context.insert(Account(name: name, type: type, openingBalance: balance,
                                   currencyCode: settings.currencyCode, colorHex: colorHex,
                                   sortIndex: 99))
        }
        try? context.save()
        dismiss()
    }
}
