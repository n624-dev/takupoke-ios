import XCTest
@testable import TakupokeParsing

final class MaterialPickerLayoutTests: XCTestCase {
    func testInstructionNeverCoversPickerAtPhoneSizes() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667),
                     CGSize(width: 390, height: 844), CGSize(width: 393, height: 852),
                     CGSize(width: 430, height: 932)] {
            for top in [20.0, 47, 59] {
                for height in [44.0, 66, 120, 240] {
                    let bounds = CGRect(origin: .zero, size: size)
                    let layout = MaterialPickerLayout(bounds: bounds, topInset: top, instructionHeight: height)
                    XCTAssertTrue(bounds.contains(layout.instruction))
                    XCTAssertTrue(bounds.contains(layout.picker))
                    XCTAssertFalse(layout.instruction.intersects(layout.picker))
                    XCTAssertGreaterThanOrEqual(layout.instruction.minY, top)
                    XCTAssertEqual(layout.picker.width, bounds.width)
                    XCTAssertEqual(layout.picker.maxY, bounds.maxY)
                    XCTAssertGreaterThan(layout.picker.height, 0)
                }
            }
        }
    }

    func testWrappedInstructionReservesMoreSpaceWithoutMovingBottomControls() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        let short = MaterialPickerLayout(bounds: bounds, topInset: 59, instructionHeight: 44)
        let wrapped = MaterialPickerLayout(bounds: bounds, topInset: 59, instructionHeight: 110)
        XCTAssertGreaterThan(wrapped.picker.minY, short.picker.minY)
        XCTAssertEqual(short.picker.maxY, wrapped.picker.maxY)
        XCTAssertFalse(wrapped.instruction.intersects(wrapped.picker))
    }
}
