import Foundation
import XCTest
@testable import TakupokeParsing

final class JapaneseDateDisplayTests: XCTestCase {
    func testTimestampUsesJapaneseDateAcrossMidnightWithForeignDeviceZone() throws {
        let previous = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        defer { NSTimeZone.default = previous }

        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-01T15:30:00Z"))
        let rendered = instant.formatted(JapaneseDateDisplay.timestamp
            .locale(Locale(identifier: "en_GB"))
            .month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        XCTAssertTrue(rendered.contains("02/10/2026"), rendered)
        XCTAssertTrue(rendered.contains("00:30"), rendered)
        XCTAssertEqual(JapaneseDateDisplay.timestamp.timeZone.identifier, "Asia/Tokyo")
    }

    func testTimestampUsesNextSchoolYearDateWithForeignDeviceZone() throws {
        let previous = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "Pacific/Honolulu"))
        defer { NSTimeZone.default = previous }

        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-03-31T15:05:00Z"))
        let rendered = instant.formatted(JapaneseDateDisplay.timestamp
            .locale(Locale(identifier: "en_GB"))
            .month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        XCTAssertTrue(rendered.contains("01/04/2027"), rendered)
        XCTAssertTrue(rendered.contains("00:05"), rendered)
    }
}
