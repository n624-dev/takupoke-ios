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

}
