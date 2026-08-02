import Foundation

/// `ExportData`'ni CSV baytlariga aylantiradi (Excel/Numbers ham ochadi).
enum CSVExporter {
    static func data(from export: ExportData) -> Data {
        var csv = ExportData.columns.joined(separator: ",") + "\n"
        let df = ISO8601DateFormatter()
        for row in export.rows {
            let cells = [
                df.string(from: row.date),
                row.typeTitle,
                row.category,
                row.account,
                row.merchant,
                String(row.signedAmount)
            ].map(escape)
            csv += cells.joined(separator: ",") + "\n"
        }
        // Yakuniy jamlanma
        csv += "\n"
        csv += "\(escape("Jami daromad")),,,,,\(export.totalIncome)\n"
        csv += "\(escape("Jami xarajat")),,,,,\(export.totalExpense)\n"
        csv += "\(escape("Sof")),,,,,\(export.net)\n"
        return Data(csv.utf8)
    }

    /// Vergul, qoʻshtirnoq yoki yangi qatorni CSV qoidasi boʻyicha qochirish.
    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
