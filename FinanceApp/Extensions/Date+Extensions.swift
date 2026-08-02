import Foundation

extension Calendar {
    /// Berilgan davr uchun joriy interval [start, end) qaytaradi.
    func currentInterval(for period: PeriodType, reference: Date) -> DateInterval {
        switch period {
        case .daily:
            let start = startOfDay(for: reference)
            return DateInterval(start: start, end: date(byAdding: .day, value: 1, to: start)!)
        case .weekly:
            let start = dateInterval(of: .weekOfYear, for: reference)?.start ?? reference
            return DateInterval(start: start, end: date(byAdding: .weekOfYear, value: 1, to: start)!)
        case .monthly:
            let start = dateInterval(of: .month, for: reference)?.start ?? reference
            return DateInterval(start: start, end: date(byAdding: .month, value: 1, to: start)!)
        case .yearly:
            let start = dateInterval(of: .year, for: reference)?.start ?? reference
            return DateInterval(start: start, end: date(byAdding: .year, value: 1, to: start)!)
        }
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// "2-avg" yoki "Bugun" kabi qisqa koʻrinish.
    var relativeShort: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Bugun" }
        if cal.isDateInYesterday(self) { return "Kecha" }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
