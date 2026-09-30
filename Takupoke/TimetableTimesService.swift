import Foundation

struct TimetableTimesService {
    let baseURL: URL
    let network: URLSession

    func revision(installed: String?) async throws -> MappingRevisionResult {
        try await MappingService(baseURL: baseURL, network: network)
            .checkRevision(installed: installed, path: "timetable-times-revision")
    }

    func download(token: String, revision: String) async throws -> SavedTimetableTimes {
        guard MappingPackage.validRevision(revision), !token.isEmpty else { throw TimetableTimesError.invalidData }
        var request = URLRequest(url: baseURL.appendingPathComponent("timetable-times"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (file, raw) = try await network.download(for: request)
        defer { try? FileManager.default.removeItem(at: file) }
        try Task.checkCancellation()
        guard let response = raw as? HTTPURLResponse else { throw TimetableTimesError.unavailable }
        if response.statusCode == 401 || response.statusCode == 403 { throw TimetableTimesError.authentication }
        guard response.statusCode == 200,
              response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("application/json") == true else {
            throw TimetableTimesError.unavailable
        }
        guard response.value(forHTTPHeaderField: "X-Timetable-Times-Revision") == revision else { throw TimetableTimesError.changed }
        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size <= 128 * 1024 else {
            throw TimetableTimesError.invalidData
        }
        let data: TimetableTimes
        do { data = try JSONDecoder().decode(TimetableTimes.self, from: Data(contentsOf: file)).validated() }
        catch { throw TimetableTimesError.invalidData }
        return SavedTimetableTimes(revision: revision, fetchedAt: Date(), data: data)
    }
}
