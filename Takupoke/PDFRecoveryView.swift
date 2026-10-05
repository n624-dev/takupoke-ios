import SwiftUI

struct PDFRecoveryView: View {
    let kind: RecoveryDocumentKind
    @ObservedObject private var coordinator = ApplicationData.shared.recovery
    @ObservedObject private var models = LocalRecoveryModelManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var selectedClass = ""
    @State private var showingSource = false
    @State private var manualValues = [String:String]()
    @State private var manualAcknowledged = [String:Bool]()
    private var title: String { kind == .timetable ? "時間割の復旧" : kind == .exam ? "試験時間割の復旧" : "試験返却時間割の復旧" }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("学校の資料・OCR文字・授業情報は端末内で処理され、外部のAIへ送信されません。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if coordinator.running { LoadingRow(title:coordinator.status,cancel:{ coordinator.cancel() }) }
                    else if let failure = coordinator.failure { Label(failure,systemImage:"exclamationmark.triangle").foregroundStyle(.orange) }
                    else { Text(coordinator.status) }
                }
                if let preview = coordinator.preview {
                    Section("採用する資料全体") {
                        LabeledContent("年度",value:"\(preview.document.schoolYear)年度")
                        if let term = preview.document.term { LabeledContent("学期",value:term) }
                        LabeledContent("対象",value:"\(preview.document.classes.count)クラス・\(preview.document.days.count)日分")
                        Text("選択クラスだけでなく、以下の資料全体を採用します。元のPDFと読み取り結果を確認してください。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("元のPDFを確認",systemImage:"doc.richtext") { showingSource = true }
                        if let corrections = preview.result.humanCorrections {
                            Text("原本を確認して入力した\(corrections.count)項目を含みます。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("読み取り結果") {
                        Picker("クラス",selection:$selectedClass) {
                            ForEach(preview.document.classes,id:\.self) { Text(TimetableDisplayText.className($0)).tag($0) }
                        }
                        let input = Dictionary(uniqueKeysWithValues:preview.document.cells.map { ($0.id,$0) })
                        ForEach(preview.result.cells.filter { input[$0.cellId]?.slots.first?.className == (selectedClass.isEmpty ? preview.document.classes.first : selectedClass) },id:\.cellId) { result in
                            if let cell = input[result.cellId], let slot = cell.slots.first {
                                VStack(alignment:.leading,spacing:5) {
                                    Text("\(day(slot.day)) · \(cell.slots.map(\.period).sorted().map(String.init).joined(separator:"・"))限").font(.headline)
                                    if result.state == .empty { Text("空欄").foregroundStyle(.secondary) }
                                    ForEach(Array(result.lessons.enumerated()),id:\.offset) { _,lesson in
                                        Text(lesson.subject.value)
                                        Text("教員: \(lesson.teacher.state == .empty ? "記載なし" : lesson.teacher.value) / 教室: \(lesson.room.state == .empty ? "記載なし" : lesson.room.value)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    let periods = cell.slots.map(\.period).sorted()
                                    let key = periods.count > 1 ? "\(slot.day):\(periods.first!)-\(periods.last!)" : "\(slot.day):\(slot.period)"
                                    if let time = periods.count > 1 ? preview.document.spanTimes[key] : preview.document.times[key] { Text(time).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                    Section {
                        Button("この資料全体の結果を使用",systemImage:"checkmark.circle") { coordinator.adopt() }
                            .buttonStyle(.glassProminent).disabled(coordinator.running)
                    }
                } else if let draft = coordinator.manualDraft {
                    Section("原本との照合") {
                        Text("確認が必要な\(draft.fields.count)項目を原本と照合してください。入力後に資料全体の結果を確認し、採用を選べます。")
                        Button("元のPDFを確認",systemImage:"doc.richtext") { showingSource = true }
                    }
                    ForEach(draft.fields) { field in
                        Section(role(field.target.role)) {
                            if let cell = draft.document.cells.first(where:{ $0.id == field.target.cellId }), let slot = cell.slots.first {
                                Text("\(TimetableDisplayText.className(slot.className)) · \(day(slot.day)) · \(cell.slots.map(\.period).sorted().map(String.init).joined(separator:"・"))限")
                                    .font(.subheadline)
                            }
                            if let image = coordinator.manualImages[field.id] {
                                Image(uiImage:image).resizable().interpolation(.none).scaledToFit()
                                    .accessibilityLabel("原本の該当箇所")
                            }
                            Text("自動読取: \(field.originalText)").font(.caption).foregroundStyle(.secondary)
                            TextField("PDFに記載された全文",text:Binding(get:{ manualValues[field.id] ?? field.originalText },set:{ manualValues[field.id] = $0; manualAcknowledged[field.id] = false }),axis:.vertical)
                                .autocorrectionDisabled().textInputAutocapitalization(.never).disabled(coordinator.running)
                            Toggle("原本と一致することを確認",isOn:Binding(get:{ manualAcknowledged[field.id] ?? false },set:{ manualAcknowledged[field.id] = $0 }))
                                .disabled(coordinator.running)
                        }
                    }
                    Section {
                        Button("入力内容を確認して全体の結果へ",systemImage:"checkmark.circle") {
                            coordinator.submitManual(Dictionary(uniqueKeysWithValues:draft.fields.map { ($0.id,manualValues[$0.id] ?? $0.originalText) }),acknowledged:Set(manualAcknowledged.filter(\.value).keys))
                        }.buttonStyle(.glassProminent)
                            .disabled(coordinator.running || draft.fields.contains { !(manualAcknowledged[$0.id] ?? false) || (manualValues[$0.id] ?? $0.originalText).trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || (manualValues[$0.id] ?? $0.originalText).utf16.count > RecoveryManualAssistance.maximumCorrectedUTF16 })
                    }
                } else if coordinator.awaitingModel {
                    Section("端末内AI") {
                        Text(coordinator.status)
                        Button("準備状況を再確認") { coordinator.retryModel() }.disabled(models.busy)
                    }
                    modelSection
                } else if !coordinator.running {
                    Section { Button("端末内で復旧を開始",systemImage:"doc.text.magnifyingglass") { coordinator.start(kind) }.buttonStyle(.glassProminent) }
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("閉じる") { coordinator.cancel(); dismiss() } } }
            .sheet(isPresented:$showingSource) {
                if let url = coordinator.preview?.source.url ?? coordinator.manualSourceURL { SavedPDFView(url:url,title:"元のPDF") }
            }
            .onChange(of:coordinator.preview?.id) { _,_ in selectedClass = coordinator.preview?.document.classes.first ?? "" }
            .onChange(of:coordinator.manualDraft?.id) { _,_ in
                manualValues = Dictionary(uniqueKeysWithValues:coordinator.manualDraft?.fields.map { ($0.id,$0.originalText) } ?? [])
                manualAcknowledged = [:]
            }
            .onChange(of:phase) { _,phase in
                if phase != .active { coordinator.suspendForInactivity(); models.cancel() }
                else { coordinator.invalidateManualIfSourceChanged() }
            }
            .onReceive(ApplicationData.shared.materials.$state) { _ in Task { @MainActor in coordinator.invalidateManualIfSourceChanged() } }
            .onReceive(ApplicationData.shared.specialSchedules.$sources) { _ in Task { @MainActor in coordinator.invalidateManualIfSourceChanged() } }
            .onReceive(ApplicationData.shared.$loadedPeriod) { _ in Task { @MainActor in coordinator.invalidateManualIfSourceChanged() } }
            .task { await models.refresh() }
        }
    }
    private var modelSection: some View { RecoveryModelControls(models:models) }
    private func role(_ value:RecoveryRole) -> String { switch value { case .subject: return "科目"; case .teacher: return "教員"; case .room: return "教室" } }
    private func day(_ value: String) -> String { kind == .timetable ? ["1":"月曜日","2":"火曜日","3":"水曜日","4":"木曜日","5":"金曜日"][value] ?? value : value }
}

struct RecoveryModelControls: View {
    @ObservedObject var models: LocalRecoveryModelManager
    var body: some View {
        Section("追加AIモデル") {
            Text("モデルの取得には通信します。学校の資料・OCR文字・授業情報は外部へ送信されません。")
                .font(.caption).foregroundStyle(.secondary)
            if models.isInUse { Text("復旧処理の終了後にモデルを変更できます。").foregroundStyle(.secondary) }
            if models.busy { LoadingRow(title:models.message ?? "準備中⋯",cancel:{ models.cancel() }) }
            else if let message = models.message { Text(message) }
            if models.catalog.isEmpty { Text("追加モデルは品質評価後に提供します。OSの端末内AIが利用可能な端末では追加ダウンロードは不要です。") }
            ForEach(models.catalog,id:\.sha256) { manifest in
                VStack(alignment:.leading,spacing:5) {
                    Text(manifest.modelId)
                    Text("約\(ByteCountFormatter.string(fromByteCount:manifest.size,countStyle:.file))のAIモデルをダウンロードします。学校の資料は外部へ送信されません。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("モデルをダウンロード") { models.install(manifest) }.disabled(models.busy || models.isInUse || !manifest.validated)
                }
            }
            ForEach(models.installed.keys.sorted(),id:\.self) { runtime in
                if let model = models.installed[runtime] { Button("\(model.modelId)を削除",role:.destructive) { models.delete(runtime) }.disabled(models.busy || models.isInUse) }
            }
        }
    }
}
struct RecoveryModelSettingsView: View {
    @ObservedObject private var models = LocalRecoveryModelManager.shared
    @Environment(\.scenePhase) private var phase
    var body: some View {
        List { RecoveryModelControls(models:models) }
            .navigationTitle("端末内AIモデル")
            .task { await models.refresh() }
            .onChange(of:phase) { _,phase in if phase != .active { models.cancel() } }
    }
}
