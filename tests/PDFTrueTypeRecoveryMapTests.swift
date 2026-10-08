import XCTest
@testable import TakupokeParsing

final class PDFTrueTypeRecoveryMapTests: XCTestCase {
    func testIdentityAndExplicitCidMapPreserveExactGlyphAndScalar() throws {
        let map = try PDFTrueTypeRecoveryMap.read(font([format12([(65, 66, 1), (0x1f642, 0x1f642, 3)])]))
        XCTAssertEqual(map.fontHash.count, 64)
        XCTAssertEqual(try map.resolve(cid: 1, cidToGid: nil).text, "A")
        XCTAssertEqual(try map.resolve(cid: 3, cidToGid: nil).text, "🙂")
        XCTAssertEqual(try map.resolve(cid: 1, cidToGid: Data([0, 0, 0, 2])).glyph, 2)
        XCTAssertEqual(try map.resolve(cid: 1, cidToGid: Data([0, 0, 0, 2])).text, "B")
        for cid in [-1, 0, 4, 65536] { XCTAssertThrowsError(try map.resolve(cid: cid, cidToGid: nil)) }
        XCTAssertThrowsError(try map.resolve(cid: 1, cidToGid: Data([0, 0, 0])))
        XCTAssertThrowsError(try map.resolve(cid: 2, cidToGid: Data([0, 0, 0, 2])))
        // Sliced Data may have a nonzero startIndex; resolution is still CID-based.
        let bytes = Data([9, 9, 0, 0, 0, 2]).dropFirst(2)
        XCTAssertEqual(try map.resolve(cid: 1, cidToGid: bytes).text, "B")
    }
    func testWhitespaceAliasesRemainAmbiguousAndUnusedAmbiguityDoesNotDiscardOtherGlyph() throws {
        let map = try PDFTrueTypeRecoveryMap.read(font([format12([(32, 32, 1), (65, 65, 2), (160, 160, 1)])]))
        XCTAssertTrue(map.ambiguousGlyphs.contains(1)); XCTAssertNil(map.uniqueScalars[1])
        XCTAssertThrowsError(try map.resolve(cid: 1, cidToGid: nil))
        XCTAssertEqual(try map.resolve(cid: 2, cidToGid: nil).text, "A")
    }
    func testAllUnicodeMapsContributeAndDisagreementIsUnresolved() throws {
        let inconsistent = try PDFTrueTypeRecoveryMap.read(font([format12([(65, 65, 1)]), format12([(66, 66, 1)])]))
        XCTAssertTrue(inconsistent.ambiguousGlyphs.contains(1))
        XCTAssertThrowsError(try inconsistent.resolve(cid: 1, cidToGid: nil))
        let consistent = try PDFTrueTypeRecoveryMap.read(font([format4(65, 1), format12([(65, 65, 1)])]))
        XCTAssertEqual(try consistent.resolve(cid: 1, cidToGid: nil).text, "A")
    }
    func testFormat4GlyphArrayUsesItsOwnOffsetAndDelta() throws {
        var table = format4(65, 1)
        u16(&table, 24, 1); u16(&table, 28, 4)
        table += [0, 0]; u16(&table, 2, table.count); u16(&table, 32, 1)
        let map = try PDFTrueTypeRecoveryMap.read(font([table]))
        XCTAssertEqual(try map.resolve(cid: 2, cidToGid: nil).text, "A")
        XCTAssertThrowsError(try map.resolve(cid: 1, cidToGid: nil))
        u16(&table, 28, 2)
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(font([table])))
    }
    func testUnsupportedUnicodeTableIsNotIgnored() {
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(font([format12([(65, 65, 1)]), [0, 6]])))
    }
    func testEveryRequiredBytePrefixIsRejected() {
        let complete = font([format12([(65, 65, 1)])])
        for count in 0..<complete.count { XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(complete.prefix(count))) }
    }
    func testDuplicateAndOverlappingTablesAreRejected() {
        var bytes = Array(font([format12([(65, 65, 1)])]))
        bytes.replaceSubrange(28..<32, with: bytes[12..<16])
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(Data(bytes)))
        bytes = Array(font([format12([(65, 65, 1)])]))
        bytes.replaceSubrange(36..<40, with: bytes[20..<24])
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(Data(bytes)))
    }
    func testInvalidUnicodeAndGlyphRangesAndOrderingAreRejected() {
        for range in [(0xd800, 0xd800, 1), (0x110000, 0x110000, 1), (65, 64, 1), (65, 68, 1)] {
            XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(font([format12([range])])))
        }
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(font([format12([(66, 66, 1), (65, 65, 2)])])))
    }
    func testNonUnicodeMapCannotSupplyAValue() {
        var bytes = Array(font([format12([(65, 65, 1)])]))
        let offset = read32(bytes, 20); u16(&bytes, offset + 4, 1)
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(Data(bytes)))
    }
    func testCancellationIsPropagated() {
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(font([format12([(65, 65, 1)])]), cancelled: { true })) {
            XCTAssertTrue($0 is CancellationError)
        }
    }
    func testExcessiveDistinctMappingWorkIsRefusedWithoutTruncation() {
        var bytes = Array(font(Array(repeating: format12([(0, 50000, 1)]), count: 64)))
        let offset = read32(bytes, 36); u16(&bytes, offset + 4, 65535)
        XCTAssertThrowsError(try PDFTrueTypeRecoveryMap.read(Data(bytes))) {
            guard case PDFTrueTypeRecoveryMap.Failure.limit = $0 else { return XCTFail("Expected a bounded-work refusal: \($0)") }
        }
    }
    func testDuplicateSubtableReferenceRetainsSameExactMapping() throws {
        var bytes = Array(font([format12([(65, 65, 1)]), format12([(65, 65, 1)])]))
        let offset = read32(bytes, 20)
        bytes.replaceSubrange((offset + 16)..<(offset + 20), with: bytes[(offset + 8)..<(offset + 12)])
        XCTAssertEqual(try PDFTrueTypeRecoveryMap.read(Data(bytes)).resolve(cid: 1, cidToGid: nil).text, "A")
    }
    private func font(_ subtables: [[UInt8]]) -> Data {
        var cmap = [UInt8](repeating: 0, count: 4 + subtables.count * 8)
        u16(&cmap, 2, subtables.count)
        for (index, subtable) in subtables.enumerated() {
            u16(&cmap, 4 + index * 8, 0); u16(&cmap, 6 + index * 8, 4); u32(&cmap, 8 + index * 8, cmap.count)
            cmap += subtable
        }
        var maxp = [UInt8](repeating: 0, count: 6); u32(&maxp, 0, 0x00010000); u16(&maxp, 4, 4)
        let tables: [(String, [UInt8])] = [("cmap", cmap), ("maxp", maxp), ("glyf", [0, 0]), ("loca", [UInt8](repeating: 0, count: 10))]
        var bytes = [UInt8](repeating: 0, count: 12 + tables.count * 16)
        u32(&bytes, 0, 0x00010000); u16(&bytes, 4, tables.count)
        for (index, table) in tables.enumerated() {
            bytes.replaceSubrange((12 + index * 16)..<(16 + index * 16), with: table.0.utf8)
            u32(&bytes, 20 + index * 16, bytes.count); u32(&bytes, 24 + index * 16, table.1.count)
            bytes += table.1
        }
        return Data(bytes)
    }
    private func format12(_ groups: [(Int, Int, Int)]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 16 + groups.count * 12)
        u16(&bytes, 0, 12); u32(&bytes, 4, bytes.count); u32(&bytes, 12, groups.count)
        for (index, group) in groups.enumerated() {
            u32(&bytes, 16 + index * 12, group.0); u32(&bytes, 20 + index * 12, group.1); u32(&bytes, 24 + index * 12, group.2)
        }
        return bytes
    }
    private func format4(_ scalar: Int, _ glyph: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 32)
        u16(&bytes, 0, 4); u16(&bytes, 2, bytes.count); u16(&bytes, 6, 4)
        u16(&bytes, 14, scalar); u16(&bytes, 16, 65535); u16(&bytes, 20, scalar); u16(&bytes, 22, 65535)
        u16(&bytes, 24, (glyph - scalar) & 65535); u16(&bytes, 26, 1)
        return bytes
    }
    private func read32(_ bytes: [UInt8], _ position: Int) -> Int { (0..<4).reduce(0) { $0 * 256 + Int(bytes[position + $1]) } }
    private func u16(_ bytes: inout [UInt8], _ offset: Int, _ value: Int) { bytes[offset] = UInt8((value >> 8) & 255); bytes[offset + 1] = UInt8(value & 255) }
    private func u32(_ bytes: inout [UInt8], _ offset: Int, _ value: Int) { for index in 0..<4 { bytes[offset + index] = UInt8((value >> (8 * (3 - index))) & 255) } }
}
