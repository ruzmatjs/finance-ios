import Foundation

/// Telegram Bot API orqali toʻgʻridan-toʻgʻri (serversiz) xabarlar va hisobot fayllarini yuborish xizmati.
enum TelegramService {

    static let botUsername = "ruzmat_finance_bot"
    static let botURL = URL(string: "https://t.me/ruzmat_finance_bot")!

    enum TelegramError: LocalizedError {
        case invalidURL
        case missingCredentials
        case apiError(String)
        case networkError(Error)
        case unknown

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Telegram API manzili notoʻgʻri."
            case .missingCredentials:
                return "Bot Token yoki Chat ID kiritilmagan."
            case .apiError(let message):
                return "Telegram xatosi: \(message)"
            case .networkError(let error):
                return "Tarmoq xatosi: \(error.localizedDescription)"
            case .unknown:
                return "Nomaʼlum xatolik yuz berdi."
            }
        }
    }

    // MARK: - API metodlari

    /// Telegram Bot ulanishini va chat ID toʻgʻriligini tekshiradi (test xabari yuboradi).
    static func testConnection(token: String, chatId: String) async -> Result<String, Error> {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanChatId.isEmpty else {
            return .failure(TelegramError.missingCredentials)
        }

        let message = "✅ <b>FinanceApp muvaffaqiyatli ulandi!</b>\n\nSizning Telegram botingiz va chat ID toʻgʻri sozlangan. Endi haftalik hisobotlar shu yerga yuboriladi."

        do {
            try await sendMessage(token: cleanToken, chatId: cleanChatId, text: message, parseMode: "HTML")
            return .success("Ulanish muvaffaqiyatli! Test xabari yuborildi.")
        } catch {
            return .failure(error)
        }
    }

    /// Matnli xabar yuboradi (HTML formatini qoʻllab-quvvatlaydi).
    @discardableResult
    static func sendMessage(token: String,
                            chatId: String,
                            text: String,
                            parseMode: String = "HTML") async throws -> Bool {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "https://api.telegram.org/bot\(cleanToken)/sendMessage") else {
            throw TelegramError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [
            "chat_id": cleanChatId,
            "text": text,
            "parse_mode": parseMode
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TelegramError.unknown
        }

        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let ok = json["ok"] as? Bool ?? false

        if httpResponse.statusCode == 200 && ok {
            return true
        } else {
            let desc = json["description"] as? String ?? "Status \(httpResponse.statusCode)"
            throw TelegramError.apiError(desc)
        }
    }

    /// Hujjat (PDF, Excel, CSV) yuboradi (multipart/form-data).
    @discardableResult
    static func sendDocument(token: String,
                             chatId: String,
                             fileURL: URL,
                             caption: String? = nil,
                             parseMode: String = "HTML") async throws -> Bool {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "https://api.telegram.org/bot\(cleanToken)/sendDocument") else {
            throw TelegramError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        var body = Data()

        // chat_id parametri
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cleanChatId)\r\n".data(using: .utf8)!)

        // caption parametri (agar boʻlsa)
        if let caption = caption, !caption.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"parse_mode\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(parseMode)\r\n".data(using: .utf8)!)
        }

        // document fayli
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // tugash chegarasi
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TelegramError.unknown
        }

        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let ok = json["ok"] as? Bool ?? false

        if httpResponse.statusCode == 200 && ok {
            return true
        } else {
            let desc = json["description"] as? String ?? "Status \(httpResponse.statusCode)"
            throw TelegramError.apiError(desc)
        }
    }

    // MARK: - Haftalik hisobot yaratish va joʻnatish

    /// Tranzaksiyalardan haftalik hisobot matnini tuzadi.
    static func buildWeeklySummaryText(transactions: [Transaction],
                                       currency: String,
                                       startDate: Date,
                                       endDate: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "uz_UZ")
        df.dateFormat = "d-MMMM"

        let periodStr = "\(df.string(from: startDate)) — \(df.string(from: endDate))"

        let incomeTxs = transactions.filter { $0.type == .income }
        let expenseTxs = transactions.filter { $0.type == .expense }

        let totalIncome = incomeTxs.reduce(0) { $0 + $1.amount }
        let totalExpense = expenseTxs.reduce(0) { $0 + $1.amount }
        let net = totalIncome - totalExpense

        var text = "📊 <b>Haftalik moliya hisoboti</b>\n"
        text += "🗓 <i>\(periodStr)</i>\n\n"

        text += "💰 <b>Jami daromad:</b> +\(CurrencyFormatter.string(totalIncome, code: currency))\n"
        text += "💸 <b>Jami xarajat:</b> -\(CurrencyFormatter.string(totalExpense, code: currency))\n"

        let netSign = net >= 0 ? "+" : "-"
        let netColor = net >= 0 ? "🟢" : "🔴"
        text += "\(netColor) <b>Sof qoldiq:</b> \(netSign)\(CurrencyFormatter.string(abs(net), code: currency))\n"

        // Kategoriyalar boʻyicha taqsimot (eng koʻp 5 ta)
        var categoryTotals: [String: Double] = [:]
        for tx in expenseTxs {
            let catName = tx.category?.name ?? "Boshqa"
            categoryTotals[catName, default: 0] += tx.amount
        }

        if !categoryTotals.isEmpty {
            text += "\n🏷 <b>Asosiy xarajatlar:</b>\n"
            let sortedCats = categoryTotals.sorted { $0.value > $1.value }.prefix(5)
            for (cat, amount) in sortedCats {
                let percent = totalExpense > 0 ? Int((amount / totalExpense) * 100) : 0
                text += " • \(cat): \(CurrencyFormatter.compact(amount, code: currency)) (\(percent)%)\n"
            }
        }

        text += "\n📱 <i>FinanceApp orqali avtomatik yuborildi.</i>"
        return text
    }

    /// Haftalik hisobotni joʻnatadi (matn va ixtiyoriy PDF/Excel biriktirma bilan).
    static func sendWeeklyReport(transactions: [Transaction],
                                 format: ExportFormat?,
                                 currency: String,
                                 token: String,
                                 chatId: String) async throws {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let summaryText = buildWeeklySummaryText(
            transactions: transactions,
            currency: currency,
            startDate: startDate,
            endDate: now
        )

        // Agar fayl biriktirish tanlangan boʻlsa
        if let format = format {
            let df = DateFormatter()
            df.dateFormat = "dd.MM"
            let title = "Haftalik hisobot (\(df.string(from: startDate)) - \(df.string(from: now)))"
            if let fileURL = ExportManager.export(transactions, format: format, title: title, currency: currency) {
                try await sendDocument(token: token, chatId: chatId, fileURL: fileURL, caption: summaryText, parseMode: "HTML")
                return
            }
        }

        // Faqat matn boʻlsa yoki fayl yasalmagan boʻlsa
        try await sendMessage(token: token, chatId: chatId, text: summaryText, parseMode: "HTML")
    }

    // MARK: - Qarz maʼlumotlarini shakllantirish va ulashish

    /// Qarz maʼlumotini Telegram xabar matniga aylantiradi.
    static func buildDebtSummaryText(person: String,
                                     amount: Double,
                                     paid: Double,
                                     type: DebtType,
                                     isSettled: Bool,
                                     date: Date,
                                     dueDate: Date?,
                                     currency: String,
                                     note: String?) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "uz_UZ")
        df.dateFormat = "d-MMMM, yyyy"

        let isLend = type == .lend
        let remaining = max(amount - paid, 0)

        var text = "🤝 <b>Qarz maʼlumoti (Eslatma)</b>\n\n"
        text += isLend ? "👤 <b>Kimga (Qarz oluvchi):</b> \(person)\n" : "👤 <b>Kimdan (Qarz beruvchi):</b> \(person)\n"
        text += "💰 <b>Qarz summasi:</b> \(CurrencyFormatter.string(amount, code: currency))\n"
        text += "🗓 <b>\(isLend ? "Qarz berilgan sana" : "Qarz olingan sana"):</b> \(df.string(from: date))\n"

        if let dueDate = dueDate {
            text += "⏳ <b>Qaytarish muddati:</b> \(df.string(from: dueDate))\n"
        }

        if paid > 0 && !isSettled {
            text += "💵 <b>Qaytarildi:</b> \(CurrencyFormatter.string(paid, code: currency))\n"
            text += "⚖️ <b>Qolgan qarz:</b> \(CurrencyFormatter.string(remaining, code: currency))\n"
        }

        text += "📌 <b>Holati:</b> \(isSettled ? "✅ Toʻliq yopilgan" : "⏳ Qaytarilishi kutilmoqda")\n"

        if let note = note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "📝 <b>Izoh:</b> \(note.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }

        text += "\n📱 <i>FinanceApp orqali yuborildi</i>"
        return text
    }

    /// Telegram orqali ulashish URL havolasini qaytaradi (t.me/share/url).
    static func debtShareURL(person: String,
                             amount: Double,
                             paid: Double,
                             type: DebtType,
                             isSettled: Bool,
                             date: Date,
                             dueDate: Date?,
                             currency: String,
                             note: String?) -> URL? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "uz_UZ")
        df.dateFormat = "d-MMMM, yyyy"

        let isLend = type == .lend
        let remaining = max(amount - paid, 0)

        var text = "🤝 Qarz maʼlumoti (Eslatma)\n\n"
        text += isLend ? "👤 Kimga: \(person)\n" : "👤 Kimdan: \(person)\n"
        text += "💰 Qarz summasi: \(CurrencyFormatter.string(amount, code: currency))\n"
        text += "🗓 \(isLend ? "Qarz berilgan sana" : "Qarz olingan sana"): \(df.string(from: date))\n"

        if let dueDate = dueDate {
            text += "⏳ Qaytarish muddati: \(df.string(from: dueDate))\n"
        }

        if paid > 0 && !isSettled {
            text += "💵 Qaytarildi: \(CurrencyFormatter.string(paid, code: currency))\n"
            text += "⚖️ Qolgan qarz: \(CurrencyFormatter.string(remaining, code: currency))\n"
        }

        text += "📌 Holati: \(isSettled ? "✅ Toʻliq yopilgan" : "⏳ Qaytarilishi kutilmoqda")\n"

        if let note = note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "📝 Izoh: \(note.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }

        text += "\n📱 FinanceApp orqali yuborildi"

        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://t.me/share/url?url=&text=\(encoded)")
    }
}
