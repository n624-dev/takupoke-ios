import XCTest
@testable import TakupokeParsing

final class SchoolDataRecoveryTests: XCTestCase {
    private let manager = FileManager.default
    private func withRoot(_ body: (URL, SchoolDataRetention) throws -> Void) throws {
        let root = manager.temporaryDirectory.appendingPathComponent("fictional-retention-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        try body(root, SchoolDataRetention(root: root))
    }
    private func marker(_ root: URL) -> URL { root.appendingPathComponent("school-data-period.json") }
    private func recovery(_ root: URL) -> URL { root.appendingPathComponent("SchoolDataRetentionRecovery") }
    private var current: SchoolDataPeriod { SchoolDataPeriod(day: SchoolDate(iso8601: "2032-10-01")!) }
    private func seed(_ root: URL) throws {
        for name in SchoolDataRetention.privatePaths + ["SchoolEventsAPI", "preferences"] {
            let url = root.appendingPathComponent(name)
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            try Data("fictional preserved bytes".utf8).write(to: url.appendingPathComponent("fixture"))
        }
    }
    private func assertPublicAndPreferences(_ root: URL) throws {
        for name in ["SchoolEventsAPI", "preferences"] {
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name).appendingPathComponent("fixture")), Data("fictional preserved bytes".utf8))
        }
    }
    func testMalformedMarkersRemainBlockedUntilExplicitQuarantineAndCleanup() throws {
        for raw in ["", "not json", "{", "null", "{\"schoolYear\":2032,\"half\":3}", "{\"schoolYear\":0,\"half\":1}"] {
            try withRoot { root, retention in
                try seed(root); let original = Data(raw.utf8); try original.write(to: marker(root))
                for _ in 0..<3 {
                    XCTAssertThrowsError(try retention.installedPeriod()) { XCTAssertEqual($0 as? SchoolDataRetention.Failure, .invalidMarker) }
                }
                XCTAssertEqual(try Data(contentsOf: marker(root)), original)
                XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent(SchoolDataRetention.privatePaths[0]).path))
                try retention.quarantineInvalidMarker()
                let saved = try XCTUnwrap(manager.contentsOfDirectory(at: recovery(root), includingPropertiesForKeys: nil).first)
                XCTAssertEqual(try Data(contentsOf: saved), original)
                XCTAssertNil(try retention.installedPeriod())
                XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent(SchoolDataRetention.privatePaths[0]).path))
                try retention.replace(with: current); try retention.finishRecovery()
                XCTAssertEqual(try retention.installedPeriod(), current)
                XCTAssertFalse(manager.fileExists(atPath: recovery(root).path))
                for path in SchoolDataRetention.privatePaths { XCTAssertFalse(manager.fileExists(atPath: root.appendingPathComponent(path).path)) }
                try assertPublicAndPreferences(root)
            }
        }
    }
    func testReadFailureAndNonFileMarkerNeverOfferDestructiveRecovery() throws {
        try withRoot { root, retention in
            try retention.replace(with: current); try seed(root)
            let old = try Data(contentsOf: marker(root))
            XCTAssertThrowsError(try retention.installedPeriod(read: { _ in throw CocoaError(.fileReadNoPermission) })) {
                XCTAssertEqual($0 as? SchoolDataRetention.Failure, .unreadableMarker)
            }
            XCTAssertEqual(try Data(contentsOf: marker(root)), old)
            XCTAssertThrowsError(try retention.quarantineInvalidMarker()) // A valid marker is not a recovery candidate.
            XCTAssertFalse(manager.fileExists(atPath: recovery(root).path))
            try manager.removeItem(at: marker(root)); try manager.createDirectory(at: marker(root), withIntermediateDirectories: false)
            XCTAssertThrowsError(try retention.installedPeriod()) { XCTAssertEqual($0 as? SchoolDataRetention.Failure, .unreadableMarker) }
            XCTAssertThrowsError(try retention.quarantineInvalidMarker())
            XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent(SchoolDataRetention.privatePaths[0]).path))
        }
    }
    func testQuarantineFailureDoesNotDeleteMarkerOrPrivateData() throws {
        try withRoot { root, retention in
            try seed(root); let raw = Data("{fictional-invalid".utf8); try raw.write(to: marker(root))
            XCTAssertThrowsError(try retention.quarantineInvalidMarker(move: { _, _ in throw CocoaError(.fileWriteNoPermission) })) {
                XCTAssertEqual($0 as? SchoolDataRetention.Failure, .recovery)
            }
            XCTAssertEqual(try Data(contentsOf: marker(root)), raw)
            XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent(SchoolDataRetention.privatePaths[0]).path))
            try assertPublicAndPreferences(root)
        }
    }
    func testInterruptedRecoveryAndDeletionFailureRetainEvidenceUntilRetryCommits() throws {
        try withRoot { root, retention in
            try seed(root); try Data("fictional-invalid".utf8).write(to: marker(root)); try retention.quarantineInvalidMarker()
            let reopened = SchoolDataRetention(root: root)
            XCTAssertNil(try reopened.installedPeriod())
            XCTAssertThrowsError(try reopened.replace(with: current, remove: { url in
                if url.lastPathComponent == "NameMappings" { throw CocoaError(.fileWriteNoPermission) }
                try self.manager.removeItem(at: url)
            })) { XCTAssertEqual($0 as? SchoolDataRetention.Failure, .cleanup) }
            XCTAssertNil(try reopened.installedPeriod())
            XCTAssertTrue(manager.fileExists(atPath: recovery(root).path))
            XCTAssertThrowsError(try reopened.finishRecovery())
            try reopened.replace(with: current)
            XCTAssertThrowsError(try reopened.finishRecovery(remove: { _ in throw CocoaError(.fileWriteNoPermission) }))
            XCTAssertEqual(try reopened.installedPeriod(), current)
            XCTAssertTrue(manager.fileExists(atPath: recovery(root).path))
            try reopened.finishRecovery(); try assertPublicAndPreferences(root)
        }
    }
    func testMarkerWriteFailureKeepsQuarantineAndNeverCommitsAPeriod() throws {
        try withRoot { root, retention in
            try seed(root); try Data("fictional-invalid".utf8).write(to: marker(root)); try retention.quarantineInvalidMarker()
            XCTAssertThrowsError(try retention.replace(with: current, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })) {
                XCTAssertEqual($0 as? SchoolDataRetention.Failure, .markerWrite)
            }
            XCTAssertNil(try retention.installedPeriod())
            XCTAssertTrue(manager.fileExists(atPath: recovery(root).path))
            try retention.replace(with: current); try retention.finishRecovery()
            XCTAssertEqual(try retention.installedPeriod(), current); try assertPublicAndPreferences(root)
        }
    }
}
