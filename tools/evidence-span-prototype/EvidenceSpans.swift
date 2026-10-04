import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// Research-only textual ranges. Never supplies Schema2 evidence or character boxes.
struct SpanRefusal: Error { let reason: String }
func rawEqual(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
func unsupportedControl(_ scalar: Unicode.Scalar) -> Bool {
    [.control,.lineSeparator,.paragraphSeparator].contains(scalar.properties.generalCategory)
}
func validID(_ s: String) -> Bool {
    (1...128).contains(s.utf16.count) && !s.unicodeScalars.contains(where: unsupportedControl)
}
func sha256(_ bytes: Data) throws -> String {
#if canImport(CryptoKit)
    return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
#else
    // Host research CLI only: no shell, arbitrary arguments or temporary input files.
    let process = Process(), input = Pipe(), output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sha256sum")
    process.standardInput = input; process.standardOutput = output
    try process.run()
    try input.fileHandleForWriting.write(contentsOf: bytes)
    try input.fileHandleForWriting.close()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let token = String(decoding: data, as: UTF8.self).prefix(64)
    guard process.terminationStatus == 0, token.count == 64,
          token.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw SpanRefusal(reason: "hashFailure") }
    return String(token)
#endif
}
struct SpanBox: Codable {
    var x: Double; var y: Double; var width: Double; var height: Double
    var valid: Bool { [x,y,width,height,x+width,y+height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0 }
    func contains(_ b: Self) -> Bool { b.x >= x && b.y >= y && b.x+b.width <= x+width && b.y+b.height <= y+height }
    func overlaps(_ b: Self) -> Bool { min(x+width,b.x+b.width)>max(x,b.x) && min(y+height,b.y+b.height)>max(y,b.y) }
}
struct SpanParent: Codable { var id: String; var page: Int; var sourceOrder: Int?; var text: String; var wholeBox: SpanBox }
struct SpanCell: Codable { var id: String; var page: Int; var bounds: SpanBox }
struct SpanBand: Codable { var id: String; var cellId: String; var page: Int; var bounds: SpanBox }
struct SpanRule: Codable {
    var page: Int; var x1: Double; var y1: Double; var x2: Double; var y2: Double
    var valid: Bool { page >= 1 && [x1,y1,x2,y2].allSatisfy { $0.isFinite && $0 >= 0 } && ((x1==x2) != (y1==y2)) }
    func crosses(_ b: SpanBox) -> Bool {
        y1==y2 ? y1>b.y && y1<b.y+b.height && min(max(x1,x2),b.x+b.width)>max(min(x1,x2),b.x)
        : x1>b.x && x1<b.x+b.width && min(max(y1,y2),b.y+b.height)>max(min(y1,y2),b.y)
    }
}
struct SpanScene: Codable { var parents: [SpanParent]; var cells: [SpanCell]; var bands: [SpanBand]; var rules: [SpanRule] }
struct TextSpan: Codable { var parentId: String; var start: Int; var length: Int; var kind: String }
struct SpanProof: Codable {
    var original: SpanParent; var parentUtf8Sha256: String; var cellId: String; var bandId: String
    var role: String; var label: TextSpan; var body: TextSpan; var bodyText: String
}
final class SpanWork {
    let limit: Int; let cancelled: () -> Bool; private(set) var used = 0
    init(limit: Int, cancelled: @escaping () -> Bool) throws {
        guard (1...100000).contains(limit) else { throw SpanRefusal(reason: "inputLimit") }
        self.limit=limit; self.cancelled=cancelled
    }
    func step(_ n: Int = 1) throws {
        if cancelled() { throw SpanRefusal(reason: "cancelled") }
        guard n >= 0, n <= limit-used else { throw SpanRefusal(reason: "workLimit") }
        used += n
    }
}
enum EvidenceSpans {
    static let aliases: [(String,[String])] = [
        ("subject",["科目","授業","授業科目","科目名","授業名"]),
        ("teacher",["教員","担当","担当教員","教師","教員名","教師名","担当者"]),
        ("room",["教室","場所","授業教室","教室名","会場"])]
    static func build(_ scene: SpanScene, workLimit: Int = 100000, cancelled: @escaping () -> Bool = { false }) throws -> [SpanProof] {
        try buildCore(scene, work: SpanWork(limit: workLimit,cancelled: cancelled))
    }
    private static func buildCore(_ s: SpanScene, work: SpanWork) throws -> [SpanProof] {
        try work.step()
        guard (1...128).contains(s.parents.count), (1...128).contains(s.cells.count),
              (1...128).contains(s.bands.count), s.rules.count <= 128 else { throw SpanRefusal(reason: "inputLimit") }
        var ids = Set<Data>()
        for c in s.cells {
            try work.step()
            guard validID(c.id), ids.insert(Data(c.id.utf8)).inserted, c.page >= 1, c.bounds.valid else { throw SpanRefusal(reason: "invalidCell") }
        }
        for i in s.cells.indices { for j in s.cells.indices where j>i {
            try work.step()
            if s.cells[i].page==s.cells[j].page && s.cells[i].bounds.overlaps(s.cells[j].bounds) { throw SpanRefusal(reason: "overlappingCells") }
        }}
        ids.removeAll()
        for b in s.bands {
            try work.step(s.cells.count)
            let owners = s.cells.filter { rawEqual($0.id,b.cellId) }
            guard validID(b.cellId), validID(b.id), ids.insert(Data(b.id.utf8)).inserted, owners.count==1,
                  b.page==owners[0].page, b.bounds.valid, owners[0].bounds.contains(b.bounds) else { throw SpanRefusal(reason: "invalidBand") }
        }
        for i in s.bands.indices { for j in s.bands.indices where j>i {
            try work.step()
            if s.bands[i].page==s.bands[j].page && s.bands[i].bounds.overlaps(s.bands[j].bounds) { throw SpanRefusal(reason: "overlappingBands") }
        }}
        for r in s.rules { try work.step(); if !r.valid { throw SpanRefusal(reason: "invalidRule") } }
        ids.removeAll(); var proofs: [SpanProof] = []; var total = 0
        for p in s.parents {
            try work.step()
            guard validID(p.id), ids.insert(Data(p.id.utf8)).inserted, p.page>=1, (p.sourceOrder ?? 0)>=0,
                  p.wholeBox.valid, p.text.utf16.count<=4096 else { throw SpanRefusal(reason: "invalidParent") }
            try work.step(p.text.utf16.count)
            let bytes = Data(p.text.utf8), textBytes = Array(p.text.utf8); total += bytes.count
            guard bytes.count<=4096, total<=262144 else { throw SpanRefusal(reason: "textLimit") }
            if p.text.unicodeScalars.contains(where: unsupportedControl) { throw SpanRefusal(reason: "controlText") }
            try work.step(s.cells.count+s.bands.count)
            let owners=s.cells.filter { $0.page==p.page && $0.bounds.contains(p.wholeBox) }
            let rows=s.bands.filter { $0.page==p.page && $0.bounds.contains(p.wholeBox) }
            guard owners.count==1, rows.count==1, rawEqual(rows[0].cellId,owners[0].id) else { throw SpanRefusal(reason: "ambiguousGeometry") }
            for previous in proofs {
                try work.step()
                if previous.original.page==p.page && previous.original.wholeBox.overlaps(p.wholeBox) { throw SpanRefusal(reason: "overlappingParents") }
            }
            for r in s.rules { try work.step(); if r.page==p.page && r.crosses(p.wholeBox) { throw SpanRefusal(reason: "ruleCrossing") } }
            var matches: [(String,Int)] = []
            for (role,list) in aliases { for alias in list { for colon in [":","："] {
                try work.step(alias.utf16.count+1)
                let prefix=Array((alias+colon).utf8)
                if textBytes.starts(with: prefix) { matches.append((role,prefix.count)) }
            }}}
            guard matches.count==1 else { throw SpanRefusal(reason: "unknownOrAmbiguousAlias") }
            let (role,cut)=matches[0]
            try work.step(p.text.utf16.count)
            // Character boundaries, not byte/scalar offsets, prohibit splitting a grapheme.
            var boundary=0; var starts=Set([0])
            for char in p.text { boundary += String(char).utf8.count; starts.insert(boundary) }
            guard cut<bytes.count, starts.contains(cut), let body=String(data: bytes.dropFirst(cut),encoding: .utf8),
                  body.unicodeScalars.contains(where: { !$0.properties.isWhitespace }), let first=body.unicodeScalars.first else { throw SpanRefusal(reason: "bodyBoundaryOrEmpty") }
            if [.nonspacingMark,.spacingMark,.enclosingMark].contains(first.properties.generalCategory)
                || first.value==0x200D || (0xFE00...0xFE0F).contains(first.value) || (0xE0100...0xE01EF).contains(first.value) { throw SpanRefusal(reason: "bodyBoundaryOrEmpty") }
            if body.unicodeScalars.contains(where: { [0x30FB,0xFF65,0x2F,0xFF0F,0x3B,0xFF1B,0x7C,0xFF5C].contains($0.value) }) { throw SpanRefusal(reason: "unsupportedParallelSyntax") }
            let bodyBytes=Array(body.utf8)
            for (_,list) in aliases { for alias in list { for colon in [":","："] {
                try work.step(body.utf16.count+alias.utf16.count+1)
                let needle=Array((alias+colon).utf8)
                if bodyBytes.count>=needle.count {
                    for start in 0...(bodyBytes.count-needle.count) {
                        var equal=true
                        for index in needle.indices {
                            try work.step()
                            if bodyBytes[start+index] != needle[index] { equal=false; break }
                        }
                        if equal { throw SpanRefusal(reason: "multipleRoleSyntax") }
                    }
                }
            }}}
            proofs.append(SpanProof(original:p,parentUtf8Sha256:try sha256(bytes),cellId:owners[0].id,bandId:rows[0].id,role:role,
                label:TextSpan(parentId:p.id,start:0,length:cut,kind:"label"),body:TextSpan(parentId:p.id,start:cut,length:bytes.count-cut,kind:"body"),bodyText:body))
        }
        for c in s.cells {
            try work.step(proofs.count)
            let ps=proofs.filter { rawEqual($0.cellId,c.id) }
            guard ps.count==3, Set(ps.map(\.role)).count==3 else { throw SpanRefusal(reason: "incompleteOrRepeatedRoles") }
        }
        return proofs
    }
    static func verify(_ scene: SpanScene, proposed: [SpanProof], workLimit: Int = 100000, cancelled: @escaping () -> Bool = { false }) throws -> Bool {
        guard proposed.count<=128 else { throw SpanRefusal(reason:"inputLimit") }
        let work=try SpanWork(limit:workLimit,cancelled:cancelled)
        func charge(_ p: SpanProof) throws {
            guard p.original.text.utf16.count<=4096, p.bodyText.utf16.count<=4096,
                  p.original.text.utf8.count<=4096, p.bodyText.utf8.count<=4096,
                  (1...16).contains(p.role.utf16.count), (1...16).contains(p.label.kind.utf16.count), (1...16).contains(p.body.kind.utf16.count),
                  [p.original.id,p.cellId,p.bandId,p.label.parentId,p.body.parentId].allSatisfy(validID), p.parentUtf8Sha256.utf16.count==64 else { throw SpanRefusal(reason:"inputLimit") }
            try work.step(p.original.text.utf16.count+p.bodyText.utf16.count+[p.original.id,p.cellId,p.bandId,p.label.parentId,p.body.parentId].reduce(64) { $0+$1.utf16.count })
        }
        for p in proposed { try charge(p) }
        let canonical=try buildCore(scene,work:work)
        guard canonical.count==proposed.count else { return false }
        let encoder=JSONEncoder(); encoder.outputFormatting=[.sortedKeys]
        for (a,b) in zip(canonical,proposed) {
            try charge(a)
            // Encoded original UTF8 is exact, unlike Swift String's canonical-equivalence equality.
            let originalBytes=try encoder.encode(a), proposedBytes=try encoder.encode(b)
            try work.step(originalBytes.count+proposedBytes.count)
            if originalBytes != proposedBytes { return false }
        }
        return true
    }
}
