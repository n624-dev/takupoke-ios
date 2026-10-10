import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

enum SimulatorChangeRowSkipFixture {
    static func owns(_ url: URL) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("--change-row-skip"),
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
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"
        var rows = [
            ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
            ["1", "ZZ", "2032/7/10", "土", "1", "補講", "架空科目A"],
            ["1", "ZZ", "2032/7/11", "月", "2", "補講", "架空除外科目B"],
            ["", "", "", "火"],
            ["1", "ZZ", "2032/7/12", "月", "3", "補講", "架空科目C"],
        ]
        rows += Array(repeating:[],count:194)
        rows += Array(repeating:["","","","土"],count:101)
        let sheet = rows.enumerated().map { index, cells in
            "<row r=\"\(index + 1)\">"
                + cells.enumerated().map { column, value in
                    if value.isEmpty { return "" }
                    let ref = String(UnicodeScalar(65 + column)!) + String(index + 1)
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
        do {
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
}
