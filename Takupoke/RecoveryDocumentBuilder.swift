import Foundation

/// Binds physical table cells and original text before any language model runs.
/// A layout without independent class/date/period and field boundaries fails.
enum RecoveryDocumentBuilder {
    private struct Heading { var text: String; var glyphs: [PDFGlyph]; var box: RecoveryBox }
    private static func box(_ glyphs: [PDFGlyph]) throws -> RecoveryBox {
        guard !glyphs.isEmpty else { throw PDFParseError(code: .ambiguous) }
        let x = glyphs.map(\.x).min()!, y = glyphs.map(\.y).min()!
        return RecoveryBox(x: x, y: y, width: glyphs.map { $0.x + $0.width }.max()! - x,
                           height: glyphs.map { $0.y + $0.height }.max()! - y)
    }
    private static func rect(_ b: PDFBox) -> RecoveryBox { .init(x: b.left, y: b.top, width: b.right-b.left, height: b.bottom-b.top) }
    private static func headings(_ glyphs: [PDFGlyph]) -> [Heading] {
        PDFGrid.rows(glyphs).flatMap { row -> [Heading] in
            var groups: [[PDFGlyph]] = []
            for glyph in row {
                if let last = groups.last?.last, glyph.x - last.x - last.width > max(2, min(last.height, glyph.height) * 0.55) { groups.append([]) }
                if groups.isEmpty { groups.append([]) }
                groups[groups.count-1].append(glyph)
            }
            return groups.compactMap { group in (try? box(group)).map { Heading(text: group.map(\.text).joined(), glyphs: group, box: $0) } }
        }
    }
    static func build(_ pages: [PDFPageLayout], kind: RecoveryDocumentKind, hash: String,
                      fromOCR: Set<Int> = [], rasters: [Int:RecoveryRasterGrid] = [:], check: () throws -> Void = {}) throws -> RecoveryDocument {
        guard (1...12).contains(pages.count), pages.allSatisfy({ $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0 && $0.glyphs.count <= 100000 }) else { throw PDFParseError(code: .limit) }
        var doc = RecoveryDocument(pdfHash: hash, kind: kind, schoolYear: 0, term: nil, classes: [], days: [], requiredSlots: [], cells: [], sources: [], complete: true, yearEvidence: [], termEvidence: [], dayEvidence: [:], classEvidence: [:], periodEvidence: [:], times: [:], timeEvidence: [], normalTimeNoteEvidence: [])
        let count = kind == .exam ? 6 : 8
        var sourceNumber = 0
        for (pageIndex, page) in pages.enumerated() {
            try check()
            let number = pageIndex + 1, grid = PDFGrid(page: page)
            var used: Set<Int> = []
            func add(_ glyphs: [PDFGlyph], owner: String = "", value: String? = nil) throws -> String {
                guard !glyphs.isEmpty else { throw PDFParseError(code: .ambiguous) }
                let indices = page.glyphs.indices.filter { i in glyphs.contains { g in g.text == page.glyphs[i].text && g.x == page.glyphs[i].x && g.y == page.glyphs[i].y && g.sourceOrder == page.glyphs[i].sourceOrder } }
                guard indices.count == glyphs.count, indices.allSatisfy({ !used.contains($0) }) else { throw PDFParseError(code: .ambiguous, page: number, stage: .textOrder) }
                used.formUnion(indices); sourceNumber += 1
                let id = "p\(number)-s\(sourceNumber)"
                doc.sources.append(RecoverySource(id: id, cellId: owner, page: number, text: value ?? glyphs.map(\.text).joined(), box: try box(glyphs), fromOcr: fromOCR.contains(number)))
                return id
            }
            func region(_ b: RecoveryBox, axis: RecoveryHeaderAxis) -> RecoveryHeaderRegion { .init(page: number, box: b, axis: axis) }
            let headingRows = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 3 })
            var yearFound = false
            for row in headingRows {
                let raw = row.map(\.text).joined()
                if let range = raw.range(of: "(?:令和[0-9]{1,2}|[0-9]{4})年度", options: .regularExpression) {
                    let token = String(raw[range]), era = token.hasPrefix("令和")
                    guard let value = Int(era ? token.dropFirst(2).dropLast(2) : token.dropLast(2)) else { throw PDFParseError(code: .ambiguous) }
                    let year = era ? value + 2018 : value
                    guard doc.schoolYear == 0 || doc.schoolYear == year else { throw PDFParseError(code: .ambiguous, stage: .yearHeading) }
                    doc.schoolYear = year; yearFound = true
                    let first = raw.distance(from: raw.startIndex, to: range.lowerBound), last = raw.distance(from: raw.startIndex, to: range.upperBound)
                    guard row.allSatisfy({ $0.text.count == 1 }), last <= row.count else { throw PDFParseError(code: .ambiguous) }
                    doc.yearEvidence.append(try add(Array(row[first..<last])))
                }
                if kind == .timetable {
                    for term in ["前期", "後期"] where raw.contains(term) {
                        guard doc.term == nil || doc.term == term, let range = raw.range(of: term) else { throw PDFParseError(code: .ambiguous, stage: .documentHeading) }
                        doc.term = term
                        let first = raw.distance(from: raw.startIndex, to: range.lowerBound)
                        guard row.allSatisfy({ $0.text.count == 1 }), first + term.count <= row.count else { throw PDFParseError(code: .ambiguous, stage: .documentHeading) }
                        doc.termEvidence.append(try add(Array(row[first..<(first+term.count)])))
                    }
                }
            }
            guard yearFound else { throw PDFParseError(code: .unsupported, stage: .yearHeading) }
            let sequence = String((1...count).map(String.init).joined())
            let periodRows = headingRows.filter { row in
                let raw = PDFSchoolParser.key(row.map(\.text).joined())
                return !raw.isEmpty && raw.count % count == 0 && raw == String(repeating: sequence, count: raw.count/count)
            }
            guard periodRows.count == 1, let periodRow = periodRows.first, periodRow.count % count == 0 else { throw PDFParseError(code: .unsupported, stage: .periodHeading) }
            let groups = periodRow.count / count
            guard kind == .exam || groups == 5 else { throw PDFParseError(code: .unsupported) }
            var periodIds = [String](); var periodBoxes = [RecoveryBox]()
            for (index, glyph) in periodRow.enumerated() {
                let id = try add([glyph]); periodIds.append(id); periodBoxes.append(try box([glyph]))
                doc.periodEvidence[String(index % count + 1), default: []].append(id)
            }
            let headerY = periodRow[0].cy
            struct AxisItem { var value: String; var ids: [String]; var region: RecoveryHeaderRegion; var position: Double; var row: PDFBox? }
            var horizontal = [AxisItem](), vertical = [AxisItem]()
            if kind == .exam {
                let labels = headings(page.glyphs.filter { $0.cy < headerY - 3 && $0.cy > headerY - page.height / 8 }).filter { h in
                    let t = PDFSchoolParser.key(h.text)
                    return t.range(of: "^(?:[1-5][_-](?:[1-3]|CN|ES|IT)|[12]年)$", options: .regularExpression) != nil
                }.sorted { $0.box.x < $1.box.x }
                guard labels.count == groups else { throw PDFParseError(code: .unsupported, stage: .classLabel) }
                for h in labels {
                    let t = PDFSchoolParser.key(h.text), cls = t.hasSuffix("年") ? "AI_" + t.prefix(1) : t.replacingOccurrences(of: "-", with: "_")
                    let id = try add(h.glyphs)
                    let group = horizontal.count, xs = Array(periodRow[(group*count)..<((group+1)*count)]).map(\.cx), step = xs.count > 1 ? xs[1]-xs[0] : 0
                    let band = RecoveryBox(x:xs[0]-step/2,y:h.box.y,width:xs.last!-xs[0]+step,height:h.box.height)
                    guard band.contains(h.box) else { throw PDFParseError(code:.ambiguous) }
                    horizontal.append(AxisItem(value: cls, ids: [id], region: region(band, axis: .above), position: h.box.x+h.box.width/2))
                    doc.classEvidence[cls, default: []].append(id)
                }
                let dates = headings(page.glyphs.filter { $0.cy > headerY && $0.cx < periodRow[0].cx }).compactMap { h -> (Heading, SchoolDate)? in
                    SpecialScheduleParser.date(PDFSchoolParser.key(h.text), schoolYear: doc.schoolYear, slash: false).map { (h,$0) }
                }
                guard dates.count == 5 else { throw PDFParseError(code: .unsupported, stage: .calendarDates) }
                for (h,date) in dates {
                    let id = try add(h.glyphs), r = try grid.box(h.box.x+h.box.width/2,h.box.y+h.box.height/2)
                    vertical.append(AxisItem(value: date.iso8601, ids: [id], region: region(h.box, axis: .left), position: h.box.y+h.box.height/2, row: r))
                    doc.dayEvidence[date.iso8601, default: []].append(id)
                }
            } else {
                let labels = headings(page.glyphs.filter { $0.cy < headerY - 2 && $0.cy > headerY - page.height / 8 }).compactMap { h -> (Heading,String)? in
                    let t = PDFSchoolParser.key(h.text)
                    if kind == .return { return SpecialScheduleParser.date(t, schoolYear: doc.schoolYear, slash: true).map { (h,$0.iso8601) } }
                    return ["月":"1","火":"2","水":"3","木":"4","金":"5"][t.replacingOccurrences(of:"曜日",with:"").replacingOccurrences(of:"曜",with:"")].map { (h,$0) }
                }.sorted { $0.0.box.x < $1.0.box.x }
                guard labels.count == 5 else { throw PDFParseError(code: .unsupported, stage: .calendarDates) }
                for (h,day) in labels {
                    let id = try add(h.glyphs)
                    let group = horizontal.count, xs = Array(periodRow[(group*count)..<((group+1)*count)]).map(\.cx), step = xs[1]-xs[0]
                    let band = RecoveryBox(x:xs[0]-step/2,y:h.box.y,width:xs.last!-xs[0]+step,height:h.box.height)
                    guard band.contains(h.box) else { throw PDFParseError(code:.ambiguous) }
                    horizontal.append(AxisItem(value: day, ids: [id], region: region(band, axis: .above), position: h.box.x+h.box.width/2))
                    doc.dayEvidence[day, default: []].append(id)
                }
                let first: PDFBox
                if kind == .return {
                    let step = periodRow[1].cx-periodRow[0].cx
                    guard step > 5 else { throw PDFParseError(code:.ambiguous) }
                    first = PDFBox(left:periodRow[0].cx-step/2,top:0,right:periodRow[0].cx+step/2,bottom:headerY+2)
                } else { first = try grid.box(periodRow[0].cx,periodRow[0].cy) }
                let classBox = try grid.box(first.left-2, first.bottom+20)
                guard let bottom = page.lines.filter({ $0.vertical && abs($0.x1-classBox.right)<0.3 }).map(\.y2).max() else { throw PDFParseError(code:.unsupported) }
                let rows = PDFGrid.rows(page.glyphs.filter { classBox.left < $0.cx && $0.cx < classBox.right && $0.cy > first.bottom && $0.cy < bottom })
                var gradeSources = [PDFBox:(String,[PDFGlyph])]()
                let grades = headings(page.glyphs.filter { $0.cx < classBox.left && $0.cy > headerY && $0.cy < bottom }).filter { PDFSchoolParser.key($0.text).range(of:"^(?:[1-5]|AI)$",options:.regularExpression) != nil }.sorted { $0.box.y < $1.box.y }
                for row in rows {
                    let y = row.map(\.cy).reduce(0,+)/Double(row.count)
                    let gradeBox: PDFBox, gradeGlyphs: [PDFGlyph]
                    if let physical = try? grid.box(classBox.left-2,y) {
                        gradeBox = physical; gradeGlyphs = grid.glyphs(in:physical)
                    } else {
                        guard kind == .return, grades.count == 6, rows.count == 17,
                              let gradeIndex = grades.indices.min(by:{ abs(grades[$0].box.y+grades[$0].box.height/2-y) < abs(grades[$1].box.y+grades[$1].box.height/2-y) }) else { throw PDFParseError(code:.unsupported,stage:.gradeLabel) }
                        let members = rows.filter { candidate in
                            let cy = candidate.map(\.cy).reduce(0,+)/Double(candidate.count)
                            return grades.indices.min(by:{ abs(grades[$0].box.y+grades[$0].box.height/2-cy) < abs(grades[$1].box.y+grades[$1].box.height/2-cy) }) == gradeIndex
                        }
                        let group = try members.map { try grid.box($0[0].cx,$0.map(\.cy).reduce(0,+)/Double($0.count)) }
                        guard members.count == (PDFSchoolParser.key(grades[gradeIndex].text) == "AI" ? 2:3), let top = group.map(\.top).min(), let bottom = group.map(\.bottom).max(),
                              grades[gradeIndex].box.y >= top && grades[gradeIndex].box.y+grades[gradeIndex].box.height <= bottom else { throw PDFParseError(code:.ambiguous,stage:.gradeLabel) }
                        gradeBox = PDFBox(left:0,top:top,right:classBox.left,bottom:bottom); gradeGlyphs = grades[gradeIndex].glyphs
                    }
                    let grade = PDFSchoolParser.key(gradeGlyphs.map(\.text).joined()), label = PDFSchoolParser.key(row.map(\.text).joined())
                    let cls = grade + "_" + label
                    guard RecoveryValidator.knownClasses.contains(cls) else { throw PDFParseError(code:.ambiguous,stage:.classLabel) }
                    // Grade cells are merged. Split their original text once into a
                    // structural source, and reference it from all relevant classes.
                    if gradeSources[gradeBox] == nil { gradeSources[gradeBox] = (try add(gradeGlyphs), gradeGlyphs) }
                    let labelId = try add(row), gradeId = gradeSources[gradeBox]!.0
                    var classRow = try grid.box((classBox.left+classBox.right)/2,y)
                    classRow.top = max(classRow.top,try grid.box(periodRow[0].cx,y).top)
                    let combined = RecoveryBox(x: gradeBox.left,y: gradeBox.top,width: classBox.right-gradeBox.left,height: gradeBox.bottom-gradeBox.top)
                    vertical.append(AxisItem(value:cls,ids:[gradeId,labelId],region:region(combined,axis:.left),position:y,row:classRow))
                    doc.classEvidence[cls,default:[]] += [gradeId,labelId]
                }
            }
            // Build logical cells, preserving short horizontal divisions as parallel lessons.
            for v in vertical {
                guard let row = v.row else { throw PDFParseError(code:.unsupported) }
                for (group,h) in horizontal.enumerated() {
                    let centers = Array(periodRow[(group*count)..<((group+1)*count)]).map(\.cx)
                    var seen: Set<PDFBox> = []
                    for (periodIndex,x) in centers.enumerated() {
                        try check()
                        let main = try grid.box(x,v.position)
                        guard seen.insert(main).inserted else { continue }
                        let covered = centers.indices.filter { main.left < centers[$0] && centers[$0] < main.right }.map { $0+1 }
                        guard !covered.isEmpty else { throw PDFParseError(code:.ambiguous) }
                        let cuts = Set(page.lines.filter { $0.horizontal && $0.x1 <= x && x <= $0.x2 && row.top+1 < $0.y1 && $0.y1 < row.bottom-1 }.map(\.y1)).sorted()
                        let edges = [row.top]+cuts+[row.bottom]
                        let sub = try (0..<(edges.count-1)).map { try grid.box(x,(edges[$0]+edges[$0+1])/2) }
                        let logical = PDFBox(left: main.left,top: row.top,right: main.right,bottom:row.bottom)
                        let cls = kind == .exam ? h.value : v.value, day = kind == .exam ? v.value : h.value
                        let id = "cell-\(number)-\(doc.cells.count)"
                        var cell = RecoveryCell(id:id,page:number,box:rect(logical),inputState:.complete,slots:covered.map { RecoverySlot(className:cls,day:day,period:$0) },sourceIds:[],blankFields:[],classHeaderIds:kind == .exam ? h.ids : v.ids,dayHeaderIds:kind == .exam ? v.ids : h.ids,classRegion:kind == .exam ? h.region : v.region,dayRegion:kind == .exam ? v.region : h.region)
                        for p in covered {
                            let index = group*count+p-1
                            cell.periodHeaderIds.append(periodIds[index]); cell.periodRegions[String(p)] = region(periodBoxes[index],axis:.above)
                        }
                        var bindings = [RecoveryLessonBinding]()
                        for subBox in Set(sub).sorted(by: { $0.top < $1.top }) {
                            let glyphs = grid.glyphs(in:subBox)
                            if glyphs.isEmpty { continue }
                            let rows = try PDFGrid.contentRows(glyphs)
                            let lines = try grid.timetableText(subBox)
                            let labeled = rows.compactMap { r -> (RecoveryRole,[PDFGlyph],[PDFGlyph])? in
                                let t = r.map(\.text).joined()
                                guard r.allSatisfy({ $0.text.count == 1 }) else { return nil }
                                for role in RecoveryRole.allCases {
                                    for label in role.labels {
                                        for suffix in [":","："] where t.hasPrefix(label+suffix) {
                                            return (role,Array(r.prefix(label.count+1)),Array(r.dropFirst(label.count+1)))
                                        }
                                    }
                                }
                                return nil
                            }
                            if labeled.count == 3, Set(labeled.map { $0.0 }).count == 3 {
                                guard bindings.isEmpty else { throw PDFParseError(code:.ambiguous) }
                                cell.bindingMode = .roleProposal
                                let lessonIndex = cell.roleScopes.count/3
                                let sorted = labeled.sorted { $0.1[0].y < $1.1[0].y }
                                for (i,item) in sorted.enumerated() {
                                    let labelId = try add(item.1,owner:id); cell.sourceIds.append(labelId)
                                    let labelBox = try box(item.1)
                                    let top = i == 0 ? subBox.top : (try box(sorted[i-1].1).y + labelBox.y)/2
                                    let bottom = i == 2 ? subBox.bottom : (labelBox.y + (try box(sorted[i+1].1)).y)/2
                                    let scope = RecoveryBox(x:labelBox.x+labelBox.width,y:top,width:subBox.right-labelBox.x-labelBox.width,height:bottom-top)
                                    if !item.2.isEmpty { cell.sourceIds.append(try add(item.2,owner:id)) } else { cell.blankFields.append(item.0.rawValue) }
                                    cell.roleScopes.append(RecoveryRoleScope(lessonIndex:lessonIndex,role:item.0,page:number,box:scope,labelSourceIds:[labelId],labelRegion:region(labelBox,axis:.left),proof:.inlineLabel,emptyVerified:item.2.isEmpty && (!fromOCR.contains(number) || rasters[number]?.isBlank(scope,rules:page.lines) == true)))
                                }
                            } else {
                                guard cell.bindingMode == .fixed, !rows.contains(where:{ RecoveryRole.hasLabelPrefix($0.map(\.text).joined()) }) else { throw PDFParseError(code:.ambiguous,stage:.lessonLines) }
                                let fields = try grid.lessonFields(subBox,lines:lines)
                                let parallel = fields.allSatisfy { $0.replacingOccurrences(of:"･",with:"・").components(separatedBy:"・").count == 2 }
                                if parallel {
                                    guard rows.count == 3, Set(sub).count == 1, rows.allSatisfy({ $0.filter { ["・","･"].contains($0.text) }.count == 1 }) else { throw PDFParseError(code:.ambiguous,stage:.parallelLessons) }
                                    var variants = [RecoveryLessonBinding(subject:[],teacher:[],room:[]),RecoveryLessonBinding(subject:[],teacher:[],room:[])]
                                    for (row,role) in zip(rows,RecoveryRole.allCases) {
                                        let separator = row.firstIndex { ["・","･"].contains($0.text) }!
                                        let sepId = try add([row[separator]],owner:id); cell.sourceIds.append(sepId); cell.parallelSeparators[role.rawValue] = sepId
                                        for variant in 0...1 {
                                            let part = variant == 0 ? Array(row[..<separator]) : Array(row[(separator+1)...])
                                            let ids = part.isEmpty ? [] : [try add(part,owner:id)]
                                            cell.sourceIds += ids
                                            if ids.isEmpty && role == .subject { throw PDFParseError(code:.ambiguous,stage:.emptySubject) }
                                            if ids.isEmpty { cell.blankFields.append(role.rawValue) }
                                            switch role { case .subject: variants[variant].subject = ids; case .teacher: variants[variant].teacher = ids; case .room: variants[variant].room = ids }
                                        }
                                    }
                                    bindings += variants
                                    continue
                                }
                                guard rows.count == lines.count else { throw PDFParseError(code:.ambiguous,stage:.fragmentAlignment) }
                                var ids = [[String]](repeating:[],count:3)
                                var offset = 0
                                for i in fields.indices where !fields[i].isEmpty {
                                    guard offset < rows.count, rows[offset].map(\.text).joined() == fields[i] else { throw PDFParseError(code:.ambiguous) }
                                    let source = try add(rows[offset],owner:id); ids[i] = [source]; cell.sourceIds.append(source); offset += 1
                                }
                                bindings.append(RecoveryLessonBinding(subject:ids[0],teacher:ids[1],room:ids[2]))
                                if ids[1].isEmpty { cell.blankFields.append("teacher") }; if ids[2].isEmpty { cell.blankFields.append("room") }
                            }
                        }
                        cell.lessonBindings = bindings
                        cell.confirmedEmpty = cell.sourceIds.isEmpty && (!fromOCR.contains(number) || rasters[number]?.isBlank(cell.box,rules:page.lines) == true)
                        cell.parallelCount = max(1,cell.bindingMode == .fixed ? bindings.count : cell.roleScopes.count/3)
                        guard cell.confirmedEmpty || !cell.sourceIds.isEmpty else { throw PDFParseError(code:.ambiguous) }
                        if fromOCR.contains(number) {
                            guard let raster = rasters[number], !raster.hasUncoveredInk(cell.box,text:try grid.glyphs(in:logical).map { try box([$0]) },rules:page.lines) else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
                        }
                        doc.cells.append(cell)
                        _ = periodIndex
                    }
                }
            }
            if kind != .timetable {
                let remaining = PDFGrid.rows(page.glyphs.indices.filter { !used.contains($0) }.map { page.glyphs[$0] })
                let pageDays = (kind == .exam ? vertical : horizontal).map(\.value).sorted()
                func extract(_ token: String, row: [PDFGlyph]) throws -> [PDFGlyph] {
                    let raw = row.map(\.text).joined()
                    guard row.allSatisfy({ $0.text.count == 1 }), let r = raw.range(of:token) else { throw PDFParseError(code:.ambiguous) }
                    let start = raw.distance(from:raw.startIndex,to:r.lowerBound)
                    return Array(row[start..<(start+token.count)])
                }
                let scopeToken: String
                if kind == .exam { scopeToken = "試験時間割" }
                else {
                    let bits = pageDays[0].split(separator:"-").compactMap { Int($0) }
                    guard bits.count == 3 else { throw PDFParseError(code:.ambiguous) }
                    scopeToken = "\(bits[1])月\(bits[2])日の時間割は以下のとおりです。"
                }
                guard let scopeRow = remaining.first(where: { $0.map(\.text).joined().contains(scopeToken) }) else { throw PDFParseError(code:.unsupported,stage:.periodHeading) }
                let scopeGlyphs = try extract(scopeToken,row:scopeRow), scopeId = try add(scopeGlyphs)
                doc.commonClockEvidence.append(scopeId); doc.commonClockRegions[String(number)] = region(try box(scopeGlyphs),axis:.above)
                var clocks = [Int:(String,String,RecoveryClockBinding)](), spans = [String:(String,String,RecoveryClockBinding)]()
                let pattern = try NSRegularExpression(pattern:"([1-8](?:[・･][1-8]時限連続|時限目))([0-9]{1,2}:[0-9]{2})[~〜～]([0-9]{1,2}:[0-9]{2})")
                for row in remaining {
                    let raw = row.map(\.text).joined(), ns = raw as NSString
                    for match in pattern.matches(in:raw,range:NSRange(location:0,length:ns.length)) {
                        let label = ns.substring(with:match.range(at:1)), token = ns.substring(with:NSRange(location:match.range(at:2).location,length:match.range(at:3).upperBound-match.range(at:2).location))
                        let labelGlyphs = try extract(label,row:row), clockGlyphs = try extract(token,row:row)
                        let labelId = try add(labelGlyphs), clockId = try add(clockGlyphs)
                        let p = Int(label.prefix(1))!, end = label.contains("連続") ? Int(label.dropFirst(2).prefix(1))! : p
                        let numbers = [ns.substring(with:match.range(at:2)),ns.substring(with:match.range(at:3))].map { $0.split(separator:":").compactMap { Int($0) } }
                        guard p <= count, end <= count, numbers.allSatisfy({ $0.count == 2 && (0...23).contains($0[0]) && (0...59).contains($0[1]) }) else { throw PDFParseError(code:.ambiguous) }
                        let value = numbers.map { String(format:"%02d:%02d",$0[0],$0[1]) }.joined(separator:"〜")
                        let binding = RecoveryClockBinding(page:number,box:try box(clockGlyphs),day:"",spanStart:p,spanEnd:end,dayHeaderIds:[],dayRegion:nil,periodHeaderIds:[labelId],periodRegion:region(try box(labelGlyphs),axis:.left),commonScope:true)
                        if p == end {
                            guard clocks[p] == nil else { throw PDFParseError(code:.ambiguous) }
                            clocks[p] = (value,clockId,binding); doc.periodEvidence[String(p),default:[]].append(labelId)
                        } else {
                            guard p < end, spans["\(p)-\(end)"] == nil else { throw PDFParseError(code:.ambiguous) }
                            spans["\(p)-\(end)"] = (value,clockId,binding)
                        }
                        if p == end { doc.timeEvidence.append(clockId) }
                    }
                }
                guard clocks.count == count else { throw PDFParseError(code:.unsupported,stage:.periodHeading) }
                if kind == .return {
                    let noteRows = remaining.filter { row in let t = row.map(\.text).joined(); return t.contains("通常の授業日どおりの授業時間") }
                    guard noteRows.count == 1 else { throw PDFParseError(code:.ambiguous) }
                    let noteId = try add(noteRows[0]); doc.normalTimeNoteEvidence += [scopeId,noteId]
                }
                for day in pageDays {
                    for p in 1...count {
                        let key = "\(day):\(p)", (value,clockId,template) = clocks[p]!
                        if kind == .return && day != pageDays.first {
                            doc.times[key] = TimetableSchedule.normalPeriodTimes[p-1]; doc.clockEvidence[key] = doc.normalTimeNoteEvidence
                        } else {
                            guard doc.times[key] == nil || doc.times[key] == value else { throw PDFParseError(code:.ambiguous) }
                            doc.times[key] = value; doc.clockEvidence[key,default:[]].append(clockId)
                            var b = template; b.day = day
                            // Every page's repeated chart is separately bounded; all
                            // chart values are required to agree before selecting one.
                            if doc.clockBindings[key] == nil { doc.clockBindings[key] = b } else { doc.clockReplicas[key,default:[]].append(b) }
                        }
                    }
                }
                let requiredSpans = doc.cells.filter { $0.page == number && $0.slots.count > 1 }
                for cell in requiredSpans {
                    let periods = cell.slots.map(\.period).sorted(), day = cell.slots[0].day, suffix = "\(periods.first!)-\(periods.last!)", key = "\(day):\(suffix)"
                    if spans[suffix] == nil || kind == .return && day != pageDays.first {
                        let first = periods.first!, last = periods.last!
                        guard let firstTime = doc.times["\(day):\(first)"], let lastTime = doc.times["\(day):\(last)"] else { throw PDFParseError(code:.ambiguous) }
                        let ids = Array(Set(doc.clockEvidence["\(day):\(first)",default:[]] + doc.clockEvidence["\(day):\(last)",default:[]])).sorted { a,b in doc.sources.firstIndex { $0.id == a }! < doc.sources.firstIndex { $0.id == b }! }
                        let sourceBoxes = doc.sources.filter { ids.contains($0.id) }.map(\.box)
                        guard !sourceBoxes.isEmpty, Set(doc.sources.filter { ids.contains($0.id) }.map(\.page)).count == 1 else { throw PDFParseError(code:.ambiguous) }
                        let x = sourceBoxes.map(\.x).min()!, y = sourceBoxes.map(\.y).min()!
                        let b = RecoveryBox(x:x,y:y,width:sourceBoxes.map { $0.x+$0.width }.max()!-x,height:sourceBoxes.map { $0.y+$0.height }.max()!-y)
                        doc.spanTimes[key] = firstTime.components(separatedBy:"〜").first!+"〜"+lastTime.components(separatedBy:"〜").last!
                        doc.clockEvidence[key] = ids
                        doc.clockBindings[key] = RecoveryClockBinding(page:doc.sources.first { ids.contains($0.id) }!.page,box:b,day:day,spanStart:first,spanEnd:last,dayHeaderIds:[],dayRegion:nil,periodHeaderIds:[],periodRegion:region(b,axis:.above),derivedSpan:true)
                        continue
                    }
                    let (value,clockId,template) = spans[suffix]!
                    guard doc.spanTimes[key] == nil || doc.spanTimes[key] == value else { throw PDFParseError(code:.ambiguous) }
                    doc.spanTimes[key] = value
                    if !doc.clockEvidence[key,default:[]].contains(clockId) { doc.clockEvidence[key,default:[]].append(clockId) }
                    if !doc.timeEvidence.contains(clockId) { doc.timeEvidence.append(clockId) }
                    var b = template; b.day = day
                    if doc.clockBindings[key] == nil { doc.clockBindings[key] = b }
                    else if doc.clockBindings[key]?.page != number && !doc.clockReplicas[key,default:[]].contains(where: { $0.page == number }) { doc.clockReplicas[key,default:[]].append(b) }
                }
            }
            // Only text outside the independently bounded body is an annotation.
            let pageCells = doc.cells.filter { $0.page == number }
            guard !pageCells.isEmpty else { throw PDFParseError(code:.unsupported) }
            let table = RecoveryBox(x:pageCells.map { $0.box.x }.min()!,y:pageCells.map { $0.box.y }.min()!,width:pageCells.map { $0.box.x+$0.box.width }.max()!-pageCells.map { $0.box.x }.min()!,height:pageCells.map { $0.box.y+$0.box.height }.max()!-pageCells.map { $0.box.y }.min()!)
            for row in PDFGrid.rows(page.glyphs.indices.filter { !used.contains($0) }.map { page.glyphs[$0] }) {
                let b = try box(row)
                let outside = b.x+b.width <= table.x || b.x >= table.x+table.width || b.y+b.height <= table.y || b.y >= table.y+table.height
                guard outside else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                let id = try add(row)
                doc.annotations.append(RecoveryAnnotation(page:number,box:b,sourceIds:[id],tableBox:table))
            }
            if kind != .timetable {
                let assigned = Set(doc.clockEvidence.values.flatMap { $0 } + doc.clockBindings.values.flatMap(\.periodHeaderIds) + doc.clockReplicas.values.flatMap { $0.flatMap(\.periodHeaderIds) })
                for source in doc.sources.filter({ $0.page == number && $0.cellId.isEmpty && !assigned.contains($0.id) && !doc.annotations.flatMap(\.sourceIds).contains($0.id) && !doc.commonClockEvidence.contains($0.id) && !doc.yearEvidence.contains($0.id) && !doc.termEvidence.contains($0.id) && !doc.classEvidence.values.flatMap({$0}).contains($0.id) && !doc.dayEvidence.values.flatMap({$0}).contains($0.id) && !doc.periodEvidence.values.flatMap({$0}).contains($0.id) }) {
                    doc.annotations.append(RecoveryAnnotation(page:number,box:source.box,sourceIds:[source.id],tableBox:table))
                }
            }
            guard used.count == page.glyphs.count else { throw PDFParseError(code:.ambiguous) }
        }
        doc.classes = doc.classEvidence.keys.sorted(); doc.days = doc.dayEvidence.keys.sorted()
        doc.requiredSlots = doc.classes.flatMap { cls in doc.days.flatMap { day in (1...count).map { RecoverySlot(className:cls,day:day,period:$0) } } }
        let errors = RecoveryValidator.inputErrors(doc)
        guard errors.isEmpty else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
        return doc
    }
}
