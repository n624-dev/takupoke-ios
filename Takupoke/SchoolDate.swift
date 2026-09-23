import Foundation

/// A calendar day without a time or device time zone. Timetable applicability
/// must be supplied explicitly; a school year or term label is not a date range.
struct SchoolDate: Codable, Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month) else { return nil }
        let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard (1...days[month - 1]).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    init?(iso8601: String) {
        let bytes = Array(iso8601.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              [0, 1, 2, 3, 5, 6, 8, 9].allSatisfy({ (48...57).contains(bytes[$0]) }) else { return nil }
        func number(_ indices: [Int]) -> Int {
            indices.reduce(0) { $0 * 10 + Int(bytes[$1] - 48) }
        }
        self.init(year: number([0, 1, 2, 3]), month: number([5, 6]), day: number([8, 9]))
    }

    var iso8601: String {
        func padded(_ value: Int, width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: width - digits.count) + digits
        }
        return "\(padded(year, width: 4))-\(padded(month, width: 2))-\(padded(day, width: 2))"
    }

    /// Japanese school years run from April 1 through the following March 31.
    var schoolYear: Int { month >= 4 ? year : year - 1 }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static var arithmeticCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func today(in timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return Self(year: parts.year!, month: parts.month!, day: parts.day!)!
    }

    func addingDays(_ count: Int) -> Self? {
        let calendar = Self.arithmeticCalendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let result = calendar.date(byAdding: .day, value: count, to: date) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: result)
        return Self(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Monday is 1; Sunday is 7.
    var schoolWeekday: Int {
        let calendar = Self.arithmeticCalendar
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    var monday: Self { addingDays(1 - schoolWeekday)! }

    /// The Web timetable opens the following week on Saturday and Sunday.
    var displayWeekStart: Self {
        schoolWeekday >= 6 ? addingDays(8 - schoolWeekday)! : monday
    }
}

/// The end boundary is exclusive. Callers must convert any stated final day
/// deliberately, with its source recorded alongside the adopted analysis.
struct SchoolDateRange: Codable, Hashable {
    let start: SchoolDate
    let endExclusive: SchoolDate

    init?(start: SchoolDate, endExclusive: SchoolDate) {
        guard start < endExclusive else { return nil }
        self.start = start
        self.endExclusive = endExclusive
    }

    func contains(_ date: SchoolDate) -> Bool {
        start <= date && date < endExclusive
    }

    func overlaps(_ other: Self) -> Bool {
        start < other.endExclusive && other.start < endExclusive
    }
}
