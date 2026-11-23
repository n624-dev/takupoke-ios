import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

struct FixtureTypeSize: ViewModifier {
    let enabled: Bool
    let size: DynamicTypeSize
    func body(content: Content) -> some View {
        if enabled { content.environment(\.dynamicTypeSize, size) } else { content }
    }
}

@MainActor
final class FixtureGridMeasurements: ObservableObject {
    nonisolated static let capturesDetailGeometry = capturesDetailGeometry(arguments: ProcessInfo.processInfo.arguments)

    nonisolated static func capturesDetailGeometry(arguments: [String]) -> Bool {
        arguments.contains("--grid-probe") && !arguments.contains("--week-motion-probe")
    }

    @Published var headerFrames: [String: CGRect] = [:]
    @Published var eventSizes: [String: CGSize] = [:]
    @Published var cardFrames: [String: CGRect] = [:]
}

struct FixtureActiveGridMetrics: View {
    @Environment(\.isDisplayedTimetableWeek) private var isDisplayed
    @ObservedObject private var motion = FixtureWeekMotionRecorder.shared
    @ObservedObject var measurements: FixtureGridMeasurements
    let read: () -> String

    var body: some View {
        // The layout assertions read this snapshot after the real frame capture.
        if isDisplayed && !motion.isRecording {
            Text("grid metrics").font(.system(size: 1)).foregroundStyle(.clear)
                .accessibilityIdentifier("fixture-grid-metrics")
                .accessibilityValue(read())
                .allowsHitTesting(false)
        }
    }
}

extension TimetableView {
    func fixtureCardKey(on day: SchoolDate, className: String, entry: TimetableSchedule.PositionedBlock)
        -> String
    {
        "\(day.iso8601)|\(className)|\(entry.lane)|\(entry.block.startPeriod)|\(entry.block.endPeriod)"
    }

    func fixtureGridMetrics(columns: [DayGridLayout], days: [SchoolDate], heights: [CGFloat]) -> String {
        FixtureWeekMotionRecorder.shared.recordGridMetricsRead()
        var cards: [[String: Any]] = []
        for column in columns {
            for (index, positioned) in column.positioned.enumerated() {
                for entry in positioned {
                    let block = entry.block
                    let source: String
                    switch block.content {
                    case .normal: source = "normal"
                    case .change: source = "change"
                    case .special(let item): source = item.kind.rawValue
                    }
                    let actual =
                        heights[(block.startPeriod - 1)..<block.endPeriod].reduce(0, +) + CGFloat(
                            block.endPeriod - block.startPeriod) * gridSpacing
                    let isCancellation: Bool = {
                        if case .change(let item) = block.content { return item.isCancellation }
                        return false
                    }()
                    let renderedTime =
                        isCancellation || block.startPeriod != block.endPeriod
                        || commonPeriodTime(block.startPeriod, days: days) == nil
                    var card: [String: Any] = [
                        "source": source, "start": block.startPeriod, "end": block.endPeriod,
                        "cancellation": {
                            if case .change(let item) = block.content { return item.isCancellation }
                            return false
                        }(),
                        "lane": entry.lane, "day": column.day.iso8601,
                        "height": actual,
                        "required": cardRequiredHeight(
                            block, on: column.day,
                            className: selectedClasses[index], days: days),
                        "timeFont": renderedTime
                            ? (cardTime(block, on: column.day, className: selectedClasses[index]).map(
                                cardTimeFontSize) ?? 0) : 0,
                    ]
                    if let frame = fixtureGridMeasurements.cardFrames[
                        fixtureCardKey(on: column.day, className: selectedClasses[index], entry: entry)]
                    {
                        card["frame"] = [
                            "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height,
                        ]
                    }
                    cards.append(card)
                }
            }
        }
        let requestedSize =
            (try? String(
                contentsOf: FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask)[0].appendingPathComponent("expected-text-size.txt"), encoding: .utf8))
            ?? "large"
        let expectedSizes: [String: UIContentSizeCategory] = [
            "large": .large, "extra-small": .extraSmall,
            "extra-extra-extra-large": .extraExtraExtraLarge,
            "accessibility-extra-extra-extra-large": .accessibilityExtraExtraExtraLarge,
        ]
        let value: [String: Any] = [
            "week": weekStart.iso8601, "firstWeek": weekBounds.lowerBound.iso8601, "lastWeek": weekBounds.upperBound.iso8601,
            "scale": gridScale, "width": dayColumnWidth,
            "systemSize": UIApplication.shared.preferredContentSizeCategory.rawValue,
            "expectedSystemSize": expectedSizes[requestedSize]?.rawValue ?? "invalid test size",
            "baseWidth": standardDayColumnWidth, "viewport": gridViewportWidth,
            "periodWidth": periodColumnWidth, "basePeriodWidth": standardPeriodColumnWidth,
            "subjectFont": gridUIFont(11).pointSize, "metadataFont": gridUIFont(9).pointSize,
            "eventFont": gridUIFont(14).pointSize, "periodFont": gridUIFont(15).pointSize,
            "headerFrames": fixtureGridMeasurements.headerFrames.filter { key, _ in days.contains { $0.iso8601 == key } }
                .mapValues { ["x": $0.minX, "y": $0.minY, "height": $0.height] },
            "eventSizes": fixtureGridMeasurements.eventSizes.mapValues { ["width": $0.width, "height": $0.height] },
            "heights": heights, "cards": cards,
            "days": days.map(\.iso8601), "eventsOnly": columns.allSatisfy { $0.fullDayEventTitle != nil },
            "commonClocks": (1...8).compactMap { commonPeriodTime($0, days: days) },
        ]
        return String(
            data: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), encoding: .utf8)!
    }
}
