import SwiftUI

struct PDFRecoveryView: View {
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    let kind: RecoveryDocumentKind
    @ObservedObject private var coordinator = ApplicationData.shared.recovery
    @ObservedObject private var models = LocalRecoveryModelManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var selectedClass = ""
    @State private var showingSource = false
    @State private var zoomedField: String?
    @State private var manualValues = [String:String]()
    @State private var manualAcknowledged = [String:Bool]()
    @FocusState private var editingManualField: String?
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
                            .buttonStyle(.glassProminent).disabled(!useAiFeatures || coordinator.running)
                    }
                } else if let review = coordinator.manualReview, let draft = coordinator.manualDraft {
                    Section("訂正箇所を先に確認") {
                        Text("この段階では採用しません。入力した本文と、比較できる前回の結果からの変更を確認してください。")
                        Button("元のPDFを確認",systemImage:"doc.richtext") { showingSource = true }
                    }
                    ForEach(draft.fields) { field in
                        Section(role(field.target.role)) {
                            fieldLocation(field,draft:draft)
                            VStack(alignment:.leading,spacing:4) {
                                Text("自動読取").font(.caption).foregroundStyle(.secondary)
                                Text(field.originalText).fixedSize(horizontal:false,vertical:true)
                                Text("確認した入力").font(.caption).foregroundStyle(.secondary)
                                Text(review.candidate.result.humanCorrections?.first(where:{ $0.target == field.target })?.value ?? "")
                                    .fixedSize(horizontal:false,vertical:true).textSelection(.enabled)
                            }
                            Button("対象セルを拡大して確認",systemImage:"plus.magnifyingglass") { zoomedField = field.id }
                                .disabled(coordinator.manualContextImages[field.id] == nil)
                        }
                    }
                    Section("前回の結果からの変更") {
                        if review.comparison.available {
                            if let date = review.previousDate { LabeledContent("比較した前回の解析") { Text(date,format:JapaneseDateDisplay.timestamp) } }
                            Text(review.comparison.changes.isEmpty ? "比較できる本文に変更はありません。" : "本文の変更: \(review.comparison.changes.count)箇所")
                            ForEach(review.comparison.changes) { change in
                                VStack(alignment:.leading,spacing:8) {
                                    Text("\(TimetableDisplayText.className(change.slot.className)) · \(day(change.slot.day)) · \(change.slot.period)限").font(.headline)
                                    Text("前回: \(lessons(change.before))")
                                    Text("今回: \(lessons(change.after))")
                                }
                            }
                        } else {
                            Text("前回の結果とは比較できません。年度・対象・本文の範囲を一致させて確認できないため、変更箇所は推測しません。")
                        }
                    }
                    Section {
                        Button("入力を見直す",systemImage:"pencil") { coordinator.editManualReview() }.disabled(!useAiFeatures || coordinator.running)
                        Button("訂正と変更を確認して資料全体へ",systemImage:"doc.text.magnifyingglass") { coordinator.showManualPreview() }
                            .buttonStyle(.glassProminent).disabled(!useAiFeatures || coordinator.running)
                    }
                } else if let draft = coordinator.manualDraft {
                    Section("原本との照合") {
                        Text("確認が必要な\(draft.fields.count)項目を原本と照合してください。入力後に資料全体の結果を確認し、採用を選べます。")
                        Button("元のPDFを確認",systemImage:"doc.richtext") { showingSource = true }
                    }
                    ForEach(draft.fields) { field in
                        Section(role(field.target.role)) {
                            fieldLocation(field,draft:draft)
                            if let image = coordinator.manualImages[field.id] {
                                Image(uiImage:image).resizable().interpolation(.none).scaledToFit()
                                    .accessibilityLabel("原本の該当箇所")
                            }
                            Button("対象セルを拡大して確認",systemImage:"plus.magnifyingglass") { zoomedField = field.id }
                                .disabled(coordinator.manualContextImages[field.id] == nil)
                            Text("自動読取: \(field.originalText)").font(.caption).foregroundStyle(.secondary)
                            HStack(alignment:.top) {
                            TextField("PDFに記載された全文",text:Binding(get:{ manualValues[field.id] ?? field.originalText },set:{ guard coordinator.manualDraft?.id == draft.id else { return }; if coordinator.manualReview != nil { return }; RecoveryManualInput.update($0,id:field.id,original:field.originalText,values:&manualValues,acknowledged:&manualAcknowledged) }),axis:.vertical)
                                .autocorrectionDisabled().textInputAutocapitalization(.never).disabled(!useAiFeatures || coordinator.running)
                                .focused($editingManualField,equals:field.id)
                                .contentShape(Rectangle())
                                .simultaneousGesture(TapGesture().onEnded {
                                    guard useAiFeatures, !coordinator.running else { return }
                                    editingManualField = field.id
                                })
                            if editingManualField == field.id, !(manualValues[field.id] ?? field.originalText).isEmpty {
                                Button {
                                    guard useAiFeatures, !coordinator.running, coordinator.manualDraft?.id == draft.id, coordinator.manualReview == nil else { return }
                                    RecoveryManualInput.update("",id:field.id,original:field.originalText,values:&manualValues,acknowledged:&manualAcknowledged)
                                    editingManualField = field.id
                                } label: {
                                    Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary)
                                        .frame(minWidth:44,minHeight:44)
                                }.buttonStyle(.borderless).accessibilityLabel("入力を消去")
                                    .accessibilityIdentifier("manual-clear-" + field.id)
                            }
                            }
                            Toggle("原本と一致することを確認",isOn:Binding(get:{ manualAcknowledged[field.id] ?? false },set:{ guard coordinator.manualDraft?.id == draft.id else { return }; if coordinator.manualReview != nil { return }; manualAcknowledged[field.id] = $0 }))
                                .disabled(!useAiFeatures || coordinator.running)
                        }
                    }
                    Section {
                        Button("訂正箇所と前回からの変更を確認",systemImage:"checkmark.circle") {
                            coordinator.submitManual(Dictionary(uniqueKeysWithValues:draft.fields.map { ($0.id,manualValues[$0.id] ?? $0.originalText) }),acknowledged:Set(manualAcknowledged.filter(\.value).keys))
                        }.buttonStyle(.glassProminent)
                            .disabled(!useAiFeatures || coordinator.running || draft.fields.contains { !(manualAcknowledged[$0.id] ?? false) || (manualValues[$0.id] ?? $0.originalText).trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || (manualValues[$0.id] ?? $0.originalText).utf16.count > RecoveryManualAssistance.maximumCorrectedUTF16 })
                    }
                } else if coordinator.awaitingModel {
                    Section("端末内AI") {
                        Text(coordinator.status)
                        Button("準備状況を再確認") { coordinator.retryModel() }.disabled(!useAiFeatures || models.busy)
                    }
                    modelSection
                } else if !coordinator.running {
                    Section { Button("端末内で復旧を開始",systemImage:"doc.text.magnifyingglass") { coordinator.start(kind) }.buttonStyle(.glassProminent).disabled(!useAiFeatures) }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("閉じる") { coordinator.cancel(); dismiss() } }
                ToolbarItemGroup(placement:.keyboard) {
                    Spacer()
                    Button("完了") { editingManualField = nil }.accessibilityIdentifier("manual-edit-done")
                }
            }
            .sheet(isPresented:$showingSource) {
                if let url = coordinator.preview?.source.url ?? coordinator.manualSourceURL { SavedPDFView(url:url,title:"元のPDF") }
            }
            .sheet(isPresented:Binding(get:{ zoomedField != nil },set:{ if !$0 { zoomedField = nil } })) {
                if let id = zoomedField, let image = coordinator.manualContextImages[id] {
                    RecoveryManualImageView(context:image)
                }
            }
            .onChange(of:coordinator.preview?.id) { _,_ in selectedClass = coordinator.preview?.document.classes.first ?? "" }
            .onChange(of:coordinator.manualDraft?.id) { _,_ in
                manualValues = Dictionary(uniqueKeysWithValues:coordinator.manualDraft?.fields.map { ($0.id,$0.originalText) } ?? [])
                manualAcknowledged = [:]; zoomedField = nil; editingManualField = nil
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
    @ViewBuilder private func fieldLocation(_ field:RecoveryManualField,draft:RecoveryManualDraft) -> some View {
        if let cell = draft.document.cells.first(where:{ $0.id == field.target.cellId }), let slot = cell.slots.first {
            Text("\(TimetableDisplayText.className(slot.className)) · \(day(slot.day)) · \(cell.slots.map(\.period).sorted().map(String.init).joined(separator:"・"))限").font(.subheadline)
        }
    }
    private func lessons(_ values:[RecoveryManualComparison.Lesson]) -> String {
        values.isEmpty ? "空欄" : values.map {
            "\($0.subject) / 教員: \($0.teacher.isEmpty ? "記載なし" : $0.teacher) / 教室: \($0.room.isEmpty ? "記載なし" : $0.room) / \($0.spanStart)-\($0.spanEnd)限" + ($0.time.map { " / " + $0 } ?? "")
        }.joined(separator:"\n")
    }
    private func role(_ value:RecoveryRole) -> String { switch value { case .subject: return "科目"; case .teacher: return "教員"; case .room: return "教室" } }
    private func day(_ value: String) -> String { kind == .timetable ? ["1":"月曜日","2":"火曜日","3":"水曜日","4":"木曜日","5":"金曜日"][value] ?? value : value }
}

struct RecoveryModelControls: View {
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
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
                    Button("モデルをダウンロード") { models.install(manifest) }.disabled(!useAiFeatures || models.busy || models.isInUse || !manifest.validated)
                }
            }
            ForEach(models.installed.keys.sorted(),id:\.self) { runtime in
                if let model = models.installed[runtime] { Button("\(model.modelId)を削除",role:.destructive) { models.delete(runtime) }.disabled(models.busy || models.isInUse) }
            }
        }
    }
}
private struct RecoveryManualImageView: View {
    let context: RecoveryManualImage
    @Environment(\.dismiss) private var dismiss
    @State private var zoom = 1.0
    var body: some View {
        NavigationStack {
            VStack(spacing:12) {
                Text("オレンジの枠が訂正箇所です。原本の対象セルを拡大し、スクロールして確認できます。")
                    .font(.subheadline).padding(.horizontal)
                HStack {
                    Slider(value:$zoom,in:1...4,step:0.5) { Text("原画像の拡大率") }
                    Text("\(zoom,format:.number.precision(.fractionLength(1)))倍").monospacedDigit()
                    Button("等倍") { zoom = 1 }.buttonStyle(.glass)
                }.padding(.horizontal)
                GeometryReader { geometry in
                    let width=max(1,geometry.size.width-32)*zoom
                    let height=width*context.image.size.height/max(1,context.image.size.width)
                    ScrollView([.horizontal,.vertical]) {
                        Image(uiImage:context.image).resizable().interpolation(.none)
                            .frame(width:width,height:height)
                            .overlay(alignment:.topLeading) {
                                Rectangle().stroke(.orange,lineWidth:3)
                                    .frame(width:width*context.highlight.width,height:height*context.highlight.height)
                                    .offset(x:width*context.highlight.x,y:height*context.highlight.y)
                                    .accessibilityElement().accessibilityLabel("訂正する本文の範囲")
                                    .allowsHitTesting(false)
                            }
                            .accessibilityElement(children:.contain)
                            .accessibilityLabel("原本の対象セル・訂正箇所を強調")
                            .padding(16)
                    }
                }
            }
            .navigationTitle("原画像の確認")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("確認を終える") { dismiss() } } }
        }
    }
}
struct RecoveryModelSettingsView: View {
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    @ObservedObject private var models = LocalRecoveryModelManager.shared
    @Environment(\.scenePhase) private var phase
    var body: some View {
        List {
            RecoveryModelControls(models:models)
        }
            .navigationTitle("端末内AIモデル")
            .task { await models.refresh() }
            .onChange(of:useAiFeatures) { _,enabled in if !enabled { models.cancel() } }
            .onChange(of:phase) { _,phase in if phase != .active { models.cancel() } }
    }
}
