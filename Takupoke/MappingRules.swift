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
            teacherFullName: metadataName(names.teacher, in: teachers) ?? names.teacherFullName,
            roomFullName: metadataName(names.room, in: rooms) ?? names.roomFullName)
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

    /// Preserve the source separators and unregistered names. Whole-field
    /// aliases take precedence over splitting a list of names.
    func metadataName(_ source: String, in rules: [MappingRule],
                      contextual: ((String) -> String?)? = nil) -> String? {
        func resolve(_ value: String) -> String? {
            contextual?(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? match(value, in: rules)
        }
        if let name = resolve(source) { return name }
        let fields = metadataFields(source)
        guard fields.count > 1 else { return nil }
        var resolved = false
        let result = fields.map { field in
            guard let name = resolve(field.value) else { return field.value + field.separator }
            resolved = true
            let leading = field.value.prefix(while: { $0.isWhitespace })
            let trailing = String(field.value.reversed().prefix(while: { $0.isWhitespace }).reversed())
            return leading + name + trailing + field.separator
        }.joined()
        return resolved ? result : nil
    }

    /// Used only to identify a trailing XLSX field. Every nonempty member
    /// must be known before treating a subject suffix as teacher/room data.
    func confirmsMetadata(_ source: String, in rules: [MappingRule],
                          contextual: ((String) -> String?)? = nil) -> Bool {
        func confirmed(_ value: String) -> Bool {
            contextual?(value.trimmingCharacters(in: .whitespacesAndNewlines)) != nil || match(value, in: rules) != nil
        }
        if confirmed(source) { return true }
        let fields = metadataFields(source)
        return fields.count > 1 && fields.allSatisfy { confirmed($0.value) }
    }

    private func metadataFields(_ source: String) -> [(value: String, separator: String)] {
        var fields: [(value: String, separator: String)] = []
        var start = source.startIndex
        var depth = 0
        for index in source.indices {
            let character = source[index]
            if character == "(" || character == "（" { depth += 1 }
            else if character == ")" || character == "）" { depth = max(0, depth - 1) }
            else if depth == 0 && (character == "," || character == "，" || character == "、") {
                fields.append((String(source[start..<index]), String(character)))
                start = source.index(after: index)
            }
        }
        fields.append((String(source[start...]), ""))
        return fields
    }

    private func match(_ alias: String, in rules: [MappingRule], className: String? = nil) -> String? {
        guard !alias.isEmpty else { return nil }
        func uniqueName(_ candidates: [MappingRule]) -> String? {
            let names = Set(candidates.map(\.fullName))
            return names.count == 1 ? names.first : nil
        }
        let eligible = rules.filter { rule in
            rule.classes == nil || className.map { rule.classes?.contains($0) == true } == true
        }
        let normalized = Self.comparable(alias)
        let matches = eligible.filter { Self.comparable($0.alias) == normalized }
        let specific = matches.filter { $0.classes != nil }
        let preferred = specific.isEmpty ? matches : specific
        let exact = preferred.filter { $0.alias == alias }
        return uniqueName(exact.isEmpty ? preferred : exact)
    }
}
