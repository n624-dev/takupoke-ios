import Foundation

enum MonitoredService: String, CaseIterable, Identifiable, Sendable {
    case api = "9028864", authentication = "9028865"
    var id: String { rawValue }
    var title: String { self == .api ? "たくポケAPI" : "たくにん" }
    var functionalID: String { self == .api ? "takupoke-api" : "takunin" }
    var featureIDs: [String] { self == .api ? ["events", "links", "mappings", "timetable-times"] : ["database", "oidc"] }
}

struct ServiceStatusSnapshot: Equatable, Sendable {
    enum State: String, Sendable {
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
    struct Day: Identifiable, Equatable, Sendable {
        let date: SchoolDate
        let state: State
        let downtime: TimeInterval?
        let maintenance: TimeInterval?
        var id: String { date.iso8601 }
    }
    struct Update: Identifiable, Equatable, Sendable {
        let id: String
        let message: String
        let publishedAt: Date
        let state: String
    }
    struct Incident: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let state: String
        let startsAt: Date?
        let updates: [Update]
        var resolved: Bool { state == "resolved" }
    }
    struct Resource: Equatable, Sendable {
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
        try Task.checkCancellation()
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.data.type == "status_page", document.data.id == "267223",
              let links = document.data.relationships?.resources?.data else { throw Failure.invalidResponse }
        let nodeIndex = Dictionary(grouping: document.included) { Reference(id: $0.id, type: $0.type) }
        let dateParser = DateParser()
        func uniqueNode(_ reference: Reference) -> Node? {
            guard let nodes = nodeIndex[reference], nodes.count == 1 else { return nil }
            return nodes[0]
        }
        var resources: [MonitoredService: Resource] = [:]
        for service in MonitoredService.allCases {
            try Task.checkCancellation()
            let reference = Reference(id: service.id, type: "status_page_resource")
            guard links.filter({ $0 == reference }).count == 1,
                  let resource = uniqueNode(reference), let value = resource.attributes,
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
                try Task.checkCancellation()
                guard let node = uniqueNode(report), let attributes = node.attributes else { continue }
                let affected = (attributes.affectedResources ?? []).filter { $0.statusPageResourceID == service.id }
                guard !affected.isEmpty else { continue }
                var updates: [Update] = []
                for updateRef in Set(node.relationships?.statusUpdates?.data ?? []) where updateRef.type == "status_update" {
                    try Task.checkCancellation()
                    guard let updateNode = uniqueNode(updateRef), let update = updateNode.attributes,
                          let date = dateParser.parse(update.publishedAt), let message = update.message else { continue }
                    let changed = (update.affectedResources ?? []).filter { $0.statusPageResourceID == service.id }
                    guard !changed.isEmpty else { continue }
                    updates.append(.init(id: updateRef.id, message: String(message.prefix(2_000)), publishedAt: date,
                                         state: changed.count == 1 ? changed[0].status : "unknown"))
                }
                updates.sort { $0.publishedAt == $1.publishedAt ? $0.id < $1.id : $0.publishedAt > $1.publishedAt }
                incidents.append(.init(id: report.id, title: String((attributes.title ?? "障害情報").prefix(300)),
                                       state: affected.count == 1 ? affected[0].status : "unknown",
                                       startsAt: dateParser.parse(attributes.startsAt), updates: updates))
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
    static func date(_ value: String?) -> Date? {
        guard let value, value.utf8.count <= 40 else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private struct DateParser {
        private let fractional = ISO8601DateFormatter()
        private let integral = ISO8601DateFormatter()

        init() {
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            integral.formatOptions = [.withInternetDateTime]
        }

        func parse(_ value: String?) -> Date? {
            guard let value, value.utf8.count <= 40 else { return nil }
            return fractional.date(from: value) ?? integral.date(from: value)
        }
    }

    private struct Document: Decodable {
        let data: Node
        let included: [Node]
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

struct FunctionalStatusSnapshot: Decodable, Equatable {
    struct Feature: Decodable, Equatable {
        let id: String
        let state: String
        let checkedAt: Date
        let validUntil: Date
        let lastSuccessfulAt: Date?

        static func title(for id: String) -> String {
            switch id {
            case "events": return "行事配信"
            case "links": return "リンク集"
            case "mappings": return "名称データ"
            case "timetable-times": return "授業時刻"
            case "database": return "認証データベース"
            case "oidc": return "認証設定と署名"
            default: return id
            }
        }

        func presentation(at now: Date) -> StatusPresentation {
            guard checkedAt <= now, now < validUntil else { return FunctionalStatusSnapshot.unknown }
            switch state {
            case "ok": return .init(title: "利用可能", tone: .good)
            case "unavailable": return .init(title: "利用できません", tone: .unavailable)
            default: return FunctionalStatusSnapshot.unknown
            }
        }
    }

    struct EventVersion: Decodable, Equatable {
        let schoolYear: Int
        let format: String
        let dataVersion: String
        let sourceState: String
        let sourceCheckedAt: Date?
        let reviewState: String
        let reviewCheckedAt: Date?
    }

    struct EventEvidence: Decodable, Equatable {
        let checkedAt: Date
        let validUntil: Date
        let versions: [EventVersion]
    }

    struct Evidence: Decodable, Equatable { let events: EventEvidence? }
    let schemaVersion: Int
    let service: String
    let checkedAt: Date
    let validUntil: Date
    let features: [Feature]
    let data: Evidence?
    static let maximumBytes = 64 * 1024
    static let unknown = StatusPresentation(title: "未確認", tone: .unknown)

    static func decode(_ bytes: Data, service: MonitoredService) throws -> Self {
        guard bytes.count <= maximumBytes else { throw ServiceStatusSnapshot.Failure.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = ServiceStatusSnapshot.date(value) else { throw ServiceStatusSnapshot.Failure.invalidResponse }
            return date
        }
        let result = try decoder.decode(Self.self, from: bytes)
        guard result.schemaVersion == 1, result.service == service.functionalID,
              result.checkedAt < result.validUntil, result.features.count <= 32 else {
            throw ServiceStatusSnapshot.Failure.invalidResponse
        }
        return result
    }

    func feature(_ id: String) -> Feature? {
        let matches = features.filter { $0.id == id }
        return matches.count == 1 ? matches.first : nil
    }

    func featurePresentation(_ id: String, at now: Date) -> StatusPresentation {
        guard checkedAt <= now, now < validUntil else { return Self.unknown }
        return feature(id)?.presentation(at: now) ?? Self.unknown
    }

    func eventVersion(year: Int, format: String, at now: Date) -> EventVersion? {
        guard let events = data?.events, events.checkedAt <= now, now < events.validUntil else { return nil }
        let matches = events.versions.filter { $0.schoolYear == year && $0.format == format }
        guard matches.count == 1, let version = matches.first, version.dataVersion.hasPrefix("sha256-"),
              version.dataVersion.utf8.count == 71,
              version.dataVersion.utf8.dropFirst(7).allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        return version
    }
}

struct EventPublisherStatus {
    private struct Edition: Hashable { let year: Int; let format: String }
    private struct Resolution { let comparedAt: Date; let waiting: Bool }
    private var resolutions: [Edition: Resolution] = [:]

    mutating func accept(_ snapshot: FunctionalStatusSnapshot, at now: Date) {
        let editions = Set((snapshot.data?.events?.versions ?? []).map { Edition(year: $0.schoolYear, format: $0.format) })
        for edition in editions {
            guard let version = snapshot.eventVersion(year: edition.year, format: edition.format, at: now),
                  let compared = version.sourceCheckedAt, compared <= now,
                  compared >= (resolutions[edition]?.comparedAt ?? .distantPast) else { continue }
            if version.sourceState == "source_differs" { resolutions[edition] = .init(comparedAt: compared, waiting: true) }
            if version.sourceState == "matched", version.reviewState == "reviewed",
               let reviewed = version.reviewCheckedAt, reviewed <= now {
                resolutions[edition] = .init(comparedAt: compared, waiting: false)
            }
        }
    }

    func isWaiting(year: Int, format: String, earlierDifference: Date? = nil) -> Bool {
        let resolution = resolutions[.init(year: year, format: format)]
        if let earlierDifference, resolution.map({ $0.comparedAt < earlierDifference }) ?? true { return true }
        return resolution?.waiting == true
    }

    func presentation(year: Int, format: String, online: FunctionalStatusSnapshot.EventVersion?,
                      previous: SchoolEventsSourcePresentation?, at now: Date) -> SchoolEventsSourcePresentation? {
        let difference = previous?.updateWaiting == true ? previous?.lastSuccessAt : nil
        if isWaiting(year: year, format: format, earlierDifference: difference) {
            if let previous, previous.updateWaiting { return previous }
            let message = "学校の元PDFと採用原本に差異があり、配信元の更新待ちです。"
            return .init(message: message, warningMessage: message, lastSuccessfulMessage: nil,
                         lastSuccessAt: online?.sourceCheckedAt, receivedAt: nil, evidence: .differs,
                         updateWaiting: true, officialSourceURL: SchoolEventsSourceStatus.officialSourceURL(for: year))
        }
        let applicable = previous?.updateWaiting == true ? nil : previous
        if let online, online.sourceState == "matched", let checked = online.sourceCheckedAt, checked <= now,
           checked >= (applicable?.lastSuccessAt ?? .distantPast) {
            return .init(message: "元PDFの本文は登録元と一致しています。", warningMessage: nil,
                         lastSuccessfulMessage: nil, lastSuccessAt: checked, receivedAt: nil, evidence: .matched)
        }
        return applicable
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
