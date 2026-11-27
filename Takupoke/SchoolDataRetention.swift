import Foundation

/// Retention uses Japan time and the actual date, never the timetable's selected week.
struct SchoolDataPeriod: Codable, Equatable, Sendable {
    let schoolYear: Int
    let half: Int

    init(day: SchoolDate) {
        schoolYear = day.schoolYear
        half = (4...9).contains(day.month) ? 1 : 2
    }

    var endsAt: Date? {
        if half == 1 { return SchoolDate(year: schoolYear, month: 10, day: 1)?.dateInJapan() }
        return SchoolDate(year: schoolYear + 1, month: 4, day: 1)?.dateInJapan()
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
    private var proof: URL { root.appendingPathComponent("school-data-period-proof.json") }
    private var unverified: URL { root.appendingPathComponent("SchoolDataUnverifiedPeriod", isDirectory: true) }
    private var pendingArchive: URL { unverified.appendingPathComponent("pending", isDirectory: true) }
    static let countdownProgressDirectory = "SchoolCountdownProgress"
    static let privatePaths = ["SchoolFileJobs", "SchoolMaterialsSQLite", "SchoolMaterialsSQLite.initializing",
        "SchoolMaterialsSQLite.lock", "SchoolMaterials", "SpecialSchedulesSQLite", "SpecialSchedules",
        "NameMappings", "LinksAPI", "ScheduleNotifications", "TimetableTimes", countdownProgressDirectory]

    enum Failure: Error, Equatable {
        case invalidMarker, unreadableMarker, cleanup, markerWrite, recovery
        case notificationCleanup(recoveringInvalidMarker: Bool)
        var message: String {
            switch self {
            case .invalidMarker: return "保存期間の管理情報が破損しています。学校データの利用を停止しています。"
            case .unreadableMarker: return "保存期間の管理情報を読み込めませんでした。端末のロック状態と保存先を確認して再試行してください。"
            case .cleanup: return "保存データを削除できませんでした。古いデータの利用を停止しています。"
            case .notificationCleanup: return "期限切れの通知を確認できませんでした。学校データの利用を停止しています。再試行してください。"
            case .markerWrite: return "保存期間の管理情報を保存できませんでした。学校データの利用を停止しています。"
            case .recovery: return "保存期間の管理情報を隔離できませんでした。保存データは利用せず、復旧を中止しました。"
            }
        }
    }
    private var recoveryDirectory: URL { root.appendingPathComponent("SchoolDataRetentionRecovery", isDirectory: true) }

    func installedPeriod(read: (URL) throws -> Data = { try Data(contentsOf: $0) }) throws -> SchoolDataPeriod? {
        try readPeriod(at: marker, read: read)
    }

    private func readPeriod(at url: URL, read: (URL) throws -> Data = { try Data(contentsOf: $0) }) throws -> SchoolDataPeriod? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { throw Failure.unreadableMarker }
        } catch let failure as Failure { throw failure }
        catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { return nil }
            throw Failure.unreadableMarker
        }
        let data: Data
        do { data = try read(url) } catch { throw Failure.unreadableMarker }
        guard let period = try? JSONDecoder().decode(SchoolDataPeriod.self, from: data),
              (1...9998).contains(period.schoolYear), (1...2).contains(period.half) else { throw Failure.invalidMarker }
        return period
    }

    func saveProofForInstalledPeriod(_ period: SchoolDataPeriod) throws {
        guard try installedPeriod() == period, (try? readPeriod(at: proof)) != period else { return }
        do { try JSONEncoder().encode(period).write(to: proof, options: .atomic) }
        catch { throw Failure.markerWrite }
    }

    /// Rebuild a damaged marker using the separately stored period proof.
    /// With no current proof, preserve unverified private files outside the
    /// active stores and start a clean current period.
    func restoreInvalidPeriod(_ period: SchoolDataPeriod, move: (URL, URL) throws -> Void = {
        try FileManager.default.moveItem(at: $0, to: $1)
    }) throws -> Bool {
        let manager = FileManager.default
        let markerExists = manager.fileExists(atPath: marker.path)
        let pending = manager.fileExists(atPath: pendingArchive.path)
        let preserveCurrent = !pending && (try? readPeriod(at: proof)) == period
        let archive = preserveCurrent ? unverified.appendingPathComponent(UUID().uuidString, isDirectory: true) : pendingArchive
        do {
            try manager.createDirectory(at: archive, withIntermediateDirectories: true)
            #if os(iOS)
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: unverified.path)
            var directory = unverified
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            #endif
            if markerExists {
                let bytes = try Data(contentsOf: marker)
                let snapshot = archive.appendingPathComponent("school-data-period.json")
                if manager.fileExists(atPath: snapshot.path) {
                    guard try Data(contentsOf: snapshot) == bytes else { throw Failure.recovery }
                } else {
                    try bytes.write(to: snapshot, options: .withoutOverwriting)
                }
            }
            if !preserveCurrent {
                for name in Self.privatePaths {
                    let source = root.appendingPathComponent(name)
                    guard manager.fileExists(atPath: source.path) else { continue }
                    try move(source, archive.appendingPathComponent(name))
                }
            }
            let bytes = try JSONEncoder().encode(period)
            try bytes.write(to: proof, options: .atomic)
            try bytes.write(to: marker, options: .atomic)
            try finalizeUnverifiedArchive()
            return preserveCurrent
        } catch { throw Failure.recovery }
    }

    func finalizeUnverifiedArchive() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: pendingArchive.path) else { return }
        do { try manager.moveItem(at: pendingArchive, to: unverified.appendingPathComponent(UUID().uuidString, isDirectory: true)) }
        catch { throw Failure.recovery }
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
            let bytes = try JSONEncoder().encode(period)
            try bytes.write(to: proof, options: .atomic)
            try write(bytes, marker)
        } catch { throw Failure.markerWrite }
    }
}
