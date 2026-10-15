import Foundation
import XCTest
@testable import TakupokeParsing

// Source-only controls derived from existing public, independently fictional
// primitive layouts. New BODY spelling and an affine layout are deliberately
// distinct; these are not native Reader/OCR output or fresh heldout material.
private func functionalLayout(_ page: PDFPageLayout) -> PDFPageLayout {
    let replacements: [Character:Character] = ["架":"仮", "空":"想", "科":"研", "目":"題", "教":"試", "員":"師", "室":"域"]
    var out = page
    out.glyphs = page.glyphs.map { g in
        var next = g
        if g.cy > 100 && g.cy < 550 && g.x >= 100 {
            next.text = String(g.text.map { replacements[$0] ?? $0 })
        }
        next.x = 15 + g.x * 1.3; next.y = 22 + g.y * 1.3
        next.width *= 1.3; next.height *= 1.3
        return next
    }
    out.lines = page.lines.map { PDFRule(x1:15+$0.x1*1.3,y1:22+$0.y1*1.3,x2:15+$0.x2*1.3,y2:22+$0.y2*1.3) }
    out.width = 15 + page.width * 1.3; out.height = 22 + page.height * 1.3
    return out
}

private func functionalPreview(_ document: RecoveryDocument, _ result: RecoveryResult) throws -> RecoveryPreview {
    let period: SchoolDataPeriod
    if document.kind == .timetable { period = SchoolDataPeriod(day:try XCTUnwrap(SchoolDate(year:document.schoolYear,month:document.term == "前期" ? 4:10,day:1))) }
    else { period = SchoolDataPeriod(day:try XCTUnwrap(SchoolDate(iso8601:try XCTUnwrap(document.days.sorted().first)))) }
    let source = RecoverySelectedSource(kind:document.kind,url:URL(fileURLWithPath:"/fictional-only-unused.pdf"),digest:document.pdfHash,originalName:"independent-functional",storedName:"",period:period)
    return RecoveryPreview(document:document,result:result,source:source)
}

extension PDFParsingTests {
    func testFunctionalUnlabeledTeacherAndRoomBlanksReachFormalConversionWithoutShifting() async throws {
        for missingY in [130.0,148.0] {
            var page = recoveryTimetablePage()
            page.glyphs.removeAll { $0.cy == missingY && $0.cx >= 100 && $0.cx < 140 }
            page = functionalLayout(page)
            let doc = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"a",count:64))
            let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
            let result = try XCTUnwrap(run.result)
            XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
            let formal = try RecoveryConversion.timetable(functionalPreview(doc,result))
            let first = try XCTUnwrap(formal.lessons.first { $0.className == "1_CN" && $0.weekday == 1 && $0.period == 1 })
            XCTAssertEqual(first.names.subject,"仮想研題Q")
            XCTAssertEqual(first.names.teacher,missingY == 130 ? "":"仮想試師Q")
            XCTAssertEqual(first.names.room,missingY == 148 ? "":"仮想域Q")
            XCTAssertEqual(doc.requiredSlots.count,120)
            XCTAssertTrue(doc.sources.allSatisfy { !$0.fromOcr })
        }
    }

    func testFunctionalMergedUnlabeledParallelTuplesRetainSeparatorAndEveryFormalSlot() async throws {
        var page = recoveryTimetablePage()
        page.lines.removeAll { $0.vertical && $0.x1 == 140 && $0.y1 == 100 }
        page.lines += [v(140,100,160),v(140,220,280)]
        let doc = try RecoveryDocumentBuilder.build([functionalLayout(page)],kind:.timetable,hash:String(repeating:"b",count:64))
        let cell = try XCTUnwrap(doc.cells.first { $0.parallelCount == 2 })
        XCTAssertEqual(cell.slots.map(\.period),[1,2]); XCTAssertEqual(cell.parallelSeparators.count,3)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
        let result = try XCTUnwrap(run.result)
        XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        let formal = try RecoveryConversion.timetable(functionalPreview(doc,result))
        for period in [1,2] {
            let tuples = formal.lessons.filter { $0.className == "2_CN" && $0.weekday == 1 && $0.period == period }.map(\.names)
            XCTAssertEqual(tuples,[TimetableLessonNames(subject:"仮想X",teacher:"試師X",room:""),TimetableLessonNames(subject:"仮想Y",teacher:"試師Y",room:"仮想域Y")])
        }
        var changed = doc; changed.cells[changed.cells.firstIndex { $0.id == cell.id }!].parallelSeparators = [:]
        XCTAssertFalse(RecoveryValidator.validate(changed,result).canAdopt)
        XCTAssertThrowsError(try RecoveryConversion.timetable(functionalPreview(changed,result)))
    }
}

extension SpecialScheduleTests {
    func testFunctionalExamMergedClockAndBlankRolesReachFormalConversion() async throws {
        let pages = (1...6).map { functionalLayout(examPage($0,mergedFirstTwo:$0 == 1)) }
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.exam,hash:String(repeating:"c",count:64))
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let result = try XCTUnwrap(run.result)
        XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        let formal = try RecoveryConversion.special(functionalPreview(doc,result))
        XCTAssertEqual(doc.requiredSlots.count,510)
        let merged = formal.lessons.filter { $0.className == "1_1" && $0.date == "2026-04-01" }
        XCTAssertEqual(merged.map(\.period),[1,2])
        XCTAssertTrue(merged.allSatisfy { $0.spanStart == 1 && $0.spanEnd == 2 && $0.timeRange == "08:50〜10:20" && $0.lines == ["仮想研題A","仮想試師A","仮想試域A"] })
        let blank = try XCTUnwrap(formal.lessons.first { $0.className == "1_2" && $0.date == "2026-04-01" })
        XCTAssertEqual(blank.lines,["仮想研題A","",""])
    }

    func testFunctionalReturnSplitParallelBlankRoomAndMergedNormalClockReachFormalConversion() async throws {
        let doc = try RecoveryDocumentBuilder.build([functionalLayout(returnPageWithSplitCell())],kind:.return,hash:String(repeating:"d",count:64))
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let result = try XCTUnwrap(run.result); XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        let formal = try RecoveryConversion.special(functionalPreview(doc,result))
        XCTAssertEqual(doc.requiredSlots.count,680)
        let parallel = formal.lessons.filter { $0.className == "3_IT" && $0.date == "2026-04-01" && $0.period == 3 }
        XCTAssertEqual(parallel.map(\.lines),[["仮想研題A","仮想試師A",""],["仮想研題B","仮想試師B",""]])
        let merged = formal.lessons.filter { $0.className == "1_1" && $0.date == "2026-04-02" && [5,6].contains($0.period) }
        XCTAssertEqual(merged.map(\.period),[5,6]); XCTAssertTrue(merged.allSatisfy { $0.spanStart == 5 && $0.spanEnd == 6 && $0.timeRange == "12:50〜14:20" && $0.lines == ["仮想研題E","",""] })
        var wrongClock = doc; wrongClock.normalTimeNoteEvidence = []
        XCTAssertFalse(RecoveryValidator.validate(wrongClock,result).canAdopt)
        XCTAssertThrowsError(try RecoveryConversion.special(functionalPreview(wrongClock,result)))
    }

    func testFunctionalSpecialHeaderEvidenceCannotBeRemovedOrBorrowedForConversion() async throws {
        for kind:RecoveryDocumentKind in [.exam,.return] {
            let pages = kind == .exam ? (1...6).map { functionalLayout(examPage($0)) }:[functionalLayout(returnPageWithSplitCell())]
            let doc = try RecoveryDocumentBuilder.build(pages,kind:kind,hash:String(repeating:"e",count:64))
            let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
            let result = try XCTUnwrap(run.result)
            let target = try XCTUnwrap(doc.cells.first { !$0.confirmedEmpty })
            for header in ["class","day","period"] { for foreign in [false,true] {
                var bad = doc; let index = try XCTUnwrap(bad.cells.firstIndex { $0.id == target.id })
                switch header {
                case "class": bad.cells[index].classHeaderIds = foreign ? doc.classEvidence.first { $0.key != target.slots[0].className }!.value : []
                case "day": bad.cells[index].dayHeaderIds = foreign ? doc.dayEvidence.first { $0.key != target.slots[0].day }!.value : []
                default: bad.cells[index].periodHeaderIds = foreign ? doc.periodEvidence.first { $0.key != String(target.slots[0].period) }!.value : []
                }
                XCTAssertFalse(RecoveryValidator.validate(bad,result).canAdopt,"\(kind) \(header)")
                XCTAssertThrowsError(try RecoveryConversion.special(functionalPreview(bad,result)))
            } }
        }
    }

    func testFunctionalReturnClassRowMustHaveCompletePhysicalBoundarySupport() throws {
        let original = functionalLayout(returnPageWithSplitCell())
        // A short spurious rule crosses the probe point but cannot bound the
        // whole class column. Its height is not used to manufacture a row.
        var ambiguous = original
        ambiguous.lines.append(PDFRule(x1:180,y1:190,x2:190,y2:190))
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([ambiguous],kind:.return,hash:String(repeating:"f",count:64))) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.gridCell)
        }
        var open = original
        open.lines.removeAll { $0.vertical && $0.x1 == 158 }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([open],kind:.return,hash:String(repeating:"f",count:64)))
    }
    func testFunctionalReturnClassRowIncludesBoundaryAtPeriodHeaderBottom() throws {
        var page = returnPageWithSplitCell()
        // The header reference ends exactly at the first real row boundary.
        // Select that first row rather than stepping down into the second one.
        for index in page.glyphs.indices where page.glyphs[index].cy == 102 && page.glyphs[index].x >= 140 {
            page.glyphs[index].y += 16
        }
        let doc = try RecoveryDocumentBuilder.build([page],kind:.return,hash:String(repeating:"f",count:64))
        XCTAssertEqual(doc.requiredSlots.count,680)
        XCTAssertEqual(doc.classes.count,17)
        let first = try XCTUnwrap(doc.cells.first { $0.slots.contains(RecoverySlot(className:"1_1",day:"2026-04-01",period:1)) })
        XCTAssertEqual(first.box.y,120)
    }
}

extension SpecialScheduleTests {
    func testSpecialMarkedRawSubjectMovesAcrossStrictAndValidatedRecoveryProjections() async throws {
        for kind: SpecialScheduleKind in [.exam,.examReturn] {
            var pages = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            let y = kind == .exam ? 126.0 : 130.0
            let x = kind == .exam ? 106.0 : 302.0
            let index = try XCTUnwrap(pages[0].glyphs.firstIndex { $0.x == x && $0.y == y })
            pages[0].glyphs[index].text += "（CN）"
            let strict = try SpecialScheduleParser.parse(pages,kind:kind,digest:"fictional",name:"fictional.pdf")
            XCTAssertTrue(strict.lessons.contains { $0.className == "1_CN" && $0.sourceClassName == "1_1" })
            XCTAssertFalse(strict.lessons.contains { $0.className == "1_1" && $0.subject.contains("CN") })
            let doc = try RecoveryDocumentBuilder.build(pages.map(functionalLayout),kind:kind == .exam ? .exam:.return,hash:String(repeating:"e",count:64))
            let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc,result).canAdopt)
            let preview = try functionalPreview(doc,result)
            let formal = try RecoveryConversion.special(preview)
            XCTAssertTrue(formal.lessons.contains { $0.className == "1_CN" && $0.sourceClassName == "1_1" })
            XCTAssertEqual(formal.recovery?.document,doc); XCTAssertEqual(formal.recovery?.result,result)
            var old = try RecoveryConversion.special(preview,remapFirstYear:false); old.version = 30
            let migrated = try XCTUnwrap(RecoveryConversion.recertifiedSpecial(old,hash:doc.pdfHash))
            XCTAssertEqual(migrated.lessons,formal.lessons); XCTAssertEqual(migrated.coveredClasses.count,17)
            XCTAssertEqual(migrated.recovery,old.recovery)
        }
    }
}


extension SpecialScheduleTests {
    func testMigratedStrictLessonsStillCompareAtTheirOriginalPDFCells() {
        typealias C = RecoveryManualComparison
        for department in ["CN","ES","IT"] {
            let original = PDFLesson(className:"1_1",weekday:1,period:1,names:TimetableLessonNames(subject:"架空科目（"+department+"）",teacher:"架空教員",room:"架空室"),sourceText:"架空原文",page:1)
            let moved = PDFClassAssignment.assign(original)
            let special = PDFClassAssignment.assign(SpecialScheduleLesson(date:"2032-04-01",className:"1_1",period:1,spanStart:1,spanEnd:1,timeRange:"09:00〜09:40",lines:[original.names.subject,"架空教員","架空室"],page:1))
            XCTAssertEqual(moved.className,"1_"+department); XCTAssertEqual(special.className,moved.className)
            for kind in ["timetable","exam","return"] {
                let effective = kind == "timetable" ? moved.className : special.className
                let source = kind == "timetable" ? moved.sourceClassName : special.sourceClassName
                let day = kind == "timetable" ? "1" : special.date
                let time = kind == "timetable" ? nil : special.timeRange
                let raw = C.Slot(className:"1_1",day:day,period:1)
                let restored = C.sourceSlot(className:effective,sourceClassName:source,day:day,period:1)
                let scope = C.Scope(kind:kind,schoolYear:2032,term:kind == "timetable" ? "前期" : nil,classes:["1_1"],days:[day],slots:[raw])
                let literal = C.Lesson(subject:original.names.subject,teacher:"架空教員",room:"架空室",spanStart:1,spanEnd:1,time:time)
                let current = C.Snapshot(scope:scope,entries:[raw:[literal]])
                let previous = C.Snapshot(scope:scope,entries:[restored:[literal]])
                XCTAssertTrue(C.compare(current,previous:previous).available)
                XCTAssertTrue(C.compare(current,previous:previous).changes.isEmpty)
                let wrong = C.Snapshot(scope:scope,entries:[C.Slot(className:effective,day:day,period:1):[literal]])
                XCTAssertFalse(C.compare(current,previous:wrong).available)
                XCTAssertEqual(C.sourceSlot(className:effective,sourceClassName:nil,day:day,period:1).className,effective)
            }
        }
    }
}
