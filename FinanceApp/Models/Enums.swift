import Foundation
import SwiftUI

// MARK: - Tranzaksiya turi
/// Har bir tranzaksiya uch xil boʻlishi mumkin.
/// `String` raw value SwiftData'da barqaror saqlanadi va migratsiyaga chidamli.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Daromad"
        case .expense: return "Xarajat"
        case .transfer: return "Oʻtkazma"
        }
    }

    var systemImage: String {
        switch self {
        case .income: return "arrow.down.left.circle.fill"
        case .expense: return "arrow.up.right.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    /// Balansga taʼsir belgisi: daromad +, xarajat -.
    var sign: Double {
        switch self {
        case .income: return 1
        case .expense: return -1
        case .transfer: return 0
        }
    }
}

// MARK: - Hisob turi
enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash, wallet, bankCard, creditCard, savings, business, investment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Naqd"
        case .wallet: return "Hamyon"
        case .bankCard: return "Bank karta"
        case .creditCard: return "Kredit karta"
        case .savings: return "Jamgʻarma"
        case .business: return "Biznes"
        case .investment: return "Investitsiya"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote.fill"
        case .wallet: return "wallet.pass.fill"
        case .bankCard: return "creditcard.fill"
        case .creditCard: return "creditcard.circle.fill"
        case .savings: return "building.columns.fill"
        case .business: return "briefcase.fill"
        case .investment: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }
}

// MARK: - Kategoriya "oilasi" (daromad/xarajat)
enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var title: String { self == .income ? "Daromad" : "Xarajat" }
}

// MARK: - Byudjet va takrorlanish davri
enum PeriodType: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Kunlik"
        case .weekly: return "Haftalik"
        case .monthly: return "Oylik"
        case .yearly: return "Yillik"
        }
    }

    /// Davr uzunligini `Calendar.Component` orqali qaytaradi (statistikada ishlatiladi).
    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}

// MARK: - Reja/hisobot oraligʻi (Reports ekranida segment)
enum ReportRange: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return "Kun"
        case .week: return "Hafta"
        case .month: return "Oy"
        case .year: return "Yil"
        }
    }
}

// MARK: - Qarz turi
enum DebtType: String, Codable, CaseIterable, Identifiable {
    case lend   // Men berdim (Mendan olishdi)
    case borrow // Men oldim (Menga berishdi)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lend: return "Men berdim"
        case .borrow: return "Men oldim"
        }
    }
}

// MARK: - Qarz holati
enum DebtStatus: String, Codable, CaseIterable, Identifiable {
    case active, settled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Faol"
        case .settled: return "Yopilgan"
        }
    }
}
