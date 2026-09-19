import Foundation

private enum CheckError: Error { case failed(String), injectedWriteFailure }

private func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw CheckError.failed(message) }
}

private func expectFailure(_ message: String, _ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw CheckError.failed(message)
}

@main
struct MaterialLibraryChecks {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let source = MaterialSource(grant: SourceGrant(bookmark: Data("synthetic".utf8),
                                   name: "fictional.pdf", isFolder: false), childName: nil)
        var rejectWrites = false
        let library = try MaterialLibrary(root: root) { data, url in
            if rejectWrites { throw CheckError.injectedWriteFailure }
            try data.write(to: url, options: .atomic)
        }
        let manifest = root.appendingPathComponent("library.json")
        let copies = root.appendingPathComponent("files")
        let staging = root.appendingPathComponent("staging")

        func commit(_ text: String, kind: MaterialKind = .timetable) throws {
            let staged = library.newStagingURL()
            defer { library.discardStaging(staged) }
            let bytes = Data(text.utf8)
            try bytes.write(to: staged)
            try library.commit(staged: staged, kind: kind, source: source,
                               originalName: "fictional." + kind.fileExtension,
                               byteCount: bytes.count, digest: text, modifiedAt: nil)
        }

        try expect(manager.fileExists(atPath: manifest.path), "Empty commit point missing")
        // A first acquisition interrupted after its move is a recoverable orphan.
        let initialOrphan = copies.appendingPathComponent(UUID().uuidString + ".pdf")
        try Data("interrupted first copy".utf8).write(to: initialOrphan)
        _ = try MaterialLibrary(root: root)
        try expect(!manager.fileExists(atPath: initialOrphan.path), "First-copy orphan not cleaned")

        try commit("original synthetic PDF")
        let original = library.localURL(for: .timetable)!
        let originalBytes = try Data(contentsOf: original)
        let originalManifest = try Data(contentsOf: manifest)
        let reloaded = try MaterialLibrary(root: root)
        try expect(reloaded.state.record(for: .timetable)?.digest == "original synthetic PDF", "Reload lost record")
        try expect(try Data(contentsOf: reloaded.localURL(for: .timetable)!) == originalBytes, "Reload lost copy")

        rejectWrites = true
        try expectFailure("Manifest failure was not propagated") { try commit("replacement") }
        rejectWrites = false
        try expect(library.localURL(for: .timetable) == original, "Failed update changed binding")
        try expect(try Data(contentsOf: original) == originalBytes, "Failed update changed original")
        try expect(try Data(contentsOf: manifest) == originalManifest, "Failed update changed manifest")
        try expect(try manager.contentsOfDirectory(atPath: copies.path).count == 1, "Failed update leaked copy")
        try expect(try manager.contentsOfDirectory(atPath: staging.path).isEmpty, "Failed update leaked staging")

        try library.recordFailure(.timetable, message: "Synthetic offline failure")
        let failed = try MaterialLibrary(root: root)
        try expect(failed.state.attempts["timetable"]?.failure != nil, "Failure status not persisted")
        try expect(failed.localURL(for: .timetable) == original, "Failure replaced original")

        try commit("replacement")
        try expect(!manager.fileExists(atPath: original.path), "Successful update retained obsolete copy")
        try expect(library.state.attempts["timetable"]?.failure == nil, "Success retained failure status")
        try commit("synthetic events", kind: .events)
        try expect(library.state.records.count == 2, "Updating one kind lost another kind")

        let scratch = library.newStagingURL()
        try Data("interrupted transfer".utf8).write(to: scratch)
        let orphan = copies.appendingPathComponent(UUID().uuidString + ".xlsx")
        try Data("interrupted commit".utf8).write(to: orphan)
        let restored = try MaterialLibrary(root: root)
        try expect(restored.state.records.count == 2, "Recovery lost committed records")
        try expect(try manager.contentsOfDirectory(atPath: copies.path).count == 2, "Recovery leaked orphan")
        try expect(try manager.contentsOfDirectory(atPath: staging.path).isEmpty, "Recovery leaked staging")

        // Corruption must stop opening without changing copies or metadata.
        let validManifest = try Data(contentsOf: manifest)
        try Data("invalid JSON".utf8).write(to: manifest)
        try expectFailure("Corrupt manifest accepted") { _ = try MaterialLibrary(root: root) }
        try expect(try manager.contentsOfDirectory(atPath: copies.path).count == 2, "Corruption destroyed copies")
        try expect(try Data(contentsOf: manifest) == Data("invalid JSON".utf8), "Corrupt manifest overwritten")
        try validManifest.write(to: manifest)

        // Never follow a filename outside the owned copy directory.
        var bad = restored.state
        bad.records[0].storedName = "../outside.pdf"
        try JSONEncoder().encode(bad).write(to: manifest)
        try expectFailure("Unsafe filename accepted") { _ = try MaterialLibrary(root: root) }
        try expect(try manager.contentsOfDirectory(atPath: copies.path).count == 2, "Invalid state triggered cleanup")
        try validManifest.write(to: manifest)

        let missing = restored.localURL(for: .events)!
        try manager.removeItem(at: missing)
        try expectFailure("Missing copy reported as acquired") { _ = try MaterialLibrary(root: root) }
        try expect(try Data(contentsOf: manifest) == validManifest, "Missing copy reset manifest")

        try manager.removeItem(at: manifest)
        try expectFailure("Copies without manifest were discarded") { _ = try MaterialLibrary(root: root) }
        try expect(try manager.contentsOfDirectory(atPath: copies.path).count == 1, "Missing manifest destroyed data")
        print("Material persistence checks passed: commit, rollback, reload, failure status, isolation, recovery and corruption.")
    }
}
