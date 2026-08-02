import UIKit

/// `ExportData`'dan sahifalanadigan PDF hisobot chizadi (`UIGraphicsPDFRenderer`).
enum PDFExporter {

    // A4 (pt)
    private static let pageWidth: CGFloat = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat = 40
    private static let rowHeight: CGFloat = 22

    // Ustun x-koordinatalari (Sana, Kategoriya, Hisob, Merchant, Summa)
    private static let columns: [(title: String, x: CGFloat, align: NSTextAlignment)] = [
        ("Sana", 40, .left),
        ("Kategoriya", 150, .left),
        ("Hisob", 260, .left),
        ("Merchant", 360, .left),
        ("Summa", 470, .right)
    ]

    static func data(from export: ExportData) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = margin

            // Sarlavha
            draw(export.title, at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 22, weight: .bold))
            y += 30
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
            draw("Yaratildi: \(df.string(from: export.generatedAt))",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 10), color: .gray)
            y += 26

            // Jamlanma qutisi
            y = drawSummary(export, y: y)
            y += 16

            // Jadval sarlavhasi
            drawTableHeader(at: y); y += rowHeight

            // Qatorlar (sahifalash bilan)
            let rowDF = DateFormatter(); rowDF.dateFormat = "dd.MM.yy"
            for row in export.rows {
                if y + rowHeight > pageHeight - margin {
                    ctx.beginPage()
                    y = margin
                    drawTableHeader(at: y); y += rowHeight
                }
                drawRow(row, dateFormatter: rowDF, currency: export.currency, y: y)
                y += rowHeight
            }
        }
    }

    // MARK: - Chizish yordamchilari

    private static func drawSummary(_ export: ExportData, y: CGFloat) -> CGFloat {
        let box = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 54)
        let path = UIBezierPath(roundedRect: box, cornerRadius: 10)
        UIColor.systemGray6.setFill(); path.fill()

        let items: [(String, Double, UIColor)] = [
            ("Daromad", export.totalIncome, .systemGreen),
            ("Xarajat", export.totalExpense, .systemRed),
            ("Sof", export.net, export.net >= 0 ? .systemBlue : .systemRed)
        ]
        let colW = box.width / 3
        for (i, item) in items.enumerated() {
            let x = box.minX + colW * CGFloat(i) + 12
            draw(item.0, at: CGPoint(x: x, y: y + 8),
                 font: .systemFont(ofSize: 10), color: .gray)
            draw(CurrencyFormatter.string(item.1, code: export.currency),
                 at: CGPoint(x: x, y: y + 24),
                 font: .systemFont(ofSize: 15, weight: .semibold), color: item.2)
        }
        return y + box.height
    }

    private static func drawTableHeader(at y: CGFloat) {
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y + rowHeight - 2))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y + rowHeight - 2))
        UIColor.systemGray4.setStroke(); line.lineWidth = 1; line.stroke()

        for col in columns {
            draw(col.title, at: CGPoint(x: col.x, y: y + 4),
                 font: .systemFont(ofSize: 10, weight: .semibold), color: .darkGray,
                 width: columnWidth(col.x), align: col.align)
        }
    }

    private static func drawRow(_ row: ExportRow, dateFormatter: DateFormatter,
                                currency: String, y: CGFloat) {
        let values = [
            dateFormatter.string(from: row.date),
            row.category,
            row.account,
            row.merchant,
            CurrencyFormatter.string(row.signedAmount, code: currency)
        ]
        for (i, col) in columns.enumerated() {
            let color: UIColor = (i == 4) ? (row.signedAmount >= 0 ? .systemGreen : .systemRed) : .label
            draw(values[i], at: CGPoint(x: col.x, y: y + 3),
                 font: .systemFont(ofSize: 10), color: color,
                 width: columnWidth(col.x), align: col.align)
        }
    }

    private static func columnWidth(_ x: CGFloat) -> CGFloat {
        if let next = columns.first(where: { $0.x > x }) { return next.x - x - 6 }
        return pageWidth - margin - x
    }

    private static func draw(_ text: String, at point: CGPoint,
                             font: UIFont, color: UIColor = .label,
                             width: CGFloat? = nil, align: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let rect = CGRect(x: point.x, y: point.y,
                          width: width ?? (pageWidth - point.x - margin),
                          height: font.lineHeight + 2)
        text.draw(in: rect, withAttributes: attrs)
    }
}
