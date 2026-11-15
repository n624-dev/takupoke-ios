import XCTest
@testable import TakupokeParsing

final class SpecialAvailabilityTests: XCTestCase {
    func testHomeKeepsLoadedLessonsWhenIndependentStoresAreUnavailable() {
        for materials in ScheduleLoadState.allCases {
            for specials in ScheduleLoadState.allCases {
                for events in ScheduleLoadState.allCases {
                    let value = HomeScheduleAvailability(materials: materials, specials: specials, events: events)
                    XCTAssertEqual(value.ready, materials == .ready, "Primary=\(materials), specials=\(specials), events=\(events)")
                    XCTAssertEqual(value.loadFailed, materials == .failed, "Independent store errors need their own warnings")
                }
            }
        }
        XCTAssertEqual(ScheduleLoadState(ready: true, busy: true, failed: true), .ready)
        XCTAssertEqual(ScheduleLoadState(ready: false, busy: true, failed: true), .loading)
    }

    func testHomeWarningsUseTheRetainedResultForEachSelectedMaterial() {
        var state = MaterialLibraryState()
        for kind: MaterialKind in [.timetable, .changes] {
            XCTAssertNil(state.scheduleWarning(for: kind, changeSchoolYear: 2032))
            state.records.append(MaterialRecord(kind: kind, source: MaterialSource(), originalName: "fixture",
                storedName: kind.rawValue, byteCount: 1, digest: "current", acquiredAt: Date()))
            XCTAssertEqual(state.scheduleWarning(for: kind, changeSchoolYear: 2032),
                "\(kind.title)の選択した資料をまだ反映できていません。正常な解析結果がありません。")
        }
        state.changeAnalysis = ChangeAnalysis(sourceDigest: "current", sourceName: "fixture", defaultYear: 2032,
            parsedAt: Date(), records: [])
        state.pdfAnalyses = [MaterialKind.timetable.rawValue: PDFAnalysis(kind: .timetable, sourceDigest: "old",
            sourceName: "fixture", parsedAt: Date(), schoolYear: 2032, lessons: [], events: [], notices: [])]
        XCTAssertNil(state.scheduleWarning(for: .changes, changeSchoolYear: 2032))
        XCTAssertEqual(state.scheduleWarning(for: .timetable, changeSchoolYear: 2032),
            "通常時間割の新しい資料をまだ反映できていません。前回の正常結果を表示しています。")
        XCTAssertEqual(state.scheduleWarning(for: .changes, changeSchoolYear: 2033),
            "時間割変更の新しい資料をまだ反映できていません。前回の正常結果を表示しています。")
        state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.sourceDigest = "current"
        XCTAssertNil(state.scheduleWarning(for: .timetable, changeSchoolYear: 2032))
    }

    func testLoadingFailureAndUnselectedAreDistinctForBothKinds() {
        for kind in SpecialScheduleKind.allCases {
            for busy in [false, true] {
                for failed in [false, true] {
                    let value = SpecialScheduleAvailability(ready: false, busy: busy, failed: failed, sources: [:], records: [:])
                    XCTAssertEqual(value.state(for: kind), failed && !busy ? .loadFailed : .loading)
                    XCTAssertEqual(value.loadFailed, failed && !busy)
                }
            }
            XCTAssertEqual(SpecialScheduleAvailability(ready: true, busy: false, failed: false, sources: [:], records: [:]).state(for: kind), .unselected)
        }
    }
    func testFirstFailedAnalysisAndPreviousSuccessUseDifferentWarnings() {
        for kind in SpecialScheduleKind.allCases {
            let source = SpecialScheduleSource(kind: kind, originalName: "fictional.pdf", storedName: "fictional.pdf", byteCount: 1, digest: "new", acquiredAt: Date())
            let analysis = SpecialScheduleAnalysis(kind: kind, sourceDigest: "new", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032,
                coveredDates: ["2032-04-05"], coveredClasses: ["1_ZZ"], periodTimes: [:], lessons: [])
            func state(_ record: SpecialScheduleRecord?) -> SpecialScheduleAvailability {
                .init(ready: true, busy: false, failed: true, sources: [kind: source], records: record.map { [kind: $0] } ?? [:])
            }
            XCTAssertEqual(state(nil).state(for: kind), .unanalysed)
            XCTAssertFalse(state(nil).message(for: kind)!.contains("前回"))
            let current = SpecialScheduleRecord(kind: kind, originalName: "fictional.pdf", storedName: "fictional.pdf", byteCount: 1, digest: "new", acquiredAt: Date(), analysis: analysis)
            XCTAssertEqual(state(current).state(for: kind), .current)
            XCTAssertNil(state(current).message(for: kind))
            var obsolete = analysis; obsolete.version -= 1
            let previous = SpecialScheduleRecord(kind: kind, originalName: "fictional.pdf", storedName: "fictional.pdf", byteCount: 1, digest: "old", acquiredAt: Date(), analysis: obsolete)
            XCTAssertEqual(state(previous).state(for: kind), .previous)
            XCTAssertTrue(state(previous).message(for: kind)!.contains("前回の正常結果"))
            let orphan = SpecialScheduleAvailability(ready: true, busy: false, failed: false, sources: [:], records: [kind: previous])
            XCTAssertEqual(orphan.state(for: kind), .previous)
        }
    }
}
