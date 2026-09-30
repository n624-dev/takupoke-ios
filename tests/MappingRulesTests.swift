import Foundation
import XCTest
@testable import TakupokeParsing

final class MappingRulesTests: XCTestCase {
    private func rules(teachers: [[String: Any]]? = nil, rooms: [[String: Any]]? = nil,
                       contexts: [[String: Any]] = []) throws -> MappingRules {
        let bytes = try JSONSerialization.data(withJSONObject: [
            "subjects": [["alias": "架空略科A", "fullName": "架空正式科目A"]],
            "teachers": teachers ?? [
                ["alias": "架空教員A", "fullName": "架空正式教員A"],
                ["alias": "架空教員B", "fullName": "架空正式教員B"],
            ],
            "rooms": rooms ?? [
                ["alias": "架空室A", "fullName": "架空正式教室A"],
                ["alias": "架空室B", "fullName": "架空正式教室B"],
                ["alias": "雨天時(架空室B)", "fullName": "雨天時：架空正式教室B"],
            ],
            "teacherContexts": contexts,
        ])
        return try JSONDecoder().decode(MappingRules.self, from: bytes)
    }

    private func change(_ subject: String, teacher: String = "", room: String = "",
                        className: String = "4_XY", date: String = "2032-10-01") -> ScheduleChange {
        ScheduleChange(change_date: date, class_name: className, period: "1", before_subject: "",
                       after_subject: subject, teacher: teacher, room: room, note: "変更",
                       raw_text: "", canonical_text: "")
    }

    func testNameMatchingAcceptsWidthVariantsAndKeepsSourceSpelling() throws {
        let bytes = try JSONSerialization.data(withJSONObject: [
            "subjects": [["alias": "架空ｺｰｽA", "fullName": "架空正式科目A", "classes": ["4_XY"]]],
            "teachers": [["alias": "架空教員A", "fullName": "架空正式教員A"]],
            "rooms": [["alias": "雨天時(架空室A)", "fullName": "雨天時：架空正式教室A"]],
        ])
        let rules = try JSONDecoder().decode(MappingRules.self, from: bytes)
        let source = TimetableLessonNames(subject: "架空コースＡ", teacher: "架空教員Ａ", room: "雨天時（架空室Ａ）")
        let presented = rules.applying(to: source, className: "4_XY")
        XCTAssertEqual(presented.detailSubject, "架空正式科目A")
        XCTAssertEqual(presented.detailTeacher, "架空正式教員A")
        XCTAssertEqual(presented.detailRoom, "雨天時：架空正式教室A")
        XCTAssertEqual(presented.subject, source.subject)
        XCTAssertEqual(presented.teacher, source.teacher)
        XCTAssertEqual(presented.room, source.room)
        XCTAssertEqual(rules.applying(to: source, className: "3_XY").detailSubject, source.subject)
    }

    func testWidthEquivalentAliasesDoNotResolveAnAmbiguousName() throws {
        let bytes = try JSONSerialization.data(withJSONObject: [
            "subjects": [], "teachers": [],
            "rooms": [
                ["alias": "架空室A", "fullName": "架空正式教室A"],
                ["alias": "架空室Ａ", "fullName": "架空別教室A"],
            ],
        ])
        let rules = try JSONDecoder().decode(MappingRules.self, from: bytes)
        XCTAssertEqual(rules.applying(to: TimetableLessonNames(subject: "", room: "架空室A"),
                                     className: "4_XY").detailRoom, "架空正式教室A")
        let unconfirmed = TimetableLessonNames(subject: "", room: " 架空室Ａ ")
        XCTAssertNil(rules.applying(to: unconfirmed, className: "4_XY").roomFullName)
    }

    func testClassSpecificWidthEquivalentSubjectPrecedesGenericExactAlias() throws {
        let bytes = try JSONSerialization.data(withJSONObject: [
            "subjects": [
                ["alias": "架空科目A", "fullName": "架空共通科目A"],
                ["alias": "架空科目Ａ", "fullName": "架空専用科目A", "classes": ["4_XY"]],
            ], "teachers": [], "rooms": [],
        ])
        let rules = try JSONDecoder().decode(MappingRules.self, from: bytes)
        let source = TimetableLessonNames(subject: "架空科目A")
        XCTAssertEqual(rules.applying(to: source, className: "4_XY").detailSubject, "架空専用科目A")
        XCTAssertEqual(rules.applying(to: source, className: "3_XY").detailSubject, "架空共通科目A")
    }


    func testCommaSeparatedTeachersAndRoomsMapMembersAndRetainSeparators() throws {
        let rules = try rules()
        for separator in [",", "，", "、"] {
            let source = TimetableLessonNames(subject: "架空略科A",
                teacher: "架空教員A" + separator + " 架空教員B",
                room: "架空室A" + separator + "雨天時（架空室B）")
            let names = rules.applying(to: source, className: "4_XY")
            XCTAssertEqual(names.detailTeacher, "架空正式教員A" + separator + " 架空正式教員B")
            XCTAssertEqual(names.detailRoom, "架空正式教室A" + separator + "雨天時：架空正式教室B")
            XCTAssertEqual(names.teacher, source.teacher)
            XCTAssertEqual(names.room, source.room)
            XCTAssertEqual(names.cellTeacher, source.cellTeacher)
            XCTAssertEqual(names.cellRoom, source.cellRoom)
        }
    }

    func testPartialMetadataKeepsUnknownNamesOrderWhitespaceAndEmptyMembers() throws {
        let rules = try rules()
        let source = TimetableLessonNames(subject: "架空略科A",
            teacher: "架空未登録A, 架空教員B , ,架空教員A",
            room: "架空室A,雨天時（架空未登録室）")
        let names = rules.applying(to: source, className: "4_XY")
        XCTAssertEqual(names.detailTeacher, "架空未登録A, 架空正式教員B , ,架空正式教員A")
        XCTAssertEqual(names.detailRoom, "架空正式教室A,雨天時（架空未登録室）")
        let unknown = TimetableLessonNames(subject: "", teacher: "架空未登録A,架空未登録B",
            teacherFullName: "保存済みの架空正式教員名")
        XCTAssertEqual(rules.applying(to: unknown, className: "4_XY").detailTeacher,
                       "保存済みの架空正式教員名")
    }

    func testWholeFieldAliasPrecedesMemberMappingAndSubjectIsNotSplit() throws {
        let rules = try rules(teachers: [
            ["alias": "架空教員A,架空教員B", "fullName": "架空合同担当A"],
            ["alias": "架空教員A", "fullName": "架空正式教員A"],
            ["alias": "架空教員B", "fullName": "架空正式教員B"],
        ])
        let source = TimetableLessonNames(subject: "架空略科A,架空科目B", teacher: "架空教員A,架空教員B")
        let names = rules.applying(to: source, className: "4_XY")
        XCTAssertEqual(names.detailTeacher, "架空合同担当A")
        XCTAssertEqual(names.detailSubject, source.subject)
        XCTAssertNil(names.subjectFullName)
    }

    func testChangeSuffixRequiresAllMembersToHaveOneConfirmedRole() throws {
        let rules = try rules()
        let source = "架空科目X（分野A）（架空教員A,架空教員B）（架空室A，架空室B）"
        let presented = rules.presenting(change(source)).after
        XCTAssertEqual(presented.subject, "架空科目X（分野A）")
        XCTAssertEqual(presented.detailTeacher, "架空正式教員A,架空正式教員B")
        XCTAssertEqual(presented.detailRoom, "架空正式教室A，架空正式教室B")
        for suffix in ["架空教員A,架空未登録A", "架空教員A,架空室A", "架空教員A,", "分野A,分野B"] {
            let unknown = "架空科目X（" + suffix + "）"
            XCTAssertEqual(rules.presenting(change(unknown)).after.subject, unknown)
            XCTAssertTrue(rules.presenting(change(unknown)).after.teacher.isEmpty)
        }
        let overlapping = try self.rules(rooms: [["alias": "架空教員A", "fullName": "架空教室A"]])
        XCTAssertEqual(overlapping.presenting(change("架空科目X(架空教員A)")).after.subject,
                       "架空科目X(架空教員A)")
    }

    func testContextualTeacherWithinListRequiresMatchingYearClassAndSubject() throws {
        let rules = try rules(contexts: [[
            "alias": "架空姓", "fullName": "架空正式教員C", "subject": "架空正式科目A",
            "className": "4_XY", "schoolYear": 2032,
        ]])
        let source = "架空略科A（架空教員A,架空姓）"
        let presented = rules.presenting(change(source)).after
        XCTAssertEqual(presented.subject, "架空略科A")
        XCTAssertEqual(presented.detailTeacher, "架空正式教員A,架空正式教員C")
        for unrelated in [change(source, className: "3_XY"), change(source, date: "2033-10-01"),
                          change("架空科目B（架空教員A,架空姓）")] {
            XCTAssertEqual(rules.presenting(unrelated).after.subject, unrelated.after_subject)
        }
        let explicit = rules.presenting(change("架空略科A", teacher: "架空教員A,架空姓",
                                               className: "3_XY")).after
        XCTAssertEqual(explicit.detailTeacher, "架空正式教員A,架空姓")
    }

    func testParentheticalCommaIsNotSplitAndBothChangeSidesAreMapped() throws {
        let rules = try rules()
        let nested = TimetableLessonNames(subject: "", room: "架空室A（架空室B,注記）")
        XCTAssertEqual(rules.applying(to: nested, className: "4_XY").detailRoom, nested.room)
        var source = change("架空略科A(架空教員B,架空教員A)")
        source.before_subject = "架空科目X（分野A）(架空教員A,架空教員B)"
        let presented = rules.presenting(source)
        XCTAssertEqual(presented.before.subject, "架空科目X（分野A）")
        XCTAssertEqual(presented.before.detailTeacher, "架空正式教員A,架空正式教員B")
        XCTAssertEqual(presented.after.detailTeacher, "架空正式教員B,架空正式教員A")
        XCTAssertEqual(source.after_subject, "架空略科A(架空教員B,架空教員A)")
    }
}
