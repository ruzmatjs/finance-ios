import SwiftUI
import SwiftData
import WidgetKit

/// Tranzaksiya qoʻshish/tahrirlash oynasi.
/// - Daromad / Xarajat / Oʻtkazma segmenti
/// - AI (tabiiy til) tez kiritish maydoni
/// - Kategoriya, hisob, sana, izoh, sevimli
struct AddTransactionView: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortIndex) private var allCategories: [Category]
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    // Tahrirlanayotgan obyekt (nil boʻlsa — yangi).
    private let existing: Transaction?

    @State private var type: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var toAccount: Account?
    @State private var date = Date()
    @State private var note = ""
    @State private var merchant = ""
    @State private var isFavorite = false
    @State private var smartInput = ""
    @State private var receiptData: Data?
    @State private var isLoaded = false

    init(transaction: Transaction? = nil) {
        self.existing = transaction
    }

    private var categories: [Category] {
        allCategories.filter { $0.kind == (type == .income ? .income : .expense) }
    }
    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private var isValid: Bool { amount > 0 && (type == .transfer ? (selectedAccount != nil && toAccount != nil) : selectedAccount != nil) }

    var body: some View {
        NavigationStack {
            Form {
                typePicker
                if existing == nil { smartAddSection }
                amountSection
                if type != .transfer { categorySection } else { transferSection }
                detailsSection
                receiptSection
            }
            .navigationTitle(existing == nil ? "Yangi tranzaksiya" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Saqlash") { save() }.fontWeight(.semibold).disabled(!isValid)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: Segments
    private var typePicker: some View {
        Picker("Tur", selection: $type.animation()) {
            ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
    }

    // MARK: AI Smart add
    private var smartAddSection: some View {
        Section {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(Theme.Colors.accent)
                TextField("Masalan: \"Taxi 35000\"", text: $smartInput)
                    .onSubmit(applySmartInput)
                if !smartInput.isEmpty {
                    Button("Tahlil") { applySmartInput() }.font(.caption.weight(.semibold))
                }
            }
        } footer: {
            Text("Aqlli kiritish: summa, kategoriya va turni matndan avtomatik aniqlaydi.")
        }
    }

    private var amountSection: some View {
        Section("Summa") {
            HStack {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(Theme.Font.largeAmount)
                    .foregroundStyle(type == .income ? Theme.Colors.income : (type == .expense ? Theme.Colors.expense : Theme.Colors.transfer))
                Text(CurrencyFormatter.symbol(for: settings.currencyCode))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    private var categorySection: some View {
        Section("Kategoriya") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(categories) { cat in
                        VStack(spacing: 6) {
                            CategoryIconView(symbol: cat.symbol, color: cat.color,
                                             size: selectedCategory?.id == cat.id ? 52 : 46)
                            Text(cat.name).font(.caption2).lineLimit(1)
                        }
                        .frame(width: 64)
                        .opacity(selectedCategory == nil || selectedCategory?.id == cat.id ? 1 : 0.5)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
                            container?.haptics.selection()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var transferSection: some View {
        Section("Oʻtkazma") {
            Picker("Qayerdan", selection: $selectedAccount) {
                Text("Tanlang").tag(Account?.none)
                ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
            }
            Picker("Qayerga", selection: $toAccount) {
                Text("Tanlang").tag(Account?.none)
                ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
            }
        }
    }

    private var detailsSection: some View {
        Section("Tafsilotlar") {
            if type != .transfer {
                Picker("Hisob", selection: $selectedAccount) {
                    Text("Tanlang").tag(Account?.none)
                    ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
                }
            }
            DatePicker("Sana", selection: $date, displayedComponents: [.date, .hourAndMinute])
            TextField("Merchant (ixtiyoriy)", text: $merchant)
            TextField("Izoh", text: $note, axis: .vertical).lineLimit(1...3)
            Toggle("Sevimli", isOn: $isFavorite)
        }
    }

    private var receiptSection: some View {
        Section("Chek rasmi") {
            ReceiptPicker(data: $receiptData)
        }
    }

    // MARK: Logic
    private func applySmartInput() {
        guard let result = NaturalLanguageParser().parse(smartInput, defaultCurrency: settings.currencyCode) else { return }
        withAnimation {
            type = result.type
            amountText = String(Int(result.amount))
            if let hint = result.categoryHint {
                selectedCategory = allCategories.first { $0.name == hint }
            }
            if let m = result.merchant { merchant = m }
        }
        container?.haptics.notify(.success)
    }

    private func loadExisting() {
        if selectedAccount == nil { selectedAccount = accounts.first }
        guard !isLoaded else { return }
        isLoaded = true
        guard let tx = existing else { return }
        type = tx.type
        amountText = tx.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(tx.amount)) : String(tx.amount)
        selectedCategory = tx.category
        selectedAccount = tx.account
        toAccount = tx.toAccount
        date = tx.date
        note = tx.note
        merchant = tx.merchant
        isFavorite = tx.isFavorite
        receiptData = tx.receiptImage
    }

    private func save() {
        let repo: FinanceRepositoryProtocol = container?.repository ?? FinanceRepository(context: modelContext)
        if let tx = existing {
            tx.type = type
            tx.amount = amount
            tx.category = type == .transfer ? nil : selectedCategory
            tx.account = selectedAccount
            tx.toAccount = type == .transfer ? toAccount : nil
            tx.date = date
            tx.note = note
            tx.merchant = merchant
            tx.isFavorite = isFavorite
            tx.receiptImage = receiptData
            tx.hasReceipt = receiptData != nil
            repo.save()
        } else {
            let tx = Transaction(type: type, amount: amount, date: date, note: note,
                                 merchant: merchant,
                                 category: type == .transfer ? nil : selectedCategory,
                                 account: selectedAccount,
                                 toAccount: type == .transfer ? toAccount : nil,
                                 currencyCode: settings.currencyCode)
            tx.isFavorite = isFavorite
            tx.receiptImage = receiptData
            tx.hasReceipt = receiptData != nil
            repo.add(tx)
        }
        container?.haptics.notify(.success)
        WidgetCenter.shared.reloadAllTimelines()

        // Xarajat qoʻshilgach byudjet ostonasi buzilganini tekshiramiz.
        if type == .expense && settings.notificationsEnabled {
            BudgetAlertService.evaluate(context: modelContext, currency: settings.currencyCode)
        }

        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
}
