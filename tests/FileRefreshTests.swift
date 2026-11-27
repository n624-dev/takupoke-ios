import XCTest
import Foundation
@testable import TakupokeParsing

final class FileRefreshTests: XCTestCase {
    private final class PipelineClock: @unchecked Sendable {
        let lock = NSLock()
        private var tick: TimeInterval = 0
        func now() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return tick }
        func advance(_ seconds: TimeInterval) { lock.lock(); tick += seconds; lock.unlock() }
    }

    func testPipelineStageDeadlinesProgressOverallAndCommitFence() throws {
        let clock = PipelineClock()
        let period = SchoolDataPeriod.current()
        let ticket = FilePipeline.Ticket(source: .changes, reason: .automatic, period: period, limits: .init(), now: { clock.now() })
        clock.advance(29); try ticket.check()
        ticket.enter(.acquiring)
        clock.advance(59); try ticket.check(); ticket.progress()
        clock.advance(59); try ticket.check()
        ticket.enter(.parsing)
        clock.advance(93); XCTAssertThrowsError(try ticket.check()) // 240 overall, despite stage progress.
        XCTAssertThrowsError(try ticket.beginCommit(period: period))
        let parseClock = PipelineClock()
        let parse = FilePipeline.Ticket(source: .exam, reason: .manual, period: period, limits: .init(), now: { parseClock.now() })
        parse.enter(.parsing); parseClock.advance(120)
        XCTAssertThrowsError(try parse.check())
        let idleClock = PipelineClock()
        let idle = FilePipeline.Ticket(source: .examReturn, reason: .automatic, period: period, limits: .init(), now: { idleClock.now() })
        idle.enter(.acquiring); idleClock.advance(60); XCTAssertThrowsError(try idle.check())
        let cancelled = FilePipeline.Ticket(source: .timetable, reason: .manual, period: period, limits: .init(), now: { 0 })
        cancelled.cancel(); XCTAssertThrowsError(try cancelled.beginCommit(period: period))
        let stale = FilePipeline.Ticket(source: .timetable, reason: .manual, period: period, limits: .init(), now: { 0 })
        let other = SchoolDataPeriod(day: SchoolDate(year: period.schoolYear - 1, month: 4, day: 1)!)
        XCTAssertThrowsError(try stale.beginCommit(period: other))
    }

    func testUnresponsivePipelineExpiresWithoutPublishingAndOtherFilesContinue() throws {
        final class Probe: @unchecked Sendable {
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            let returned = DispatchSemaphore(value: 0), cleaned = DispatchSemaphore(value: 0)
            let lock = NSLock()
            var expired = false, commits = 0
        }
        let probe = Probe(), clock = PipelineClock()
        let pipeline = FilePipeline(now: { clock.now() })
        DispatchQueue.global().async {
            defer { probe.returned.signal() }
            do {
                try pipeline.run(source: .changes, reason: .automatic, period: .current(), cancelled: {}, work: { _ in
                    probe.entered.signal(); probe.release.wait(); return 42
                }, cleanup: { probe.cleaned.signal() }, commit: { _, _ in
                    probe.lock.lock(); probe.commits += 1; probe.lock.unlock()
                })
            } catch FilePipeline.Failure.timedOut {
                probe.lock.lock(); probe.expired = true; probe.lock.unlock()
            } catch { XCTFail("Unexpected timeout outcome") }
        }
        defer { probe.release.signal() }
        XCTAssertEqual(probe.entered.wait(timeout: .now() + 5), .success)
        clock.advance(30)
        XCTAssertEqual(probe.returned.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(pipeline.isRecovering(.changes))
        XCTAssertEqual(pipeline.snapshot[.changes]?.stage, .timedOut)
        XCTAssertTrue(pipeline.snapshot[.changes]?.waitingForWorker == true)
        XCTAssertThrowsError(try pipeline.run(source: .changes, reason: .manual, period: .current(), cancelled: {},
            work: { _ in XCTFail("Duplicate read"); return 0 }, cleanup: {}, commit: { _, _ in XCTFail("Duplicate commit") }))
        var otherCommitted = false
        try pipeline.run(source: .exam, reason: .manual, period: .current(), cancelled: {}, work: { _ in 7 }, cleanup: {},
            commit: { value, ticket in try ticket.beginCommit(period: .current()); XCTAssertEqual(value, 7); otherCommitted = true })
        XCTAssertTrue(otherCommitted)
        probe.release.signal()
        XCTAssertEqual(probe.cleaned.wait(timeout: .now() + 5), .success)
        probe.lock.lock(); defer { probe.lock.unlock() }
        XCTAssertTrue(probe.expired); XCTAssertEqual(probe.commits, 0)
    }

    func testTransientRetriesStopAtTwoAndKeepOneCommitAndCleanup() throws {
        final class Probe: @unchecked Sendable {
            let lock = NSLock()
            var calls = 0, commits = 0, cleanups = 0
            let finished = DispatchSemaphore(value: 0)
        }
        let probe = Probe()
        var limits = FilePipeline.Limits(); limits.retryDelay = 0
        let pipeline = FilePipeline(limits: limits)
        let owner = DispatchQueue(label: "fictional-owner")
        XCTAssertThrowsError(try pipeline.run(source: .changes, reason: .manual, period: .current(), cancelled: {}, work: { _ in
            probe.lock.lock(); probe.calls += 1; let calls = probe.calls; probe.lock.unlock()
            if calls < 3 { throw URLError(.networkConnectionLost) }
            return 42
        }, cleanup: {
            probe.lock.lock(); probe.cleanups += 1; probe.lock.unlock(); probe.finished.signal()
        }, retryQueue: owner, commit: { value, ticket in
            try ticket.beginCommit(period: .current()); XCTAssertEqual(value, 42)
            ticket.didCommit()
            probe.lock.lock(); probe.commits += 1; probe.lock.unlock()
        }))
        XCTAssertEqual(probe.finished.wait(timeout: .now() + 5), .success)
        probe.lock.lock(); defer { probe.lock.unlock() }
        XCTAssertEqual(probe.calls, 3); XCTAssertEqual(probe.commits, 1); XCTAssertEqual(probe.cleanups, 1)
        XCTAssertEqual(pipeline.snapshot[.changes]?.attempt, 2)
        XCTAssertEqual(pipeline.snapshot[.changes]?.stage, .succeeded)
    }

    func testTransportShapedFailuresAfterAcquisitionNeverStartANewAttempt() throws {
        let owner = DispatchQueue(label: "fictional-stage-retry-owner")
        let errors: [Error] = [URLError(.networkConnectionLost), MaterialError.providerReadFailed]
        var limits = FilePipeline.Limits()
        limits.retryDelay = 0
        for reason: FilePipeline.Reason in [.automatic, .manual] {
            for stage: FilePipeline.Stage in [.parsing, .validating, .saving] {
                for error in errors {
                    let pipeline = FilePipeline(limits: limits)
                    let cleaned = DispatchSemaphore(value: 0)
                    XCTAssertThrowsError(try pipeline.run(source: .exam, reason: reason, period: .current(), cancelled: {},
                        work: { ticket in
                            if stage != .saving { ticket.enter(stage); throw error }
                            return 42
                        }, cleanup: { cleaned.signal() }, retryQueue: owner, commit: { _, ticket in
                            try ticket.beginCommit(period: .current())
                            throw error
                        }))
                    XCTAssertEqual(cleaned.wait(timeout: .now() + 5), .success)
                    let status = try XCTUnwrap(pipeline.snapshot[.exam])
                    XCTAssertEqual(status.attempt, 0, "\(reason) \(stage)")
                    XCTAssertEqual(status.stage, .failed)
                    XCTAssertNotNil(status.requestFinishedAt)
                    XCTAssertFalse(pipeline.isRecovering(.exam))
                }
            }
        }
    }

    func testStaleReferenceRequiresTheReadAndSavedOriginalDigestsToMatch() throws {
        var reads = 0
        try MaterialBookmarkResolution.verifiesOriginal(receivedDigest: "fictional-original", savedDigest: "fictional-original") {
            reads += 1; return "fictional-original"
        }
        XCTAssertEqual(reads, 1)
        XCTAssertThrowsError(try MaterialBookmarkResolution.verifiesOriginal(receivedDigest: "changed", savedDigest: "fictional-original") {
            XCTFail("A different provider file must not renew the reference"); return "fictional-original"
        }) { error in
            guard case .bookmarkStale? = error as? MaterialError else { return XCTFail("Expected stale reference failure") }
        }
        XCTAssertThrowsError(try MaterialBookmarkResolution.verifiesOriginal(receivedDigest: "fictional-original", savedDigest: "fictional-original") {
            "different-actual-stored-file"
        }) { error in
            guard case .bookmarkStale? = error as? MaterialError else { return XCTFail("Expected stale reference failure") }
        }
    }

    func testRetryAcquiringTheOriginalButFailingToParseAllowsMonitorRecovery() throws {
        var limits = FilePipeline.Limits()
        limits.retryDelay = 0
        let owner = DispatchQueue(label: "fictional-monitor-recovery-owner")
        for source in FileRefreshDiagnostics.Source.allCases {
            let pipeline = FilePipeline(limits: limits)
            let cleaned = DispatchSemaphore(value: 0)
            XCTAssertThrowsError(try pipeline.run(source: source, reason: .automatic, period: .current(),
                cancelled: {}, work: { ticket in
                    if ticket.attempt == 0 { throw URLError(.networkConnectionLost) }
                    ticket.acquired()
                    return PDFParseError(code: .ambiguous)
                }, cleanup: { cleaned.signal() }, retryQueue: owner, commit: { parseFailure, ticket in
                    try ticket.beginCommit(period: .current())
                    ticket.didCommit()
                    throw parseFailure
                }))
            XCTAssertEqual(cleaned.wait(timeout: .now() + 5), .success)
            let status = try XCTUnwrap(pipeline.snapshot[source])
            XCTAssertEqual(status.attempt, 1)
            XCTAssertEqual(status.stage, .failed)
            XCTAssertTrue(status.canRetryMonitorRegistration)

            XCTAssertThrowsError(try pipeline.run(source: source, reason: .automatic, period: .current(),
                cancelled: {}, work: { ticket in ticket.acquired(); return 42 }, cleanup: {},
                commit: { _, ticket in
                    try ticket.beginCommit(period: .current())
                    throw MaterialError.invalidState
                }))
            XCTAssertEqual(pipeline.snapshot[source]?.canRetryMonitorRegistration, false)

            XCTAssertThrowsError(try pipeline.run(source: source, reason: .automatic, period: .current(),
                cancelled: {}, work: { _ in throw MaterialError.accessExpired }, cleanup: {},
                commit: { (_: Int, _) in XCTFail("An inaccessible original cannot be committed") }))
            XCTAssertEqual(pipeline.snapshot[source]?.canRetryMonitorRegistration, false)
        }
    }

    func testPipelinePublishesOneLogicalResultAfterBothSourcesFinish() throws {
        var limits = FilePipeline.Limits()
        limits.retryDelay = 0
        let owner = DispatchQueue(label: "fictional-request-owner")
        let pipeline = FilePipeline(limits: limits)
        let requestID = UUID()
        let expected: Set<FileRefreshDiagnostics.Source> = [.timetable, .changes]
        let finalized = expectation(description: "logical outcome is published")
        finalized.assertForOverFulfill = true
        let observer = NotificationCenter.default.addObserver(forName: .filePipelineChanged, object: nil, queue: nil) { change in
            guard (change.object as? FilePipeline) === pipeline,
                  pipeline.observation.result(for: requestID, sources: expected) != nil else { return }
            finalized.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        owner.suspend()
        var suspended = true
        defer { if suspended { owner.resume() } }
        let parseFailure = PDFParseError(code: .ambiguous)
        XCTAssertThrowsError(try pipeline.run(source: .timetable, reason: .manual, period: .current(), cancelled: {},
            work: { ticket in
                if ticket.attempt == 0 { throw URLError(.networkConnectionLost) }
                ticket.acquired(); ticket.enter(.parsing)
                return 42
            }, cleanup: {}, retryQueue: owner, requestID: requestID, commit: { _, ticket in
                try ticket.beginCommit(period: .current())
                ticket.didCommit()
                throw parseFailure
            }))
        XCTAssertNil(pipeline.observation.completed[.timetable])
        XCTAssertNil(pipeline.observation.result(for: requestID, sources: expected))
        try pipeline.run(source: .changes, reason: .manual, period: .current(), cancelled: {}, work: { _ in 1 },
            cleanup: {}, requestID: requestID, commit: { _, ticket in
                try ticket.beginCommit(period: .current()); ticket.didCommit()
            })
        let initial = pipeline.observation
        XCTAssertEqual(initial.result(for: requestID, sources: [.changes]), .succeeded)
        XCTAssertNil(initial.result(for: requestID, sources: expected))

        owner.resume()
        suspended = false
        wait(for: [finalized], timeout: 5)
        let terminal = pipeline.observation
        XCTAssertEqual(terminal.result(for: requestID, sources: expected), .failed(parseFailure.localizedDescription))
        XCTAssertNil(terminal.result(for: UUID(), sources: expected))
        var handled: [FileRefreshDiagnostics.Source: UUID] = [:]
        XCTAssertEqual(FilePipeline.claimMonitorRegistrations(in: terminal.completed, handled: &handled), ["timetable"])
        XCTAssertTrue(FilePipeline.claimMonitorRegistrations(in: terminal.completed, handled: &handled).isEmpty)
    }

    func testFirstRegularAcquisitionFailurePersistsWithoutAnOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("library")
        let failures: [(MaterialError, AcquisitionProblem)] = [(.tooLarge, .sizeLimit), (.invalidFile, .invalidFormat),
            (.accessExpired, .permission), (.providerReadFailed, .temporary)]
        for kind in [MaterialKind.timetable, .changes] {
            for (error, problem) in failures {
                do {
                    let live = try LocalMaterialDatabase.openLibrary(root: root)
                    try live.recordFailure(kind, message: error.localizedDescription, problem: AcquisitionProblem(error))
                    try live.recordFailure(kind, message: MaterialError.cancelled.localizedDescription, cancelled: true)
                }
                let reopened = try LocalMaterialDatabase.openLibrary(root: root)
                XCTAssertNil(reopened.state.record(for: kind))
                XCTAssertEqual(reopened.state.attempts[kind.rawValue]?.problem, problem)
                let status = FileStatusPresentation.material(reopened.state, kind: kind, year: 2032)
                XCTAssertEqual(status.updateState, .unavailable)
                XCTAssertEqual(status.status.detail, problem.message)
            }
        }
    }

    func testIsolatedLibraryRejectsChangedSourceAndKeepsOtherFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try MaterialLibrary(root: root.appendingPathComponent("live"))
        func seed(_ target: MaterialLibrary, _ kind: MaterialKind, _ digest: String) throws {
            let staged = target.newStagingURL()
            try Data("%PDF-fictional".utf8).write(to: staged)
            try target.commit(staged: staged, kind: kind, source: MaterialSource(grant: nil, childName: nil),
                originalName: "fictional.pdf", byteCount: 14, digest: digest, modifiedAt: nil)
        }
        try seed(library, .timetable, "v1")
        let expected = try library.pipelineIdentity(.timetable)
        let isolated = try library.isolatedCopy(at: root.appendingPathComponent("job"))
        try seed(isolated, .timetable, "v2")
        try seed(library, .events, "event")
        let ticket = FilePipeline.Ticket(source: .timetable, reason: .manual, period: .current(), limits: .init(), now: { 0 })
        try library.acceptPipeline(isolated, kind: .timetable, expected: expected, ticket: ticket)
        XCTAssertEqual(library.state.record(for: .timetable)?.digest, "v2")
        XCTAssertEqual(library.state.record(for: .events)?.digest, "event")
        let staleTicket = FilePipeline.Ticket(source: .timetable, reason: .manual, period: .current(), limits: .init(), now: { 0 })
        XCTAssertThrowsError(try library.acceptPipeline(isolated, kind: .timetable, expected: expected, ticket: staleTicket))
        XCTAssertEqual(library.state.record(for: .timetable)?.digest, "v2")
    }

    func testSpecialSnapshotPreservesOtherSourceAndRejectsStaleCommit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root.appendingPathComponent("live"))
        func seed(_ store: SpecialScheduleStore, _ kind: SpecialScheduleKind, _ digest: String) throws {
            let staged = store.newStagingURL(); let bytes = Data("%PDF-fictional".utf8)
            try bytes.write(to: staged)
            try store.saveSelection(staged: staged, kind: kind, originalName: "fictional.pdf", byteCount: bytes.count, digest: digest)
        }
        try seed(store, .exam, "before")
        let expected = try store.pipelineIdentity(.exam)
        let copy = try store.isolatedCopy(at: root.appendingPathComponent("job"))
        try seed(copy, .exam, "after")
        try seed(store, .examReturn, "other")
        let ticket = FilePipeline.Ticket(source: .exam, reason: .manual, period: .current(), limits: .init(), now: { 0 })
        try store.acceptPipeline(copy, kind: .exam, expected: expected, ticket: ticket)
        XCTAssertEqual(store.sources[.exam]?.digest, "after")
        XCTAssertEqual(store.sources[.examReturn]?.digest, "other")
        let stale = FilePipeline.Ticket(source: .exam, reason: .manual, period: .current(), limits: .init(), now: { 0 })
        XCTAssertThrowsError(try store.acceptPipeline(copy, kind: .exam, expected: expected, ticket: stale))
        let reopened = try SpecialScheduleStore(root: root.appendingPathComponent("live"))
        XCTAssertEqual(reopened.sources[.exam]?.digest, "after")
        XCTAssertEqual(reopened.sources[.examReturn]?.digest, "other")
    }

    func testLateStageAndProgressCannotEraseExpiredDeadline() throws {
        let clock = PipelineClock()
        let ticket = FilePipeline.Ticket(source: .changes, reason: .manual, period: .current(), limits: .init(), now: { clock.now() })
        clock.advance(30)
        ticket.enter(.parsing)
        XCTAssertEqual(ticket.stage, .access)
        XCTAssertThrowsError(try ticket.check())
        let secondClock = PipelineClock()
        let second = FilePipeline.Ticket(source: .exam, reason: .manual, period: .current(), limits: .init(), now: { secondClock.now() })
        second.enter(.acquiring); secondClock.advance(60); second.progress()
        XCTAssertThrowsError(try second.check())
        XCTAssertThrowsError(try second.beginCommit(period: .current()))
    }

    func testClearPresentationDuringCommitCannotStrandLane() throws {
        let pipeline = FilePipeline()
        try pipeline.run(source: .changes, reason: .manual, period: .current(), cancelled: {}, work: { _ in 1 }, cleanup: {},
            commit: { _, ticket in
                try ticket.beginCommit(period: .current())
                pipeline.clearStatuses([.changes])
                ticket.didCommit()
            })
        XCTAssertFalse(pipeline.isRecovering(.changes))
        XCTAssertNil(pipeline.snapshot[.changes])
    }

    func testSavingCanFinishAfterDeadlineWithoutPermittingAnotherAttempt() throws {
        let clock = PipelineClock()
        let pipeline = FilePipeline(now: { clock.now() })
        try pipeline.run(source: .changes, reason: .manual, period: .current(), cancelled: {}, work: { ticket in
            ticket.enter(.checkingDigest)
            clock.advance(239)
            return 1
        }, cleanup: {}, commit: { _, ticket in
            try ticket.beginCommit(period: .current())
            clock.advance(1)
            pipeline.cancel([.changes])
            XCTAssertEqual(pipeline.snapshot[.changes]?.stage, .saving)
            XCTAssertTrue(pipeline.isRecovering(.changes))
            XCTAssertThrowsError(try pipeline.run(source: .changes, reason: .manual, period: .current(),
                cancelled: {}, work: { _ in XCTFail("Provider must wait for save"); return 2 },
                cleanup: {}, commit: { _, _ in XCTFail("Must not save concurrently") })) {
                XCTAssertEqual($0 as? FilePipeline.Failure, .recovering)
            }
            try ticket.check()
            ticket.didCommit()
        })
        XCTAssertFalse(pipeline.isRecovering(.changes))
        XCTAssertEqual(pipeline.snapshot[.changes]?.stage, .succeeded)
    }

    func testPipelineCanRepairMissingMaterialCopyEvenWhenOriginalBytesMatch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try MaterialLibrary(root: root.appendingPathComponent("live"))
        let source = MaterialSource()
        func save(_ library: MaterialLibrary) throws {
            let file = library.newStagingURL()
            try Data([42]).write(to: file)
            defer { library.discardStaging(file) }
            try library.commit(staged: file, kind: .changes, source: source, originalName: "fictional.xlsx",
                byteCount: 1, digest: "same", modifiedAt: nil, reuseUnchanged: true)
        }
        try save(library)
        let old = try XCTUnwrap(library.localURL(for: .changes))
        try FileManager.default.removeItem(at: old)
        let identity = try library.pipelineIdentity(.changes)
        let copy = try library.pipelineSnapshot(.changes).open(at: root.appendingPathComponent("work"))
        try save(copy)
        let ticket = FilePipeline.Ticket(source: .changes, reason: .manual, period: .current(), limits: .init(), now: { 0 })
        try library.acceptPipeline(copy, kind: .changes, expected: identity, ticket: ticket)
        let repaired = try XCTUnwrap(library.localURL(for: .changes))
        XCTAssertNotEqual(repaired, old)
        XCTAssertEqual(try Data(contentsOf: repaired), Data([42]))
    }

    func testCancelledAdmissionNeverLaunchesProvider() {
        let pipeline = FilePipeline()
        XCTAssertThrowsError(try pipeline.run(source: .changes, reason: .manual, period: .current(),
            cancelled: { throw FilePipeline.Failure.cancelled }, work: { _ in XCTFail("Provider must not start"); return 1 },
            cleanup: {}, commit: { _, _ in XCTFail("No commit") }))
        XCTAssertFalse(pipeline.isRecovering(.changes))
    }

    func testCancellationAtRetryReplacementStopsNewProvider() throws {
        final class Probe: @unchecked Sendable {
            let lock = NSLock(), done = DispatchSemaphore(value: 0)
            var calls = 0
        }
        let probe = Probe()
        var limits = FilePipeline.Limits(); limits.retryDelay = 0
        let pipeline = FilePipeline(limits: limits)
        let owner = DispatchQueue(label: "fictional-retry-owner")
        XCTAssertThrowsError(try pipeline.run(source: .exam, reason: .manual, period: .current(), cancelled: {},
            registerCancellation: { _ in
                if pipeline.snapshot[.exam]?.attempt == 1 { pipeline.cancel([.exam]) }
            }, work: { _ in
                probe.lock.lock(); probe.calls += 1; probe.lock.unlock()
                throw URLError(.networkConnectionLost)
            }, cleanup: { probe.done.signal() }, retryQueue: owner, commit: { (_: Int, _) in XCTFail("No commit") }))
        XCTAssertEqual(probe.done.wait(timeout: .now() + 5), .success)
        probe.lock.lock(); defer { probe.lock.unlock() }
        XCTAssertEqual(probe.calls, 1)
        XCTAssertFalse(pipeline.isRecovering(.exam))
        XCTAssertEqual(pipeline.snapshot[.exam]?.stage, .cancelled)
    }

    func testSelectionIntentRejectsAnOlderNotYetStartedRequest() {
        let pipeline = FilePipeline()
        let admitted = pipeline.intentSnapshot["changes"]!
        pipeline.cancel("changes") // Selection B arrives before queued A registers its ticket.
        XCTAssertThrowsError(try pipeline.run(source: .changes, reason: .selection, period: .current(), cancelled: {},
            work: { _ in XCTFail("Superseded request must not access provider"); return 0 }, cleanup: {},
            expectedIntent: admitted, commit: { _, _ in XCTFail("Superseded commit") })) { error in
                XCTAssertEqual(error as? FilePipeline.Failure, .stale)
            }
        XCTAssertFalse(pipeline.isRecovering(.changes))
    }

    func testSourceCancellationDoesNotDropAnotherDrainedBatchRequest() {
        var checked: [MaterialKind] = []
        XCTAssertThrowsError(try SelectedFileRefresher.refresh(requested: ["timetable", "changes"], check: {}) { kind in
            checked.append(kind)
            if kind == .timetable { throw FilePipeline.Failure.cancelled }
        })
        XCTAssertEqual(checked, [.timetable, .changes])
    }

    func testRetryBudgetExpiresEvenWhenOwnerQueueCannotRun() throws {
        let clock = PipelineClock()
        var limits = FilePipeline.Limits(); limits.retryDelay = 0
        let pipeline = FilePipeline(limits: limits, now: { clock.now() })
        let owner = DispatchQueue(label: "fictional-blocked-owner")
        owner.suspend()
        defer { owner.resume() }
        XCTAssertThrowsError(try pipeline.run(source: .examReturn, reason: .manual, period: .current(), cancelled: {},
            work: { _ in throw URLError(.networkConnectionLost) }, cleanup: {}, retryQueue: owner,
            commit: { (_: Int, _) in XCTFail("No commit") }))
        clock.advance(240)
        XCTAssertEqual(pipeline.snapshot[.examReturn]?.stage, .timedOut)
        XCTAssertFalse(pipeline.isRecovering(.examReturn))
    }

    #if canImport(Darwin)
    func testInjectedProviderCannotPublishDelayedCompletionForAnySelectedKind() {
        final class Provider: SelectedFileProviding, @unchecked Sendable {
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            func copy(_ url: URL, to staged: URL, source: FileRefreshDiagnostics.Source?, workbook: Bool,
                      control: AcquisitionControl) throws -> SelectedFileCopy {
                control.pipelineTicket?.enter(.access)
                entered.signal(); release.wait()
                // Deliberately noncooperative: ignore cancellation and return late.
                return SelectedFileCopy(count: workbook ? 4 : 14, digest: "fictional", modifiedAt: nil, receipt: .unobserved)
            }
        }
        for source in FileRefreshDiagnostics.Source.allCases {
            let clock = PipelineClock(), provider = Provider(), done = DispatchSemaphore(value: 0), cleaned = DispatchSemaphore(value: 0)
            let pipeline = FilePipeline(now: { clock.now() })
            let control = AcquisitionControl(); control.provider = provider
            DispatchQueue.global().async {
                defer { done.signal() }
                do {
                    try pipeline.run(source: source, reason: .automatic, period: .current(), cancelled: control.check,
                        registerCancellation: control.registerCancellationTarget, work: { ticket in
                            let inner = AcquisitionControl(); inner.pipelineTicket = ticket; inner.provider = control.provider
                            return try inner.provider.copy(URL(fileURLWithPath: "/fictional-input"), to: URL(fileURLWithPath: "/fictional-stage"),
                                source: source, workbook: source == .changes, control: inner)
                        }, cleanup: { cleaned.signal() }, commit: { _, _ in XCTFail("Late provider commit") })
                } catch FilePipeline.Failure.timedOut { }
                catch { XCTFail("Unexpected provider outcome") }
            }
            XCTAssertEqual(provider.entered.wait(timeout: .now() + 5), .success)
            clock.advance(30)
            XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
            XCTAssertTrue(pipeline.isRecovering(source))
            provider.release.signal()
            XCTAssertEqual(cleaned.wait(timeout: .now() + 5), .success)
            XCTAssertFalse(pipeline.isRecovering(source))
        }
    }
    #endif

    func testDiagnosticElapsedTimeUsesInjectedMonotonicClock() {
        final class Clock: @unchecked Sendable {
            let lock = NSLock()
            private var tick: TimeInterval = 100
            func now() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return tick }
            func advance() { lock.lock(); defer { lock.unlock() }; tick += 2.5 }
        }
        let clock = Clock()
        let diagnostic = FileRefreshDiagnostics(now: { clock.now() })
        diagnostic.record(.refreshStarted, source: .changes)
        clock.advance()
        diagnostic.record(.cancelled, source: .changes)
        XCTAssertEqual(diagnostic.snapshot.entries.map(\.elapsedMilliseconds), [0, 2500])
    }

    func testBlockedReaderRejectsLateBytesAfterCancellation() {
        final class Provider: @unchecked Sendable {
            let lock = NSLock()
            let entered = DispatchSemaphore(value: 0)
            let release = DispatchSemaphore(value: 0)
            let finished = DispatchSemaphore(value: 0)
            var cancelled = false, completed = false, writes = 0, rejected = false
            func check() throws {
                lock.lock(); defer { lock.unlock() }
                if cancelled { throw MaterialError.cancelled }
            }
        }
        let provider = Provider()
        DispatchQueue.global().async {
            do {
                _ = try MaterialFileReader.read(isWorkbook: false, check: provider.check, next: {
                    provider.entered.signal()
                    guard provider.release.wait(timeout: .now() + 5) == .success else {
                        throw MaterialError.unavailable
                    }
                    return Data("%PDF-fictional".utf8)
                }, write: { _ in
                    provider.lock.lock(); defer { provider.lock.unlock() }
                    provider.writes += 1
                }, synchronize: {})
            } catch MaterialError.cancelled {
                provider.lock.lock(); provider.rejected = true; provider.lock.unlock()
            } catch { XCTFail("Unexpected provider result: \(type(of: error))") }
            provider.lock.lock(); provider.completed = true; provider.lock.unlock()
            provider.finished.signal()
        }
        defer { provider.release.signal() }
        XCTAssertEqual(provider.entered.wait(timeout: .now() + 5), .success)
        provider.lock.lock()
        provider.cancelled = true
        XCTAssertFalse(provider.completed, "Cancel is a request; the provider still owns the read")
        provider.lock.unlock()
        provider.release.signal()
        XCTAssertEqual(provider.finished.wait(timeout: .now() + 5), .success)
        provider.lock.lock(); defer { provider.lock.unlock() }
        XCTAssertTrue(provider.rejected)
        XCTAssertTrue(provider.completed)
        XCTAssertEqual(provider.writes, 0, "Late bytes must never reach the staged result")
    }

    func testSharedReaderChecksCancellationBeforeReadAndAfterLateBytesOrEOF() {
        for late in [Data("%PDF-fictional".utf8), Data(), nil] {
            var cancelled = false
            var reads = 0, writes = 0, syncs = 0
            XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false, check: {
                if cancelled { throw MaterialError.cancelled }
            }, next: {
                reads += 1
                cancelled = true // The read returns after the user has cancelled.
                return late
            }, write: { _ in writes += 1 }, synchronize: { syncs += 1 })) { error in
                guard case MaterialError.cancelled = error else { return XCTFail("Expected cancellation") }
            }
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(writes, 0)
            XCTAssertEqual(syncs, 0)
        }
        XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false,
            check: { throw MaterialError.cancelled }, next: { XCTFail("Must not read"); return nil },
            write: { _ in XCTFail("Must not write") }, synchronize: { XCTFail("Must not synchronize") }))
    }

    func testSharedReaderPrefersCancellationOverLateIOErrors() {
        enum Failure: Error { case io }
        for stage in 0...2 {
            var cancelled = false
            var chunks = [Data("%PDF-fictional".utf8)]
            XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false,
                check: { if cancelled { throw MaterialError.cancelled } }, next: {
                    if stage == 0 { cancelled = true; throw Failure.io }
                    return chunks.isEmpty ? nil : chunks.removeFirst()
                }, write: { _ in
                    if stage == 1 { cancelled = true; throw Failure.io }
                }, synchronize: {
                    if stage == 2 { cancelled = true; throw Failure.io }
                })) { error in
                    guard case MaterialError.cancelled = error else { return XCTFail("Expected cancellation") }
                }
        }
        XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false, check: {},
            next: { throw Failure.io }, write: { _ in }, synchronize: {})) { error in
                guard case Failure.io = error else { return XCTFail("Must retain genuine I/O errors") }
            }
    }

    func testSharedReaderRejectsCancellationDuringSynchronize() {
        var cancelled = false
        var chunks = [Data("%PDF-fictional".utf8)]
        XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false,
            check: { if cancelled { throw MaterialError.cancelled } },
            next: { chunks.isEmpty ? nil : chunks.removeFirst() }, write: { _ in },
            synchronize: { cancelled = true })) { error in
                guard case MaterialError.cancelled = error else { return XCTFail("Expected cancellation") }
            }
    }

    func testSharedReaderValidatesSplitHeadersSizeAndDigest() throws {
        // Independent SHA-256 reference for the complete fictional byte sequence.
        let bytes = Data("%PDF-fictional".utf8)
        var chunks = bytes.map { Data([$0]) }
        var written = Data(), syncs = 0
        let receipt = try MaterialFileReader.read(isWorkbook: false, maximumBytes: bytes.count,
            check: {}, next: { chunks.isEmpty ? nil : chunks.removeFirst() },
            write: { written.append($0) }, synchronize: { syncs += 1 })
        XCTAssertEqual(receipt.count, bytes.count)
        XCTAssertEqual(receipt.digest, "e604a9e2526224c5bddcfba54526a87aa865443e5967c35f05675c532f332060")
        XCTAssertEqual(written, bytes)
        XCTAssertEqual(syncs, 1)
        var reads = 0
        XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: false, maximumBytes: bytes.count - 1,
            check: {}, next: { reads += 1; return bytes }, write: { _ in XCTFail("Oversize write") },
            synchronize: { XCTFail("Oversize sync") })) { error in
                guard case MaterialError.tooLarge = error else { return XCTFail("Expected size rejection") }
            }
        XCTAssertEqual(reads, 1)
        for (workbook, input) in [(false, Data()), (false, Data("invalid".utf8)),
                                   (true, bytes), (false, Data([0x50, 0x4b, 0x03, 0x04]))] {
            var chunks = [input]
            XCTAssertThrowsError(try MaterialFileReader.read(isWorkbook: workbook, check: {},
                next: { chunks.isEmpty ? nil : chunks.removeFirst() }, write: { _ in },
                synchronize: { XCTFail("Invalid data must not reach success") }))
        }
        var zipChunks = [Data([0x50]), Data([0x4b, 0x03]), Data([0x04])]
        let zip = try MaterialFileReader.read(isWorkbook: true, check: {},
            next: { zipChunks.isEmpty ? nil : zipChunks.removeFirst() }, write: { _ in }, synchronize: {})
        XCTAssertEqual(zip.count, 4)
    }

    func testSharedReaderCopiesRealFileIntoStagingWithoutChangingSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("fictional.pdf")
        let staged = root.appendingPathComponent("staged")
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: source)
        let receipt = try MaterialFileReader.copy(source, to: staged, isWorkbook: false, check: {})
        XCTAssertEqual(receipt.count, bytes.count)
        XCTAssertEqual(try Data(contentsOf: staged), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testRefreshPreservesTheFirstFailureAndStillChecksOtherSources() throws {
        let failure = PDFParseError(code: .unsupported, page: 2)
        var checked: [MaterialKind] = []
        XCTAssertThrowsError(try SelectedFileRefresher.refresh(requested: ["timetable", "changes"], check: {}) { kind in
            checked.append(kind)
            if kind == .timetable { throw failure }
        }) { error in
            XCTAssertEqual((error as? PDFParseError)?.code, .unsupported)
            XCTAssertEqual((error as? PDFParseError)?.page, 2)
        }
        XCTAssertEqual(checked, [.timetable, .changes])
    }

    func testRefreshPreservesChangeAndAcquisitionFailureKinds() {
        let errors: [Error] = [ChangeParseError(code: .defaultYear), MaterialError.tooLarge, MaterialError.accessExpired]
        for expected in errors {
            XCTAssertThrowsError(try SelectedFileRefresher.refresh(requested: ["changes"], check: {}) { _ in throw expected }) { error in
                XCTAssertEqual(String(reflecting: type(of: error)), String(reflecting: type(of: expected)))
                XCTAssertEqual(error.localizedDescription, expected.localizedDescription)
            }
        }
    }

    func testRefreshCancellationStopsBeforeTheNextSourceAndAfterTheLastRead() {
        let errors: [Error] = [MaterialError.cancelled, PDFParseError(code: .cancelled),
                               ChangeParseError(code: .cancelled), CancellationError()]
        for finalSource in [false, true] {
            for expected in errors {
                var calls: [MaterialKind] = []
                XCTAssertThrowsError(try SelectedFileRefresher.refresh(requested: finalSource ? ["changes"] : ["timetable", "changes"],
                    check: {}) { kind in calls.append(kind); throw expected }) { error in
                    XCTAssertEqual(String(reflecting: type(of: error)), String(reflecting: type(of: expected)))
                    XCTAssertEqual(error.localizedDescription, expected.localizedDescription)
                }
                XCTAssertEqual(calls, finalSource ? [.changes] : [.timetable])
                let lastEntry = FileRefreshDiagnostics.shared.snapshot.entries.last
                XCTAssertEqual(lastEntry?.step, .cancelled)
                XCTAssertEqual(lastEntry?.source, finalSource ? .changes : .timetable)
            }
        }
    }

    func testUserSelectionsWaitAndPreserveOrderAcrossAllFourKinds() {
        var pending = PendingFileSelections<String, Int>()
        for (index, kind) in ["timetable", "changes", "exam", "examReturn"].enumerated() {
            pending.append(index, kind: kind)
        }
        XCTAssertNil(pending.take(busy: true))
        for (index, kind) in ["timetable", "changes", "exam", "examReturn"].enumerated() {
            let next = pending.take(busy: false)
            XCTAssertEqual(next?.kind, kind)
            XCTAssertEqual(next?.selection, index)
        }
        XCTAssertNil(pending.take(busy: false))
    }

    func testPendingSelectionKeepsLeaseUntilCancellationOrRetentionClear() {
        var pending = PendingFileSelections<String, NSObject>()
        weak var lease: NSObject?
        do {
            let selection = NSObject()
            lease = selection
            pending.append(selection, kind: "exam")
        }
        XCTAssertNotNil(lease)
        XCTAssertNil(pending.take(busy: true))
        XCTAssertNotNil(lease)
        pending.clear()
        XCTAssertNil(lease)
        XCTAssertNil(pending.take(busy: false))
    }

    func testCancellationDropsPendingAndLateCallbacksUntilForegroundReturn() {
        var queue = FileRefreshQueue()
        queue.setForeground(true)
        queue.request("timetable")
        queue.suspend()
        queue.request("changes")
        queue.setForeground(true)
        XCTAssertTrue(queue.suspended)
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        queue.setForeground(false)
        XCTAssertTrue(queue.suspended, "Backgrounding does not resume paused file checks")
        queue.setForeground(false)
        XCTAssertTrue(queue.suspended, "A background refresh cannot clear a user's pause")
        queue.setForeground(true)
        queue.request("changes")
        XCTAssertFalse(queue.suspended)
        XCTAssertEqual(queue.take(ready: true, busy: false), ["changes"])
    }

    func testRefreshDiagnosticIsBoundedAndSafeUnderConcurrentEvents() throws {
        let diagnostic = FileRefreshDiagnostics(limit: 64)
        DispatchQueue.concurrentPerform(iterations: 1_000) { _ in
            diagnostic.record(.metadataUnavailable, source: .changes)
        }
        let snapshot = diagnostic.snapshot
        XCTAssertEqual(snapshot.totalEntries, 1_000)
        XCTAssertEqual(snapshot.omittedEntries, 936)
        XCTAssertEqual(snapshot.entries.count, 64)
        XCTAssertEqual(snapshot.entries.first?.sequence, 1)
        XCTAssertEqual(snapshot.entries.last?.sequence, 1_000)
        XCTAssertEqual(snapshot.entries.map(\.sequence), snapshot.entries.map(\.sequence).sorted())
        let data = try XCTUnwrap(diagnostic.report.split(separator: "\n").last?.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        XCTAssertEqual(Set(entries[0].keys), ["sequence", "elapsedMilliseconds", "step", "source"])
        XCTAssertTrue(entries.allSatisfy { $0["source"] as? String == "changes" })
    }

    func testBusyOrLoadingDefersAndCoalescesNotifications() {
        var queue = FileRefreshQueue()
        queue.setForeground(true)
        queue.request("timetable")
        queue.request("timetable")
        queue.request("changes")
        XCTAssertTrue(queue.take(ready: false, busy: false).isEmpty)
        XCTAssertTrue(queue.take(ready: true, busy: true).isEmpty)
        XCTAssertEqual(queue.take(ready: true, busy: false), ["timetable", "changes"])
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        queue.request("timetable")
        XCTAssertEqual(queue.take(ready: true, busy: false), ["timetable"])
    }

    func testBackgroundDropsPendingAndLateNotifications() {
        var queue = FileRefreshQueue()
        queue.setForeground(true)
        queue.request("exam")
        queue.setForeground(false)
        queue.request("return")
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        queue.setForeground(true)
        XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        queue.request("return")
        XCTAssertEqual(queue.take(ready: true, busy: false), ["return"])
    }

    func testObservationIdentityIgnoresSuccessfulReadMetadata() {
        let bookmark = Data("fictional-bookmark".utf8)
        let first = SourceGrant(bookmark: bookmark, name: "架空資料A.pdf", isFolder: false)
        let renamed = SourceGrant(bookmark: bookmark, name: "架空資料B.pdf", isFolder: false)
        XCTAssertEqual(SelectedFileSource(id: "exam", grant: first), SelectedFileSource(id: "exam", grant: renamed))
        let folder = SourceGrant(bookmark: bookmark, name: "架空フォルダ", isFolder: true)
        XCTAssertNotEqual(SelectedFileSource(id: "exam", grant: folder, childName: "A.pdf"),
                          SelectedFileSource(id: "exam", grant: folder, childName: "B.pdf"))
    }

    func testFailedVersionRetriesOnlyAfterQuietPeriodAndSuccessfulReadAcknowledgesIt() {
        var gate = FileContentChangeGate()
        let a = FileContentVersion(identity: NSNumber(value: 1), generation: NSNumber(value: 1))
        let b = FileContentVersion(identity: NSNumber(value: 1), generation: NSNumber(value: 2))
        gate.record(a)
        XCTAssertTrue(gate.shouldRefresh(b, now: 0))
        XCTAssertFalse(gate.shouldRefresh(b, now: 0.1))
        gate.readFailed(now: 0.2)
        for tick in 1...20 { XCTAssertFalse(gate.shouldRefresh(b, now: Double(tick) / 10 + 0.2)) }
        XCTAssertTrue(gate.shouldRefresh(b, now: 3.3))
        gate.record(b)
        XCTAssertFalse(gate.shouldRefresh(b, now: 5))
        XCTAssertTrue(gate.shouldRefresh(a, now: 5.1))
        gate.readFailed(now: 5.2)
        XCTAssertTrue(gate.shouldRefresh(FileContentVersion(identity: NSNumber(value: 2), generation: NSNumber(value: 1)), now: 5.3))
    }

    func testRepeatedAttributeNotificationsDoNotRestartRefresh() {
        let version = FileContentVersion(identity: NSNumber(value: 1), generation: NSNumber(value: 10))
        var gate = FileContentChangeGate()
        var queue = FileRefreshQueue()
        queue.setForeground(true)
        gate.record(version)
        // Model the provider emitting an attribute notification after each read.
        for _ in 0..<100 {
            if gate.shouldRefresh(version) { queue.request("timetable") }
            XCTAssertTrue(queue.take(ready: true, busy: false).isEmpty)
        }
        let changed = FileContentVersion(identity: NSNumber(value: 1), generation: NSNumber(value: 11))
        XCTAssertTrue(gate.shouldRefresh(changed))
        XCTAssertFalse(gate.shouldRefresh(changed))
    }

    func testReplacementAndUnsupportedVersionsStillGetHashChecked() {
        var gate = FileContentChangeGate()
        gate.record(FileContentVersion(identity: NSNumber(value: 1), generation: NSNumber(value: 10)))
        XCTAssertTrue(gate.shouldRefresh(FileContentVersion(identity: NSNumber(value: 2), generation: NSNumber(value: 10))))
        XCTAssertTrue(gate.shouldRefresh(nil))
        XCTAssertTrue(gate.shouldRefresh(nil))
    }

#if canImport(Darwin)
    @MainActor
    func testFailedRegistrationRetriesSameSourceWithoutInitialRefreshAndRejectsLateCallbacks() async throws {
        final class Fake: SelectedFileObserving {
            var starts: [Bool] = []; var stops = 0
            func start(requestInitialRefresh: Bool) { starts.append(requestInitialRefresh) }
            func stop() { stops += 1 }
            func refreshCompleted() {}
        }
        func drainCallbacks() async {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        var observations: [Fake] = []; var callbacks: [(Bool) -> Void] = []; var completed: [() -> Void] = []
        let monitor = SelectedFileMonitor(changed: { _ in XCTFail("Unexpected refresh") }, factory: { _, _, registered, ended in
            let fake = Fake(); observations.append(fake); callbacks.append(registered); completed.append(ended); return fake
        })
        let source = SelectedFileSource(id: "changes", grant: SourceGrant(bookmark: Data([1]), name: "fictional.xlsx", isFolder: false))
        monitor.update([source]); monitor.setForeground(true)
        XCTAssertEqual(observations.count, 1)
        monitor.update([source]); XCTAssertEqual(observations.count, 1)
        callbacks[0](false); completed[0](); await drainCallbacks()
        monitor.update([source]); XCTAssertEqual(observations.count, 1)
        monitor.update([source], retryFailedFor: ["timetable"]); XCTAssertEqual(observations.count, 1)
        monitor.update([source], retryFailedFor: ["changes"])
        XCTAssertEqual(observations.count, 2); XCTAssertEqual(observations[1].starts, [false])
        callbacks[1](true); completed[1](); await drainCallbacks()
        monitor.update([source], retryFailedFor: ["changes"]); XCTAssertEqual(observations.count, 2)
        callbacks[0](false); await drainCallbacks()
        XCTAssertEqual(monitor.registrations["changes"], .registered)
        monitor.setForeground(false); callbacks[1](true); await drainCallbacks()
        XCTAssertEqual(monitor.registrations["changes"], .stopped)
        monitor.update([source], retryFailedFor: ["changes"]); XCTAssertEqual(observations.count, 2)
        monitor.setForeground(true); XCTAssertEqual(observations.count, 3)
        monitor.setForeground(false)
    }

    @MainActor
    func testRegistrationTimeoutKeepsOnlyItsWorkerOwnedAndDiscardsLateCallbacks() async throws {
        final class Fake: SelectedFileObserving {
            var stops = 0
            func start(requestInitialRefresh: Bool) {}
            func stop() { stops += 1 }
            func refreshCompleted() {}
        }
        struct Observation {
            let worker: Fake
            let changed: () -> Void
            let registered: (Bool) -> Void
            let ended: () -> Void
        }
        var observers: [String: [Observation]] = [:]
        var deadlines: [String: CheckedContinuation<Void, Never>] = [:]
        var requests: [String] = []
        let monitor = SelectedFileMonitor(waitForRegistration: { id in
            await withCheckedContinuation { deadlines[id] = $0 }
        }, changed: { requests.append($0) }, factory: { source, changed, registered, ended in
            let worker = Fake()
            observers[source.id, default: []].append(.init(worker: worker, changed: changed, registered: registered, ended: ended))
            return worker
        })
        let changes = SelectedFileSource(id: "changes", grant: SourceGrant(bookmark: Data([1]), name: "fictional.xlsx", isFolder: false))
        let timetable = SelectedFileSource(id: "timetable", grant: SourceGrant(bookmark: Data([2]), name: "fictional.pdf", isFolder: false))
        monitor.setForeground(true)
        monitor.update([changes, timetable])
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while deadlines.count < 2, ContinuousClock.now < deadline { await Task.yield() }
        defer {
            monitor.setForeground(false)
            deadlines.values.forEach { $0.resume() }
        }
        let slow = try XCTUnwrap(observers["changes"]?.first)
        let available = try XCTUnwrap(observers["timetable"]?.first)
        try XCTUnwrap(deadlines.removeValue(forKey: "changes")).resume()
        available.registered(true); available.ended()
        while (monitor.registrations["changes"] != .timedOut || monitor.isRegistering("timetable")),
              ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertEqual(monitor.blockedSources, ["changes"])
        XCTAssertEqual(monitor.registrations["changes"], .timedOut)
        XCTAssertEqual(monitor.registrations["timetable"], .registered)
        XCTAssertEqual(slow.worker.stops, 1)
        XCTAssertEqual(monitor.timeoutStatus("changes")?.title, "監視登録が期限切れ・終了待ち")

        slow.registered(true); slow.changed()
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
        XCTAssertEqual(monitor.registrations["changes"], .timedOut)
        XCTAssertTrue(requests.isEmpty)
        slow.ended()
        while monitor.isRegistering("changes"), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(monitor.blockedSources.isEmpty)
        XCTAssertEqual(monitor.timeoutStatus("changes")?.title, "監視登録が期限切れ")
        XCTAssertEqual(requests, ["changes"])
        XCTAssertEqual(observers["timetable"]?.count, 1)
    }

    func testReadAcknowledgesMaterializedVersionAndStillDetectsLaterEdit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("fictional.txt")
        let bytes = Data("fictional unchanged content".utf8)
        try bytes.write(to: file)
        let noRefresh = expectation(description: "delayed notification for already-read content")
        noRefresh.isInverted = true
        let externalEdit = expectation(description: "later real edit remains observable")
        let lock = NSLock()
        var external = false
        let presenter = SelectedFilePresenter(url: file, source:.changes) {
            lock.lock(); let isExternal = external; lock.unlock()
            if isExternal { externalEdit.fulfill() } else { noRefresh.fulfill() }
        }
        NSFileCoordinator.addFilePresenter(presenter)
        defer { presenter.deactivate(); NSFileCoordinator.removeFilePresenter(presenter) }
        let access = SelectedFilePresenter.readAccess(for:file, source:.changes)
        try capturedRead(of:file, using:access).acknowledge()
        var error: NSError?
        // Simulate a provider replacing its local materialization with identical
        // bytes during access: the source identity changes, the digest does not.
        var receipt: SelectedFilePresenter.ReadReceipt?
        access.coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            do {
                try bytes.write(to: url, options: .atomic)
                let read = try access.read(at: url) { try Data(contentsOf: url) }
                XCTAssertEqual(read.value, bytes)
                receipt = read.receipt
            } catch { XCTFail("Synthetic read failed") }
        }
        XCTAssertNil(error)
        try XCTUnwrap(receipt).acknowledge()
        for _ in 0..<10 { presenter.presentedItemDidChange() }
        wait(for: [noRefresh], timeout: 0.5)
        lock.lock(); external = true; lock.unlock()
        let writer = NSFileCoordinator(filePresenter: nil)
        writer.coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            do { try Data("fictional next content".utf8).write(to: url, options: .atomic) }
            catch { XCTFail("Synthetic external write failed") }
        }
        XCTAssertNil(error)
        wait(for: [externalEdit], timeout: 5)
    }

    func testFailedReadDoesNotAcknowledgeUnreadVersion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("fictional.txt")
        try Data("before".utf8).write(to: file)
        let retry = expectation(description: "failed read must leave the change detectable")
        let presenter = SelectedFilePresenter(url: file) { retry.fulfill() }
        NSFileCoordinator.addFilePresenter(presenter)
        defer { presenter.deactivate(); NSFileCoordinator.removeFilePresenter(presenter) }
        let access = SelectedFilePresenter.readAccess(for: file)
        var error: NSError?
        let baseline = try capturedRead(of:file, using:access)
        baseline.acknowledge()
        access.coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            do { try Data("after".utf8).write(to: url, options: .atomic) }
            catch { XCTFail("Synthetic write failed") }
            do {
                let _: (value: Data, receipt: SelectedFilePresenter.ReadReceipt) = try access.read(at: url) { throw CocoaError(.userCancelled) }
                XCTFail("Cancelled read unexpectedly succeeded")
            } catch {
                XCTAssertEqual((error as? CocoaError)?.code, .userCancelled)
            }
        }
        XCTAssertNil(error)
        presenter.presentedItemDidChange()
        wait(for: [retry], timeout: 5)
    }

    func testCopiedVersionRemainsObservableUntilCommittedAndCannotHideNewerBytes() throws {
        for commitOlderCopy in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at:root, withIntermediateDirectories:true)
            defer { try? FileManager.default.removeItem(at:root) }
            let file = root.appendingPathComponent("fictional.txt")
            try Data("version-one".utf8).write(to:file)
            let refresh = expectation(description: commitOlderCopy ? "newer bytes after commit" : "uncommitted copy")
            let presenter = SelectedFilePresenter(url:file, source:.changes) { refresh.fulfill() }
            NSFileCoordinator.addFilePresenter(presenter)
            defer { presenter.deactivate(); NSFileCoordinator.removeFilePresenter(presenter) }
            let access = SelectedFilePresenter.readAccess(for:file, source:.changes)
            try capturedRead(of:file, using:access).acknowledge()
            let copied = try capturedRead(of:file, using:access, replacingWith:Data("version-two".utf8))
            if commitOlderCopy {
                _ = try capturedRead(of:file, using:access, replacingWith:Data("version-three".utf8))
                copied.acknowledge()
            }
            presenter.presentedItemDidChange()
            wait(for:[refresh], timeout:5)
        }
    }

    private func capturedRead(of file: URL, using access: SelectedFilePresenter.ReadAccess,
                              replacingWith replacement: Data? = nil) throws -> SelectedFilePresenter.ReadReceipt {
        var error: NSError?
        var result: Result<SelectedFilePresenter.ReadReceipt, Error>?
        let read: (URL) -> Void = { url in
            result = Result {
                if let replacement { try replacement.write(to:url, options:.atomic) }
                return try access.read(at:url) { try Data(contentsOf:url) }.receipt
            }
        }
        if replacement != nil {
            access.coordinator.coordinate(writingItemAt:file, options:.forReplacing, error:&error) { read($0) }
        } else {
            access.coordinator.coordinate(readingItemAt:file, options:[], error:&error) { read($0) }
        }
        if let error { throw error }
        return try XCTUnwrap(result).get()
    }

    @MainActor
    func testSuspendedMonitorCannotRestartFromSourceUpdateOrLateWork() async throws {
        var calls: [String] = []
        let monitor = SelectedFileMonitor(changed: { calls.append($0) })
        monitor.update([SelectedFileSource(id: "exam", grant: nil)])
        monitor.setForeground(true)
        monitor.suspend()
        monitor.update([SelectedFileSource(id: "examReturn", grant: nil)])
        monitor.setForeground(true)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertTrue(calls.isEmpty)
        monitor.setForeground(false)
        monitor.setForeground(true)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(calls, ["examReturn"])
        monitor.setForeground(false)
    }

    @MainActor
    func testEveryForegroundEntryChecksOnceAndUnchangedSourcesDoNotLoop() async throws {
        var calls: [String] = []
        let monitor = SelectedFileMonitor(changed: { calls.append($0) })
        let source = SelectedFileSource(id: "exam", grant: nil)
        monitor.update([source])
        monitor.setForeground(true)
        monitor.setForeground(true)
        monitor.update([source])
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(calls, ["exam"])
        monitor.update([source])
        monitor.setForeground(false)
        monitor.setForeground(true)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(calls, ["exam", "exam"])
        monitor.setForeground(false)
    }

    @MainActor
    func testBackgroundAndReselectionInvalidatePendingCallbacks() async throws {
        var calls: [String] = []
        let monitor = SelectedFileMonitor(changed: { calls.append($0) })
        monitor.setForeground(true)
        monitor.update([SelectedFileSource(id: "exam", grant: nil)])
        monitor.setForeground(false)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertTrue(calls.isEmpty)
        monitor.setForeground(true)
        monitor.update([SelectedFileSource(id: "return", grant: nil)])
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(calls, ["return"])
        monitor.setForeground(false)
    }

    func testPresenterRegistersBeforeInitialRefreshAndObservesCoordinatedWrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("fictional.txt")
        try Data("before".utf8).write(to: file)
        let initial = expectation(description: "initial refresh after registration")
        let changed = expectation(description: "provider write notification")
        let lock = NSLock()
        var count = 0
        let observation = SelectedFileObservation(resolve: { (file, nil) }) {
            lock.lock()
            count += 1
            let number = count
            lock.unlock()
            if number == 1 { initial.fulfill() }
            else if number == 2 { changed.fulfill() }
        }
        defer { observation.stop() }
        observation.start()
        wait(for: [initial], timeout: 5)
        XCTAssertTrue(NSFileCoordinator.filePresenters.contains { $0.presentedItemURL == file })
        let writer = NSFileCoordinator(filePresenter: nil)
        var error: NSError?
        writer.coordinate(writingItemAt: file, options: [], error: &error) { url in
            do { try Data("after".utf8).write(to: url) }
            catch { XCTFail("Synthetic write failed") }
        }
        XCTAssertNil(error)
        wait(for: [changed], timeout: 5)
        observation.stop()
        XCTAssertFalse(NSFileCoordinator.filePresenters.contains { $0.presentedItemURL == file })
    }

    func testOwnFileOperationsDoNotFeedBackButExternalWritesStillNotify() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("fictional.txt")
        try Data("before".utf8).write(to: file)
        let initial = expectation(description: "initial read")
        let ownChange = expectation(description: "no self notification")
        ownChange.isInverted = true
        let externalChange = expectation(description: "external changes remain observable")
        let lock = NSLock()
        var initialSeen = false
        var external = false
        let observation = SelectedFileObservation(resolve: { (file, nil) }) {
            lock.lock()
            let first = !initialSeen
            initialSeen = true
            let isExternal = external
            lock.unlock()
            if first { initial.fulfill() }
            else if isExternal { externalChange.fulfill() }
            else { ownChange.fulfill() }
        }
        defer { observation.stop() }
        observation.start()
        wait(for: [initial], timeout: 5)
        // Use the same coordinator factory as both actual PDF/XLSX read paths.
        let ownCoordinator = SelectedFilePresenter.coordinator(for: file)
        var error: NSError?
        ownCoordinator.coordinate(writingItemAt: file, options: [], error: &error) { url in
            do { try Data("own-change".utf8).write(to: url) }
            catch { XCTFail("Synthetic write failed") }
        }
        XCTAssertNil(error)
        wait(for: [ownChange], timeout: 0.4)
        lock.lock(); external = true; lock.unlock()
        let writer = NSFileCoordinator(filePresenter: nil)
        writer.coordinate(writingItemAt: file, options: [], error: &error) { url in
            do { try Data("external-change".utf8).write(to: url) }
            catch { XCTFail("Synthetic write failed") }
        }
        XCTAssertNil(error)
        wait(for: [externalChange], timeout: 5)
    }

    func testStopWhileResolvingCannotRegisterAfterBackground() {
        let resolving = expectation(description: "resolving")
        let noRefresh = expectation(description: "cancelled observation cannot refresh")
        noRefresh.isInverted = true
        let proceed = DispatchSemaphore(value: 0)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let observation = SelectedFileObservation(resolve: {
            resolving.fulfill()
            _ = proceed.wait(timeout: .now() + 5)
            return (file, nil)
        }, changed: { noRefresh.fulfill() })
        observation.start()
        wait(for: [resolving], timeout: 5)
        observation.stop()
        proceed.signal()
        wait(for: [noRefresh], timeout: 0.3)
        XCTAssertFalse(NSFileCoordinator.filePresenters.contains { $0.presentedItemURL == file })
    }
#endif
}
