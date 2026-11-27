import XCTest
@testable import TakupokeParsing

final class SchoolDataRetentionTests: XCTestCase {
    func testJapanBoundariesIncludeOctoberAndAprilButNotJanuary() throws {
        let formatter = ISO8601DateFormatter()
        func period(_ instant: String) throws -> SchoolDataPeriod {
            SchoolDataPeriod.current(at: try XCTUnwrap(formatter.date(from: instant)))
        }
        XCTAssertNotEqual(try period("2032-09-30T14:59:59Z"), try period("2032-09-30T15:00:00Z"))
        XCTAssertNotEqual(try period("2033-03-31T14:59:59Z"), try period("2033-03-31T15:00:00Z"))
        XCTAssertEqual(try period("2032-12-31T14:59:59Z"), try period("2032-12-31T15:00:00Z"))
        XCTAssertEqual(try period("2033-01-01T00:00:00Z").schoolYear, 2032)
    }

    func testDeletesOnlyOwnedPrivateDataAndCommitsPeriodAfterCleanup() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let retention = SchoolDataRetention(root: root)
        XCTAssertNil(try retention.installedPeriod())
        for path in SchoolDataRetention.privatePaths + ["SchoolEventsAPI", "unrelated"] {
            let dir = root.appendingPathComponent(path)
            try manager.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("synthetic".utf8).write(to: dir.appendingPathComponent("data"))
        }
        let period = SchoolDataPeriod(day: try XCTUnwrap(SchoolDate(iso8601: "2032-10-01")))
        try retention.replace(with: period)
        XCTAssertEqual(try retention.installedPeriod(), period)
        for path in SchoolDataRetention.privatePaths { XCTAssertFalse(manager.fileExists(atPath: root.appendingPathComponent(path).path)) }
        for path in ["SchoolEventsAPI", "unrelated"] { XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent(path).path)) }
        try retention.replace(with: period)
        XCTAssertEqual(try retention.installedPeriod(), period)
    }
    func testFailureDoesNotCommitNewPeriodAndRetryCompletes() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let retention = SchoolDataRetention(root: root)
        let first = SchoolDataPeriod(day: try XCTUnwrap(SchoolDate(iso8601: "2032-04-01")))
        let second = SchoolDataPeriod(day: try XCTUnwrap(SchoolDate(iso8601: "2032-10-01")))
        try retention.replace(with: first)
        for name in ["SchoolMaterialsSQLite", "NameMappings"] {
            try manager.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        XCTAssertThrowsError(try retention.replace(with: second) { url in
            if url.lastPathComponent == "NameMappings" { throw CocoaError(.fileWriteNoPermission) }
            try manager.removeItem(at: url)
        })
        XCTAssertEqual(try retention.installedPeriod(), first)
        XCTAssertFalse(manager.fileExists(atPath: root.appendingPathComponent("SchoolMaterialsSQLite").path))
        try retention.replace(with: second)
        XCTAssertEqual(try retention.installedPeriod(), second)
    }

    func testAutomaticMarkerRecoveryKeepsCurrentDataOrArchivesUnverifiedDataAndRetries() throws {
        let manager = FileManager.default
        let current = SchoolDataPeriod(day: try XCTUnwrap(SchoolDate(iso8601: "2032-10-01")))
        let malformed = Data("{fictional-broken-marker".utf8)
        let markerName = "school-data-period.json"
        for hasProof in [false, true] {
            let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? manager.removeItem(at: root) }
            let retention = SchoolDataRetention(root: root)
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            if hasProof { try retention.replace(with: current) }
            let marker = root.appendingPathComponent(markerName)
            try malformed.write(to: marker)
            let names = ["SchoolMaterialsSQLite", "SpecialSchedulesSQLite", "SchoolEventsAPI", "unrelated"]
            for name in names { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
            if !hasProof {
                XCTAssertThrowsError(try retention.restoreInvalidPeriod(current) { source, archive in
                    if source.lastPathComponent == "SpecialSchedulesSQLite" { throw CocoaError(.fileWriteNoPermission) }
                    try manager.moveItem(at: source, to: archive)
                })
                XCTAssertEqual(try Data(contentsOf: marker), malformed)
                XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent("SpecialSchedulesSQLite").path))
            }
            XCTAssertEqual(try retention.restoreInvalidPeriod(current), hasProof)
            XCTAssertEqual(try retention.installedPeriod(), current)
            let archiveRoot = root.appendingPathComponent("SchoolDataUnverifiedPeriod")
            let archive = try XCTUnwrap(manager.contentsOfDirectory(at: archiveRoot, includingPropertiesForKeys: nil).first)
            XCTAssertEqual(try Data(contentsOf: archive.appendingPathComponent(markerName)), malformed)
            for name in names {
                let active = root.appendingPathComponent(name)
                let retained = archive.appendingPathComponent(name)
                if hasProof || name == "SchoolEventsAPI" || name == "unrelated" {
                    XCTAssertEqual(try Data(contentsOf: active), Data(name.utf8))
                    XCTAssertFalse(manager.fileExists(atPath: retained.path))
                } else {
                    XCTAssertFalse(manager.fileExists(atPath: active.path))
                    XCTAssertEqual(try Data(contentsOf: retained), Data(name.utf8))
                }
            }
        }
    }

    func testHalfYearDeletionPreservesPreferencesPublicEventsAndExternalOriginal() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let external = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "retention-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            try? manager.removeItem(at: root)
            try? manager.removeItem(at: external)
            defaults.removePersistentDomain(forName: suite)
        }
        let preferences = LinkPreferencesStore(defaults: defaults)
        let value = LinkPreferences(favoriteIDs: ["fictional-link"], hiddenIDs: ["fictional-hidden"],
                                    colorOverrides: ["fictional-link": "teal"])
        try preferences.save(value)
        defaults.set("3_XY", forKey: "timetableSelectedClasses")
        defaults.set(true, forKey: "timetableInternationalStudent")
        try Data("synthetic external original".utf8).write(to: external)
        let publicEvents = root.appendingPathComponent("SchoolEventsAPI")
        try manager.createDirectory(at: publicEvents, withIntermediateDirectories: true)
        let publicFile = publicEvents.appendingPathComponent("synthetic.json")
        try Data("synthetic public events".utf8).write(to: publicFile)
        let retention = SchoolDataRetention(root: root)
        for day in ["2032-04-01", "2032-10-01", "2033-04-01"] {
            for name in SchoolDataRetention.privatePaths {
                let dir = root.appendingPathComponent(name)
                try manager.createDirectory(at: dir, withIntermediateDirectories: true)
                try Data("synthetic private data".utf8).write(to: dir.appendingPathComponent("data"))
            }
            try retention.replace(with: SchoolDataPeriod(day: try XCTUnwrap(SchoolDate(iso8601: day))))
            for name in SchoolDataRetention.privatePaths {
                XCTAssertFalse(manager.fileExists(atPath: root.appendingPathComponent(name).path))
            }
            XCTAssertEqual(try preferences.load(), value)
            XCTAssertEqual(defaults.string(forKey: "timetableSelectedClasses"), "3_XY")
            XCTAssertTrue(defaults.bool(forKey: "timetableInternationalStudent"))
            XCTAssertEqual(try Data(contentsOf: external), Data("synthetic external original".utf8))
            XCTAssertEqual(try Data(contentsOf: publicFile), Data("synthetic public events".utf8))
        }
    }

}
