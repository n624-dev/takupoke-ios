import Foundation

extension SpecialSchedulesModel {
    func checkForUpdates(_ kind: SpecialScheduleKind? = nil) {
        guard ready, !busy else { return }
        let requested = Set((kind.map { [$0] } ?? SpecialScheduleKind.allCases).compactMap {
            sources[$0] == nil ? nil : $0.rawValue
        })
        guard !requested.isEmpty else { return }
        perform(success: "選択済みファイルの更新を確認しました。") { store, control, _ in
            try Self.refreshSelectedFiles(store, requested: requested, control: control, reason: .manual)
        }
    }

    func refresh(_ kind: SpecialScheduleKind) {
        guard ready, sources[kind]?.grant != nil else { return }
        if busy || FilePipeline.shared.isRecovering(kind.rawValue) { pendingManualRefresh.insert(kind); return }
        perform(success: "\(kind.title)を再取得して解析しました。") { store, control, _ in
            try Self.refreshSelectedFiles(store, requested: [kind.rawValue], control: control, force: true)
        }
    }

    func setFileMonitoring(_ foreground: Bool) {
        observePipeline(foreground)
        fileRefreshQueue.setForeground(foreground)
        fileMonitor.setForeground(foreground)
    }

    func updateFileMonitoring(retryFailedFor acquired: Set<String>) {
        fileMonitor.update(SpecialScheduleKind.allCases.compactMap { kind in
            guard let source = sources[kind] else { return nil }
            return SelectedFileSource(id: kind.rawValue, grant: source.grant)
        }, retryFailedFor: acquired)
    }
}
