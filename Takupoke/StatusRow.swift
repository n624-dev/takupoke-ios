import SwiftUI
import UniformTypeIdentifiers

extension StatusPresentation {
    var color: Color {
        switch tone {
        case .good: return .green
        case .checking: return .blue
        case .neutral, .unknown: return .secondary
        case .attention: return .orange
        case .unavailable: return .red
        }
    }
}

struct StatusLabel: View {
    let value: StatusPresentation
    var body: some View {
        Label(value.title, systemImage: value.symbol)
            .foregroundStyle(value.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct StatusRow: View {
    let title: String
    let status: StatusPresentation
    var subtitle: String? = nil
    var date: Date? = nil
    var dateLabel: String = "最終確認"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline).foregroundStyle(.primary)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
            StatusLabel(value: status).font(.subheadline)
            if let detail = status.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            if let date {
                (Text(dateLabel + "：") + Text(date, format: JapaneseDateDisplay.timestamp))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct FileSelectionRequest: Identifiable {
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

struct FileRefreshControls: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specials: SpecialSchedulesModel
    private var paused: Bool { materials.fileRefreshQueue.suspended || specials.fileRefreshQueue.suspended }
    private var busy: Bool { materials.busy || specials.busy }
    private var hasRefreshableSelection: Bool {
        (materials.ready && (materials.state.record(for: .timetable) != nil || materials.state.record(for: .changes) != nil)) ||
            (specials.ready && !specials.sources.isEmpty)
    }

    private var summary: StatusPresentation {
        var values = [MaterialKind.timetable, .changes].map { materials.fileStatus($0) } +
            SpecialScheduleKind.allCases.map { specials.fileStatus($0) }
        if !materials.ready {
            values.append(.init(title: "通常時間割・時間割変更の保存データを確認", tone: materials.failed ? .unavailable : .checking))
        }
        if !specials.ready {
            values.append(.init(title: "試験・返却の保存データを確認", tone: specials.failed ? .unavailable : .checking))
        }
        return .summary(values, checking: busy, paused: paused)
    }
    private var lastCheckedAt: Date? {
        let regular = [MaterialKind.timetable, .changes].compactMap { materials.state.record(for: $0)?.lastCheckedAt }
        let special = SpecialScheduleKind.allCases.compactMap { specials.sources[$0]?.lastCheckedAt }
        return (regular + special).max()
    }

    var body: some View {
        StatusLabel(value: summary).accessibilityIdentifier("files-summary")
        if let lastCheckedAt {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("直近の更新確認") { Text(lastCheckedAt, format: JapaneseDateDisplay.timestamp) }
                Text("選択済みファイルの中で、最後に更新確認に成功した日時です。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if !busy && (materials.lastOperationWasCancelled || specials.lastOperationWasCancelled) {
            StatusLabel(value: .init(title: "前回の処理を中止しました", tone: .neutral))
                .font(.footnote)
        }
        if materials.busy {
            LoadingRow(title: materials.cancellationRequested ? "中止して処理の終了を待っています⋯" :
                        "通常時間割・時間割変更を処理中⋯")
        }
        if specials.busy {
            LoadingRow(title: specials.cancellationRequested ? "中止して処理の終了を待っています⋯" :
                        "試験・返却時間割を処理中⋯")
        }
        if busy {
            Button("処理を中止", role: .cancel) {
                materials.cancelCurrentOperation(); specials.cancelCurrentOperation()
            }
            .disabled((!materials.busy || materials.cancellationRequested) && (!specials.busy || specials.cancellationRequested))
        }
        Button("すべての更新を確認", systemImage: "arrow.clockwise") {
            materials.checkForUpdates(); specials.checkForUpdates()
        }
        .disabled(busy || !hasRefreshableSelection)
        if paused {
            Button("自動確認を再開", systemImage: "play") {
                materials.resumeAutomaticChecks(); specials.resumeAutomaticChecks()
            }
            .disabled(busy)
            Text("自動確認を一時停止しています。次にアプリを開き直すと再開します。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct FileRefreshMenu: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specials: SpecialSchedulesModel
    var body: some View {
        Menu("ファイルの操作", systemImage: "ellipsis.circle") {
            if materials.fileRefreshQueue.suspended || specials.fileRefreshQueue.suspended {
                Button("自動確認を再開", systemImage: "play") {
                    materials.resumeAutomaticChecks(); specials.resumeAutomaticChecks()
                }.disabled(materials.busy || specials.busy)
            } else {
                Button("自動確認を一時停止", systemImage: "pause") {
                    materials.pauseAutomaticChecks(); specials.pauseAutomaticChecks()
                }
            }
        }
        .accessibilityIdentifier("file-refresh-menu")
    }
}
