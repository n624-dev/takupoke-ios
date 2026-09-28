import Foundation

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

    static func comparable(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolve a class-specific canonical subject without changing the stored source spelling.
    func canonicalSubject(_ source: String, className: String) -> String? {
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

    private func match(_ alias: String, in rules: [MappingRule], className: String? = nil) -> String? {
        guard !alias.isEmpty else { return nil }
        let matches = rules.filter { $0.alias == alias }
        if let className, let specific = matches.first(where: { $0.classes?.contains(className) == true }) {
            return specific.fullName
        }
        return matches.first(where: { $0.classes == nil })?.fullName
    }
}
