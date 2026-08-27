import SwiftUI
import SwiftData

/// Qarzlar (Berdilar / Oldilar) — monitoring, qisman toʻlash, sana kiritish va Telegram orqali ulashish.
struct DebtsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.container) private var container
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    @Query(sort: \Debt.date, order: .reverse) private var allDebts: [Debt]
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    @State private var selectedFilter: DebtFilter = .lend
    @State private var showAddSheet = false
    @State private var editingDebt: Debt?
    @State private var repayingDebt: Debt?

    enum DebtFilter: String, CaseIterable, Identifiable {
        case lend, borrow, settled
        var id: String { rawValue }
        var title: String {
            switch self {
            case .lend: return "Mendan olganlar"
            case .borrow: return "Men olganlar"
            case .settled: return "Yopilganlar"
            }
        }
    }

    private var activeDebts: [Debt] { allDebts.filter { !$0.isSettled } }
    private var totalLent: Double {
        activeDebts.filter { $0.type == .lend }.reduce(0) { $0 + $1.remaining }
    }
    private var totalBorrowed: Double {
        activeDebts.filter { $0.type == .borrow }.reduce(0) { $0 + $1.remaining }
    }
    private var netDebt: Double { totalLent - totalBorrowed }

    private var filteredDebts: [Debt] {
        switch selectedFilter {
        case .lend:
            return allDebts.filter { $0.type == .lend && !$0.isSettled }
        case .borrow:
            return allDebts.filter { $0.type == .borrow && !$0.isSettled }
        case .settled:
            return allDebts.filter { $0.isSettled }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Umumiy koʻrsatkichlar kartochkasi
                summaryGrid

                // Segment filtri
                Picker("Filtr", selection: $selectedFilter.animation()) {
                    Text("🟢 Berilgan (\(allDebts.filter { $0.type == .lend && !$0.isSettled }.count))").tag(DebtFilter.lend)
                    Text("🔴 Olingan (\(allDebts.filter { $0.type == .borrow && !$0.isSettled }.count))").tag(DebtFilter.borrow)
                    Text("✓ Yopilgan (\(allDebts.filter { $0.isSettled }.count))").tag(DebtFilter.settled)
                }
                .pickerStyle(.segmented)

                if filteredDebts.isEmpty {
                    EmptyStateView(
                        icon: "hand.raised.fill",
                        title: "Qarzlar yoʻq",
                        message: selectedFilter == .lend ? "Sizdan qarz olganlar roʻyxati boʻsh." :
                            (selectedFilter == .borrow ? "Siz olgan qarzlar mavjud emas." : "Yopilgan qarzlar tarixi boʻsh."),
                        actionTitle: "Qarz qoʻshish"
                    ) {
                        showAddSheet = true
                    }
                } else {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredDebts) { debt in
                            debtCard(debt)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 120)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Qarzlar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DebtEditorView(initialType: selectedFilter == .borrow ? .borrow : .lend)
        }
        .sheet(item: $editingDebt) { debt in
            DebtEditorView(debt: debt)
        }
        .sheet(item: $repayingDebt) { debt in
            DebtRepaySheet(debt: debt)
        }
    }

    // MARK: - Summary Grid
    private var summaryGrid: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mendan olishgan")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text("+\(CurrencyFormatter.string(totalLent, code: settings.currencyCode))")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Theme.Colors.income)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Men olganman")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text("−\(CurrencyFormatter.string(totalBorrowed, code: settings.currencyCode))")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Theme.Colors.expense)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }

            HStack {
                Text("Sof qarz holati:")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                Text(CurrencyFormatter.signed(netDebt, code: settings.currencyCode))
                    .font(.subheadline.bold())
                    .foregroundStyle(netDebt >= 0 ? Theme.Colors.income : Theme.Colors.expense)
            }
            .cardStyle()
        }
    }

    // MARK: - Debt Card
    private func debtCard(_ debt: Debt) -> some View {
        let isLend = debt.type == .lend
        let isSettled = debt.isSettled
        let color = isSettled ? Theme.Colors.secondaryText : (isLend ? Theme.Colors.income : Theme.Colors.expense)

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: isLend ? "person.crop.circle.badge.plus" : "person.crop.circle.badge.minus")
                    .font(.title2)
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.person)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.primaryText)

                    HStack(spacing: 4) {
                        if let acc = debt.account {
                            Text(acc.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                        Text("🗓 \(isLend ? "Berildi" : "Olindi"): \(debt.date.formatted(.dateTime.day().month()))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        if let due = debt.dueDate {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text("⏳ Muddat: \(due.formatted(.dateTime.day().month()))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.warning)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(isSettled ? "✓ Yopildi" : CurrencyFormatter.string(debt.remaining, code: settings.currencyCode))
                        .font(.headline)
                        .foregroundStyle(color)

                    if debt.paid > 0 && !isSettled {
                        Text("Jami: \(CurrencyFormatter.compact(debt.amount, code: settings.currencyCode))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }

            if !debt.note.isEmpty {
                Text(debt.note)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.top, 2)
            }

            // Progress bar (qisman qaytarilgan bo'lsa)
            if debt.paid > 0 && !isSettled {
                VStack(spacing: 4) {
                    ProgressView(value: debt.progress)
                        .tint(color)
                    HStack {
                        Text("Qaytarildi: \(CurrencyFormatter.compact(debt.paid, code: settings.currencyCode)) (\(Int(debt.progress * 100))%)")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                        Text("Qoldi: \(CurrencyFormatter.compact(debt.remaining, code: settings.currencyCode))")
                            .font(.caption2.bold())
                            .foregroundStyle(color)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider().padding(.vertical, 4)

            // Pastki tugmalar: Qaytarish, Telegram forward, Tahrirlash
            HStack {
                if !isSettled {
                    Button {
                        repayingDebt = debt
                    } label: {
                        Label(isLend ? "Qaytarib oldim" : "Qaytarib berdim",
                              systemImage: isLend ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .buttonBorderShape(.capsule)
                } else {
                    Label("Toʻliq qaytarilgan", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.income)
                }

                // Telegram orqali yuborish
                Button {
                    forwardToTelegram(debt)
                } label: {
                    Label("Telegram", systemImage: "paperplane.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.accent)
                .buttonBorderShape(.capsule)

                Spacer()

                Button("Tahrirlash ›") {
                    editingDebt = debt
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .cardStyle()
    }

    private func forwardToTelegram(_ debt: Debt) {
        container?.haptics.impact(.medium)
        if let url = TelegramService.debtShareURL(
            person: debt.person,
            amount: debt.amount,
            paid: debt.paid,
            type: debt.type,
            isSettled: debt.isSettled,
            date: debt.date,
            dueDate: debt.dueDate,
            currency: settings.currencyCode,
            note: debt.note.isEmpty ? nil : debt.note
        ) {
            openURL(url)
        }
    }
}

// MARK: - Qarz tahrirlash / qoʻshish oynasi
struct DebtEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    private let existing: Debt?
    private let initialType: DebtType

    @State private var type: DebtType = .lend
    @State private var person = ""
    @State private var amountText = ""
    @State private var selectedAccount: Account?
    @State private var date = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400 * 30)
    @State private var note = ""

    init(debt: Debt? = nil, initialType: DebtType = .lend) {
        self.existing = debt
        self.initialType = initialType
    }

    private var isValid: Bool {
        !person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Qarz turi", selection: $type) {
                        Text("🟢 Men berdim (Mendan olishdi)").tag(DebtType.lend)
                        Text("🔴 Men oldim (Menga berishdi)").tag(DebtType.borrow)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Shaxs va Summa") {
                    TextField("Shaxs (Kimga / Kimdan)", text: $person)
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.Font.amount)
                            .foregroundStyle(type == .lend ? Theme.Colors.income : Theme.Colors.expense)
                        Text(CurrencyFormatter.symbol(for: settings.currencyCode))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Section("Sana va Hisob") {
                    DatePicker(type == .lend ? "Qarz berilgan sana" : "Qarz olingan sana",
                               selection: $date, displayedComponents: .date)

                    Picker(type == .lend ? "Qaysi hisobdan berildi" : "Qaysi hisobga qabul qilindi",
                           selection: $selectedAccount) {
                        Text("Tanlang").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(Account?.some(acc))
                        }
                    }
                }

                Section("Qaytarish muddati") {
                    Toggle("Muddat belgilash", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Qaytarish sanasi", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Izoh") {
                    TextField("Ixtiyoriy izoh", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                if existing != nil {
                    Section {
                        Button {
                            forwardCurrentToTelegram()
                        } label: {
                            Label("Telegram orqali yuborish", systemImage: "paperplane.fill")
                                .foregroundStyle(Theme.Colors.accent)
                        }

                        Button(role: .destructive) {
                            deleteCurrent()
                        } label: {
                            Label("Qarzni oʻchirish", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Yangi qarz" : "Qarzni tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Saqlash") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if selectedAccount == nil { selectedAccount = accounts.first }
        guard let d = existing else {
            type = initialType
            return
        }
        type = d.type
        person = d.person
        amountText = String(Int(d.amount))
        selectedAccount = d.account
        date = d.date
        note = d.note
        if let due = d.dueDate {
            hasDueDate = true
            dueDate = due
        }
    }

    private func save() {
        let amt = Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
        let cleanPerson = person.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let txType: TransactionType = type == .lend ? .expense : .income

        if let d = existing {
            d.type = type
            d.person = cleanPerson
            d.amount = amt
            d.account = selectedAccount
            d.date = date
            d.dueDate = hasDueDate ? dueDate : nil
            d.note = cleanNote
            if d.paid >= d.amount { d.status = .settled } else { d.status = .active }

            if let tx = d.transaction {
                tx.amount = amt
                tx.type = txType
                tx.account = selectedAccount
                tx.merchant = cleanPerson
                tx.date = date
                tx.note = type == .lend ? "Qarz berildi: \(cleanPerson)" : "Qarz olindi: \(cleanPerson)"
                if !cleanNote.isEmpty { tx.note += " (\(cleanNote))" }
            }
        } else {
            let txNote = type == .lend ? "Qarz berildi: \(cleanPerson)" : "Qarz olindi: \(cleanPerson)"
            let finalNote = cleanNote.isEmpty ? txNote : "\(txNote) (\(cleanNote))"

            let tx = Transaction(
                type: txType,
                amount: amt,
                date: date,
                note: finalNote,
                merchant: cleanPerson,
                account: selectedAccount,
                currencyCode: settings.currencyCode
            )
            context.insert(tx)

            let newDebt = Debt(
                person: cleanPerson,
                amount: amt,
                paid: 0,
                type: type,
                status: .active,
                date: date,
                dueDate: hasDueDate ? dueDate : nil,
                note: cleanNote,
                account: selectedAccount,
                transaction: tx
            )
            context.insert(newDebt)
        }

        try? context.save()
        dismiss()
    }

    private func deleteCurrent() {
        guard let d = existing else { return }
        if let tx = d.transaction { context.delete(tx) }
        context.delete(d)
        try? context.save()
        dismiss()
    }

    private func forwardCurrentToTelegram() {
        guard let d = existing else { return }
        if let url = TelegramService.debtShareURL(
            person: d.person,
            amount: d.amount,
            paid: d.paid,
            type: d.type,
            isSettled: d.isSettled,
            date: d.date,
            dueDate: d.dueDate,
            currency: settings.currencyCode,
            note: d.note.isEmpty ? nil : d.note
        ) {
            openURL(url)
        }
    }
}

// MARK: - Qarzni qaytarish (qisman/toʻliq) oynasi
struct DebtRepaySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    let debt: Debt
    @State private var amountText: String = ""
    @State private var selectedAccount: Account?

    private var isLend: Bool { debt.type == .lend }
    private var repayAmount: Double {
        Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Qolgan umumiy qarz:")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                        Text(CurrencyFormatter.string(debt.remaining, code: settings.currencyCode))
                            .font(.headline)
                            .foregroundStyle(isLend ? Theme.Colors.income : Theme.Colors.expense)
                    }
                }

                Section("Qaytarilayotgan summa") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.Font.amount)
                            .foregroundStyle(isLend ? Theme.Colors.income : Theme.Colors.expense)
                        Text(CurrencyFormatter.symbol(for: settings.currencyCode))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Section(isLend ? "Qaysi hisobga qabul qilindi" : "Qaysi hisobdan toʻlandi") {
                    Picker("Hisob", selection: $selectedAccount) {
                        Text("Tanlang").tag(Account?.none)
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(Account?.some(acc))
                        }
                    }
                }
            }
            .navigationTitle(isLend ? "Qarzni qaytarib olish" : "Qarzni qaytarib berish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLend ? "Qabul qilish" : "Toʻlash") {
                        saveRepay()
                    }
                    .fontWeight(.semibold)
                    .disabled(repayAmount <= 0)
                }
            }
            .onAppear {
                amountText = String(Int(debt.remaining))
                selectedAccount = debt.account ?? accounts.first
            }
        }
        .presentationDetents([.height(340)])
    }

    private func saveRepay() {
        guard repayAmount > 0 else { return }

        debt.paid += repayAmount
        if debt.paid >= debt.amount {
            debt.status = .settled
        }

        let txType: TransactionType = isLend ? .income : .expense
        let txNote = isLend ? "Qarz qaytarildi: \(debt.person)" : "Qarz toʻlandi: \(debt.person)"

        let tx = Transaction(
            type: txType,
            amount: repayAmount,
            date: Date(),
            note: txNote,
            merchant: debt.person,
            account: selectedAccount,
            currencyCode: settings.currencyCode
        )
        context.insert(tx)

        try? context.save()
        dismiss()
    }
}
