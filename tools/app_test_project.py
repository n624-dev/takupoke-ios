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

WEEK_MOTION_INSERTIONS = (
    ('            if let scroll, let week { progress?.motion.register(scroll, week: week, probe: self) }',
     '\n            if let week { FixtureWeekMotionRecorder.shared.register(week: week.iso8601, body: self) }'),
    ('                inputGeneration = motion.inputGeneration',
     '\n                FixtureWeekMotionRecorder.shared.began(body: self)'
     '\n                FixtureWeekSequenceRecorder.shared.observe("contact", week: week, phase: motion.reservedHeight == nil ? "settled" : "height")'),
    ('                let distance = pull?.distance(for: translation) ?? 0',
     '\n                FixtureWeekMotionRecorder.shared.released(body: self)'
     '\n                FixtureWeekSequenceRecorder.shared.observe("release", week: week, phase: motion.reservedHeight == nil ? "settled" : "height")'),
    ('        deferredReleases.append(release)',
     '\n        FixtureWeekSequenceRecorder.shared.observe("release", week: release.week, phase: transition == nil ? "pending" : "slide")'),
    ('            case .failed, .cancelled:', '\n                FixtureWeekMotionRecorder.shared.cancelBadgeCapture()'),
    ('            let windowVisible = scroll.convert(visible.offsetBy(dx: scroll.bounds.minX, dy: scroll.bounds.minY), to: window)',
     '\n            FixtureWeekMotionRecorder.shared.visible = windowVisible'),
    ('        let minimum = -scroll.adjustedContentInset.left',
     '\n        FixtureWeekMotionRecorder.shared.begin(source: week.iso8601, target: destination.iso8601)'),
    ('    private func settle(id: UUID) {', '\n        FixtureWeekMotionRecorder.shared.arrived()'),
    ('    private func promote(_ value: Transition) {',
     '\n        FixtureWeekMotionRecorder.shared.checkpoint("promotion-begin")'),
    ('            arrive?(value.source, value.destination)',
     '\n            FixtureWeekMotionRecorder.shared.checkpoint("arrival-callback-returned")'),
    ('            heldScroll?.isScrollEnabled = true\n            heldScroll = nil',
     '\n            FixtureWeekMotionRecorder.shared.checkpoint("scroll-restored")'
     '\n            if heightAdjustment != nil { FixtureWeekSequenceRecorder.shared.signalHeightWindow() }'),
    ('    private func configure(_ weeks: [SchoolDate]) {',
     '\n        FixtureWeekMotionRecorder.shared.checkpoint("configuration-begin")'),
    ('        motion.resetNeighborScrolls(selected: selection)\n        motion.scheduleQueuedMove()',
     '\n        FixtureWeekMotionRecorder.shared.checkpoint("configuration-end")'),
    ('            selection = value.destination',
     '\n            FixtureWeekSequenceRecorder.shared.observe("arrival", week: value.source, target: value.destination)'),
    ('            motion.setTransitionTouch(active: true, week: week)',
     '\n            FixtureWeekSequenceRecorder.shared.observe("contact", week: week, phase: motion.transition == nil ? "pending" : "slide", deferred: start == nil)'),
    ('    private func finishHeight(reserving height: CGFloat? = nil) {',
     '\n        FixtureWeekMotionRecorder.shared.finished()'
     '\n        FixtureWeekSequenceRecorder.shared.observe("settled", week: selection)'),
    ('        .clipped()', '\n        .background {\n            if ProcessInfo.processInfo.arguments.contains("--week-motion-probe") {\n                FixtureWeekRowBounds()\n            }\n        }'),
    ('        .glassEffect(.regular, in: .rect(cornerRadius: 14))',
     '\n        .modifier(FixtureWeekBadgeCapture(ready: ready))'),
)


def instrument_week_motion(text):
    for marker, insertion in WEEK_MOTION_INSERTIONS:
        assert text.count(marker) == 1, 'Week motion observation insertion point missing: ' + marker
        text = text.replace(marker, marker + insertion)
    return text


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

RETENTION_ACTION_TRACE = '; FixtureLaunchDiagnostics.record("retention-recovery-action"); SimulatorRetentionObservation.shared.capture()'
RETENTION_DIALOG_TRACE = '''        .onChange(of: confirmingRetentionRecovery) { presented in
            FixtureLaunchDiagnostics.record(presented ? "retention-dialog-on" : "retention-dialog-off")
            SimulatorRetentionObservation.shared.capture(closed: !presented)
        }
'''


def instrument_retention_recovery(text):
    action = 'Button("保存期間の管理情報を復旧") { confirmingRetentionRecovery = true }'
    observer = '        .onChange(of: dataReady) { ready in'
    assert text.count(action) == 1 and text.count(observer) == 1, 'Retention observation insertion point missing'
    return text.replace(action, action[:-2] + RETENTION_ACTION_TRACE + ' }').replace(
        observer, RETENTION_DIALOG_TRACE + observer)


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

TIMETABLE_DATE_SITES = {
    'TimetableView.swift': (
        '    @State private var selectedWeek = TimetableWeekSelection(date: SchoolDate.today().displayWeekStart)\n',
        '    @State var navigationHalfAnchor = SchoolDate.today()\n',
        '    @State var today = SchoolDate.today()\n',
    ),
    'TimetableView+Navigation.swift': (
        '        let current = SchoolDate.today()\n',
        '        today = SchoolDate.today()\n',
    ),
}


def instrument_timetable_date(text, filename):
    fixture = (
        '(SimulatorAuxiliaryStoreFixture.fixedDayEnabled ? SimulatorAuxiliaryStoreFixture.day : '
        'SimulatorEventsYearFixture.enabled ? SimulatorEventsYearFixture.day : '
        '((ProcessInfo.processInfo.arguments.contains("--selection-snapshot") || '
        'ProcessInfo.processInfo.arguments.contains("--comparison")) ? SimulatorSelectionFixture.day : SchoolDate.today()))'
    )
    call = 'SchoolDate.today()'
    sites = TIMETABLE_DATE_SITES[filename]
    assert text.count(call) == len(sites), f'Unexpected timetable date sites in {filename}'
    lines = text.splitlines(keepends=True)
    for site in sites:
        assert lines.count(site) == 1, f'Timetable date insertion point missing in {filename}: {site.strip()}'
        lines[lines.index(site)] = site.replace(call, fixture)
    return ''.join(lines)


def instrument_browser_fixture(text):
    marker = '        let controller = SFSafariViewController(url: url)'
    assert text.count(marker) == 1, 'Native Safari network boundary insertion point missing'
    factory = '    func makeUIViewController(context: Context) -> SFSafariViewController {'
    assert text.count(factory) == 1, 'Browser fixture factory insertion point missing'
    text = text.replace(factory, '''    @MainActor
    static func fixtureBrowserURL() -> URL? {
        guard ProcessInfo.processInfo.arguments.contains("--loopback-browser-fixture") else { return nil }
        guard let raw = ProcessInfo.processInfo.environment["TKPK_BROWSER_FIXTURE_URL"],
              let local = URL(string: raw), local.scheme == "http", local.host == "127.0.0.1",
              local.port.map({ (1...65535).contains($0) }) == true,
              local.user == nil, local.password == nil, local.path == "/fictional-link",
              local.query == nil, local.fragment == nil else {
            preconditionFailure("The browser fixture requires its owned loopback input")
        }
        return local
    }

''' + factory)
    text = text.replace(marker, '''        let local = Self.fixtureBrowserURL()
        if local != nil {
            precondition(url.absoluteString == "https://fixture.example.test",
                         "The browser fixture requires its original fictional input")
        }
        let controller = SFSafariViewController(url: local ?? url)
        FixtureLaunchDiagnostics.record("browser-controller-created")''')
    delegate = '    final class Coordinator: NSObject, SFSafariViewControllerDelegate {\n'
    assert text.count(delegate) == 1, 'Native Safari delegate observation insertion point missing'
    finished = '        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {\n'
    assert text.count(finished) == 1, 'Native Safari finish delegate insertion point missing'
    text = text.replace(finished, finished + '            FixtureLaunchDiagnostics.record("browser-finish-received")\n')
    return text.replace(delegate, delegate + '''        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad success: Bool) {
            FixtureLaunchDiagnostics.record(success ? "browser-load-success" : "browser-load-failure")
        }
''')

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

NOTIFICATION_PERMISSION_BEGIN = (
    '        let fixturePermissionRead = FixtureNotificationAuthorization.shared.begin()\n')
NOTIFICATION_PERMISSION_READ = '        let settings = await readCurrentNotificationSettings()\n'
NOTIFICATION_PERMISSION_READ_ORIGINAL = '        _ = await readCurrentNotificationSettings()\n'
NOTIFICATION_PERMISSION_END = (
    '        FixtureNotificationAuthorization.shared.complete(fixturePermissionRead,\n'
    '            authorization: settings?.authorizationStatus.rawValue, cancelled: Task.isCancelled)\n')

NOTIFICATION_NATIVE_REQUEST = '            FixtureLaunchDiagnostics.record("notification-native-request")\n'
NOTIFICATION_NATIVE_CALLBACK = '                FixtureLaunchDiagnostics.record("notification-native-callback")\n'
NOTIFICATION_AUTH_REQUEST = '            FixtureLaunchDiagnostics.record("notification-auth-request")\n'
NOTIFICATION_AUTH_CALLBACK = (
    '                FixtureLaunchDiagnostics.record("notification-auth-callback")\n'
    '                FixtureLaunchDiagnostics.record(error != nil ? "notification-auth-error" :\n'
    '                    (granted ? "notification-auth-granted" : "notification-auth-denied"))\n')
NOTIFICATION_AUTH_RETURNED = '            FixtureLaunchDiagnostics.record("notification-auth-returned")\n'

NOTIFICATION_PERMISSION_SKIPPED = (
    '            FixtureNotificationAuthorization.shared.completeWithoutRead(fixturePermissionRead,\n'
    '                cancelled: Task.isCancelled)\n')

def instrument_notification_permission(text):
    # Observe actual branches and calls. Never supply an OS status or change settings.
    start = '    func checkPermission() async {\n'
    read = NOTIFICATION_PERMISSION_READ_ORIGINAL
    disabled = ('            permissionMessage = nil\n'
                '            return\n')
    end = text.index('    // Keep the actual OS response')
    permission = text[:end]
    assert permission.count(start) == 1 and permission.count(read) == 1, (
        'Notification permission read insertion point missing')
    assert permission.count(disabled) == 1, 'Disabled permission branch insertion point missing'
    permission = permission.replace(start, start + NOTIFICATION_PERMISSION_BEGIN)
    permission = permission.replace(read, NOTIFICATION_PERMISSION_READ + NOTIFICATION_PERMISSION_END)
    permission = permission.replace(disabled, disabled.replace(
        '            return\n', NOTIFICATION_PERMISSION_SKIPPED + '            return\n'))
    text = permission + text[end:]
    request = '            center.getNotificationSettings { settings in\n'
    callback = '                callback(settings)\n'
    assert text.count(request) == 1 and text.count(request.strip()) == 1, (
        'Native settings request insertion point missing')
    assert text.count(callback) == 1 and text.count(callback.strip()) == 1, (
        'Native settings callback insertion point missing')
    text = text.replace(request, NOTIFICATION_NATIVE_REQUEST + request).replace(
        callback, NOTIFICATION_NATIVE_CALLBACK + callback)
    auth = '            center.requestAuthorization(options: [.alert, .sound]) { granted, error in\n'
    assert text.count(auth) == 1 and text.count(auth.strip()) == 1, (
        'Native authorization request insertion point missing')
    end = ('                else { continuation.resume(returning: granted) }\n'
           '            }\n')
    assert text.count(end) == 1, 'Native authorization return insertion point missing'
    return text.replace(auth, NOTIFICATION_AUTH_REQUEST + auth + NOTIFICATION_AUTH_CALLBACK).replace(
        end, end + NOTIFICATION_AUTH_RETURNED)

def retention_notice_read_insertions():
    for operation, stage in (('getPendingNotificationRequests', 'pending'),
                             ('getDeliveredNotifications', 'delivered')):
        original = f'            center.{operation}(completionHandler:callback)\n'
        flag = 'ProcessInfo.processInfo.arguments.contains("--retention-corrupt")'
        observed = (f'            let fixtureRetentionRead = {flag} ? UUID().uuidString.prefix(8).lowercased() : nil\n'
                    f'            if let fixtureRetentionRead {{ FixtureCITrace.mark("retention-notice-{stage}-request-\\(fixtureRetentionRead)") }}\n'
                    f'            center.{operation} {{ requests in\n'
                    f'                if let fixtureRetentionRead {{ FixtureCITrace.mark("retention-notice-{stage}-callback-\\(fixtureRetentionRead)") }}\n'
                    '                callback(requests)\n'
                    '            }\n')
        yield original, observed

def instrument_retention_notification_reads(text):
    # Preserve real requests and callbacks, including callbacks after a timeout.
    for original, observed in retention_notice_read_insertions():
        assert text.count(original) == 1, 'Retention notification insertion point missing'
        text = text.replace(original, observed)
    return text

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
        if path.name == 'SafariLinkView.swift':
            text = instrument_browser_fixture(text)
        if path.name == 'ContentView.swift':
            text = instrument_retention_recovery(text)
        if path.name == 'NotificationSettingsView.swift':
            text = instrument_notification_switch(text)
        if path.name == 'ScheduleNotifications.swift':
            text = instrument_notification_permission(text)
            text = instrument_retention_notification_reads(text)
        # A URLProtocol below rejects every request. Rewrite URLs as a second
        # guard against any production communication from the test app.
        text = rewrite_network_urls(text)
        text = re.sub(r'(\b(?:let|var) (\w+) = URLSessionConfiguration\.(?:ephemeral|default))',
                      lambda match: match[1] + "\n        " + match[2] + ".protocolClasses = [FixtureNetwork.self]", text)
        if path.name == 'SchoolEventsModel.swift':
            text = instrument_events_cache(text)
            endpoint = 'URL(string: "https://fixture.example.test")!'
            assert text.count(endpoint) == 1, 'Event fixture endpoint insertion point missing'
            text = text.replace(endpoint, endpoint + '.appendingPathComponent("events")')
        if path.name == 'ApplicationData.swift':
            clock = 'let homeClock = HomeScheduleClock()'
            assert text.count(clock) == 1, 'Home clock provider insertion point missing'
            text = text.replace(clock, 'let homeClock = HomeScheduleClock(now: { SimulatorHomeBoundaryFixture.enabled ? SimulatorHomeBoundaryFixture.current : Date() })')
            events = 'let schoolEvents = SchoolEventsModel(canAccessData:'
            assert text.count(events) == 1, 'Event fixture format insertion point missing'
            text = text.replace(events, 'let schoolEvents = SchoolEventsModel(preferredFormat: ProcessInfo.processInfo.arguments.contains("--events-v2") ? .v2 : .v1, canAccessData:')
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
            text = instrument_timetable_date(text, path.name)
        if path.name == 'HomeTodayView.swift':
            configure = '    private func configureClock() {'
            assert text.count(configure) == 1, 'Home clock boundary insertion point missing'
            text = text.replace(configure, configure + '\n        SimulatorHomeBoundaryFixture.crossIfArmed()')
            marker = 'private var day: SchoolDate { TimetableDaySchedule.schoolDay(at: now) }'
            assert text.count(marker) == 1, 'Home selection date probe insertion point missing'
            text = text.replace(marker, 'private var day: SchoolDate { SimulatorAuxiliaryStoreFixture.fixedDayEnabled ? SimulatorAuxiliaryStoreFixture.day : SimulatorEventsYearFixture.enabled ? SimulatorEventsYearFixture.day : ((ProcessInfo.processInfo.arguments.contains("--selection-snapshot") || ProcessInfo.processInfo.arguments.contains("--comparison")) ? SimulatorSelectionFixture.day : TimetableDaySchedule.schoolDay(at: now)) }')
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
    @State var fixtureGridMeasurements = FixtureGridMeasurements()
''')
        if path.name == 'TimetableView+GridHeaders.swift':
            marker = next(line for line in text.splitlines() if '.accessibilityIdentifier("timetable-day-' in line)
            text = text.replace(marker, marker + '''
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("fixture-grid")) } action: { frame in
                guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                if fixtureGridMeasurements.headerFrames[column.day.iso8601] != frame {
                    fixtureGridMeasurements.headerFrames[column.day.iso8601] = frame
                }
            }
''')
        if path.name == 'TimetableView+DayColumns.swift':
            marker = next(line for line in text.splitlines() if '.accessibilityIdentifier("timetable-event-' in line)
            text = text.replace(marker, marker + '''
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                if fixtureGridMeasurements.eventSizes[title] != size { fixtureGridMeasurements.eventSizes[title] = size }
            }
''')
            # The observer must be inside offset so its frame includes the
            # ancestor's translation, rather than measuring offset's layout box.
            marker = next(line for line in text.splitlines() if '.offset(x: CGFloat(entry.lane)' in line)
            text = text.replace(marker, '''
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("fixture-grid")) } action: { frame in
                        guard ProcessInfo.processInfo.arguments.contains("--grid-probe") else { return }
                        let key = fixtureCardKey(on: day, className: className, entry: entry)
                        if fixtureGridMeasurements.cardFrames[key] != frame { fixtureGridMeasurements.cardFrames[key] = frame }
                    }
''' + marker)
        if path.name == 'TimetableView+Grid.swift':
            text = instrument_week_motion(text)
            marker = next(line for line in text.splitlines() if '.modifier(WeekGridAccessibility(' in line)
            assert marker in text, 'Timetable grid probe insertion point missing'
            text = text.replace(marker, marker + '''
        .coordinateSpace(name: "fixture-grid")
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("--grid-probe") {
                FixtureActiveGridMetrics(measurements: fixtureGridMeasurements) {
                    fixtureGridMetrics(columns: columns, days: days, heights: rowHeights)
                }
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
