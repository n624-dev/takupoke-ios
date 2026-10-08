import Foundation
import XCTest
#if canImport(Vision) && canImport(AppKit)
import Vision
import AppKit
import CoreText
import CryptoKit

/// Shadow measurement only. Printed answers/regions are evaluation truth, never
/// Vision input, candidate selection or an application adoption capability.
final class RecoveryNativeScoreBoundaryTests:XCTestCase {
    private struct Item {
        var kind:String; var literal:String; var box:CGRect; var pixels:CGFloat
    }
    private struct Result {
        var item:Item; var observed:String?; var score:Double?; var status:String
        var exact:Bool { status == "single-contained" && observed == item.literal }
        var eligible:Bool { status == "single-contained" && score?.isFinite == true }
    }
    func testIndependentNativeScoreBoundaryWithoutAdoption() async throws {
        guard #available(macOS 26.0,*),ProcessInfo.processInfo.environment["TAKUPOKE_NATIVE_SCORE_BOUNDARY"] == "1" else {
            throw XCTSkip("Requires the dedicated nonadoptable native score experiment")
        }
        let kinds=["ascii-header","japanese-header","japanese-body","code"]
        let literals=[
            ["AI_7","Al_7","1_Q3","I_Q3","4_X2","A_X2","0_Z6","O_Z6","3_K8","8_K3","2_T5","5_T2","B_R4","D_R4","6_N9","9_N6"],
            ["架空月曜日","架空火曜日","架空水曜日","架空木曜日","架空金曜日","架空前期","架空後期","架空年度","架空試験日","架空返却日","架空第一限","架空第二限","架空第三限","架空第四限","架空第五限","架空第六限"],
            ["架空科目壱","架空科目弐","架空科目参","架空科目肆","架空講師甲","架空講師乙","架空講師丙","架空講師丁","架空教室壱","架空教室弐","架空教室参","架空教室肆","架空演習甲","架空演習乙","架空実験丙","架空実験丁"],
            ["B203","B2O3","C110","Cl10","D401","DA01","E_10","E_I0","F-07","F-O7","G101","Gl01","H203","H2O3","J_14","J_IA"]]
        let heldLiterals=[
            ["AI_9","Al_9","1_V2","I_V2","4_P6","A_P6","0_F8","O_F8","3_W5","8_W3","2_S7","5_S2","B_Y1","D_Y1","6_M4","9_M6"],
            ["架空月曜","架空火曜","架空水曜","架空木曜","架空金曜","架空学期前","架空学期後","架空西暦","架空試験週","架空返却週","架空一時限","架空二時限","架空三時限","架空四時限","架空五時限","架空六時限"],
            ["架空科目伍","架空科目陸","架空科目漆","架空科目捌","架空講師戊","架空講師己","架空講師庚","架空講師辛","架空教室伍","架空教室陸","架空教室漆","架空教室捌","架空演習戊","架空演習己","架空実験庚","架空実験辛"],
            ["K305","K3O5","L112","Ll12","M407","MA07","N_16","N_I6","P-09","P-O9","R105","Rl05","S207","S2O7","T_14","T_IA"]]
        let fontNames=["HiraginoSans-W3","HiraMinProN-W3"]
        var cohorts=[[Result]]()
        for cohort in 0..<2 {
            let side=1920
            let context=try XCTUnwrap(CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,
                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:side,height:side))
            var items=[Item]()
            for kind in 0..<4 {
                for index in 0..<16 {
                    let slot=((kind*16+index)*29+7)%64
                    let box=CGRect(x:16+(slot%8)*236,y:16+(slot/8)*236,width:220,height:220)
                    let size:CGFloat=[9,12,16,20][index%4]
                    let font=CTFontCreateWithName(fontNames[cohort] as CFString,size,nil)
                    XCTAssertEqual(CTFontCopyPostScriptName(font) as String,fontNames[cohort],"Do not silently substitute a cohort font")
                    let literal=(cohort==0 ? literals:heldLiterals)[kind][index]
                    let color=index%2==0 ? CGColor(gray:0,alpha:1):CGColor(red:0.05,green:0.1,blue:0.3,alpha:1)
                    let line=CTLineCreateWithAttributedString(NSAttributedString(string:literal,attributes:[
                        NSAttributedString.Key(kCTFontAttributeName as String):font,
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]))
                    context.textMatrix = .identity
                    context.textPosition=CGPoint(x:box.minX+12,y:CGFloat(side)-box.minY-80)
                    CTLineDraw(line,context)
                    items.append(Item(kind:kinds[kind],literal:literal,box:box,pixels:size))
                }
            }
            let image=try XCTUnwrap(context.makeImage())
            var request=RecoveryVisionCapture.request()
            request.textRecognitionOptions.minimumTextHeightFraction=8/Float(side)
            let lines=try await request.perform(on:image).flatMap{$0.document.text.lines}
            // Resolve observation locations after recognition, before looking at
            // expected text. A spanning observation stays ineligible, never split.
            let positioned=lines.enumerated().map { order,line -> (CGRect,String?,Double?,Int) in
                let b=line.boundingBox.cgRect,candidate=line.topCandidates(1).first
                return (CGRect(x:b.minX*CGFloat(side),y:(1-b.maxY)*CGFloat(side),width:b.width*CGFloat(side),height:b.height*CGFloat(side)),
                    candidate?.string,candidate.map{Double($0.confidence)},order)
            }
            var results=[Result]()
            for (ordinal,item) in items.enumerated() {
                let hits=positioned.filter{$0.0.intersects(item.box)}
                let contained=hits.count==1 && item.box.contains(hits[0].0)
                let status=hits.isEmpty ? "missing":hits.count>1 ? "split-or-conflicting":hits[0].1 == nil ? "candidate-missing":contained ? "single-contained":"spanning-region"
                let result=Result(item:item,observed:hits.count==1 ? hits[0].1:nil,score:hits.count==1 ? hits[0].2:nil,status:status)
                results.append(result)
                let report:[String:Any]=["cohort":cohort,"ordinal":ordinal,"kind":item.kind,"sourcePixels":Double(item.pixels),
                    "expectedAfterRecognition":item.literal,"observed":result.observed as Any? ?? NSNull(),
                    "nativeScore":result.score as Any? ?? NSNull(),"status":status,"exact":result.exact,
                    "evaluationRegion":[Double(item.box.minX),Double(item.box.minY),Double(item.box.width),Double(item.box.height)],
                    "observations":hits.map { hit -> [String:Any] in ["nativeOrder":hit.3,
                        "originalPageBox":[Double(hit.0.minX),Double(hit.0.minY),Double(hit.0.width),Double(hit.0.height)],
                        "text":hit.1 as Any? ?? NSNull(),"score":hit.2 as Any? ?? NSNull()] },
                    "qualified":false,"adoptionCalls":0]
                print("NATIVE_SCORE_ITEM "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
            }
            cohorts.append(results)
            let outside=positioned.filter { observed in !items.contains { $0.box.contains(observed.0) } }.count
            print("NATIVE_SCORE_SCOPE cohort=\(cohort) items=64 calls=1 lines=\(lines.count) notWhollyInOneRegion=\(outside) font=\(fontNames[cohort]); original1920px raster; native score; no adoption")
        }
        // One monotone candidate is chosen on development only. Without at
        // least2 scored errors and4 exact observations, calibration is unknown.
        // The held-out results never move a threshold or trigger a retry.
        for kind in kinds {
            let development=cohorts[0].filter{$0.item.kind==kind},held=cohorts[1].filter{$0.item.kind==kind}
            let errors=development.filter{$0.eligible && !$0.exact}.compactMap(\.score)
            let positives=development.filter(\.exact).compactMap(\.score)
            let candidate=errors.max().map{$0.nextUp}
            let measurable=errors.count>=2 && positives.count>=4 && candidate.map { t in t<=1 && positives.contains{$0>=t} } == true
            let threshold=measurable ? candidate:nil
            let accepted=threshold.map { t in held.filter{$0.eligible && ($0.score ?? -1)>=t} } ?? []
            let report:[String:Any]=["kind":kind,"developmentExact":development.filter(\.exact).count,
                "developmentScoredErrors":errors.count,"candidateThreshold":threshold as Any? ?? NSNull(),
                "calibrationMeasurable":measurable,"heldExact":held.filter(\.exact).count,
                "heldAcceptedExact":accepted.filter(\.exact).count,"heldAcceptedWrong":accepted.filter{!$0.exact}.count,
                "qualified":false,"productionThresholdChanged":false]
            print("NATIVE_SCORE_BOUNDARY "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
        }
    }
}
#endif
