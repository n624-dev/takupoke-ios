import CoreFoundation

// Shared by the generated fixture and its XCTest runner. This notification
// reports an observed milestone and carries no input or fixture values.
struct WeekMotionSignal: Sendable {
    static let heightWindow = WeekMotionSignal(identifier: "jp.n624.takupoke.ci.week-height-window")
    static let reportReady = WeekMotionSignal(identifier: "jp.n624.takupoke.ci.week-motion-report-ready")

    private let identifier: String
    private var rawName: CFString {
        CFStringCreateWithCString(nil, identifier, CFStringBuiltInEncodings.UTF8.rawValue)!
    }

    private var name: CFNotificationName {
#if canImport(Darwin)
        CFNotificationName(rawValue: rawName)
#else
        rawName
#endif
    }

    func post() -> Bool {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return false }
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
        return true
    }

    func observe(_ observer: UnsafeRawPointer, callback: CFNotificationCallback) -> Bool {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return false }
        CFNotificationCenterAddObserver(center, observer, callback, rawName, nil, .deliverImmediately)
        return true
    }

    func remove(_ observer: UnsafeRawPointer) {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterRemoveObserver(center, observer, name, nil)
    }
}
