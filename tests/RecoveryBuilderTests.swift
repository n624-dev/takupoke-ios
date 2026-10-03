import Foundation
import XCTest
@testable import TakupokeParsing

extension PDFParsingTests {
    func recoveryTimetablePage(labeled: Bool = false) -> PDFPageLayout {
        var p = timetable(); p.width = 1900
        p.glyphs.removeAll { $0.cy == 70 }
        p.lines.removeAll { $0.vertical && $0.y1 == 60 && $0.y2 == 80 }
        for i in 0..<40 {
            p.glyphs += text(String(i%8+1),x:108+Double(i)*40,y:70)
            p.lines.append(v(100+Double(i)*40,60,80))
        }
        p.lines.append(v(1700,60,80))
        p.lines.removeAll { $0.vertical && $0.x1 >= 100 && $0.y1 == 100 }
        for i in 0...40 { p.lines.append(v(100+Double(i)*40,100,280)) }
        for i in p.lines.indices where p.lines[i].horizontal { p.lines[i].x2 = 1700 }
        for i in p.glyphs.indices {
            if p.glyphs[i].x == 70 && [130.0,190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "C" }
            if p.glyphs[i].x == 74 && [130.0,190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "N" }
            if p.glyphs[i].x == 70 && p.glyphs[i].cy == 250 { p.glyphs[i].text = "2" }
        }
        for (i,label) in ["月","火","水","木","金"].enumerated() { p.glyphs += text(label,x:200+Double(i)*320,y:50) }
        if labeled {
            p.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
            for (i,line) in ["教員:架空担当R","教室:架空室S","科目:架空科目T"].enumerated() { p.glyphs += text(line,x:102,y:110+Double(i)*18,step:3) }
        }
        return p
    }
    func testLayoutRecoveryPreservesParallelLessonsAndAllSlots() async throws {
        let p = recoveryTimetablePage()
        let d = try RecoveryDocumentBuilder.build([p],kind:.timetable,hash:String(repeating:"b",count:64))
        XCTAssertEqual(d.classes.count,3); XCTAssertEqual(d.cells.flatMap(\.slots).count,120)
        XCTAssertTrue(d.cells.contains { $0.parallelCount == 2 && $0.parallelSeparators.count == 3 })
        let run = try await RecoveryEngine.run(d,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
        XCTAssertEqual(run.result?.metadata.provider,"rule")
    }
    func testReorderedInlineRolesRequireIndependentLabels() throws {
        let d = try RecoveryDocumentBuilder.build([recoveryTimetablePage(labeled:true)],kind:.timetable,hash:String(repeating:"b",count:64))
        let cell = try XCTUnwrap(d.cells.first { $0.bindingMode == .roleProposal })
        XCTAssertEqual(Set(cell.roleScopes.map(\.role)),Set(RecoveryRole.allCases))
        XCTAssertNil(RecoveryRules.recover(d,cell))
    }
    func testStrictMissingTeacherDoesNotShiftRoomIntoTeacher() throws {
        var p = timetable(); p.glyphs.removeAll { $0.cy == 130 && $0.cx >= 100 }
        let result = try parse([p],kind:.timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.teacher,""); XCTAssertEqual(lesson.names.room,"架空室Q")
        p.glyphs.removeAll { $0.cy == 190 && $0.cx >= 100 }
        XCTAssertThrowsError(try parse([p],kind:.timetable))
    }
}

extension SpecialScheduleTests {
    func testExamLayoutRecoveryReusesAllRepeatedClockCharts() async throws {
        let pages = (1...6).map { examPage($0,mergedFirstTwo:$0 == 1) }
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.exam,hash:String(repeating:"c",count:64))
        XCTAssertEqual(doc.classes.count,17); XCTAssertEqual(doc.days.count,5)
        XCTAssertEqual(doc.clockReplicas["2026-04-01:1"]?.count,5)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
    func testReturnLayoutRecoveryRequiresNormalTimeNoteAndSpanEndpoints() async throws {
        let doc = try RecoveryDocumentBuilder.build([returnPageWithSplitCell()],kind:.return,hash:String(repeating:"d",count:64))
        XCTAssertEqual(doc.classes.count,17)
        XCTAssertEqual(doc.spanTimes["2026-04-02:5-6"],"12:50〜14:20")
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
}
