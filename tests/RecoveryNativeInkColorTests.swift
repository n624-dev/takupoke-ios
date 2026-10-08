import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(Vision) && canImport(AppKit)
import Vision
import AppKit
import CoreText
import CryptoKit

/// Fixed shadow comparison; synthetic pixels only, no application adoption.
final class RecoveryNativeInkColorTests: XCTestCase {
    private struct Source { var kind: String; var literal: String; var box: CGRect; var size: CGFloat }
    private struct Line { var box: CGRect; var candidates: [(String, Double)]; var order: Int }
    private struct Batch {
        var cohort: Int; var color: Int; var hash: String; var sources: [Source]
        var readers: [(String, [Line])]; var correction: Bool
    }
    func testFixedInkColorsWithoutAdoption() async throws {
        guard #available(macOS 26.0, *), ProcessInfo.processInfo.environment["TAKUPOKE_NATIVE_INK_COLORS"] == "1" else {
            throw XCTSkip("Requires the dedicated local native ink-color comparison")
        }
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["TAKUPOKE_NATIVE_INK_REPORT"])
        XCTAssertFalse(path.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        guard !path.isEmpty, !FileManager.default.fileExists(atPath: path) else { return }
        let palette: [(String, [CGFloat])] = [
            ("black", [0,0,0]), ("navy", [0.05,0.1,0.3]),
            ("red", [0.65,0.08,0.08]), ("green", [0.05,0.35,0.05]),
            ("dark-gray", [28/255.0,28/255.0,28/255.0]),
            ("medium-gray", [0.35,0.35,0.35]), ("light-gray", [0.65,0.65,0.65]),
            ("very-light-gray", [0.85,0.85,0.85])]
        let kinds = ["ascii-header", "japanese-header", "japanese-body", "code"]
        let literals = [
            ["AI_7","Al_7","1_Q3","I_Q3","4_X2","A_X2","0_Z6","O_Z6"],
            ["架空月曜日","架空火曜日","架空水曜日","架空木曜日","架空金曜日","架空前期","架空後期","架空年度"],
            ["架空科目壱","架空科目弐","架空講師甲","架空講師乙","架空教室壱","架空教室弐","架空演習甲","架空演習乙"],
            ["B203","B2O3","C110","Cl10","D401","DA01","E_10","E_I0"]]
        let fonts = ["HiraginoSans-W3", "HiraMinProN-W3"]
        var batches = [Batch]()
        let side = 1920
        // Freeze layout and use the same original region for every color.
        // Complete all32 native calls before comparing any recognized literal.
        for cohort in 0..<2 {
            for (colorIndex, entry) in palette.enumerated() {
                let context = try XCTUnwrap(CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,
                    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(gray:1,alpha:1); context.fill(CGRect(x:0,y:0,width:side,height:side))
                var sources = [Source]()
                for kind in 0..<4 {
                    for index in 0..<8 {
                        let ordinal = kind*8+index, slot = (ordinal*17+3)%64
                        let box = CGRect(x:16+(slot%8)*236,y:16+(slot/8)*236,width:220,height:220)
                        let size: CGFloat = [9,12,16,20][index%4]
                        let font = CTFontCreateWithName(fonts[cohort] as CFString,size,nil)
                        XCTAssertEqual(CTFontCopyPostScriptName(font) as String,fonts[cohort])
                        let line = CTLineCreateWithAttributedString(NSAttributedString(string:literals[kind][index],attributes:[
                            NSAttributedString.Key(kCTFontAttributeName as String):font,
                            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(red:entry.1[0],green:entry.1[1],blue:entry.1[2],alpha:1)]) as CFAttributedString)
                        context.textMatrix = .identity
                        context.textPosition = CGPoint(x:box.minX+12,y:CGFloat(side)-box.minY-80)
                        CTLineDraw(line,context)
                        sources.append(Source(kind:kinds[kind],literal:literals[kind][index],box:box,size:size))
                    }
                }
                let image = try XCTUnwrap(context.makeImage())
                let pixels = try XCTUnwrap(image.dataProvider?.data)
                let imageHash = SHA256.hash(data:pixels as Data).map { String(format:"%02x",$0) }.joined()
                var documents = RecoveryVisionCapture.request()
                documents.textRecognitionOptions.minimumTextHeightFraction = 8/Float(side)
                let rawDocuments = try await documents.perform(on:image).flatMap { $0.document.text.lines }
                var text = RecognizeTextRequest()
                text.recognitionLevel = .accurate
                text.recognitionLanguages = documents.textRecognitionOptions.recognitionLanguages
                text.automaticallyDetectsLanguage = false
                text.usesLanguageCorrection = documents.textRecognitionOptions.useLanguageCorrection
                text.minimumTextHeightFraction = documents.textRecognitionOptions.minimumTextHeightFraction
                let rawText = try await text.perform(on:image)
                func position(_ box: CGRect) -> CGRect {
                    CGRect(x:box.minX*CGFloat(side),y:(1-box.maxY)*CGFloat(side),width:box.width*CGFloat(side),height:box.height*CGFloat(side))
                }
                let a = rawDocuments.enumerated().map { order, line in
                    Line(box:position(line.boundingBox.cgRect),candidates:line.topCandidates(5).map { ($0.string,Double($0.confidence)) },order:order)
                }
                let b = rawText.enumerated().map { order, line in
                    Line(box:position(line.boundingBox.cgRect),candidates:line.topCandidates(5).map { ($0.string,Double($0.confidence)) },order:order)
                }
                batches.append(Batch(cohort:cohort,color:colorIndex,hash:imageHash,sources:sources,
                    readers:[("documents",a),("accurate-text",b)],correction:text.usesLanguageCorrection))
            }
        }
        XCTAssertEqual(batches.count,16)
        XCTAssertEqual(Set(batches.map(\.hash)).count,16)
        var records = [String]()
        func emit(_ prefix: String, _ value: [String:Any]) throws {
            let line = prefix+String(decoding:try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),as:UTF8.self)
            records.append(line); print(line)
        }
        func box(_ b: CGRect) -> [Double] { [Double(b.minX),Double(b.minY),Double(b.width),Double(b.height)] }
        for batch in batches {
            try emit("NATIVE_INK_SCOPE ",["cohort":batch.cohort,"color":palette[batch.color].0,"RGB":palette[batch.color].1,
                "imageRGBAHash":batch.hash,"width":side,"height":side,"items":32,"calls":2,"font":fonts[batch.cohort],
                "languages":["ja","en"],"languageCorrection":batch.correction,"automaticLanguage":false,
                "qualified":false,"adoptionCalls":0,"newIndependentItems":0])
            for (reader, lines) in batch.readers {
                var metrics = [String:(Int,Int,Int,Int)]()
                for (ordinal, source) in batch.sources.enumerated() {
                    let hits = lines.filter { $0.box.intersects(source.box) }
                    let contained = hits.count==1 && source.box.contains(hits[0].box)
                    let first = hits.count==1 ? hits[0].candidates.first:nil
                    let status = hits.isEmpty ? "missing":hits.count>1 ? "split-or-conflicting":first==nil ? "candidate-missing":contained ? "single-contained":"spanning-region"
                    let exact = status=="single-contained" && first?.0==source.literal
                    let above = status=="single-contained" && first.map { $0.1>=0.85 }==true
                    let old = metrics[source.kind] ?? (0,0,0,0)
                    metrics[source.kind] = (old.0+(exact ? 1:0),old.1+(exact && above ? 1:0),old.2+(!exact && above ? 1:0),old.3+(hits.isEmpty ? 1:0))
                    let observed: [[String:Any]] = hits.map { line in ["sourceOrder":line.order,"box":box(line.box),
                        "candidates":line.candidates.map { ["text":$0.0,"score":$0.1] as [String:Any] }] }
                    try emit("NATIVE_INK_ITEM ",["cohort":batch.cohort,"color":palette[batch.color].0,"ordinal":ordinal,"kind":source.kind,
                        "reader":reader,"sourcePixels":Double(source.size),"evaluationRegion":box(source.box),"imageRGBAHash":batch.hash,
                        "expectedAfterRecognition":source.literal,"observed":first?.0 as Any? ?? NSNull(),"nativeScore":first?.1 as Any? ?? NSNull(),
                        "status":status,"exact":exact,"observations":observed,"crossReaderScoreSubstitution":false,"qualified":false,"adoptionCalls":0])
                }
                for kind in kinds {
                    let metric = try XCTUnwrap(metrics[kind])
                    try emit("NATIVE_INK_OUTCOME ",["cohort":batch.cohort,"color":palette[batch.color].0,"reader":reader,"kind":kind,
                        "items":8,"exact":metric.0,"correctAtOrAbove085":metric.1,"wrongAtOrAbove085":metric.2,"missing":metric.3,
                        "qualified":false,"adoptionCalls":0,"productionThresholdChanged":false])
                }
            }
        }
        try Data((records.joined(separator:"\n")+"\n").utf8).write(to:URL(fileURLWithPath:path),options:.withoutOverwriting)
    }
}
#endif
