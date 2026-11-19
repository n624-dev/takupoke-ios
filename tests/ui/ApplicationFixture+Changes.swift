import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

enum SimulatorChangeRowSkipFixture {
    static func owns(_ url: URL) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--change-row-skip") || arguments.contains("--change-weekday-carryover"),
            let base = try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return false }
        return url.standardizedFileURL
            == base.appendingPathComponent("FictionalChangeRowSkip/完全架空変更.xlsx").standardizedFileURL
    }

    static func seed(_ base: URL) throws {
        UserDefaults.standard.set("2032", forKey: ChangeNormalizer.schoolYearSettingKey)
        let directory = base.appendingPathComponent("FictionalChangeRowSkip", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("完全架空変更.xlsx")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        var rows = [
            ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
            ["1", "ZZ", "2032/7/10", "土", "1", "補講", "架空科目A"],
            ["1", "ZZ", "46343", "月", "2", "補講", "架空除外科目B"],
            ["", "", "", "火"],
            ["1", "ZZ", "2032/7/12", "月", "3", "補講", "架空科目C"],
            ["", "ES・IT", "2032/7/10", "土", "4", "補講", "架空科目D"],
            ["", "ZZ", "2032/7/12", "月", "5", "補講", "架空科目E"],
        ]
        rows += Array(repeating:[],count:192)
        rows += Array(repeating:["","","","土"],count:101)
        try writeWorkbook(rows, numericDate: true, to: url)
        let worker = MaterialWorker()
        try worker.open()
        try worker.selectFile(ScopedMaterialSelection(url), kind: .changes, control: AcquisitionControl())
        do {
            try worker.analyzeChanges(defaultYear: 2032, control: AcquisitionControl())
            throw NSError(domain: "FictionalRowSkipMustFailStrict", code: 1)
        } catch let failure as ChangeParseError {
            guard failure.code == .weekdayMismatch else { throw failure }
        }
    }

    static func seedCarryover(_ base: URL, updated: Bool) throws {
        let directory = base.appendingPathComponent("FictionalChangeRowSkip", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("完全架空変更.xlsx")
        let saturday = ["", "", "", "土"], sunday = ["", "", "", "日"]
        let headers = ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"]
        var rows = [headers, ["1", "ZZ", "2032/7/10", "土", "1", "補講", "架空科目A"]]
            + Array(repeating: saturday, count: 46) + Array(repeating: sunday, count: 44)
        if updated {
            rows[2] = ["1", "ZZ", "2032/7/12", "月", "2", "補講", "架空追加科目B"]
            rows.append(sunday)
            let staged = directory.appendingPathComponent("更新-\(UUID().uuidString).xlsx")
            defer { try? FileManager.default.removeItem(at: staged) }
            try writeWorkbook(rows, numericDate: false, to: staged)
            // Replace bytes in the selected file so the real bookmark, source identity,
            // provider and freshness checks are exercised on reacquisition.
            let bytes = try Data(contentsOf: staged)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: bytes)
            return
        }
        UserDefaults.standard.set("2032", forKey: ChangeNormalizer.schoolYearSettingKey)
        try writeWorkbook(rows, numericDate: false, to: url)
        let worker = MaterialWorker()
        try worker.open()
        try worker.selectFile(ScopedMaterialSelection(url), kind: .changes, control: AcquisitionControl())
        let library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite"))
        guard let record = library.state.record(for: .changes) else { throw ChangeParseError(code: .invalidArchive) }
        let view = try library.changeEditor(year: 2032)
        let edits = Dictionary(uniqueKeysWithValues: (3...92).map { ($0, ChangeRowEdit(excluded: true)) })
        try library.saveChangeEditor(view, year: 2032, expectedIdentity: record.source.selectionID ?? record.storedName,
            expectedDigest: record.digest, edits: edits, manual: true, check: {})
    }

    private static func writeWorkbook(_ rows: [[String]], numericDate: Bool, to url: URL) throws {
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"
        let sheet = rows.enumerated().map { index, cells in
            "<row r=\"\(index + 1)\">"
                + cells.enumerated().map { column, value in
                    if value.isEmpty { return "" }
                    let ref = String(UnicodeScalar(65 + column)!) + String(index + 1)
                    if numericDate && ref == "C3" { return "<c r=\"C3\"><v>46343</v></c>" }
                    return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(value)</t></is></c>"
                }.joined() + "</row>"
        }.joined()
        let entries = [
            "xl/workbook.xml":
                "<workbook xmlns=\"\(ns)\" xmlns:q=\"\(rel)\"><sheets><sheet name=\"時間割変更\" sheetId=\"1\" q:id=\"s1\"/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels":
                "<Relationships xmlns=\"\(pkg)\"><Relationship Id=\"s1\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
            "xl/worksheets/sheet1.xml":
                "<worksheet xmlns=\"\(ns)\"><sheetData>\(sheet)</sheetData></worksheet>",
        ]
        // Release the writer before the real provider/reader opens the archive.
        let archive = try Archive(url: url, accessMode: .create)
        for (path, text) in entries.sorted(by: { $0.key < $1.key }) {
            let data = Data(text.utf8)
            try archive.addEntry(
                with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate
            ) { position, size in
                data.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
    }
}
