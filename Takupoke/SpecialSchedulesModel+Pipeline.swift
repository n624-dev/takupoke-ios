import Foundation

extension SpecialSchedulesModel {
    nonisolated static func pipeline(_ store: SpecialScheduleStore, kind: SpecialScheduleKind,
                                     reason: FilePipeline.Reason, control: AcquisitionControl,
                                     operation: @escaping (SpecialScheduleStore, AcquisitionControl) throws -> Void) throws {
        guard let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue) else { throw MaterialError.invalidState }
        let started = ProcessInfo.processInfo.systemUptime
        let period = control.period
        let expected = try store.pipelineIdentity(kind)
        let snapshot = store.pipelineSnapshot(kind)
        let workspace = PipelineWorkspace.Lease()
        try FilePipeline.shared.run(source: source, reason: reason, period: period, cancelled: control.check,
            registerCancellation: control.registerCancellationTarget, work: { ticket in
            let root = try workspace.create()
            try ticket.check()
            let copy = try snapshot.open(at: root)
            try ticket.check()
            let inner = AcquisitionControl(); inner.pipelineTicket = ticket; inner.provider = control.provider
            var failure: Error?
            do { try operation(copy, inner) }
            catch {
                try ticket.check()
                if FileOperationOutcome.isCancellation(error) || (FilePipeline.isTransient(error, stage: ticket.stage) && reason != .review && reason != .background && ticket.attempt < FilePipeline.shared.limits.retries) { throw error }
                if let parse = error as? PDFParseError { try copy.recordFailure(parse, kind: kind) }
                else { try copy.recordAcquisitionFailure(kind: kind) }
                failure = error
            }
            return (copy, failure, inner.acquiredProviderSources)
        }, cleanup: workspace.removeAll, retryQueue: store.ownerQueue, requestID: control.operationID, budgetStartedAt: started, expectedIntent: control.intentSnapshot[source.rawValue], commit: { outcome, ticket in
            let (copy, error, acquired) = outcome
            try store.acceptPipeline(copy, kind: kind, expected: expected, ticket: ticket)
            for id in acquired { control.recordProviderAcquisition(id) }
            if let error { throw error }
        })
    }
}
