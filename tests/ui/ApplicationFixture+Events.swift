import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

// Seed actual event files; user actions still run production fetch/decode/save.
// The separate probe launch omits this mutation to verify persisted repair.
enum SimulatorEventsCacheFixture {
    static func payload(year: Int, title: String) -> SchoolEventsPayload {
        SchoolEventsPayload(
            version: "v1", schoolYear: year, sourcePdfSha256: String(repeating: "c", count: 64),
            sourcePdfETag: "\"fictional-events-source\"",
            events: [
                .init(startDate: "\(year)-04-02", endDate: "\(year)-04-02", title: title, tag: "行事（授業あり）")
            ])
    }
    static func seed(_ base: URL) throws {
        let root = base.appendingPathComponent("SchoolEventsAPI", isDirectory: true)
        let store = try SchoolEventsStore(root: root)
        try store.save(payload(year: 2032, title: "架空正常行事2032"), apiETag: "\"fictional-events-old\"")
        try Data("{entirely-fictional-corrupt-event-json".utf8)
            .write(to: root.appendingPathComponent("events-2033.json"), options: .atomic)
    }
}

// An isolated date and actual saved files exercise year availability separately
// from whether this particular day has any events or lessons.
enum SimulatorEventsYearFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--events-year-coverage") }
    static let day = SchoolDate(year: 2033, month: 3, day: 31)!
    static func seed(_ base: URL) throws {
        let arguments = ProcessInfo.processInfo.arguments
        let noLessons = arguments.contains("--events-year-no-lessons")
        let library = try LocalMaterialDatabase.openLibrary(
            root: base.appendingPathComponent("SchoolMaterialsSQLite"))
        let state = library.state
        guard let source = state.record(for: .timetable), let changes = state.record(for: .changes) else {
            throw LocalMaterialDatabase.StoreError.invalidDatabase
        }
        let lesson = PDFLesson(
            className: "3_IT", weekday: noLessons ? 1 : day.schoolWeekday, period: 1,
            names: .init(subject: "架空年度確認科目A", teacher: "架空教員A", room: "架空教室A"), sourceText: "", page: 1)
        try library.savePDFAnalysis(
            PDFAnalysis(
                kind: .timetable, sourceDigest: source.digest,
                sourceName: source.originalName, parsedAt: Date(), schoolYear: 2032, term: "後期",
                lessons: [lesson], events: [], notices: []))
        // The no-classes guard requires a loaded change analysis. The store
        // requires a nonempty result; this other-day record cannot add a block
        // to the fixed day or its March/April boundary week.
        try library.saveChangeAnalysis(
            ChangeAnalysis(
                sourceDigest: changes.digest,
                sourceName: changes.originalName, defaultYear: 2032, parsedAt: Date(),
                records: [
                    ScheduleChange(
                        change_date: "2032-04-02", class_name: "3_IT", period: "1", before_subject: "",
                        after_subject: "架空別日変更A", teacher: "", room: "", note: "補講", raw_text: "",
                        canonical_text: "")
                ]))
        let root = base.appendingPathComponent("SchoolEventsAPI", isDirectory: true)
        let store = try SchoolEventsStore(root: root)
        // All these files belong to this reset, synthetic application fixture.
        for year in try store.loadAll().keys {
            try FileManager.default.removeItem(at: root.appendingPathComponent("events-\(year).json"))
        }
        let covered = arguments.contains("--events-year-current")
        let years = arguments.contains("--events-year-both") ? [2032, 2033] : [covered ? 2032 : 2031]
        for year in years {
            try store.save(SimulatorEventsCacheFixture.payload(year: year, title: "架空別日の年度確認行事\(year)"))
        }
    }
}

// Only the isolated test app uses these controls and metrics. Production
// sources are instrumented in the temporary project, not in the shipped app.

// Mutate only this reset fixture's real files before models open them. Keep
// complete originals for a later launch, rather than injecting ready flags.
enum SimulatorAuxiliaryStoreFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--auxiliary-store-failures") }
    static let roots = ["SpecialSchedulesSQLite", "SchoolEventsAPI"]
    static func prepare(_ base: URL) throws {
        let manager = FileManager.default
        for name in roots {
            let root = base.appendingPathComponent(name)
            let backup = base.appendingPathComponent("fixture-aux-backup-" + name)
            if ProcessInfo.processInfo.arguments.contains("--reset-fixture"),
               manager.fileExists(atPath: backup.path) {
                try manager.removeItem(at: backup)
            }
            if enabled {
                guard !manager.fileExists(atPath: backup.path) else { continue }
                try manager.moveItem(at: root, to: backup)
                if name == "SpecialSchedulesSQLite" {
                    try manager.copyItem(at: backup, to: root)
                    // Use a non-SQLite formal file with the original PDFs kept.
                    for suffix in ["-wal", "-shm", "-journal"] {
                        let sidecar = root.appendingPathComponent("specials.sqlite" + suffix)
                        if manager.fileExists(atPath: sidecar.path) { try manager.removeItem(at: sidecar) }
                    }
                    try Data("fictional-invalid-special-sqlite".utf8)
                        .write(to: root.appendingPathComponent("specials.sqlite"), options: .atomic)
                } else {
                    // An actual file obstructs directory enumeration/open.
                    try Data("fictional-unavailable-event-directory".utf8).write(to: root)
                }
            } else if manager.fileExists(atPath: backup.path) {
                // This is the obstruction we own, never a production data root.
                try manager.removeItem(at: root)
                try manager.moveItem(at: backup, to: root)
            }
        }
    }
}
