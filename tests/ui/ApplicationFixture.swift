import SwiftUI
import UIKit
import CryptoKit
import UserNotifications

final class FixtureNetwork: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Synthetic revision responses exercise saved/empty/update UI states.
        // Every other request is rejected; nothing reaches a production service.
        if let url = request.url, ["/mapping-revision", "/links-revision", "/timetable-times-revision"].contains(url.path) {
            let installed = request.value(forHTTPHeaderField: "If-None-Match")
            let changed = ProcessInfo.processInfo.arguments.contains("--updated-revisions")
            let status = installed != nil && !changed ? 304 : 200
            let etag = status == 304 ? installed! : "\"" + String(repeating: "Z", count: 43) + "\""
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["ETag": etag, "Cache-Control": "no-store"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

@main
struct SimulatorApplication: App {
    @State private var notificationProbe = "待機中"
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue
    init() {
        URLProtocol.registerClass(FixtureNetwork.self)
        do { try Self.seed() } catch { fatalError("Synthetic fixture initialization failed: \(error)") }
    }
    var body: some Scene {
        WindowGroup {
            ContentView().tint((MainColor(rawValue: mainColor) ?? .blue).color)
                .overlay {
                    if ProcessInfo.processInfo.arguments.contains("--notification-probe") {
                        Text(notificationProbe).accessibilityIdentifier("fixture-notification-result")
                    }
                }
                .task {
                    guard ProcessInfo.processInfo.arguments.contains("--notification-probe") else { return }
                    for _ in 0..<40 {
                        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
                        let changes = delivered.filter { $0.request.identifier == "takupoke.changes" }
                        if !changes.isEmpty { notificationProbe = changes[0].request.content.body; return }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    notificationProbe = "通知なし"
                }
        }
    }
    private static func seed() throws {
        let defaults = UserDefaults.standard
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let day = SchoolDate.today()
        let period = SchoolDataPeriod.current()
        if ProcessInfo.processInfo.arguments.contains("--reset-fixture") {
            try SchoolDataRetention(root: base).replace(with: period)
            if let domain = Bundle.main.bundleIdentifier { defaults.removePersistentDomain(forName: domain) }
        }
        defaults.set(!ProcessInfo.processInfo.arguments.contains("--setup"), forKey: "setupPresented")
        if ProcessInfo.processInfo.arguments.contains("--empty-fixture") { return }
        if !FileManager.default.fileExists(atPath: base.appendingPathComponent("fixture-seeded").path) || ProcessInfo.processInfo.arguments.contains("--reset-fixture") {
            try SchoolDataRetention(root: base).replace(with: period)
            defaults.set("3_IT", forKey: "timetableSelectedClasses")
            let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
            let staged = library.newStagingURL()
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0,y: 0,width: 200,height: 200))
            let raw = renderer.pdfData { context in context.beginPage(); ("架空の資料" as NSString).draw(at: CGPoint(x: 20,y: 20), withAttributes: nil) }
            try raw.write(to: staged)
            let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
            try library.commit(staged: staged, kind: .timetable, source: .init(grant: nil, childName: nil),
                               originalName: "fictional.pdf", byteCount: raw.count, digest: digest, modifiedAt: nil)
            let analysis = PDFAnalysis(kind: .timetable, sourceDigest: digest, sourceName: "fictional.pdf", parsedAt: Date(),
                schoolYear: period.schoolYear, term: period.half == 1 ? "前期" : "後期",
                lessons: (1...5).flatMap { weekday in (1...8).map { number in
                    PDFLesson(className: "3_IT", weekday: weekday, period: number,
                        names: .init(subject: "架空科目\(number <= 2 ? "A" : "B")", teacher: "架空教員A", room: "架空教室A"), sourceText: "", page: 1)
                } }, events: [], notices: [])
            try library.savePDFAnalysis(analysis)
            let monday = day.monday
            let changeDay = monday.addingDays(3)!
            let changeStaged = library.newStagingURL()
            try raw.write(to: changeStaged)
            try library.commit(staged: changeStaged, kind: .changes, source: .init(grant: nil, childName: nil),
                originalName: "fictional.xlsx", byteCount: raw.count, digest: digest, modifiedAt: nil)
            let change = ScheduleChange(change_date: changeDay.iso8601, class_name: "3_IT", period: "4,5",
                before_subject: "", after_subject: "架空変更A", teacher: "架空教員B", room: "架空教室B", note: "補講", raw_text: "", canonical_text: "")
            try library.saveChangeAnalysis(.init(sourceDigest: digest, sourceName: "fictional.xlsx", defaultYear: period.schoolYear,
                parsedAt: Date(), records: [change,
                    ScheduleChange(change_date: day.iso8601, class_name: "3_IT", period: "6", before_subject: "",
                        after_subject: "架空変更通知A", teacher: "", room: "", note: "変更", raw_text: "", canonical_text: "")]))
            let specialStore = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
            for (kind, offset, subject) in [(SpecialScheduleKind.exam, 1, "架空試験A"), (.examReturn, 2, "架空返却A")] {
                let date = monday.addingDays(offset)!.iso8601
                let staged = specialStore.newStagingURL()
                try raw.write(to: staged)
                let name = "fictional-\(kind.rawValue).pdf"
                let lessons = (1...2).map { n in SpecialScheduleLesson(date: date, className: "3_IT", period: n,
                    spanStart: 1, spanEnd: 2, timeRange: "08:00〜09:20", lines: [subject,"架空教員C","架空教室C"], page: 1) }
                let special = SpecialScheduleAnalysis(kind: kind, sourceDigest: digest, sourceName: name, parsedAt: Date(),
                    schoolYear: period.schoolYear,
                    // Keep the normal Thursday separate from special coverage, including
                    // weeks that straddle the April/October semester boundary.
                    coveredDates: ([offset] + Array(8...11)).map { monday.addingDays($0)!.iso8601 },
                    coveredClasses: ["3_IT"] + (1...16).map { "fictional_\($0)" },
                    periodTimes: Dictionary(uniqueKeysWithValues: (1...(kind == .exam ? 6 : 8)).map {
                        ($0, String(format: "%02d:00〜%02d:40", $0 + 7, $0 + 7))
                    }), lessons: lessons)
                try specialStore.save(staged: staged, analysis: special, originalName: name, byteCount: raw.count, digest: digest)
            }
            let eventDay = monday.addingDays(4)!.iso8601
            let events = SchoolEventsPayload(version: "v1", schoolYear: period.schoolYear, sourcePdfSha256: digest,
                sourcePdfETag: "\"fictional\"", events: [.init(startDate: eventDay, endDate: eventDay, title: "架空行事A", tag: "行事（授業なし）")])
            try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI")).save(events)

            let payload = LinksPayload(version: "v1", linksVersion: "sha256-" + String(repeating: "a",count: 64), categories: [
                .init(id: "fictional", label: "架空カテゴリ", sortOrder: 0, buttons: [
                    .init(id: "fictional-link", categoryId: "fictional", label: "架空リンクA", href: "https://fixture.example.test",
                          color: "blue", visible: true, sortOrder: 0, recommended: true, recommendationOrder: 0, searchAliases: [], searchTerms: "架空リンクA")])])
            try LinksStore(root: base.appendingPathComponent("LinksAPI")).save(.init(payload: payload, apiETag: "\"fictional\"", checkedAt: Date(), revision: String(repeating: "L", count: 43)))
            try LinkPreferencesStore().save(.init(favoriteIDs: ["fictional-link"]))
            let directory = base.appendingPathComponent("NameMappings")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let rules = try JSONDecoder().decode(MappingRules.self, from: Data("{\"subjects\":[],\"teachers\":[],\"rooms\":[],\"teacherContexts\":[]}".utf8))
            try MappingStore(url: directory.appendingPathComponent("mappings.sqlite")).save(.init(revision: String(repeating: "M", count: 43), version: "fictional", schemaVersion: 1,
                archiveETag: "\"fictional\"", archiveSHA256: String(repeating: "a", count: 64), publishedAt: "2032-04-01T00:00:00Z", fetchedAt: Date(), rules: rules))
            let times = TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601,
                periods: (1...8).map { .init(period: $0, start: String(format: "%02d:00", $0+7), end: String(format: "%02d:40", $0+7)) })])
            let timesDirectory = base.appendingPathComponent("TimetableTimes")
            try FileManager.default.createDirectory(at: timesDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(SavedTimetableTimes(revision: String(repeating: "T",count: 43), fetchedAt: Date(), data: times))
                .write(to: timesDirectory.appendingPathComponent("current.json"))
            try Data().write(to: base.appendingPathComponent("fixture-seeded"))
        }
        if ProcessInfo.processInfo.arguments.contains("--updated-changes") {
            let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
            var analysis = library.state.changeAnalysis!
            analysis.records[1].after_subject = "架空変更通知B"
            let data = Data("Synthetic updated XLSX fixture".utf8)
            let staged = library.newStagingURL()
            try data.write(to: staged)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            try library.commit(staged: staged, kind: .changes, source: .init(grant: nil, childName: nil),
                originalName: "fictional.xlsx", byteCount: data.count, digest: digest, modifiedAt: nil)
            analysis.sourceDigest = digest; analysis.parsedAt = Date()
            try library.saveChangeAnalysis(analysis)
        }
        if ProcessInfo.processInfo.arguments.contains("--failed-refresh") {
            let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
            try library.recordFailure(.changes, message: "架空の変更ファイル取得エラー")
            try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
                .recordFailure(PDFParseError(code: .unsupported), kind: .exam)
        }
    }
}
