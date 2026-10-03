import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit

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
    @State private var recoveryOCRProbe = "OCR実行中"
    @State private var applicationReady = false
    @State private var fixtureTypeSize: DynamicTypeSize = .large
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue
    init() {
        URLProtocol.registerClass(FixtureNetwork.self)
        do { try Self.seed() } catch { fatalError("Synthetic fixture initialization failed: \(error)") }
    }
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.timeZone, JapaneseDateDisplay.timeZone).tint((MainColor(rawValue: mainColor) ?? .systemDefault).color)
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
                            if ProcessInfo.processInfo.arguments.contains("--recovery-preview") || ProcessInfo.processInfo.arguments.contains("--recovery-probe") { FixtureRecoveryProbe() }
                        }
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                        Text(recoveryOCRProbe).accessibilityIdentifier("fixture-ocr-result")
                            .allowsHitTesting(false)
                    }
                    if ProcessInfo.processInfo.arguments.contains("--theme-probe") {
                        Text(UserDefaults.standard.string(forKey: MainColor.storageKey) ?? "未設定")
                            .id(mainColor)
                            .accessibilityIdentifier("fixture-stored-color")
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
                    if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                        do { recoveryOCRProbe = try await SimulatorRecoveryOCRFixture.check() }
                        catch { recoveryOCRProbe = "OCR検証失敗: \(error)" }
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
        if ProcessInfo.processInfo.arguments.contains("--recovery-preview") { try SimulatorRecoveryFixture.seed(base) }
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
    func fixtureCardKey(on day: SchoolDate, className: String, entry: TimetableSchedule.PositionedBlock) -> String {
        "\(day.iso8601)|\(className)|\(entry.lane)|\(entry.block.startPeriod)|\(entry.block.endPeriod)"
    }

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
                    let renderedTime = block.startPeriod != block.endPeriod || commonPeriodTime(block.startPeriod, days: days) == nil
                    var card: [String: Any] = ["source": source, "start": block.startPeriod, "end": block.endPeriod,
                        "cancellation": { if case .change(let item) = block.content { return item.isCancellation }; return false }(),
                        "lane": entry.lane, "day": column.day.iso8601,
                        "height": actual, "required": cardRequiredHeight(block, on: column.day,
                            className: selectedClasses[index], days: days),
                        "timeFont": renderedTime ? (cardTime(block, on: column.day, className: selectedClasses[index]).map(cardTimeFontSize) ?? 0) : 0]
                    if let frame = fixtureCardFrames[fixtureCardKey(on: column.day, className: selectedClasses[index], entry: entry)] {
                        card["frame"] = ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
                    }
                    cards.append(card)
                }
            }
        }
        let requestedSize = (try? String(contentsOf: FileManager.default.urls(for: .documentDirectory,
            in: .userDomainMask)[0].appendingPathComponent("expected-text-size.txt"), encoding: .utf8)) ?? "large"
        let expectedSizes: [String: UIContentSizeCategory] = ["large": .large, "extra-small": .extraSmall,
            "extra-extra-extra-large": .extraExtraExtraLarge,
            "accessibility-extra-extra-extra-large": .accessibilityExtraExtraExtraLarge]
        let value: [String: Any] = ["scale": gridScale, "width": dayColumnWidth,
            "systemSize": UIApplication.shared.preferredContentSizeCategory.rawValue,
            "expectedSystemSize": expectedSizes[requestedSize]?.rawValue ?? "invalid test size",
            "baseWidth": standardDayColumnWidth, "viewport": gridViewportWidth,
            "periodWidth": periodColumnWidth, "basePeriodWidth": standardPeriodColumnWidth,
            "subjectFont": gridUIFont(11).pointSize, "metadataFont": gridUIFont(9).pointSize,
            "eventFont": gridUIFont(14).pointSize, "periodFont": gridUIFont(15).pointSize,
            "headerFrames": fixtureHeaderFrames.mapValues { ["x": $0.minX, "height": $0.height] },
            "eventSizes": fixtureEventSizes.mapValues { ["width": $0.width, "height": $0.height] },
            "heights": heights, "cards": cards,
            "days": days.map(\.iso8601), "eventsOnly": columns.allSatisfy { $0.fullDayEventTitle != nil },
            "commonClocks": (1...8).compactMap { commonPeriodTime($0, days: days) }]
        return String(data: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), encoding: .utf8)!
    }
}

// This fixture injects a validated preview into only the temporary simulator
// app. Runtime/recognition correctness is exercised separately by core tests.
// Adoption, original PDF viewer and displayed field states use production UI.
@MainActor
enum SimulatorRecoveryFixture {
    static func payload() -> (RecoveryDocument, RecoveryResult) {
        let slots = (1...5).flatMap { d in (1...8).map { RecoverySlot(className: "3_IT", day: String(d), period: $0) } }
        let box = RecoveryBox(x: 110, y: 110, width: 60, height: 10)
        var sources = [RecoverySource(id: "heading", cellId: "header", page: 1, text: "\(SchoolDataPeriod.current().schoolYear)年度", box: RecoveryBox(x: 0, y: 0, width: 90, height: 10)),
                       RecoverySource(id: "subject", cellId: "c0", page: 1, text: "架空科目A", box: box),
                       RecoverySource(id: "teacher", cellId: "c0", page: 1, text: "架空教員A", box: box),
                       RecoverySource(id: "room", cellId: "c0", page: 1, text: "架空教室A", box: box)]
        sources.append(RecoverySource(id: "term", cellId: "header", page: 1, text: SchoolDataPeriod.current().half == 1 ? "前期" : "後期", box: RecoveryBox(x: 0, y: 20, width: 40, height: 10)))
        sources.append(RecoverySource(id: "class", cellId: "header", page: 1, text: "3_IT", box: RecoveryBox(x: 10, y: 110, width: 20, height: 10)))
        for day in 1...5 { sources.append(RecoverySource(id: "day\(day)", cellId: "header", page: 1, text: ["月", "火", "水", "木", "金"][day - 1], box: RecoveryBox(x: Double(day * 100 + 10), y: 20, width: 60, height: 10))) }
        for period in 1...8 { sources.append(RecoverySource(id: "period\(period)", cellId: "header", page: 1, text: String(period), box: RecoveryBox(x: 50, y: Double(period * 100 + 10), width: 20, height: 10))) }
        let cells = slots.enumerated().map { i, slot in RecoveryCell(id: "c\(i)", page: 1, box: RecoveryBox(x: Double(Int(slot.day)! * 100), y: Double(slot.period * 100), width: 100, height: 100), inputState: .complete, slots: [slot], sourceIds: i == 0 ? ["subject", "teacher", "room"] : [], blankFields: [], confirmedEmpty: i != 0, classHeaderIds: ["class"], dayHeaderIds: ["day\(slot.day)"], periodHeaderIds: ["period\(slot.period)"], lessonBindings: i == 0 ? [RecoveryLessonBinding(subject: ["subject"], teacher: ["teacher"], room: ["room"])] : [], classRegion: RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: 0, y: 100, width: 40, height: 800), axis: .left), dayRegion: RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: Double(Int(slot.day)! * 100), y: 0, width: 100, height: 50), axis: .above), periodRegions: [String(slot.period): RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: 40, y: Double(slot.period * 100), width: 40, height: 100), axis: .left)]) }
        var doc = RecoveryDocument(pdfHash: String(repeating: "a", count: 64), kind: .timetable, schoolYear: SchoolDataPeriod.current().schoolYear, term: SchoolDataPeriod.current().half == 1 ? "前期" : "後期", classes: ["3_IT"], days: (1...5).map(String.init), requiredSlots: slots, cells: cells, sources: sources, complete: true, yearEvidence: ["heading"], termEvidence: ["term"], dayEvidence: Dictionary(uniqueKeysWithValues: (1...5).map { (String($0), ["day\($0)"]) }), classEvidence: ["3_IT": ["class"]], periodEvidence: Dictionary(uniqueKeysWithValues: (1...8).map { (String($0), ["period\($0)"]) }), times: [:], timeEvidence: [], normalTimeNoteEvidence: [])
        let lesson = RecoveryLesson(subject: RecoveryField(state: .present, value: "架空科目A", evidence: ["subject"]), teacher: RecoveryField(state: .present, value: "架空教員A", evidence: ["teacher"]), room: RecoveryField(state: .present, value: "架空教室A", evidence: ["room"]), dateEvidence: ["day1"], periodEvidence: ["period1"])
        var result = RecoveryResult(pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: SchoolDataPeriod.current().schoolYear, term: SchoolDataPeriod.current().half == 1 ? "前期" : "後期", cells: cells.enumerated().map { i, cell in RecoveredCell(cellId: cell.id, state: i == 0 ? .present : .empty, lessons: i == 0 ? [lesson] : []) }, metadata: RecoveryMetadata(provider: "rule", modelId: "rules", modelVersion: "1", runtimeVersion: "1", promptVersion: "1", recoverySchemaVersion: RecoveryValidator.schemaVersion, validatorVersion: RecoveryValidator.version, osVersion: "test"))
        // A blank teacher is independently asserted in this UI-only input.
        doc.sources.removeAll { $0.id == "teacher" }
        doc.sources[doc.sources.firstIndex { $0.id == "room" }!].box.y = 145
        doc.cells[0].sourceIds.removeAll { $0 == "teacher" }
        doc.cells[0].blankFields = ["teacher"]
        doc.cells[0].lessonBindings[0].teacher = []
        result.cells[0].lessons[0].teacher = RecoveryField(state: .empty, value: "", evidence: [])
        return (doc, result)
    }

    private struct SpecialPayload: Decodable { var document: RecoveryDocument; var result: RecoveryResult }
    static func specialPayload(_ kind: RecoveryDocumentKind) throws -> (RecoveryDocument, RecoveryResult) {
        guard let path = Bundle.main.url(forResource: kind == .exam ? "recovery-exam" : "recovery-return", withExtension: "json") else { throw PDFParseError(code: .storage) }
        let period = SchoolDataPeriod.current()
        let month = period.half == 1 ? "04" : "10"
        let json = try String(contentsOf: path, encoding: .utf8)
            .replacingOccurrences(of: "2026-10-", with: "\(period.schoolYear)-\(month)-")
            .replacingOccurrences(of: "10月", with: period.half == 1 ? "4月" : "10月")
            .replacingOccurrences(of: "10/", with: period.half == 1 ? "4/" : "10/")
            .replacingOccurrences(of: "2026", with: String(period.schoolYear))
        let payload = try JSONDecoder().decode(SpecialPayload.self, from: Data(json.utf8))
        return (payload.document, payload.result)
    }
    static func seed(_ base: URL) throws {
        if ProcessInfo.processInfo.arguments.contains("--recovery-exam") || ProcessInfo.processInfo.arguments.contains("--recovery-return") {
            let kind: RecoveryDocumentKind = ProcessInfo.processInfo.arguments.contains("--recovery-exam") ? .exam : .return
            let special: SpecialScheduleKind = kind == .exam ? .exam : .examReturn
            let store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
            let (document, _) = try specialPayload(kind)
            let width = document.sources.map { $0.box.x + $0.box.width }.max()! + 30
            let height = document.sources.map { $0.box.y + $0.box.height }.max()! + 30
            let raw = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: height)).pdfData { context in
                for page in Set(document.sources.map(\.page)).sorted() {
                    context.beginPage()
                    for source in document.sources where source.page == page {
                        (source.text as NSString).draw(at: CGPoint(x: source.box.x, y: source.box.y), withAttributes: [.font: UIFont.systemFont(ofSize: 8)])
                    }
                }
            }
            let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
            let staging = store.newStagingURL(); try raw.write(to: staging)
            try store.saveSelection(staged: staging, kind: special, originalName: "fictional-recovery-\(kind.rawValue).pdf", byteCount: raw.count, digest: digest)
            try store.recordFailure(PDFParseError(code: .ambiguous), kind: special)
            return
        }
        let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
        let (document, _) = payload()
        let raw = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 650, height: 950)).pdfData { context in
            context.beginPage()
            for source in document.sources {
                (source.text as NSString).draw(at: CGPoint(x: source.box.x, y: source.box.y), withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            }
        }
        let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        let staging = library.newStagingURL(); try raw.write(to: staging)
        try library.commit(staged: staging, kind: .timetable, source: .init(grant: nil, childName: nil), originalName: "fictional-recovery.pdf", byteCount: raw.count, digest: digest, modifiedAt: nil)
        try library.recordPDFFailure(PDFParseError(code: .ambiguous), kind: .timetable)
    }
    static func preview(_ kind: RecoveryDocumentKind) async throws -> RecoveryPreview {
        let app = ApplicationData.shared
        let selected = kind == .timetable ? await app.materials.recoverySource() : await app.specialSchedules.recoverySource(kind == .exam ? .exam : .examReturn)
        guard let source = selected else { throw PDFParseError(code: .storage) }
        if kind != .timetable {
            var (document, result) = try specialPayload(kind); document.pdfHash = source.digest; result.pdfHash = source.digest
            let validation = RecoveryValidator.validate(document, result)
            guard validation.canAdopt else { throw NSError(domain: "SyntheticRecoveryPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: validation.errors.joined(separator: ",")]) }
            return RecoveryPreview(document: document, result: result, source: source)
        }
        var (document, result) = payload(); document.pdfHash = source.digest; result.pdfHash = source.digest
        let validation = RecoveryValidator.validate(document, result)
        guard validation.canAdopt else { throw NSError(domain: "SyntheticRecoveryPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: validation.errors.joined(separator: ",")]) }
        return RecoveryPreview(document: document, result: result, source: source)
    }
}
struct FixtureRecoveryProbe: View {
    @ObservedObject private var model = ApplicationData.shared.materials
    @ObservedObject private var specials = ApplicationData.shared.specialSchedules
    var body: some View {
        let adopted: Bool = {
            if ProcessInfo.processInfo.arguments.contains("--recovery-exam") { return specials.records[.exam]?.analysis.recovery != nil }
            if ProcessInfo.processInfo.arguments.contains("--recovery-return") { return specials.records[.examReturn]?.analysis.recovery != nil }
            return model.state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.recovery != nil
        }()
        Text(adopted ? "確認後に正式採用済み" : "前回の正式結果を保持")
            .font(.caption2).accessibilityIdentifier("fixture-recovery-formal")
            .allowsHitTesting(false)
    }
}

// This runs the production renderer, Vision recognition and grayscale checks.
// The PDF contains only a raster image; no extracted text or preview is injected.
@MainActor
enum SimulatorRecoveryOCRFixture {
    // Generated test target only. Run on the actual production PDF bitmap,
    // before Vision can safely reject its candidate confidence.
    nonisolated static func rasterProof(_ input: RecoveryRasterGrid) -> String {
        do {
            let lines = try input.rules(check: {})
            let raster = try input.preparingRules(lines, check: {})
            let scale = Double(raster.height) / 800
            guard let line = lines.first(where: { $0.horizontal && abs($0.y1 - 140.5 * scale) <= 3 && $0.x2 - $0.x1 > Double(raster.width) * 0.95 }),
                  raster.dark(raster.width / 2, Int(line.y1.rounded())),
                  !raster.dark(raster.width / 2, raster.height - 1 - Int(line.y1.rounded())) else { return "実rasterの上端座標・罫線が不一致" }
            let text = RecoveryBox(x: 10 * scale, y: 20 * scale, width: 550 * scale, height: 70 * scale)
            let blank = RecoveryBox(x: 10 * scale, y: 550 * scale, width: 550 * scale, height: 200 * scale)
            let rule = RecoveryBox(x: 10 * scale, y: 125 * scale, width: 550 * scale, height: 30 * scale)
            guard raster.hasUncoveredInk(text, text: [], rules: lines),
                  !raster.hasUncoveredInk(rule, text: [], rules: lines),
                  raster.isBlank(blank), !raster.hasUncoveredInk(blank, text: [], rules: lines) else { return "実rasterの未読インク・空欄が不一致" }
            return "実raster・上端座標・罫線・未読インク・空欄検証済み"
        } catch { return "実raster検証失敗: " + String(describing: error) }
    }
    static func check() async throws -> String {
        for key in ["fixture.nativeOCRCandidates", "fixture.nativeOCRText", "fixture.nativeOCRConfidence", "fixture.nativeRasterProof"] { UserDefaults.standard.removeObject(forKey: key) }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-ocr-ui-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let size = CGSize(width: 600, height: 800)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            ("これは架空の時間割です" as NSString).draw(at: CGPoint(x: 20, y: 32), withAttributes: [.font: UIFont.systemFont(ofSize: 32), .foregroundColor: UIColor.black])
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 140, width: 600, height: 1))
            context.cgContext.fill(CGRect(x: 0, y: 500, width: 600, height: 1))
            context.cgContext.fill(CGRect(x: 0, y: 140, width: 1, height: 361))
            context.cgContext.fill(CGRect(x: 599, y: 140, width: 1, height: 361))
        }
        let url = root.appendingPathComponent("fictional-image-only.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).writePDF(to: url) { context in
            context.beginPage(); image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let pdf = PDFDocument(url: url), pdf.pageCount == 1,
              (pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PDFParseError(code: .ambiguous) }
        let pages: [PDFRecoveryRecognition.LayoutPage]
        do { pages = try await PDFRecoveryRecognition.layouts(url, only: [1], check: {}) }
        catch {
            let candidates = UserDefaults.standard.stringArray(forKey: "fixture.nativeOCRCandidates") ?? []
            let text = UserDefaults.standard.string(forKey: "fixture.nativeOCRText")
            let confidence = UserDefaults.standard.object(forKey: "fixture.nativeOCRConfidence") as? Double
            let raster = UserDefaults.standard.string(forKey: "fixture.nativeRasterProof")
            if let failure = error as? PDFParseError, failure.code == .ambiguous, failure.stage == .rasterInput,
               text == "これは架空の時間割です", let confidence, confidence.isFinite, confidence >= 0, confidence < 0.85,
               raster == "実raster・上端座標・罫線・未読インク・空欄検証済み" {
                print("SYNTHETIC_NATIVE_OCR safelyRejected confidence=\(confidence), rasterProof=\(raster!)")
                return "低信頼OCRを安全拒否・実raster・上端座標・罫線・未読インク・空欄検証済み; confidence=\(confidence)"
            }
            throw NSError(domain: "SyntheticNativeOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: String(describing: error) + "; candidates=" + candidates.joined(separator: " | ") + "; raster=" + (raster ?? "未取得")])
        }
        guard pages.count == 1, let page = pages.first else { throw PDFParseError(code: .unreadable) }
        let layout = page.layout, raster = page.raster
        let text = layout.glyphs.map(\.text).joined().filter { !$0.isWhitespace }
        guard text == "これは架空の時間割です", !layout.glyphs.isEmpty,
              layout.glyphs.allSatisfy({ $0.y < layout.height * 0.15 && $0.x >= 0 && $0.width > 0 && $0.height > 0 }) else { throw PDFParseError(code: .ambiguous, stage: .characterMapping) }
        let scale = layout.height / 800
        guard let line = layout.lines.first(where: { $0.horizontal && abs($0.y1 - 140.5 * scale) <= 3 && $0.x2 - $0.x1 > layout.width * 0.95 }),
              raster.dark(raster.width / 2, Int(line.y1.rounded())),
              !raster.dark(raster.width / 2, raster.height - 1 - Int(line.y1.rounded())) else {
            let horizontal = layout.lines.filter(\.horizontal).map { String(format: "%.1f", $0.y1) }.joined(separator: ",")
            throw NSError(domain: "SyntheticOCRProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "rule/orientation h=\(layout.height), expected=\(140.5 * scale), horizontal=\(horizontal), grayAtExpected=\(raster.grayscale[Int(140.5 * scale) * raster.width + raster.width / 2])"])
        }
        let textRegion = RecoveryBox(x: 10 * scale, y: 20 * scale, width: 550 * scale, height: 70 * scale)
        let blankRegion = RecoveryBox(x: 10 * scale, y: 550 * scale, width: 550 * scale, height: 200 * scale)
        let ruleRegion = RecoveryBox(x: 10 * scale, y: 125 * scale, width: 550 * scale, height: 30 * scale)
        guard raster.hasUncoveredInk(textRegion, text: [], rules: layout.lines),
              !raster.hasUncoveredInk(ruleRegion, text: [], rules: layout.lines),
              raster.isBlank(blankRegion),
              !raster.hasUncoveredInk(blankRegion, text: [], rules: layout.lines) else {
            throw NSError(domain: "SyntheticOCRProbe", code: 2, userInfo: [NSLocalizedDescriptionKey: "ink: text=\(raster.hasUncoveredInk(textRegion, text: [], rules: layout.lines)), rule=\(raster.hasUncoveredInk(ruleRegion, text: [], rules: layout.lines)), blank=\(raster.isBlank(blankRegion)), blankInk=\(raster.hasUncoveredInk(blankRegion, text: [], rules: layout.lines))"])
        }
        return "OCR・上端座標・罫線・未読インク検証済み"
    }
}
