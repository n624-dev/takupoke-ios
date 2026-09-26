import Foundation

enum MappingError: Error, LocalizedError {
    case invalidPackage, invalidResponse, authentication, unavailable, storage, changedDuringDownload

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "名称対応表の形式または整合性を確認できませんでした。"
        case .invalidResponse: return "名称対応表の配信応答を確認できませんでした。"
        case .authentication: return "認証を完了できませんでした。"
        case .unavailable: return "名称対応表を取得できませんでした。"
        case .storage: return "名称対応表を保存できませんでした。"
        case .changedDuringDownload: return "取得中に名称対応表が更新されました。もう一度お試しください。"
        }
    }
}

struct MappingRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let classes: [String]?
    let internationalStudent: Bool?
}

struct TeacherContextRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let subject: String
    let className: String
    let schoolYear: Int
}

struct ChangePresentation: Equatable {
    let before: TimetableLessonNames
    let after: TimetableLessonNames

    static func source(_ change: ScheduleChange) -> Self {
        Self(before: TimetableLessonNames(subject: change.before_subject),
             after: TimetableLessonNames(subject: change.after_subject,
                                         teacher: change.teacher, room: change.room))
    }
}

struct MappingRules: Codable, Equatable {
    let subjects: [MappingRule]
    let teachers: [MappingRule]
    let rooms: [MappingRule]
    let teacherContexts: [TeacherContextRule]

    private enum CodingKeys: String, CodingKey { case subjects, teachers, rooms, teacherContexts }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        subjects = try values.decode([MappingRule].self, forKey: .subjects)
        teachers = try values.decode([MappingRule].self, forKey: .teachers)
        rooms = try values.decode([MappingRule].self, forKey: .rooms)
        teacherContexts = try values.decodeIfPresent([TeacherContextRule].self, forKey: .teacherContexts) ?? []
    }

    func applying(to names: TimetableLessonNames, className: String) -> TimetableLessonNames {
        TimetableLessonNames(subject: names.subject, teacher: names.teacher, room: names.room,
            subjectFullName: match(names.subject, in: subjects, className: className) ?? names.subjectFullName,
            teacherFullName: match(names.teacher, in: teachers) ?? names.teacherFullName,
            roomFullName: match(names.room, in: rooms) ?? names.roomFullName)
    }

    private static func comparable(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolve a class-specific canonical subject without changing the stored source spelling.
    private func canonicalSubject(_ source: String, className: String) -> String? {
        let text = Self.comparable(source)
        guard !text.isEmpty else { return nil }
        let candidates = subjects.filter { rule in
            (rule.classes == nil || rule.classes?.contains(className) == true) &&
                (Self.comparable(rule.alias) == text || Self.comparable(rule.fullName) == text)
        }
        let specific = candidates.filter { $0.classes?.contains(className) == true }
        let names = Set((specific.isEmpty ? candidates : specific).map { Self.comparable($0.fullName) })
        return names.count == 1 ? names.first : nil
    }

    func shortSubject(for change: ScheduleChange, in lessons: [PDFLesson]) -> String? {
        let source = separatingChangeField(change.after_subject, className: change.displayClassName,
            schoolYear: SchoolDate(iso8601: change.change_date)?.schoolYear).subject
        guard let canonical = canonicalSubject(source, className: change.displayClassName) else { return nil }
        let candidates = Set(lessons.compactMap { lesson -> String? in
            guard lesson.className == change.displayClassName,
                  canonicalSubject(lesson.names.subject, className: lesson.className) == canonical else { return nil }
            return lesson.names.cellSubject
        })
        return candidates.count == 1 ? candidates.first : nil
    }

    private func contextualTeacher(_ alias: String, subject: String, className: String,
                                   schoolYear: Int?) -> String? {
        guard let schoolYear, let canonical = canonicalSubject(subject, className: className) else { return nil }
        let matches = Set(teacherContexts.filter {
            $0.alias == alias && $0.className == className && $0.schoolYear == schoolYear &&
                Self.comparable($0.subject) == canonical
        }.map(\.fullName))
        return matches.count == 1 ? matches.first : nil
    }

    private func presenting(_ names: TimetableLessonNames, className: String,
                            schoolYear: Int?) -> TimetableLessonNames {
        let standard = applying(to: names, className: className)
        return TimetableLessonNames(subject: names.subject, teacher: names.teacher, room: names.room,
            subjectFullName: standard.subjectFullName,
            teacherFullName: contextualTeacher(names.teacher, subject: names.subject,
                className: className, schoolYear: schoolYear) ?? standard.teacherFullName,
            roomFullName: standard.roomFullName)
    }

    func isInternationalStudentSubject(_ alias: String, className: String) -> Bool {
        guard !alias.isEmpty else { return false }
        func matching(_ rules: [MappingRule]) -> MappingRule? {
            rules.first(where: { $0.classes?.contains(className) == true }) ??
                rules.first(where: { $0.classes == nil })
        }
        if let exact = matching(subjects.filter({ $0.alias == alias })) {
            return exact.internationalStudent == true
        }
        let derived = subjects.filter { rule in
            rule.internationalStudent == true && rule.alias.hasPrefix("留 ") &&
                String(rule.alias.dropFirst(2)) == alias
        }
        return matching(derived)?.internationalStudent == true
    }

    /// Split only trailing metadata confirmed by the installed mapping. A
    /// subject component such as 「架空科目X（分野A）」 remains part of the subject.
    func separatingChangeField(_ source: String, className: String? = nil,
                               schoolYear: Int? = nil) -> TimetableLessonNames {
        var remaining = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var teacher = ""
        var room = ""
        while let closing = remaining.last, closing == ")" || closing == "）" {
            let opening: Character = closing == ")" ? "(" : "（"
            var depth = 0
            var openingIndex: String.Index?
            for index in remaining.indices.reversed() {
                let character = remaining[index]
                if character == closing { depth += 1 }
                else if character == opening {
                    depth -= 1
                    if depth == 0 { openingIndex = index; break }
                }
            }
            guard let openingIndex, depth == 0 else { break }
            let token = String(remaining[remaining.index(after: openingIndex)..<remaining.index(before: remaining.endIndex)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = String(remaining[..<openingIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let isTeacher = teachers.contains { $0.alias == token } ||
                (className.flatMap { contextualTeacher(token, subject: subject,
                    className: $0, schoolYear: schoolYear) } != nil)
            let isRoom = rooms.contains { $0.alias == token }
            guard isTeacher != isRoom else { break }
            if isTeacher {
                guard teacher.isEmpty else { break }
                teacher = token
            } else {
                guard room.isEmpty else { break }
                room = token
            }
            remaining = String(remaining[..<openingIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return TimetableLessonNames(subject: remaining, teacher: teacher, room: room)
    }

    func presenting(_ change: ScheduleChange) -> ChangePresentation {
        let className = change.displayClassName
        let schoolYear = SchoolDate(iso8601: change.change_date)?.schoolYear
        let before = separatingChangeField(change.before_subject, className: className, schoolYear: schoolYear)
        let inlineAfter = separatingChangeField(change.after_subject, className: className, schoolYear: schoolYear)
        let teacherConflict = !change.teacher.isEmpty && !inlineAfter.teacher.isEmpty &&
            change.teacher != inlineAfter.teacher
        let roomConflict = !change.room.isEmpty && !inlineAfter.room.isEmpty &&
            change.room != inlineAfter.room
        // A rare disagreement between two explicit source fields is left in
        // source form; the app must not silently discard either value.
        let after: TimetableLessonNames
        if teacherConflict || roomConflict {
            after = TimetableLessonNames(subject: change.after_subject,
                teacher: change.teacher, room: change.room)
        } else {
            after = TimetableLessonNames(subject: inlineAfter.subject,
                teacher: change.teacher.isEmpty ? inlineAfter.teacher : change.teacher,
                room: change.room.isEmpty ? inlineAfter.room : change.room)
        }
        return ChangePresentation(before: presenting(before, className: className, schoolYear: schoolYear),
                                  after: presenting(after, className: className, schoolYear: schoolYear))
    }

    private func match(_ alias: String, in rules: [MappingRule], className: String? = nil) -> String? {
        guard !alias.isEmpty else { return nil }
        let matches = rules.filter { $0.alias == alias }
        if let className, let specific = matches.first(where: { $0.classes?.contains(className) == true }) {
            return specific.fullName
        }
        return matches.first(where: { $0.classes == nil })?.fullName
    }
}

struct SavedMapping: Codable, Equatable {
    let revision: String
    let version: String
    let schemaVersion: Int
    let archiveETag: String
    let archiveSHA256: String
    let publishedAt: String
    let fetchedAt: Date
    let rules: MappingRules
}
