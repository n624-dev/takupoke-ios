import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

// Only the clock input crosses the boundary. The settings change, real Home
// body, onChange callback, production driver, and rendered label stay intact.
@MainActor enum SimulatorHomeBoundaryFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--home-clock-boundary") }
    static var current = SchoolEventsSourceStatus.date("2032-04-05T08:49:59.999+09:00")!
    static var armed: Date?
    static func crossIfArmed() {
        guard enabled, let value = armed else { return }
        armed = nil; current = value
    }
    static func changeSettingAcrossBoundary(ending: Bool) {
        armed = SchoolEventsSourceStatus.date(ending ? "2032-04-05T09:35:00.001+09:00" : "2032-04-05T08:50:00.001+09:00")!
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "timetableInternationalStudent"), forKey: "timetableInternationalStudent")
    }
    static func seed(_ base: URL) throws {
        let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
        guard let source = library.state.record(for: .timetable) else { throw SchoolEventsError.invalidResponse }
        try library.savePDFAnalysis(.init(kind: .timetable, sourceDigest: source.digest,
            sourceName: source.originalName, parsedAt: Date(), schoolYear: 2032, term: "前期",
            lessons: [.init(className: "3_IT", weekday: 1, period: 1,
                names: .init(subject: "架空境界確認科目A", teacher: "架空教員A", room: "架空教室A"),
                sourceText: "", page: 1)], events: [], notices: []))
    }
}

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
    static var fixedDayEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--auxiliary-store-day") }
    static var day: SchoolDate { SchoolDate.today().displayWeekStart }
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

enum SimulatorCountdownEventsFixture {
    private static let schoolNoticeStart = SchoolDate.today()
    private static let schoolNoticePeriods = [
        (offset: 0, id: "fictional-active-exam", title: "架空の試験期間A"),
        (offset: 8, id: "fictional-next-exam", title: "架空の試験期間B"),
        (offset: 14, id: "fictional-later-exam", title: "架空の試験期間C"),
    ]

    static func seedSchoolNotices(_ base: URL) throws {
        let store = try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI"))
        let observed = Date().addingTimeInterval(-5)
        let timestamp = ISO8601DateFormatter().string(from: observed)
        let source = String(repeating: "b", count: 64)
        let version = "sha256-" + String(repeating: "c", count: 64)
        let events = Dictionary(grouping: schoolNoticePeriods) { schoolNoticeStart.addingDays($0.offset)!.schoolYear }
        for (year, periods) in events {
            let payload = SchoolEventsPayload(schoolYear: year, sourcePdfSha256: source, sourcePdfETag: nil,
                identifiedEvents: periods.map { period in
                    let day = schoolNoticeStart.addingDays(period.offset)!.iso8601
                    return .init(eventId: period.id, title: period.title, tag: "テスト", ranges: [.init(startDate: day, endDate: day)])
                })
            let saved = SavedSchoolEvents(fetchedAt: observed, payload: payload, apiETag: nil, responseDataVersion: version,
                lastEventsCheckedAt: observed)
            try store.save(saved)
            let status = SchoolEventsSourceStatus(version: "v1", schoolYear: year, dataVersion: version,
                adoptedSourcePdfSha256: source, status: .matched, lastSuccessfulStatus: .matched,
                lastSuccessAt: timestamp, lastAttemptAt: timestamp, nextAttemptAt: nil, checking: false, stale: false)
            try store.saveSourceStatus(.init(receivedAt: observed, response: status, requestedTarget: .init(saved)))
        }
        try CountdownStore(root: base).save(CountdownLibrary(automatic: CountdownAutomatic(enabled: true)))
    }

    static func expectedSchoolNotices() -> [String: Date] {
        let prefix = CountdownNotice.prefix + "personal." + CountdownAutomatic.identity.uuidString + "."
        return Dictionary(uniqueKeysWithValues: schoolNoticePeriods.dropFirst().flatMap { period in
            let start = schoolNoticeStart.addingDays(period.offset)!
            return [7, 1].map { days in
                (prefix + "\(start.schoolYear):\(period.id).\(days)-20-0", start.addingDays(-days)!.dateInJapan(hour: 20)!)
            }
        })
    }

    @MainActor static func observeNativeReservation(_ center: UNUserNotificationCenter,
                                                    request: UNNotificationRequest, expected: Date) async throws {
        guard ProcessInfo.processInfo.arguments.contains("--countdown-school-notices") else {
            try await center.add(request)
            return
        }
        FixtureCITrace.mark("countdown-notice-reserve-begin")
        defer { FixtureCITrace.mark("countdown-notice-reserve-end") }
        let actual = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        if let actual {
            FixtureCITrace.mark(actual == expected ? "countdown-notice-reserve-trigger-matches" : "countdown-notice-reserve-trigger-mismatch")
        } else { FixtureCITrace.mark("countdown-notice-reserve-trigger-empty") }
        do {
            try await center.add(request)
            FixtureCITrace.mark("countdown-notice-reserve-accepted")
        } catch {
            let error = error as NSError
            let domain = error.domain == "UNErrorDomain" ? "un" : "other"
            let code = error.code < 0 ? "n\(error.code.magnitude)" : String(error.code)
            FixtureCITrace.mark("countdown-notice-reserve-error-\(domain)-\(code)")
            if [error.localizedDescription,error.localizedFailureReason ?? ""].contains(where: {
                $0.localizedCaseInsensitiveContains("source is not authorized")
            }) {
                FixtureCITrace.mark("countdown-notice-reserve-source-unauthorized")
            }
            throw error
        }
    }

    static func reply(to transport: URLProtocol) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        let today = SchoolDate.today()
        guard arguments.contains("--countdown-calendar"), let url = transport.request.url,
              url.host == "fixture.example.test", transport.request.httpMethod == "GET",
              ["/events", "/events/source-status"].contains(url.path),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items == [.init(name: "schoolYear", value: String(today.schoolYear)), .init(name: "format", value: "v2")] else { return false }
        let updated = arguments.contains("--countdown-calendar-update")
        let yearEnd = SchoolDate(year: today.schoolYear + 1, month: 3, day: 31)!
        let first = min(today.addingDays(updated ? 15 : 14)!, yearEnd.addingDays(-5)!)
        let later = first.addingDays(3)!
        let payload = SchoolEventsPayload(schoolYear: today.schoolYear, sourcePdfSha256: String(repeating: "b", count: 64),
            sourcePdfETag: nil, identifiedEvents: [
                .init(eventId: "fictional-class-exam-202", title: updated ? "架空訂正試験B" : "架空の分割試験A", tag: "テスト",
                    ranges: [.init(startDate: first.iso8601, endDate: first.iso8601),
                             .init(startDate: later.iso8601, endDate: later.addingDays(1)!.iso8601)]),
                .init(eventId: "fictional-return", title: "架空の採点返却", tag: "テスト返却",
                    ranges: [.init(startDate: first.iso8601, endDate: first.iso8601)])
            ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let body = try! encoder.encode(payload)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let tag = "W/\"\(hash)\""
        let isEvents = url.path == "/events"
        let date = Date().addingTimeInterval(-3)
        let difference = arguments.contains("--countdown-different-source")
        let formatter = ISO8601DateFormatter()
        let checking = arguments.contains("--countdown-source-checking")
        let status = SchoolEventsSourceStatus(version: "v1", schoolYear: today.schoolYear, dataVersion: "sha256-" + hash,
            adoptedSourcePdfSha256: payload.sourcePdfSha256, status: difference ? .source_differs : .matched,
            lastSuccessfulStatus: difference ? .source_differs : .matched, lastSuccessAt: formatter.string(from: date),
            lastAttemptAt: formatter.string(from: date), nextAttemptAt: formatter.string(from: date.addingTimeInterval(86_400)),
            checking: checking, stale: false)
        let notModified = isEvents && transport.request.value(forHTTPHeaderField: "If-None-Match") == tag
        var headers = ["Content-Type": "application/json"]
        if isEvents { headers["ETag"] = tag }
        let response = HTTPURLResponse(url: url, statusCode: notModified ? 304 : 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        transport.client?.urlProtocol(transport, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !notModified { transport.client?.urlProtocol(transport, didLoad: isEvents ? body : try! encoder.encode(status)) }
        transport.client?.urlProtocolDidFinishLoading(transport)
        return true
    }
}
