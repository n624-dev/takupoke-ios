import Foundation
import CryptoKit
import PDFKit
import UIKit

struct NativeFixture: Decodable { var file: String; var sha256: String; var bytes: Int }
struct NativeInputs: Decodable { var schema: Int; var files: [NativeFixture] }
struct LiteralLesson: Codable, Equatable { var subject: String; var teacher: String; var room: String }
struct LiteralSlot: Decodable { var className: String; var weekday: Int; var period: Int; var lessons: [LiteralLesson] }
struct LiteralExpected: Decodable { var schoolYear: Int; var term: String; var classes: [String]; var slots: [LiteralSlot] }
struct AcquiredCase { var record: [String:Any]; var analysis: PDFAnalysis? }

@main
struct IndependentReaderProbe {
    static let files = ["unlabeled.pdf","labeled-control.pdf","unlabeled-no-unused-font.pdf","labeled-control-no-unused-font.pdf","parallel-mismatch.pdf","unreadable-body.pdf"]
    static func sha(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func object<T:Encodable>(_ value:T) throws -> Any {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        return try JSONSerialization.jsonObject(with:encoder.encode(value))
    }
    static func emit(_ record:[String:Any]) throws {
        let data=try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys])
        guard data.count<=16*1024*1024 else { throw NSError(domain:"RecordTransportLimit",code:1) }
        FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data([10]))
    }
    static func failure(_ error:Error) -> [String:Any] {
        if let pdf=error as? PDFParseError {
            return ["type":"PDFParseError","code":pdf.code.rawValue,"stage":pdf.stage?.rawValue as Any? ?? NSNull(),
                    "page":pdf.page as Any? ?? NSNull(),"detail":(try? object(pdf)) ?? NSNull()]
        }
        let native=error as NSError
        return ["type":String(describing:type(of:error)),"domain":native.domain,"code":native.code,"description":String(describing:error)]
    }
    static func captureRecord(_ capture:RecoveryReadCapture) throws -> [String:Any] {
        var pages=[[String:Any]]()
        for page in capture.pages {
            var value:[String:Any]=["page":page.page,"state":page.state.rawValue,"layoutPresent":page.layout != nil]
            if let layout=page.layout {
                value["glyphs"]=layout.glyphs.count;value["rules"]=layout.lines.count
                let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
                value["originalLayoutSHA256"]=sha(try encoder.encode(layout))
            }
            pages.append(value)
        }
        return ["readerCompleted":capture.readerCompleted,"complete":capture.complete,"pages":pages]
    }
    // This acquisition function has no assertion data parameter and never opens
    // expected.json. Only the actual PDF and existing production APIs decide route.
    static func acquire(_ fixture:NativeFixture, folder:URL, readerOnly:Bool) async -> AcquiredCase {
        let start=Date(), url=folder.appendingPathComponent(fixture.file), capture=RecoveryReadCapture()
        var record:[String:Any]=["type":"fixture","file":fixture.file,"pdfSHA256":fixture.sha256,"pdfBytes":fixture.bytes,
            "readerOnly":readerOnly,"readerCallStarted":false,"readReturned":false,"strictReturned":false,"analysisReturned":false,
            "ocrRequests":0,"modelInvocations":0,"formalStorageAssessed":false,"manualAdoptionUIAssessed":false]
        var analysis:PDFAnalysis?, stage="reader"
        let check:() throws -> Void = {
            try Task.checkCancellation()
            guard Date().timeIntervalSince(start)<120 else { throw PDFParseError(code:.limit) }
        }
        do {
            let data=try Data(contentsOf:url)
            guard data.count==fixture.bytes, sha(data)==fixture.sha256 else { throw NSError(domain:"GeneratedPDFChanged",code:1) }
            record["readerCallStarted"]=true
            let pages=try PDFKitReader.read(url,kind:.timetable,capture:capture,check:check)
            record["readReturned"]=true;record["layouts"]=try object(pages)
            record["pageCount"]=pages.count;record["glyphCount"]=pages.reduce(0){$0+$1.glyphs.count}
            record["ruleCount"]=pages.reduce(0){$0+$1.lines.count};record["capture"]=try captureRecord(capture)
            if readerOnly { record["route"]="readerOnly" }
            else {
                stage="strictParser"
                do {
                    analysis=try PDFSchoolParser.parse(pages,kind:.timetable,digest:fixture.sha256,name:fixture.file,check:check)
                    record["strictReturned"]=true;record["route"]="strict"
                } catch {
                    record["strictError"]=failure(error)
                    guard let pdf=error as? PDFParseError, RecoveryPolicy.eligible(pdf), capture.complete,
                          capture.pages.count==pages.count, capture.pages.allSatisfy({$0.state == .complete && $0.layout != nil}) else { throw error }
                    // Use the actual complete Reader capture, exactly as production
                    // recovery does. No gold layouts, roles, evidence or blank flags.
                    let layouts=capture.pages.compactMap(\.layout)
                    stage="recoveryBuilder";record["route"]="recovery"
                    let document:RecoveryDocument
                    do { document=try RecoveryDocumentBuilder.build(layouts,kind:.timetable,hash:fixture.sha256,check:check) }
                    catch let preparation as RecoveryStructurePreparation {
                        record["structureDocument"]=try object(preparation.document)
                        record["structureRequests"]=try object(preparation.requests.map(\.prompt))
                        record["structureInputErrors"]=try RecoveryValidator.inputErrors(preparation.document,unresolvedCellIds:Set(preparation.requests.map(\.ownerCellId)),check:check)
                        let resolution=try await RecoveryStructure.resolve(preparation,providers:[],os:"ios",osMajor:27,check:check)
                        record["structureState"]=resolution.state.rawValue;record["structureErrors"]=resolution.errors
                        // The actual return type contains proposals/metadata, not
                        // a document. This no-provider vector probe does not
                        // apply model structure proposals or qualify that route.
                        record["structureProposalReturned"]=resolution.proposals != nil
                        record["structureProposalAdoptionAssessed"]=false
                        throw NSError(domain:"StructureProposalNotAssessed",code:1)
                    }
                    record["recoveryDocument"]=try object(document)
                    record["builderRequiredSlots"]=document.requiredSlots.count;record["builderClasses"]=document.classes
                    record["builderInputErrors"]=try RecoveryValidator.inputErrors(document,check:check)
                    stage="rulesEngine"
                    let run=try await RecoveryEngine.run(document,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:check)
                    record["engineState"]=run.state.rawValue;record["engineErrors"]=run.errors
                    guard run.state == .awaitingConfirmation, let result=run.result else { throw NSError(domain:"SourceOnlyRulesNotComplete",code:1) }
                    stage="validator"
                    let validation=try RecoveryValidator.validate(document,result,check:check)
                    record["validatorCanAdopt"]=validation.canAdopt;record["validatorErrors"]=validation.errors
                    guard validation.canAdopt else { throw NSError(domain:"NativeValidatorRejected",code:1) }
                    record["recoveryResult"]=try object(result)
                    stage="inMemoryAnalysisConversion"
                    guard let day=SchoolDate(year:document.schoolYear,month:document.term == "前期" ? 4:10,day:1),
                          document.term == "前期" || document.term == "後期" else { throw PDFParseError(code:.ambiguous) }
                    let source=RecoverySelectedSource(kind:.timetable,url:url,digest:fixture.sha256,originalName:fixture.file,storedName:fixture.file,period:SchoolDataPeriod(day:day),captured:capture.pages)
                    analysis=try RecoveryConversion.timetable(RecoveryPreview(document:document,result:result,source:source))
                    record["inMemoryConversionOnly"]=true
                }
            }
            if let analysis {
                record["analysisReturned"]=true;record["actualAnalysis"]=try object(analysis)
                record["schoolYear"]=analysis.schoolYear;record["term"]=analysis.term as Any? ?? NSNull()
                record["actualLessons"]=analysis.lessons.count
                record["observedClasses"]=Array(Set(analysis.lessons.map(\.className))).sorted()
            }
        } catch { record["failureStage"]=stage;record["failure"]=failure(error) }
        record["capture"]=(try? captureRecord(capture)) ?? NSNull()
        record["seconds"]=Date().timeIntervalSince(start)
        return AcquiredCase(record:record,analysis:analysis)
    }
    // Called only after production returned an actual Analysis. Literal
    // assertions do not influence Reader, parser, fallback choice or conversion.
    static func assertLiteral(_ analysis:PDFAnalysis, expectedURL:URL, expectedSHA:String) throws -> [String:Any] {
        let data=try Data(contentsOf:expectedURL)
        guard sha(data)==expectedSHA else { throw NSError(domain:"AssertionOracleChanged",code:1) }
        let expected=try JSONDecoder().decode(LiteralExpected.self,from:data)
        func key(_ c:String,_ d:Int,_ p:Int)->String { "\(c)|\(d)|\(p)" }
        let observed=Dictionary(grouping:analysis.lessons,by:{key($0.className,$0.weekday,$0.period)})
            .mapValues { $0.map { LiteralLesson(subject:$0.names.subject,teacher:$0.names.teacher,room:$0.names.room) } }
        let expectedKeys=Set(expected.slots.map {key($0.className,$0.weekday,$0.period)})
        guard expected.slots.count==680,expectedKeys.count==680 else { throw NSError(domain:"InvalidLiteralAssertions",code:1) }
        var mismatches=[[String:Any]](),matched=0
        for slot in expected.slots {
            let actual=observed[key(slot.className,slot.weekday,slot.period)] ?? []
            if actual==slot.lessons { matched+=1 }
            else {
                mismatches.append(["className":slot.className,"weekday":slot.weekday,"period":slot.period,
                    "expected":try object(slot.lessons),"actual":try object(actual)])
            }
        }
        let extra=observed.keys.filter {!expectedKeys.contains($0)}.sorted()
        let metadata=analysis.schoolYear==expected.schoolYear && analysis.term==expected.term
        let classes=Set(analysis.lessons.map(\.className))==Set(expected.classes)
        return ["assertionOnly":true,"expectedSHA256":expectedSHA,"literalSlotsAssessed":680,"literalSlotsMatched":matched,
            "mismatches":mismatches,"extraSlotKeys":extra,"yearAndTermMatch":metadata,"classesMatch":classes,
            "all680LiteralMatch":matched==680 && extra.isEmpty && metadata && classes,
            "limits":"Empty expected slots compare against actual parser absence only after complete Reader and parser success; not OCR/EMPTY quality proof"]
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count==6 else { throw NSError(domain:"Arguments",code:1) }
            let mode=CommandLine.arguments[1],prepared=URL(fileURLWithPath:CommandLine.arguments[2]),fixtures=URL(fileURLWithPath:CommandLine.arguments[3])
            let expectedURL=URL(fileURLWithPath:CommandLine.arguments[4]),expectedSHA=CommandLine.arguments[5]
            guard ["baseline","fixed"].contains(mode) else { throw NSError(domain:"Mode",code:1) }
            let inputData=try Data(contentsOf:prepared.appendingPathComponent("native-inputs.json"))
            let inputs=try JSONDecoder().decode(NativeInputs.self,from:inputData)
            guard inputs.schema==1,inputs.files.map(\.file)==files else { throw NSError(domain:"FiniteInputManifest",code:1) }
            let selected=mode=="baseline" ? Array(inputs.files.prefix(4)):inputs.files
            try emit(["type":"environment","mode":mode,"os":ProcessInfo.processInfo.operatingSystemVersionString,"deviceSystemVersion":UIDevice.current.systemVersion,
                "simulator":true,"nativeInputManifestSHA256":sha(inputData),"plannedReaderCalls":selected.count,
                "scope":"Independent generated vector PDFs only; actual production source APIs, no OCR/models or persistence",
                "ocrRequests":0,"modelInvocations":0,"qualityQualification":false])
            var attempted=0,returned=0,analyses=0,matches=0
            for fixture in selected {
                var acquired=await acquire(fixture,folder:fixtures,readerOnly:mode=="baseline")
                acquired.record["mode"]=mode
                if acquired.record["readerCallStarted"] as? Bool==true {attempted+=1}
                if acquired.record["readReturned"] as? Bool==true {returned+=1}
                if let analysis=acquired.analysis {
                    analyses+=1
                    do {
                        let assertion=try assertLiteral(analysis,expectedURL:expectedURL,expectedSHA:expectedSHA)
                        acquired.record["literalAssertion"]=assertion
                        if assertion["all680LiteralMatch"] as? Bool==true {matches+=1}
                    } catch { acquired.record["assertionError"]=failure(error) }
                }
                try emit(acquired.record)
            }
            try emit(["type":"summary","mode":mode,"plannedReaderCalls":selected.count,"recordedCases":selected.count,"attemptedReaderCalls":attempted,
                "readReturned":returned,"analysesReturned":analyses,"all680LiteralMatches":matches,
                "ocrRequests":0,"modelInvocations":0,"qualityQualification":false])
        } catch { try? emit(["type":"fatal","failure":failure(error),"qualityQualification":false]);exit(1) }
    }
}
