import Foundation

enum MonitoredService: String, CaseIterable, Identifiable {
    case api = "9028864", authentication = "9028865"
    var id: String { rawValue }
    var title: String { self == .api ? "たくポケAPI" : "たくにん" }
}

struct ServiceStatusSnapshot: Equatable {
    enum State: String {
        case operational, degraded, downtime, maintenance, not_monitored, recovered, recovered_degraded, unknown

        var presentation: StatusPresentation {
            switch self {
            case .operational: return .init(title: "正常稼働", tone: .good)
            case .degraded: return .init(title: "一部機能に影響", tone: .attention)
            case .downtime: return .init(title: "停止中", tone: .unavailable)
            case .maintenance: return .init(title: "メンテナンス中", tone: .attention)
            case .not_monitored: return .init(title: "監視対象外", tone: .neutral)
            case .recovered: return .init(title: "障害から復旧", tone: .attention)
            case .recovered_degraded: return .init(title: "一部機能の障害から復旧", tone: .attention)
            case .unknown: return .init(title: "未確認", tone: .unknown)
            }
        }
    }
    struct Day: Identifiable, Equatable {
        let date: SchoolDate
        let state: State
        let downtime: TimeInterval?
        let maintenance: TimeInterval?
        var id: String { date.iso8601 }
    }
    struct Update: Identifiable, Equatable {
        let id: String
        let message: String
        let publishedAt: Date
        let state: String
    }
    struct Incident: Identifiable, Equatable {
        let id: String
        let title: String
        let state: String
        let startsAt: Date?
        let updates: [Update]
        var resolved: Bool { state == "resolved" }
    }
    struct Resource: Equatable {
        let state: State
        let availability: Double?
        let history: [Day]
        let incidents: [Incident]
    }

    let resources: [MonitoredService: Resource]
    static let maximumBytes = 2 * 1024 * 1024
    enum Failure: Error { case invalidResponse }

    /// Public JSON only. Page metadata is never a monitor probe timestamp, and
    /// the page-wide aggregate includes unrelated services.
    /// Contract: betterstack.com/docs/uptime/status-pages/subscribing-to-status-updates/subscribing-to-api/
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw Failure.invalidResponse }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.data.type == "status_page", document.data.id == "267223",
              let links = document.data.relationships?.resources?.data else { throw Failure.invalidResponse }
        var resources: [MonitoredService: Resource] = [:]
        for service in MonitoredService.allCases {
            let reference = Reference(id: service.id, type: "status_page_resource")
            guard links.filter({ $0 == reference }).count == 1,
                  let resource = document.uniqueNode(reference), let value = resource.attributes,
                  value.resourceType == "Monitor" else { continue }
            let state = value.status.flatMap(State.init(rawValue:)) ?? .unknown
            // recovered is a history-only value, not a valid current status.
            let current = state == .recovered || state == .recovered_degraded ? State.unknown : state
            let availability = value.availability.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
            var days: [SchoolDate: Day] = [:]
            var duplicates = Set<SchoolDate>()
            for entry in value.statusHistory ?? [] {
                guard let date = SchoolDate(iso8601: entry.day) else { continue }
                if days[date] != nil { duplicates.insert(date); continue }
                days[date] = Day(date: date, state: State(rawValue: entry.status) ?? .unknown,
                                 downtime: duration(entry.downtimeDuration), maintenance: duration(entry.maintenanceDuration))
            }
            for date in duplicates { days[date] = Day(date: date, state: .unknown, downtime: nil, maintenance: nil) }
            let history = days.values.sorted { $0.date < $1.date }
            let reports = document.data.relationships?.statusReports?.data ?? []
            var incidents: [Incident] = []
            for report in Set(reports) where report.type == "status_report" {
                guard let node = document.uniqueNode(report), let attributes = node.attributes else { continue }
                let affected = (attributes.affectedResources ?? []).filter { $0.statusPageResourceID == service.id }
                guard !affected.isEmpty else { continue }
                var updates: [Update] = []
                for updateRef in Set(node.relationships?.statusUpdates?.data ?? []) where updateRef.type == "status_update" {
                    guard let updateNode = document.uniqueNode(updateRef), let update = updateNode.attributes,
                          let date = date(update.publishedAt), let message = update.message else { continue }
                    let changed = (update.affectedResources ?? []).filter { $0.statusPageResourceID == service.id }
                    guard !changed.isEmpty else { continue }
                    updates.append(.init(id: updateRef.id, message: String(message.prefix(2_000)), publishedAt: date,
                                         state: changed.count == 1 ? changed[0].status : "unknown"))
                }
                updates.sort { $0.publishedAt == $1.publishedAt ? $0.id < $1.id : $0.publishedAt > $1.publishedAt }
                incidents.append(.init(id: report.id, title: String((attributes.title ?? "障害情報").prefix(300)),
                                       state: affected.count == 1 ? affected[0].status : "unknown", startsAt: date(attributes.startsAt), updates: updates))
            }
            incidents.sort {
                let left = $0.startsAt ?? .distantPast, right = $1.startsAt ?? .distantPast
                return left == right ? $0.id < $1.id : left > right
            }
            resources[service] = Resource(state: current, availability: availability, history: history, incidents: incidents)
        }
        return .init(resources: resources)
    }

    private static func duration(_ value: Double?) -> TimeInterval? {
        value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
    private static func date(_ value: String?) -> Date? {
        guard let value, value.utf8.count <= 40 else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private struct Document: Decodable {
        let data: Node
        let included: [Node]
        func uniqueNode(_ reference: Reference) -> Node? {
            let matches = included.filter { $0.id == reference.id && $0.type == reference.type }
            return matches.count == 1 ? matches.first : nil
        }
    }
    private struct Reference: Decodable, Hashable { let id: String; let type: String }
    private struct Relationship: Decodable { let data: [Reference] }
    private struct Relationships: Decodable {
        let resources: Relationship?
        let statusReports: Relationship?
        let statusUpdates: Relationship?
        enum CodingKeys: String, CodingKey {
            case resources, statusReports = "status_reports", statusUpdates = "status_updates"
        }
    }
    private struct Node: Decodable {
        let id: String
        let type: String
        let attributes: Attributes?
        let relationships: Relationships?
    }
    private struct Attributes: Decodable {
        let resourceType: String?
        let status: String?
        let availability: Double?
        let statusHistory: [History]?
        let title: String?
        let startsAt: String?
        let affectedResources: [Affected]?
        let message: String?
        let publishedAt: String?
        enum CodingKeys: String, CodingKey {
            case resourceType = "resource_type", status, availability, statusHistory = "status_history"
            case title, startsAt = "starts_at", affectedResources = "affected_resources", message, publishedAt = "published_at"
        }
    }
    private struct History: Decodable {
        let day: String
        let status: String
        let downtimeDuration: Double?
        let maintenanceDuration: Double?
        enum CodingKeys: String, CodingKey {
            case day, status, downtimeDuration = "downtime_duration", maintenanceDuration = "maintenance_duration"
        }
    }
    private struct Affected: Decodable {
        let statusPageResourceID: String
        let status: String
        enum CodingKeys: String, CodingKey { case statusPageResourceID = "status_page_resource_id", status }
    }
}

/// Successful receipt/revalidation times are not Better Stack's probe times.
struct ServiceStatusCache {
    struct RetainedResource {
        let value: ServiceStatusSnapshot.Resource
        let checkedAt: Date
    }
    private(set) var retained: [MonitoredService: RetainedResource] = [:]
    private(set) var snapshot: ServiceStatusSnapshot?
    private(set) var checkedAt: Date?
    private(set) var etag: String?
    private(set) var failed = false

    mutating func accept(_ snapshot: ServiceStatusSnapshot, etag: String?, at date: Date) {
        self.snapshot = snapshot; self.etag = etag; checkedAt = date; failed = false
        for (service, resource) in snapshot.resources {
            retained[service] = .init(value: resource, checkedAt: date)
        }
    }
    mutating func revalidate(responseETag: String? = nil, at date: Date) throws {
        guard snapshot != nil, etag?.isEmpty == false else { throw ServiceStatusSnapshot.Failure.invalidResponse }
        if let responseETag {
            let stripWeak: (String) -> String = { $0.hasPrefix("W/") ? String($0.dropFirst(2)) : $0 }
            guard stripWeak(responseETag) == stripWeak(etag!) else { throw ServiceStatusSnapshot.Failure.invalidResponse }
        }
        checkedAt = date; failed = false
        // A 304 validates only the resources present in that response's body.
        for (service, resource) in snapshot!.resources {
            retained[service] = .init(value: resource, checkedAt: date)
        }
    }
    mutating func recordFailure() { failed = true }

    func hasCurrentResource(_ service: MonitoredService, at now: Date) -> Bool {
        guard !failed, let checkedAt, now >= checkedAt else { return false }
        return now.timeIntervalSince(checkedAt) < 180 && snapshot?.resources[service] != nil
    }

    func presentation(for service: MonitoredService, at now: Date) -> StatusPresentation {
        guard hasCurrentResource(service, at: now), let resource = snapshot?.resources[service] else {
            return .init(title: "現在の状況は未確認", tone: .unknown,
                         detail: retained[service] == nil ? nil : "前回取得した情報を詳細で確認できます。")
        }
        return resource.state.presentation
    }
}
