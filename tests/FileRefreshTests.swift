import XCTest
import Foundation
@testable import TakupokeParsing

final class FileRefreshTests: XCTestCase {
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
