import Foundation

/// Builds a verified candidate in an isolated directory. It never activates SQLite,
/// edits library.json, or invokes MaterialLibrary's legacy garbage collector.
/// Call only while acquisitions/legacy writes are suspended on the material worker.
enum LegacyDatabaseMigration {
    enum Stage { case copiedOriginal, imported, reopened }
    enum MigrationError: Error { case invalidSource, overlappingDirectories, sourceChanged, verificationFailed }

    /// On success the caller owns the returned candidate and must retain it until
    /// activation or discard. Failure only removes this invocation's UUID directory.
    static func prepare(legacyRoot: URL, candidatesRoot: URL,
                        checkpoint: (Stage) throws -> Void = { _ in }) throws -> URL {
        let source = legacyRoot.resolvingSymlinksInPath().standardizedFileURL
        let parent = candidatesRoot.resolvingSymlinksInPath().standardizedFileURL
        guard !contains(source, parent), !contains(parent, source) else {
            throw MigrationError.overlappingDirectories
        }
        let manifest = source.appendingPathComponent("library.json")
        let manifestData = try readRegularFile(manifest, maximum: 64 * 1024 * 1024)
        let state = try MaterialLibrary.decodeLegacyManifest(manifestData)
        let manager = FileManager.default
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let candidate = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
        // withIntermediateDirectories=false: do not take ownership of an existing directory.
        try manager.createDirectory(at: candidate, withIntermediateDirectories: false)
        var finished = false
        defer { if !finished { try? manager.removeItem(at: candidate) } }
        try protect(candidate)
        let files = candidate.appendingPathComponent("files", isDirectory: true)
        try manager.createDirectory(at: files, withIntermediateDirectories: false)
        try protect(files)
        for record in state.records {
            guard record.byteCount > 0, record.byteCount <= MaterialLibrary.maximumBytes else {
                throw MigrationError.invalidSource
            }
            let original = source.appendingPathComponent("files").appendingPathComponent(record.storedName)
            guard original.resolvingSymlinksInPath().deletingLastPathComponent() == source.appendingPathComponent("files") else {
                throw MigrationError.invalidSource
            }
            let bytes = try readRegularFile(original, maximum: MaterialLibrary.maximumBytes)
            guard bytes.count == record.byteCount else { throw MigrationError.invalidSource }
            let copy = files.appendingPathComponent(record.storedName)
            try bytes.write(to: copy, options: .atomic)
            try protect(copy)
            guard try readRegularFile(copy, maximum: MaterialLibrary.maximumBytes) == bytes else {
                throw MigrationError.verificationFailed
            }
            try checkpoint(.copiedOriginal)
        }
        let url = candidate.appendingPathComponent("library.sqlite")
        do {
            let database = try LocalMaterialDatabase(url: url, create: true)
            defer { try? database.close() }
            try database.importLegacy(state)
            try checkpoint(.imported)
        }
        try protect(url)
        do {
            let database = try LocalMaterialDatabase(url: url)
            defer { try? database.close() }
            let restored = try database.legacySnapshot()
            guard try comparable(restored) == comparable(state) else {
                throw MigrationError.verificationFailed
            }
        }
        try checkpoint(.reopened)
        // Detect source updates during preparation. Compare original bytes as well
        // as JSON: sourceDigest is preserved provenance, not recomputed here.
        guard try readRegularFile(manifest, maximum: 64 * 1024 * 1024) == manifestData else {
            throw MigrationError.sourceChanged
        }
        for record in state.records {
            let original = source.appendingPathComponent("files").appendingPathComponent(record.storedName)
            let copy = files.appendingPathComponent(record.storedName)
            guard try readRegularFile(original, maximum: MaterialLibrary.maximumBytes) ==
                        readRegularFile(copy, maximum: MaterialLibrary.maximumBytes) else {
                throw MigrationError.sourceChanged
            }
        }
        finished = true
        return candidate
    }

    private static func comparable(_ state: MaterialLibraryState) throws -> Data {
        var state = state
        // Old Codable archives distinguish nil and empty dictionaries without a
        // semantic difference. Preserve all entries, not that encoding detail.
        if state.pdfAnalyses?.isEmpty == true { state.pdfAnalyses = nil }
        if state.pdfParseAttempts?.isEmpty == true { state.pdfParseAttempts = nil }
        return try LocalMaterialDatabase.encode(state)
    }

    private static func contains(_ directory: URL, _ other: URL) -> Bool {
        other.pathComponents.starts(with: directory.pathComponents)
    }

    private static func readRegularFile(_ url: URL, maximum: Int) throws -> Data {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true,
              let size = info.fileSize, size > 0, size <= maximum else { throw MigrationError.invalidSource }
        let data = try Data(contentsOf: url)
        guard data.count == size, data.count <= maximum else { throw MigrationError.sourceChanged }
        return data
    }

    private static func protect(_ url: URL) throws {
        #if os(iOS) || os(macOS)
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
}
