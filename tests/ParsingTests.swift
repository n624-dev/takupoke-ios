import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

final class ParsingTests: XCTestCase {
    struct Fixtures: Decodable {
        struct Case: Decodable {
            let id: String
            let defaultYear: Int
            let iosDisposition: String
            let sheetRows: [[String]]
            let expectedRecords: [ScheduleChange]
            let iosClassAliases: [String: String]?
        }
        let cases: [Case]
    }
    let headers = ["学 年", "学科・クラス", "月日", "時限", "変更内容", "科目(担当教員)"]
    var example: [[String]] { [headers, ["1", "ZZ", "2032/7/10", "1,2", "休講", "架空科目A(架空教員A)"]] }
    let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"

    func temporary(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-parsing-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
    func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    func workbook(_ rows: [[String]], shared: Bool = false) -> [String: Data] {
        var strings: [String] = []
        let contents = rows.enumerated().map { row, cells in
            "<row r=\"\(row + 1)\">" + cells.enumerated().map { col, value in
                // Fixture tables have fewer than 26 columns; omitted cells test sparse reads.
                if value.isEmpty { return "" }
                let ref = String(UnicodeScalar(65 + col)!) + String(row + 1)
                if shared {
                    strings.append(value)
                    return "<c r=\"\(ref)\" t=\"s\"><v>\(strings.count - 1)</v></c>"
                }
                return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
            }.joined() + "</row>"
        }.joined()
        var files = [
            "xl/workbook.xml": "<workbook xmlns=\"\(ns)\" xmlns:q=\"\(rel)\"><sheets><sheet name=\"時間割変更\" sheetId=\"1\" q:id=\"s1\"/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels": "<Relationships xmlns=\"\(pkg)\"><Relationship Id=\"s1\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
            "xl/worksheets/sheet1.xml": "<worksheet xmlns=\"\(ns)\"><sheetData>\(contents)</sheetData></worksheet>"
        ]
        if shared { files["xl/sharedStrings.xml"] = "<sst xmlns=\"\(ns)\">" + strings.map { "<si><r><t>\(escape($0))</t></r></si>" }.joined() + "</sst>" }
        return files.mapValues { Data($0.utf8) }
    }
    func write(_ files: [String: Data], to url: URL, compression: CompressionMethod = .deflate) throws {
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in files.sorted(by: { $0.key < $1.key }) {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: compression) { position, size in
                data.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
    }
    func mutate(_ files: inout [String: Data], _ path: String, _ before: String, _ after: String) {
        let s = String(data: files[path]!, encoding: .utf8)!
        precondition(s.contains(before))
        files[path] = Data(s.replacingOccurrences(of: before, with: after).utf8)
    }
    func assertCode(_ code: ChangeParseError.Code, _ body: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual((error as? ChangeParseError)?.code, code, file: file, line: line)
        }
    }

}
