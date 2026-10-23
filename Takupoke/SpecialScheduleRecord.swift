import Foundation

struct SpecialScheduleRecord: Codable {
    let kind: SpecialScheduleKind
    let originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    let analysis: SpecialScheduleAnalysis
}

struct SpecialScheduleSource: Codable {
    let kind: SpecialScheduleKind
    var originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    var lastCheckedAt: Date? = nil
    var failure: PDFParseError?
    var recoveryJob: RecoveryJob? = nil
    var attemptParserVersion: Int? = nil
    var acquisitionFailure: String? = nil
    var grant: SourceGrant?
}

/// Shared by Home and the week view. Missing analysis is distinct from a
/// document that was never selected; retained results remain visible with notice.
struct SpecialScheduleAvailability {
    enum State: Equatable { case loading, loadFailed, unselected, unanalysed, previous, current }
    let ready: Bool
    let busy: Bool
    let failed: Bool
    let sources: [SpecialScheduleKind: SpecialScheduleSource]
    let records: [SpecialScheduleKind: SpecialScheduleRecord]

    var loadFailed: Bool { !ready && !busy && failed }
    func state(for kind: SpecialScheduleKind) -> State {
        guard ready else { return loadFailed ? .loadFailed : .loading }
        guard let source = sources[kind] else { return records[kind] == nil ? .unselected : .previous }
        guard let record = records[kind] else { return .unanalysed }
        return source.digest == record.digest && record.digest == record.analysis.sourceDigest &&
            record.analysis.version == SpecialScheduleAnalysis.parserVersion ? .current : .previous
    }
    func message(for kind: SpecialScheduleKind) -> String? {
        switch state(for: kind) {
        case .unanalysed: return "\(kind.title)の選択した資料をまだ反映できていません。正常な解析結果がありません。"
        case .previous: return "\(kind.title)の新しい資料をまだ反映できていません。前回の正常結果を表示しています。"
        default: return nil
        }
    }
}

enum ScheduleLoadState: CaseIterable {
    case loading, failed, ready
    init(ready: Bool, busy: Bool, failed: Bool) {
        self = ready ? .ready : failed && !busy ? .failed : .loading
    }
}

struct HomeScheduleAvailability {
    let materials: ScheduleLoadState
    let specials: ScheduleLoadState
    let events: ScheduleLoadState
    var ready: Bool { materials == .ready }
    var loadFailed: Bool { materials == .failed }
}
