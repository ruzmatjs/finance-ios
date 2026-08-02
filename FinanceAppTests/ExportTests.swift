import XCTest
@testable import FinanceApp

/// Eksport generatorlari testlari — SwiftData'siz, sof `ExportData` ustida.
final class ExportTests: XCTestCase {

    private var sample: ExportData {
        ExportData(
            title: "Test hisobot",
            currency: "UZS",
            generatedAt: Date(timeIntervalSince1970: 0),
            rows: [
                ExportRow(date: Date(timeIntervalSince1970: 0), typeTitle: "Xarajat",
                          category: "Taxi", account: "Naqd", merchant: "Yandex",
                          note: "", signedAmount: -35000),
                ExportRow(date: Date(timeIntervalSince1970: 86400), typeTitle: "Daromad",
                          category: "Salary", account: "Karta", merchant: "Ish",
                          note: "", signedAmount: 15_000_000)
            ],
            totalIncome: 15_000_000,
            totalExpense: 35_000
        )
    }

    func testCSVContainsHeaderAndData() throws {
        let text = String(decoding: CSVExporter.data(from: sample), as: UTF8.self)
        XCTAssertTrue(text.contains("Sana,Tur,Kategoriya"))
        XCTAssertTrue(text.contains("Taxi"))
        XCTAssertTrue(text.contains("Jami daromad"))
    }

    func testXLSXHasZipSignature() {
        // Haqiqiy .xlsx — ZIP konteyner. "PK" (0x50 0x4B) bilan boshlanadi.
        let data = XLSXExporter.data(from: sample)
        XCTAssertEqual(Array(data.prefix(2)), [0x50, 0x4B])
        XCTAssertGreaterThan(data.count, 200)
    }

    func testPDFHasSignature() {
        // PDF fayl "%PDF" bilan boshlanadi.
        let data = PDFExporter.data(from: sample)
        XCTAssertEqual(Array(data.prefix(4)), Array("%PDF".utf8))
    }

    func testCRC32KnownValue() {
        // "123456789" uchun standart CRC-32 = 0xCBF43926.
        let data = Data("123456789".utf8)
        XCTAssertEqual(CRC32.checksum(data), 0xCBF4_3926)
    }
}
