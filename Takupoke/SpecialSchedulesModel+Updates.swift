import Foundation

extension SpecialSchedulesModel {
    func setFileMonitoring(_ foreground: Bool) {
        fileRefreshQueue.setForeground(foreground)
        fileMonitor.setForeground(foreground)
    }

    func updateFileMonitoring(retryFailed: Bool = false) {
        fileMonitor.update(SpecialScheduleKind.allCases.compactMap { kind in
            guard let source = sources[kind] else { return nil }
            return SelectedFileSource(id: kind.rawValue, grant: source.grant)
        }, retryFailed: retryFailed)
    }
}
