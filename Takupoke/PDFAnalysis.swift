import Foundation

enum PDFDisplayText {
    /// Remove document line breaks for display, keeping the stored text intact.
    static func continuous(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined()
    }
}

struct PDFGlyph: Codable {
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var sourceLine: Int? = nil
    var sourceOrder: Int? = nil
    var cx: Double { x + width / 2 }
    var cy: Double { y + height / 2 }
}
struct PDFRule: Codable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    var horizontal: Bool { abs(y1 - y2) < 0.2 }
    var vertical: Bool { abs(x1 - x2) < 0.2 }
}
struct PDFPageLayout: Codable {
    var width: Double
    var height: Double
    var glyphs: [PDFGlyph]
    var lines: [PDFRule]
    var arrows: [PDFArrow]? = nil
}
struct PDFArrow: Codable { var x: Double; var top: Double; var bottom: Double }
struct PDFBox: Hashable {
    var left: Double
    var top: Double
    var right: Double
    var bottom: Double
}
/// A bounded, text-free snapshot of just the failing cell. Never include glyph
/// text, document names, digests, paths or the rest of the page in this type.
struct PDFCellGeometryDiagnostic: Codable, Equatable {
    struct Glyph: Codable, Equatable {
        var line: Int?
        var order: Int?
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }
    static let maximumGlyphs = 256
    var parserVersion: Int
    var width: Double
    var height: Double
    var totalGlyphs: Int
    var glyphs: [Glyph]

    init(_ input: [PDFGlyph], box: PDFBox) {
        parserVersion = PDFAnalysis.currentVersion(for: .timetable)
        width = box.right - box.left
        height = box.bottom - box.top
        totalGlyphs = input.count
        // Cell-local ranks preserve comparisons without disclosing page offsets.
        let lines = Dictionary(uniqueKeysWithValues: Set(input.compactMap(\.sourceLine)).sorted().enumerated().map { ($1, $0) })
        let orders = Dictionary(uniqueKeysWithValues: Set(input.compactMap(\.sourceOrder)).sorted().enumerated().map { ($1, $0) })
        glyphs = input.prefix(Self.maximumGlyphs).map {
            Glyph(line: $0.sourceLine.flatMap { lines[$0] }, order: $0.sourceOrder.flatMap { orders[$0] },
                  x: $0.x - box.left, y: $0.y - box.top, width: $0.width, height: $0.height)
        }
    }
}
struct PDFLesson: Codable, Equatable {
    var className: String
    var weekday: Int
    var period: Int
    var names: TimetableLessonNames
    var sourceText: String
    var page: Int
}
struct PDFSchoolEvent: Codable, Equatable {
    var date: String
    var scope: String
    var title: String
    var page: Int
    var endDate: String? = nil
    var periodNeedsReview: Bool = false
    var periodEvidence: String? = nil
    var classification: PDFEventClassification? = nil
    // Present only for the reviewed events API. Existing PDF classifications
    // keep their original behavior when this value is absent.
    var apiTag: String? = nil
}
struct PDFEventClassification: Codable, Equatable {
    enum EventType: String, Codable {
        case noClass = "NO_CLASS", weekdayOverride = "WEEKDAY_OVERRIDE", special = "SPECIAL"
        case supplementary = "SUPPLEMENTARY", schoolEventNoClass = "SCHOOL_EVENT_NO_CLASS"
    }
    var type: EventType
    var scheduleDay: Int? = nil
    var needsReview: Bool = false

    var label: String {
        switch type {
        case .noClass: return "授業なし"
        case .supplementary: return "補講日"
        case .schoolEventNoClass: return "校内行事（授業なし）"
        case .weekdayOverride:
            let days = [1: "月", 2: "火", 3: "水", 4: "木", 5: "金"]
            return days[scheduleDay ?? 0].map { "曜日振替（\($0)曜日授業）" } ?? "曜日振替（要確認）"
        case .special: return needsReview ? "分類を要確認" : "行事（授業の有無は未判定）"
        }
    }

    static func fromExplicitText(_ title: String) -> Self {
        let lines = title.components(separatedBy: .newlines).map(PDFSchoolParser.key)
        // Exact declarations only. Do not turn exams, ceremonies or
        // comments merely mentioning a break into an inferred cancellation.
        func declares(_ names: [String]) -> Bool {
            let words = names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            return lines.contains { $0.range(of: "^(?:" + words + ")(?=$|[（(/／])", options: .regularExpression) != nil }
        }
        let holidays = ["元日", "成人の日", "建国記念の日", "天皇誕生日", "春分の日", "昭和の日", "憲法記念日",
                        "みどりの日", "こどもの日", "子どもの日", "海の日", "山の日", "敬老の日", "秋分の日",
                        "スポーツの日", "文化の日", "勤労感謝の日", "振替休日", "国民の休日"]
        // These labels classify text already present in the PDF. No holiday dates
        // are calculated, fetched, or inserted into a calendar by this code.
        let noClass = declares(["臨時休業", "夏季休業", "冬季休業", "学年末休業", "休業日"] + holidays)
        let supplementary = declares(["補講日"])
        let schoolEvents = ["体育祭", "体育大会", "春季体育大会", "夏季体育大会", "秋季体育大会", "冬季体育大会",
                            "文化祭", "総合文化祭", "電波祭"]
        let schoolEvent = declares(schoolEvents.flatMap { [$0, $0 + "準備", $0 + "準備日"] })
        let pattern = try! NSRegularExpression(pattern: "(?:^([月火水木金])曜日授業$|【([月火水木金])曜日授業】)")
        let days = ["月": 1, "火": 2, "水": 3, "木": 4, "金": 5]
        var overrides: [Int] = []
        for line in lines {
            let ns = line as NSString
            for match in pattern.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                let range = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
                if let day = days[ns.substring(with: range)] { overrides.append(day) }
            }
        }
        // A break and an approved school event agree that regular lessons are
        // absent. Keep the more specific school-event tag in that combination.
        let categories = [noClass || schoolEvent, supplementary, !overrides.isEmpty].filter { $0 }.count
        if overrides.count > 1 || categories > 1 { return Self(type: .special, needsReview: true) }
        if schoolEvent { return Self(type: .schoolEventNoClass) }
        if noClass { return Self(type: .noClass) }
        if supplementary { return Self(type: .supplementary) }
        if let day = overrides.first { return Self(type: .weekdayOverride, scheduleDay: day) }
        return Self(type: .special)
    }
}
struct PDFAnalysis: Codable {
    static let parserVersion = 8
    // Timetable fixes must not ask users to reparse an unchanged calendar.
    static func currentVersion(for kind: MaterialKind) -> Int { kind == .events ? 4 : parserVersion }
    var version = parserVersion
    var kind: MaterialKind
    var sourceDigest: String
    var sourceName: String
    var parsedAt: Date
    var schoolYear: Int
    var term: String?
    var lessons: [PDFLesson]
    var events: [PDFSchoolEvent]
    var notices: [String]
}
