import Foundation

enum MappingRevisionResult: Equatable {
    case unchanged
    case available(String)
}

struct MappingService {
    let baseURL: URL
    let network: URLSession

    func checkRevision(installed: String?, path: String = "mapping-revision") async throws -> MappingRevisionResult {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let installed { request.setValue("\"\(installed)\"", forHTTPHeaderField: "If-None-Match") }
        let (data, rawResponse) = try await network.data(for: request)
        guard let response = rawResponse as? HTTPURLResponse, data.isEmpty else { throw MappingError.invalidResponse }
        switch response.statusCode {
        case 304:
            guard installed != nil else { throw MappingError.invalidResponse }
            return .unchanged
        case 200:
            guard let etag = response.value(forHTTPHeaderField: "ETag"), etag.count == 45,
                  etag.first == "\"", etag.last == "\"" else { throw MappingError.invalidResponse }
            let revision = String(etag.dropFirst().dropLast())
            guard MappingPackage.validRevision(revision) else { throw MappingError.invalidResponse }
            return revision == installed ? .unchanged : .available(revision)
        default:
            throw MappingError.unavailable
        }
    }

    func download(accessToken: String, expectedRevision: String) async throws -> SavedMapping {
        guard MappingPackage.validRevision(expectedRevision), !accessToken.isEmpty else { throw MappingError.invalidResponse }
        var request = URLRequest(url: baseURL.appendingPathComponent("mappings").appendingPathComponent("current"))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/zip", forHTTPHeaderField: "Accept")
        let (temporary, rawResponse) = try await network.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = rawResponse as? HTTPURLResponse else { throw MappingError.invalidResponse }
        if response.statusCode == 401 || response.statusCode == 403 { throw MappingError.authentication }
        guard response.statusCode == 200,
              response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("application/zip") == true,
              let version = response.value(forHTTPHeaderField: "X-Mapping-Version"),
              let revision = response.value(forHTTPHeaderField: "X-Mapping-Revision"),
              let archiveETag = response.value(forHTTPHeaderField: "ETag") else { throw MappingError.unavailable }
        guard revision == expectedRevision else { throw MappingError.changedDuringDownload }
        guard let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 8 * 1024 * 1024 else { throw MappingError.invalidPackage }
        let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
        return try MappingPackage.decode(data, version: version, revision: revision, archiveETag: archiveETag)
    }
}
