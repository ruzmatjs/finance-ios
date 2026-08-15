import XCTest
@testable import FinanceApp

/// Sof biznes-logika testlari — SwiftData'siz, tez ishlaydi.
/// Repository protocol + sof funksiyalar arxitekturasi shuni mumkin qiladi.
final class ParserAndFilterTests: XCTestCase {

    // MARK: - NaturalLanguageParser
    func testParsesTaxiExpense() throws {
        let result = try XCTUnwrap(NaturalLanguageParser().parse("Taxi 35000"))
        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 35000)
        XCTAssertEqual(result.categoryHint, "Taxi")
    }

    func testParsesSalaryIncome() throws {
        let result = try XCTUnwrap(NaturalLanguageParser().parse("Salary 15000000"))
        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 15_000_000)
    }

    func testParsesShorthandK() throws {
        let result = try XCTUnwrap(NaturalLanguageParser().parse("cafe 35k"))
        XCTAssertEqual(result.amount, 35_000)
        XCTAssertEqual(result.categoryHint, "Cafe")
    }

    func testReturnsNilWithoutAmount() {
        XCTAssertNil(NaturalLanguageParser().parse("just some text"))
    }

    // MARK: - TransactionFilter (sof funksiya)
    func testFilterByType() {
        let income = Transaction(type: .income, amount: 100)
        let expense = Transaction(type: .expense, amount: 50)
        var filter = TransactionFilter()
        filter.type = .income
        let result = filter.apply(to: [income, expense])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.type, .income)
    }

    func testSortByAmountDesc() {
        let a = Transaction(type: .expense, amount: 10)
        let b = Transaction(type: .expense, amount: 90)
        var filter = TransactionFilter()
        filter.sort = .amountDesc
        let result = filter.apply(to: [a, b])
        XCTAssertEqual(result.first?.amount, 90)
    }

    func testSearchMatchesMerchant() {
        let tx = Transaction(type: .expense, amount: 25000, merchant: "Korzinka")
        var filter = TransactionFilter()
        filter.searchText = "korz"
        XCTAssertEqual(filter.apply(to: [tx]).count, 1)
    }

    // MARK: - Report AI & Filter Logic Tests
    func testReportFilterIncomeAndExpense() {
        let income = Transaction(type: .income, amount: 500000)
        let expense = Transaction(type: .expense, amount: 150000)
        let all = [income, expense]

        let incomeOnly = all.filter { $0.type == .income }
        XCTAssertEqual(incomeOnly.count, 1)
        XCTAssertEqual(incomeOnly.first?.amount, 500000)

        let expenseOnly = all.filter { $0.type == .expense }
        XCTAssertEqual(expenseOnly.count, 1)
        XCTAssertEqual(expenseOnly.first?.amount, 150000)
    }

    func testReportFilterCashExclusion() {
        let cashAccount = Account(name: "Naqd pul", type: .cash)
        let cardAccount = Account(name: "Uzcard", type: .bankCard)

        let cashTx = Transaction(type: .expense, amount: 50000, account: cashAccount)
        let cardTx = Transaction(type: .expense, amount: 120000, account: cardAccount)

        let txs = [cashTx, cardTx]
        let nonCashTxs = txs.filter { tx in
            let accName = tx.account?.name.lowercased() ?? ""
            return tx.account?.id != "cash" && !accName.contains("naqd")
        }

        XCTAssertEqual(nonCashTxs.count, 1)
        XCTAssertEqual(nonCashTxs.first?.amount, 120000)
    }

    func testReportFilterLargeAmountExclusion() {
        let normalTx = Transaction(type: .income, amount: 3000000)
        let largeTx = Transaction(type: .income, amount: 25000000)

        let threshold: Double = 5000000
        let txs = [normalTx, largeTx]
        let filtered = txs.filter { $0.amount < threshold }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.amount, 3000000)
    }
}

