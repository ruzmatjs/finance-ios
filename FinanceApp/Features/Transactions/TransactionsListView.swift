import SwiftUI
import SwiftData

/// Barcha tranzaksiyalar — qidiruv, filtr, saralash, swipe actions, undo delete.
struct TransactionsListView: View {
    @Environment(\.container) private var container
    @Environment(AppSettings.self) private var settings

    // SwiftData @Query — reaktiv, avtomatik yangilanadi.
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var filter = TransactionFilter()
    @State private var showFilters = false
    @State private var editing: Transaction?
    @State private var recentlyDeleted: Transaction?
    @State private var showUndo = false
    @State private var exportFile: ExportFile?

    private var filtered: [Transaction] { filter.apply(to: allTransactions) }

    /// Kunlar boʻyicha guruhlangan (sarlavhali seksiyalar).
    private var grouped: [(date: Date, items: [Transaction])] {
        let dict = Dictionary(grouping: filtered) { $0.date.startOfDay }
        return dict.map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    icon: filter.isActive || !filter.searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "tray",
                    title: filter.isActive || !filter.searchText.isEmpty ? "Natija topilmadi" : "Hozircha tranzaksiya yoʻq",
                    message: "Filtrlarni oʻzgartiring yoki yangi tranzaksiya qoʻshing."
                )
            } else {
                List {
                    ForEach(grouped, id: \.date) { section in
                        Section {
                            ForEach(section.items) { tx in
                                Button { editing = tx } label: { TransactionRow(transaction: tx) }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { delete(tx) } label: {
                                            Label("Oʻchirish", systemImage: "trash")
                                        }
                                        Button { duplicate(tx) } label: {
                                            Label("Nusxa", systemImage: "doc.on.doc")
                                        }.tint(Theme.Colors.transfer)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button { toggleFavorite(tx) } label: {
                                            Label("Sevimli", systemImage: tx.isFavorite ? "star.slash" : "star")
                                        }.tint(.yellow)
                                    }
                            }
                        } header: {
                            Text(section.date.formatted(.dateTime.weekday(.wide).day().month()))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Tranzaksiyalar")
        .searchable(text: $filter.searchText, prompt: "Summa, kategoriya, teg, izoh...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Saralash", selection: $filter.sort) {
                        ForEach(TransactionFilter.SortOption.allCases) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Button { showFilters = true } label: { Label("Filtrlar", systemImage: "line.3.horizontal.decrease") }
                } label: {
                    Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            if let url = ExportManager.export(filtered, format: format,
                                                              title: "Tranzaksiyalar",
                                                              currency: settings.currencyCode) {
                                exportFile = ExportFile(url: url)
                            }
                        } label: { Label(format.title, systemImage: format.systemImage) }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(filtered.isEmpty)
            }
        }
        .sheet(isPresented: $showFilters) { FilterSheet(filter: $filter) }
        .sheet(item: $editing) { AddTransactionView(transaction: $0) }
        .sheet(item: $exportFile) { file in ShareSheet(items: [file.url]) }
        .overlay(alignment: .bottom) { undoBanner }
        .background(Theme.Colors.background)
    }

    // MARK: Undo banner
    @ViewBuilder private var undoBanner: some View {
        if showUndo {
            HStack {
                Text("Tranzaksiya oʻchirildi")
                Spacer()
                Button("Qaytarish") { undoDelete() }.fontWeight(.semibold)
            }
            .padding()
            .glassStyle()
            .padding(.horizontal)
            .padding(.bottom, 90)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions
    private func repo() -> FinanceRepositoryProtocol? { container?.repository }

    private func delete(_ tx: Transaction) {
        recentlyDeleted = tx
        container?.haptics.impact(.rigid)
        repo()?.delete(tx)
        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showUndo = false }
            recentlyDeleted = nil
        }
    }

    private func undoDelete() {
        guard let tx = recentlyDeleted else { return }
        // Oʻchirilgan obyektni qayta yaratamiz (SwiftData delete qaytmas).
        let restored = Transaction(type: tx.type, amount: tx.amount, date: tx.date,
                                   note: tx.note, merchant: tx.merchant,
                                   category: tx.category, account: tx.account,
                                   toAccount: tx.toAccount, currencyCode: tx.currencyCode)
        repo()?.add(restored)
        withAnimation { showUndo = false }
        recentlyDeleted = nil
    }

    private func duplicate(_ tx: Transaction) {
        container?.haptics.impact(.light)
        _ = repo()?.duplicate(tx)
    }

    private func toggleFavorite(_ tx: Transaction) {
        tx.isFavorite.toggle()
        container?.haptics.selection()
        repo()?.save()
    }
}

#Preview {
    NavigationStack { TransactionsListView() }
        .modelContainer(PersistenceController.preview)
        .environment(AppSettings())
}
