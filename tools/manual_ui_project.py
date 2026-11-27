"""Build the production manual UI in the existing isolated synthetic app project.

Only generated QA copies are instrumented. No production coordinator/view edits,
network requests, OCR/model invocations, or committed PDF/image/font inputs.
"""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from ui_test_manifest import MANUAL_CHECK_SOURCES, manual_check_source


def once(text, marker, replacement):
    if text.count(marker) != 1:
        raise ValueError("manual UI fixture insertion point missing or duplicated")
    return text.replace(marker, replacement)


def coordinator(text):
    fixture_failure = '    @Published private var fixtureFailure: String?'
    text = once(text, fixture_failure, fixture_failure + '\n    @Published private(set) var manualQAPreviewRevalidations = 0')
    verified = """                guard preview?.id == candidate.id else { throw CancellationError() }
                previewNeedsRevalidation = false
                running = false"""
    text = once(text, verified, verified + '''
                if SimulatorManualFixture.enabled {
                    manualQAPreviewRevalidations += 1
                    FixtureCITrace.mark("manual-preview-revalidation-complete")
                }''')
    marker = "    func start(_ kind: RecoveryDocumentKind) {"
    text = once(text, marker, marker + '''
        if SimulatorManualFixture.enabled {
            cancel(); running = true
            let fixtureOperation = self.operation
            task = Task { @MainActor in
                do {
                    let prepared = try await SimulatorManualFixture.prepare()
                    guard self.operation == fixtureOperation, !Task.isCancelled else { return }
                    SimulatorManualFixture.trace("stage=crop")
                    var images = [String:UIImage]()
                    for field in prepared.draft.fields {
                        guard let image = Self.crop(field.crop,raster:prepared.raster) else { throw PDFParseError(code:.unreadable) }
                        images[field.id] = image
                    }
                    manualContextImages = try Self.contextImages(prepared.draft,rasters:[1:prepared.raster])
                    previewRasters = [1:prepared.raster]
                    source = prepared.source; manualDraft = prepared.draft; manualImages = images
                    running = false; status = "原本と入力内容を照合してください。"
                } catch {
                    SimulatorManualFixture.failed(error)
                    guard self.operation == fixtureOperation else { return }
                    running = false; fixtureFailure = "架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"
                }
            }
            return
        }
''')
    submit_signature = '    func submitManual(_ values: [String:String], acknowledged:Set<String>) {'
    text = once(text, submit_signature, submit_signature + '\n        FixtureCITrace.mark("manual-submit-enter")')
    submit_guard = '              acknowledged == Set(draft.fields.map(\\.id)) else { return }'
    text = once(text, submit_guard, '''              acknowledged == Set(draft.fields.map(\\.id)) else {
            FixtureCITrace.mark("manual-submit-rejected"); return
        }
        FixtureCITrace.mark("manual-submit-accepted")''')
    text = once(text, '                manualReview = RecoveryManualReview(draftID:draft.id,candidate:candidate',
                '                if SimulatorManualFixture.enabled { SimulatorManualFixture.trace("stage=manual-review-ready") }\n                manualReview = RecoveryManualReview(draftID:draft.id,candidate:candidate')
    text = once(text, '                preview = review.candidate',
                '                if SimulatorManualFixture.enabled { SimulatorManualFixture.trace("stage=manual-preview-ready") }\n                preview = review.candidate')
    text = once(text, '                manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; self.source = nil',
                '                if SimulatorManualFixture.enabled { SimulatorManualFixture.failed(error) }\n                manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; self.source = nil')
    return text


def view(text):
    text = once(text, 'else { Text(coordinator.status) }',
                'else { Text(coordinator.status).accessibilityIdentifier("manual-status") }')
    text = once(text, '    @State private var selectedClass = ""', '''    @State private var selectedClass = ""
    @State private var manualQATypeSize:DynamicTypeSize = .large
    @State private var manualQAActionsPresented = false
    @State private var manualQARevalidationCount = 0
    @AppStorage("fixture.manualMutationComplete") private var manualQAMutationComplete = false''')
    text = once(text, '.navigationTitle(title)', '''.accessibilityIdentifier("manual-recovery-list")
            .navigationTitle(title)
            .onAppear { FixtureCITrace.mark("manual-screen-appeared") }
            .onDisappear { FixtureCITrace.mark("manual-screen-disappeared") }
            .dynamicTypeSize(manualQATypeSize)
            .toolbar { ToolbarItem(placement:.topBarTrailing) {
                Button("架空検証") { manualQAActionsPresented = true }
            } }
            .confirmationDialog("架空検証", isPresented: $manualQAActionsPresented) {
                Button("表示サイズを変更") { manualQATypeSize = manualQATypeSize == .large ? .xxxLarge : .large }
                Button("同じ原本の状態を再確認") {
                    coordinator.invalidateManualIfSourceChanged()
                    manualQARevalidationCount += 1
                }
                Button("架空原本のハッシュを変更") { Task { try await SimulatorManualFixture.changeOriginal(); manualQAMutationComplete = true } }
            }
            .background(alignment: .topLeading) {
                if SimulatorManualFixture.enabled {
                    VStack { FixtureManualProbe()
                        Text(SimulatorManualFixture.processIdentity).font(.system(size:1))
                            .accessibilityIdentifier("manual-process-launch").allowsHitTesting(false)
                        Text(manualQATypeSize == .xxxLarge ? "expanded" : "standard")
                            .font(.system(size:1)).accessibilityIdentifier("manual-fixture-type-size").allowsHitTesting(false)
                        Text(String(manualQARevalidationCount))
                            .font(.system(size:1)).accessibilityIdentifier("manual-fixture-revalidations").allowsHitTesting(false)
                        Text("preview=\\(coordinator.preview != nil);review=\\(coordinator.manualReview != nil);running=\\(coordinator.running);draft=\\(coordinator.manualDraft?.id ?? "nil");revalidation=\\(coordinator.previewNeedsRevalidation);revalidations=\\(coordinator.manualQAPreviewRevalidations);failure=\\(coordinator.failure ?? "none")")
                            .font(.system(size:1)).accessibilityIdentifier("manual-coordinator-state").allowsHitTesting(false)
                        if manualQAMutationComplete { Text("変更完了").accessibilityIdentifier("manual-mutation-complete").allowsHitTesting(false) }
                        if let draft = coordinator.manualDraft {
                            Text(draft.fields.map { field in
                                field.id + "=" + (manualValues[field.id] ?? field.originalText) + ";ack=" + String(manualAcknowledged[field.id] ?? false)
                            }.joined(separator:"|"))
                                .font(.system(size:1)).accessibilityIdentifier("manual-input-state").allowsHitTesting(false)
                            Text(draft.fields.map(\\.id).joined(separator:"|"))
                                .font(.system(size:1)).accessibilityIdentifier("manual-field-ids").allowsHitTesting(false)
                        }
                    }
                    .accessibilityElement(children:.contain)
                    .accessibilityIdentifier("manual-observation")
                    .allowsHitTesting(false)
                }
            }''')
    field_setter = 'RecoveryManualInput.update($0,id:field.id,original:field.originalText,values:&manualValues,acknowledged:&manualAcknowledged)'
    text = once(text, field_setter, 'SimulatorManualFixture.event("text",id:field.id,old:manualValues[field.id] ?? field.originalText,new:$0); ' + field_setter)
    clear_setter = 'RecoveryManualInput.update("",id:field.id,original:field.originalText,values:&manualValues,acknowledged:&manualAcknowledged)'
    text = once(text, clear_setter, 'SimulatorManualFixture.event("clear",id:field.id,old:manualValues[field.id] ?? field.originalText,new:""); ' + clear_setter)
    clear_guard = 'guard useAiFeatures, !coordinator.running, coordinator.manualDraft?.id == draft.id, coordinator.manualReview == nil else { return }'
    clear_rejected = 'if !(useAiFeatures && !coordinator.running && coordinator.manualDraft?.id == draft.id && coordinator.manualReview == nil) { SimulatorManualFixture.event("clear-rejected",id:field.id,old:String(coordinator.manualDraft?.id == draft.id),new:String(useAiFeatures && !coordinator.running && coordinator.manualReview == nil)) }; '
    text = once(text, clear_guard, clear_rejected + clear_guard)
    acknowledgement = 'manualAcknowledged[field.id] = newAcknowledgement'
    text = once(text, acknowledgement,
                'SimulatorManualFixture.event("ack",id:field.id,old:String(manualAcknowledged[field.id] ?? false),new:String(newAcknowledgement)); ' + acknowledgement)
    text = once(text, '.onChange(of:coordinator.manualDraft?.id) { _,_ in', '.onChange(of:coordinator.manualDraft?.id) { old,new in SimulatorManualFixture.event("draft",id:"snapshot",old:old ?? "nil",new:new ?? "nil")')
    text = once(text, 'Section("採用する資料全体") {', 'Section {')
    text = once(text, '        }\n        Section("読み取り結果") {', '        } header: { Text("採用する資料全体").accessibilityIdentifier("manual-preview-header") }\n        Section("読み取り結果") {')
    text = once(text, '.autocorrectionDisabled().textInputAutocapitalization(.never).disabled(!useAiFeatures || coordinator.running)',
                '.autocorrectionDisabled().textInputAutocapitalization(.never).disabled(!useAiFeatures || coordinator.running).accessibilityIdentifier("manual-value-" + field.id)')
    marker = '                            .accessibilityAddTraits(acknowledged ? .isSelected : [])'
    text = once(text, marker, marker + '.accessibilityIdentifier("manual-ack-" + field.id)')
    text = once(text, '.accessibilityLabel("原本の該当箇所")', '.accessibilityLabel("原本の該当箇所").accessibilityIdentifier("manual-crop-" + field.id)')
    submit_action = '                            coordinator.submitManual(Dictionary('
    text = once(text, submit_action, '                            FixtureCITrace.mark("manual-submit-action")\n' + submit_action)
    text = once(text, '                        }.buttonStyle(.glassProminent)\n                            .disabled(!useAiFeatures || coordinator.running || draft.fields.contains',
                '                        }.buttonStyle(.glassProminent).accessibilityIdentifier("manual-submit")\n                            .disabled(!useAiFeatures || coordinator.running || draft.fields.contains')
    review_submit = 'Button("訂正と変更を確認して資料全体へ",systemImage:"doc.text.magnifyingglass") { coordinator.showManualPreview() }'
    text = once(text, review_submit, review_submit + '.accessibilityIdentifier("manual-review-submit")')
    zoom_marker = 'Button("対象セルを拡大して確認",systemImage:"plus.magnifyingglass") { zoomedField = field.id }'
    if text.count(zoom_marker) != 2:
        raise ValueError("manual source zoom insertion point missing or duplicated")
    text = text.replace(zoom_marker, zoom_marker + '.accessibilityIdentifier("manual-zoom-" + field.id)')
    text = once(text, 'Text("この段階では採用しません。入力した本文と、比較できる前回の結果からの変更を確認してください。")',
                'Text("この段階では採用しません。入力した本文と、比較できる前回の結果からの変更を確認してください。").accessibilityIdentifier("manual-review-header")')
    text = once(text, 'Text(review.candidate.result.humanCorrections?.first(where:{ $0.target == field.target })?.value ?? "")',
                'Text(review.candidate.result.humanCorrections?.first(where:{ $0.target == field.target })?.value ?? "").accessibilityIdentifier("manual-reviewed-" + field.id)')
    text = once(text, 'Text(review.comparison.changes.isEmpty ? "比較できる本文に変更はありません。" : "本文の変更: \\(review.comparison.changes.count)箇所")',
                'Text(review.comparison.changes.isEmpty ? "比較できる本文に変更はありません。" : "本文の変更: \\(review.comparison.changes.count)箇所").accessibilityIdentifier("manual-comparison-available")')
    text = once(text, 'Text("前回の結果とは比較できません。年度・対象・本文の範囲を一致させて確認できないため、変更箇所は推測しません。")',
                'Text("前回の結果とは比較できません。年度・対象・本文の範囲を一致させて確認できないため、変更箇所は推測しません。").accessibilityIdentifier("manual-comparison-unavailable")')
    text = once(text, 'Text("前回: \\(lessons(change.before))")', 'Text("前回: \\(lessons(change.before))").accessibilityIdentifier("manual-change-before")')
    text = once(text, 'Text("今回: \\(lessons(change.after))")', 'Text("今回: \\(lessons(change.after))").accessibilityIdentifier("manual-change-after")')
    text = once(text, 'Slider(value:$zoom,in:1...4,step:0.5) { Text("原画像の拡大率") }',
                'Slider(value:$zoom,in:1...4,step:0.5) { Text("原画像の拡大率") }.accessibilityIdentifier("manual-source-zoom")')
    zoom_controls = '                }.padding(.horizontal)\n                GeometryReader { geometry in'
    text = once(text, zoom_controls, zoom_controls.replace('}.padding(.horizontal)',
                '}.padding(.horizontal).accessibilityElement(children:.contain).accessibilityIdentifier("manual-source-controls")'))
    scroll_end = '                            .padding(16)\n                    }\n                }\n            }\n            .navigationTitle("原画像の確認")'
    text = once(text, scroll_end, scroll_end.replace('                    }', '                    }.accessibilityIdentifier("manual-source-scroll")', 1))
    text = once(text, '.accessibilityElement().accessibilityLabel("訂正する本文の範囲")',
                '.accessibilityElement().accessibilityLabel("訂正する本文の範囲").accessibilityIdentifier("manual-source-highlight")')
    text = once(text, '.accessibilityLabel("原本の対象セル・訂正箇所を強調")',
                '.accessibilityLabel("原本の対象セル・訂正箇所を強調").accessibilityIdentifier("manual-source-context")')
    text = once(text, 'Text("\\(zoom,format:.number.precision(.fractionLength(1)))倍").monospacedDigit()',
                'Text("\\(zoom,format:.number.precision(.fractionLength(1)))倍").monospacedDigit().accessibilityIdentifier("manual-source-scale")')
    return text


def application(text):
    marker = '        if ProcessInfo.processInfo.arguments.contains("--recovery-preview") { LocalAIFeaturePolicy.setEnabled(true); try SimulatorRecoveryFixture.seed(base) }'
    text = once(text, marker, marker + '\n        if SimulatorManualFixture.enabled { try SimulatorManualFixture.seed(base) }')
    # The comparable prior uses the actual builder after the first QA window
    # exists. Keep model/store consumers absent until both prior and source commit.
    text = once(text, '    @State private var applicationReady = false',
                '    @State private var applicationReady = false\n    @State private var manualSeedComplete = !SimulatorManualFixture.requiresAsyncSeed\n    @State private var manualSeedError:String?')
    text = once(text, '        WindowGroup {\n            ContentView()',
                '        WindowGroup {\n            if manualSeedComplete {\n            ContentView()')
    text = once(text, '        }\n        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {', '''            } else {
                VStack {
                    ProgressView("架空資料を準備中")
                    if let manualSeedError { Text(manualSeedError).accessibilityIdentifier("manual-seed-failure") }
                }.task {
                    guard manualSeedError == nil else { return }
                    do { try await SimulatorManualFixture.finishAsyncSeed(); manualSeedComplete = true }
                    catch { SimulatorManualFixture.failed(error); manualSeedError = String(reflecting:error) }
                }
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {''')
    probe_marker = '                            if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") { FixtureSelectionProbe() }'
    text = once(text, probe_marker, probe_marker + '\n                            if SimulatorManualFixture.enabled { FixtureManualProbe().accessibilityElement(children:.contain).accessibilityIdentifier("manual-root-observation").allowsHitTesting(false) }')
    text += '\n' + (ROOT / "tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
    return text


def generate(destination, source_root=ROOT):
    source_root = Path(source_root).resolve()
    spec = importlib.util.spec_from_file_location("app_test_project", source_root / "tools/app_test_project.py")
    sys.path.insert(0, str(source_root / "tools"))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    manual_check_source(ROOT)
    module.generate(destination, check_sources=MANUAL_CHECK_SOURCES, check_root=ROOT)
    destination = Path(destination)
    app = destination / "Takupoke"
    for file, title, identifier in (("SettingsView.swift", '"設定"', "manual-settings-list"),
                                    ("MaterialsView.swift", '"時間割ファイル"', "manual-materials-list"),
                                    ("PDFAnalysisView.swift", "kind.title", "manual-analysis-list")):
        path = app / file
        anchor = f".navigationTitle({title})"
        path.write_text(once(path.read_text(encoding="utf-8"), anchor,
                             f'.accessibilityIdentifier("{identifier}")' + anchor), encoding="utf-8")
    path = app / "PDFAnalysisView.swift"
    sheet_dismiss = '.sheet(isPresented:$showingRecovery,onDismiss:{ ApplicationData.shared.recovery.cancel() })'
    sheet_observation = '.sheet(isPresented:$showingRecovery,onDismiss:{\n            FixtureCITrace.mark("manual-sheet-dismissed")\n            ApplicationData.shared.recovery.cancel()\n        })'
    path.write_text(once(path.read_text(encoding="utf-8"), sheet_dismiss, sheet_observation), encoding="utf-8")
    path = app / "PDFRecoveryCoordinator.swift"; path.write_text(coordinator(path.read_text(encoding="utf-8")), encoding="utf-8")
    path = app / "PDFRecoveryView.swift"; path.write_text(view(path.read_text(encoding="utf-8")), encoding="utf-8")
    path = app / "TakupokeApp.swift"; path.write_text(application(path.read_text(encoding="utf-8")), encoding="utf-8")


if __name__ == "__main__":
    generate(sys.argv[1], Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT)
