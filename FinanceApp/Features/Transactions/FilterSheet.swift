import SwiftUI
import SwiftData

/// Filtr sozlamalari oynasi.
struct FilterSheet: View {
    @Binding var filter: TransactionFilter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \Account.sortIndex) private var accounts: [Account]

    var body: some View {
        NavigationStack {
            Form {
                Section("Tur") {
                    Picker("Tur", selection: $filter.type) {
                        Text("Barchasi").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases) { Text($0.title).tag(TransactionType?.some($0)) }
                    }.pickerStyle(.segmented)
                }

                Section("Kategoriya") {
                    Picker("Kategoriya", selection: $filter.categoryName) {
                        Text("Barchasi").tag(String?.none)
                        ForEach(categories) { Text($0.name).tag(String?.some($0.name)) }
                    }
                }

                Section("Hisob") {
                    Picker("Hisob", selection: $filter.accountName) {
                        Text("Barchasi").tag(String?.none)
                        ForEach(accounts) { Text($0.name).tag(String?.some($0.name)) }
                    }
                }

                Section("Summa oraligʻi") {
                    HStack {
                        TextField("Min", value: $filter.minAmount, format: .number).keyboardType(.numberPad)
                        Divider()
                        TextField("Max", value: $filter.maxAmount, format: .number).keyboardType(.numberPad)
                    }
                }

                Section {
                    Toggle("Faqat sevimlilar", isOn: $filter.onlyFavorites)
                }

                Section {
                    Button("Filtrlarni tozalash", role: .destructive) {
                        filter = TransactionFilter(searchText: filter.searchText, sort: filter.sort)
                    }
                }
            }
            .navigationTitle("Filtrlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tayyor") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
