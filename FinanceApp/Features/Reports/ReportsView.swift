import SwiftUI
import SwiftData
import Charts

/// Hisobot turi tanlovi
enum ReportTypeFilter: String, CaseIterable, Identifiable {
    case expense, income, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expense: return "🔴 Xarajat"
        case .income: return "🟢 Daromad"
        case .all: return "⚖️ Barchasi (Sof)"
        }
    }
}

/// Hisobotlar — davr va sana tanlash, AI tahlil, naqd/yirik bitimlar filtri, kategoriya taqsimoti.
struct ReportsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var transactions: [Transaction]
    @Query private var allCategories: [Category]

    @State private var range: ReportRange = .month
    @State private var typeFilter: ReportTypeFilter = .expense
    @State private var selectedDate: Date = Date()
    
    @State private var excludeCash: Bool = false
    @State private var excludeLarge: Bool = false
    @State private var largeThreshold: Double = 5_000_000
    @State private var selectedCategories: Set<String> = []
    
    @State private var exportFile: ExportFile?
    @State private var showDatePicker: Bool = false

    private var interval: DateInterval {
        let cal = Calendar.current
        switch range {
        case .day:
            let st = cal.startOfDay(for: selectedDate)
            let en = cal.date(byAdding: .day, value: 1, to: st)!.addingTimeInterval(-1)
            return DateInterval(start: st, end: en)
        case .week:
            let st = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
            let en = cal.date(byAdding: .day, value: 7, to: st)!.addingTimeInterval(-1)
            return DateInterval(start: st, end: en)
        case .month:
            let comp = cal.dateComponents([.year, .month], from: selectedDate)
            let st = cal.date(from: comp) ?? selectedDate
            let en = cal.date(byAdding: .month, value: 1, to: st)!.addingTimeInterval(-1)
            return DateInterval(start: st, end: en)
        case .year:
            let comp = cal.dateComponents([.year], from: selectedDate)
            let st = cal.date(from: comp) ?? selectedDate
            let en = cal.date(byAdding: .year, value: 1, to: st)!.addingTimeInterval(-1)
            return DateInterval(start: st, end: en)
        }
    }

    private var intervalTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uz_UZ")
        switch range {
        case .day:
            formatter.dateFormat = "d-MMMM, yyyy"
            return formatter.string(from: selectedDate)
        case .week:
            formatter.dateFormat = "d-MMM"
            let stStr = formatter.string(from: interval.start)
            formatter.dateFormat = "d-MMM, yyyy"
            let enStr = formatter.string(from: interval.end)
            return "\(stStr) — \(enStr)"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: selectedDate).capitalized
        case .year:
            formatter.dateFormat = "yyyy'-yil'"
            return formatter.string(from: selectedDate)
        }
    }

    /// Davr ichidagi va filtrlardan oʻtgan barcha tranzaksiyalar
    private var filteredInPeriod: [Transaction] {
        transactions.filter { tx in
            guard interval.contains(tx.date) else { return false }
            if excludeCash {
                let accName = tx.account?.name.lowercased() ?? ""
                if tx.account?.type == .cash || accName.contains("naqd") { return false }
            }
            if excludeLarge {
                if tx.amount >= largeThreshold { return false }
            }
            return true
        }
    }

    /// Kategoriya filtri ham qoʻllangan tranzaksiyalar
    private var categoryFilteredInPeriod: [Transaction] {
        filteredInPeriod.filter { tx in
            if !selectedCategories.isEmpty {
                let catName = tx.category?.name ?? "Boshqa"
                if !selectedCategories.contains(catName) { return false }
            }
            return true
        }
    }

    private var scoped: [Transaction] {
        categoryFilteredInPeriod.filter { tx in
            switch typeFilter {
            case .expense: return tx.type == .expense
            case .income: return tx.type == .income
            case .all: return tx.type == .expense || tx.type == .income
            }
        }
    }

    /// Kategoriya boʻyicha yigʻindi.
    private var byCategory: [(name: String, amount: Double, color: Color)] {
        let groups = Dictionary(grouping: scoped) { $0.category?.name ?? "Boshqa" }
        return groups.map { key, txs in
            (name: key,
             amount: txs.reduce(0) { $0 + $1.amount },
             color: txs.first?.category?.color ?? Theme.Colors.secondaryText)
        }.sorted { $0.amount > $1.amount }
    }

    private var totalIncome: Double {
        categoryFilteredInPeriod.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        categoryFilteredInPeriod.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { totalIncome - totalExpense }

    private var currentTypeTotal: Double {
        switch typeFilter {
        case .expense: return totalExpense
        case .income: return totalIncome
        case .all: return totalIncome + totalExpense
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Turlar segmenti
                Picker("Tur", selection: $typeFilter) {
                    ForEach(ReportTypeFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                // Davr segmenti
                Picker("Davr", selection: $range) {
                    ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                // Navigatsiya kartochkasi (Oldingi / Aniq Sana / Keyingi)
                periodNavigationCard

                // AI Tahlil va Filtrlar kartochkasi
                aiAnalysisCard

                // Kategoriyalar multi-select kartochkasi
                categoryFilterCard

                // Daromad vs Xarajat umumiy statistikasi
                summaryCards

                if scoped.isEmpty {
                    EmptyStateView(icon: "chart.pie", title: "Maʼlumot yoʻq",
                                   message: "Tanlangan davr va filtrlar boʻyicha tranzaksiyalar mavjud emas.")
                } else {
                    donutCard
                    topCategoriesCard
                    trendCard
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 120)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Hisobotlar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            exportCurrent(as: format)
                        } label: {
                            Label(format.title, systemImage: format.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(scoped.isEmpty)
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Sana tanlang", selection: $selectedDate,
                               displayedComponents: range == .day ? [.date] : [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Sana tanlash")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Tayyor") { showDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Period Navigation Card
    private var periodNavigationCard: some View {
        HStack {
            Button(action: { shiftPeriod(by: -1) }) {
                Image(systemName: "chevron.left")
                    .padding(8)
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
            }
            Spacer()
            Button(action: { showDatePicker = true }) {
                HStack(spacing: 4) {
                    Text(intervalTitle)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            Spacer()
            Button(action: { shiftPeriod(by: 1) }) {
                Image(systemName: "chevron.right")
                    .padding(8)
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
            }
        }
        .cardStyle()
    }

    private func shiftPeriod(by value: Int) {
        let cal = Calendar.current
        let component: Calendar.Component
        switch range {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        if let newDate = cal.date(byAdding: component, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    // MARK: AI Analysis Card
    private var aiAnalysisCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("AI Tahlil va Filtrlar", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.accent)
                Spacer()
            }

            HStack(spacing: Theme.Spacing.xs) {
                Toggle(isOn: $excludeCash) {
                    Text("💵 Naqd pulsiz")
                        .font(.caption.bold())
                }
                .toggleStyle(.button)
                .tint(Theme.Colors.accent)

                Toggle(isOn: $excludeLarge) {
                    Text("⚡ Yirik bitimlarsiz")
                        .font(.caption.bold())
                }
                .toggleStyle(.button)
                .tint(Theme.Colors.accent)
            }

            if excludeLarge {
                HStack {
                    Text("Yirik summa chegarasi:")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                    TextField("Summa", value: $largeThreshold, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.caption.bold())
                        .frame(width: 110)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if filteredInPeriod.isEmpty {
                    Text("Tanlangan davr va filtrlar boʻyicha tranzaksiya mavjud emas.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    Text("Sof natija: \(CurrencyFormatter.string(netBalance, code: settings.currencyCode))")
                        .font(.caption.bold())
                        .foregroundStyle(netBalance >= 0 ? Theme.Colors.income : Theme.Colors.expense)

                    if totalIncome > 0 && netBalance > 0 {
                        let pct = Int((netBalance / totalIncome) * 100)
                        Text("💡 Daromadingizning \(pct)% qismi jamgʻarilgan. Moliyaviy barqarorlik ijobiy.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else if totalExpense > totalIncome && totalIncome > 0 {
                        Text("⚠️ Xarajat daromaddan oshib ketdi. Xarajatlarni tejash tavsiya etiladi.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.expense)
                    }
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.Radius.sm)
        }
        .cardStyle()
    }

    // MARK: Category Multi-Select Filter Card
    private var categoryFilterCard: some View {
        let availableCategories: [Category] = allCategories.filter { cat in
            switch typeFilter {
            case .expense: return cat.kind == .expense
            case .income: return cat.kind == .income
            case .all: return true
            }
        }

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Kategoriyalar filtri", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.accent)
                Spacer()
                if !selectedCategories.isEmpty {
                    Button("Barchasi (\(selectedCategories.count))") {
                        withAnimation { selectedCategories.removeAll() }
                        Haptics.light()
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Colors.accent)
                } else {
                    Text("Barchasi tanlangan")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation { selectedCategories.removeAll() }
                        Haptics.light()
                    } label: {
                        Text("Hammasi")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategories.isEmpty ? Theme.Colors.accent : Theme.Colors.secondaryBackground)
                            .foregroundStyle(selectedCategories.isEmpty ? .white : Theme.Colors.secondaryText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(availableCategories, id: \.id) { cat in
                        let isSelected = selectedCategories.contains(cat.name)
                        Button {
                            withAnimation {
                                if isSelected {
                                    selectedCategories.remove(cat.name)
                                } else {
                                    selectedCategories.insert(cat.name)
                                }
                            }
                            Haptics.light()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.symbol)
                                    .font(.caption2)
                                Text(cat.name)
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? cat.color : Theme.Colors.secondaryBackground)
                            .foregroundStyle(isSelected ? .white : Theme.Colors.primaryText)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Theme.Colors.separator, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .cardStyle()
    }

    // MARK: Summary Cards
    private var summaryCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(title: "Daromad",
                     amount: totalIncome,
                     currencyCode: settings.currencyCode,
                     icon: "arrow.down.left.circle.fill",
                     tint: Theme.Colors.income)
            StatCard(title: "Xarajat",
                     amount: totalExpense,
                     currencyCode: settings.currencyCode,
                     icon: "arrow.up.right.circle.fill",
                     tint: Theme.Colors.expense)
        }
    }

    // MARK: Donut (Pie) chart
    private var donutCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            SectionHeader(title: typeFilter == .expense ? "Xarajatlar taqsimoti" : (typeFilter == .income ? "Daromadlar taqsimoti" : "Tranzaksiyalar taqsimoti"))
            Chart(byCategory, id: \.name) { item in
                SectorMark(
                    angle: .value("Summa", item.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(item.color)
                .cornerRadius(4)
            }
            .frame(height: 220)
            .overlay {
                VStack {
                    Text("Jami").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                    Text(CurrencyFormatter.compact(currentTypeTotal, code: settings.currencyCode))
                        .font(.system(.title3, design: .rounded).bold())
                }
            }
        }
        .cardStyle()
    }

    // MARK: Top kategoriyalar
    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Eng koʻp kategoriyalar")
            ForEach(byCategory.prefix(6), id: \.name) { item in
                HStack {
                    Circle().fill(item.color).frame(width: 10, height: 10)
                    Text(item.name)
                    Spacer()
                    Text("\(Int(item.amount / max(currentTypeTotal,1) * 100))%")
                        .foregroundStyle(Theme.Colors.secondaryText).font(.caption)
                    Text(CurrencyFormatter.compact(item.amount, code: settings.currencyCode))
                        .font(.callout.weight(.medium))
                }
            }
        }
        .cardStyle()
    }

    // MARK: Trend (kunlik line/bar)
    private var trendCard: some View {
        let daily = dailySeries()
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Trend")
            Chart(daily, id: \.date) { p in
                LineMark(x: .value("Sana", p.date), y: .value("Summa", p.amount))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.accent)
                AreaMark(x: .value("Sana", p.date), y: .value("Summa", p.amount))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.15).gradient)
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    private func dailySeries() -> [(date: Date, amount: Double)] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: scoped) { cal.startOfDay(for: $0.date) }
        return groups.map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }

    /// Joriy koʻrinishdagi tranzaksiyalarni tanlangan formatda eksport qiladi.
    private func exportCurrent(as format: ExportFormat) {
        let title = "\(typeFilter.title) hisoboti — \(intervalTitle)"
        if let url = ExportManager.export(scoped, format: format,
                                          title: title, currency: settings.currencyCode) {
            exportFile = ExportFile(url: url)
        }
    }
}

#Preview {
    NavigationStack { ReportsView() }
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
}

