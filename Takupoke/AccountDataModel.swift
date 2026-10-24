import SwiftUI

/// A single user-initiated authorization supplies the private data sets.
/// Tokens are cached only in memory until expiry; each validated data set commits independently.
@MainActor
final class AccountDataModel: ObservableObject {
    @Published private(set) var busy = false
    private let oidc = MappingOIDC()
    private var task: Task<Void, Never>?

    func refresh(mappings: MappingModel, links: LinksModel, times: TimetableTimesModel,
                 selection: AccountDataSelection = .all) async {
        guard !selection.isEmpty, selection.subtracting(.all).isEmpty else { return }
        guard !busy, !mappings.busy, !times.busy else { return }
        busy = true
        let operation = Task {
            let network = LinksModel.networkSession()
            defer { network.invalidateAndCancel(); busy = false; task = nil }
            var mappingRevision: String?
            var linkRevision: String?
            var timesRevision: String?
            do {
                if selection.contains(.mappings), case .available(let revision) = try await mappings.revision(using: network) { mappingRevision = revision }
            } catch { if !Task.isCancelled { mappings.report(error) } }
            do {
                if selection.contains(.links), case .available(let revision) = try await links.revision() { linkRevision = revision }
            } catch { if !Task.isCancelled { links.report(error) } }
            do {
                if selection.contains(.times), case .available(let revision) = try await times.revision(using: network) { timesRevision = revision }
            } catch { if !Task.isCancelled { times.report(error) } }
            guard !Task.isCancelled, mappingRevision != nil || linkRevision != nil || timesRevision != nil else { return }
            do {
                let token = try await oidc.accessToken(using: network, selection: selection)
                try Task.checkCancellation()
                if let revision = mappingRevision {
                    do { try await mappings.download(token: token, revision: revision, network: network) }
                    catch { if !Task.isCancelled { mappings.report(error) } }
                }
                try Task.checkCancellation()
                if let revision = linkRevision {
                    do { try await links.download(token: token, revision: revision, network: network) }
                    catch { if !Task.isCancelled { links.report(error) } }
                }
                try Task.checkCancellation()
                if let revision = timesRevision {
                    do { try await times.download(token: token, revision: revision, network: network) }
                    catch { if !Task.isCancelled { times.report(error) } }
                }
            } catch {
                if !Task.isCancelled {
                    if timesRevision != nil { times.report(error) }
                    if mappingRevision != nil { mappings.report(error) }
                    if linkRevision != nil { links.report(error) }
                }
            }
        }
        task = operation
        await operation.value
    }

    func stopForRetention() async {
        cancel()
        await task?.value
    }

    func cancel() {
        task?.cancel()
        oidc.cancel()
    }
}
