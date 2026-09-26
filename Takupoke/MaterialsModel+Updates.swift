import Foundation

extension MaterialsModel {
    func setFileMonitoring(_ foreground: Bool) {
        fileRefreshQueue.setForeground(foreground)
        fileMonitor.setForeground(foreground)
    }

    func updateFileMonitoring() {
        fileMonitor.update([MaterialKind.timetable, .changes].compactMap { kind in
            guard let source = state.record(for: kind)?.source, source.grant != nil else { return nil }
            return SelectedFileSource(id: kind.rawValue, grant: source.grant, childName: source.childName)
        })
    }

    func runPendingFileRefresh() {
        let requested = fileRefreshQueue.take(ready: ready, busy: busy)
        guard !requested.isEmpty else { return }
        let year = automaticChangeSchoolYear
        perform(success: "保存済みファイルの変更を確認しました。") { worker, control in
            var failed = false
            for kind in [MaterialKind.timetable, .changes] where requested.contains(kind.rawValue) {
                let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue)
                FileRefreshDiagnostics.shared.record(.refreshStarted, source: source)
                do {
                    let changed = try worker.refreshIfChanged(kind, defaultYear: year, control: control)
                    FileRefreshDiagnostics.shared.record(changed ? .hashChanged : .hashSame, source: source)
                } catch {
                    FileRefreshDiagnostics.shared.record(.refreshFailed, source: source)
                    failed = true
                }
            }
            if failed { throw MaterialError.providerReadFailed }
        }
    }
}
