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
    private var previous: FileContentVersion?

    mutating func record(_ version: FileContentVersion?) { previous = version }

    mutating func shouldRefresh(_ version: FileContentVersion?) -> Bool {
        // Some volumes do not expose these identifiers. Never infer unchanged
        // content from a timestamp or file size in that case.
        guard let version else { previous = nil; return true }
        guard previous != version else { return false }
        previous = version
        return true
    }
}
