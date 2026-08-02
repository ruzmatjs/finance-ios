import Foundation

/// `ExportData`'dan haqiqiy `.xlsx` (OOXML) fayl yasaydi.
/// Inline string'lardan foydalanadi (sharedStrings.xml kerak emas) — sodda va yaroqli.
enum XLSXExporter {

    static func data(from export: ExportData) -> Data {
        var zip = ZipArchive()
        zip.add("[Content_Types].xml", Data(contentTypes.utf8))
        zip.add("_rels/.rels", Data(rootRels.utf8))
        zip.add("xl/workbook.xml", Data(workbook.utf8))
        zip.add("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8))
        zip.add("xl/worksheets/sheet1.xml", Data(sheet(for: export).utf8))
        return zip.finalize()
    }

    // MARK: - Worksheet qurish

    private static func sheet(for export: ExportData) -> String {
        var rows = ""
        var r = 1
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        // Sarlavha qatori
        rows += row(r, cells: [.text(export.title)]); r += 1
        rows += row(r, cells: [.text("Yaratildi: " + df.string(from: export.generatedAt))]); r += 1
        r += 1 // boʻsh qator

        // Ustun sarlavhalari
        rows += row(r, cells: ExportData.columns.map { .text($0) }); r += 1

        // Maʼlumot qatorlari
        for item in export.rows {
            rows += row(r, cells: [
                .text(df.string(from: item.date)),
                .text(item.typeTitle),
                .text(item.category),
                .text(item.account),
                .text(item.merchant),
                .number(item.signedAmount)
            ])
            r += 1
        }

        // Jamlanma
        r += 1
        rows += row(r, cells: [.text("Jami daromad"), .empty, .empty, .empty, .empty, .number(export.totalIncome)]); r += 1
        rows += row(r, cells: [.text("Jami xarajat"), .empty, .empty, .empty, .empty, .number(export.totalExpense)]); r += 1
        rows += row(r, cells: [.text("Sof"), .empty, .empty, .empty, .empty, .number(export.net)])

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(rows)</sheetData></worksheet>
        """
    }

    private enum Cell { case text(String), number(Double), empty }

    private static func row(_ index: Int, cells: [Cell]) -> String {
        var xml = "<row r=\"\(index)\">"
        for (col, cell) in cells.enumerated() {
            let ref = "\(columnLetter(col))\(index)"
            switch cell {
            case .empty:
                continue
            case .number(let value):
                xml += "<c r=\"\(ref)\"><v>\(value)</v></c>"
            case .text(let value):
                xml += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
            }
        }
        xml += "</row>"
        return xml
    }

    /// 0 -> "A", 25 -> "Z", 26 -> "AA".
    private static func columnLetter(_ index: Int) -> String {
        var n = index, result = ""
        repeat {
            result = String(UnicodeScalar(65 + n % 26)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Statik OOXML qismlar

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """

    private static let workbook = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Hisobot" sheetId="1" r:id="rId1"/></sheets></workbook>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
    """
}
