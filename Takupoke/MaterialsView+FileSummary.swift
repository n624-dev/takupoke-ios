import SwiftUI

extension MaterialsView {
    @ViewBuilder var fileRows: some View {
        ForEach([MaterialKind.timetable, .changes]) { kind in
            if let record = model.state.record(for: kind) {
                let status = model.fileStatus(kind)
                NavigationLink {
                    if kind == .changes { ChangeAnalysisView(model: model, mappings: mappings) }
                    else { PDFAnalysisView(model: model, mappings: mappings, kind: kind) }
                } label: {
                    StatusRow(title: kind.title, status: status, subtitle: record.originalName)
                }
                .accessibilityLabel("\(kind.title)の詳細を見る")
                .accessibilityValue(fileAccessibilityValue(status, name: record.originalName))
            } else {
                let status = model.fileStatus(kind)
                Button { fileRequest = FileSelectionRequest(target: .material(kind)) } label: {
                    StatusRow(title: kind.title, status: status, subtitle: "ファイルを選ぶ")
                }
                .accessibilityLabel("\(kind.title)のファイルを選ぶ")
                .accessibilityValue(fileAccessibilityValue(status, name: nil))
                .disabled(model.busy || !model.ready)
            }
        }
        ForEach(SpecialScheduleKind.allCases) { kind in
            if specialSchedules.sources[kind] != nil || specialSchedules.records[kind] != nil {
                let status = specialSchedules.fileStatus(kind)
                let name = specialSchedules.sources[kind]?.originalName ?? specialSchedules.records[kind]?.originalName
                NavigationLink {
                    SpecialScheduleAnalysisView(model: specialSchedules, kind: kind)
                } label: {
                    StatusRow(title: kind.title, status: status, subtitle: name)
                }
                .accessibilityLabel("\(kind.title)の詳細を見る")
                .accessibilityValue(fileAccessibilityValue(status, name: name))
            } else {
                let status = specialSchedules.fileStatus(kind)
                Button { fileRequest = FileSelectionRequest(target: .special(kind)) } label: {
                    StatusRow(title: kind.title, status: status, subtitle: "ファイルを選ぶ")
                }
                .accessibilityLabel("\(kind.title)のファイルを選ぶ")
                .accessibilityValue(fileAccessibilityValue(status, name: nil))
                .disabled(specialSchedules.busy || !specialSchedules.ready)
            }
        }
    }

    private func fileAccessibilityValue(_ status: StatusPresentation, name: String?) -> String {
        [name, status.title, status.detail].compactMap { $0 }.joined(separator: "、")
    }
}

extension SpecialSchedulesModel {
    func analysisStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        fileStatus(kind).title
    }

    func fileStatus(_ kind: SpecialScheduleKind) -> StatusPresentation {
        if let status = fileMonitor.timeoutStatus(kind.rawValue) { return status }
        if let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue),
           let running = FilePipeline.shared.snapshot[source], running.stage != .succeeded && running.stage != .unchanged {
            return running.presentation
        }
        return FileStatusPresentation.special(availability, kind: kind,
                                       recoveryRejected: rejectedRecoveryKinds.contains(kind)).status
    }
}

extension MaterialsModel {
    func analysisStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        fileStatus(kind).title
    }

    func fileStatus(_ kind: MaterialKind) -> StatusPresentation {
        if let status = fileMonitor.timeoutStatus(kind.rawValue) { return status }
        if let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue),
           let running = FilePipeline.shared.snapshot[source], running.stage != .succeeded && running.stage != .unchanged {
            return running.presentation
        }
        var value = FileStatusPresentation.material(state, kind: kind, year: automaticChangeSchoolYear,
                                                   recoveryRejected: rejectedRecoveryKinds.contains(kind.rawValue)).status
        if kind == .changes {
            let count = state.excludedChangeRows(year: automaticChangeSchoolYear).count
            if count > 0 {
                let excluded = "\(count)行を除外して読み込んでいます。"
                value.detail = value.detail.map { $0 + "\n" + excluded } ?? excluded
            }
        }
        return value
    }
}
