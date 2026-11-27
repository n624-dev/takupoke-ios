import Foundation

struct MappingRules: Codable, Equatable {
    static let maximumRuleCount = 10_000
    let subjects: [MappingRule]
    let teachers: [MappingRule]
    let rooms: [MappingRule]
    let teacherContexts: [TeacherContextRule]

    enum MetadataKind: Equatable { case teacher, room }
    private struct AliasIndex {
        let rules: [MappingRule]
        let indices: [String: [Int]]

        init(_ rules: [MappingRule]) {
            self.rules = rules
            indices = Dictionary(grouping: rules.indices, by: { MappingRules.comparable(rules[$0].alias) })
        }

        func match(_ alias: String, className: String?) -> String? {
            guard !alias.isEmpty, let indices = indices[MappingRules.comparable(alias)] else { return nil }
            let eligible = indices.map { rules[$0] }.filter { rule in
                rule.classes == nil || className.map { rule.classes?.contains($0) == true } == true
            }
            let specific = eligible.filter { $0.classes != nil }
            let preferred = specific.isEmpty ? eligible : specific
            let exact = preferred.filter { $0.alias == alias }
            let names = Set((exact.isEmpty ? preferred : exact).map(\.fullName))
            return names.count == 1 ? names.first : nil
        }
    }
    private struct SubjectMatch {
        let rule: Int
        let direct: Bool
        let canonicalName: String
    }
    private struct TeacherContextKey: Hashable {
        let alias: String
        let subject: String
        let className: String
        let schoolYear: Int
    }
    private let subjectsByAlias: AliasIndex
    private let teachersByAlias: AliasIndex
    private let roomsByAlias: AliasIndex
    private let subjectIndex: [String: [SubjectMatch]]
    private let teacherContextIndex: [TeacherContextKey: [Int]]

    private enum CodingKeys: String, CodingKey { case subjects, teachers, rooms, teacherContexts }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        subjects = try values.decode([MappingRule].self, forKey: .subjects)
        teachers = try values.decode([MappingRule].self, forKey: .teachers)
        rooms = try values.decode([MappingRule].self, forKey: .rooms)
        teacherContexts = try values.decodeIfPresent([TeacherContextRule].self, forKey: .teacherContexts) ?? []
        guard subjects.count + teachers.count + rooms.count + teacherContexts.count <= Self.maximumRuleCount else {
            throw MappingError.invalidPackage
        }
        subjectsByAlias = AliasIndex(subjects)
        teachersByAlias = AliasIndex(teachers)
        roomsByAlias = AliasIndex(rooms)
        var index: [String: [SubjectMatch]] = [:]
        for (position, subject) in subjects.enumerated() {
            let alias = Self.comparable(subject.alias)
            let canonicalName = Self.comparable(subject.fullName)
            let direct = Set([alias, canonicalName])
            for key in direct { index[key, default: []].append(.init(rule: position, direct: true, canonicalName: canonicalName)) }
            if subject.internationalStudent == true, alias.hasPrefix("留 ") {
                let short = String(alias.dropFirst(2))
                if !direct.contains(short) {
                    index[short, default: []].append(.init(rule: position, direct: false, canonicalName: canonicalName))
                }
            }
        }
        subjectIndex = index
        let contexts = teacherContexts
        teacherContextIndex = Dictionary(grouping: contexts.indices) { position in
            let context = contexts[position]
            return TeacherContextKey(alias: Self.comparable(context.alias), subject: Self.comparable(context.subject),
                                     className: context.className, schoolYear: context.schoolYear)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.subjects == rhs.subjects && lhs.teachers == rhs.teachers &&
            lhs.rooms == rhs.rooms && lhs.teacherContexts == rhs.teacherContexts
    }

    func applying(to names: TimetableLessonNames, className: String) -> TimetableLessonNames {
        TimetableLessonNames(subject: names.subject, teacher: names.teacher, room: names.room,
            subjectFullName: subjectsByAlias.match(names.subject, className: className) ?? names.subjectFullName,
            teacherFullName: metadataName(names.teacher, in: .teacher) ?? names.teacherFullName,
            roomFullName: metadataName(names.room, in: .room) ?? names.roomFullName)
    }

    static func comparable(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Scope precedes spelling, as with ordinary mapping. Within that scope,
    /// direct source spelling wins over width matches and an omitted 留 prefix.
    private func subjectCandidates(_ source: String, className: String) -> [SubjectMatch] {
        let text = Self.comparable(source)
        guard !text.isEmpty, let matches = subjectIndex[text] else { return [] }
        let candidates = matches.filter {
            let rule = subjects[$0.rule]
            return rule.classes == nil || rule.classes?.contains(className) == true
        }
        let specific = candidates.filter { subjects[$0.rule].classes != nil }
        let scoped = specific.isEmpty ? candidates : specific
        let exact = scoped.filter {
            let rule = subjects[$0.rule]
            return rule.alias == source || rule.fullName == source
        }
        if !exact.isEmpty { return exact }
        let normalized = scoped.filter(\.direct)
        return normalized.isEmpty ? scoped : normalized
    }

    /// Resolve a class-specific canonical subject without changing source text.
    func canonicalSubject(_ source: String, className: String) -> String? {
        let names = Set(subjectCandidates(source, className: className).map(\.canonicalName))
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
        let candidates = subjectCandidates(alias, className: className)
        return !candidates.isEmpty && candidates.allSatisfy { subjects[$0.rule].internationalStudent == true }
    }

    func contextualTeacher(_ alias: String, subject: String, className: String, schoolYear: Int?) -> String? {
        guard let schoolYear, let canonical = canonicalSubject(subject, className: className) else { return nil }
        let key = TeacherContextKey(alias: Self.comparable(alias), subject: canonical, className: className, schoolYear: schoolYear)
        guard let indices = teacherContextIndex[key] else { return nil }
        let candidates = indices.map { teacherContexts[$0] }
        let exact = candidates.filter { $0.alias == alias }
        let names = Set((exact.isEmpty ? candidates : exact).map(\.fullName))
        return names.count == 1 ? names.first : nil
    }

    /// Preserve the source separators and unregistered names. Whole-field
    /// aliases take precedence over splitting a list of names.
    func metadataName(_ source: String, in kind: MetadataKind,
                      contextual: ((String) -> String?)? = nil) -> String? {
        let index = kind == .teacher ? teachersByAlias : roomsByAlias
        func resolve(_ value: String) -> String? {
            contextual?(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? index.match(value, className: nil)
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
    func confirmsMetadata(_ source: String, in kind: MetadataKind,
                          contextual: ((String) -> String?)? = nil) -> Bool {
        let index = kind == .teacher ? teachersByAlias : roomsByAlias
        func confirmed(_ value: String) -> Bool {
            contextual?(value.trimmingCharacters(in: .whitespacesAndNewlines)) != nil || index.match(value, className: nil) != nil
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
}
