import XCTest
import Foundation
import CryptoKit
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

final class MappingPackageTests: XCTestCase {
    private let revision = String(repeating: "A", count: 43)

    private func package(subjects: [[String: Any]]? = nil, teacherContexts: [[String: Any]]? = nil,
                         corruptDigest: Bool = false, extraEntry: Bool = false) throws -> Data {
        var rules: [String: Any] = [
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
        if let teacherContexts { rules["teacherContexts"] = teacherContexts }
        let mapping = try JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        let sha = SHA256.hash(data: mapping).map { String(format: "%02x", $0) }.joined()
        let manifest: [String: Any] = [
            "schemaVersion": teacherContexts == nil ? 1 : 2,
            "version": "v1", "publishedAt": "2032-01-02T03:04:05Z",
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
            matchedByRule: { subject, className, _ in saved.rules.isInternationalStudentSubject(subject, className: className) }))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: true,
            matchedByRule: { subject, className, _ in saved.rules.isInternationalStudentSubject(subject, className: className) }))
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

    func testContextualTeacherSplitsOnlyMatchingYearClassAndSubject() throws {
        let context: [String: Any] = [
            "alias": "架空姓", "fullName": "架空正式教員B", "subject": "架空正式科目A",
            "className": "3_IT", "schoolYear": 2032,
        ]
        let saved = try MappingPackage.decode(package(teacherContexts: [context]),
                                              version: "v1", revision: revision, archiveETag: "\"zip\"")
        XCTAssertEqual(saved.schemaVersion, 2)
        func change(_ date: String, _ className: String, _ subject: String) -> ScheduleChange {
            ScheduleChange(change_date: date, class_name: className, period: "1",
                           before_subject: "", after_subject: subject, teacher: "", room: "",
                           note: "変更", raw_text: "", canonical_text: "")
        }
        let source = "架空略科A（架空姓）"
        let matched = saved.rules.presenting(change("2032-10-01", "3_IT", source)).after
        XCTAssertEqual(matched.cellSubject, "架空略科A")
        XCTAssertEqual(matched.cellTeacher, "架空姓")
        XCTAssertEqual(matched.detailTeacher, "架空正式教員B")
        for unrelated in [change("2033-10-01", "3_IT", source),
                          change("2032-10-01", "3_CN", source),
                          change("2032-10-01", "3_IT", "架空別科目（架空姓）")] {
            let names = saved.rules.presenting(unrelated).after
            XCTAssertEqual(names.cellSubject, unrelated.after_subject)
            XCTAssertTrue(names.cellTeacher.isEmpty)
        }
    }

    func testChangeShortSubjectUsesOnlyOneAliasFromSameClass() throws {
        let saved = try MappingPackage.decode(package(), version: "v1",
                                              revision: revision, archiveETag: "\"zip\"")
        let change = ScheduleChange(change_date: "2032-10-01", class_name: "3_IT", period: "1",
                                    before_subject: "", after_subject: "架空正式科目A", teacher: "", room: "",
                                    note: "変更", raw_text: "", canonical_text: "")
        func lesson(_ className: String, _ subject: String) -> PDFLesson {
            PDFLesson(className: className, weekday: 1, period: 1,
                      names: TimetableLessonNames(subject: subject), sourceText: subject, page: 1)
        }
        XCTAssertEqual(saved.rules.shortSubject(for: change, in: [
            lesson("3_IT", "架空略科A"), lesson("3_CN", "架空略科B")
        ]), "架空略科A")
        var withTeacher = change
        withTeacher.after_subject = "架空正式科目A（架空教員A）"
        XCTAssertEqual(saved.rules.shortSubject(for: withTeacher, in: [
            lesson("3_IT", "架空略科A")
        ]), "架空略科A")
        XCTAssertNil(saved.rules.shortSubject(for: change, in: [lesson("3_CN", "架空略科A")]))
        let ambiguous = try MappingPackage.decode(package(subjects: [
            ["alias": "架空略科A", "fullName": "架空正式科目A"],
            ["alias": "架空略科B", "fullName": "架空正式科目A"],
        ]), version: "v1", revision: revision, archiveETag: "\"zip\"")
        XCTAssertNil(ambiguous.rules.shortSubject(for: change, in: [
            lesson("3_IT", "架空略科A"), lesson("3_IT", "架空略科B")
        ]))
    }
    func testScopedInternationalRuleSurvivesGenericExactAliasBeforeLessonReplacement() throws {
        let scoped: [String: Any] = ["alias": "留 架空科目A", "fullName": "架空科目A", "classes": ["3_IT"], "internationalStudent": true]
        let generic: [String: Any] = ["alias": "架空科目A", "fullName": "架空科目A"]
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        for rows in [[generic], [scoped], [generic, scoped], [scoped, generic]] {
            let rules = try MappingPackage.decode(package(subjects: rows), version: "v1", revision: revision, archiveETag: "\"zip\"").rules
            for cls in ["3_IT", "2_IT"] {
                let hidden = cls == "3_IT" && rows.contains { $0["internationalStudent"] as? Bool == true }
                XCTAssertEqual(rules.isInternationalStudentSubject("架空科目A", className: cls), hidden)
                for kind in ["休講", "補講", "変更"] {
                    let row = ScheduleChange(change_date: day.iso8601, class_name: cls, period: "1", before_subject: "", after_subject: "架空科目A", teacher: "", room: "", note: "架空備考A", raw_text: "", canonical_text: "", change_kind: kind)
                    let timetable = PDFAnalysis(kind: .timetable, sourceDigest: "fictional", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032, term: "前期", lessons: [PDFLesson(className: cls, weekday: 1, period: 1, names: TimetableLessonNames(subject: "架空一般科目B"), sourceText: "", page: 1)], events: [], notices: [])
                    let schedule = TimetableDaySchedule(timetable: timetable, changes: ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: [row]), events: nil, specials: [], includesChanges: true)
                    for international in [false, true] {
                        let block = try XCTUnwrap(schedule.blocks(on: day, className: cls, international: international, matchedByRule: { rules.isInternationalStudentChangeField($0, className: $1, schoolYear: $2) }).first)
                        if hidden && !international {
                            guard case .normal(let normal) = block.content else { return XCTFail("Hidden change must preserve the ordinary lesson") }
                            XCTAssertEqual(normal.names.subject, "架空一般科目B")
                        } else {
                            guard case .change(let actual) = block.content else { return XCTFail("Expected explicit change") }
                            XCTAssertEqual(actual, row)
                        }
                    }
                }
            }
        }
    }

    private final class RepairProtocol: URLProtocol {
        static var payload = Data()
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let url = request.url, ["mapping.example.test", "failure.example.test", "invalid.example.test"].contains(url.host ?? "") else {
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
            }
            let revision = String(repeating: "A", count: 43)
            let checking = url.path == "/mapping-revision"
            if checking { precondition(request.value(forHTTPHeaderField: "If-None-Match") == nil) }
            let status = url.host == "failure.example.test" ? 503 : checking ? 200 :
                request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-token" ? 200 : 401
            let headers = checking ? ["ETag": "\"\(revision)\""] : ["Content-Type": "application/zip", "X-Mapping-Version": "v1", "X-Mapping-Revision": revision, "ETag": "\"zip\""]
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: checking ? Data() : url.host == "invalid.example.test" ? Data("fictional invalid archive".utf8) : Self.payload)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    @MainActor
    func testCorruptMappingPayloadAllowsRepairAndFailuresPreserveItsBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root); RepairProtocol.payload = Data() }
        let file = root.appendingPathComponent("mappings.sqlite")
        _ = try MappingStore(url: file)
        let queue = try DatabaseQueue(path: file.path)
        let bytes = Data("{fictional corrupt mapping".utf8)
        try queue.write { try $0.execute(sql: "INSERT INTO currentMapping (id,payload) VALUES (1,?)", arguments: [bytes]) }
        func preserved() throws { XCTAssertEqual(try queue.read { try Data.fetchOne($0, sql: "SELECT payload FROM currentMapping WHERE id=1") }, bytes) }
        RepairProtocol.payload = try package()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RepairProtocol.self]
        let network = URLSession(configuration: config); defer { network.invalidateAndCancel() }
        for (host, token) in [("failure.example.test", "synthetic-token"), ("invalid.example.test", "synthetic-token"), ("mapping.example.test", "invalid-token")] {
            let model = MappingModel(directory: root, baseURL: URL(string: "https://\(host)")!)
            model.loadIfNeeded(); XCTAssertTrue(model.ready); XCTAssertTrue(model.failed); XCTAssertNil(model.current)
            try preserved()
            do { try await model.download(token: token, revision: revision, network: network); XCTFail("Invalid response must not replace cache") } catch { }
            try preserved(); XCTAssertNil(model.current)
        }
        let model = MappingModel(directory: root, baseURL: URL(string: "https://mapping.example.test")!)
        model.loadIfNeeded()
        let result = try await model.revision(using: network)
        XCTAssertEqual(result, .available(revision)); try preserved()
        try queue.write { try $0.execute(sql: "CREATE TRIGGER fictional_save_failure BEFORE INSERT ON currentMapping BEGIN SELECT RAISE(ABORT,'fictional failure'); END") }
        do { try await model.download(token: "synthetic-token", revision: revision, network: network); XCTFail("Failed save must not replace cache") } catch { }
        try preserved(); XCTAssertNil(model.current)
        try queue.write { try $0.execute(sql: "DROP TRIGGER fictional_save_failure") }
        try await model.download(token: "synthetic-token", revision: revision, network: network)
        XCTAssertFalse(model.failed); XCTAssertNotNil(model.current)
        let reopened = MappingModel(directory: root); reopened.loadIfNeeded()
        XCTAssertTrue(reopened.ready); XCTAssertFalse(reopened.failed); XCTAssertEqual(reopened.current?.revision, revision)
        let blocked = root.appendingPathComponent("blocked"); try Data([1]).write(to: blocked)
        let unavailable = MappingModel(directory: blocked); unavailable.loadIfNeeded()
        XCTAssertFalse(unavailable.ready); XCTAssertTrue(unavailable.failed)
    }

}
