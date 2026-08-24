import XCTest
@testable import FinanceApp

final class TelegramServiceTests: XCTestCase {

    func testBuildWeeklySummaryText() {
        let catFood = Category(name: "Food", kind: .expense, symbol: "fork.knife", colorHex: "#FF9500")
        let catTaxi = Category(name: "Taxi", kind: .expense, symbol: "car.fill", colorHex: "#FFCC00")
        let catSalary = Category(name: "Salary", kind: .income, symbol: "banknote.fill", colorHex: "#34C759")

        let acc = Account(name: "Karta", type: .bankCard, openingBalance: 0, colorHex: "#007AFF")

        let t1 = Transaction(type: .expense, amount: 50_000, category: catFood, account: acc, currencyCode: "UZS")
        let t2 = Transaction(type: .expense, amount: 25_000, category: catTaxi, account: acc, currencyCode: "UZS")
        let t3 = Transaction(type: .income, amount: 500_000, category: catSalary, account: acc, currencyCode: "UZS")

        let transactions = [t1, t2, t3]
        let startDate = Date(timeIntervalSince1970: 0)
        let endDate = Date(timeIntervalSince1970: 86400 * 7)

        let summary = TelegramService.buildWeeklySummaryText(
            transactions: transactions,
            currency: "UZS",
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertTrue(summary.contains("Haftalik moliya hisoboti"))
        XCTAssertTrue(summary.contains("Jami daromad"))
        XCTAssertTrue(summary.contains("Jami xarajat"))
        XCTAssertTrue(summary.contains("Sof qoldiq"))
        XCTAssertTrue(summary.contains("Food"))
        XCTAssertTrue(summary.contains("Taxi"))
    }

    func testValidationWithEmptyCredentials() async {
        let result = await TelegramService.testConnection(token: "", chatId: "")
        switch result {
        case .success:
            XCTFail("Bo'sh ma'lumotlar bilan muvaffaqiyatli bo'lmasligi kerak")
        case .failure(let error):
            XCTAssertTrue(error is TelegramService.TelegramError)
        }
    }
}
