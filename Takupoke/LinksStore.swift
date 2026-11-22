import Foundation

final class LinksStore {
    private let file: URL
    private static let maximumSavedBytes = LinksPayload.maximumBytes + 100_000

    private static func cacheEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Match the compact API representation when applying its payload limit.
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }

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
              size <= Self.maximumSavedBytes else { throw LinksError.invalidResponse }
        let data = try Data(contentsOf: file)
        guard data.count <= Self.maximumSavedBytes else { throw LinksError.invalidResponse }
        let saved = try JSONDecoder().decode(SavedLinks.self, from: data)
        guard LinksResponse.validETag(saved.apiETag) else { throw LinksError.invalidResponse }
        _ = try LinksPayload.decode(Self.cacheEncoder().encode(saved.payload))
        return saved
    }

    func save(_ saved: SavedLinks) throws {
        guard LinksResponse.validETag(saved.apiETag) else { throw LinksError.invalidResponse }
        let encoder = Self.cacheEncoder()
        _ = try LinksPayload.decode(encoder.encode(saved.payload))
        let data = try encoder.encode(saved)
        guard data.count <= Self.maximumSavedBytes else { throw LinksError.invalidResponse }
        try data.write(to: file, options: .atomic)
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
        let unsupported = preferences.colorOverrides.filter { !LinksPayload.colors.contains($0.value) }
        if !unsupported.isEmpty {
            // Carry forward an opaque saved color without accepting any new unsupported value.
            let original = try load().colorOverrides
            guard unsupported.allSatisfy({ original[$0.key] == $0.value }) else { throw LinksError.invalidResponse }
        }
        defaults.set(try JSONEncoder().encode(preferences), forKey: key)
    }
}
