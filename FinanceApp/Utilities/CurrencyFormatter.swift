import Foundation

/// Pul summalarini formatlash uchun markazlashtirilgan yordamchi.
/// Formatter'lar qimmat obyektlar — shuning uchun cache qilinadi.
enum CurrencyFormatter {
    private static var cache: [String: NumberFormatter] = [:]

    static func formatter(for code: String) -> NumberFormatter {
        if let f = cache[code] { return f }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = (code == "UZS") ? 0 : 2
        f.currencySymbol = symbol(for: code)
        cache[code] = f
        return f
    }

    static func string(_ amount: Double, code: String = "UZS") -> String {
        formatter(for: code).string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Ishorali koʻrinish: "+120 000 soʻm" / "-35 000 soʻm".
    static func signed(_ amount: Double, code: String = "UZS") -> String {
        let sign = amount > 0 ? "+" : (amount < 0 ? "-" : "")
        return sign + string(abs(amount), code: code)
    }

    /// Katta summalarni qisqartiradi: 15 000 000 -> "15M".
    static func compact(_ amount: Double, code: String = "UZS") -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        let sym = symbol(for: code)
        switch abs(amount) {
        case 1_000_000...:
            return "\(f.string(from: NSNumber(value: amount / 1_000_000)) ?? "")M \(sym)"
        case 1_000...:
            return "\(f.string(from: NSNumber(value: amount / 1_000)) ?? "")K \(sym)"
        default:
            return string(amount, code: code)
        }
    }

    static func symbol(for code: String) -> String {
        switch code {
        case "UZS": return "soʻm"
        case "USD": return "$"
        case "EUR": return "€"
        case "RUB": return "₽"
        case "GBP": return "£"
        default: return code
        }
    }

    static let supportedCodes = ["UZS", "USD", "EUR", "RUB", "GBP"]
}
