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
    // Existing structure instruction bytes retain their own provenance.
    static let promptVersion = "3"
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
    /// Bounded exact-label search uses original groups, including fragments with
    /// body-only rows between them. The certificate remains the authority: a
    /// matching string alone cannot establish source ownership or empty fields.
    static func cheap(_ request: RecoveryStructureRequest) -> [RecoveryLesson]? {
        try? cheap(request,check:{})
    }
    static func cheap(_ request: RecoveryStructureRequest,check:@escaping () throws -> Void) throws -> [RecoveryLesson]? {
        try cheap(request,work:RecoveryValidationWork(check:check))
    }
    static func cheap(_ request: RecoveryStructureRequest,work:RecoveryValidationWork) throws -> [RecoveryLesson]? {
        try work.finish()
        guard !request.units.isEmpty,request.units.count <= 64,request.cuts.count <= 132 else { throw PDFParseError(code:.limit) }
        guard request.box.valid,Set(request.units.map(\.id)).count == request.units.count,
              Set(request.cuts.map(\.id)).count == request.cuts.count else { return nil }
        // Every unit at the left boundary must belong to one of three labels,
        // and the unchanged certificate allows at most three groups per label.
        let required = Set(request.units.filter { $0.box.x-request.box.x <= $0.box.height }.map(\.id))
        guard required.count <= 9 else { return nil }
        var glyphCount=0
        for unit in request.units {
            guard unit.glyphs.count <= 512-glyphCount else { throw PDFParseError(code:.limit) }
            glyphCount += unit.glyphs.count
        }
        let ordered=request.units.sorted { ($0.box.y,$0.box.x) < ($1.box.y,$1.box.x) }
        var strings=[String](), originalBytes=[String:Int]()
        for unit in ordered {
            guard work.charge(unit.glyphs.count+1) else { try work.finish(); return nil }
            var parts=[String](), bytes=0
            for glyph in unit.glyphs {
                guard work.charge(glyph.text.utf8.count+1) else { try work.finish(); return nil }
                parts.append(glyph.text);bytes += glyph.text.utf8.count
            }
            originalBytes[unit.id]=bytes
            strings.append(normalized(parts.joined()))
        }
        func field(_ indices:[Int]) throws -> RecoveryField? {
            guard work.charge(indices.count+request.cuts.count+1) else { try work.finish(); return nil }
            let units=indices.map { ordered[$0] }
            guard let label=try? bounds(units.flatMap(\.glyphs)),
                  let top=request.cuts.filter({ $0.axis == "horizontal" && $0.position <= label.y }).max(by:{ $0.position < $1.position }),
                  let bottom=request.cuts.filter({ $0.axis == "horizontal" && $0.position >= label.y+label.height }).min(by:{ $0.position < $1.position }),
                  let left=request.cuts.filter({ $0.axis == "vertical" && $0.position >= label.x+label.width && $0.position > request.box.x && $0.position < request.box.x+request.box.width }).min(by:{ $0.position < $1.position }) else { return nil }
            // These nearest measured margins include the whole label footprint.
            // verify requires every body group to lie within that footprint, so
            // wider equivalent margins need no separate assignment search.
            return RecoveryField(state:.present,value:"",evidence:units.map(\.id)+[top.id,bottom.id,left.id])
        }
        var candidates=[RecoveryRole:[RecoveryField]]()
        for role in RecoveryRole.allCases {
            let targets=role.labels.map { normalized($0+":") }
            var fields=[RecoveryField]()
            func search(_ start:Int,_ chain:[Int],_ prefix:String) throws {
                guard chain.count < 3 else { return }
                for index in start..<ordered.count {
                    guard work.charge(strings[index].utf8.count+prefix.utf8.count+1) else { try work.finish(); return }
                    let text=prefix+strings[index]
                    guard targets.contains(where:{ $0.hasPrefix(text) }) else { continue }
                    let next=chain+[index]
                    if targets.contains(text),let value=try field(next) { fields.append(value) }
                    try search(index+1,next,text)
                }
            }
            try search(0,[],"")
            guard !fields.isEmpty else { try work.finish(); return nil }
            candidates[role]=fields
        }
        var accepted:[RecoveryLesson]?, signature:[[String]]?
        for subject in candidates[.subject]! {
            let subjectIds=Set(subject.evidence.dropLast(3))
            for teacher in candidates[.teacher]! {
                guard work.charge(subject.evidence.count+teacher.evidence.count+1) else { try work.finish(); return nil }
                let teacherIds=Set(teacher.evidence.dropLast(3))
                guard subjectIds.isDisjoint(with:teacherIds) else { continue }
                for room in candidates[.room]! {
                    guard work.charge(request.units.count*4+request.cuts.count+room.evidence.count+1) else { try work.finish(); return nil }
                    let roomIds=Set(room.evidence.dropLast(3)), labels=subjectIds.union(teacherIds).union(roomIds)
                    guard roomIds.isDisjoint(with:subjectIds),roomIds.isDisjoint(with:teacherIds),required.isSubset(of:labels) else { continue }
                    guard work.charge(labels.reduce(0) { $0+originalBytes[$1,default:0] }) else { try work.finish(); return nil }
                    let proposal=[RecoveryLesson(subject:subject,teacher:teacher,room:room,dateEvidence:[],periodEvidence:[])]
                    guard let roles=try? verify(request,proposal) else { continue }
                    let partition=RecoveryRole.allCases.flatMap { role -> [[String]] in
                        let value=roles.first { $0.role == role }!
                        return [value.labels.map(\.id),value.body.map(\.id)]
                    }
                    if let signature,signature != partition { try work.finish(); throw PDFParseError(code:.ambiguous,stage:.lessonLines) }
                    if accepted == nil { accepted=proposal;signature=partition }
                }
            }
        }
        try work.finish()
        return accepted
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
                var metadata = provider.metadata
                metadata.promptVersion = promptVersion
                return RecoveryStructureResolution(state:.awaitingConfirmation,proposals:proposals,metadata:metadata,errors:[])
            } catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled || error.code == .limit { throw error }
            catch RecoveryProviderError.invalidOutput { return RecoveryStructureResolution(state:.failed,proposals:nil,metadata:nil,errors:["invalidOutput"]) }
            catch { runtimeFailed = true }
        }
        try check(); try Task.checkCancellation()
        return RecoveryStructureResolution(state:runtimeFailed ? .failed:.awaitingModel,proposals:nil,metadata:nil,errors:[runtimeFailed ? "runtimeFailure":"noLocalProvider"])
    }
}
