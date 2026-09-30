import Foundation

extension MappingRules {
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
            teacherFullName: metadataName(names.teacher, in: teachers, contextual: {
                contextualTeacher($0, subject: names.subject, className: className, schoolYear: schoolYear)
            }) ?? standard.teacherFullName,
            roomFullName: standard.roomFullName)
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
            let isTeacher = confirmsMetadata(token, in: teachers, contextual: { alias in
                className.flatMap { contextualTeacher(alias, subject: subject,
                    className: $0, schoolYear: schoolYear) }
            })
            let isRoom = confirmsMetadata(token, in: rooms)
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
}
