import Foundation

enum DataUpdateState: Equatable {
    case unused, unconfirmed, checking, confirmed, updateAvailable, updateWaiting, failed, unavailable

    static func withoutLocalData(checking: Bool, failed: Bool) -> Self {
        if checking { return .checking }
        return failed ? .unavailable : .unused
    }

    static func distributed(acquired: Bool, updateAvailable: Bool, failed: Bool, busy: Bool,
                            confirmation: DistributedRevisionConfirmation?) -> Self {
        if !acquired { return withoutLocalData(checking: busy, failed: failed) }
        if busy { return .checking }
        if failed || confirmation?.outcome == .failed { return .failed }
        if updateAvailable { return .updateAvailable }
        return confirmation?.outcome == .unchanged ? .confirmed : .unconfirmed
    }
}

/// Evidence shown to the user, independent of the color or screen presenting it.
struct StatusPresentation: Equatable {
    enum Tone: Equatable { case good, checking, neutral, unknown, attention, unavailable }
    let title: String
    let tone: Tone
    var detail: String? = nil

    var needsAttention: Bool { tone == .attention || tone == .unavailable }
    var symbol: String {
        switch tone {
        case .good: return "checkmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .neutral: return "minus.circle"
        case .unknown: return "questionmark.circle"
        case .attention: return "exclamationmark.triangle"
        case .unavailable: return "xmark.circle"
        }
    }

    static func summary(_ values: [Self], checking: Bool = false, paused: Bool = false) -> Self {
        let attention = values.filter(\.needsAttention)
        if !attention.isEmpty {
            if attention.allSatisfy({ $0.title == "更新待ち" }) {
                return .init(title: "更新待ち", tone: .attention, detail: attention.first?.detail)
            }
            return .init(title: "要確認 \(attention.count)件", tone: .attention,
                         detail: checking ? "更新状況も確認しています。" : "詳しい状態と対処方法を確認できます。")
        }
        if checking || values.contains(where: { $0.tone == .checking }) {
            return .init(title: "確認中", tone: .checking)
        }
        if paused {
            return .init(title: "自動確認を一時停止中", tone: .neutral,
                         detail: "次にアプリを開き直すと再開します。")
        }
        if values.isEmpty || values.contains(where: { $0.tone == .unknown }) {
            return .init(title: "未確認の項目があります", tone: .unknown)
        }
        if values.contains(where: { $0.tone == .neutral }) {
            return .init(title: "各項目の状態を確認できます", tone: .neutral)
        }
        return .init(title: "確認した項目は正常です", tone: .good)
    }

    static func downloaded(acquired: Bool, updateAvailable: Bool, failed: Bool, busy: Bool,
                           confirmation: DistributedRevisionConfirmation? = nil) -> Self {
        switch DataUpdateState.distributed(acquired: acquired, updateAvailable: updateAvailable,
                                           failed: failed, busy: busy, confirmation: confirmation) {
        case .checking: return .init(title: "確認・取得中", tone: .checking)
        case .failed, .unavailable:
            return .init(title: "要確認", tone: .attention,
                         detail: acquired ? "前回取得したデータは保持しています。" : "データを取得できていません。")
        case .unused: return .init(title: "未取得", tone: .neutral)
        case .updateAvailable: return .init(title: "更新あり", tone: .attention)
        case .confirmed: return .init(title: "更新確認済み", tone: .good)
        case .unconfirmed, .updateWaiting:
            if confirmation?.outcome == .adopted {
                return .init(title: "取得済み", tone: .neutral, detail: "配信版を検証して保存しました。")
            }
            return .init(title: "保存済み・更新未確認", tone: .unknown)
        }
    }

    static func dataSummary(_ values: [(title: String, state: DataUpdateState)]) -> Self {
        let issues = values.filter { [.unavailable, .failed, .updateAvailable, .updateWaiting].contains($0.state) }
        let checking = values.contains { $0.state == .checking }
        let unavailable = issues.filter { $0.state == .unavailable }
        if let issue = unavailable.first {
            let title = unavailable.count == 1 ? "\(issue.title)を利用できません" : "\(unavailable.count)件のデータを利用できません"
            return .init(title: title, tone: .unavailable, detail: checking ? "他のデータの更新を確認中です。" : nil)
        }
        if issues.count > 1 {
            return .init(title: "要確認 \(issues.count)件", tone: .attention,
                         detail: checking ? "他のデータの更新を確認中です。" : nil)
        }
        if let issue = issues.first {
            switch issue.state {
            case .updateWaiting:
                return .init(title: "更新待ち", tone: .attention, detail: "\(issue.title)は配信元の更新待ちです。")
            case .updateAvailable:
                return .init(title: "\(issue.title)に更新があります", tone: .attention)
            default:
                return .init(title: "\(issue.title)の更新を確認できません", tone: .attention)
            }
        }
        if checking { return .init(title: "更新を確認中", tone: .checking) }
        let unknown = values.filter { $0.state == .unconfirmed }
        if let item = unknown.first {
            let title = unknown.count == 1 ? "\(item.title)の更新が未確認" : "\(unknown.count)件のデータの更新が未確認"
            return .init(title: title, tone: .unknown)
        }
        if values.contains(where: { $0.state == .confirmed }) {
            return .init(title: "更新確認済み", tone: .good)
        }
        return .init(title: "データを設定してください", tone: .neutral)
    }

    static func schoolEvents(ready: Bool, failed: Bool, checking: Bool, cacheFailed: Bool,
                             acquired: Bool, source: SchoolEventsSourcePresentation?) -> Self {
        guard ready else {
            return .init(title: failed ? "保存データを読み込めません" : "保存データを確認中",
                         tone: failed ? .unavailable : .checking)
        }
        if cacheFailed { return .init(title: "再取得が必要", tone: .attention) }
        if acquired, let source, source.updateWaiting || source.evidence == .differs {
            return .init(title: "更新待ち", tone: .attention, detail: source.warningMessage ?? source.message)
        }
        if checking {
            return .init(title: acquired ? "行事データを確認中" : "行事データを取得中", tone: .checking)
        }
        if failed {
            return .init(title: "取得状況の確認が必要", tone: .attention,
                         detail: acquired ? "前回取得した行事データは保持しています。" : nil)
        }
        guard acquired else { return .init(title: "未取得", tone: .neutral) }
        guard let source else { return .init(title: "元PDFは未確認", tone: .unknown) }
        if let warning = source.warningMessage {
            return .init(title: "内容・更新状況の確認が必要", tone: .attention, detail: warning)
        }
        switch source.evidence {
        case .matched: return .init(title: "元PDFの一致を確認", tone: .good, detail: "行事内容の正確さを保証する判定ではありません。")
        case .differs: return .init(title: "更新待ち", tone: .attention, detail: source.message)
        case .checking: return .init(title: "元PDFを確認中", tone: .checking)
        case .unknown: return .init(title: "元PDFは未確認", tone: .unknown, detail: source.message)
        }
    }
}

enum FileOperationOutcome {
    static func isCancellation(_ error: Error) -> Bool {
        if case MaterialError.cancelled = error { return true }
        if (error as? FilePipeline.Failure) == .cancelled { return true }
        return error is CancellationError || (error as? PDFParseError)?.code == .cancelled ||
            (error as? ChangeParseError)?.code == .cancelled
    }
}

struct FileStatusPresentation {
    let status: StatusPresentation
    let hasSavedAnalysis: Bool
    let updateState: DataUpdateState

    static func material(_ state: MaterialLibraryState, kind: MaterialKind, year: Int?,
                         recoveryRejected: Bool = false) -> Self {
        guard let record = state.record(for: kind) else {
            if state.attempts[kind.rawValue]?.failedToAcquire == true {
                return .init(status: .init(title: "取得できませんでした", tone: .attention,
                                          detail: state.attempts[kind.rawValue]?.failure), hasSavedAnalysis: false, updateState: .unavailable)
            }
            return .init(status: .init(title: "未選択", tone: .neutral), hasSavedAnalysis: false, updateState: .unused)
        }
        let hasAnalysis: Bool
        let isCurrent: Bool
        let parseFailed: Bool
        let parseCancelled: Bool
        if kind == .changes {
            hasAnalysis = state.changeAnalysis != nil
            isCurrent = state.changeAnalysis?.matches(record: record, defaultYear: year) == true
            let attempt = state.changeParseAttempt
            let matching = attempt?.matches(digest: record.digest, defaultYear: year) == true
            parseCancelled = matching && attempt?.failure?.code == .cancelled
            parseFailed = matching && attempt?.failure != nil && !parseCancelled
        } else {
            let analysis = state.pdfAnalyses?[kind.rawValue]
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == PDFAnalysis.currentVersion(for: kind)
            let failure = state.pdfParseAttempts?[kind.rawValue]?.failure
            parseCancelled = failure?.code == .cancelled
            parseFailed = failure != nil && !parseCancelled
        }
        let result: StatusPresentation
        let updateState: DataUpdateState
        if recoveryRejected {
            result = .init(title: "保存済み復旧結果を再検証できません", tone: .attention)
            updateState = .unavailable
        } else if state.attempts[kind.rawValue]?.failedToAcquire == true {
            result = .init(title: hasAnalysis ? "取得失敗（前回結果あり）" : "取得失敗", tone: .attention,
                           detail: state.attempts[kind.rawValue]?.failure)
            updateState = hasAnalysis ? .failed : .unavailable
        } else if parseFailed {
            result = .init(title: kind == .changes && isCurrent ? "解析済み（再解析は失敗）" :
                            hasAnalysis ? "解析失敗（前回結果あり）" : "解析失敗", tone: .attention)
            updateState = hasAnalysis ? .failed : .unavailable
        } else if state.attempts[kind.rawValue]?.wasCancelled == true || parseCancelled {
            result = .init(title: "確認・解析を中止しました", tone: .neutral,
                           detail: hasAnalysis ? "保存済みの解析結果は保持しています。" : "まだ正常な解析結果はありません。")
            updateState = !hasAnalysis ? .unavailable : (isCurrent && record.lastCheckedAt != nil ? .confirmed : .unconfirmed)
        } else if isCurrent {
            result = .init(title: "解析済み", tone: .good)
            updateState = record.lastCheckedAt == nil ? .unconfirmed : .confirmed
        } else {
            result = .init(title: hasAnalysis ? "未解析（前回結果あり）" : "未解析", tone: .attention)
            updateState = hasAnalysis ? .failed : .unavailable
        }
        return .init(status: result, hasSavedAnalysis: hasAnalysis, updateState: updateState)
    }

    static func special(_ availability: SpecialScheduleAvailability, kind: SpecialScheduleKind,
                        recoveryRejected: Bool = false) -> Self {
        let saved = availability.records[kind] != nil
        guard let source = availability.sources[kind] else {
            return .init(status: .init(title: saved ? "前回の解析結果あり" : "未選択",
                                      tone: saved ? .attention : .neutral), hasSavedAnalysis: saved, updateState: saved ? .failed : .unused)
        }
        let result: StatusPresentation
        let updateState: DataUpdateState
        if recoveryRejected {
            result = .init(title: "保存済み復旧結果を再検証できません", tone: .attention)
            updateState = .unavailable
        } else if source.acquisitionFailure != nil {
            result = .init(title: saved ? "更新確認失敗（前回結果あり）" : "更新確認失敗", tone: .attention)
            updateState = saved ? .failed : .unavailable
        } else if source.failure?.code == .cancelled {
            result = .init(title: "解析を中止しました", tone: .neutral,
                           detail: saved ? "保存済みの解析結果は保持しています。" : "まだ正常な解析結果はありません。")
            updateState = !saved ? .unavailable :
                (availability.state(for: kind) == .current && source.lastCheckedAt != nil ? .confirmed : .unconfirmed)
        } else if source.failure != nil {
            result = .init(title: saved ? "解析失敗（前回結果あり）" : "解析失敗", tone: .attention)
            updateState = saved ? .failed : .unavailable
        } else if source.grant == nil {
            result = .init(title: "再選択が必要", tone: .attention)
            updateState = saved ? .failed : .unavailable
        } else if availability.state(for: kind) == .current {
            result = .init(title: "解析済み", tone: .good)
            updateState = source.lastCheckedAt == nil ? .unconfirmed : .confirmed
        } else {
            result = .init(title: saved ? "未解析（前回結果あり）" : "未解析", tone: .attention)
            updateState = saved ? .failed : .unavailable
        }
        return .init(status: result, hasSavedAnalysis: saved, updateState: updateState)
    }
}

extension AcquisitionAttempt {
    var wasCancelled: Bool { failure != nil && !failedToAcquire }
}

extension MaterialLibraryState {
    func excludedChangeRows(year: Int?) -> [Int] {
        guard let source = record(for: .changes) else { return [] }
        let identity = source.source.selectionID ?? source.storedName
        if let personal = source.source.personalChanges, personal.year == year,
           let rows = personal.rows, rows.sourceIdentity == identity, rows.digest == source.digest,
           changeAnalysis?.matches(record: source, defaultYear: year) == true {
            return rows.entries.filter { $0.edit.excluded }.map(\.row)
        }
        if let skip = source.source.rowSkipConsent,
           skip.matches(sourceIdentity: identity, digest: source.digest, defaultYear: year) { return skip.rows }
        return []
    }
}


extension FilePipeline.Status {
    var presentation: StatusPresentation {
        if waitingForWorker {
            return .init(title: stage == .cancelled ? "中止しました・終了待ち" : "期限切れ・終了待ち", tone: stage == .cancelled ? .neutral : .attention,
                         detail: "前回の正常結果を保持しています。同じファイルは旧処理の終了後に再取得できます。")
        }
        switch stage {
        case .queued: return .init(title: "確認待ち", tone: .checking)
        case .access: return .init(title: "ファイルへのアクセス待ち", tone: .checking)
        case .acquiring: return .init(title: "ファイルを取得中", tone: .checking)
        case .checkingDigest: return .init(title: "内容の変更を確認中", tone: .checking)
        case .parsing: return .init(title: "ファイルを解析中", tone: .checking)
        case .validating: return .init(title: "解析結果を検証中", tone: .checking)
        case .saving: return .init(title: "解析結果を保存中", tone: .checking)
        case .cancelled: return .init(title: "確認を中止しました", tone: .neutral)
        case .timedOut: return .init(title: "更新確認が期限切れになりました", tone: .attention, detail: "前回の正常結果は保持しています。再取得できます。")
        case .recovering: return .init(title: "旧処理の終了待ち", tone: .neutral)
        case .failed: return .init(title: "更新を確認できませんでした", tone: .attention)
        case .succeeded, .unchanged: return .init(title: "更新確認済み", tone: .good)
        }
    }
}
