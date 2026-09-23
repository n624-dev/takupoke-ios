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

    func testReferenceFixturesThroughCompressedXLSX() throws {
        let url = Bundle.module.url(forResource: "normalization", withExtension: "json", subdirectory: "fixtures")!
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        try temporary { root in
            for item in fixtures.cases {
                for shared in [false, true] {
                    let url = root.appendingPathComponent(item.id + (shared ? "-shared" : "-inline") + ".xlsx")
                    try write(workbook(item.sheetRows, shared: shared), to: url)
                    let rows = try XLSXReader.read(url)
                    if item.iosDisposition == "compare" {
                        let expected = item.expectedRecords.map { reference in
                            guard let alias = item.iosClassAliases?[reference.class_name] else { return reference }
                            var adjusted = reference
                            let prefix = reference.change_date + " | " + reference.class_name
                            XCTAssertTrue(reference.canonical_text.hasPrefix(prefix + " | "))
                            adjusted.class_name = alias
                            adjusted.canonical_text = reference.change_date + " | " + alias + reference.canonical_text.dropFirst(prefix.count)
                            return adjusted
                        }
                        XCTAssertEqual(try ChangeNormalizer.parse(rows, defaultYear: item.defaultYear), expected, item.id)
                    } else {
                        assertCode(item.id == "all-without-known-classes" ? .unknownAll : .date) {
                            _ = try ChangeNormalizer.parse(rows, defaultYear: item.defaultYear)
                        }
                    }
                }
            }
        }
    }
    func testAIClassAliasesThroughXLSXKeepRowsAndSourceText() throws {
        let rows = [["学 年", "学科・クラス", "月日", "科目"],
                    ["1", "AI", "2032/7/10", "架空科目A"],
                    ["AI", "1", "2032/7/11", "架空科目B"],
                    ["2", "AI", "2032/7/12", "架空科目C"],
                    ["AI", "2", "2032/7/13", "架空科目D"],
                    ["1～2", "ZZ,AI", "2032/7/14", "架空科目E"],
                    ["AI", "2,1", "2032/7/15", "架空科目F"],
                    ["1", "全", "2032/7/16", "架空科目G"]]
        try temporary { root in
            for shared in [false, true] {
                let url = root.appendingPathComponent("aliases-\(shared).xlsx")
                try write(workbook(rows, shared: shared), to: url)
                let records = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: nil)
                XCTAssertEqual(records.map(\.class_name), ["AI_1", "AI_1", "AI_2", "AI_2", "1_ZZ", "AI_1", "2_ZZ", "AI_2", "AI_2", "AI_1", "1_ZZ"])
                XCTAssertEqual(records[0].raw_text, "学 年:1 | 学科・クラス:AI | 月日:2032/7/10 | 科目:架空科目A")
                XCTAssertEqual(records[1].raw_text, "学 年:AI | 学科・クラス:1 | 月日:2032/7/11 | 科目:架空科目B")
                XCTAssertEqual(records[0].canonical_text, "2032-07-10 | AI_1 | 架空科目A | 学 年:1 | 学科・クラス:AI | 月日:2032/7/10 | 科目:架空科目A")
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_1" }.count, 4)
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_2" }.count, 4)
                XCTAssertEqual(try ChangeNormalizer.parse([rows[0], rows[1], rows[1]], defaultYear: nil).count, 2)
            }
        }
        for year in 1...9 {
            XCTAssertEqual(ChangeNormalizer.canonicalClassName("\(year)_AI"), "AI_\(year)")
            XCTAssertEqual(ChangeNormalizer.canonicalClassName("AI_\(year)"), "AI_\(year)")
        }
        for name in ["1_ZZ", "2_YY", "AI_ZZ", "1_AIX", "0_AI", "10_AI", "ZZ_AI", "1_AI_ZZ"] {
            XCTAssertEqual(ChangeNormalizer.canonicalClassName(name), name)
        }
    }

    func testLegacyAIClassDisplayDoesNotRewriteSavedResults() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root)
            let staged = library.newStagingURL()
            try Data("PK synthetic".utf8).write(to: staged)
            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                               byteCount: 12, digest: "source-a", modifiedAt: nil)
            let old = ScheduleChange(change_date: "2032-07-10", class_name: "1_AI", period: "1",
                before_subject: "架空科目A", after_subject: "", teacher: "架空教員A", room: "", note: "",
                raw_text: "学 年:1 | 学科・クラス:AI", canonical_text: "2032-07-10 | 1_AI | 1 | 架空科目A | 架空教員A | 学 年:1 | 学科・クラス:AI")
            var other = old
            other.class_name = "AI_1"
            other.raw_text = "学 年:AI | 学科・クラス:1"
            other.canonical_text = "2032-07-10 | AI_1 | 1 | 架空科目A | 架空教員A | 学 年:AI | 学科・クラス:1"
            let manifest = root.appendingPathComponent("library.json")
            for version in [1, 2] {
                var legacy = library.state
                legacy.changeAnalysis = ChangeAnalysis(version: version, sourceDigest: "source-a", sourceName: "架空資料.xlsx",
                    defaultYear: nil, parsedAt: Date(), records: [old, other])
                legacy.changeParseAttempt = ChangeParseAttempt(date: Date(), sourceDigest: "source-a", defaultYear: nil,
                                                               failure: ChangeParseError(code: .weekdayMismatch, row: 5))
                let original = try JSONEncoder().encode(legacy)
                try original.write(to: manifest, options: .atomic)
                let reloaded = try MaterialLibrary(root: root)
                let records = try XCTUnwrap(reloaded.state.changeAnalysis?.records)
                XCTAssertEqual(records, [old, other])
                XCTAssertEqual(Set(records.map(\.displayClassName)), ["AI_1"])
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_1" }.count, 2)
                XCTAssertEqual(reloaded.state.changeAnalysis?.version, version)
                XCTAssertEqual(reloaded.state.changeParseAttempt?.failure?.code, .weekdayMismatch)
                XCTAssertEqual(try Data(contentsOf: manifest), original)
            }
        }
    }

    func testDatesAndExplicitYear() throws {
        XCTAssertEqual(try ChangeNormalizer.date("2032年2月29日", defaultYear: nil), "2032-02-29")
        XCTAssertEqual(try ChangeNormalizer.date("1/2", defaultYear: 2033), "2034-01-02")
        XCTAssertEqual(try ChangeNormalizer.date("4/1", defaultYear: 2033), "2033-04-01")
        XCTAssertEqual(try ChangeNormalizer.date("2033/1/2", defaultYear: 2033), "2033-01-02")
        XCTAssertEqual(try ChangeNormalizer.date("46119.75", defaultYear: nil), "2026-04-07")
        for value in ["2031/2/29", "2032/13/1", "2032/0/1", "2032/4/31", "7/10", "99999999999999999999", "0"] {
            assertCode(.date) { _ = try ChangeNormalizer.date(value, defaultYear: nil) }
        }
    }
    func testTableFailuresAndBounds() throws {
        assertCode(.headers) { _ = try ChangeNormalizer.parse([["架空見出し"]], defaultYear: nil) }
        assertCode(.headers) { _ = try ChangeNormalizer.parse([headers + ["月日"], example[1]], defaultYear: nil) }
        assertCode(.empty) { _ = try ChangeNormalizer.parse([headers], defaultYear: nil) }
        assertCode(.year) { _ = try ChangeNormalizer.parse([headers, ["1～99999", "ZZ", "2032/7/10"]], defaultYear: nil) }
        for grade in ["", "0", "10", "架空学年", "AI-2", "1,2"] {
            assertCode(.year) { _ = try ChangeNormalizer.parse([headers, [grade, "ZZ", "2032/7/10"]], defaultYear: nil) }
        }
        assertCode(.classes) { _ = try ChangeNormalizer.parse([headers, ["1", "", "2032/7/10"]], defaultYear: nil) }
        assertCode(.limit) { _ = try ChangeNormalizer.parse(Array(repeating: [], count: 10_001), defaultYear: nil) }
        var rows = example
        rows[1][5] = String(repeating: "架空", count: 4097)
        assertCode(.limit) { _ = try ChangeNormalizer.parse(rows, defaultYear: nil) }
    }
    func testUnsupportedAndMalformedWorkbooks() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            var files = workbook(example)
            mutate(&files, "xl/workbook.xml", "時間割変更", "架空別表")
            variants.append((files, .missingSheet))
            files = workbook(example)
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"1\"/><sheets>")
            variants.append((files, .dateSystem))
            files = workbook(example)
            mutate(&files, "xl/_rels/workbook.xml.rels", "Target=", "TargetMode=\"External\" Target=")
            variants.append((files, .unsupported))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"A2\"", "<c r=\"B2\"")
            variants.append((files, .invalidXML))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "</worksheet>", "<mergeCells><mergeCell ref=\"A2:B2\"/></mergeCells></worksheet>")
            variants.append((files, .mergedCells))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"A2\" t=\"inlineStr\"><is>", "<c r=\"A2\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            files = workbook(example, shared: true)
            mutate(&files, "xl/worksheets/sheet1.xml", "<v>0</v>", "<v>-1</v>")
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["xl/workbook.xml"] = Data("<!DOCTYPE workbook [<!ENTITY x SYSTEM 'https://example.invalid/never'>]><workbook>&x;</workbook>".utf8)
            variants.append((files, .unsupported))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<sheetData>", "<sheetData/><sheetData>")
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["xl/workbook.xml"] = Data("<workbook>".utf8)
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["../outside.xml"] = Data("架空".utf8)
            variants.append((files, .invalidArchive))
            files = workbook(example)
            files["xl/workbook.xml"] = Data(repeating: 32, count: XLSXReader.maximumXMLBytes + 1)
            variants.append((files, .limit))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("invalid-\(index).xlsx")
                try write(variant.0, to: url)
                assertCode(variant.1) { _ = try XLSXReader.read(url) }
            }
        }
    }
    func weekdayWorkbook(date: String = "2032/7/10", cached: String? = "土") -> [String: Data] {
        let rows = [["架空の確認表"], [], [],
                    ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
                    ["1", "ZZ", date, "架空置換欄", "1", "休講", "架空科目A(架空教員A)"]]
        var files = workbook(rows)
        let path = "xl/worksheets/sheet1.xml"
        mutate(&files, path, "<row r=\"3\"></row>", "<row r=\"3\"><c r=\"G3\"><f>TODAY()</f><v>48000</v></c></row>")
        let formula = "<f>TEXT(架空表[[#This Row],[月日]], &quot;aaa&quot;)</f>"
        let value = cached.map { "<v>\(escape($0))</v>" } ?? ""
        mutate(&files, path, "<c r=\"D5\" t=\"inlineStr\"><is><t xml:space=\"preserve\">架空置換欄</t></is></c>",
               "<c r=\"D5\" t=\"str\">\(formula)\(value)</c>")
        mutate(&files, path, "</worksheet>", "<mergeCells><mergeCell ref=\"A1:G1\"/></mergeCells></worksheet>")
        return files
    }

    func testMetadataAndValidatedWeekdayFormulas() throws {
        try temporary { root in
            for (index, value) in ["土", "土曜", "土曜日", "（土）"].enumerated() {
                let url = root.appendingPathComponent("weekday-\(index).xlsx")
                try write(weekdayWorkbook(cached: value), to: url)
                let rows = try XLSXReader.read(url)
                XCTAssertEqual(rows[2][6], "") // Metadata formula is outside the table.
                let result = try ChangeNormalizer.parse(rows, defaultYear: nil)
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result[0].before_subject, "架空科目A(架空教員A)")
                XCTAssertTrue(result[0].raw_text.contains("曜日:" + ChangeNormalizer.text(value)))
            }
            let url = root.appendingPathComponent("yearless.xlsx")
            try write(weekdayWorkbook(date: "7/10"), to: url)
            assertCode(.date) { _ = try XLSXReader.read(url) }
            XCTAssertEqual(try ChangeNormalizer.parse(XLSXReader.read(url, defaultYear: 2032), defaultYear: 2032).count, 1)
        }
    }

    func testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula() throws {
        try temporary { root in
            for (index, pair) in [(nil, ChangeParseError.Code.formulaCache), ("日", .weekdayMismatch), ("架空文字", .weekdayMismatch)].enumerated() {
                let url = root.appendingPathComponent("bad-weekday-\(index).xlsx")
                try write(weekdayWorkbook(cached: pair.0), to: url)
                assertCode(pair.1) { _ = try XLSXReader.read(url) }
            }
            var files = weekdayWorkbook()
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"G5\" t=\"inlineStr\"><is>",
                   "<c r=\"G5\" t=\"inlineStr\"><f>1+1</f><is>")
            let url = root.appendingPathComponent("major-formula.xlsx")
            try write(files, to: url)
            assertCode(.formula) { _ = try XLSXReader.read(url) }
        }
    }

    func testWarningPreviewKeepsSuccessAndFailureUnchanged() throws {
        try temporary { root in
            for (index, cached) in [nil, "金"].enumerated() {
                let directory = root.appendingPathComponent("library-\(index)")
                let library = try MaterialLibrary(root: directory)
                func acquire(_ files: [String: Data], digest: String) throws {
                    let staged = library.newStagingURL()
                    try write(files, to: staged)
                    let count = try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!
                    try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                                       byteCount: count, digest: digest, modifiedAt: nil)
                }
                try acquire(weekdayWorkbook(), digest: "good")
                let good = ChangeAnalysis(sourceDigest: "good", sourceName: "架空資料.xlsx", defaultYear: nil,
                    parsedAt: Date(), records: try ChangeNormalizer.parse(example, defaultYear: nil))
                try library.saveChangeAnalysis(good)
                try acquire(weekdayWorkbook(date: "7/10", cached: cached), digest: "warning")
                assertCode(.unsupported) { _ = try library.previewChanges() } // No failed weekday check yet.
                do {
                    _ = try XLSXReader.read(library.localURL(for: .changes)!, defaultYear: 2032)
                    XCTFail("Strict parsing must reject a weekday warning")
                } catch let failure as ChangeParseError {
                    XCTAssertTrue(failure.permitsPreview)
                    try library.recordParseFailure(failure, defaultYear: 2032)
                }
                let manifest = directory.appendingPathComponent("library.json")
                let previousBytes = try Data(contentsOf: manifest)
                let preview = try library.previewChanges()
                XCTAssertEqual(preview.defaultYear, 2032)
                XCTAssertEqual(preview.records.count, 1)
                XCTAssertEqual(preview.records[0].change_date, "2032-07-10")
                XCTAssertEqual(preview.records[0].before_subject, "架空科目A(架空教員A)")
                XCTAssertEqual(preview.warnings, [ChangeParseError(code: cached == nil ? .formulaCache : .weekdayMismatch, row: 5)])
                XCTAssertEqual(try Data(contentsOf: manifest), previousBytes)
                let reopened = try MaterialLibrary(root: directory)
                XCTAssertEqual(reopened.state.changeAnalysis?.records, good.records)
                XCTAssertEqual(reopened.state.changeAnalysis?.sourceDigest, "good")
                XCTAssertTrue(reopened.state.changeParseAttempt?.failure?.permitsPreview == true)
                assertCode(.cancelled) { _ = try library.previewChanges { throw ChangeParseError(code: .cancelled) } }
                XCTAssertEqual(try Data(contentsOf: manifest), previousBytes)
                try acquire(weekdayWorkbook(cached: cached), digest: "another-source")
                assertCode(.unsupported) { _ = try library.previewChanges() } // A new source needs a new check.
            }
        }
    }

    func testPreviewDoesNotBypassOtherErrors() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            variants.append((weekdayWorkbook(date: "2032/2/30", cached: nil), .date))
            var files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"G5\" t=\"inlineStr\"><is>",
                   "<c r=\"G5\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/worksheets/sheet1.xml", "A1:G1", "A5:B5")
            variants.append((files, .mergedCells))
            files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"1\"/><sheets>")
            variants.append((files, .dateSystem))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("blocked-preview-\(index).xlsx")
                try write(variant.0, to: url)
                assertCode(variant.1) { _ = try XLSXReader.readForPreview(url) }
                XCTAssertFalse(ChangeParseError(code: variant.1).permitsPreview)
            }
        }
    }

    func testSharedStringsExpansionLimit() throws {
        try temporary { root in
            var files = workbook(example, shared: true)
            files["xl/sharedStrings.xml"] = Data(("<sst xmlns=\"\(ns)\"><si><t>" + String(repeating: "A", count: 4096) + "</t></si></sst>").utf8)
            let rows = (1...4097).map { "<row r=\"\($0)\"><c r=\"A\($0)\" t=\"s\"><v>0</v></c></row>" }.joined()
            files["xl/worksheets/sheet1.xml"] = Data("<worksheet xmlns=\"\(ns)\"><sheetData>\(rows)</sheetData></worksheet>".utf8)
            let url = root.appendingPathComponent("repeated.xlsx")
            try write(files, to: url)
            assertCode(.limit) { _ = try XLSXReader.read(url) }
        }
    }

    func testCancellationAndCorruption() throws {
        try temporary { root in
            let url = root.appendingPathComponent("test.xlsx")
            try write(workbook(example), to: url, compression: .none)
            var calls = 0
            assertCode(.cancelled) {
                _ = try XLSXReader.read(url) {
                    calls += 1
                    if calls > 4 { throw ChangeParseError(code: .cancelled) }
                }
            }
            var bytes = try Data(contentsOf: url)
            // Alter a stored XML byte without changing the recorded CRC.
            let needle = Data("時間割変更".utf8)
            let range = bytes.range(of: needle)!
            bytes[range.lowerBound] ^= 1
            try bytes.write(to: url)
            assertCode(.invalidArchive) { _ = try XLSXReader.read(url) }
            try Data("not a workbook".utf8).write(to: url)
            assertCode(.invalidArchive) { _ = try XLSXReader.read(url) }
        }
    }
    func testRichTextNumericDatesAndSparseCells() throws {
        try temporary { root in
            var files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"C2\" t=\"inlineStr\"><is><t xml:space=\"preserve\">2032/7/10</t></is></c>", "<c r=\"C2\"><v>46119</v></c>")
            mutate(&files, "xl/worksheets/sheet1.xml", "<t xml:space=\"preserve\">架空科目A(架空教員A)</t>", "<r><t>架空科目</t></r><r><t>A</t></r><rPh><t>架空読み</t></rPh>")
            let url = root.appendingPathComponent("rich.xlsx")
            try write(files, to: url)
            let records = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: nil)
            XCTAssertEqual(records[0].change_date, "2026-04-07")
            XCTAssertEqual(records[0].before_subject, "架空科目A")
        }
    }
    func testPersistenceFailureAndNewSourceKeepLastGoodResult() throws {
        try temporary { root in
            var fail = false
            let library = try MaterialLibrary(root: root) { data, url in
                if fail { throw ChangeParseError(code: .storage) }
                try data.write(to: url, options: .atomic)
            }
            func acquire(_ digest: String) throws {
                let staged = library.newStagingURL()
                try Data("PK synthetic".utf8).write(to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                                   byteCount: 12, digest: digest, modifiedAt: nil)
            }
            try acquire("source-a")
            let records = try ChangeNormalizer.parse(example, defaultYear: nil)
            let good = ChangeAnalysis(sourceDigest: "source-a", sourceName: "架空資料.xlsx", defaultYear: nil, parsedAt: Date(), records: records)
            try library.saveChangeAnalysis(good)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.records, records)
            try acquire("source-b")
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            try library.recordParseFailure(ChangeParseError(code: .date, row: 2), defaultYear: 2032)
            XCTAssertEqual(library.state.changeAnalysis?.records, records)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeParseAttempt?.failure?.code, .date)
            fail = true
            var next = good
            next.sourceDigest = "source-b"
            XCTAssertThrowsError(try library.saveChangeAnalysis(next))
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-a")
            fail = false
            try library.saveChangeAnalysis(next)
            XCTAssertNil(library.state.changeParseAttempt?.failure)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-b")
            var legacy = library.state
            legacy.changeAnalysis?.version = 1
            legacy.changeParseAttempt?.failure = ChangeParseError(code: .unsupported, row: 3)
            try JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("library.json"), options: .atomic)
            let reopened = try MaterialLibrary(root: root)
            XCTAssertEqual(reopened.state.changeAnalysis?.version, 1)
            XCTAssertEqual(reopened.state.changeAnalysis?.records, records)
            XCTAssertEqual(reopened.state.changeParseAttempt?.failure?.code, .unsupported)
        }
    }
}
