import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

extension SpecialScheduleTests {
    func examPage(_ number: Int, omitLastTime: Bool = false,
                          mergedFirstTwo: Bool = false,
                          metadataOnFirstCell: Bool = false) -> PDFPageLayout {
        var glyphs: [PDFGlyph] = []
        var lines: [PDFRule] = []
        var sourceLine = 0
        var order = 0
        func write(_ value: String, x: Double, y: Double, step: Double = 4) {
            for (index, character) in value.enumerated() {
                glyphs.append(PDFGlyph(text: String(character), x: x + Double(index) * step,
                                       y: y, width: step, height: 8,
                                       sourceLine: sourceLine, sourceOrder: order))
                order += 1
            }
            sourceLine += 1
        }
        let columns = number == 6 ? 2 : 3
        let labels: [String]
        switch number {
        case 1: labels = ["1-1", "1-2", "1-3"]
        case 2: labels = ["2-CN", "2-ES", "2-IT"]
        case 3: labels = ["3-CN", "3-ES", "3-IT"]
        case 4: labels = ["4-CN", "4-ES", "4-IT"]
        case 5: labels = ["5-CN", "5-ES", "5-IT"]
        default: labels = ["1年", "2年"]
        }
        write("令和8年度 試験時間割", x: 20, y: 20)
        for column in 0..<columns {
            write(labels[column], x: 200 + Double(column) * 240, y: 70)
            for period in 0..<6 {
                write("\(period + 1)", x: 118 + Double(column * 6 + period) * 40, y: 100)
            }
        }
        for index in 0...columns * 6 {
            let x = 100 + Double(index) * 40
            lines.append(PDFRule(x1: x, y1: mergedFirstTwo && index == 1 ? 150 : 110,
                                 x2: x, y2: 350))
        }
        lines.append(PDFRule(x1: 0, y1: 110, x2: 0, y2: 350))
        for index in 0...6 {
            let y = 110 + Double(index) * 40
            lines.append(PDFRule(x1: 0, y1: y, x2: 100 + Double(columns * 6) * 40, y2: y))
        }
        for index in 0..<5 {
            write("4月\(index + 1)日", x: 16, y: 126 + Double(index) * 40)
            for column in 0..<columns {
                write("架空科目A", x: 106 + Double(column) * 240,
                      y: 126 + Double(index) * 40, step: 6)
            }
            if metadataOnFirstCell && index == 0 {
                write("架空教員A", x: 106, y: 136, step: 5)
                write("架空教室A", x: 106, y: 145, step: 5)
            }
        }
        let times = ["8:50~9:35", "9:50~10:35", "10:50~11:35",
                     "11:50~12:35", "13:20~14:05", "14:20~15:05"]
        for (index, time) in times.enumerated() where !omitLastTime || index != 5 {
            write("\(index + 1)時限目\(time)", x: 20, y: 470 + Double(index) * 15)
        }
        write("1・2時限連続8:50~10:20", x: 300, y: 470)
        return PDFPageLayout(width: 850, height: 600, glyphs: glyphs, lines: lines)
    }

    func returnPageWithSplitCell() -> PDFPageLayout {
        var glyphs: [PDFGlyph] = []
        var lines: [PDFRule] = []
        func write(_ value: String, x: Double, y: Double, step: Double = 4) {
            for (index, character) in value.enumerated() {
                glyphs.append(PDFGlyph(text: String(character), x: x + Double(index) * step,
                                       y: y, width: step, height: 4))
            }
        }
        write("令和8年度 試験返却時間割", x: 20, y: 20)
        for day in 0..<5 {
            write("4/\(day + 1)", x: 150 + Double(day * 8) * 40, y: 70)
            for period in 0..<8 {
                write("\(period + 1)", x: 150 + Double(day * 8 + period) * 40, y: 100)
            }
        }
        let classGroups: [(String, [String])] = [
            ("1", ["1", "2", "3"]), ("2", ["CN", "ES", "IT"]),
            ("3", ["CN", "ES", "IT"]), ("4", ["CN", "ES", "IT"]),
            ("5", ["CN", "ES", "IT"]), ("AI", ["1", "2"]),
        ]
        var rowIndex = 0
        for (grade, classes) in classGroups {
            write(grade, x: 30, y: 132 + Double(rowIndex + classes.count / 2) * 25)
            for className in classes {
                write(className, x: 124, y: 132 + Double(rowIndex) * 25)
                rowIndex += 1
            }
        }
        for index in 0...40 {
            let x = 140 + Double(index) * 40
            lines.append(PDFRule(x1: x, y1: index == 5 || index == 13 ? 145 : 110,
                                 x2: x, y2: 545))
        }
        lines.append(PDFRule(x1: 110, y1: 110, x2: 110, y2: 545))
        for index in 0...17 {
            let y = 120 + Double(index) * 25
            lines.append(PDFRule(x1: 0, y1: y, x2: 1740, y2: y))
        }
        // Two independent lessons in the same 3-IT period cell, divided by a
        // short horizontal rule. Names are fictional and unrelated to the PDF.
        lines.append(PDFRule(x1: 220, y1: 332.5, x2: 260, y2: 332.5))
        write("架空科目A", x: 222, y: 322, step: 3)
        write("架空教員A", x: 222, y: 327, step: 3)
        write("架空科目B", x: 222, y: 335, step: 3)
        write("架空教員B", x: 222, y: 340, step: 3)
        write("架空科目C", x: 502, y: 322, step: 3)
        write("架空科目D", x: 302, y: 130, step: 3)
        write("架空科目E", x: 622, y: 130, step: 3)
        write("4月1日の時間割は以下のとおりです。", x: 1300, y: 650)
        write("4月2日~5日は通常の授業日どおりの授業時間です。", x: 1300, y: 670)
        let times = ["7:00~7:40", "7:50~8:30", "8:40~9:20", "9:30~10:10",
                     "10:30~11:10", "11:10~11:50", "12:00~12:40", "12:40~13:20"]
        for (index, time) in times.enumerated() {
            write("\(index + 1)時限目\(time)", x: 20, y: 760 + Double(index + 1) * 15)
        }
        return PDFPageLayout(width: 1800, height: 1000, glyphs: glyphs, lines: lines)
    }
}
