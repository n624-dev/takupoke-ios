import SwiftUI

extension MaterialsView {
    func specialStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        specialSchedules.analysisStatus(kind, source: source)
    }

    func materialStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        model.analysisStatus(kind, record: record)
    }

    func materialNeedsAttention(_ kind: MaterialKind, record: MaterialRecord) -> Bool {
        model.state.attempts[kind.rawValue]?.failure != nil ||
            materialStatus(kind, record: record) != "解析済み"
    }

    func fileSummary(name: String, status: String, needsAttention: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).lineLimit(2)
            Label(status, systemImage: needsAttention ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(needsAttention ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
    }
}

extension SpecialSchedulesModel {
    func analysisStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        availability.analysisStatus(kind, source: source, recoveryRejected: rejectedRecoveryKinds.contains(kind))
    }

}

extension MaterialsModel {
    func analysisStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        if rejectedRecoveryKinds.contains(kind.rawValue) { return "保存済み復旧結果を再検証できません" }
        let hasAnalysis: Bool
        let isCurrent: Bool
        if kind == .changes {
            let analysis = state.changeAnalysis
            hasAnalysis = analysis != nil
            isCurrent = analysis?.matches(record: record, defaultYear: automaticChangeSchoolYear) == true
        } else {
            let analysis = state.pdfAnalyses?[kind.rawValue]
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == PDFAnalysis.currentVersion(for: kind)
        }
        let parseFailed = kind == .changes ? (state.changeParseAttempt?.matches(digest: record.digest, defaultYear: automaticChangeSchoolYear) == true && state.changeParseAttempt?.failure != nil) :
            state.pdfParseAttempts?[kind.rawValue]?.failure != nil
        if state.attempts[kind.rawValue]?.failure != nil {
            return hasAnalysis ? "取得失敗（前回結果あり）" : "取得失敗"
        }
        if kind == .changes && parseFailed && isCurrent { return "解析済み（再解析は失敗）" }
        if parseFailed { return hasAnalysis ? "解析失敗（前回結果あり）" : "解析失敗" }
        if isCurrent { return "解析済み" }
        return hasAnalysis ? "未解析（前回結果あり）" : "未解析"
    }

}
