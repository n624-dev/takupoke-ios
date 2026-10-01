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
    @State private var applicationReady = false
    @State private var fixtureTypeSize: DynamicTypeSize = .large
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue
    init() {
        URLProtocol.registerClass(FixtureNetwork.self)
        do { try Self.seed() } catch { fatalError("Synthetic fixture initialization failed: \(error)") }
    }
    var body: some Scene {
        WindowGroup {
            ContentView().tint((MainColor(rawValue: mainColor) ?? .blue).color)
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
                        Text("準備完了").font(.caption2)
                            .accessibilityIdentifier("fixture-ready")
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if ProcessInfo.processInfo.arguments.contains("--notification-probe") {
                        Text(notificationProbe).accessibilityIdentifier("fixture-notification-result")
                    }
                }
                .task {
                    let data = ApplicationData.shared
                    for _ in 0..<300 {
                        if data.ready && data.materials.ready && data.specialSchedules.ready &&
                            data.schoolEvents.ready && data.links.ready && data.mappings.ready && data.times.ready &&
                            !data.materials.busy && !data.specialSchedules.busy &&
                            !data.schoolEvents.busy && !data.links.busy && !data.mappings.busy && !data.times.busy {
                            applicationReady = true
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
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
                eventRows = ProcessInfo.processInfo.arguments.contains("--normal-only") ? [] :
                    [.init(startDate: eventDay, endDate: eventDay, title: "架空行事A", tag: "行事（授業なし）")]
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
            let rules = try JSONDecoder().decode(MappingRules.self, from: Data("{\"subjects\":[],\"teachers\":[],\"rooms\":[],\"teacherContexts\":[]}".utf8))
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
        if ProcessInfo.processInfo.arguments.contains("--failed-refresh") {
            let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
            try library.recordFailure(.changes, message: "架空の変更ファイル取得エラー")
            try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
                .recordFailure(PDFParseError(code: .unsupported), kind: .exam)
        }
    }
}

// Only the isolated test app uses these controls and metrics. Production
// sources are instrumented in the temporary project, not in the shipped app.
private struct FixtureTypeSize: ViewModifier {
    let enabled: Bool
    let size: DynamicTypeSize
    func body(content: Content) -> some View {
        if enabled { content.environment(\.dynamicTypeSize, size) }
        else { content }
    }
}

extension TimetableView {
    func fixtureGridMetrics(columns: [DayGridLayout], days: [SchoolDate], heights: [CGFloat]) -> String {
        var cards: [[String: Any]] = []
        for column in columns {
            for (index, positioned) in column.positioned.enumerated() {
                for entry in positioned {
                    let block = entry.block
                    let source: String
                    switch block.content {
                    case .normal: source = "normal"
                    case .change: source = "change"
                    case .special(let item): source = item.kind.rawValue
                    }
                    let actual = heights[(block.startPeriod - 1)..<block.endPeriod].reduce(0, +) +
                        CGFloat(block.endPeriod - block.startPeriod) * gridSpacing
                    cards.append(["source": source, "start": block.startPeriod, "end": block.endPeriod,
                        "cancellation": { if case .change(let item) = block.content { return item.isCancellation }; return false }(),
                        "lane": entry.lane, "day": column.day.iso8601,
                        "height": actual, "required": cardRequiredHeight(block, on: column.day,
                            className: selectedClasses[index], days: days),
                        "timeFont": cardTime(block, on: column.day, className: selectedClasses[index]).map(cardTimeFontSize) ?? 0])
                }
            }
        }
        let value: [String: Any] = ["scale": gridScale, "width": dayColumnWidth,
            "systemSize": UIApplication.shared.preferredContentSizeCategory.rawValue,
            "baseWidth": standardDayColumnWidth, "viewport": gridViewportWidth,
            "periodWidth": periodColumnWidth, "basePeriodWidth": standardPeriodColumnWidth,
            "subjectFont": gridUIFont(11).pointSize, "metadataFont": gridUIFont(9).pointSize,
            "eventFont": gridUIFont(14).pointSize, "periodFont": gridUIFont(15).pointSize,
            "heights": heights, "cards": cards,
            "days": days.map(\.iso8601), "eventsOnly": columns.allSatisfy { $0.fullDayEventTitle != nil },
            "commonClocks": (1...8).compactMap { commonPeriodTime($0, days: days) }]
        return String(data: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), encoding: .utf8)!
    }
}
