import Foundation

final class LinksStore {
    let file: URL
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
    private static let knownKeys: Set<String> = ["favoriteIDs", "hiddenIDs", "colorOverrides"]

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> LinkPreferences {
        guard let saved = defaults.object(forKey: key) else { return LinkPreferences() }
        guard let data = saved as? Data else { throw LinksError.invalidResponse }
        let fields = try preferenceFields(data)
        guard Set(fields.keys) == Self.knownKeys else { throw LinksError.invalidResponse }
        return try JSONDecoder().decode(LinkPreferences.self, from: data)
    }

    func recoverReadableValues() throws -> LinkPreferences? {
        guard let data = defaults.data(forKey: key), (try? load()) == nil else { return nil }
        let fields = try preferenceFields(data)
        var recovered = LinkPreferences()
        var recognized = false
        if let values = fields["favoriteIDs"] as? [Any] {
            recovered.favoriteIDs = Set(values.compactMap { $0 as? String })
            recognized = true
        }
        if let values = fields["hiddenIDs"] as? [Any] {
            recovered.hiddenIDs = Set(values.compactMap { $0 as? String })
            recognized = true
        }
        if let values = fields["colorOverrides"] as? [String: Any] {
            recovered.colorOverrides = values.compactMapValues { $0 as? String }
            recognized = true
        }
        guard recognized else { return nil }
        let bytes = try JSONEncoder().encode(recovered)
        let retained = key + ".retained." + UUID().uuidString
        defaults.set(data, forKey: retained)
        guard defaults.data(forKey: retained) == data, defaults.data(forKey: key) == data else {
            throw LinksError.invalidResponse
        }
        defaults.set(bytes, forKey: key)
        return recovered
    }

    private func preferenceFields(_ data: Data) throws -> [String: Any] {
        guard let fields = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(fields.keys).isSubset(of: Self.knownKeys) else { throw LinksError.invalidResponse }
        return fields
    }

    func save(_ preferences: LinkPreferences) throws {
        let original = try load().colorOverrides
        let unsupported = preferences.colorOverrides.filter { !LinksPayload.colors.contains($0.value) }
        if !unsupported.isEmpty {
            // Carry forward an opaque saved color without accepting any new unsupported value.
            guard unsupported.allSatisfy({ original[$0.key] == $0.value }) else { throw LinksError.invalidResponse }
        }
        defaults.set(try JSONEncoder().encode(preferences), forKey: key)
    }
}
