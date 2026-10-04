import Foundation

struct SchoolEventsAvailableLoad {
    let saved: [Int: SavedSchoolEvents]
    let failedYears: Set<Int>

    var warning: String? { Self.warning(for: failedYears) }

    static func warning(for years: Set<Int>) -> String? {
        guard !years.isEmpty else { return nil }
        return "\(years.sorted().map(String.init).joined(separator: "、"))年度の保存済み学校行事を読み取れません。正常な年度の結果は表示しています。該当年度を再取得してください。端末内の結果は削除していません。"
    }
}

final class SchoolEventsStore {
    private let root: URL

    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var directory = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        #endif
    }

    func loadAll() throws -> [Int: SavedSchoolEvents] {
        let available = try loadAvailable()
        guard available.failedYears.isEmpty else { throw SchoolEventsError.invalidResponse }
        return available.saved
    }

    /// Only confirmed content/type failures are isolated by year. Directory,
    /// permission/protection and cancellation errors still prevent readiness.
    func loadAvailable() throws -> SchoolEventsAvailableLoad {
        try Task.checkCancellation()
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw CocoaError(.fileReadUnknown)
        }
        let files = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles])
        var saved: [Int: SavedSchoolEvents] = [:]
        var failedYears = Set<Int>()
        for file in files {
            try Task.checkCancellation()
            guard file.lastPathComponent.hasPrefix("events-"), file.pathExtension == "json",
                  let year = Int(file.deletingPathExtension().lastPathComponent.dropFirst(7)),
                  (1900...9998).contains(year) else { continue }
            let info = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard info.isRegularFile == true, info.isSymbolicLink != true,
                  let size = info.fileSize, (0...1_000_000).contains(size) else {
                failedYears.insert(year)
                continue
            }
            // I/O failure may be transient device protection; do not mislabel
            // it as corrupt JSON or expose a writable ready state.
            let data = try Data(contentsOf: file)
            try Task.checkCancellation()
            do {
                guard data.count <= 1_000_000 else { throw SchoolEventsError.invalidResponse }
                let value = try JSONDecoder().decode(SavedSchoolEvents.self, from: data)
                let verified = try SchoolEventsPayload.decode(JSONEncoder().encode(value.payload), requestedYear: year)
                try Task.checkCancellation()
                saved[year] = SavedSchoolEvents(fetchedAt: value.fetchedAt, payload: verified,
                                               apiETag: value.apiETag.flatMap {
                                                   SchoolEventsResponse.validETag($0) ? $0 : nil
                                               })
            } catch is DecodingError {
                failedYears.insert(year)
            } catch SchoolEventsError.invalidResponse {
                failedYears.insert(year)
            }
        }
        try Task.checkCancellation()
        return SchoolEventsAvailableLoad(saved: saved, failedYears: failedYears)
    }

    func save(_ payload: SchoolEventsPayload, apiETag: String? = nil, fetchedAt: Date = Date()) throws {
        let checked = try SchoolEventsPayload.decode(JSONEncoder().encode(payload), requestedYear: payload.schoolYear)
        guard apiETag == nil || SchoolEventsResponse.validETag(apiETag!) else {
            throw SchoolEventsError.invalidResponse
        }
        let url = root.appendingPathComponent("events-\(checked.schoolYear).json")
        try JSONEncoder().encode(SavedSchoolEvents(fetchedAt: fetchedAt, payload: checked, apiETag: apiETag))
            .write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
}
