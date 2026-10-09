import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension SpecialScheduleTests {
    func testDenseRecoverySourceGroupsUseOneIndexAndRemainCancellable() async throws {
        let bands = [0..<3, 3..<6, 6..<9, 9..<12, 12..<17]
        let pages = bands.map { rows -> PDFPageLayout in
            var page = returnPageWithSplitCell()
            page.glyphs.removeAll { glyph in
                guard glyph.cy >= 120 && glyph.cy < 545 else { return false }
                return glyph.x >= 140 || !rows.contains(Int((glyph.cy - 120) / 25))
            }
            page.lines.removeAll { $0.y1 >= 110 && $0.y1 <= 545 }
            for column in 0...40 {
                page.lines.append(
                    PDFRule(x1: 140 + Double(column) * 40, y1: 120, x2: 140 + Double(column) * 40, y2: 545))
            }
            page.lines.append(PDFRule(x1: 110, y1: 120, x2: 110, y2: 545))
            for row in 0...17 {
                page.lines.append(
                    PDFRule(x1: 0, y1: 120 + Double(row) * 25, x2: 1740, y2: 120 + Double(row) * 25))
            }
            for i in page.glyphs.indices {
                page.glyphs[i].x *= 3
                page.glyphs[i].width *= 3
            }
            for i in page.lines.indices {
                page.lines[i].x1 *= 3
                page.lines[i].x2 *= 3
            }
            page.width *= 3
            for row in rows {
                for column in 0..<40 {
                    for (role, line) in ["架S", "架T", "架R"].enumerated() {
                        for group in 0..<24 {
                            for (letter, char) in line.enumerated() {
                                page.glyphs.append(
                                    PDFGlyph(
                                        text: String(char),
                                        x: 423 + Double(column) * 120 + Double(group) * 3.5 + Double(letter)
                                            * 0.2, y: 123 + Double(row) * 25 + Double(role) * 6, width: 0.2,
                                        height: 2))
                            }
                        }
                    }
                }
            }
            return page
        }
        let doc = try RecoveryDocumentBuilder.build(
            pages, kind: .return, hash: String(repeating: "e", count: 64))
        XCTAssertEqual(doc.cells.count, 680)
        // Actual iOS Builder reachability: one original span per fixed field.
        XCTAssertEqual(doc.sources.count, 2388)
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation, run.errors.joined(separator: ","))
        let result = try XCTUnwrap(run.result)
        XCTAssertEqual(result.cells.count, 680)
        XCTAssertEqual(result.cells[0].lessons[0].subject.value, String(repeating: "架S", count: 24))
        // Independent schema-contract fixture, distinct from the shipping
        // Builder's coarser field spans. Text, order, and atom geometry remain
        // those of the entirely fictional original layout above.
        var atoms = doc
        var atomResult = result
        var split = [String: [String]]()
        var expanded = [RecoverySource]()
        for source in doc.sources {
            if source.cellId.hasPrefix("cell-"), source.text.count == 48 {
                var ids = [String]()
                for group in 0..<24 {
                    var atom = source
                    atom.id += "-atom-\(group)"
                    atom.text = String(source.text.prefix(2))
                    atom.box.x += Double(group) * 3.5
                    atom.box.width = 0.4
                    ids.append(atom.id)
                    expanded.append(atom)
                }
                split[source.id] = ids
            } else {
                expanded.append(source)
            }
        }
        func expand(_ ids: [String]) -> [String] { ids.flatMap { split[$0] ?? [$0] } }
        atoms.sources = expanded
        for i in atoms.cells.indices {
            atoms.cells[i].sourceIds = expand(atoms.cells[i].sourceIds)
            for j in atoms.cells[i].lessonBindings.indices {
                atoms.cells[i].lessonBindings[j].subject = expand(atoms.cells[i].lessonBindings[j].subject)
                atoms.cells[i].lessonBindings[j].teacher = expand(atoms.cells[i].lessonBindings[j].teacher)
                atoms.cells[i].lessonBindings[j].room = expand(atoms.cells[i].lessonBindings[j].room)
            }
        }
        for i in atomResult.cells.indices {
            for j in atomResult.cells[i].lessons.indices {
                atomResult.cells[i].lessons[j].subject.evidence = expand(
                    atomResult.cells[i].lessons[j].subject.evidence)
                atomResult.cells[i].lessons[j].teacher.evidence = expand(
                    atomResult.cells[i].lessons[j].teacher.evidence)
                atomResult.cells[i].lessons[j].room.evidence = expand(
                    atomResult.cells[i].lessons[j].room.evidence)
            }
        }
        XCTAssertEqual(atoms.sources.count, 49308)
        let contractStart = Date()
        XCTAssertEqual(RecoveryValidator.validate(atoms, atomResult).errors, [])
        print(
            "RECOVERY PERFORMANCE: actualBuilderCells=\(doc.cells.count) actualBuilderSources=\(doc.sources.count) independentContractSources=\(atoms.sources.count) contractValidationSeconds=\(Date().timeIntervalSince(contractStart))"
        )
        let atomRun = try await RecoveryEngine.run(
            atoms, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(atomRun.state, .awaitingConfirmation, atomRun.errors.joined(separator: ","))
        XCTAssertEqual(atomRun.result, atomResult)
        var innerChecks = -1_000_000
        let indexedWork = RecoveryValidationWork(check: {
            if innerChecks >= 0 {
                innerChecks += 1
                if innerChecks == 30 { throw PDFParseError(code: .cancelled) }
            }
        })
        let indexed = try RecoverySourceIndex(atoms.sources, work: indexedWork)
        innerChecks = 0
        XCTAssertThrowsError(
            try RecoveryValidator.validate(atoms, atomResult, index: indexed, work: indexedWork)
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(innerChecks, 30)

        var checks = 0
        XCTAssertThrowsError(
            try RecoveryValidator.validate(
                doc, result,
                check: {
                    checks += 1
                    if checks == 50 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 50)
        var checksDuringEngine = 0
        do {
            _ = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil },
                check: {
                    checksDuringEngine += 1
                    if checksDuringEngine == 50 { throw PDFParseError(code: .cancelled) }
                })
            XCTFail("Cancelled recovery continued")
        } catch let error as PDFParseError { XCTAssertEqual(error.code, .cancelled) }
        XCTAssertEqual(checksDuringEngine, 50)
    }

    func testRecoverySpecialTitleYearEvidenceCannotIgnoreASecondYear() async throws {
        for kind: RecoveryDocumentKind in [.exam, .return] {
            let originals = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            func pages(_ years: String) -> [PDFPageLayout] {
                var result = originals
                result[0].glyphs.removeAll { $0.y == 20 }
                let title = years + (kind == .exam ? "試験時間割" : "試験返却時間割")
                result[0].glyphs += title.enumerated().map {
                    PDFGlyph(
                        text: String($0.element), x: 20 + Double($0.offset) * 4, y: 20, width: 4, height: 4)
                }
                return result
            }
            for years in ["令和8年度令和8年度", "2026年度令和8年度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度"] {
                let doc = try RecoveryDocumentBuilder.build(
                    pages(years), kind: kind, hash: String(repeating: "c", count: 64))
                XCTAssertEqual(doc.schoolYear, 2026)
                XCTAssertEqual(doc.yearEvidence.count, kind == .exam ? 7 : 2)
                let run = try await RecoveryEngine.run(
                    doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil },
                    check: {})
                XCTAssertEqual(run.state, .awaitingConfirmation)
            }
            for years in [
                "令和7年度令和8年度", "令和8年度令和7年度",
                "令和8年度令和100年度", "令和8年度12026年度",
                "令和8年度令和0年度", "令和8年度99999999999999999999年度", "令和8年度令 和 1 0 0 年 度", "令和8年度令和Ⅸ年度", "令和8年度令和9年度",
                "令和8年度㋿9年度", "令和8年度𝟚𝟘𝟚𝟟年度", "令和8年度令和九年度", "令和8年度令和年度",
            ] {
                do {
                    let doc = try RecoveryDocumentBuilder.build(
                        pages(years), kind: kind, hash: String(repeating: "c", count: 64))
                    let run = try await RecoveryEngine.run(
                        doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil },
                        check: {})
                    XCTFail("Invalid annual marker reached \(run.state.rawValue): \(run.errors)")
                } catch let error as PDFParseError { XCTAssertEqual(error.stage, .yearHeading) }

            }
            let spaced = try RecoveryDocumentBuilder.build(
                pages("令 和 8 年 度2 0 2 6 年 度"), kind: kind, hash: String(repeating: "c", count: 64))
            XCTAssertEqual(spaced.schoolYear, 2026)
            XCTAssertEqual(spaced.yearEvidence.count, kind == .exam ? 7 : 2)
            let run = try await RecoveryEngine.run(
                spaced, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {}
            )
            XCTAssertEqual(run.state, .awaitingConfirmation)
        }
    }
    func testSpecialTitleYearMustBeUniqueAndEquivalentYearMarkersRemainValid() throws {
        for kind: SpecialScheduleKind in [.exam, .examReturn] {
            let originals = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            func pages(_ years: String) -> [PDFPageLayout] {
                var result = originals
                result[0].glyphs.removeAll { $0.y == 20 }
                let title = years + (kind == .exam ? "試験時間割" : "試験返却時間割")
                result[0].glyphs += title.enumerated().map {
                    PDFGlyph(
                        text: String($0.element), x: 20 + Double($0.offset) * 4, y: 20, width: 4, height: 8)
                }
                return result
            }
            for years in ["令和8年度令和8年度", "2026年度令和8年度", "令 和 8 年 度2 0 2 6 年 度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度"] {
                XCTAssertEqual(
                    try SpecialScheduleParser.parse(
                        pages(years), kind: kind, digest: "fictional", name: "fictional.pdf"
                    ).schoolYear, 2026)
            }
            for years in [
                "令和7年度令和8年度", "令和8年度令和7年度",
                "令和8年度令和100年度", "令和8年度12026年度",
                "令和8年度令和0年度", "令和8年度99999999999999999999年度", "令和8年度令 和 1 0 0 年 度", "令和8年度令和Ⅸ年度", "令和8年度令和9年度",
                "令和8年度㋿9年度", "令和8年度𝟚𝟘𝟚𝟟年度", "令和8年度令和九年度", "令和8年度令和年度",
            ] {
                XCTAssertThrowsError(
                    try SpecialScheduleParser.parse(
                        pages(years), kind: kind, digest: "fictional", name: "fictional.pdf")
                ) {
                    XCTAssertEqual(($0 as? PDFParseError)?.stage, .yearHeading)
                }
            }
        }
    }
    func testExamLayoutRecoveryReusesAllRepeatedClockCharts() async throws {
        let pages = (1...6).map { examPage($0, mergedFirstTwo: $0 == 1) }
        let doc = try RecoveryDocumentBuilder.build(
            pages, kind: .exam, hash: String(repeating: "c", count: 64))
        XCTAssertEqual(doc.classes.count, 17)
        XCTAssertEqual(doc.days.count, 5)
        XCTAssertEqual(doc.clockReplicas["2026-04-01:1"]?.count, 5)
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
    }
    func testExamDerivedSpanOnLaterPageUsesVerifiedPrimaryEndpointChart() async throws {
        var pages = (1...6).map { examPage($0, mergedFirstTwo: $0 == 2) }
        for i in pages.indices { pages[i].glyphs.removeAll { $0.x >= 300 && $0.y == 470 } }
        let doc = try RecoveryDocumentBuilder.build(
            pages, kind: .exam, hash: String(repeating: "c", count: 64))
        XCTAssertEqual(doc.spanTimes["2026-04-01:1-2"], "08:50〜10:35")
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
    }
    func testReturnDerivedSpanOnLaterPageUsesApplicableNormalNote() async throws {
        var pages = [returnPageWithSplitCell(), returnPageWithSplitCell()]
        for i in pages.indices {
            pages[i].glyphs.removeAll { glyph in
                guard glyph.cy >= 120 && glyph.cy < 545 else { return false }
                let row = Int((glyph.cy - 120) / 25)
                return i == 0 ? row >= 9 : row < 9
            }
        }
        pages[1].lines.removeAll { $0.vertical && $0.x1 == 660 }
        pages[1].lines += [
            PDFRule(x1: 660, y1: 110, x2: 660, y2: 345), PDFRule(x1: 660, y1: 370, x2: 660, y2: 545),
        ]
        let doc = try RecoveryDocumentBuilder.build(
            pages, kind: .return, hash: String(repeating: "d", count: 64))
        XCTAssertEqual(doc.spanTimes["2026-04-02:5-6"], "12:50〜14:20")
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
    }
    func testReturnLayoutRecoveryRequiresNormalTimeNoteAndSpanEndpoints() async throws {
        let doc = try RecoveryDocumentBuilder.build(
            [returnPageWithSplitCell()], kind: .return, hash: String(repeating: "d", count: 64))
        XCTAssertEqual(doc.classes.count, 17)
        XCTAssertEqual(doc.spanTimes["2026-04-02:5-6"], "12:50〜14:20")
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
        var changed = doc
        changed.spanTimes["2026-04-02:5-6"] = "12:50〜15:15"
        XCTAssertTrue(
            RecoveryValidator.validate(changed, try XCTUnwrap(run.result)).errors.contains(
                "normalSpanTimeCondition"))
    }
}
