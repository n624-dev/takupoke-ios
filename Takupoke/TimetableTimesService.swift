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
        let (body, response) = try await BoundedHTTPResponse.read(request, using: network, maximum: 128 * 1024)
        try Task.checkCancellation()
        if response.statusCode == 401 || response.statusCode == 403 { throw TimetableTimesError.authentication }
        guard response.statusCode == 200,
              response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("application/json") == true else {
            throw TimetableTimesError.unavailable
        }
        guard response.value(forHTTPHeaderField: "X-Timetable-Times-Revision") == revision else { throw TimetableTimesError.changed }
        let data: TimetableTimes
        do { data = try JSONDecoder().decode(TimetableTimes.self, from: body).validated() }
        catch { throw TimetableTimesError.invalidData }
        return SavedTimetableTimes(revision: revision, fetchedAt: Date(), data: data)
    }
}
