import Foundation

extension MaterialWorker {
    func pipeline(_ kind: MaterialKind, reason: FilePipeline.Reason, control: AcquisitionControl,
                  operation: @escaping (MaterialWorker, AcquisitionControl) throws -> Void) throws {
        guard let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue) else {
            try operation(self, control); return // Legacy events PDF is not a selected timetable file.
        }
        guard let library else { throw MaterialError.invalidState }
        let started = ProcessInfo.processInfo.systemUptime
        let expected = try library.pipelineIdentity(kind)
        let period = control.period
        let snapshot = library.pipelineSnapshot(kind)
        let workspace = PipelineWorkspace.Lease()
        try FilePipeline.shared.run(source: source, reason: reason, period: period, cancelled: control.check,
            registerCancellation: control.registerCancellationTarget, work: { ticket in
            let root = try workspace.create()
            try ticket.check()
            let copy = try snapshot.open(at: root)
            try ticket.check()
            let isolated = MaterialWorker(library: copy)
            let inner = AcquisitionControl(); inner.pipelineTicket = ticket; inner.provider = control.provider
            var failure: Error?
            do { try operation(isolated, inner) }
            catch {
                try ticket.check()
                if FileOperationOutcome.isCancellation(error) || (FilePipeline.isTransient(error, stage: ticket.stage) && reason != .review && reason != .background && ticket.attempt < FilePipeline.shared.limits.retries) { throw error }
                failure = error
            }
            return (isolated, failure, inner.acquiredProviderSources)
        }, cleanup: workspace.removeAll, retryQueue: ownerQueue, requestID: control.operationID, budgetStartedAt: started, expectedIntent: control.intentSnapshot[source.rawValue], commit: { outcome, ticket in
            let (isolated, error, acquired) = outcome
            guard let copy = isolated.library else { throw MaterialError.invalidState }
            try library.acceptPipeline(copy, kind: kind, expected: expected, ticket: ticket)
            if kind == .changes { self.changePreview = isolated.changePreview }
            if kind == .timetable && (isolated.recoveryCapturedStoredName != nil || isolated.timetableFailure != nil || isolated.timetableReadReport != nil) {
                self.timetableReadReport = isolated.timetableReadReport
                self.timetableFailure = isolated.timetableFailure
                self.recoveryCapture = isolated.recoveryCapture
                self.recoveryCapturedStoredName = isolated.recoveryCapturedStoredName
            }
            for id in acquired { control.recordProviderAcquisition(id) }
            if let error { throw error }
        })
    }
}
