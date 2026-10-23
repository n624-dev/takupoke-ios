import XCTest
@testable import TakupokeParsing

final class SpecialAvailabilityTests: XCTestCase {
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
