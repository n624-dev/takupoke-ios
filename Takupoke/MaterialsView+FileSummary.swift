import SwiftUI

extension MaterialsView {
    @ViewBuilder var fileRows: some View {
        ForEach([MaterialKind.timetable, .changes]) { kind in
            if let record = model.state.record(for: kind) {
                NavigationLink {
                    if kind == .changes { ChangeAnalysisView(model: model, mappings: mappings) }
                    else { PDFAnalysisView(model: model, mappings: mappings, kind: kind) }
                } label: {
                    StatusRow(title: kind.title, status: model.fileStatus(kind), subtitle: record.originalName)
                }
                .accessibilityLabel("\(kind.title)の詳細を見る")
                .accessibilityValue(model.fileStatus(kind).title)
            } else {
                Button { fileRequest = FileSelectionRequest(target: .material(kind)) } label: {
                    StatusRow(title: kind.title, status: model.fileStatus(kind), subtitle: "ファイルを選ぶ")
                }
                .accessibilityLabel("\(kind.title)のファイルを選ぶ")
                .disabled(model.busy || !model.ready)
            }
        }
        ForEach(SpecialScheduleKind.allCases) { kind in
            if specialSchedules.sources[kind] != nil || specialSchedules.records[kind] != nil {
                NavigationLink {
                    SpecialScheduleAnalysisView(model: specialSchedules, kind: kind)
                } label: {
                    StatusRow(title: kind.title, status: specialSchedules.fileStatus(kind),
                              subtitle: specialSchedules.sources[kind]?.originalName ?? specialSchedules.records[kind]?.originalName)
                }
                .accessibilityLabel("\(kind.title)の詳細を見る")
                .accessibilityValue(specialSchedules.fileStatus(kind).title)
            } else {
                Button { fileRequest = FileSelectionRequest(target: .special(kind)) } label: {
                    StatusRow(title: kind.title, status: specialSchedules.fileStatus(kind), subtitle: "ファイルを選ぶ")
                }
                .accessibilityLabel("\(kind.title)のファイルを選ぶ")
                .disabled(specialSchedules.busy || !specialSchedules.ready)
            }
        }
    }
}

extension SpecialSchedulesModel {
    func analysisStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        fileStatus(kind).title
    }

    func fileStatus(_ kind: SpecialScheduleKind) -> StatusPresentation {
        FileStatusPresentation.special(availability, kind: kind,
                                       recoveryRejected: rejectedRecoveryKinds.contains(kind)).status
    }
}

extension MaterialsModel {
    func analysisStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        fileStatus(kind).title
    }

    func fileStatus(_ kind: MaterialKind) -> StatusPresentation {
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
