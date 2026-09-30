import XCTest
@testable import TakupokeParsing

final class ScheduleNotificationTests: XCTestCase {
    private let today = SchoolDate(iso8601: "2032-10-15")!

    private func change(_ fingerprint: String, date: String = "2032-10-15", className: String = "3_XY",
                        period: String = "1") -> ScheduleNotificationSnapshot.Change {
        .init(date: date, className: className, period: period, fingerprint: fingerprint)
    }

    func testFirstImportAndUnchangedContentDoNotNotify() {
        let rows: Set = [change("synthetic-fingerprint-A")]
        let first = ScheduleNotificationSnapshot()
        XCTAssertEqual(first.changeCount(comparedWith: rows, today: today, classes: ["3_XY"]), 0)
        let saved = ScheduleNotificationSnapshot(changes: rows)
        XCTAssertEqual(saved.changeCount(comparedWith: rows, today: today, classes: ["3_XY"]), 0)
        XCTAssertFalse(saved.specialChanged(kind: "exam", digest: "synthetic-digest-A"))
    }

    func testUpdatesOnlyCountSelectedClassesTodayOrLaterAndCountReplacementsOnce() {
        let before: Set = [change("old"), change("past-old", date: "2032-10-14"),
                           change("other-old", className: "4_XY")]
        let after: Set = [change("new"), change("past-new", date: "2032-10-14"),
                          change("other-new", className: "4_XY"),
                          change("future", date: "2032-10-16", period: "2,3")]
        let saved = ScheduleNotificationSnapshot(changes: before)
        XCTAssertEqual(saved.changeCount(comparedWith: after, today: today, classes: ["3_XY"]), 2)
        XCTAssertEqual(saved.changeCount(comparedWith: after, today: today, classes: []), 0)
        // A removal is also an update to the selected class's schedule.
        XCTAssertEqual(saved.changeCount(comparedWith: [], today: today, classes: ["3_XY"]), 1)
    }

    func testSelectionChangeAndReorderingDoNotBecomeDataUpdates() {
        let a = change("a"), b = change("b", className: "4_XY")
        let saved = ScheduleNotificationSnapshot(changes: [a, b])
        XCTAssertEqual(saved.changeCount(comparedWith: [b, a], today: today, classes: ["4_XY"]), 0)
    }

    func testSavedBaselineSurvivesRestartAndSeparatesExamAndReturn() throws {
        let saved = ScheduleNotificationSnapshot(changes: [change("a")],
            specialDigests: ["exam": "synthetic-exam-A", "examReturn": "synthetic-return-A"])
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: data)
        XCTAssertEqual(saved, restored)
        XCTAssertFalse(restored.specialChanged(kind: "exam", digest: "synthetic-exam-A"))
        XCTAssertTrue(restored.specialChanged(kind: "examReturn", digest: "synthetic-return-B"))
        XCTAssertFalse(restored.specialChanged(kind: "unknown", digest: "synthetic-digest-A"))
        XCTAssertEqual(restored.changeCount(comparedWith: [change("a")], today: today, classes: ["3_XY"]), 0)
    }

    func testInvalidDateCannotNotify() {
        let saved = ScheduleNotificationSnapshot(changes: [])
        XCTAssertEqual(saved.changeCount(comparedWith: [change("a", date: "invalid")], today: today, classes: ["3_XY"]), 0)
    }

    func testFailedParseCannotReplaceNotificationBaselineWithPreviousAnalysis() {
        let analysis = ChangeAnalysis(sourceDigest: "synthetic-A", sourceName: "synthetic.xlsx",
                                      defaultYear: 2032, parsedAt: Date(), records: [])
        var state = MaterialLibraryState()
        state.changeAnalysis = analysis
        XCTAssertNil(ScheduleNotificationSnapshot.acceptedChanges(in: state))
        state.records = [MaterialRecord(kind: .changes, source: MaterialSource(), originalName: "synthetic.xlsx",
            storedName: "synthetic.xlsx", byteCount: 10, digest: "synthetic-A", acquiredAt: Date())]
        XCTAssertNotNil(ScheduleNotificationSnapshot.acceptedChanges(in: state))
        state.records[0].digest = "synthetic-B"
        XCTAssertNil(ScheduleNotificationSnapshot.acceptedChanges(in: state))
        state.records[0].digest = "synthetic-A"
        state.changeAnalysis?.version = ChangeAnalysis.parserVersion - 1
        XCTAssertNil(ScheduleNotificationSnapshot.acceptedChanges(in: state))
    }
}
