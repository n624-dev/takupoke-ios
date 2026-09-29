import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialsView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    var setupMode = false
    @State private var fileRequest: FileRequest?
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
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
                Section("更新確認") {
                    refreshControlButton("更新確認の診断をコピー") {
                        UIPasteboard.general.setItems(
                            [[UTType.utf8PlainText.identifier: FileRefreshDiagnostics.shared.report]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(900)])
                        copiedRefreshDiagnostic = true
                    }
                    Text(copiedRefreshDiagnostic ? "診断をコピーしました。" :
                        "再取得のきっかけと処理結果をコピーします。ファイル名・本文・教員名は含みません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
#endif
                if model.fileRefreshQueue.suspended || specialSchedules.fileRefreshQueue.suspended {
                    Section {
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
                        fileRequest = FileRequest(target: .material(kind))
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
                        fileRequest = FileRequest(target: .special(kind))
                    }
                    .accessibilityLabel("\(kind.title)のファイルを\(specialSchedules.sources[kind] == nil ? "選ぶ" : "選び直す")")
                    .disabled(specialSchedules.busy || !specialSchedules.ready)
                }
            }

        }
        .navigationTitle("ファイル選択")
        .toolbar {
            if !setupMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("自動確認を中止") {
                        model.cancel()
                        specialSchedules.cancel()
                    }
                    .disabled(model.fileRefreshQueue.suspended && specialSchedules.fileRefreshQueue.suspended)
                }
            }
        }
        .task { model.loadIfNeeded() }
        .task { specialSchedules.loadIfNeeded() }
        .task { schoolEvents.loadIfNeeded() }
        .background {
            MaterialDocumentPicker(item: $fileRequest, type: { $0.type }, instruction: { $0.instruction },
                selected: { request, selection in
                    switch request.target {
                    case .material(let kind): model.selectFile(selection, kind: kind)
                    case .special(let kind): specialSchedules.importPDF(selection, kind: kind)
                    }
                })
                .allowsHitTesting(false)
        }
    }

    private struct FileRequest: Identifiable {
        enum Target { case material(MaterialKind), special(SpecialScheduleKind) }
        let id = UUID()
        let target: Target
        var type: UTType {
            if case .material(.changes) = target { return UTType(filenameExtension: "xlsx") ?? .data }
            return .pdf
        }
        var instruction: String {
            switch target {
            case .material(.changes): return "時間割変更のExcelファイルを選んでください"
            case .material: return "通常時間割のPDFを選んでください"
            case .special(let kind): return "\(kind.title)のPDFを選んでください"
            }
        }
    }

    @ViewBuilder private func refreshControlButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button(title, action: action).buttonStyle(.glass)
        } else {
            Button(title, action: action).buttonStyle(.bordered)
        }
    }


}
