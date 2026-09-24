import XCTest
import Foundation
import CryptoKit
import ZIPFoundation
@testable import TakupokeParsing

final class MappingPackageTests: XCTestCase {
    private let revision = String(repeating: "A", count: 43)

    private func package(subjects: [[String: Any]]? = nil, corruptDigest: Bool = false,
                         extraEntry: Bool = false) throws -> Data {
        let rules: [String: Any] = [
            "subjects": subjects ?? [
                ["alias": "架空略科A", "fullName": "架空正式科目A"],
                ["alias": "架空略科A", "fullName": "架空専用科目A", "classes": ["4_XY"]],
            ],
            "teachers": [["alias": "架空教員A", "fullName": "架空正式教員A"]],
            "rooms": [
                ["alias": "架空室A", "fullName": "架空正式教室A"],
                ["alias": "留 架空室B", "fullName": "架空正式教室B", "internationalStudent": true],
            ],
        ]
        let mapping = try JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        let sha = SHA256.hash(data: mapping).map { String(format: "%02x", $0) }.joined()
        let manifest: [String: Any] = [
            "schemaVersion": 1, "version": "v1", "publishedAt": "2032-01-02T03:04:05Z",
            "mappings": ["sha256": corruptDigest ? String(repeating: "0", count: 64) : sha, "bytes": mapping.count],
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        let archive = try Archive(data: Data(), accessMode: .create)
        for (name, data) in [("manifest.json", manifestData), ("mappings.json", mapping)] +
            (extraEntry ? [("unexpected.txt", Data("x".utf8))] : []) {
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count),
                                 compressionMethod: .deflate) { position, size in
                data.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
        return try XCTUnwrap(archive.data)
    }

    func testValidatedPackageAppliesExactRulesWithoutChangingSourceNames() throws {
        let saved = try MappingPackage.decode(package(), version: "v1", revision: revision, archiveETag: "\"zip\"")
        let source = TimetableLessonNames(subject: "架空略科A", teacher: "架空教員A", room: "架空室A")
        let generic = saved.rules.applying(to: source, className: "3_XY")
        let specific = saved.rules.applying(to: source, className: "4_XY")
        XCTAssertEqual(generic.cellSubject, "架空略科A")
        XCTAssertEqual(generic.detailSubject, "架空正式科目A")
        XCTAssertEqual(specific.detailSubject, "架空専用科目A")
        XCTAssertEqual(specific.detailTeacher, "架空正式教員A")
        XCTAssertEqual(specific.detailRoom, "架空正式教室A")
        let international = TimetableLessonNames(subject: "", room: "留 架空室B")
        XCTAssertEqual(saved.rules.applying(to: international, className: "4_XY").detailRoom, "架空正式教室B")
        XCTAssertEqual(source.detailSubject, "架空略科A")
    }

    func testInvalidNewPackageCannotReplaceSavedPackage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MappingStore(url: directory.appendingPathComponent("mappings.sqlite"))
        let first = try MappingPackage.decode(package(), version: "v1", revision: revision, archiveETag: "\"zip\"")
        try store.save(first)
        XCTAssertThrowsError(try MappingPackage.decode(package(corruptDigest: true), version: "v1",
                                                       revision: revision, archiveETag: "\"zip\""))
        XCTAssertThrowsError(try MappingPackage.decode(package(extraEntry: true), version: "v1",
                                                       revision: revision, archiveETag: "\"zip\""))
        XCTAssertThrowsError(try MappingPackage.decode(package(), version: "v2", revision: revision,
                                                       archiveETag: "\"zip\""))
        XCTAssertEqual(try store.load(), first)
    }

    func testDuplicateExactRuleIsRejected() throws {
        let duplicates: [[String: Any]] = [
            ["alias": "架空略科A", "fullName": "架空正式科目A", "classes": ["4_XY"]],
            ["alias": "架空略科A", "fullName": "架空別名A", "classes": ["4_XY"]],
        ]
        XCTAssertThrowsError(try MappingPackage.decode(package(subjects: duplicates), version: "v1",
                                                       revision: revision, archiveETag: "\"zip\""))
    }

    func testInternationalStudentMarkerAlsoMatchesUnmarkedSubjectInMappedClass() throws {
        let subjects: [[String: Any]] = [
            ["alias": "留 架空科目A", "fullName": "架空正式科目A", "classes": ["4_XY"],
             "internationalStudent": true],
            ["alias": "架空科目B", "fullName": "架空正式科目B"],
        ]
        let saved = try MappingPackage.decode(package(subjects: subjects), version: "v1",
                                              revision: revision, archiveETag: "\"zip\"")
        XCTAssertTrue(saved.rules.isInternationalStudentSubject("留 架空科目A", className: "4_XY"))
        XCTAssertTrue(saved.rules.isInternationalStudentSubject("架空科目A", className: "4_XY"))
        XCTAssertFalse(saved.rules.isInternationalStudentSubject("架空科目A", className: "3_XY"))
        XCTAssertFalse(saved.rules.isInternationalStudentSubject("架空科目B", className: "4_XY"))
        XCTAssertFalse(saved.rules.isInternationalStudentSubject("架空科目C", className: "4_XY"))
        let lesson = PDFLesson(className: "4_XY", weekday: 1, period: 1,
                               names: TimetableLessonNames(subject: "架空科目A"), sourceText: "", page: 1)
        XCTAssertFalse(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: false,
            matchedByRule: { saved.rules.isInternationalStudentSubject($0, className: $1) }))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: true,
            matchedByRule: { saved.rules.isInternationalStudentSubject($0, className: $1) }))
    }

    func testChangeFieldSeparatesOnlyMappedTrailingTeacherAndRoom() throws {
        let saved = try MappingPackage.decode(package(), version: "v1",
                                              revision: revision, archiveETag: "\"zip\"")
        let extracted = saved.rules.separatingChangeField("架空科目X（分野A）（架空教員A）（架空室A）")
        XCTAssertEqual(extracted.subject, "架空科目X（分野A）")
        XCTAssertEqual(extracted.teacher, "架空教員A")
        XCTAssertEqual(extracted.room, "架空室A")
        let reversed = saved.rules.separatingChangeField("架空略科A(架空室A)(架空教員A)")
        XCTAssertEqual(reversed.subject, "架空略科A")
        XCTAssertEqual(reversed.teacher, "架空教員A")
        XCTAssertEqual(reversed.room, "架空室A")
        let unknown = saved.rules.separatingChangeField("架空科目X（分野A）（架空未登録A）")
        XCTAssertEqual(unknown.subject, "架空科目X（分野A）（架空未登録A）")
        XCTAssertEqual(unknown.teacher, "")
        XCTAssertEqual(unknown.room, "")
    }

    func testChangePresentationSeparatesBothSidesAndKeepsSourceFields() throws {
        let saved = try MappingPackage.decode(package(), version: "v1",
                                              revision: revision, archiveETag: "\"zip\"")
        let change = ScheduleChange(change_date: "2032-10-01", class_name: "3_XY", period: "1",
            before_subject: "架空科目X（分野A）（架空教員A）",
            after_subject: "架空略科A（架空教員A）（架空室A）", teacher: "", room: "",
            note: "", raw_text: "", canonical_text: "")
        let names = saved.rules.presenting(change)
        XCTAssertEqual(names.before.subject, "架空科目X（分野A）")
        XCTAssertEqual(names.before.detailTeacher, "架空正式教員A")
        XCTAssertEqual(names.after.cellSubject, "架空略科A")
        XCTAssertEqual(names.after.detailSubject, "架空正式科目A")
        XCTAssertEqual(names.after.detailTeacher, "架空正式教員A")
        XCTAssertEqual(names.after.detailRoom, "架空正式教室A")
        XCTAssertEqual(change.after_subject, "架空略科A（架空教員A）（架空室A）")
    }
}
