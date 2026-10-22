import Foundation

/// A provider bookmark identifies the original file, never the app's saved copy.
struct SelectedFileSource: Equatable {
    let id: String
    let bookmark: Data?
    let childName: String?

    init(id: String, grant: SourceGrant?, childName: String? = nil) {
        self.id = id
        bookmark = grant?.bookmark
        self.childName = grant?.isFolder == true ? childName : nil
    }
}

/// Main-thread scheduling: notifications during a read wait for that read to end.
struct FileRefreshQueue {
    private(set) var foreground = false
    private(set) var pending: Set<String> = []
    private(set) var suspended = false

    mutating func setForeground(_ value: Bool) {
        if !value || !foreground { suspended = false }
        foreground = value
        if !value { pending.removeAll() }
    }

    mutating func suspend() {
        suspended = true
        pending.removeAll()
    }

    mutating func request(_ id: String) {
        if foreground && !suspended { pending.insert(id) }
    }

    mutating func take(ready: Bool, busy: Bool) -> Set<String> {
        guard foreground, !suspended, ready, !busy else { return [] }
        let result = pending
        pending.removeAll()
        return result
    }
}

/// A data-fork generation changes for content, not provider metadata. Identity
/// is included because a replacement file can have the same generation value.
struct FileContentVersion: Equatable {
    let identity: NSObject
    let generation: NSObject
}

struct FileContentChangeGate {
    private var acknowledged: FileContentVersion?
    private var observed: FileContentVersion?
    private var awaitingRead = false
    private var lastNotification: TimeInterval?
    private var retryAfter: TimeInterval?

    mutating func record(_ version: FileContentVersion?) {
        acknowledged = version
        if version == observed || version == nil {
            observed = nil; awaitingRead = false; retryAfter = nil
        }
    }

    mutating func readFailed(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard awaitingRead else { return }
        awaitingRead = false; retryAfter = now + 1
    }

    mutating func shouldRefresh(_ version: FileContentVersion?, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        // Unsupported metadata still requires a hash read; notifications never
        // acknowledge bytes, even when the provider reports a new generation.
        guard let version else { return true }
        guard acknowledged != version else { return false }
        let previousNotification = lastNotification
        lastNotification = now
        if observed == version {
            if awaitingRead { return false }
            if let retryAfter, now < retryAfter || previousNotification.map({ now - $0 < 1 }) == true { return false }
        }
        observed = version; awaitingRead = true; retryAfter = nil
        return true
    }
}

/// User selections retain their access lease while another operation finishes.
/// The model drains these before starting another automatic refresh.
struct PendingFileSelections<Kind, Selection> {
    private var items: [(kind: Kind, selection: Selection)] = []

    mutating func append(_ selection: Selection, kind: Kind) {
        items.append((kind, selection))
    }

    mutating func take(busy: Bool) -> (kind: Kind, selection: Selection)? {
        guard !busy, !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    mutating func clear() { items.removeAll() }
}
