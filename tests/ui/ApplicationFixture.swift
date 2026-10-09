import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

final class FixtureNetwork: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Synthetic revision responses exercise saved/empty/update UI states.
        // Every other request is rejected; nothing reaches a production service.
        if ProcessInfo.processInfo.arguments.contains("--events-cache-corrupt") ||
            ProcessInfo.processInfo.arguments.contains("--events-cache-probe"),
           let url = request.url, url.host == "fixture.example.test", request.httpMethod == "GET",
           let yearText = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "schoolYear" })?.value,
           let year = Int(yearText), [2032, 2033].contains(year) {
            let payload = SimulatorEventsCacheFixture.payload(year: year, title: "架空行事更新\(year)")
            do {
                let bytes = try JSONEncoder().encode(payload)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                    headerFields: ["ETag": "\"fictional-events-\(year)\"", "Content-Type": "application/json", "Content-Length": String(bytes.count)])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: bytes)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
            return
        }
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
    @State private var notificationDeliveryProof = "待機中"
    @State private var recoveryOCRProbe = "OCR実行中"
    @State private var recoveryTableProbe = ""
    @State private var recoveryOffProbe = "未実行"
    @State private var applicationReady = false
    @State private var fixtureTypeSize: DynamicTypeSize = .large
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    init() {
        _ = FixtureNotificationDelivery.startedAt
        FixtureLaunchDiagnostics.record("init-enter")
        URLProtocol.registerClass(FixtureNetwork.self)
        FixtureLaunchDiagnostics.record("seed-enter")
        do { try Self.seed() } catch { fatalError("Synthetic fixture initialization failed: \(error)") }
        FixtureLaunchDiagnostics.record("seed-complete")
    }
    var body: some Scene {
        let _ = FixtureLaunchDiagnostics.record("scene-construction")
        WindowGroup {
            ContentView().environment(\.timeZone, JapaneseDateDisplay.timeZone).tint((MainColor(rawValue: mainColor) ?? .systemDefault).color)
                .onAppear { FixtureLaunchDiagnostics.record("content-appeared") }
                .modifier(FixtureTypeSize(enabled: ProcessInfo.processInfo.arguments.contains("--grid-probe") &&
                    !ProcessInfo.processInfo.arguments.contains("--system-text-size"),
                                          size: fixtureTypeSize))
                .overlay(alignment: .topTrailing) {
                    if ProcessInfo.processInfo.arguments.contains("--grid-probe") {
                        Menu("文字サイズ") {
                            ForEach(["標準", "小", "大", "最大"], id: \.self) { title in
                                Button(title) {
                                    fixtureTypeSize = ["小": .xSmall, "標準": .large,
                                                       "大": .xxxLarge, "最大": .accessibility5][title]!
                                }
                            }
                        }
                        .font(.system(size: 12)).accessibilityIdentifier("fixture-type-size")
                    }
                }
                .overlay(alignment: .topLeading) {
                    if applicationReady {
                        VStack {
                            Text("準備完了").font(.caption2)
                                .accessibilityIdentifier("fixture-ready")
                                .allowsHitTesting(false)
                            if ProcessInfo.processInfo.arguments.contains("--ai-feature-probe") {
                                Text(LocalAIFeaturePolicy.enabled ? "1" : "0").id(useAiFeatures)
                                    .font(.caption2).accessibilityIdentifier("fixture-stored-ai-permission")
                                    .allowsHitTesting(false)
                                Text(recoveryOffProbe).font(.caption2)
                                    .accessibilityIdentifier("fixture-recovery-off-blocked").allowsHitTesting(false)
                            }
                            if ProcessInfo.processInfo.arguments.contains("--recovery-preview") || ProcessInfo.processInfo.arguments.contains("--recovery-probe") { FixtureRecoveryProbe() }
                            if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") { FixtureSelectionProbe() }
                        }
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                        VStack {
                            Text(recoveryOCRProbe).accessibilityIdentifier("fixture-ocr-result")
                            if !recoveryTableProbe.isEmpty { Text(recoveryTableProbe).accessibilityIdentifier("fixture-native-table-capture") }
                        }.allowsHitTesting(false)
                    }
                    if ProcessInfo.processInfo.arguments.contains("--theme-probe") {
                        Text(UserDefaults.standard.string(forKey: MainColor.storageKey) ?? "未設定")
                            .id(mainColor)
                            .accessibilityIdentifier("fixture-stored-color")
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if ProcessInfo.processInfo.arguments.contains("--notification-permission-probe") {
                        FixtureNotificationPermissionTouch()
                    }
                    if ProcessInfo.processInfo.arguments.contains("--notification-probe") {
                        VStack {
                            Text(notificationProbe).accessibilityIdentifier("fixture-notification-result")
                            Text(notificationDeliveryProof).accessibilityIdentifier("fixture-notification-delivery-proof")
                        }.allowsHitTesting(false)
                    }
                }
                .task {
                    FixtureLaunchDiagnostics.record("root-task-enter")
                    let data = ApplicationData.shared
                    var recordedApplicationReady = false
                    for _ in 0..<300 {
                        if data.ready && !recordedApplicationReady {
                            FixtureLaunchDiagnostics.record("application-ready")
                            recordedApplicationReady = true
                        }
                        if data.ready && data.materials.ready && data.specialSchedules.ready &&
                            data.schoolEvents.ready && data.links.ready && data.mappings.ready && data.times.ready &&
                            !data.materials.busy && !data.specialSchedules.busy &&
                            !data.schoolEvents.busy && !data.links.busy && !data.mappings.busy && !data.times.busy {
                            if ProcessInfo.processInfo.arguments.contains("--ai-feature-probe"), !LocalAIFeaturePolicy.enabled {
                                data.recovery.start(.timetable)
                                recoveryOffProbe = !data.recovery.running && data.recovery.preview == nil && data.recovery.manualDraft == nil ? "1" : "0"
                            }
                            applicationReady = true
                            FixtureLaunchDiagnostics.record("fixture-ready")
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    if !applicationReady { FixtureLaunchDiagnostics.record("fixture-ready-timeout") }
                    if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                        do { recoveryOCRProbe = try await SimulatorRecoveryOCRFixture.check() }
                        catch { recoveryOCRProbe = "OCR検証失敗: \(error)" }
                        recoveryTableProbe=UserDefaults.standard.string(forKey:"fixture.nativeTableCapture") ?? "未取得"
                    }
                    guard ProcessInfo.processInfo.arguments.contains("--notification-probe") else { return }
                    for _ in 0..<40 {
                        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
                        let changes = delivered.filter { $0.request.identifier == "takupoke.changes" }
                        let fresh = changes.filter { $0.date >= FixtureNotificationDelivery.startedAt }
                        if let received = fresh.first {
                            let revision = received.request.content.userInfo["revision"] as? String ?? ""
                            notificationDeliveryProof = "delivered=\(delivered.count);fresh=\(fresh.count);revision=\(!revision.isEmpty)"
                            notificationProbe = received.request.content.body
                            return
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    notificationProbe = "通知なし"
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await ApplicationData.shared.refreshInBackground()
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
            let monday = day.displayWeekStart
            let changeDay = monday.addingDays(3)!
            let changeStaged = library.newStagingURL()
            try raw.write(to: changeStaged)
            try library.commit(staged: changeStaged, kind: .changes, source: .init(grant: nil, childName: nil),
                originalName: "fictional.xlsx", byteCount: raw.count, digest: digest, modifiedAt: nil)
            let change = ScheduleChange(change_date: changeDay.iso8601, class_name: "3_IT", period: "4,5",
                before_subject: "", after_subject: "架空変更A", teacher: "架空教員B", room: "架空教室B", note: "補講", raw_text: "", canonical_text: "")
            var changeRecords = [change,
                    ScheduleChange(change_date: day.iso8601, class_name: "3_IT", period: "6", before_subject: "",
                        after_subject: "架空変更通知A", teacher: "", room: "", note: "変更", raw_text: "", canonical_text: "")]
            if ProcessInfo.processInfo.arguments.contains("--grid-probe") {
                changeRecords.append(ScheduleChange(change_date: changeDay.iso8601, class_name: "3_IT", period: "3",
                    before_subject: "架空休講A", after_subject: "", teacher: "架空教員D", room: "架空教室D",
                    note: "休講", raw_text: "", canonical_text: ""))
            }
            if !ProcessInfo.processInfo.arguments.contains("--normal-only") {
                try library.saveChangeAnalysis(.init(sourceDigest: digest, sourceName: "fictional.xlsx", defaultYear: period.schoolYear,
                    parsedAt: Date(), records: changeRecords))
            }
            let specialStore = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
            for (kind, offset, subject) in [(SpecialScheduleKind.exam, 1, "架空試験A"), (.examReturn, 2, "架空返却A")] {
                if ProcessInfo.processInfo.arguments.contains("--normal-only") { continue }
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
            let eventRows: [SchoolEventsPayload.Event]
            if ProcessInfo.processInfo.arguments.contains("--events-only") {
                eventRows = (0..<5).map { offset in
                    let date = monday.addingDays(offset)!.iso8601
                    return .init(startDate: date, endDate: date, title: "架空行事A", tag: "行事（授業なし）")
                }
            } else {
                // The API requires at least one event. A teaching-day event
                // keeps all normal lessons and exercises unequal header text.
                eventRows = [.init(startDate: eventDay, endDate: eventDay, title: "架空行事A",
                    tag: ProcessInfo.processInfo.arguments.contains("--normal-only") ?
                        "行事（授業あり）" : "行事（授業なし）")]
            }
            let events = SchoolEventsPayload(version: "v1", schoolYear: period.schoolYear, sourcePdfSha256: digest,
                sourcePdfETag: "\"fictional\"", events: eventRows)
            try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI")).save(events)

            let payload = LinksPayload(version: "v1", linksVersion: "sha256-" + String(repeating: "a",count: 64), categories: [
                .init(id: "fictional", label: "架空カテゴリ", sortOrder: 0, buttons: [
                    .init(id: "fictional-link", categoryId: "fictional", label: "架空リンクA", href: "https://fixture.example.test",
                          color: "blue", visible: true, sortOrder: 0, recommended: true, recommendationOrder: 0, searchAliases: [], searchTerms: "架空リンクA")])])
            try LinksStore(root: base.appendingPathComponent("LinksAPI")).save(.init(payload: payload, apiETag: "\"fictional\"", checkedAt: Date(), revision: String(repeating: "L", count: 43)))
            try LinkPreferencesStore().save(.init(favoriteIDs: ["fictional-link"]))
            let directory = base.appendingPathComponent("NameMappings")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Keep all three distinct full names within the returned VoiceOver utterance.
            let mappingJSON = ProcessInfo.processInfo.arguments.contains("--mapped-names") ?
                """
                {"subjects":[{"alias":"架空科目A","fullName":"架空科目甲"}],
                 "teachers":[{"alias":"架空教員A","fullName":"架空教員甲"}],
                 "rooms":[{"alias":"架空教室A","fullName":"架空教室甲"}],"teacherContexts":[]}
                """ : "{\"subjects\":[],\"teachers\":[],\"rooms\":[],\"teacherContexts\":[]}"
            let rules = try JSONDecoder().decode(MappingRules.self, from: Data(mappingJSON.utf8))
            try MappingStore(url: directory.appendingPathComponent("mappings.sqlite")).save(.init(revision: String(repeating: "M", count: 43), version: "fictional", schemaVersion: 1,
                archiveETag: "\"fictional\"", archiveSHA256: String(repeating: "a", count: 64), publishedAt: "2032-04-01T00:00:00Z", fetchedAt: Date(), rules: rules))
            let timesDate = ProcessInfo.processInfo.arguments.contains("--normal-only") ?
                monday.addingDays(7)!.iso8601 : day.iso8601
            let times = TimetableTimes(schemaVersion: 1, days: [.init(date: timesDate,
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
        if ProcessInfo.processInfo.arguments.contains("--recovery-preview") { LocalAIFeaturePolicy.setEnabled(true); try SimulatorRecoveryFixture.seed(base) }
        if ProcessInfo.processInfo.arguments.contains("--events-cache-corrupt") {
            try SimulatorEventsCacheFixture.seed(base)
        }
        if SimulatorEventsYearFixture.enabled { try SimulatorEventsYearFixture.seed(base) }
        if ProcessInfo.processInfo.arguments.contains("--failed-refresh") {
            let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
            try library.recordFailure(.changes, message: "架空の変更ファイル取得エラー")
            try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
                .recordFailure(PDFParseError(code: .unsupported), kind: .exam)
        }
        if ProcessInfo.processInfo.arguments.contains("--change-row-skip"),
           ProcessInfo.processInfo.arguments.contains("--reset-fixture") {
            try SimulatorChangeRowSkipFixture.seed(base)
        }
    }
}

enum FixtureNotificationDelivery {
    // Initialized before seed/update and retained for this process only.
    static let startedAt = Date()
}

// Independent of AX: fixed lifecycle labels only, never school/user content.
// This file belongs to the disposable fictional simulator app container.
enum FixtureLaunchDiagnostics {
    private static let writeLock = NSLock()
    static func recordAIChange(_ requested: Bool, phase: String) {
        guard ProcessInfo.processInfo.arguments.contains("--ai-feature-probe"),
              phase == "before" || phase == "after" else { return }
        append("TAKUPOKE_AI_SWITCH pid=\(ProcessInfo.processInfo.processIdentifier) time=\(Date().timeIntervalSince1970) phase=\(phase) requested=\(requested ? 1 : 0) stored=\(LocalAIFeaturePolicy.enabled ? 1 : 0)\n")
    }
    static func record(_ stage: String) {
        let allowed: Set<String> = ["init-enter", "seed-enter", "seed-complete", "scene-construction",
            "content-appeared", "root-task-enter", "application-ready", "fixture-ready", "fixture-ready-timeout",
            "notification-settings-enter", "notification-settings-complete", "notification-settings-cancelled",
            "notification-on-binding", "notification-off-binding",
            "notification-native-request", "notification-native-callback"]
        guard allowed.contains(stage) else { return }
        let line = "TAKUPOKE_LIFECYCLE pid=\(ProcessInfo.processInfo.processIdentifier) time=\(Date().timeIntervalSince1970) stage=\(stage)\n"
        append(line)
    }
    private static func append(_ line: String) {
        writeLock.lock()
        defer { writeLock.unlock() }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-fictional-launch-owned.log")
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url, options: .withoutOverwriting)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch { print("TAKUPOKE_LIFECYCLE recording-unavailable") }
    }
}
