import Foundation

/// Tabiiy tildagi matndan tranzaksiya ajratib oluvchi parser.
/// Misollar:
///   "Taxi 35000"          -> xarajat, 35000, Taxi
///   "Dinner 120000"       -> xarajat, 120000, Restaurant
///   "Salary 15000000"     -> daromad, 15000000, Salary
///
/// Backend'siz, oflayn ishlaydi — kalit soʻzlar + summa ajratish (heuristik NLP).
/// SOLID: parsing logikasi View'dan ajratilgan, alohida test qilinadi.
struct NaturalLanguageParser {

    struct Result {
        var type: TransactionType
        var amount: Double
        var categoryHint: String?
        var merchant: String?
        var date: Date
    }

    /// Kalit soʻz -> (kategoriya nomi, tur) xaritasi.
    private let keywordMap: [String: (category: String, type: TransactionType)] = [
        // Xarajatlar
        "taxi": ("Taxi", .expense), "taksi": ("Taxi", .expense),
        "food": ("Food", .expense), "ovqat": ("Food", .expense),
        "dinner": ("Restaurant", .expense), "kechki": ("Restaurant", .expense),
        "lunch": ("Restaurant", .expense), "tushlik": ("Restaurant", .expense),
        "cafe": ("Cafe", .expense), "kafe": ("Cafe", .expense),
        "coffee": ("Cafe", .expense), "kofe": ("Cafe", .expense),
        "water": ("Ichimliklar", .expense), "suv": ("Ichimliklar", .expense), "ichimlik": ("Ichimliklar", .expense), "ichimliklar": ("Ichimliklar", .expense),
        "fuel": ("Fuel", .expense), "benzin": ("Fuel", .expense),
        "shopping": ("Shopping", .expense), "xarid": ("Shopping", .expense),
        "clothes": ("Clothing", .expense), "kiyim": ("Clothing", .expense),
        "pharmacy": ("Pharmacy", .expense), "dori": ("Pharmacy", .expense),
        "gym": ("Gym", .expense), "sport": ("Gym", .expense),
        "internet": ("Internet", .expense),
        "mobile": ("Mobile", .expense), "aloqa": ("Mobile", .expense),
        "rent": ("Rent", .expense), "ijara": ("Rent", .expense),
        "netflix": ("Entertainment", .expense),
        // Daromadlar
        "salary": ("Salary", .income), "maosh": ("Salary", .income),
        "bonus": ("Bonus", .income),
        "freelance": ("Freelance", .income),
        "gift": ("Gift", .income), "sovga": ("Gift", .income),
        "cashback": ("Cashback", .income)
    ]

    func parse(_ input: String, defaultCurrency: String = "UZS") -> Result? {
        let lower = input.lowercased()

        // 1) Summani ajratib olish (raqamlar, mumkin probel/vergul bilan).
        guard let amount = extractAmount(from: lower), amount > 0 else { return nil }

        // 2) Kategoriya va turini topish.
        var detectedType: TransactionType = .expense
        var categoryHint: String?
        for (keyword, mapping) in keywordMap where lower.contains(keyword) {
            categoryHint = mapping.category
            detectedType = mapping.type
            break
        }

        // 3) "I earned / oldim / keldi" kabi daromad signallari.
        let incomeSignals = ["earned", "received", "income", "oldim", "keldi", "daromad"]
        if incomeSignals.contains(where: lower.contains) { detectedType = .income }

        // 4) Merchant nomi — raqam va kalit soʻzlardan tozalangan matn.
        let merchant = extractMerchant(from: input)

        return Result(
            type: detectedType,
            amount: amount,
            categoryHint: categoryHint,
            merchant: merchant,
            date: Date()
        )
    }

    private func extractAmount(from text: String) -> Double? {
        // "120 000", "120,000", "120000", "15m", "35k"
        // Avval "15m"/"35k" kabi qisqartmalar.
        if let m = text.range(of: #"(\d+(?:[.,]\d+)?)\s*(k|m|ming|mln)"#, options: .regularExpression) {
            let token = String(text[m]).replacingOccurrences(of: ",", with: ".")
            let number = Double(token.filter { $0.isNumber || $0 == "." }) ?? 0
            if token.contains("m") || token.contains("mln") { return number * 1_000_000 }
            if token.contains("k") || token.contains("ming") { return number * 1_000 }
        }
        // Oddiy raqamlar (probellarni olib tashlab).
        let digits = text.replacingOccurrences(of: #"[^\d]"#, with: "", options: .regularExpression)
        return Double(digits)
    }

    private func extractMerchant(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: #"\d"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned.capitalized
    }
}
