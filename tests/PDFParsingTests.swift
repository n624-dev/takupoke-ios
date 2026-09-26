import Foundation
import XCTest
import ZIPFoundation
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

final class PDFParsingTests: XCTestCase {
    // Construct new layouts from primitives, with no copied school cells or coordinates.
    func text(_ value: String, x: Double, y: Double, step: Double = 4) -> [PDFGlyph] {
        value.enumerated().map { PDFGlyph(text: String($0.element), x: x + Double($0.offset) * step, y: y - 3, width: step, height: 6) }
    }
    func h(_ y: Double, _ x1: Double = 10, _ x2: Double = 1100) -> PDFRule { PDFRule(x1: x1, y1: y, x2: x2, y2: y) }
    func v(_ x: Double, _ y1: Double = 60, _ y2: Double = 280) -> PDFRule { PDFRule(x1: x, y1: y1, x2: x, y2: y2) }
    func timetable() -> PDFPageLayout {
        var gs = text("令和14年度前期時間割", x: 200, y: 20)
        var lines = [60.0, 80, 100, 160, 220, 280].map { h($0) } + [20.0, 50, 100].map { v($0) }
        for i in 0..<40 {
            gs += text(String(i % 8 + 1), x: 108 + Double(i) * 20, y: 70)
            lines.append(v(100 + Double(i) * 20, 60, 80))
        }
        lines.append(v(900, 60, 80))
        for i in 0...20 { lines.append(v(100 + Double(i) * 40, 100, 280)) }
        for (grade, label, y) in [("1", "ZZ", 130.0), ("2", "YY", 190.0), ("AI", "3", 250.0)] {
            gs += text(grade, x: 30, y: y)
            gs += text(label, x: 70, y: y)
        }
        gs += text("架空科目Q", x: 104, y: 112)
        gs += text("架空教員Q", x: 104, y: 130)
        gs += text("架空室Q", x: 104, y: 148)
        gs += text("架空X・架空Y", x: 104, y: 172)
        gs += text("教員X・教員Y", x: 104, y: 190)
        gs += text("・架空室Y", x: 104, y: 208)
        gs += text("架空科目Z", x: 264, y: 232)
        return PDFPageLayout(width: 1100, height: 600, glyphs: gs, lines: lines)
    }
    func calendar(_ months: [Int], winter: Bool = true) -> PDFPageLayout {
        var gs = text("令和14年度行事予定表", x: 400, y: 20)
        gs += text("日", x: 18, y: 60)
        var lines = [h(40), h(70)]
        var arrows: [PDFArrow] = []
        for day in 1...31 {
            gs += text(String(day), x: day < 10 ? 18 : 16, y: 70 + Double(day) * 20 - 10)
            lines.append(h(70 + Double(day) * 20))
        }
        lines += [v(10, 40, 690), v(30, 40, 690)]
        for (i, month) in months.enumerated() {
            let x = 60 + Double(i) * 170
            gs += text("\(month)月", x: x + 40, y: 47)
            gs += text("共通", x: x + 12, y: 60)
            gs += text("高松", x: x + 52, y: 60)
            gs += text("詫間", x: x + 92, y: 60)
            lines += [x, x + 40, x + 80, x + 120].map { v($0, 40, 690) }
            gs += text("架空行事\(month)", x: x + 2, y: 100)
            gs += text("架空対象外", x: x + 42, y: 120)
            gs += text("架空交流会", x: x + 82, y: 140)
            gs += text("9", x: x + 115, y: 160) // Teaching-week counter, not an event.
            if month == 6 {
                gs += text("夏季休業(6/19まで)", x: x + 2, y: 260, step: 2)
            }
            if winter && month == 12 {
                gs += text("冬季休業", x: x + 2, y: 560)
                arrows.append(PDFArrow(x: x + 30, top: 555, bottom: 680))
            }
            if winter && month == 1 { arrows.append(PDFArrow(x: x + 30, top: 72, bottom: 150)) }
        }
        return PDFPageLayout(width: 1100, height: 800, glyphs: gs, lines: lines, arrows: arrows)
    }
    func parse(_ pages: [PDFPageLayout], kind: MaterialKind) throws -> PDFAnalysis {
        try PDFSchoolParser.parse(pages, kind: kind, digest: "synthetic-digest", name: "synthetic.pdf")
    }
}
