import Foundation
import XCTest
@testable import TakupokeParsing

final class StatusPresentationTests: XCTestCase {
    func testSourceDifferenceIsPublisherUpdateWaitingEvenDuringRecheck() {
        let source = SchoolEventsSourcePresentation(message: "更新待ち。端末の再取得では解消しません。", warningMessage: "配信元の更新待ちです。",
            lastSuccessfulMessage: nil, lastSuccessAt: Date(), receivedAt: Date(), evidence: .differs, updateWaiting: true)
        let value = StatusPresentation.schoolEvents(ready: true, failed: false, checking: true, cacheFailed: false, acquired: true, source: source)
        XCTAssertEqual(value.title, "更新待ち")
        XCTAssertEqual(value.tone, .attention)
        XCTAssertTrue(value.needsAttention)
    }

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

    func testUsingOnlyConfirmedDataReachesGreenAndNamesAffectedData() {
        let confirmed: [(title: String, state: DataUpdateState)] = [("リンク一覧", .confirmed), ("試験時間割", .unused)]
        let ready = StatusPresentation.dataSummary(confirmed)
        XCTAssertEqual(ready.title, "更新確認済み")
        XCTAssertEqual(ready.tone, .good)
        let pending = StatusPresentation.dataSummary(confirmed + [("名称データ", .unconfirmed)])
        XCTAssertEqual(pending.title, "名称データの更新が未確認")
        XCTAssertEqual(pending.tone, .unknown)
        XCTAssertEqual(StatusPresentation.dataSummary([("試験時間割", .unused)]).title, "データを設定してください")
        let failedFirstFetch = DataUpdateState.withoutLocalData(checking: false, failed: true)
        XCTAssertEqual(StatusPresentation.dataSummary(confirmed + [("学校行事", failedFirstFetch)]).tone, .unavailable)
        XCTAssertEqual(StatusPresentation.dataSummary(confirmed + [("授業時刻", .updateAvailable)]).title, "授業時刻に更新があります")
        let waiting = StatusPresentation.dataSummary(confirmed + [("学校行事", .updateWaiting)])
        XCTAssertEqual(waiting.title, "更新待ち")
        XCTAssertTrue(waiting.detail?.contains("学校行事") == true)
        XCTAssertEqual(StatusPresentation.dataSummary(confirmed + [("通常時間割", .unavailable), ("名称データ", .failed)]).tone, .unavailable)
    }

    func testSavedFileNeedsAnActualCheckAndKeepsItAcrossCancellation() {
        let date = Date(timeIntervalSince1970: 200)
        let name = "fictional.xlsx"
        let digest = "fictional-digest"
        var state = MaterialLibraryState()
        state.records = [MaterialRecord(kind: .changes, source: .init(), originalName: name, storedName: name,
                                        byteCount: 1, digest: digest, acquiredAt: date)]
        state.changeAnalysis = .init(sourceDigest: digest, sourceName: name, defaultYear: 2032, parsedAt: date, records: [])
        func updateState() -> DataUpdateState { FileStatusPresentation.material(state, kind: .changes, year: 2032).updateState }
        XCTAssertEqual(updateState(), .unconfirmed)
        state.records[0].lastCheckedAt = date.addingTimeInterval(60)
        XCTAssertEqual(updateState(), .confirmed)
        state.attempts["changes"] = .init(date: date.addingTimeInterval(120), failure: MaterialError.cancelled.localizedDescription)
        XCTAssertEqual(updateState(), .confirmed)
        state.attempts["changes"] = .init(date: date.addingTimeInterval(180), failure: MaterialError.accessExpired.localizedDescription)
        XCTAssertEqual(updateState(), .failed)
    }

    func testAccountAcquisitionDoesNotAssertLatestOrAuthentication() {
        let acquired = StatusPresentation.downloaded(acquired: true, updateAvailable: false, failed: false, busy: false)
        XCTAssertEqual(acquired.title, "保存済み・更新未確認")
        XCTAssertEqual(acquired.tone, .unknown)
        XCTAssertEqual(StatusPresentation.summary([acquired, .init(title: "接続あり", tone: .neutral)]).tone, .unknown)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: false, updateAvailable: true, failed: false, busy: false).tone, .neutral)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: true, updateAvailable: true, failed: false, busy: false).tone, .attention)
        XCTAssertEqual(StatusPresentation.downloaded(acquired: true, updateAvailable: false, failed: true, busy: false).tone, .attention)
    }

    func testRevisionObservationDistinguishesUnchangedNewerAndFailedWithSavedData() {
        let revision = String(repeating: "A", count: 43)
        let newer = String(repeating: "B", count: 43)
        let acquiredAt = Date(timeIntervalSince1970: 100)
        let checkedAt = acquiredAt.addingTimeInterval(120)
        let installation = DistributedRevisionConfirmation.Installation(revision: revision, acquiredAt: acquiredAt)
        let adopted = DistributedRevisionConfirmation(adopted: installation, at: acquiredAt)
        let confirmed = DistributedRevisionConfirmation(installation: installation, result: .unchanged, at: checkedAt)
        let available = DistributedRevisionConfirmation(installation: installation, result: .available(newer), at: checkedAt)
        let failed = DistributedRevisionConfirmation(failed: installation, previous: confirmed,
                                                     at: checkedAt.addingTimeInterval(10))

        func status(_ record: DistributedRevisionConfirmation?, busy: Bool = false, storageFailed: Bool = false) -> StatusPresentation {
            .downloaded(acquired: !storageFailed, updateAvailable: record?.hasNewerRevision == true,
                        failed: storageFailed, busy: busy, confirmation: record)
        }

        XCTAssertEqual(status(nil).tone, .unknown)
        XCTAssertEqual(status(nil, busy: true).tone, .checking)
        XCTAssertEqual(status(adopted).title, "取得済み")
        XCTAssertNil(adopted.lastSuccess)
        XCTAssertEqual(status(confirmed).title, "更新確認済み")
        XCTAssertEqual(status(confirmed).tone, .good)
        XCTAssertEqual(status(available).title, "更新あり")
        XCTAssertEqual(status(failed).tone, .attention)
        XCTAssertEqual(failed.lastSuccess, confirmed.lastSuccess)
        XCTAssertEqual(failed.lastSuccess?.checkedAt, checkedAt)
        XCTAssertGreaterThan(failed.lastAttemptAt, checkedAt)
        XCTAssertEqual(status(confirmed, storageFailed: true).tone, .attention)
    }

    func testRevisionConfirmationRestoresOnlyForTheSameInstallationAndCorruptionIsIndependent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = root.appendingPathComponent("fictional-data.json")
        try Data("fictional payload".utf8).write(to: data)
        let revision = String(repeating: "A", count: 43)
        let acquiredAt = Date(timeIntervalSince1970: 100)
        let original = DistributedRevisionConfirmation.Installation(revision: revision, acquiredAt: acquiredAt)
        let replacement = DistributedRevisionConfirmation.Installation(revision: revision,
                                                                      acquiredAt: acquiredAt.addingTimeInterval(10))
        let checkedAt = acquiredAt.addingTimeInterval(3)
        let record = DistributedRevisionConfirmation(installation: original, result: .unchanged, at: checkedAt)

        XCTAssertNil(DistributedRevisionConfirmation.load(beside: data, installation: original))
        record.save(beside: data)
        XCTAssertEqual(DistributedRevisionConfirmation.load(beside: data, installation: original), record)
        XCTAssertNil(DistributedRevisionConfirmation.load(beside: data, installation: replacement))
        try Data("malformed".utf8).write(to: data.appendingPathExtension("revision-check.json"))
        XCTAssertNil(DistributedRevisionConfirmation.load(beside: data, installation: original))
        XCTAssertEqual(try Data(contentsOf: data), Data("fictional payload".utf8))
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
