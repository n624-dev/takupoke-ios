import Foundation

extension MaterialsModel {
    func setFileMonitoring(_ foreground: Bool) {
        fileRefreshQueue.setForeground(foreground)
        fileMonitor.setForeground(foreground)
    }

    func updateFileMonitoring(retryFailed: Bool = false) {
        fileMonitor.update([MaterialKind.timetable, .changes].compactMap { kind in
            guard let source = state.record(for: kind)?.source, source.grant != nil else { return nil }
            return SelectedFileSource(id: kind.rawValue, grant: source.grant, childName: source.childName)
        }, retryFailed: retryFailed)
    }

    func runPendingFileRefresh() {
        let requested = fileRefreshQueue.take(ready: ready, busy: busy)
        guard !requested.isEmpty else { return }
        let year = automaticChangeSchoolYear
        perform(success: "保存済みファイルの変更を確認しました。", preserveChangePreview: true) { worker, control in
            try Self.refreshSelectedFiles(worker, requested: requested, year: year, control: control)
        }
    }

    nonisolated static func refreshSelectedFiles(_ worker: MaterialWorker, requested: Set<String>,
                                                 year: Int?, control: AcquisitionControl) throws {
        try SelectedFileRefresher.refresh(requested: requested, year: year, check: control.check) { kind in
            try worker.refreshIfChanged(kind, defaultYear: year, control: control)
        }
    }
}
