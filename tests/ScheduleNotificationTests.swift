import XCTest
@testable import TakupokeParsing

final class ScheduleNotificationTests: XCTestCase {
    func testRemovingExamResetsOnlyItsComparisonAndFirstReselectionIsQuiet() throws {
        var snapshot = ScheduleNotificationSnapshot()
        snapshot.specialDigests = ["exam": "exam-old", "examReturn": "return-old"]
        snapshot.pending["exam"] = .init(fingerprint: "exam-old", count: 1)
        snapshot.pending["examReturn"] = .init(fingerprint: "return-old", count: 1)
        snapshot.removeSpecialSchedule(.exam)
        let result = try snapshot.reconciling(changes: nil, specials: ["exam": "exam-new", "examReturn": "return-old"],
            availability: .init(changes: .unavailable, specials: ["exam": .available, "examReturn": .available]),
            today: .today(), classes: [], changesEnabled: true, specialsEnabled: true)
        XCTAssertNil(result.pending["exam"])
        XCTAssertEqual(result.specialDigests["exam"], "exam-new")
        XCTAssertEqual(result.pending["examReturn"], snapshot.pending["examReturn"])
        XCTAssertEqual(result.specialDigests["examReturn"], "return-old")
    }

    private let today = SchoolDate(iso8601: "2032-10-15")!

    private func change(_ fingerprint: String, date: String = "2032-10-15", className: String = "3_XY",
                        period: String = "1") -> ScheduleNotificationSnapshot.Change {
        .init(date: date, className: className, period: period, fingerprint: fingerprint)
    }

    func testNoticesUseVisibleChangedRowsAndRecheckBeforeSending() throws {
        typealias Snapshot = ScheduleNotificationSnapshot
        let rules = try JSONDecoder().decode(MappingRules.self, from: JSONSerialization.data(withJSONObject: [
            "subjects": [["alias": "留 架空略号B", "fullName": "架空科目B", "classes": ["3_XY"], "internationalStudent": true]],
            "teachers": [], "rooms": [], "teacherContexts": []]))
        let mapping = SavedMapping(revision: "fictional", version: "v1", schemaVersion: 1,
            archiveETag: "", archiveSHA256: "fictional-rules", publishedAt: "", fetchedAt: Date(), rules: rules)
        let available = Snapshot.Availability(changes: .available, specials: [:])
        func row(_ subject: String, period: String = "1") -> ScheduleChange {
            .init(change_date: today.iso8601, class_name: "3_XY", period: period, before_subject: "",
                  after_subject: subject, teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        }
        func state(_ rows: [ScheduleChange], international: Bool, mapping: SavedMapping?) -> (Set<Snapshot.Change>, Snapshot.ChangeScope) {
            let values = Dictionary(uniqueKeysWithValues: rows.map { (Snapshot.Change.from($0), $0) })
            return (Set(values.keys), .init(visibility: .init(rows: values, mapping: mapping), international: international))
        }
        func reconcile(_ previous: Snapshot, _ rows: [ScheduleChange], international: Bool = false,
                       using mapping: SavedMapping? = nil) throws -> Snapshot {
            let (rows, scope) = state(rows, international: international, mapping: mapping)
            return try previous.reconciling(changes: rows, specials: [:], availability: available, today: today,
                classes: ["3_XY"], changesEnabled: true, specialsEnabled: false, scope: scope)
        }
        let ordinary = row("架空科目A")
        let prefixed = row("留架空科目C")
        let mapped = row("架空科目B", period: "2")
        let unknown = row("架空科目D", period: "未確定")
        let baseline = try reconcile(Snapshot(), [ordinary], using: mapping)
        let hidden = try reconcile(baseline, [ordinary, prefixed, mapped, unknown], using: mapping)
        XCTAssertNil(hidden.pending["changes"])
        XCTAssertEqual(hidden.changes?.count, 4)
        XCTAssertNil(try reconcile(hidden, [ordinary, prefixed, mapped, unknown], international: true, using: mapping).pending["changes"])
        XCTAssertNil(try reconcile(hidden, [ordinary, prefixed, mapped, unknown]).pending["changes"])

        let visible = try reconcile(baseline, [ordinary, prefixed, mapped, unknown], international: true, using: mapping)
        let notice = try XCTUnwrap(visible.pending["changes"])
        XCTAssertEqual(notice.changeTargets?.map(\.period), ["1", "2"])
        let (current, hiddenScope) = state([ordinary, prefixed, mapped, unknown], international: false, mapping: mapping)
        XCTAssertTrue(visible.validTargets(notice.changeTargets ?? [], in: current, today: today,
            classes: ["3_XY"], scope: hiddenScope).isEmpty)
        XCTAssertNil(try reconcile(visible, [ordinary, prefixed, mapped, unknown], using: mapping).pending["changes"])

        let removed = try reconcile(hidden, [prefixed, mapped, unknown], using: mapping)
        XCTAssertEqual(removed.pending["changes"]?.changeTargets?.map(\.period), ["1"])
        let roundTrip = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(removed))
        XCTAssertEqual(roundTrip, removed)
        let replaced = try reconcile(hidden, [row("架空科目E"), prefixed, mapped, unknown], using: mapping)
        XCTAssertEqual(replaced.pending["changes"]?.count, 1)
    }

    func testUpdateNoticeSelectsNearestCurrentDateOrMatchingRememberedDate() throws {
        let next = try XCTUnwrap(today.addingDays(2))
        let later = try XCTUnwrap(today.addingDays(4))
        let past = try XCTUnwrap(today.addingDays(-1))
        let classes: Set<String> = ["2_IT", "1_ES"]
        let digest = ScheduleUpdateNotice.digest("fictional-document")
        let notice = try XCTUnwrap(ScheduleUpdateNotice(identifier: "takupoke.changes", revision: digest,
            documentRevision: digest, classRevision: ScheduleUpdateNotice.selectedClassesRevision(classes),
            days: [later.iso8601, past.iso8601, next.iso8601, next.iso8601, "invalid"]))
        XCTAssertEqual(notice.days, [past, next, later])
        XCTAssertEqual(notice.edition(currentRevision: digest), .same)
        XCTAssertEqual(notice.date(today: today, upcoming: [today, later], edition: .same,
            selectedClasses: classes, allowsRememberedDates: true), next)
        XCTAssertEqual(notice.date(today: today, upcoming: [past, later], edition: .replaced,
            selectedClasses: classes, allowsRememberedDates: true), later)
        XCTAssertNil(notice.date(today: today, upcoming: [past], edition: .same,
            selectedClasses: ["3_IT"], allowsRememberedDates: true))
        XCTAssertNil(notice.date(today: today, upcoming: [past], edition: .same,
            selectedClasses: classes, allowsRememberedDates: false))
        XCTAssertEqual(notice.date(today: today, upcoming: [today, later], edition: .same,
            selectedClasses: classes, allowsRememberedDates: true, international: true), today)
        XCTAssertEqual(notice.date(today: today, upcoming: [today, later], edition: .same,
            selectedClasses: classes, allowsRememberedDates: true, mappingRevision: "different-rules"), today)
        XCTAssertNil(ScheduleUpdateNotice(identifier: "unrelated", revision: digest))
        for (kind, id) in [(ScheduleUpdateNotice.Kind.exam, "takupoke.exam"), (.examReturn, "takupoke.examReturn")] {
            let update = try XCTUnwrap(ScheduleUpdateNotice(identifier: id, revision: digest))
            XCTAssertEqual(update.kind, kind)
            XCTAssertEqual(update.edition(currentRevision: digest), .same)
            XCTAssertEqual(update.date(today: today, upcoming: [later, next], edition: .same,
                selectedClasses: classes, allowsRememberedDates: false), next)
        }
    }

    func testPersonalEditRebasesSameDocumentAndLaterSchoolUpdateNotifies() throws {
        let available = ScheduleNotificationSnapshot.Availability(changes: .available, specials: [:])
        let baseline = ScheduleNotificationSnapshot(changeDocument: "selection/first", changes: [change("original")])
        let personal = try baseline.reconciling(changes: [change("personal")], specials: [:], availability: available,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: false,
            changeDocument: "selection/first", personalEdit: true)
        XCTAssertNil(personal.pending["changes"])
        XCTAssertEqual(personal.changes, [change("personal")])
        let updated = try personal.reconciling(changes: [change("school")], specials: [:], availability: available,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: false,
            changeDocument: "selection/second")
        XCTAssertEqual(updated.pending["changes"]?.count, 1)
    }

    func testLegacyBaselineAdoptsDocumentOnPersonalSaveAndPreservesSchoolNotices() throws {
        let priorSchoolUpdate = change("pending school change", period: "2")
        let target = ScheduleNotificationSnapshot.ChangeTarget(date: priorSchoolUpdate.date,
            className: priorSchoolUpdate.className, period: priorSchoolUpdate.period,
            expectedFingerprints: [priorSchoolUpdate.fingerprint])
        let old = ScheduleNotificationSnapshot(changes: [change("original"), priorSchoolUpdate],
            pending: ["changes": try ScheduleNotificationSnapshot.notice([target])])
        let legacyBytes = try JSONEncoder().encode(old)
        XCTAssertFalse(String(decoding: legacyBytes, as: UTF8.self).contains("changeDocument"))
        let legacy = try JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: legacyBytes)
        let available = ScheduleNotificationSnapshot.Availability(changes: .available, specials: [:])
        let personalRows: Set = [change("my edit"), priorSchoolUpdate]
        let adopted = try legacy.reconciling(changes: personalRows, specials: [:], availability: available,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: false,
            changeDocument: "selected/first", personalEdit: true)
        XCTAssertEqual(adopted.changes, personalRows)
        XCTAssertEqual(adopted.changeDocument, "selected/first")
        XCTAssertEqual(adopted.pending["changes"]?.changeTargets, [target])

        // A school update can also be the first operation after upgrading.
        let schoolRows: Set = [change("school revision"), priorSchoolUpdate]
        let updated = try legacy.reconciling(changes: schoolRows, specials: [:], availability: available,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: false,
            changeDocument: "selected/second")
        XCTAssertEqual(updated.pending["changes"]?.changeTargets?.map(\.period), ["1", "2"])
        // If the known source changed while a person edited it, keep the school diff.
        let changedDocument = try adopted.reconciling(changes: schoolRows, specials: [:], availability: available,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: false,
            changeDocument: "selected/second", personalEdit: true)
        XCTAssertEqual(changedDocument.pending["changes"]?.changeTargets, updated.pending["changes"]?.changeTargets)
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
            specialDigests: ["exam": "synthetic-exam-A", "examReturn": "synthetic-return-A"],
            pending: ["examReturn": .init(fingerprint: "synthetic-return-A", count: 1)])
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: data)
        XCTAssertEqual(saved, restored)
        XCTAssertEqual(restored.pending["examReturn"]?.fingerprint, "synthetic-return-A")
        XCTAssertFalse(restored.specialChanged(kind: "exam", digest: "synthetic-exam-A"))
        XCTAssertTrue(restored.specialChanged(kind: "examReturn", digest: "synthetic-return-B"))
        XCTAssertFalse(restored.specialChanged(kind: "unknown", digest: "synthetic-digest-A"))
        XCTAssertEqual(restored.changeCount(comparedWith: [change("a")], today: today, classes: ["3_XY"]), 0)
    }

    func testMalformedStoredBaselineRecoversWithoutInventingAnUpdate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("baseline.json")
        let malformed = Data("{\"specialDigests\":{\"exam\":\"fictional".utf8)
        try malformed.write(to:file)

        let first = try ScheduleNotificationSnapshot.load(from:file)
        XCTAssertEqual(first,ScheduleNotificationSnapshot())
        let retained = try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)
            .filter { $0.lastPathComponent.hasPrefix("baseline-malformed-") }
        XCTAssertEqual(retained.count,1)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(retained.first)),malformed)
        XCTAssertEqual(try ScheduleNotificationSnapshot.load(from:file),first)

        let availability = ScheduleNotificationSnapshot.Availability(changes:.available,
            specials:["exam":.available,"examReturn":.available])
        let original = try first.reconciling(changes:[change("first-school-revision")],
            specials:["exam":"first-exam","examReturn":"first-return"],availability:availability,
            today:today,classes:["3_XY"],changesEnabled:true,specialsEnabled:true)
        XCTAssertTrue(original.pending.isEmpty)
        try original.save(to:file)
        let reopened = try ScheduleNotificationSnapshot.load(from:file)
        let update = try reopened.reconciling(changes:[change("next-school-revision")],
            specials:["exam":"next-exam","examReturn":"next-return"],availability:availability,
            today:today,classes:["3_XY"],changesEnabled:true,specialsEnabled:true)
        XCTAssertEqual(Set(update.pending.keys),["changes","exam","examReturn"])
        XCTAssertEqual(update.pending["changes"]?.count,1)
    }

    func testStoredBaselinePreservesUnrecognizedFormatAndDoesNotFollowSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("baseline.json")
        XCTAssertEqual(try ScheduleNotificationSnapshot.load(from:file),ScheduleNotificationSnapshot())
        XCTAssertFalse(FileManager.default.fileExists(atPath:file.path))
        let unknown = Data("{\"futureVersion\": 2, \"history\": []}".utf8)
        try unknown.write(to:file)
        XCTAssertThrowsError(try ScheduleNotificationSnapshot.load(from:file))
        XCTAssertEqual(try Data(contentsOf:file),unknown)
        let target = root.appendingPathComponent("valid-snapshot.json")
        let valid = ScheduleNotificationSnapshot(changes:[change("fictional-current")])
        try valid.save(to:target)
        XCTAssertEqual(try ScheduleNotificationSnapshot.load(from:target),valid)
        let link = root.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:target)
        XCTAssertThrowsError(try ScheduleNotificationSnapshot.load(from:link))
        XCTAssertEqual(try ScheduleNotificationSnapshot.load(from:target),valid)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath:link.path),target.path)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:root.path).sorted(),
                       ["baseline.json","link.json","valid-snapshot.json"])
    }

    func testKnownInvalidNotificationBaselineCanBeRebuiltWithoutReplayingCurrentData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("baseline.json")
        let availability = ScheduleNotificationSnapshot.Availability(changes: .available,
            specials: ["exam": .available, "examReturn": .available])
        let current = try ScheduleNotificationSnapshot().reconciling(changes: [change("current")],
            specials: ["exam": "fictional-current-exam", "examReturn": "fictional-current-return"], availability: availability,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: true)
        XCTAssertTrue(current.pending.isEmpty)

        let legacy = Data("{\"specialDigests\":{},\"pending\":{}}".utf8)
        try legacy.write(to: file)
        XCTAssertEqual(try ScheduleNotificationSnapshot.load(from: file), ScheduleNotificationSnapshot())
        XCTAssertThrowsError(try ScheduleNotificationSnapshot.restoreKnownStructure(at: file, with: current))
        XCTAssertEqual(try Data(contentsOf: file), legacy)

        let unsupported = Data("{\"formatVersion\":2,\"specialDigests\":{},\"pending\":{}}".utf8)
        try unsupported.write(to: file)
        XCTAssertThrowsError(try ScheduleNotificationSnapshot.load(from: file)) {
            XCTAssertEqual($0 as? ScheduleNotificationSnapshot.ReadError, .unsupportedFormat)
        }
        XCTAssertThrowsError(try ScheduleNotificationSnapshot.restoreKnownStructure(at: file, with: current))
        XCTAssertEqual(try Data(contentsOf: file), unsupported)

        let corrupt = [Data("{}".utf8), Data("{\"formatVersion\":1,\"pending\":[]}".utf8)]
        for bytes in corrupt {
            try bytes.write(to: file)
            XCTAssertThrowsError(try ScheduleNotificationSnapshot.load(from: file)) {
                XCTAssertEqual($0 as? ScheduleNotificationSnapshot.ReadError, .invalidStructure)
            }
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            try ScheduleNotificationSnapshot.restoreKnownStructure(at: file, with: current)
            let restored = try ScheduleNotificationSnapshot.load(from: file)
            XCTAssertEqual(restored, current)
            XCTAssertTrue(restored.pending.isEmpty)
            let change = try restored.reconciling(changes: [self.change("actual-update")],
                specials: current.specialDigests, availability: availability, today: today, classes: ["3_XY"],
                changesEnabled: true, specialsEnabled: true)
            XCTAssertEqual(Set(change.pending.keys), ["changes"])
        }
        let retained = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("baseline-invalid-") }
        XCTAssertEqual(Set(try retained.map { try Data(contentsOf: $0) }), Set(corrupt))
    }

    func testFailedChangeSendCannotSurviveClassSwitchTargetExpiryOrChangedContent() throws {
        let previous: Set = [change("old")], current: Set = [change("new")]
        var baseline = ScheduleNotificationSnapshot(changes:previous)
        let targets = baseline.changeTargets(comparedWith:current,today:today,classes:["3_XY"])
        baseline.pending["changes"] = .init(fingerprint:"failed",count:1,changeTargets:targets)
        baseline.changes = current
        XCTAssertEqual(baseline.pendingChangeTargets(in:current,today:today,classes:["3_XY"]).count,1)
        XCTAssertTrue(baseline.pendingChangeTargets(in:current,today:today,classes:["4_XY"]).isEmpty)
        XCTAssertTrue(baseline.pendingChangeTargets(in:current,today:SchoolDate(iso8601:"2032-10-16")!,classes:["3_XY"]).isEmpty)
        XCTAssertTrue(baseline.validTargets(targets,in:[change("superseded")],today:today,classes:["3_XY"]).isEmpty)
        let restored = try JSONDecoder().decode(ScheduleNotificationSnapshot.self,from:JSONEncoder().encode(baseline))
        XCTAssertEqual(restored.pending["changes"]?.changeTargets,targets)
        baseline.pending["changes"] = .init(fingerprint:"legacy",count:1)
        XCTAssertTrue(baseline.pendingChangeTargets(in:current,today:today,classes:["3_XY"]).isEmpty)
    }

    func testIndexedChangesRetainAllContentsAndMergeOnlyEligiblePendingSlots() throws {
        let inside = change("unchanged-content"), removed = change("removed",period:"2")
        let pending = change("retry-content",period:"3")
        let past = change("past",date:"2032-10-14"), other = change("other",className:"4_XY")
        let before: Set = [change("old-content"),inside,removed,pending,past,other]
        let next: Set = [change("changed-content"),inside,pending,
                         change("new-past",date:past.date),change("new-other",className:other.className)]
        func target(_ row: ScheduleNotificationSnapshot.Change, _ fingerprints: [String]) -> ScheduleNotificationSnapshot.ChangeTarget {
            .init(date:row.date,className:row.className,period:row.period,expectedFingerprints:fingerprints)
        }
        let changed = target(inside,["changed-content","unchanged-content"])
        let cancellation = target(removed,[])
        let stillPending = target(pending,["retry-content"])
        let prior = [target(past,["past"]),stillPending,target(inside,["old-content","unchanged-content"]),target(other,["other"])]
        let baseline = ScheduleNotificationSnapshot(changes:before,pending:["changes":try ScheduleNotificationSnapshot.notice(prior)])

        XCTAssertEqual(baseline.changeTargets(comparedWith:next,today:today,classes:["3_XY"]),[changed,cancellation])
        XCTAssertEqual(baseline.validTargets(prior,in:next,today:today,classes:["3_XY"]),[stillPending])
        XCTAssertEqual(baseline.pendingChangeTargets(in:next,today:today,classes:["3_XY"]),[changed,cancellation,stillPending])
        XCTAssertEqual(baseline.pendingChangeTargets(in:next,today:today,classes:[]),[])
    }

    func testFailedRemovalNoticeRemainsRelevantOnlyWhileSlotIsAbsent() {
        var baseline = ScheduleNotificationSnapshot(changes:[change("removed")])
        let targets = baseline.changeTargets(comparedWith:[],today:today,classes:["3_XY"])
        baseline.pending["changes"] = .init(fingerprint:"removed",count:1,changeTargets:targets)
        baseline.changes = []
        XCTAssertEqual(baseline.pendingChangeTargets(in:[],today:today,classes:["3_XY"]).count,1)
        XCTAssertTrue(baseline.validTargets(targets,in:[change("restored")],today:today,classes:["3_XY"]).isEmpty)
    }

    func testPersistedPendingSurvivesPartialStartupAndOnlyConfirmedAbsenceClearsIt() throws {
        let old: Set = [change("old")], current: Set = [change("new")]
        let loaded = ScheduleNotificationSnapshot(changes: old, specialDigests: ["exam": "old-exam", "examReturn": "old-return"])
        let ready = ScheduleNotificationSnapshot.Availability(changes: .available, specials: ["exam": .available, "examReturn": .available])
        let pending = try loaded.reconciling(changes: current, specials: ["exam": "new-exam", "examReturn": "new-return"], availability: ready,
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: true)
        XCTAssertEqual(pending.pending.count, 3)
        let reopened = try JSONDecoder().decode(ScheduleNotificationSnapshot.self, from: JSONEncoder().encode(pending))
        for kind in ["changes", "exam", "examReturn"] {
            var partial = ScheduleNotificationSnapshot.Availability(changes: .unavailable, specials: [:])
            if kind == "changes" { partial.changes = .available } else { partial.specials[kind] = .available }
            let reconciled = try reopened.reconciling(changes: current, specials: ["exam": "new-exam", "examReturn": "new-return"], availability: partial,
                today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: true)
            XCTAssertEqual(reconciled, reopened)
        }
        let removed = try reopened.reconciling(changes: nil, specials: [:], availability: .init(changes: .absent, specials: ["exam": .absent]),
            today: today, classes: ["3_XY"], changesEnabled: true, specialsEnabled: true)
        XCTAssertNil(removed.changes); XCTAssertNil(removed.pending["changes"]); XCTAssertNil(removed.pending["exam"])
        XCTAssertNotNil(removed.pending["examReturn"])
        let disabled = try reopened.reconciling(changes: nil, specials: [:], availability: .init(changes: .unavailable, specials: [:]),
            today: today, classes: [], changesEnabled: false, specialsEnabled: false)
        XCTAssertTrue(disabled.pending.isEmpty)
        let filtered = try reopened.reconciling(changes: current, specials: [:], availability: ready,
            today: today, classes: ["4_XY"], changesEnabled: true, specialsEnabled: true)
        XCTAssertNil(filtered.pending["changes"])
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
