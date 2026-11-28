import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

extension SpecialScheduleTests {
    func testSpecialStoreRecoversOtherPDFWhenOneSavedPayloadIsUnreadable() throws {
        for legacy in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let ownerQueue = DispatchQueue(label: "fictional-special-recovery")
            let store = try SpecialScheduleStore(root: root, ownerQueue: ownerQueue)
            for kind in SpecialScheduleKind.allCases {
                let bytes = Data("%PDF-fictional-\(kind.rawValue)".utf8)
                let staged = store.newStagingURL()
                try bytes.write(to: staged)
                let snapshot = try MaterialFileReader.copy(staged, to: nil, isWorkbook: false, check: {})
                let pages = kind == .exam ? [flexibleExamPage(["2-CN"], days: [1, 2])] : [returnPageWithSplitCell()]
                let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: snapshot.digest, name: "fictional.pdf")
                try store.save(staged: staged, analysis: analysis, originalName: analysis.sourceName,
                               byteCount: snapshot.count, digest: snapshot.digest)
            }
            let savedExam = try XCTUnwrap(store.savedURL(for: .exam))
            let savedReturn = try XCTUnwrap(store.savedURL(for: .examReturn))
            try store.queue.write { db in
                try db.execute(sql: "UPDATE specialSchedule SET payload = ? WHERE kind = 'examReturn'", arguments: [Data([0x7B])])
                if legacy { try db.execute(sql: "DROP TABLE specialSource; DROP TABLE specialAcquisitionAttempt") }
            }
            try store.queue.close()
            let database = root.appendingPathComponent("specials.sqlite")
            let original = try Data(contentsOf: database)
            let recovered = try SpecialScheduleStore.openRecovering(root: root, ownerQueue: ownerQueue)
            XCTAssertTrue(recovered.wasPartiallyRecovered)
            XCTAssertEqual(recovered.records[.exam]?.analysis, store.records[.exam]?.analysis)
            XCTAssertNil(recovered.sources[.examReturn])
            XCTAssertNil(recovered.records[.examReturn])
            XCTAssertEqual(try Data(contentsOf: database), original)
            XCTAssertTrue(FileManager.default.fileExists(atPath: savedExam.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: savedReturn.path))
            let reopened = try SpecialScheduleStore.openRecovering(root: root, ownerQueue: ownerQueue)
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.savedURL(for: .exam))), Data("%PDF-fictional-exam".utf8))
        }
    }

    func testRemovingSelectedExamRollsBackOnFailureAndKeepsReturnAcrossRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let exam = try SpecialScheduleParser.parse([flexibleExamPage(["2-CN"], days: [1, 2])], kind: .exam,
                                                    digest: "fictional-exam", name: "exam.pdf")
        let returned = try SpecialScheduleParser.parse([returnPageWithSplitCell()], kind: .examReturn,
                                                        digest: "fictional-return", name: "return.pdf")
        for analysis in [exam, returned] {
            let bytes = Data("%PDF-fictional-\(analysis.kind.rawValue)".utf8)
            let staged = store.newStagingURL()
            try bytes.write(to: staged)
            try store.save(staged: staged, analysis: analysis, originalName: analysis.sourceName,
                           byteCount: bytes.count, digest: analysis.sourceDigest)
        }
        let savedExam = try XCTUnwrap(store.savedURL(for: .exam))
        let staged = store.newStagingURL(), newer = Data("%PDF-fictional-new".utf8)
        try newer.write(to: staged)
        try store.saveSelection(staged: staged, kind: .exam, originalName: "new.pdf",
                                byteCount: newer.count, digest: "fictional-new")
        let selectedExam = try XCTUnwrap(store.selectedURL(for: .exam))
        let savedReturn = try XCTUnwrap(store.savedURL(for: .examReturn))

        try store.queue.write { db in
            try db.execute(sql: """
                CREATE TRIGGER testAbortRemove BEFORE DELETE ON specialSchedule
                BEGIN SELECT RAISE(ABORT, 'fictional failure'); END
                """)
        }
        XCTAssertThrowsError(try store.removeSelection(.exam))
        let unchanged = try SpecialScheduleStore(root: root)
        XCTAssertEqual(unchanged.selectedURL(for: .exam), selectedExam)
        XCTAssertEqual(unchanged.savedURL(for: .exam), savedExam)
        try store.queue.write { db in try db.execute(sql: "DROP TRIGGER testAbortRemove") }

        try store.removeSelection(.exam)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertNil(reopened.sources[.exam])
        XCTAssertNil(reopened.records[.exam])
        XCTAssertNil(reopened.acquisitionAttempts[.exam])
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedExam.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: selectedExam.path))
        XCTAssertEqual(reopened.savedURL(for: .examReturn), savedReturn)
        XCTAssertEqual(reopened.records[.examReturn]?.analysis, returned)
    }

    func testScopedReturnSubsetCannotReplaceFullReturnAfterRestart() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SpecialScheduleStore(root:root)
        let good=try SpecialScheduleParser.parse([returnPageWithSplitCell()],kind:.examReturn,digest:"fictional-return",name:"fictional.pdf")
        let bytes=Data("%PDF-fictional-return".utf8), staged=store.newStagingURL()
        try bytes.write(to:staged)
        try store.save(staged:staged,analysis:good,originalName:"fictional.pdf",byteCount:bytes.count,digest:good.sourceDigest)
        let date="2026-04-01"
        let partial=SpecialScheduleAnalysis(kind:.examReturn,sourceDigest:good.sourceDigest,sourceName:good.sourceName,
            parsedAt:good.parsedAt,schoolYear:good.schoolYear,coveredDates:[date],coveredClasses:["3_IT"],
            periodTimes:good.periodTimes,lessons:good.lessons.filter { $0.className == "3_IT" && $0.date == date },
            dedicatedTimeDate:date,scopes:[SpecialScheduleScope(page:1,classes:["3_IT"],dates:[date])])
        XCTAssertTrue(partial.validScopes)
        let next=store.newStagingURL();try bytes.write(to:next)
        XCTAssertThrowsError(try store.save(staged:next,analysis:partial,originalName:"fictional.pdf",byteCount:bytes.count,digest:good.sourceDigest))
        XCTAssertEqual(try SpecialScheduleStore(root:root).records[.examReturn]?.analysis,good)
    }

    func testVariableExamScopeSurvivesStoreRestartAndRejectsPhantomScope() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SpecialScheduleStore(root:root)
        let result=try SpecialScheduleParser.parse([
            flexibleExamPage(["2-CN"],days:[1,2]),flexibleExamPage(["3-IT"],days:[3])
        ],kind:.exam,digest:"fictional-scope",name:"fictional.pdf")
        let bytes=Data("%PDF-fictional-scope".utf8), staged=store.newStagingURL()
        try bytes.write(to:staged)
        try store.save(staged:staged,analysis:result,originalName:"fictional.pdf",byteCount:bytes.count,digest:result.sourceDigest)
        let reopened=try SpecialScheduleStore(root:root)
        XCTAssertEqual(reopened.records[.exam]?.analysis,result)
        XCTAssertFalse(try XCTUnwrap(reopened.records[.exam]).analysis.applies(date:"2026-04-03",className:"2_CN"))
        var broken=result; broken.scopes=nil
        let next=store.newStagingURL(); try bytes.write(to:next)
        XCTAssertThrowsError(try store.save(staged:next,analysis:broken,originalName:"fictional.pdf",byteCount:bytes.count,digest:result.sourceDigest))
        XCTAssertEqual(try SpecialScheduleStore(root:root).records[.exam]?.analysis,result)
    }

    func testInterruptedEmptySpecialDatabaseCanFinishInitializationWithoutLosingSources() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.createDirectory(at:root.appendingPathComponent("files"),withIntermediateDirectories:true)
        do {
            let unfinished=try DatabaseQueue(path:root.appendingPathComponent("specials.sqlite").path)
            try unfinished.close()
        }
        let first=try SpecialScheduleStore(root:root)
        XCTAssertTrue(first.records.isEmpty)
        XCTAssertTrue(first.sources.isEmpty)
        let reopened=try SpecialScheduleStore(root:root)
        XCTAssertTrue(reopened.records.isEmpty)
        XCTAssertTrue(reopened.sources.isEmpty)
    }

    func testMissingScheduleTableWithOtherSchemaOrVersionIsNotReinitialized() throws {
        for evidence in ["CREATE TABLE fictionalEvidence (value TEXT)",
                         "PRAGMA user_version = 1", "PRAGMA application_id = 1"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let database = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
            try database.write { try $0.execute(sql: evidence) }
            XCTAssertThrowsError(try SpecialScheduleStore(root: root))
            try database.read { db in
                XCTAssertFalse(try db.tableExists("specialSchedule"))
                XCTAssertFalse(try db.tableExists("specialSource"))
            }
        }
    }

    func testMissingDatabaseOrTablesPreserveRetainedPDFCopies() throws {
        for missing in ["database", "specialSchedule", "specialSource"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let bytes = Data("%PDF-fictional-preserved".utf8)
            let selected: URL
            do {
                let store = try SpecialScheduleStore(root: root)
                let staged = store.newStagingURL(); try bytes.write(to: staged)
                try store.saveSelection(staged: staged, kind: .exam, originalName: "fictional.pdf",
                    byteCount: bytes.count, digest: "fictional")
                selected = try XCTUnwrap(store.selectedURL(for: .exam))
            }
            let database = root.appendingPathComponent("specials.sqlite")
            if missing == "database" { try FileManager.default.removeItem(at: database) }
            else {
                let db = try DatabaseQueue(path: database.path)
                try db.write { try $0.execute(sql: "DROP TABLE \(missing)") }
            }
            XCTAssertThrowsError(try SpecialScheduleStore(root: root))
            XCTAssertEqual(try Data(contentsOf: selected), bytes)
            if missing == "database" { XCTAssertFalse(FileManager.default.fileExists(atPath: database.path)) }
        }
    }

    func testFreshStoreCollectsOrphansOnlyAfterValidMetadataAndUpgradesLegacyRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-fictional-legacy".utf8)
        let selected: URL
        do {
            let store = try SpecialScheduleStore(root: root)
            XCTAssertTrue(store.sources.isEmpty); XCTAssertTrue(store.records.isEmpty)
            let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) }, kind: .exam,
                digest: "fictional", name: "fictional.pdf")
            let staged = store.newStagingURL(); try bytes.write(to: staged)
            try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
            selected = try XCTUnwrap(store.savedURL(for: .exam))
        }
        do {
            let db = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
            try db.write { try $0.execute(sql: "DROP TABLE specialSource") }
        }
        do {
            let legacy = try SpecialScheduleStore(root: root)
            XCTAssertEqual(legacy.selectedURL(for: .exam), selected)
            XCTAssertEqual(try Data(contentsOf: selected), bytes)
        }
        let orphan = root.appendingPathComponent("files").appendingPathComponent(UUID().uuidString + ".pdf")
        let staged = root.appendingPathComponent("staging").appendingPathComponent(UUID().uuidString)
        try bytes.write(to: orphan); try bytes.write(to: staged)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.selectedURL(for: .exam), selected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: selected), bytes)
    }

    func testIncompleteSpecialTimesDoNotReplacePreviousStoreResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let good = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                   kind: .exam, digest: "fictional",
                                                   name: "fictional.pdf")
        let staged = store.newStagingURL()
        let data = Data("%PDF-fictional".utf8)
        try data.write(to: staged)
        try store.save(staged: staged, analysis: good, originalName: "fictional.pdf",
                       byteCount: data.count, digest: "fictional")
        let oldURL = try XCTUnwrap(store.savedURL(for: .exam))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertThrowsError(try SpecialScheduleParser.parse(
            (1...6).map { examPage($0, omitLastTime: $0 == 3) },
            kind: .exam, digest: "different", name: "different.pdf"))
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.records[.exam]?.analysis, good)
        XCTAssertEqual(reopened.savedURL(for: .exam), oldURL)
    }

    func testAcquisitionFailureStatusKeepsGoodAnalysisUntilTheSameSourceIsConfirmed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-entirely-fictional-status".utf8)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
            kind: .exam, digest: "fictional-current", name: "fictional-status.pdf")
        let store = try SpecialScheduleStore(root: root)
        let staged = store.newStagingURL(); try bytes.write(to: staged)
        try store.save(staged: staged, analysis: analysis, originalName: "fictional-status.pdf",
            byteCount: bytes.count, digest: analysis.sourceDigest)
        func status(_ store: SpecialScheduleStore) throws -> String {
            SpecialScheduleAvailability(ready: true, busy: false, failed: false,
                sources: store.sources, records: store.records).analysisStatus(.exam, source: try XCTUnwrap(store.sources[.exam]))
        }
        XCTAssertEqual(try status(store), "解析済み")
        try store.recordAcquisitionFailure(kind: .exam)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(try status(reopened), "更新確認失敗（前回結果あり）")
        XCTAssertEqual(reopened.records[.exam]?.analysis.sourceDigest, analysis.sourceDigest)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.savedURL(for: .exam))), bytes)
        XCTAssertThrowsError(try reopened.recordSuccessfulCheck(.exam, digest: "fictional-other"))
        XCTAssertEqual(try status(reopened), "更新確認失敗（前回結果あり）")
        try reopened.recordSuccessfulCheck(.exam, digest: analysis.sourceDigest)
        XCTAssertEqual(try status(SpecialScheduleStore(root: root)), "解析済み")
        XCTAssertEqual(reopened.records[.exam]?.analysis.sourceDigest, analysis.sourceDigest)
    }

    func testFirstAcquisitionFailuresReopenWithoutInventingASelectedPDF() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try SpecialScheduleStore(root: root.appendingPathComponent("live"))
        let failures: [(MaterialError, AcquisitionProblem)] = [(.tooLarge, .sizeLimit), (.invalidFile, .invalidFormat),
            (.accessExpired, .permission), (.providerReadFailed, .temporary)]
        for (index, failure) in failures.enumerated() {
            let kind = SpecialScheduleKind.allCases[index % 2]
            let identity = try live.pipelineIdentity(kind)
            let copy = try live.pipelineSnapshot(kind).open(at: root.appendingPathComponent("isolated-\(index)"))
            try copy.recordAcquisitionFailure(kind: kind, error: failure.0)
            let source = try XCTUnwrap(FileRefreshDiagnostics.Source(rawValue: kind.rawValue))
            let ticket = FilePipeline.Ticket(source: source, reason: .selection, period: .current(), limits: .init(), now: { 0 })
            try live.acceptPipeline(copy, kind: kind, expected: identity, ticket: ticket)
            let reopened = try SpecialScheduleStore(root: root.appendingPathComponent("live"))
            XCTAssertTrue(reopened.sources.isEmpty)
            XCTAssertTrue(reopened.records.isEmpty)
            XCTAssertEqual(reopened.acquisitionAttempts[kind]?.problem, failure.1)
            let availability = SpecialScheduleAvailability(ready: true, busy: false, failed: false,
                sources: reopened.sources, records: reopened.records, acquisitionAttempts: reopened.acquisitionAttempts)
            let row = FileStatusPresentation.special(availability, kind: kind)
            XCTAssertEqual(row.updateState, .unavailable)
            XCTAssertEqual(row.status.detail, failure.1.message)
        }
        let staged = live.newStagingURL()
        let bytes = Data("%PDF-fictional-file".utf8)
        try bytes.write(to: staged)
        try live.saveSelection(staged: staged, kind: .exam, originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
        let reopened = try SpecialScheduleStore(root: root.appendingPathComponent("live"))
        XCTAssertNil(reopened.acquisitionAttempts[.exam])
        XCTAssertEqual(reopened.acquisitionAttempts[.examReturn]?.problem, .temporary)
    }

    func testCancellingSpecialReanalysisKeepsOnlyTheSameOriginalRecoveryJob() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("fictional-cancelled-special-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        for kind in SpecialScheduleKind.allCases {
            let bytes = Data("%PDF-fictional-\(kind.rawValue)".utf8)
            func select(_ digest: String, payload: Data) throws {
                let staged = store.newStagingURL()
                try payload.write(to: staged)
                try store.saveSelection(staged: staged, kind: kind, originalName: "fictional.pdf", byteCount: payload.count, digest: digest)
            }
            func assertRetryableCancellation(_ source: SpecialScheduleSource) {
                XCTAssertEqual(source.failure?.code, .cancelled)
                XCTAssertNil(source.recoveryJob)
                XCTAssertTrue(PDFParseAttempt.needsAnalysis(digest: source.digest, parserVersion: SpecialScheduleAnalysis.parserVersion,
                    analysisDigest: nil, analysisVersion: nil, attemptDigest: source.digest, failure: source.failure,
                    attemptVersion: source.attemptParserVersion))
            }
            try select("fictional-current", payload: bytes)
            try store.recordFailure(.init(code: .cancelled), kind: kind)
            assertRetryableCancellation(try XCTUnwrap(store.sources[kind]))
            try store.recordFailure(.init(code: .unsupported, stage: .characterMapping), kind: kind)
            let source = try XCTUnwrap(store.sources[kind])
            XCTAssertEqual(source.recoveryJob?.state, .pending)
            XCTAssertEqual(source.recoveryJob?.kind, kind == .exam ? .exam : .return)
            let file = try XCTUnwrap(store.selectedURL(for: kind))
            try store.recordFailure(.init(code: .cancelled), kind: kind)
            let reopened = try SpecialScheduleStore(root: root)
            XCTAssertEqual(reopened.sources[kind]?.failure, source.failure)
            XCTAssertEqual(reopened.sources[kind]?.attemptParserVersion, source.attemptParserVersion)
            XCTAssertEqual(reopened.sources[kind]?.recoveryJob, source.recoveryJob)
            XCTAssertEqual(reopened.selectedURL(for: kind), file)
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            try store.recordFailure(.init(code: .storage), kind: kind)
            XCTAssertEqual(store.sources[kind]?.failure?.code, .storage)
            XCTAssertNil(store.sources[kind]?.recoveryJob)
            try store.recordFailure(.init(code: .unsupported, stage: .characterMapping), kind: kind)
            let replacement = bytes + Data("-replacement".utf8)
            try select("fictional-replacement", payload: replacement)
            try store.recordFailure(.init(code: .cancelled), kind: kind)
            assertRetryableCancellation(try XCTUnwrap(store.sources[kind]))
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.selectedURL(for: kind))), replacement)
        }
    }

    func testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let previous = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "previous",
                                                       name: "fictional-old.pdf")
        let oldStaging = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: oldStaging)
        try store.save(staged: oldStaging, analysis: previous, originalName: "fictional-old.pdf",
                       byteCount: bytes.count, digest: "previous")
        let previousURL = try XCTUnwrap(store.savedURL(for: .exam))

        let selectedStaging = store.newStagingURL()
        try bytes.write(to: selectedStaging)
        try store.saveSelection(staged: selectedStaging, kind: .exam,
                                originalName: "fictional-new.pdf", byteCount: bytes.count,
                                digest: "current", grant: SourceGrant(bookmark: Data("fictional-bookmark".utf8),
                                                                      name: "fictional-new.pdf", isFolder: false))
        let failure = PDFParseError(code: .unsupported, stage: .characterMapping)
        try store.recordFailure(failure, kind: .exam)
        try store.recordAcquisitionFailure(kind: .exam)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName, "fictional-new.pdf")
        XCTAssertEqual(reopened.sources[.exam]?.grant?.bookmark, Data("fictional-bookmark".utf8))
        XCTAssertEqual(reopened.sources[.exam]?.failure?.stage, .characterMapping)
        XCTAssertEqual(reopened.sources[.exam]?.recoveryJob?.state, .pending)
        XCTAssertNotNil(reopened.sources[.exam]?.acquisitionFailure)
        XCTAssertEqual(reopened.records[.exam]?.analysis, previous)
        XCTAssertNotEqual(reopened.selectedURL(for: .exam), previousURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: previousURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(reopened.selectedURL(for: .exam)).path))

        let current = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                      kind: .exam, digest: "current",
                                                      name: "fictional-new.pdf")
        try reopened.saveAnalysis(current)
        let final = try SpecialScheduleStore(root: root)
        XCTAssertEqual(final.records[.exam]?.analysis, current)
        XCTAssertNil(final.sources[.exam]?.failure)
        XCTAssertEqual(final.selectedURL(for: .exam), final.savedURL(for: .exam))
        XCTAssertFalse(FileManager.default.fileExists(atPath: previousURL.path))
    }

    func testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "fictional",
                                                       name: "fictional.pdf")
        let staged = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: staged)
        try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf",
                       byteCount: bytes.count, digest: "fictional")
        let source = try XCTUnwrap(store.sources[.exam])
        let selectedURL = try XCTUnwrap(store.selectedURL(for: .exam))
        let checkedAt = Date(timeIntervalSince1970: 2_000_000_000)
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        legacyJSON.removeValue(forKey: "lastCheckedAt")
        let legacySource = try JSONDecoder().decode(SpecialScheduleSource.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertNil(legacySource.lastCheckedAt)

        XCTAssertThrowsError(try store.recordSuccessfulCheck(.exam, digest: "different", checkedAt: checkedAt))
        XCTAssertEqual(store.sources[.exam]?.lastCheckedAt, source.lastCheckedAt)
        try store.recordSuccessfulCheck(.exam, digest: "fictional", checkedAt: checkedAt)

        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.lastCheckedAt, checkedAt)
        XCTAssertEqual(reopened.sources[.exam]?.acquiredAt, source.acquiredAt)
        XCTAssertEqual(reopened.selectedURL(for: .exam), selectedURL)
        XCTAssertEqual(reopened.records[.exam]?.analysis, analysis)
    }

    func testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = try SpecialScheduleStore(root:root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },kind:.exam,digest:"fictional",name:"fictional.pdf")
        let staged = store.newStagingURL(), bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to:staged)
        try store.save(staged:staged,analysis:analysis,originalName:"fictional.pdf",byteCount:bytes.count,digest:"fictional")
        try store.recordFailure(PDFParseError(code:.ambiguous),kind:.exam)
        let storedName = try XCTUnwrap(store.sources[.exam]?.storedName),job = store.sources[.exam]?.recoveryJob
        try store.recordSuccessfulCheck(.exam,digest:"fictional",originalName:"fictional-renamed.pdf")
        let reopened = try SpecialScheduleStore(root:root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName,"fictional-renamed.pdf")
        XCTAssertEqual(reopened.sources[.exam]?.storedName,storedName)
        XCTAssertEqual(reopened.sources[.exam]?.recoveryJob,job)
        XCTAssertEqual(reopened.sources[.exam]?.failure?.code,.ambiguous)
        XCTAssertEqual(reopened.records[.exam]?.analysis,analysis)
        XCTAssertEqual(reopened.records[.exam]?.originalName,"fictional.pdf")
    }
    func testPreviousVersionAnalysisStillProvidesSelectedSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "fictional",
                                                       name: "fictional.pdf")
        let staged = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: staged)
        try store.save(staged: staged, analysis: analysis,
                       originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
        let db = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
        let current = try XCTUnwrap(store.records[.exam])
        var oldAnalysis = current.analysis
        oldAnalysis.version = 4
        let old = SpecialScheduleRecord(kind: current.kind, originalName: current.originalName,
                                        storedName: current.storedName, byteCount: current.byteCount,
                                        digest: current.digest, acquiredAt: current.acquiredAt,
                                        analysis: oldAnalysis)
        try db.write {
            try $0.execute(sql: "UPDATE specialSchedule SET payload = ? WHERE kind = 'exam'",
                           arguments: [JSONEncoder().encode(old)])
            try $0.execute(sql: "DELETE FROM specialSource")
        }

        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName, "fictional.pdf")
        XCTAssertEqual(reopened.selectedURL(for: .exam), reopened.savedURL(for: .exam))
        XCTAssertEqual(reopened.records[.exam]?.analysis.version, 4)
    }
    func testReturnClockDateAndLegacyRawTimesSurviveSqliteReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-fictional-return".utf8)
        let analysis = try SpecialScheduleParser.parse([returnPageWithSplitCell(dateDays: [2,1,3,4,5])], kind: .examReturn, digest: "fictional", name: "fictional.pdf")
        do {
            let store = try SpecialScheduleStore(root: root)
            let staged = store.newStagingURL(); try bytes.write(to: staged)
            try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
        }
        let reopened = try SpecialScheduleStore(root: root)
        let current = try XCTUnwrap(reopened.records[.examReturn])
        XCTAssertEqual(current.analysis.dedicatedTimeDate, "2026-04-02")
        XCTAssertEqual(current.analysis.periodTime(on: "2026-04-02", period: 5), "10:30〜11:10")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        var saved = try XCTUnwrap(legacy["analysis"] as? [String: Any])
        saved.removeValue(forKey: "dedicatedTimeDate"); saved["version"] = 32
        var oldLessons = try XCTUnwrap(saved["lessons"] as? [[String: Any]])
        oldLessons[0].removeValue(forKey: "timeRange")
        saved["lessons"] = oldLessons
        legacy["analysis"] = saved
        let oldBytes = try JSONSerialization.data(withJSONObject: legacy)
        let queue = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
        try queue.write { try $0.execute(sql: "UPDATE specialSchedule SET payload=? WHERE kind='examReturn'", arguments: [oldBytes]) }
        let old = try SpecialScheduleStore(root: root)
        let retained = try XCTUnwrap(old.records[.examReturn]?.analysis)
        XCTAssertNil(retained.dedicatedTimeDate)
        XCTAssertNil(retained.periodTime(on: "2026-04-01", period: 5))
        XCTAssertNil(retained.periodTime(on: "2026-04-02", period: 5))
        let joined = try XCTUnwrap(retained.lessons.first { $0.date == "2026-04-02" && $0.period == 5 && $0.className == "1_1" })
        XCTAssertEqual(retained.timeRange(for: joined), "10:30〜11:50")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(old.savedURL(for: .examReturn))), bytes)
        XCTAssertEqual(try queue.read { try Data.fetchOne($0, sql: "SELECT payload FROM specialSchedule WHERE kind='examReturn'") }, oldBytes)
    }

}
