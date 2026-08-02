import Foundation

/// Eksport uchun formatga bogʻliq boʻlmagan sof maʼlumot modeli.
/// SwiftData'ga bogʻlanmagan — shu sabab PDF/XLSX/CSV generatorlari mustaqil test qilinadi.
struct ExportData {
    let title: String
    let currency: String
    let generatedAt: Date
    let rows: [ExportRow]
    let totalIncome: Double
    let totalExpense: Double

    var net: Double { totalIncome - totalExpense }

    /// Jadval ustunlari sarlavhasi (barcha formatlar uchun umumiy).
    static let columns = ["Sana", "Tur", "Kategoriya", "Hisob", "Merchant", "Summa"]
}

struct ExportRow {
    let date: Date
    let typeTitle: String
    let category: String
    let account: String
    let merchant: String
    let note: String
    /// Ishorali summa: daromad +, xarajat −.
    let signedAmount: Double
}

/// Qoʻllab-quvvatlanadigan eksport formatlari.
enum ExportFormat: String, CaseIterable, Identifiable {
    case csv, excel, pdf
    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv: return "CSV"
        case .excel: return "Excel (.xlsx)"
        case .pdf: return "PDF"
        }
    }

    var systemImage: String {
        switch self {
        case .csv: return "tablecells"
        case .excel: return "tablecells.badge.ellipsis"
        case .pdf: return "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .pdf: return "pdf"
        }
    }
}
