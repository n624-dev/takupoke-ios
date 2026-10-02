import Foundation

/// Display absolute timestamps in Japan while preserving their stored instant.
/// The locale still follows the user; only the display time zone is fixed.
enum JapaneseDateDisplay {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    static var timestamp: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.year().month().day().hour().minute()
        style.timeZone = timeZone
        return style
    }
}
