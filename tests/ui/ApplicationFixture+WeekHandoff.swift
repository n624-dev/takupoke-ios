import CoreFoundation

// Shared by the generated fixture and its XCTest runner. This notification
// reports an observed handoff and carries no input or fixture values.
enum WeekHeightHandoff {
    private static let rawName = CFStringCreateWithCString(
        nil, "jp.n624.takupoke.ci.week-height-window", CFStringBuiltInEncodings.UTF8.rawValue
    )!

    private static var name: CFNotificationName {
#if canImport(Darwin)
        CFNotificationName(rawValue: rawName)
#else
        rawName
#endif
    }

    static func post() -> Bool {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return false }
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
        return true
    }

    static func observe(_ observer: UnsafeRawPointer, callback: CFNotificationCallback) -> Bool {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return false }
        CFNotificationCenterAddObserver(center, observer, callback, rawName, nil, .deliverImmediately)
        return true
    }

    static func remove(_ observer: UnsafeRawPointer) {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterRemoveObserver(center, observer, name, nil)
    }
}
