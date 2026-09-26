import Foundation

/// Retention uses Japan time and the actual date, never the timetable's selected week.
struct SchoolDataPeriod: Codable, Equatable {
    let schoolYear: Int
    let half: Int

    init(day: SchoolDate) {
        schoolYear = day.schoolYear
        half = (4...9).contains(day.month) ? 1 : 2
    }

    static func current(at date: Date = Date()) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return Self(day: SchoolDate(year: parts.year!, month: parts.month!, day: parts.day!)!)
    }
}

/// The marker is committed only after all deletions succeed. Retry partial deletion
/// before opening any private store; public events and preferences live elsewhere.
struct SchoolDataRetention {
    let root: URL
    private var marker: URL { root.appendingPathComponent("school-data-period.json") }
    static let privatePaths = ["SchoolMaterialsSQLite", "SchoolMaterialsSQLite.initializing",
        "SchoolMaterialsSQLite.lock", "SchoolMaterials", "SpecialSchedulesSQLite", "SpecialSchedules",
        "NameMappings", "LinksAPI"]

    func installedPeriod() throws -> SchoolDataPeriod? {
        guard FileManager.default.fileExists(atPath: marker.path) else { return nil }
        return try JSONDecoder().decode(SchoolDataPeriod.self, from: Data(contentsOf: marker))
    }

    func replace(with period: SchoolDataPeriod, remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) throws {
        for path in Self.privatePaths {
            let url = root.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: url.path) { try remove(url) }
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(period).write(to: marker, options: .atomic)
    }
}
