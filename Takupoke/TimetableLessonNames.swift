import Foundation

/// Names for one lesson, after parallel lessons have been separated.
/// Timetable PDF parsing may collapse a repeated halfwidth voicing mark in room;
/// the unmodified cell text remains available in PDFLesson.sourceText.
struct TimetableLessonNames: Codable, Equatable, Sendable {
    let subject: String
    let teacher: String
    let room: String
    let subjectFullName: String?
    let teacherFullName: String?
    let roomFullName: String?

    init(subject: String, teacher: String = "", room: String = "",
         subjectFullName: String? = nil, teacherFullName: String? = nil, roomFullName: String? = nil) {
        self.subject = subject
        self.teacher = teacher
        self.room = room
        self.subjectFullName = subjectFullName
        self.teacherFullName = teacherFullName
        self.roomFullName = roomFullName
    }

    // Match the Web timetable's choice of source names in cells and full names in details.
    // The persisted strings retain parentheses and whitespace even when a cell hides them.
    var cellSubject: String { Self.trim(subject) }
    var cellTeacher: String { Self.cellMetadata(teacher) }
    var cellRoom: String { Self.cellMetadata(room) }
    var detailSubject: String { Self.detail(subjectFullName, fallback: subject) }
    var detailTeacher: String { Self.detail(teacherFullName, fallback: teacher) }
    var detailRoom: String { Self.detail(roomFullName, fallback: room) }

    private static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func detail(_ fullName: String?, fallback: String) -> String {
        let fullName = trim(fullName ?? "")
        return fullName.isEmpty ? trim(fallback) : fullName
    }

    private static func cellMetadata(_ value: String) -> String {
        trim(value.replacingOccurrences(of: "[()（）]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression))
    }
}

enum TimetableDisplayText {
    static func className(_ value: String) -> String {
        kana(value).replacingOccurrences(of: "_", with: "-")
    }

    static func classNames(_ values: [String]) -> String {
        values.map(className).joined(separator: "・")
    }

    /// Convert halfwidth katakana only when presenting timetable data. Source
    /// names stay unchanged so exact mapping rules still match PDF aliases.
    static func kana(_ value: String) -> String {
        var result = ""
        var halfwidthRun = ""
        for scalar in value.unicodeScalars {
            if (0xFF61...0xFF9F).contains(scalar.value) {
                halfwidthRun.append(String(scalar))
            } else {
                if !halfwidthRun.isEmpty {
                    result += halfwidthRun.precomposedStringWithCompatibilityMapping
                    halfwidthRun = ""
                }
                result.append(String(scalar))
            }
        }
        if !halfwidthRun.isEmpty {
            result += halfwidthRun.precomposedStringWithCompatibilityMapping
        }
        return result
    }

    /// Use compact katakana only for a room label that does not fit a card.
    static func halfwidthKana(_ value: String) -> String {
        var result = ""
        var katakana = ""
        func appendRun() {
            if !katakana.isEmpty {
                result += katakana.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? katakana
                katakana = ""
            }
        }
        for scalar in value.unicodeScalars {
            if (0x30A0...0x30FF).contains(scalar.value) {
                katakana.append(String(scalar))
            } else {
                appendRun()
                result.append(String(scalar))
            }
        }
        appendRun()
        return result
    }

    static func continuous(_ value: String) -> String {
        kana(PDFDisplayText.continuous(value))
    }
}
