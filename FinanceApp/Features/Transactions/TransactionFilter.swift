import Foundation

/// Tranzaksiyalar uchun filtr va saralash holati.
/// Alohida struct — ViewModel'ni sodda saqlaydi va test qilinadi.
struct TransactionFilter: Equatable {
    var searchText: String = ""
    var type: TransactionType? = nil
    var categoryName: String? = nil
    var accountName: String? = nil
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var onlyFavorites: Bool = false

    enum SortOption: String, CaseIterable, Identifiable {
        case dateDesc, dateAsc, amountDesc, amountAsc
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dateDesc: return "Sana ↓"
            case .dateAsc: return "Sana ↑"
            case .amountDesc: return "Summa ↓"
            case .amountAsc: return "Summa ↑"
            }
        }
    }
    var sort: SortOption = .dateDesc

    var isActive: Bool {
        type != nil || categoryName != nil || accountName != nil
        || minAmount != nil || maxAmount != nil || onlyFavorites
    }

    /// Berilgan roʻyxatga filtr va saralashni qoʻllaydi (sof funksiya).
    func apply(to items: [Transaction]) -> [Transaction] {
        var result = items.filter { tx in
            if let type, tx.type != type { return false }
            if let categoryName, tx.category?.name != categoryName { return false }
            if let accountName, tx.account?.name != accountName { return false }
            if let minAmount, tx.amount < minAmount { return false }
            if let maxAmount, tx.amount > maxAmount { return false }
            if onlyFavorites, !tx.isFavorite { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let haystack = [tx.merchant, tx.note, tx.category?.name ?? "",
                                String(Int(tx.amount)),
                                (tx.tags ?? []).map(\.name).joined(separator: " ")]
                    .joined(separator: " ").lowercased()
                if !haystack.contains(q) { return false }
            }
            return true
        }

        switch sort {
        case .dateDesc:   result.sort { $0.date > $1.date }
        case .dateAsc:    result.sort { $0.date < $1.date }
        case .amountDesc: result.sort { $0.amount > $1.amount }
        case .amountAsc:  result.sort { $0.amount < $1.amount }
        }
        return result
    }
}
