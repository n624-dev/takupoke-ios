import Foundation

enum RecoveryPromptMode: String, Codable, Sendable { case fieldExtraction, structureProposal }
struct RecoveryStructureCut: Codable, Equatable, Sendable {
    var id: String; var axis: String; var position: Double
}
struct RecoveryStructureUnit: Sendable {
    var id: String; var glyphs: [PDFGlyph]; var box: RecoveryBox
    var text: String { glyphs.map(\.text).joined() }
}
struct RecoveryStructureRequest: Error, Sendable {
    var id: String; var page: Int; var box: RecoveryBox; var slots: [RecoverySlot]
    var units: [RecoveryStructureUnit]; var cuts: [RecoveryStructureCut]
    var ownerCellId:String { id.range(of:"-sub-",options:.backwards).map { String(id[..<$0.lowerBound]) } ?? id }
    var prompt: RecoveryPromptCell {
        RecoveryPromptCell(cellId:id,slots:slots,sources:units.map {
            RecoveryPromptSource(id:$0.id,text:$0.text,box:$0.box,sourceLine:$0.glyphs.first?.sourceLine,sourceOrder:$0.glyphs.first?.sourceOrder)
        },blankFields:[],parallelCount:1,lessonBindings:[],mode:.structureProposal,structureCuts:cuts)
    }
}
struct RecoveryStructurePreparation: Error, Sendable {
    var document: RecoveryDocument; var requests: [RecoveryStructureRequest]
}
enum RecoveryBuildAttempt: Sendable { case document(RecoveryDocument), structure(RecoveryStructurePreparation) }
struct RecoveryStructureResolution: Sendable {
    var state: RecoveryJobState; var proposals:[String:[RecoveryLesson]]?; var metadata:RecoveryMetadata?; var errors:[String]
}
struct RecoveryPreparedPages: Sendable {
    var pages: [PDFPageLayout]; var fromOCR: Set<Int>; var rasters: [Int:RecoveryRasterGrid]
}
struct RecoveryStructureRole: Sendable {
    var role: RecoveryRole; var labels: [RecoveryStructureUnit]; var body: [RecoveryStructureUnit]
    var scope: RecoveryBox; var labelBox: RecoveryBox
}
enum RecoveryStructure {
    static func bounds(_ glyphs: [PDFGlyph]) throws -> RecoveryBox {
        guard !glyphs.isEmpty else { throw PDFParseError(code:.ambiguous) }
        let x = glyphs.map(\.x).min()!, y = glyphs.map(\.y).min()!
        let box = RecoveryBox(x:x,y:y,width:glyphs.map { $0.x+$0.width }.max()!-x,height:glyphs.map { $0.y+$0.height }.max()!-y)
        guard box.valid else { throw PDFParseError(code:.ambiguous) }
        return box
    }
    static func request(id: String,page: Int,box: RecoveryBox,slots: [RecoverySlot],glyphs: [PDFGlyph]) throws -> RecoveryStructureRequest {
        guard box.valid, !glyphs.isEmpty, glyphs.count <= 512 else { throw PDFParseError(code:.limit) }
        var units = [RecoveryStructureUnit]()
        let rows = try PDFGrid.contentRows(glyphs)
        for row in rows {
            var groups = [[PDFGlyph]]()
            for glyph in row {
                guard box.contains(try bounds([glyph])) else { throw PDFParseError(code:.ambiguous) }
                if let last = groups.last?.last, glyph.x-last.x-last.width > max(2,min(last.height,glyph.height)*0.55) { groups.append([]) }
                if groups.isEmpty { groups.append([]) }
                groups[groups.count-1].append(glyph)
            }
            for group in groups { units.append(RecoveryStructureUnit(id:"g\(units.count)",glyphs:group,box:try bounds(group))) }
        }
        guard units.count <= 64 else { throw PDFParseError(code:.limit) }
        func gaps(_ intervals: [(Double,Double)], first: Double,last: Double) -> [Double] {
            var merged = [(Double,Double)]()
            for range in intervals.sorted(by:{ $0.0 < $1.0 }) {
                if let end = merged.last, range.0 <= end.1 { merged[merged.count-1].1 = max(end.1,range.1) }
                else { merged.append(range) }
            }
            return [first] + zip(merged,merged.dropFirst()).compactMap { a,b in b.0-a.1 >= 0.5 ? (a.1+b.0)/2 : nil } + [last]
        }
        let ys = gaps(units.map { ($0.box.y,$0.box.y+$0.box.height) },first:box.y,last:box.y+box.height)
        let xs = gaps(units.map { ($0.box.x,$0.box.x+$0.box.width) },first:box.x,last:box.x+box.width)
        let cuts = ys.enumerated().map { RecoveryStructureCut(id:"y\($0.offset)",axis:"horizontal",position:$0.element) } +
            xs.enumerated().map { RecoveryStructureCut(id:"x\($0.offset)",axis:"vertical",position:$0.element) }
        return RecoveryStructureRequest(id:id,page:page,box:box,slots:slots,units:units,cuts:cuts)
    }
    private static func normalized(_ value: String) -> String { value.precomposedStringWithCompatibilityMapping.filter { !$0.isWhitespace } }
    /// This narrow certificate proves a unique semantic partition without
    /// enumerating complete assignment graphs: every original label-column unit
    /// is consumed by exactly three colon-terminated, same-column label chains,
    /// and every body unit lies inside exactly one disjoint label footprint.
    /// Different cut margins may describe the same partition; semantic alternatives fail.
    static func verify(_ request: RecoveryStructureRequest,_ lessons: [RecoveryLesson]) throws -> [RecoveryStructureRole] {
        guard lessons.count == 1 else { throw RecoveryProviderError.invalidOutput }
        let fields = [lessons[0].subject,lessons[0].teacher,lessons[0].room]
        guard Set(request.units.map(\.id)).count == request.units.count, Set(request.cuts.map(\.id)).count == request.cuts.count else { throw RecoveryProviderError.invalidOutput }
        let units = Dictionary(uniqueKeysWithValues:request.units.map { ($0.id,$0) })
        let cuts = Dictionary(uniqueKeysWithValues:request.cuts.map { ($0.id,$0) })
        var result = [RecoveryStructureRole](), usedLabels = Set<String>()
        for (role,field) in zip(RecoveryRole.allCases,fields) {
            guard field.state == .present,field.value.isEmpty,Set(field.evidence).count == field.evidence.count else { throw RecoveryProviderError.invalidOutput }
            let labelIds = field.evidence.filter { units[$0] != nil }
            let cutIds = field.evidence.filter { cuts[$0] != nil }
            guard (1...3).contains(labelIds.count),cutIds.count == 3,labelIds.count+cutIds.count == field.evidence.count,
                  field.evidence == labelIds+cutIds,
                  let top = cuts[cutIds[0]],let bottom = cuts[cutIds[1]],let left = cuts[cutIds[2]],
                  top.axis == "horizontal",bottom.axis == "horizontal",left.axis == "vertical",top.position < bottom.position,
                  left.position > request.box.x,left.position < request.box.x+request.box.width else { throw RecoveryProviderError.invalidOutput }
            let labels = labelIds.map { units[$0]! }
            guard labels.map(\.id) == labels.sorted(by:{ ($0.box.y,$0.box.x) < ($1.box.y,$1.box.x) }).map(\.id),
                  role.labels.map { normalized($0+":") }.contains(normalized(labels.map(\.text).joined())),
                  labels.allSatisfy({ usedLabels.insert($0.id).inserted }) else { throw RecoveryProviderError.invalidOutput }
            let labelBox = try bounds(labels.flatMap(\.glyphs))
            let scope = RecoveryBox(x:left.position,y:top.position,width:request.box.x+request.box.width-left.position,height:bottom.position-top.position)
            let height = labels.map { $0.box.height }.max()!
            guard request.box.contains(scope),labels.allSatisfy({ $0.box.x-request.box.x <= height && abs($0.box.x-labels[0].box.x) <= height*0.5 }),
                  labelBox.x+labelBox.width <= scope.x,labelBox.y >= scope.y,labelBox.y+labelBox.height <= scope.y+scope.height else { throw RecoveryProviderError.invalidOutput }
            result.append(RecoveryStructureRole(role:role,labels:labels,body:[],scope:scope,labelBox:labelBox))
        }
        for (index,role) in result.enumerated() {
            guard !result.prefix(index).contains(where:{
                min($0.scope.y+$0.scope.height,role.scope.y+role.scope.height) > max($0.scope.y,role.scope.y)
            }) else { throw RecoveryProviderError.invalidOutput }
        }
        let body = request.units.filter { !usedLabels.contains($0.id) }
        guard !body.isEmpty,request.units.filter({ $0.box.x-request.box.x <= $0.box.height }).allSatisfy({ usedLabels.contains($0.id) }) else { throw RecoveryProviderError.invalidOutput }
        for unit in body {
            let matching = result.indices.filter {
                result[$0].scope.contains(unit.box) &&
                unit.box.y >= result[$0].labelBox.y && unit.box.y+unit.box.height <= result[$0].labelBox.y+result[$0].labelBox.height
            }
            guard matching.count == 1 else { throw RecoveryProviderError.invalidOutput }
            result[matching[0]].body.append(unit)
        }
        guard result.first(where:{ $0.role == .subject })?.body.isEmpty == false else { throw RecoveryProviderError.invalidOutput }
        return result.sorted { $0.scope.y < $1.scope.y }
    }
    /// Cheap rule path: adjacent original text rows only. A wrapped label with a
    /// body row interleaved between its parts proceeds to the bounded AI proposal.
    static func cheap(_ request: RecoveryStructureRequest) -> [RecoveryLesson]? {
        let rows = PDFGrid.rows(request.units.flatMap(\.glyphs))
        var fields = [RecoveryRole:RecoveryField]()
        for role in RecoveryRole.allCases {
            let candidates = request.units.enumerated().filter { _,unit in
                role.labels.contains { normalized($0+":").hasPrefix(normalized(unit.text)) }
            }
            for (_,first) in candidates {
                let row = rows.firstIndex { $0.contains { $0.x == first.glyphs[0].x && $0.y == first.glyphs[0].y } }!
                for length in 1...3 where row+length <= rows.count {
                    guard (row..<(row+length)).allSatisfy({ index in
                        request.units.contains { u in u.box.x-request.box.x <= u.box.height && rows[index].contains { $0.x == u.glyphs[0].x && $0.y == u.glyphs[0].y } }
                    }) else { continue }
                    let labelUnits = request.units.filter { u in u.box.x-request.box.x <= u.box.height && (row..<(row+length)).contains(rows.firstIndex { $0.contains { $0.x == u.glyphs[0].x && $0.y == u.glyphs[0].y } }!) }
                    guard role.labels.map({ normalized($0+":") }).contains(normalized(labelUnits.map(\.text).joined())) else { continue }
                    guard let label = try? bounds(labelUnits.flatMap(\.glyphs)),
                          let x = request.cuts.first(where:{ $0.axis == "vertical" && $0.position >= label.x+label.width }),
                          let top = request.cuts.last(where:{ $0.axis == "horizontal" && $0.position <= label.y }),
                          let bottom = request.cuts.first(where:{ $0.axis == "horizontal" && $0.position >= label.y+label.height }) else { continue }
                    fields[role] = RecoveryField(state:.present,value:"",evidence:labelUnits.map(\.id)+[top.id,bottom.id,x.id])
                    break
                }
                if fields[role] != nil { break }
            }
        }
        guard let subject = fields[.subject],let teacher = fields[.teacher],let room = fields[.room] else { return nil }
        let proposal = [RecoveryLesson(subject:subject,teacher:teacher,room:room,dateEvidence:[],periodEvidence:[])]
        return (try? verify(request,proposal)) == nil ? nil : proposal
    }
}

extension RecoveryStructure {
    static func resolve(_ input:RecoveryStructurePreparation,providers:[any LocalRecoveryProvider],os:String,osMajor:Int,check:@escaping () throws -> Void) async throws -> RecoveryStructureResolution {
        try check(); try Task.checkCancellation()
        let errors = try RecoveryValidator.inputErrors(input.document,unresolvedCellIds:Set(input.requests.map(\.ownerCellId)),check:check)
        guard errors.isEmpty else { return RecoveryStructureResolution(state:.failed,proposals:nil,metadata:nil,errors:errors) }
        return try await resolve(input.requests,providers:providers,os:os,osMajor:osMajor,check:check)
    }
    private static func resolve(_ requests:[RecoveryStructureRequest],providers:[any LocalRecoveryProvider],os:String,osMajor:Int,check:@escaping () throws -> Void) async throws -> RecoveryStructureResolution {
        guard !requests.isEmpty,requests.count <= 32,Set(requests.map(\.id)).count == requests.count else { throw RecoveryProviderError.invalidOutput }
        for request in requests { guard try JSONEncoder().encode(request.prompt).count <= 8192 else { throw PDFParseError(code:.limit) } }
        var runtimeFailed = false
        for id in RecoveryPolicy.providers(os:os,majorVersion:osMajor) {
            try check(); try Task.checkCancellation()
            let matches = providers.filter { $0.id == id && $0.localOnly }
            guard matches.count <= 1 else { throw RecoveryProviderError.invalidOutput }
            guard let provider = matches.first else { continue }
            let availability:LocalProviderState
            do { availability = try await provider.availability(); try check(); try Task.checkCancellation() }
            catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled || error.code == .limit { throw error }
            catch { runtimeFailed = true; continue }
            if availability != .ready {
                if RecoveryPolicy.mayTryNext(availability) || os == "windows" && availability == .notReady { continue }
                return RecoveryStructureResolution(state:.awaitingModel,proposals:nil,metadata:nil,errors:[availability.rawValue])
            }
            do {
                var proposals = [String:[RecoveryLesson]]()
                for request in requests {
                    try check(); try Task.checkCancellation()
                    let proposal = try await provider.recoverCell(request.prompt)
                    try check(); try Task.checkCancellation()
                    _ = try verify(request,proposal)
                    proposals[request.id] = proposal
                }
                try check(); try Task.checkCancellation()
                return RecoveryStructureResolution(state:.awaitingConfirmation,proposals:proposals,metadata:provider.metadata,errors:[])
            } catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled || error.code == .limit { throw error }
            catch RecoveryProviderError.invalidOutput { return RecoveryStructureResolution(state:.failed,proposals:nil,metadata:nil,errors:["invalidOutput"]) }
            catch { runtimeFailed = true }
        }
        try check(); try Task.checkCancellation()
        return RecoveryStructureResolution(state:runtimeFailed ? .failed:.awaitingModel,proposals:nil,metadata:nil,errors:[runtimeFailed ? "runtimeFailure":"noLocalProvider"])
    }
}
