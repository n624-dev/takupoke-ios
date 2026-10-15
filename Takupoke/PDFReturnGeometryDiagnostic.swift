import Foundation

/// Manually requested, text-free telemetry for ONE return-PDF lesson.
/// Only numbers / booleans are serializable; the target strings never leave
/// this recorder. No file names, hashes, text, images, recovery or persisted data.
final class PDFReturnGeometryRecorder {
    struct Rect: Codable, Equatable {
        let left: Double; let top: Double; let right: Double; let bottom: Double
        init(_ box: PDFBox) { left = box.left; top = box.top; right = box.right; bottom = box.bottom }
    }
    struct Glyph: Codable {
        let id: Int; let line: Int?; let order: Int?; let rect: Rect
    }
    struct Rule: Codable {
        let id: Int; let x1: Double; let y1: Double; let x2: Double; let y2: Double
    }
    struct Cell: Codable {
        let id: Int; let day: Int; let period: Int
        let original: Rect; let content: Rect
        let adoptedRows: [[Int]]
    }
    struct Snapshot: Codable {
        let formatVersion: Int; let parserVersion: Int; let page: Int
        let width: Double; let height: Double; let contentTop: Double
        let firstClass: Rect; let firstClassCell: Rect; let classLabel: Rect; let classCell: Rect; let gradeLabel: Rect
        let classRow: Int; let classLabelIDs: [Int]; let gradeLabelIDs: [Int]; let firstClassIDs: [Int]
        let periodHeadingIDs: [Int]; let contextGlyphs: [Glyph]; let rules: [Rule]
        var cells: [Cell]; var limited: Bool
    }
    static let marker = "TAKUPOKE-RETURN-POSITIONS-1"
    let className: String
    let date: String
    let period: Int
    private(set) var snapshot: Snapshot?
    private var glyphIDs: [PDFGlyph:[Int]] = [:]
    private var selectedIDs = Set<Int>()

    init(lesson: SpecialScheduleLesson) {
        className = lesson.sourceClassName ?? lesson.className
        date = lesson.date; period = lesson.period
    }
    func begin(page: PDFPageLayout, firstClass: PDFBox, firstClassCell: PDFBox, label: PDFBox, grade: PDFBox,
               row: PDFBox, original: PDFBox, classRow: Int, contentTop: Double, headings: [PDFGlyph], day: Int, periodXs: [Double]) {
        guard snapshot == nil else { return }
        glyphIDs = Dictionary(grouping:page.glyphs.indices,by:{ page.glyphs[$0] })
        let x = periodXs[period - 1]
        // Includes the header band and nearby rules, even if the current
        // contentTop incorrectly includes a heading. Never classifies text.
        let step = periodXs[1] - periodXs[0]
        let left = max(0, min(original.left, x - step * 2)), right = min(page.width, max(original.right, x + step * 2))
        let top = max(0, min(row.top, headings.map(\.y).min() ?? row.top) - step)
        let indices = page.glyphs.indices.filter {
            let g = page.glyphs[$0]
            return g.x <= right && g.x + g.width >= left && g.y <= row.bottom && g.y + g.height >= top
        }
        let headingIDs = headings.compactMap { glyphIDs[$0]?.first }
        func labelIDs(_ box: PDFBox) -> [Int] {
            page.glyphs.indices.filter {
                let g = page.glyphs[$0]
                return box.left <= g.cx && g.cx <= box.right && box.top <= g.cy && g.cy <= box.bottom
            }
        }
        let classIDs = labelIDs(label), gradeIDs = labelIDs(grade), firstIDs = labelIDs(firstClass)
        let candidates = headingIDs + classIDs + gradeIDs + firstIDs + indices
        var unique = Set<Int>(), ordered = [Int]()
        for id in candidates where unique.insert(id).inserted { ordered.append(id) }
        selectedIDs = Set(ordered.prefix(4096))
        let context = selectedIDs.sorted().map { i -> Glyph in
            let g = page.glyphs[i]
            return Glyph(id:i, line:g.sourceLine, order:g.sourceOrder,
                         rect:Rect(PDFBox(left:g.x,top:g.y,right:g.x+g.width,bottom:g.y+g.height)))
        }
        let nearby = page.lines.indices.filter {
            let r = page.lines[$0]
            return max(r.x1,r.x2) >= 0 && min(r.x1,r.x2) <= right &&
                max(r.y1,r.y2) >= top && min(r.y1,r.y2) <= row.bottom
        }
        let rules = nearby.prefix(4096).map { i -> Rule in
            let r = page.lines[i]; return Rule(id:i,x1:r.x1,y1:r.y1,x2:r.x2,y2:r.y2)
        }
        snapshot = Snapshot(formatVersion:1,parserVersion:SpecialScheduleAnalysis.parserVersion,page:1,
            width:page.width,height:page.height,contentTop:contentTop,firstClass:Rect(firstClass),firstClassCell:Rect(firstClassCell),
            classLabel:Rect(label),classCell:Rect(row),gradeLabel:Rect(grade),
            classRow:classRow,classLabelIDs:classIDs.filter { selectedIDs.contains($0) },
            gradeLabelIDs:gradeIDs.filter { selectedIDs.contains($0) },firstClassIDs:firstIDs.filter { selectedIDs.contains($0) },
            periodHeadingIDs:headingIDs,contextGlyphs:context,rules:rules,cells:[],
            limited:ordered.count > 4096 || nearby.count > 4096)
    }
    func record(box: PDFBox, content: PDFBox, rows: [[PDFGlyph]], day: Int, period: Int) {
        guard var current = snapshot else { return }
        guard current.cells.count < 32 else { current.limited = true; snapshot = current; return }
        var used: [PDFGlyph:Int] = [:], total = 0
        let ids = rows.prefix(64).map { row in row.prefix(max(0,4096-total)).compactMap { glyph -> Int? in
            total += 1
            let occurrence = used[glyph,default:0]; used[glyph] = occurrence + 1
            guard let matches = glyphIDs[glyph], occurrence < matches.count else { current.limited = true; return nil }
            return matches[occurrence]
        } }
        if rows.count > 64 || rows.reduce(0, { $0 + $1.count }) > 4096 { current.limited = true }
        if !Set(ids.flatMap { $0 }).isSubset(of:selectedIDs) { current.limited = true }
        current.cells.append(Cell(id:current.cells.count,day:day,period:period,
            original:Rect(box),content:Rect(content),adoptedRows:ids))
        snapshot = current
    }
    func report() -> String? {
        guard let snapshot, !snapshot.cells.isEmpty else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot), data.count <= 2 * 1024 * 1024,
              let body = String(data:data,encoding:.utf8) else { return nil }
        return Self.marker + "\n" + body
    }
}
