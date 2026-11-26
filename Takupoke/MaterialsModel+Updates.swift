import Foundation

extension MaterialsModel {
    func checkForUpdates(_ kind: MaterialKind? = nil) {
        guard ready, !busy else { return }
        let requested = Set((kind.map { [$0] } ?? [.timetable, .changes]).compactMap {
            state.record(for: $0) == nil ? nil : $0.rawValue
        })
        guard !requested.isEmpty else { return }
        let year = automaticChangeSchoolYear
        perform(success: "選択済みファイルの更新を確認しました。", preserveChangePreview: true) { worker, control in
            try Self.refreshSelectedFiles(worker, requested: requested, year: year, control: control, reason: .manual)
        }
    }

    func setFileMonitoring(_ foreground: Bool) {
        observePipeline(foreground)
        fileRefreshQueue.setForeground(foreground)
        fileMonitor.setForeground(foreground)
    }

    func updateFileMonitoring(retryFailedFor acquired: Set<String>) {
        fileMonitor.update([MaterialKind.timetable, .changes].compactMap { kind in
            guard let source = state.record(for: kind)?.source, source.grant != nil else { return nil }
            return SelectedFileSource(id: kind.rawValue, grant: source.grant, childName: source.childName)
        }, retryFailedFor: acquired)
    }

    func runPendingFileRefresh() {
        let requested = fileRefreshQueue.take(ready: ready, busy: busy, blocked: Set(FilePipeline.shared.activeSources.map(\.rawValue)))
        guard !requested.isEmpty else { return }
        let year = automaticChangeSchoolYear
        perform(success: "保存済みファイルの変更を確認しました。", preserveChangePreview: true) { worker, control in
            try Self.refreshSelectedFiles(worker, requested: requested, year: year, control: control)
        }
    }

    nonisolated static func refreshSelectedFiles(_ worker: MaterialWorker, requested: Set<String>,
                                                 year: Int?, control: AcquisitionControl, reason: FilePipeline.Reason = .automatic) throws {
        try SelectedFileRefresher.refresh(requested: requested, check: control.check) { kind in
            try worker.pipeline(kind, reason: reason, control: control) { worker, control in
                try worker.refreshIfChanged(kind, defaultYear: year, control: control)
            }
        }
    }
}
