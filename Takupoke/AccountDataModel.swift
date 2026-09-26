import SwiftUI

/// A single user-initiated authorization supplies both private data sets.
/// Tokens live only inside this task; each validated data set commits independently.
@MainActor
final class AccountDataModel: ObservableObject {
    @Published private(set) var busy = false
    private let oidc = MappingOIDC()
    private var task: Task<Void, Never>?

    func refresh(mappings: MappingModel, links: LinksModel) async {
        guard !busy, !mappings.busy, !links.busy else { return }
        busy = true
        let operation = Task {
            let network = LinksModel.networkSession()
            defer { network.invalidateAndCancel(); busy = false; task = nil }
            var mappingRevision: String?
            var linkRevision: String?
            do {
                if case .available(let revision) = try await mappings.revision(using: network) { mappingRevision = revision }
            } catch { if !Task.isCancelled { mappings.report(error) } }
            do {
                if case .available(let revision) = try await links.revision(using: network) { linkRevision = revision }
            } catch { if !Task.isCancelled { links.report(error) } }
            guard !Task.isCancelled, mappingRevision != nil || linkRevision != nil else { return }
            do {
                let token = try await oidc.accessToken(using: network)
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
            } catch {
                if !Task.isCancelled {
                    if mappingRevision != nil { mappings.report(error) }
                    if linkRevision != nil { links.report(error) }
                }
            }
        }
        task = operation
        await operation.value
    }

    func stopForRetention() async {
        task?.cancel()
        oidc.cancel()
        await task?.value
    }
}
