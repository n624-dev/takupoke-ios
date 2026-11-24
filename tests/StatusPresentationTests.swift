import Foundation
import XCTest
@testable import TakupokeParsing

final class StatusPresentationTests: XCTestCase {
    func testCancellationIsNeutralAndKeepsTheSavedResult() {
        var state = MaterialLibraryState()
        state.records = [MaterialRecord(kind: .changes, source: MaterialSource(), originalName: "fictional.xlsx",
            storedName: "fictional.xlsx", byteCount: 1, digest: "fictional-digest", acquiredAt: Date())]
        state.changeAnalysis = ChangeAnalysis(sourceDigest: "fictional-digest", sourceName: "fictional.xlsx", defaultYear: 2032,
                                              parsedAt: Date(), records: [])
        for cancelled in [nil, true] as [Bool?] {
            state.attempts["changes"] = .init(date: Date(), failure: MaterialError.cancelled.localizedDescription, cancelled: cancelled)
            let value = FileStatusPresentation.material(state, kind: .changes, year: 2032)
            XCTAssertEqual(value.status.tone, .neutral)
            XCTAssertTrue(value.hasSavedAnalysis)
            XCTAssertFalse(value.status.needsAttention)
        }
        state.attempts["changes"] = .init(date: Date(), failure: MaterialError.accessExpired.localizedDescription)
        let failed = FileStatusPresentation.material(state, kind: .changes, year: 2032)
        XCTAssertTrue(failed.status.needsAttention)
        XCTAssertTrue(failed.hasSavedAnalysis)
        XCTAssertEqual(failed.status.detail, MaterialError.accessExpired.localizedDescription)
        state.records = []; state.changeAnalysis = nil
        state.attempts["timetable"] = .init(date: Date(), failure: MaterialError.unavailable.localizedDescription)
        let missing = FileStatusPresentation.material(state, kind: .changes, year: 2032)
        XCTAssertEqual(missing.status.detail, MaterialError.accessExpired.localizedDescription)
        XCTAssertFalse(missing.hasSavedAnalysis)
    }

    func testUnknownAndUnselectedDoNotBecomeFailuresOrAllNormal() {
        let empty = MaterialLibraryState()
        XCTAssertEqual(FileStatusPresentation.material(empty, kind: .changes, year: 2032).status.tone, .neutral)
        for kind in SpecialScheduleKind.allCases {
            let availability = SpecialScheduleAvailability(ready: true, busy: false, failed: false, sources: [:], records: [:])
            XCTAssertEqual(FileStatusPresentation.special(availability, kind: kind).status.tone, .neutral)
        }
        XCTAssertEqual(StatusPresentation.summary([.init(title: "未確認", tone: .unknown), .init(title: "正常", tone: .good)]).tone, .unknown)
        let unselected = StatusPresentation.summary([.init(title: "未選択", tone: .neutral)])
        XCTAssertEqual(unselected.tone, .neutral)
        XCTAssertEqual(unselected.title, "各項目の状態を確認できます")
        XCTAssertEqual(StatusPresentation.summary([]).tone, .unknown)
    }

    func testAccountAcquisitionDoesNotAssertLatestOrAuthentication() {
        let acquired = StatusPresentation.downloaded(acquired: true, updateAvailable: false, failed: false, busy: false)
        XCTAssertEqual(acquired.title, "取得済み")
        XCTAssertEqual(acquired.tone, .unknown)
        XCTAssertEqual(StatusPresentation.summary([acquired, .init(title: "接続あり", tone: .neutral)]).tone, .unknown)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: false, updateAvailable: true, failed: false, busy: false).tone, .neutral)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: true, updateAvailable: true, failed: false, busy: false).tone, .attention)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: true, updateAvailable: false, failed: true, busy: false).tone, .attention)
    }

    func testSummaryCountsAttentionWithoutCountingNeutralCancellation() {
        let result = StatusPresentation.summary([.init(title: "停止", tone: .unavailable), .init(title: "更新", tone: .attention),
                                                .init(title: "中止", tone: .neutral), .init(title: "未選択", tone: .neutral)])
        XCTAssertEqual(result.title, "要確認 2件")
        XCTAssertEqual(StatusPresentation.summary([.init(title: "正常", tone: .good)], paused: true).tone, .neutral)
        XCTAssertEqual(StatusPresentation.summary([.init(title: "正常", tone: .good)], checking: true).tone, .checking)
    }

    func testOnlyCancellationErrorsAreNeutral() {
        for error: Error in [MaterialError.cancelled, CancellationError(), PDFParseError(code: .cancelled), ChangeParseError(code: .cancelled)] {
            XCTAssertTrue(FileOperationOutcome.isCancellation(error))
        }
        for error: Error in [MaterialError.accessExpired, PDFParseError(code: .unsupported), ChangeParseError(code: .storage)] {
            XCTAssertFalse(FileOperationOutcome.isCancellation(error))
        }
    }

    func testExplicitResumeIsInSessionAndDoesNotReplayDiscardedRequests() {
        var queue = FileRefreshQueue()
        queue.setForeground(true)
        queue.request("timetable")
        queue.suspend()
        queue.resume()
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        queue.request("changes")
        XCTAssertEqual(queue.take(ready: true, busy: false), ["changes"])
        queue.suspend()
        queue.setForeground(false)
        XCTAssertTrue(queue.suspended)
        queue.setForeground(true)
        XCTAssertFalse(queue.suspended)
        queue.request("exam")
        queue.discardPending()
        XCTAssertFalse(queue.suspended, "Stopping queued work must not disable automatic checks")
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
    }
}
