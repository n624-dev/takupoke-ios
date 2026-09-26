import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialsView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    var setupMode = false
    @State private var picker: MaterialKind?
    @State private var specialPickerKind: SpecialScheduleKind?
    @State private var copiedRefreshDiagnostic = false

    var body: some View {
        List {
            Section {
                if model.busy {
                    LoadingRow(title: "処理中⋯", cancel: { model.cancel() })
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
                    LoadingRow(title: "処理中⋯", cancel: { specialSchedules.cancel() })
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

            if !setupMode {
                Section("更新確認") {
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
                    refreshControlButton("更新確認の診断をコピー") {
                        UIPasteboard.general.setItems(
                            [[UTType.utf8PlainText.identifier: FileRefreshDiagnostics.shared.report]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(900)])
                        copiedRefreshDiagnostic = true
                    }
                    Text(copiedRefreshDiagnostic ? "診断をコピーしました。" :
                        "再取得のきっかけと処理結果をコピーします。ファイル名・本文・教員名は含みません。")
                        .font(.footnote).foregroundStyle(.secondary)
#endif
                    refreshControlButton("自動確認を中止") {
                        model.cancel()
                        specialSchedules.cancel()
                    }
                    .disabled(model.fileRefreshQueue.suspended && specialSchedules.fileRefreshQueue.suspended)
                    if model.fileRefreshQueue.suspended || specialSchedules.fileRefreshQueue.suspended {
                        Text("自動確認を中止中")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
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

    @ViewBuilder private func refreshControlButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button(title, action: action).buttonStyle(.glass)
        } else {
            Button(title, action: action).buttonStyle(.bordered)
        }
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
