import CryptoKit
import Foundation

/// Cancellation can be requested from the UI while the serial worker is
/// waiting for the File Provider. No UI work is performed under file coordination.
final class AcquisitionControl {
    private let lock = NSLock()
    private var cancelled = false
    private var coordinator: NSFileCoordinator?

    func cancel() {
        lock.lock()
        cancelled = true
        let active = coordinator
        lock.unlock()
        active?.cancel()
    }

    func check() throws {
        lock.lock()
        let value = cancelled
        lock.unlock()
        if value { throw MaterialError.cancelled }
    }

    func attach(_ value: NSFileCoordinator?) {
        lock.lock()
        coordinator = value
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { value?.cancel() }
    }
}

struct MaterialCandidate: Identifiable {
    var name: String
    var id: String { name }
    var fileExtension: String { (name as NSString).pathExtension.lowercased() }
}

final class MaterialWorker {
    private(set) var library: MaterialLibrary?
    private(set) var candidates: [MaterialCandidate] = []
    private(set) var folderListed = false

    func open() throws {
        if library != nil { return }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        library = try MaterialLibrary(root: base.appendingPathComponent("SchoolMaterials", isDirectory: true))
    }

    private func grant(for url: URL, folder: Bool) throws -> SourceGrant {
        guard url.startAccessingSecurityScopedResource() else { throw MaterialError.unavailable }
        defer { url.stopAccessingSecurityScopedResource() }
        return SourceGrant(bookmark: try url.bookmarkData(options: .minimalBookmark,
                                                         includingResourceValuesForKeys: nil, relativeTo: nil),
                           name: url.lastPathComponent, isFolder: folder)
    }

    private func withAccess<T>(_ grant: SourceGrant, body: (URL) throws -> T) throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: grant.bookmark, options: [], relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        // Do not guess a replacement path or silently switch files.
        guard !stale, url.startAccessingSecurityScopedResource() else { throw MaterialError.unavailable }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }

    private func coordinated<T>(_ url: URL, control: AcquisitionControl,
                                read: (URL) throws -> T) throws -> T {
        try control.check()
        let coordinator = NSFileCoordinator(filePresenter: nil)
        control.attach(coordinator)
        defer { control.attach(nil) }
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { safeURL in
            result = Result { try control.check(); return try read(safeURL) }
        }
        try control.check()
        if let error = coordinationError { throw error }
        guard let result = result else { throw MaterialError.unavailable }
        return try result.get()
    }

    func selectFolder(_ url: URL, control: AcquisitionControl) throws {
        guard let library = library else { throw MaterialError.invalidState }
        let selected = try grant(for: url, folder: true)
        let files = try list(selected, control: control)
        try control.check()
        try library.saveFolder(selected)
        candidates = files
        folderListed = true
    }

    func refreshFolder(control: AcquisitionControl) throws {
        guard let folder = library?.state.folder else { return }
        // A failed listing must not leave an old list looking up to date.
        candidates = []
        folderListed = false
        candidates = try list(folder, control: control)
        folderListed = true
    }

    private func list(_ grant: SourceGrant, control: AcquisitionControl) throws -> [MaterialCandidate] {
        try withAccess(grant) { url in
            try coordinated(url, control: control) { folder in
                guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                    throw MaterialError.unavailable
                }
                let urls = try FileManager.default.contentsOfDirectory(at: folder,
                    includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
                guard urls.count <= 1000 else { throw MaterialError.folderTooLarge }
                var matches: [MaterialCandidate] = []
                for file in urls {
                    try control.check()
                    guard ["pdf", "xlsx"].contains(file.pathExtension.lowercased()),
                          !file.lastPathComponent.hasPrefix("~$") else { continue }
                    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isRegularFile == true && values.isSymbolicLink != true {
                        matches.append(MaterialCandidate(name: file.lastPathComponent))
                    }
                }
                return matches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
    }

    func selectFile(_ url: URL, kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control) {
            MaterialSource(grant: try grant(for: url, folder: false), childName: nil)
        }
    }

    func selectCandidate(_ name: String, kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control) {
            guard let folder = library?.state.folder, candidates.contains(where: { $0.name == name }) else {
                throw MaterialError.unavailable
            }
            return MaterialSource(grant: folder, childName: name)
        }
    }

    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control) {
            guard let source = library?.state.record(for: kind)?.source else { throw MaterialError.unavailable }
            return source
        }
    }

    private func acquire(_ kind: MaterialKind, control: AcquisitionControl,
                         source makeSource: () throws -> MaterialSource) throws {
        guard let library = library else { throw MaterialError.invalidState }
        let staged = library.newStagingURL()
        defer { library.discardStaging(staged) }
        do {
            let source = try makeSource()
            try withAccess(source.grant) { root in
                let target: URL
                if source.grant.isFolder {
                    guard let name = source.childName, !name.isEmpty, name != ".", name != "..",
                          !name.contains("/"), !name.contains("\\") else { throw MaterialError.invalidFile }
                    target = root.appendingPathComponent(name)
                } else {
                    target = root
                }
                guard target.pathExtension.lowercased() == kind.fileExtension else { throw MaterialError.invalidFile }
                let result = try coordinated(target, control: control) { file -> (Int, String, Date?) in
                    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                    let input = try FileHandle(forReadingFrom: file)
                    defer { try? input.close() }
                    guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
                    let output = try FileHandle(forWritingTo: staged)
                    defer { try? output.close() }
                    var hasher = SHA256()
                    var count = 0
                    var header = Data()
                    while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        try control.check()
                        count += chunk.count
                        guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
                        if header.count < 8 { header.append(chunk.prefix(8 - header.count)) }
                        hasher.update(data: chunk)
                        try output.write(contentsOf: chunk)
                    }
                    guard count > 0 else { throw MaterialError.invalidFile }
                    if kind == .changes {
                        guard header.starts(with: [0x50, 0x4b, 0x03, 0x04]) else { throw MaterialError.invalidFile }
                    } else {
                        guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
                    }
                    // Basic container detection only; semantic parsing belongs to steps 3 and 4.
                    try output.synchronize()
                    return (count, hasher.finalize().map { String(format: "%02x", $0) }.joined(), values.contentModificationDate)
                }
                try control.check()
                try library.commit(staged: staged, kind: kind, source: source,
                                   originalName: target.lastPathComponent, byteCount: result.0,
                                   digest: result.1, modifiedAt: result.2)
            }
        } catch {
            let safeError = (error as? MaterialError) ?? .unavailable
            // This updates attempt information only, never the previous copy or binding.
            try library.recordFailure(kind, message: safeError.localizedDescription)
            throw safeError
        }
    }
}
