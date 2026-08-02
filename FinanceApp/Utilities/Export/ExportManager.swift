import Foundation
import SwiftData

/// Eksportning yagona kirish nuqtasi — [Transaction] -> tanlangan format -> vaqtinchalik URL.
/// Facade pattern: chaqiruvchi (View) format ichki tafsilotlarini bilmaydi.
enum ExportManager {

    /// Tranzaksiyalarni tanlangan formatda eksport qiladi va ulashiladigan URL qaytaradi.
    static func export(_ transactions: [Transaction],
                       format: ExportFormat,
                       title: String,
                       currency: String) -> URL? {
        let data = makeExportData(transactions, title: title, currency: currency)
        let payload: Data
        switch format {
        case .csv:   payload = CSVExporter.data(from: data)
        case .excel: payload = XLSXExporter.data(from: data)
        case .pdf:   payload = PDFExporter.data(from: data)
        }
        return write(payload, extension: format.fileExtension)
    }

    /// Modellarni formatdan mustaqil `ExportData`ga aylantiradi.
    static func makeExportData(_ transactions: [Transaction],
                               title: String,
                               currency: String) -> ExportData {
        let sorted = transactions.sorted { $0.date < $1.date }
        let rows = sorted.map { tx in
            ExportRow(
                date: tx.date,
                typeTitle: tx.type.title,
                category: tx.category?.name ?? "",
                account: tx.account?.name ?? "",
                merchant: tx.merchant,
                note: tx.note,
                signedAmount: tx.type == .income ? tx.amount : -tx.amount
            )
        }
        let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return ExportData(title: title, currency: currency, generatedAt: Date(),
                          rows: rows, totalIncome: income, totalExpense: expense)
    }

    private static func write(_ data: Data, extension ext: String) -> URL? {
        let name = "FinanceHisobot-\(Int(Date().timeIntervalSince1970)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
