"""Build the production manual UI in the existing isolated synthetic app project.

Only generated QA copies are instrumented. No production coordinator/view edits,
network requests, OCR/model invocations, or committed PDF/image/font inputs.
"""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def once(text, marker, replacement):
    if text.count(marker) != 1:
        raise ValueError("manual UI fixture insertion point missing or duplicated")
    return text.replace(marker, replacement)


def coordinator(text):
    marker = "    func start(_ kind: RecoveryDocumentKind) {"
    return once(text, marker, marker + '''
        if SimulatorManualFixture.enabled {
            cancel(); failure = nil; running = true
            let fixtureOperation = self.operation
            task = Task { @MainActor in
                do {
                    let prepared = try await SimulatorManualFixture.prepare()
                    guard self.operation == fixtureOperation, !Task.isCancelled else { return }
                    print("TAKUPOKE-MANUAL-QA stage=crop")
                    var images = [String:UIImage]()
                    for field in prepared.draft.fields {
                        guard let image = Self.crop(field.crop,raster:prepared.raster) else { throw PDFParseError(code:.unreadable) }
                        images[field.id] = image
                    }
                    source = prepared.source; manualDraft = prepared.draft; manualImages = images
                    running = false; status = "原本と入力内容を照合してください。"
                } catch {
                    print("TAKUPOKE-MANUAL-QA failure=\\(String(reflecting:error))")
                    guard self.operation == fixtureOperation else { return }
                    running = false; failure = "架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"
                }
            }
            return
        }
''')


def view(text):
    text = once(text, '    @State private var selectedClass = ""', '    @State private var selectedClass = ""\n    @State private var manualQATypeSize:DynamicTypeSize = .large\n    @AppStorage("fixture.manualMutationComplete") private var manualQAMutationComplete = false')
    text = once(text, '.navigationTitle(title)', '''.navigationTitle(title)
            .dynamicTypeSize(manualQATypeSize)
            .toolbar { ToolbarItem(placement:.topBarTrailing) {
                Menu("架空検証") {
                    Button("表示サイズを変更") { manualQATypeSize = manualQATypeSize == .large ? .xxxLarge : .large }
                    Button("同じ原本の状態を再確認") { coordinator.invalidateManualIfSourceChanged() }
                    Button("架空原本のハッシュを変更") { Task { try await SimulatorManualFixture.changeOriginal(); manualQAMutationComplete = true } }
                }
            } }
            .overlay(alignment: .topLeading) {
                if SimulatorManualFixture.enabled {
                    VStack { FixtureManualProbe()
                        if manualQAMutationComplete { Text("変更完了").accessibilityIdentifier("manual-mutation-complete") }
                        if let draft = coordinator.manualDraft {
                            Text(draft.fields.map(\\.id).joined(separator:"|"))
                                .font(.system(size:1)).accessibilityIdentifier("manual-field-ids").allowsHitTesting(false)
                        }
                    }
                }
            }''')
    text = once(text, '.autocorrectionDisabled().textInputAutocapitalization(.never).disabled(coordinator.running)',
                '.autocorrectionDisabled().textInputAutocapitalization(.never).disabled(coordinator.running).accessibilityIdentifier("manual-value-" + field.id)')
    marker = '''                            Toggle("原本と一致することを確認",isOn:Binding(get:{ manualAcknowledged[field.id] ?? false },set:{ manualAcknowledged[field.id] = $0 }))
                                .disabled(coordinator.running)'''
    text = once(text, marker, marker + '.accessibilityIdentifier("manual-ack-" + field.id)')
    text = once(text, '.accessibilityLabel("原本の該当箇所")', '.accessibilityLabel("原本の該当箇所").accessibilityIdentifier("manual-crop-" + field.id)')
    text = once(text, '                        }.buttonStyle(.glassProminent)\n                            .disabled(coordinator.running || draft.fields.contains',
                '                        }.buttonStyle(.glassProminent).accessibilityIdentifier("manual-submit")\n                            .disabled(coordinator.running || draft.fields.contains')
    return text


def generate(destination, source_root=ROOT):
    source_root = Path(source_root).resolve()
    spec = importlib.util.spec_from_file_location("app_test_project", source_root / "tools/app_test_project.py")
    sys.path.insert(0, str(source_root / "tools"))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    module.generate(destination)
    destination = Path(destination)
    app = destination / "Takupoke"
    path = app / "PDFRecoveryCoordinator.swift"; path.write_text(coordinator(path.read_text(encoding="utf-8")), encoding="utf-8")
    path = app / "PDFRecoveryView.swift"; path.write_text(view(path.read_text(encoding="utf-8")), encoding="utf-8")
    path = app / "TakupokeApp.swift"; text = path.read_text(encoding="utf-8")
    marker = '        if ProcessInfo.processInfo.arguments.contains("--recovery-preview") { try SimulatorRecoveryFixture.seed(base) }'
    text = once(text, marker, marker + '\n        if SimulatorManualFixture.enabled { try SimulatorManualFixture.seed(base) }')
    probe_marker = '                            if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") { FixtureSelectionProbe() }'
    text = once(text, probe_marker, probe_marker + '\n                            if SimulatorManualFixture.enabled { FixtureManualProbe() }')
    text += '\n' + (ROOT / "tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
    path.write_text(text, encoding="utf-8")
    project = destination / "AppChecks.xcodeproj/project.pbxproj"
    text = project.read_text(encoding="utf-8")
    text = once(text, str(source_root / "tests/ui/ApplicationChecks.swift"), str(ROOT / "tests/ui/ManualAssistanceChecks.swift"))
    project.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    generate(sys.argv[1], Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT)
