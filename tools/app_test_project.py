"""Build the real app UI with synthetic local stores in an isolated project."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from picker_test_project import generate as generate_picker
from ui_test_manifest import CHECK_SOURCES, FIXTURE_SOURCES


def add_swift_sources(project, target, paths, prefix):
    objects = project['objects']
    phases = [objects[key] for key in objects[target]['buildPhases']
              if objects[key]['isa'] == 'PBXSourcesBuildPhase']
    if len(phases) != 1:
        raise ValueError('Expected one Swift sources phase for the selected target')
    group = objects[objects[project['rootObject']]['mainGroup']]
    for index, path in enumerate(paths, start=1):
        reference = f'{prefix}0{index:021X}'
        build_file = f'{prefix}1{index:021X}'
        if reference in objects or build_file in objects:
            raise ValueError('Duplicate generated Swift source identifier')
        objects[reference] = dict(isa='PBXFileReference', lastKnownFileType='sourcecode.swift',
                                  path=str(path), sourceTree='<absolute>')
        objects[build_file] = dict(isa='PBXBuildFile', fileRef=reference)
        phases[0]['files'].append(build_file)
        group['children'].append(reference)

def instrument_events_cache(text):
    marker = '    func refreshAtStartup() {'
    assert text.count(marker) == 1, 'Events cache fixture insertion point missing'
    return text.replace(marker, marker + '''
        if ProcessInfo.processInfo.arguments.contains("--events-cache-corrupt") ||
            ProcessInfo.processInfo.arguments.contains("--events-cache-probe") ||
            SimulatorEventsYearFixture.enabled {
            loadIfNeeded()
            return
        }
''')

def rewrite_network_urls(text):
    # These are XML identifiers, never network destinations. Keep the real XLSX
    # namespace checks while the fixture URLProtocol still denies all network I/O.
    namespaces = {
        'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
        'http://schemas.openxmlformats.org/package/2006/relationships',
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    }
    return re.sub(r'https?://[^"\s)]+',
                  lambda match: match[0] if match[0] in namespaces else 'https://fixture.example.test', text)

NATIVE_OCR_DIAGNOSTIC = r'''
                    if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                        let captured = lines.last?.candidates.first
                        let detail = captured.map {
                            let text = $0.text
                            let confidence = String($0.confidence)
                            let candidateBox = String(describing: $0.lineRange)
                            let observationBox = String(describing: $0.observationRange)
                            return "\(text) confidence=\(confidence) candidateBox=\(candidateBox) observationBox=\(observationBox)"
                        } ?? "no-top1"
                        let previous = UserDefaults.standard.stringArray(forKey: "fixture.nativeOCRCandidates") ?? []
                        UserDefaults.standard.set(previous + [detail], forKey: "fixture.nativeOCRCandidates")
                        if let probe = captured {
                            UserDefaults.standard.set(probe.text, forKey: "fixture.nativeOCRText")
                            UserDefaults.standard.set(probe.confidence, forKey: "fixture.nativeOCRConfidence")
                        }
                        print("SYNTHETIC_NATIVE_OCR " + detail)
                    }
'''

def instrument_native_ocr(text):
    # Record only the captured page-level top1 after unchanged top-five capture.
    # Hierarchy cell lines are separate observations and never duplicate this log.
    marker = '                lines.append(try captureLine(line, order: lines.count, hierarchy: false))'
    assert text.count(marker) == 1, 'Native OCR probe insertion point missing'
    return text.replace(marker, marker + NATIVE_OCR_DIAGNOSTIC)

AI_SWITCH_BEFORE = 'FixtureLaunchDiagnostics.recordAIChange($0, phase: "before"); '
AI_SWITCH_AFTER = '; FixtureLaunchDiagnostics.recordAIChange($0, phase: "after")'

def instrument_ai_switch(text):
    # Observe the unchanged production setter only in the disposable app copy.
    marker = 'useAiFeatures = $0; LocalAIFeaturePolicy.setEnabled($0)'
    assert text.count(marker) == 1, 'AI switch setter diagnostic insertion point missing'
    return text.replace(marker, AI_SWITCH_BEFORE + marker + AI_SWITCH_AFTER)

NOTIFICATION_BINDING_TRACE = ('FixtureLaunchDiagnostics.record(value ? '
                              '"notification-on-binding" : "notification-off-binding"); ')

def instrument_notification_switch(text):
    marker = 'set: { value in\n                    Task {'
    assert text.count(marker) == 2, 'Notification switch binding insertion points missing'
    return text.replace(marker, marker.replace('Task {', NOTIFICATION_BINDING_TRACE + 'Task {'))

def generate(destination, check_sources=CHECK_SOURCES, check_root=None):
    repo = Path(__file__).resolve().parents[1]
    check_root = repo if check_root is None else Path(check_root)
    destination = Path(destination)
    # Reuse the standard UITest target/scheme machinery, not a second app UI.
    generate_picker(destination)
    generated = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(destination/'PickerChecks.xcodeproj/project.pbxproj')]))
    real = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(repo/'Takupoke.xcodeproj/project.pbxproj')]))
    copied = destination/'Takupoke'
    shutil.copytree(repo/'Takupoke', copied)
    # The real project also uses local bridge packages and build phases.
    # Preserve those relative references in this isolated app; never rely on
    # the working tree being adjacent to the temporary project.
    shutil.copytree(repo/'Vendor', destination/'Vendor', ignore=shutil.ignore_patterns('.build', '.swiftpm'))
    (destination/'tools').mkdir(exist_ok=True)
    for script in ('prepare-llama-runtime.py', 'prepare-coreai-runtime.py'):
        shutil.copyfile(repo/'tools'/script, destination/'tools'/script)
    for path in copied.glob('*.swift'):
        text = path.read_text()
        if path.name == 'NotificationSettingsView.swift':
            text = instrument_notification_switch(text)
        # A URLProtocol below rejects every request. Rewrite URLs as a second
        # guard against any production communication from the test app.
        text = rewrite_network_urls(text)
        text = re.sub(r'(\b(?:let|var) (\w+) = URLSessionConfiguration\.(?:ephemeral|default))',
                      lambda match: match[1] + "\n        " + match[2] + ".protocolClasses = [FixtureNetwork.self]", text)
        if path.name == 'SchoolEventsModel.swift':
            text = instrument_events_cache(text)
        if path.name == 'ScopedMaterialSelection.swift':
            # The synthetic workbook is owned by this sandbox, not a real File
            # Provider. Substitute only the lease boundary in this disposable copy;
            # acquisition, hashing, XLSX parsing and persistence remain unchanged.
            marker = 'guard granted else { throw MaterialError.accessExpired }'
            assert text.count(marker) == 1, 'Synthetic workbook lease insertion point missing'
            text = text.replace(marker, 'guard granted || SimulatorChangeRowSkipFixture.owns(url) else { throw MaterialError.accessExpired }')
        if path.name == 'SettingsView.swift':
            text = instrument_ai_switch(text)
        if path.name in ('TimetableView.swift', 'TimetableView+Navigation.swift'):
            text = text.replace('SchoolDate.today()', '(SimulatorEventsYearFixture.enabled ? SimulatorEventsYearFixture.day : (ProcessInfo.processInfo.arguments.contains("--selection-snapshot") ? SimulatorSelectionFixture.day : SchoolDate.today()))')
        if path.name == 'HomeTodayView.swift':
            marker = 'private var day: SchoolDate { TimetableDaySchedule.schoolDay(at: now) }'
            assert text.count(marker) == 1, 'Home selection date probe insertion point missing'
            text = text.replace(marker, 'private var day: SchoolDate { SimulatorEventsYearFixture.enabled ? SimulatorEventsYearFixture.day : (ProcessInfo.processInfo.arguments.contains("--selection-snapshot") ? SimulatorSelectionFixture.day : TimetableDaySchedule.schoolDay(at: now)) }')
            selection_marker = '                    selectedLesson = LessonSelection(lesson: lesson, date: day,'
            assert text.count(selection_marker) == 1, 'Home detail selection diagnostic insertion point missing'
            text = text.replace(selection_marker, '''                    if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") {
                        SimulatorSelectionFixture.recordTrace("SYNTHETIC_SELECTION_HOME tap " + lesson.names.subject + " revision=" + String(describing: detailRevision))
                    }
''' + selection_marker)
            revision_marker = '        .onChange(of: detailRevision) { _ in'
            assert text.count(revision_marker) == 1, 'Home detail revision diagnostic insertion point missing'
            text = text.replace(revision_marker, revision_marker + '''
            if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") {
                SimulatorSelectionFixture.recordTrace("SYNTHETIC_SELECTION_HOME reset selected=" + (selectedLesson?.lesson.names.subject ?? "none") + " revision=" + String(describing: detailRevision))
            }
''')
        if path.name == 'HomeView.swift':
            sheet_marker = '                NavigationStack { presentation.lessonDetail(selection) }'
            assert text.count(sheet_marker) == 1, 'Home detail presentation diagnostic insertion point missing'
            text = text.replace(sheet_marker, sheet_marker + '''
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") { SimulatorSelectionFixture.recordTrace("SYNTHETIC_SELECTION_HOME sheet appeared " + selection.lesson.names.subject) }
                }
''')
        if path.name == 'TimetablePresentation+Details.swift':
            marker = '.navigationBarTitleDisplayMode(.inline)'
            assert text.count(marker) == 3, 'Selection snapshot controls insertion point missing'
            text = text.replace(marker, marker + '''
        .safeAreaInset(edge: .bottom) {
            if ProcessInfo.processInfo.arguments.contains("--selection-snapshot") { FixtureSelectionMutationControls() }
        }
''')
        if path.name == 'PDFRecoveryCoordinator.swift':
            marker = '    func start(_ kind: RecoveryDocumentKind) {'
            assert marker in text, 'Recovery UI fixture insertion point missing'
            text = text.replace(marker, marker + '\n' + """
        if ProcessInfo.processInfo.arguments.contains("--recovery-preview") {
            cancel(); failure = nil; running = true
            let fixtureOperation = self.operation
            task = Task { @MainActor in
                do {
                    let prepared = try await SimulatorRecoveryFixture.preview(kind)
                    guard self.operation == fixtureOperation, !Task.isCancelled else { return }
                    source = prepared.source; preview = prepared; running = false; status = "採用前に元のPDFと内容を確認してください。"
                } catch {
                    guard self.operation == fixtureOperation else { return }
                    running = false; failure = "架空復旧fixtureを準備できませんでした: " + String(describing: error)
                }
            }
            return
        }
""")
        if path.name == 'PDFRecoveryView.swift':
            marker = '.navigationTitle(title)'
            assert marker in text, 'Recovery preview probe insertion point missing'
            text = text.replace(marker, ' .accessibilityIdentifier("fixture-recovery-list")\n' + marker + """
            .overlay(alignment: .topLeading) {
                if ProcessInfo.processInfo.arguments.contains("--recovery-preview") { FixtureRecoveryProbe() }
            }
""")
        if path.name == 'PDFRecoveryRecognition.swift':
            raster_marker = '            let raster = try RecoveryRasterGrid.fromRGBA(width: cg.width, height: cg.height, pixels: rgba, check: check)'
            assert raster_marker in text, 'Native raster probe insertion point missing'
            text = text.replace(raster_marker, raster_marker + '\n' + '''            if ProcessInfo.processInfo.arguments.contains("--recovery-ocr-probe") {
                if let mode = UserDefaults.standard.string(forKey: "fixture.nativeCropMode") {
                    let proof = SimulatorRecoveryOCRFixture.cropRasterProof(raster, clipped: mode == "cropped")
                    UserDefaults.standard.set(proof, forKey: "fixture.nativeCropRasterProof")
                    print("SYNTHETIC_NATIVE_CROP_RASTER " + proof)
                } else {
                    let proof = SimulatorRecoveryOCRFixture.rasterProof(raster)
                    UserDefaults.standard.set(proof, forKey: "fixture.nativeRasterProof")
                    print("SYNTHETIC_NATIVE_RASTER " + proof)
                }
            }
''')
        if path.name == 'RecoveryVisionCapture.swift':
            text = instrument_native_ocr(text)
        if path.name == 'TimetableView.swift':
            marker = 'struct TimetableView: View {'
            assert marker in text
            text = text.replace(marker, marker + '''
    @State var fixtureHeaderFrames: [String: CGRect] = [:]
    @State var fixtureEventSizes: [String: CGSize] = [:]
    @State var fixtureCardFrames: [String: CGRect] = [:]
''')
        if path.name == 'TimetableView+GridHeaders.swift':
            marker = next(line for line in text.splitlines() if '.accessibilityIdentifier("timetable-day-' in line)
            text = text.replace(marker, marker + '''
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("fixture-grid")) } action: { frame in
                guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                if fixtureHeaderFrames[column.day.iso8601] != frame {
                    fixtureHeaderFrames[column.day.iso8601] = frame
                }
            }
''')
        if path.name == 'TimetableView+DayColumns.swift':
            marker = next(line for line in text.splitlines() if '.accessibilityIdentifier("timetable-event-' in line)
            text = text.replace(marker, marker + '''
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                if fixtureEventSizes[title] != size { fixtureEventSizes[title] = size }
            }
''')
            # The observer must be inside offset so its frame includes the
            # ancestor's translation, rather than measuring offset's layout box.
            marker = next(line for line in text.splitlines() if '.offset(x: CGFloat(entry.lane)' in line)
            text = text.replace(marker, '''
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("fixture-grid")) } action: { frame in
                        guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                        let key = fixtureCardKey(on: day, className: className, entry: entry)
                        if fixtureCardFrames[key] != frame { fixtureCardFrames[key] = frame }
                    }
''' + marker)
        if path.name == 'TimetableView+Grid.swift':
            marker = next(line for line in text.splitlines() if '.accessibilityLabel(' in line and 'の週の時間割' in line)
            assert marker in text, 'Timetable grid probe insertion point missing'
            text = text.replace(marker, marker + '''
        .coordinateSpace(name: "fixture-grid")
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("--grid-probe") {
                Text("grid metrics").font(.system(size: 1)).foregroundStyle(.clear)
                    .accessibilityIdentifier("fixture-grid-metrics")
                    .accessibilityValue(fixtureGridMetrics(columns: columns, days: days, heights: rowHeights))
                    .allowsHitTesting(false)
            }
        }
        ''')
        path.write_text(text)
    shutil.copyfile(repo/'tests/ui/ApplicationFixture.swift',copied/'TakupokeApp.swift')
    actual = {path.name for path in (repo/'tests/ui').glob('ApplicationFixture*.swift')}
    if actual != set(FIXTURE_SOURCES):
        raise ValueError('UI fixture files differ from registered sources')
    for name in FIXTURE_SOURCES[1:]:
        shutil.copyfile(repo/'tests/ui'/name, copied/name)
    add_swift_sources(real, 'D00000000000000000000001',
                      (copied/name for name in FIXTURE_SOURCES[1:]), '9A')
    fixture_dir = destination/'recovery-fixtures'
    fixture_dir.mkdir()
    resources = next(obj for obj in real['objects'].values() if obj.get('isa') == 'PBXResourcesBuildPhase')
    for index, name in enumerate(('exam', 'return'), start=1):
        fixture = fixture_dir/f'recovery-{name}.json'
        shutil.copyfile(repo/'tests/fixtures'/fixture.name, fixture)
        reference = f'FA90000000000000000000{index:02X}'
        build_file = f'FB90000000000000000000{index:02X}'
        assert reference not in real['objects'] and build_file not in real['objects']
        real['objects'][reference] = dict(isa='PBXFileReference', lastKnownFileType='text.json', path=str(fixture), sourceTree='<absolute>')
        real['objects'][build_file] = dict(isa='PBXBuildFile', fileRef=reference)
        resources['files'].append(build_file)
    real['objects']['C00000000000000000000002']['sourceTree']='<absolute>'
    real['objects']['C00000000000000000000002']['path']=str(copied)
    for obj in real['objects'].values():
        if obj.get('isa')=='XCBuildConfiguration':
            settings=obj['buildSettings']
            settings['CODE_SIGNING_ALLOWED']='NO'
            if 'INFOPLIST_FILE' in settings:
                settings['INFOPLIST_FILE']=str(copied/'Info.plist')
                settings['PRODUCT_BUNDLE_IDENTIFIER']='jp.n624.takupoke.app-checks'
                settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
    # The generated object's IDs are numeric; real project's IDs have A-F/9 prefixes.
    test_target=next(k for k,v in generated['objects'].items() if v.get('productType')=='com.apple.product-type.bundle.ui-testing')
    app_target='D00000000000000000000001'
    for key,obj in generated['objects'].items():
        if obj.get('isa') in ['PBXProject','PBXNativeTarget','PBXGroup'] and key!=test_target: continue
        if obj.get('isa')=='PBXFileReference' and obj.get('path','').endswith('MaterialPickerTapChecks.swift'):
            obj['path']=str(check_root/'tests/ui'/check_sources[0])
        if obj.get('isa')=='PBXTargetDependency': obj['target']=app_target
        if obj.get('isa')=='PBXContainerItemProxy':
            obj['containerPortal']=real['rootObject']
            obj['remoteGlobalIDString']=app_target
            obj['remoteInfo']='Takupoke'
        if obj.get('isa')=='XCBuildConfiguration':
            obj['buildSettings']['TEST_TARGET_NAME']='Takupoke'
            if os.environ.get('TKPK_VOICEOVER_AUTOMATION')=='1':
                obj['buildSettings']['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='TAKUPOKE_VOICEOVER_AUTOMATION'
        real['objects'][key]=obj
    add_swift_sources(real, test_target,
                      (check_root/'tests/ui'/name for name in check_sources[1:]), '9B')
    add_swift_sources(real, test_target, [repo/'tests/Support/ObservedScreenGeometry.swift'], '9C')
    real['objects'][real['rootObject']]['targets'].append(test_target)
    real['objects'][real['rootObject']].setdefault('attributes',{}).setdefault('TargetAttributes',{})[test_target]={'CreatedOnToolsVersion':'27.0','TestTargetID':app_target}
    def encode(v):
        if isinstance(v,dict): return '{'+''.join(f'{json.dumps(k)}={encode(x)};' for k,x in v.items())+'}'
        if isinstance(v,list): return '('+','.join(encode(x) for x in v)+')'
        return json.dumps(v)
    project=destination/'AppChecks.xcodeproj'
    project.mkdir()
    (project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(real))
    package_lock=project/'project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
    package_lock.parent.mkdir(parents=True)
    shutil.copyfile(repo/'Takupoke.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',package_lock)
    scheme=(destination/'PickerChecks.xcodeproj/xcshareddata/xcschemes/PickerChecks.xcscheme').read_text()
    old_app=next(k for k,v in generated['objects'].items() if v.get('productType')=='com.apple.product-type.application')
    scheme=scheme.replace(old_app,app_target).replace('PickerChecks.app','Takupoke.app').replace('BlueprintName="PickerChecks"','BlueprintName="Takupoke"').replace('container:PickerChecks.xcodeproj','container:AppChecks.xcodeproj')
    folder=project/'xcshareddata/xcschemes'; folder.mkdir(parents=True)
    (folder/'AppChecks.xcscheme').write_text(scheme)

if __name__=='__main__': generate(sys.argv[1])
