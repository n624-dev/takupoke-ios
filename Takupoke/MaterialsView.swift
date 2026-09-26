import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialsView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @State private var picker: MaterialKind?
    @State private var specialPickerKind: SpecialScheduleKind?

    var body: some View {
        List {
            Section {
                Text("通常時間割・時間割変更・試験時間割・試験返却時間割は「ファイル」から個別に選びます。学校行事はAPIから取得します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.busy {
                    HStack {
                        ProgressView()
                        Text("処理中…")
                        Spacer()
                        Button("中止") { model.cancel() }
                    }
                }
                if let message = model.message {
                    Label(message, systemImage: model.failed ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                        .font(.subheadline)
                        .accessibilityLabel(message)
                }
                if !model.ready && !model.busy {
                    Button("保存情報を再読み込み") { model.loadIfNeeded() }
                }
                if specialSchedules.busy {
                    HStack {
                        ProgressView()
                        Text("試験時間割・試験返却時間割を処理中…")
                        Spacer()
                        Button("中止") { specialSchedules.cancel() }
                    }
                }
                if let message = specialSchedules.message {
                    Label(message, systemImage: specialSchedules.failed ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(specialSchedules.failed ? Color.orange : Color.secondary)
                        .font(.subheadline)
                }
                if !specialSchedules.ready && !specialSchedules.busy {
                    Button("試験時間割・試験返却時間割を再読み込み") { specialSchedules.loadIfNeeded() }
                }
            }

            ForEach([MaterialKind.timetable, .changes]) { kind in
                Section(kind.title) {
                    if let record = model.state.record(for: kind) {
                        fileSummary(name: record.originalName, status: materialStatus(kind, record: record),
                                    needsAttention: materialNeedsAttention(kind, record: record))
                        NavigationLink {
                            if kind == .changes { ChangeAnalysisView(model: model, mappings: mappings) }
                            else { PDFAnalysisView(model: model, mappings: mappings, kind: kind) }
                        } label: { Text("詳細を見る") }
                        .accessibilityLabel("\(kind.title)の詳細を見る")
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                        if let failure = model.state.attempts[kind.rawValue]?.failure {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Button(model.state.record(for: kind) == nil ? "ファイルを選ぶ" : "ファイルを選び直す") {
                        picker = kind
                    }
                    .accessibilityLabel("\(kind.title)のファイルを\(model.state.record(for: kind) == nil ? "選ぶ" : "選び直す")")
                }
                .disabled(model.busy || !model.ready)
            }
            SchoolEventsSettingsSection(model: schoolEvents)
            ForEach(SpecialScheduleKind.allCases) { kind in
                Section(kind.title) {
                    if let source = specialSchedules.sources[kind] {
                        fileSummary(name: source.originalName, status: specialStatus(kind, source: source),
                                    needsAttention: specialStatus(kind, source: source) != "解析済み" || source.grant == nil)
                        NavigationLink {
                            SpecialScheduleAnalysisView(model: specialSchedules, kind: kind)
                        } label: { Text("詳細を見る") }
                        .accessibilityLabel("\(kind.title)の詳細を見る")
                        if source.grant == nil {
                            Label("再選択が必要", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                    }
                    Button(specialSchedules.sources[kind] == nil ? "ファイルを選ぶ" : "ファイルを選び直す") {
                        specialPickerKind = kind
                    }
                    .accessibilityLabel("\(kind.title)のファイルを\(specialSchedules.sources[kind] == nil ? "選ぶ" : "選び直す")")
                    .disabled(specialSchedules.busy || !specialSchedules.ready)
                }
            }
            Section {
                Text("選択済みのPDF・XLSXは、アプリの起動時・復帰時と、表示中にファイルの変更通知を受けたときに確認します。内容が変わったときだけ自動で再解析します。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("OneDriveのクラウド同期を強制する機能ではありません。更新が反映されない場合は、OneDriveで同期状況を確認し、「ファイル」で対象を開いてからアプリへ戻ってください。オフライン設定だけで常に最新版になるとは限りません。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("取得を安定させるため、OneDriveで対象ファイルの「…」をタップし、「オフラインで使用可能にする」を選んで、ダウンロードの完了を待ってください。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("iPhoneの「設定」→「一般」→「Appのバックグラウンド更新」でOneDriveを有効にしてください。低電力モードではバックグラウンド更新が停止し、同期が遅れることがあります。更新が届かないときは低電力モードを解除してOneDriveを開き、同期を確認してください。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("それでも読み取れない場合は、「ファイル」で一度開いてからファイルを選び直してください。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("選択したファイルは端末内に保存します。解析に成功した結果を時間割に反映します。1ファイル50 MiBまで。解析に失敗しても選択したファイルと前回の正常な結果を残します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ファイル選択")
        .task { model.loadIfNeeded() }
        .task { specialSchedules.loadIfNeeded() }
        .task { schoolEvents.loadIfNeeded() }
        .sheet(item: $picker) { kind in
            MaterialDocumentPicker(type: kind == .changes ? (UTType(filenameExtension: "xlsx") ?? .data) : .pdf,
                                   selected: { selection in
                                       picker = nil
                                       model.selectFile(selection, kind: kind)
                                   }, cancelled: { picker = nil })
        }
        .sheet(item: $specialPickerKind) { kind in
            MaterialDocumentPicker(type: .pdf, selected: { selection in
                specialPickerKind = nil
                specialSchedules.importPDF(selection, kind: kind)
            }, cancelled: { specialPickerKind = nil })
        }
    }

    private func specialStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        if source.failure != nil {
            return specialSchedules.records[kind] == nil
                ? "解析失敗" : "解析失敗（前回結果あり）"
        }
        guard let record = specialSchedules.records[kind] else {
            return "未解析"
        }
        return record.digest == source.digest && record.analysis.version == SpecialScheduleAnalysis.parserVersion
            ? "解析済み" : "未解析（前回結果あり）"
    }

    private func materialStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        let hasAnalysis: Bool
        let isCurrent: Bool
        if kind == .changes {
            let analysis = model.state.changeAnalysis
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == ChangeAnalysis.parserVersion
        } else {
            let analysis = model.state.pdfAnalyses?[kind.rawValue]
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == PDFAnalysis.currentVersion(for: kind)
        }
        let parseFailed = kind == .changes ? model.state.changeParseAttempt?.failure != nil :
            model.state.pdfParseAttempts?[kind.rawValue]?.failure != nil
        if model.state.attempts[kind.rawValue]?.failure != nil {
            return hasAnalysis ? "取得失敗（前回結果あり）" : "取得失敗"
        }
        if parseFailed { return hasAnalysis ? "解析失敗（前回結果あり）" : "解析失敗" }
        if isCurrent { return "解析済み" }
        return hasAnalysis ? "未解析（前回結果あり）" : "未解析"
    }

    private func materialNeedsAttention(_ kind: MaterialKind, record: MaterialRecord) -> Bool {
        model.state.attempts[kind.rawValue]?.failure != nil ||
            materialStatus(kind, record: record) != "解析済み"
    }

    private func fileSummary(name: String, status: String, needsAttention: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).lineLimit(2)
            Label(status, systemImage: needsAttention ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(needsAttention ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
    }
}
