import XCTest
@testable import TakupokeParsing

final class SchoolDateTests: XCTestCase {
    func testJapaneseSchoolYearAndAutomaticChangeYear() throws {
        let march = try XCTUnwrap(SchoolDate(year: 2027, month: 3, day: 31))
        let april = try XCTUnwrap(SchoolDate(year: 2027, month: 4, day: 1))
        XCTAssertEqual(march.schoolYear, 2026)
        XCTAssertEqual(april.schoolYear, 2027)
        XCTAssertEqual(ChangeNormalizer.effectiveSchoolYear(configured: nil, today: march), 2026)
        XCTAssertEqual(ChangeNormalizer.effectiveSchoolYear(configured: "", today: april), 2027)
        XCTAssertEqual(ChangeNormalizer.effectiveSchoolYear(configured: "2032", today: march), 2032)
        XCTAssertEqual(try ChangeNormalizer.date("3/31", defaultYear: march.schoolYear), "2027-03-31")
    }
    func testInvalidNonemptyConfiguredYearNeverFallsBackToToday() throws {
        let today = try XCTUnwrap(SchoolDate(iso8601: "2031-03-01"))
        for text in ["203", "1899", "9999", "架空", "+2032", "２０３２"] {
            XCTAssertNil(ChangeNormalizer.effectiveSchoolYear(configured: text, today: today), text)
        }
        for (text, expected) in [("", 2030), ("  ", 2030), ("1900", 1900), ("9998", 9998), (" 2032 ", 2032)] {
            XCTAssertEqual(ChangeNormalizer.effectiveSchoolYear(configured: text, today: today), expected)
        }
    }

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
    func testUnknownConfiguredYearCannotMatchAttemptOrRequestAutomaticReanalysis() {
        let failure = ChangeParseAttempt(date: Date(), sourceDigest: "fictional", defaultYear: 2032,
            failure: ChangeParseError(code: .date), parserVersion: ChangeAnalysis.parserVersion)
        let invalidYears: [Int?] = [nil, 203, 1899, 9999]
        for year in invalidYears {
            XCTAssertFalse(failure.matches(digest: "fictional", defaultYear: year))
            XCTAssertFalse(ChangeParseAttempt.needsAnalysis(digest: "fictional", defaultYear: year, analysis: nil, attempt: nil))
        }
        XCTAssertTrue(failure.matches(digest: "fictional", defaultYear: 2032))
        XCTAssertFalse(failure.matches(digest: "fictional", defaultYear: 2033))
        XCTAssertFalse(ChangeParseAttempt.needsAnalysis(digest: "fictional", defaultYear: 2032, analysis: nil, attempt: failure))
        XCTAssertTrue(ChangeParseAttempt.needsAnalysis(digest: "fictional", defaultYear: 2033, analysis: nil, attempt: failure))
    }

}
