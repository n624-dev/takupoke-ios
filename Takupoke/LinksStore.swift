import Foundation

final class LinksStore {
    private let file: URL

    init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var protectedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        #endif
        file = root.appendingPathComponent("links.json")
    }

    func load() throws -> SavedLinks? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= LinksPayload.maximumBytes + 100_000 else { throw LinksError.invalidResponse }
        let saved = try JSONDecoder().decode(SavedLinks.self, from: Data(contentsOf: file))
        guard LinksResponse.validETag(saved.apiETag) else { throw LinksError.invalidResponse }
        _ = try LinksPayload.decode(JSONEncoder().encode(saved.payload))
        return saved
    }

    func save(_ saved: SavedLinks) throws {
        guard LinksResponse.validETag(saved.apiETag) else { throw LinksError.invalidResponse }
        _ = try LinksPayload.decode(JSONEncoder().encode(saved.payload))
        try JSONEncoder().encode(saved).write(to: file, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
        #endif
    }
}

struct LinkPreferences: Codable, Equatable {
    var favoriteIDs: Set<String> = []
    var hiddenIDs: Set<String> = []
    var colorOverrides: [String: String] = [:]
}

final class LinkPreferencesStore {
    private let defaults: UserDefaults
    private let key = "linkPreferences.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> LinkPreferences {
        guard let data = defaults.data(forKey: key) else { return LinkPreferences() }
        return try JSONDecoder().decode(LinkPreferences.self, from: data)
    }

    func save(_ preferences: LinkPreferences) throws {
        guard preferences.colorOverrides.values.allSatisfy(LinksPayload.colors.contains) else {
            throw LinksError.invalidResponse
        }
        defaults.set(try JSONEncoder().encode(preferences), forKey: key)
    }
}
