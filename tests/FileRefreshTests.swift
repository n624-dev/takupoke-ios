import XCTest
import Foundation
@testable import TakupokeParsing

final class FileRefreshTests: XCTestCase {
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
        let presenter = SelectedFilePresenter(url: file) {
            lock.lock(); let isExternal = external; lock.unlock()
            if isExternal { externalEdit.fulfill() } else { noRefresh.fulfill() }
        }
        presenter.recordContentVersion(at: file)
        NSFileCoordinator.addFilePresenter(presenter)
        defer { presenter.deactivate(); NSFileCoordinator.removeFilePresenter(presenter) }
        let access = SelectedFilePresenter.readAccess(for: file)
        var error: NSError?
        // Simulate a provider replacing its local materialization with identical
        // bytes during access: the source identity changes, the digest does not.
        access.coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            do {
                try bytes.write(to: url, options: .atomic)
                let read = try access.read(at: url) { try Data(contentsOf: url) }
                XCTAssertEqual(read, bytes)
            } catch { XCTFail("Synthetic read failed") }
        }
        XCTAssertNil(error)
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
        presenter.recordContentVersion(at: file)
        NSFileCoordinator.addFilePresenter(presenter)
        defer { presenter.deactivate(); NSFileCoordinator.removeFilePresenter(presenter) }
        let access = SelectedFilePresenter.readAccess(for: file)
        var error: NSError?
        access.coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            do { try Data("after".utf8).write(to: url, options: .atomic) }
            catch { XCTFail("Synthetic write failed") }
            do {
                let _: Data = try access.read(at: url) { throw CocoaError(.userCancelled) }
                XCTFail("Cancelled read unexpectedly succeeded")
            } catch {
                XCTAssertEqual((error as? CocoaError)?.code, .userCancelled)
            }
        }
        XCTAssertNil(error)
        presenter.presentedItemDidChange()
        wait(for: [retry], timeout: 5)
    }

    @MainActor
    func testSuspendedMonitorCannotRestartFromSourceUpdateOrLateWork() async throws {
        var calls: [String] = []
        let monitor = SelectedFileMonitor { calls.append($0) }
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
        let monitor = SelectedFileMonitor { calls.append($0) }
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
        let monitor = SelectedFileMonitor { calls.append($0) }
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
