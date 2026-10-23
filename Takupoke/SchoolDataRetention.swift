import Foundation

/// Retention uses Japan time and the actual date, never the timetable's selected week.
struct SchoolDataPeriod: Codable, Equatable, Sendable {
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
        "NameMappings", "LinksAPI", "ScheduleNotifications", "TimetableTimes"]

    enum Failure: Error, Equatable {
        case invalidMarker, unreadableMarker, cleanup, markerWrite, recovery
        var message: String {
            switch self {
            case .invalidMarker: return "保存期間の管理情報が破損しています。学校データの利用を停止しています。"
            case .unreadableMarker: return "保存期間の管理情報を読み込めませんでした。端末のロック状態と保存先を確認して再試行してください。"
            case .cleanup: return "保存データを削除できませんでした。古いデータの利用を停止しています。"
            case .markerWrite: return "保存期間の管理情報を保存できませんでした。学校データの利用を停止しています。"
            case .recovery: return "保存期間の管理情報を隔離できませんでした。保存データは利用せず、復旧を中止しました。"
            }
        }
    }
    private var recoveryDirectory: URL { root.appendingPathComponent("SchoolDataRetentionRecovery", isDirectory: true) }

    func installedPeriod(read: (URL) throws -> Data = { try Data(contentsOf: $0) }) throws -> SchoolDataPeriod? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: marker.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { throw Failure.unreadableMarker }
        } catch let failure as Failure { throw failure }
        catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { return nil }
            throw Failure.unreadableMarker
        }
        let data: Data
        do { data = try read(marker) } catch { throw Failure.unreadableMarker }
        guard let period = try? JSONDecoder().decode(SchoolDataPeriod.self, from: data),
              (1...9998).contains(period.schoolYear), (1...2).contains(period.half) else { throw Failure.invalidMarker }
        return period
    }

    /// Only an explicit recovery operation may move a readable, malformed marker.
    /// No private directory is touched before this durable quarantine succeeds.
    func quarantineInvalidMarker(move: (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }) throws {
        do { _ = try installedPeriod(); throw Failure.recovery }
        catch Failure.invalidMarker { }
        catch { throw error }
        do {
            try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: recoveryDirectory.path)
            var directory = recoveryDirectory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            #endif
            try move(marker, recoveryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        } catch { throw Failure.recovery }
    }

    func finishRecovery(remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) throws {
        guard FileManager.default.fileExists(atPath: recoveryDirectory.path) else { return }
        // A current marker proves private-data cleanup and marker commit finished.
        guard try installedPeriod() != nil else { throw Failure.cleanup }
        do { try remove(recoveryDirectory) } catch { throw Failure.cleanup }
    }

    func replace(with period: SchoolDataPeriod, remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) },
                 write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
        do {
            for path in Self.privatePaths {
                let url = root.appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: url.path) { try remove(url) }
            }
        } catch { throw Failure.cleanup }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try write(JSONEncoder().encode(period), marker)
        } catch { throw Failure.markerWrite }
    }
}
