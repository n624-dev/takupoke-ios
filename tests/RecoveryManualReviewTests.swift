import XCTest
@testable import TakupokeParsing

final class RecoveryManualReviewTests: XCTestCase {
    typealias C = RecoveryManualComparison
    private let slot=C.Slot(className:"架空組",day:"1",period:1)
    private func scope(year:Int=2030,kind:String="timetable",term:String?="前期") -> C.Scope {
        C.Scope(kind:kind,schoolYear:year,term:term,classes:[slot.className],days:[slot.day],slots:[slot])
    }
    private func lesson(_ subject:String="架空科",teacher:String="架空師",room:String="架空室",end:Int=1,time:String?="09:00〜09:45") -> C.Lesson {
        C.Lesson(subject:subject,teacher:teacher,room:room,spanStart:1,spanEnd:end,time:time)
    }
    private func snapshot(_ lessons:[C.Lesson],scope:C.Scope?=nil) -> C.Snapshot {
        C.Snapshot(scope:scope ?? self.scope(),entries:[slot:lessons])
    }
    func testChangedLiteralShowsBothSidesWithoutAssigningParallelRoles() {
        let before=snapshot([lesson("旧架空科"),lesson("並記架空科")]),after=snapshot([lesson("新架空科"),lesson("並記架空科")])
        let result=C.compare(after,previous:before)
        XCTAssertTrue(result.available);XCTAssertEqual(result.changes.count,1)
        XCTAssertEqual(result.changes[0].slot,slot)
        XCTAssertEqual(result.changes[0].before.count,2);XCTAssertEqual(result.changes[0].after.count,2)
    }
    func testParallelOrderDoesNotInventAChangeAndMultiplicityRemainsVisible() {
        let a=lesson("架空甲"),b=lesson("架空乙")
        XCTAssertTrue(C.compare(snapshot([a,b]),previous:snapshot([b,a])).changes.isEmpty)
        XCTAssertEqual(C.compare(snapshot([a,a]),previous:snapshot([a])).changes.count,1)
    }
    func testWhitespaceAndUnicodeBytesAreComparedLiterally() {
        XCTAssertEqual(C.compare(snapshot([lesson("架空科 ")]),previous:snapshot([lesson()])).changes.count,1)
        XCTAssertEqual(C.compare(snapshot([lesson("Ae\u{301}")]),previous:snapshot([lesson("Aé")])).changes.count,1)
    }
    func testTeacherRoomSpanAndTimeChangesAreVisible() {
        for changed in [lesson(teacher:"別架空師"),lesson(room:"別架空室"),lesson(end:2),lesson(time:"10:00〜10:45"),lesson(time:nil)] {
            XCTAssertEqual(C.compare(snapshot([changed]),previous:snapshot([lesson()])).changes.count,1)
        }
    }
    func testExplicitBlankCanCompareButMissingPreviousCellCannot() {
        let empty=snapshot([]),present=snapshot([lesson()])
        XCTAssertEqual(C.compare(empty,previous:present).changes.count,1)
        XCTAssertTrue(C.compare(empty,previous:empty).available)
        XCTAssertFalse(C.compare(present,previous:C.Snapshot(scope:scope(),entries:[:])).available)
    }
    func testDifferentYearTermKindAndMissingPreviousAreUnavailable() {
        for previous in [snapshot([lesson()],scope:scope(year:2031)),snapshot([lesson()],scope:scope(kind:"return")),snapshot([lesson()],scope:scope(term:"後期"))] {
            let result=C.compare(snapshot([lesson()]),previous:previous)
            XCTAssertFalse(result.available);XCTAssertTrue(result.changes.isEmpty)
        }
        XCTAssertFalse(C.compare(snapshot([lesson()]),previous:nil).available)
    }
    func testDifferentClassDayOrPeriodCannotBeGuessed() {
        for other in [C.Slot(className:"別架空組",day:"1",period:1),C.Slot(className:"架空組",day:"2",period:1),C.Slot(className:"架空組",day:"1",period:2)] {
            let previous=C.Snapshot(scope:C.Scope(kind:"timetable",schoolYear:2030,term:"前期",classes:[other.className],days:[other.day],slots:[other]),entries:[other:[lesson()]])
            XCTAssertFalse(C.compare(snapshot([lesson()]),previous:previous).available)
        }
    }
    func testDuplicateScopeSlotsAndUndeclaredEntriesCannotCompare() {
        let duplicate=C.Scope(kind:"timetable",schoolYear:2030,term:"前期",classes:[slot.className],days:[slot.day],slots:[slot,slot])
        XCTAssertFalse(C.compare(snapshot([lesson()],scope:duplicate),previous:snapshot([lesson()])).available)
        let extra=C.Slot(className:"別架空組",day:"1",period:1)
        XCTAssertFalse(C.compare(C.Snapshot(scope:scope(),entries:[slot:[lesson()],extra:[]]),previous:snapshot([lesson()])).available)
    }
    func testPixelHighlightPreservesOriginAndFractionalBounds() {
        typealias G=RecoveryManualImageGeometry
        let actual=G.normalizedHighlight(container:G.Bounds(x:20,y:30,width:40,height:80),target:G.Bounds(x:22.5,y:50,width:10,height:20))
        XCTAssertEqual(actual,G.Bounds(x:0.0625,y:0.25,width:0.25,height:0.25))
    }
    func testHighlightRejectsOutsideNonfiniteAndDegenerateGeometry() {
        typealias G=RecoveryManualImageGeometry
        let container=G.Bounds(x:0,y:0,width:40,height:80)
        for invalid in [G.Bounds(x:-1,y:0,width:2,height:2),G.Bounds(x:39,y:0,width:2,height:2),G.Bounds(x:0,y:79,width:2,height:2),G.Bounds(x:0,y:0,width:0,height:2),G.Bounds(x:.nan,y:0,width:2,height:2),G.Bounds(x:0,y:0,width:2,height:.infinity),G.Bounds(x:Double.greatestFiniteMagnitude,y:0,width:Double.greatestFiniteMagnitude,height:2)] {
            XCTAssertNil(G.normalizedHighlight(container:container,target:invalid))
        }
    }
}
