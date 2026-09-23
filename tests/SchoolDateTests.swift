import XCTest
@testable import TakupokeParsing

final class SchoolDateTests: XCTestCase {
    func testStrictCivilDateParsingAcrossLeapAndSchoolYearBoundary() throws {
        XCTAssertEqual(SchoolDate(iso8601: "2032-02-29")?.iso8601, "2032-02-29")
        XCTAssertNil(SchoolDate(iso8601: "2033-02-29"))
        XCTAssertNil(SchoolDate(iso8601: "2033-04-31"))
        XCTAssertNil(SchoolDate(iso8601: "2033-4-01"))
        XCTAssertNil(SchoolDate(iso8601: "2033/04/01"))
        XCTAssertNil(SchoolDate(iso8601: "2033-04-01T00:00:00Z"))
        XCTAssertLessThan(try XCTUnwrap(SchoolDate(iso8601: "2033-12-31")),
                          try XCTUnwrap(SchoolDate(iso8601: "2034-01-01")))
    }

    func testApplicabilityBoundariesAndOverlap() throws {
        let start = try XCTUnwrap(SchoolDate(iso8601: "2033-04-01"))
        let end = try XCTUnwrap(SchoolDate(iso8601: "2033-10-01"))
        let first = try XCTUnwrap(SchoolDateRange(start: start, endExclusive: end))
        XCTAssertTrue(first.contains(start))
        XCTAssertTrue(first.contains(try XCTUnwrap(SchoolDate(iso8601: "2033-09-30"))))
        XCTAssertFalse(first.contains(end))
        XCTAssertNil(SchoolDateRange(start: end, endExclusive: start))
        XCTAssertNil(SchoolDateRange(start: start, endExclusive: start))
        let following = try XCTUnwrap(SchoolDateRange(start: end,
            endExclusive: try XCTUnwrap(SchoolDate(iso8601: "2034-04-01"))))
        XCTAssertFalse(first.overlaps(following))
        let conflicting = try XCTUnwrap(SchoolDateRange(start: try XCTUnwrap(SchoolDate(iso8601: "2033-09-30")),
            endExclusive: following.endExclusive))
        XCTAssertTrue(first.overlaps(conflicting))
    }

    func testMondayAndWeekNavigationAcrossYearBoundary() throws {
        let wednesday = try XCTUnwrap(SchoolDate(iso8601: "2033-12-28"))
        XCTAssertEqual(wednesday.monday.iso8601, "2033-12-26")
        XCTAssertEqual(wednesday.monday.addingDays(7)?.iso8601, "2034-01-02")
        XCTAssertEqual(try XCTUnwrap(SchoolDate(iso8601: "2033-12-31")).schoolWeekday, 6)
        XCTAssertEqual(try XCTUnwrap(SchoolDate(iso8601: "2034-01-01")).schoolWeekday, 7)
    }

    func testDisplayedWeekAdvancesOnWeekend() throws {
        XCTAssertEqual(try XCTUnwrap(SchoolDate(iso8601: "2033-12-30")).displayWeekStart.iso8601, "2033-12-26")
        XCTAssertEqual(try XCTUnwrap(SchoolDate(iso8601: "2033-12-31")).displayWeekStart.iso8601, "2034-01-02")
        XCTAssertEqual(try XCTUnwrap(SchoolDate(iso8601: "2034-01-01")).displayWeekStart.iso8601, "2034-01-02")
    }
}
