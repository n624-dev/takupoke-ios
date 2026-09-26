import Foundation
import XCTest
import GRDB
@testable import TakupokeParsing

final class LocalDatabaseTests: XCTestCase {
    var root: URL!
    let time = Date(timeIntervalSince1970: 2_000_000_000)
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    var legacy: URL { root.appendingPathComponent("legacy") }
    var candidates: URL { root.appendingPathComponent("candidates") }

    func fixture() throws -> MaterialLibraryState {
        let files = legacy.appendingPathComponent("files")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        var state = MaterialLibraryState()
        state.folder = SourceGrant(bookmark: Data([0, 1, 2]), name: "架空フォルダ", isFolder: true)
        for kind in MaterialKind.allCases {
            let bytes = Data("entirely synthetic \(kind.rawValue) bytes".utf8)
            let record = MaterialRecord(kind: kind,
                source: MaterialSource(grant: nil, childName: "架空資料", remoteURL: nil),
                originalName: "架空資料.\(kind.fileExtension)", storedName: "\(UUID().uuidString).\(kind.fileExtension)",
                byteCount: bytes.count, digest: "synthetic-\(kind.rawValue)", sourceModifiedAt: nil,
                acquiredAt: time, lastCheckedAt: time)
            try bytes.write(to: files.appendingPathComponent(record.storedName))
            state.records.append(record)
            state.attempts[kind.rawValue] = AcquisitionAttempt(date: time, failure: nil)
        }
        let lessons = ["架空科目A", "架空科目B"].map {
            PDFLesson(className: "架空組", weekday: 1, period: 1,
                names: TimetableLessonNames(subject: $0, teacher: "架空教員A", room: ""),
                sourceText: "架空原文", page: 1)
        }
        state.pdfAnalyses = [
            "timetable": PDFAnalysis(kind: .timetable, sourceDigest: "synthetic-timetable", sourceName: "架空資料.pdf",
                parsedAt: time, schoolYear: 2033, term: "前期", lessons: lessons, events: [], notices: []),
            "events": PDFAnalysis(version: 4, kind: .events, sourceDigest: "synthetic-events", sourceName: "架空行事.pdf",
                parsedAt: time, schoolYear: 2033, term: nil, lessons: [],
                events: [PDFSchoolEvent(date: "2033-04-11", scope: "共通", title: "架空行事A", page: 1)], notices: [])
        ]
        state.changeAnalysis = ChangeAnalysis(sourceDigest: "synthetic-changes", sourceName: "架空変更.xlsx",
            defaultYear: 2033, parsedAt: time, records: [ScheduleChange(change_date: "2033-04-11",
                class_name: "架空組", period: "1,2", before_subject: "架空科目A", after_subject: "架空科目C",
                teacher: "架空教員B", room: "架空室B", note: "架空備考", raw_text: "架空原文", canonical_text: "架空正規化文")])
        state.changeParseAttempt = ChangeParseAttempt(date: time, sourceDigest: "synthetic-changes",
            defaultYear: 2033, failure: ChangeParseError(code: .storage))
        state.pdfParseAttempts = ["timetable": PDFParseAttempt(date: time, sourceDigest: "synthetic-timetable", failure: nil)]
        try save(state)
        return state
    }

    func save(_ state: MaterialLibraryState) throws {
        try LocalMaterialDatabase.encode(state).write(to: legacy.appendingPathComponent("library.json"), options: .atomic)
    }

    func prepare() throws -> URL {
        try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: candidates)
    }

    var runtime: URL { root.appendingPathComponent("runtime") }

    func runtimeStore() throws -> (LocalMaterialDatabase, MaterialLibrary) {
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: false)
        let db = try LocalMaterialDatabase(url: runtime.appendingPathComponent("library.sqlite"), create: true)
        try db.initializeCurrentLibrary()
        return (db, try MaterialLibrary(root: runtime, persistence: db))
    }

    func acquire(_ library: MaterialLibrary, kind: MaterialKind, suffix: String = "") throws {
        let staged = library.newStagingURL()
        let bytes = Data("entirely synthetic \(kind.rawValue) bytes \(suffix)".utf8)
        try bytes.write(to: staged)
        try library.commit(staged: staged, kind: kind,
            source: MaterialSource(grant: nil, childName: nil,
                                   remoteURL: kind == .events ? URL(string: "https://example.invalid/calendar.pdf") : nil),
            originalName: "架空資料.\(kind.fileExtension)", byteCount: bytes.count,
            digest: "synthetic-\(kind.rawValue)\(suffix)", modifiedAt: nil)
    }


}
