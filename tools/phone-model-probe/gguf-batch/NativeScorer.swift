// Appended only in an owned research copy of this existing test source.
// No production source or Rules branch is modified to force a Provider call.
extension PDFParsingTests {
    func testParallelGGUFNativeCertificateControl() async throws {
        let directory=try XCTUnwrap(ProcessInfo.processInfo.environment["IOS_GGUF_WORK"])
        let url=URL(fileURLWithPath:directory)
        let raw=try JSONSerialization.jsonObject(with:Data(contentsOf:url.appendingPathComponent("batch-report.json"))) as! [String:Any]
        let rows=raw["results"] as? [[String:Any]] ?? []
        let immutable=try preparedStructureInput(),request=try XCTUnwrap(immutable.requests.first)
        // This fixed preparation predates the bounded Rules change. It remains
        // useful as a component certificate control, never an AI-needed example.
        XCTAssertNotNil(RecoveryStructure.cheap(request))
        let page=foldedPage(),hash=immutable.document.pdfHash
        let baselineDoc=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash)
        let baseline=try await RecoveryEngine.run(baselineDoc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        let expected=try XCTUnwrap(baseline.result)
        XCTAssertEqual(baseline.state,.awaitingConfirmation)
        XCTAssertTrue(RecoveryValidator.validate(baselineDoc,expected).canAdopt)
        let modes=(raw["promptVariants"] as? [String:String]).map { $0.keys.sorted() } ?? ["baseline"]
        var evaluations=[[String:Any]]()
        for mode in modes {
            var report:[String:Any]=["variant":mode,"scope":"One original geometry component control plus complete ordinary timetable rebuild; other raw cases are text-only. Current ordinary/exam/return Rules controls are separately tested. No production adapter or useful AI denominator.","currentRulesResolved":true,"modelNecessary":false,"certificateAccepted":false,"wholeTimetableExact":false,"schemaVersion":RecoveryValidator.schemaVersion,"validatorVersion":RecoveryValidator.version]
            func required<T>(_ value:T?) throws -> T { guard let value else { throw RecoveryProviderError.invalidOutput };return value }
            do {
                let row=try required(rows.first { $0["case"] as? String == "original-certificate-control" && ($0["variant"] as? String ?? "baseline") == mode })
                guard row["nativeStatus"] as? Int == 0,row["decoderAccepted"] as? Bool == true,let labels=row["decoded"] as? [String:[String]] else { throw RecoveryProviderError.invalidOutput }
                func field(_ role:String) throws -> RecoveryField {
                    let ids=try required(labels[role])
                    guard (1...48).contains(ids.count),Set(ids).count == ids.count else { throw RecoveryProviderError.invalidOutput }
                    let units=try ids.map { id in try required(request.units.first { $0.id == id }) }
                    let bounds=try RecoveryStructure.bounds(units.flatMap(\.glyphs))
                    let top=try required(request.cuts.filter { $0.axis == "horizontal" && $0.position <= bounds.y }.max { $0.position < $1.position })
                    let bottom=try required(request.cuts.filter { $0.axis == "horizontal" && $0.position >= bounds.y+bounds.height }.min { $0.position < $1.position })
                    let left=try required(request.cuts.filter { $0.axis == "vertical" && $0.position >= bounds.x+bounds.width }.min { $0.position < $1.position })
                    return RecoveryField(state:.present,value:"",evidence:ids+[top.id,bottom.id,left.id])
                }
                let proposal=[RecoveryLesson(subject:try field("subject"),teacher:try field("teacher"),room:try field("room"),dateEvidence:[],periodEvidence:[])]
                _=try RecoveryStructure.verify(request,proposal)
                report["certificateAccepted"]=true
                let document=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash,structureProposals:[request.id:proposal])
                let run=try await RecoveryEngine.run(document,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
                if var result=run.result {
                    result.metadata=expected.metadata
                    let actualHash=try RecoveryValidator.fingerprint(result),expectedHash=try RecoveryValidator.fingerprint(expected)
                    report["wholeTimetableExact"]=run.state == .awaitingConfirmation && RecoveryValidator.validate(document,result).canAdopt && actualHash == expectedHash
                }
            } catch { report["rejectionType"]=String(describing:type(of:error)) }
            evaluations.append(report)
        }
        try JSONSerialization.data(withJSONObject:["scope":"Same actual source geometry certificate and complete unchanged timetable pipeline for each shared prompt; useful AI denominator zero","currentRulesResolved":true,"variants":evaluations],options:[.prettyPrinted,.sortedKeys]).write(to:url.appendingPathComponent("native-certificate.json"))
    }
}
