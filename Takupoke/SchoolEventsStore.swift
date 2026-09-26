import Foundation

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
        let files = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var saved: [Int: SavedSchoolEvents] = [:]
        for file in files {
            guard file.lastPathComponent.hasPrefix("events-"), file.pathExtension == "json",
                  let year = Int(file.deletingPathExtension().lastPathComponent.dropFirst(7)),
                  (1900...9998).contains(year) else { continue }
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                  let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 1_000_000 else { throw SchoolEventsError.invalidResponse }
            let value = try JSONDecoder().decode(SavedSchoolEvents.self, from: Data(contentsOf: file))
            let verified = try SchoolEventsPayload.decode(JSONEncoder().encode(value.payload), requestedYear: year)
            saved[year] = SavedSchoolEvents(fetchedAt: value.fetchedAt, payload: verified,
                                            apiETag: value.apiETag.flatMap {
                                                SchoolEventsResponse.validETag($0) ? $0 : nil
                                            })
        }
        return saved
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
