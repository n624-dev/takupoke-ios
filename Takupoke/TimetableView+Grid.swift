import SwiftUI
import UIKit

extension TimetableView {
    var weekGrid: some View {
        let days = TimetableSchedule.displayedDays(weekStart: weekStart, classes: selectedClasses,
                                                   timetable: timetable, changes: changes, events: events,
                                                   includesChanges: includesChanges,
                                                   isInternationalStudent: isInternationalStudent,
                                                   specials: specials, matchedByRule: isMappedInternational,
                                                   sourceIndex:daySchedule.sourceIndex)
        let columns = days.map(dayLayout)
        let eventsOnly = !columns.isEmpty && columns.allSatisfy { $0.fullDayEventTitle != nil }
        let rowHeights = gridRowHeights(columns, days: days)
        return ScrollView(.horizontal) {
            Group {
                if eventsOnly {
                    HStack(alignment: .top, spacing: gridSpacing) {
                        Color.clear.frame(width: periodColumnWidth, height: 1)
                        ForEach(columns, id: \.day) { column in
                            VStack(spacing: gridSpacing) {
                                dayHeaderCell(column)
                                if let title = column.fullDayEventTitle {
                                    fullDayEventCard(title, width: column.width, height: nil)
                                }
                            }
                        }
                    }
                } else {
                    Grid(alignment: .topLeading, horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
                        GridRow {
                            Text("時限")
                                .font(periodHeadingFont)
                                .frame(width: periodColumnWidth, alignment: .center)
                                .gridCellAnchor(.center)
                            ForEach(columns, id: \.day) { column in
                                dayHeaderCell(column).gridCellAnchor(.center)
                            }
                        }
                        GridRow {
                            VStack(spacing: gridSpacing) {
                                ForEach(1...8, id: \.self) { period in
                                    let commonTime = commonPeriodTime(period, days: days)
                                    VStack(spacing: 2) {
                                        Text("\(period)").font(periodNumberFont)
                                        if let commonTime {
                                            Text(TimetableDisplayText.periodTime(commonTime))
                                                .font(periodClockFont)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .multilineTextAlignment(.center)
                                    .frame(width: periodColumnWidth, height: rowHeights[period - 1], alignment: .center)
                                }
                            }
                            ForEach(columns, id: \.day) { column in
                                dayColumn(column, days: days, rowHeights: rowHeights)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, gridSpacing)
            .background(WeekPullObserver { distance, released in
                let allowed = distance > 0 ? canMovePrevious : canMoveNext
                if released {
                    weekPull = 0
                    if allowed && abs(distance) >= WeekPullObserver.threshold { moveWeek(distance > 0 ? -7 : 7) }
                } else {
                    weekPull = allowed ? distance : 0
                }
            })
        }
        .scrollBounceBehavior(.always, axes: .horizontal)
        .id(weekStart)
        .overlay(alignment: weekPull > 0 ? .topLeading : .topTrailing) {
            if weekPull != 0, let destination = weekStart.addingDays(weekPull > 0 ? -7 : 7) {
                let previous = weekPull > 0
                let ready = abs(weekPull) >= WeekPullObserver.threshold
                WeekPullBadge(previous: previous, ready: ready, date: destination,
                              progress: min(abs(weekPull) / WeekPullObserver.threshold, 1), accent: weekControlColor)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: WeekGridWidthKey.self, value: proxy.size.width)
        })
        .background(periodColumnMeasurement(standard: true).dynamicTypeSize(.large))
        .background(periodColumnMeasurement(standard: false))
        .onPreferenceChange(StandardPeriodColumnWidthKey.self) { width in
            let fittedWidth = ceil(width) + 2
            guard width > 0, abs(standardPeriodColumnWidth - fittedWidth) > 0.5 else { return }
            standardPeriodColumnWidth = fittedWidth
        }
        .onPreferenceChange(PeriodColumnWidthKey.self) { width in
            let fittedWidth = ceil(width) + 2
            guard width > 0, abs(measuredPeriodColumnWidth - fittedWidth) > 0.5 else { return }
            measuredPeriodColumnWidth = fittedWidth
        }
        .onPreferenceChange(WeekGridWidthKey.self) { width in
            guard width > 0, abs(gridViewportWidth - width) > 0.5 else { return }
            gridViewportWidth = width
        }
        .onPreferenceChange(DayHeaderHeightKey.self) { height in
            if abs(dayHeaderHeight - height) > 0.5 { dayHeaderHeight = height }
        }
        .dynamicTypeSize(.large...)
        .accessibilityIdentifier("timetable-week-grid")
        .accessibilityLabel("\(selectedClasses.map(TimetableDisplayText.className).joined(separator: "・"))の週の時間割")
    }

    var weekEvents: some View {
        let rows = (0..<7).compactMap { weekStart.addingDays($0) }.compactMap { day -> (SchoolDate, [String])? in
            let titles = TimetableSchedule.events(on: day, analysis: events).map(\.title)
            return titles.isEmpty ? nil : (day, titles)
        }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        Text(TimetableDisplayText.kana("\(entry.0.month)/\(entry.0.day) " + entry.1.joined(separator: "・")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct WeekGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WeekPullBadge: View {
    let previous: Bool
    let ready: Bool
    let date: SchoolDate
    let progress: CGFloat
    let accent: Color
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.3), lineWidth: 2)
                Circle().trim(from: 0, to: progress).stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: previous ? "chevron.left" : "chevron.right")
                    .foregroundStyle(contrast == .increased ? Color.primary : accent)
            }.frame(width: 27, height: 27)
            Text(ready ? (previous ? "離すと前週へ" : "離すと翌週へ") : (previous ? "前週" : "翌週"))
            Text("\(date.month)/\(date.day)〜").monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .padding(7)
        .background { if reduceTransparency { RoundedRectangle(cornerRadius: 14).fill(.background) } }
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Observe the horizontal scroll view's own pan. Tracking ends with the finger,
/// before bouncing or deceleration can choose another week.
private struct WeekPullObserver: UIViewRepresentable {
    static let threshold: CGFloat = 115
    let update: (CGFloat, Bool) -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.update = update
        return view
    }
    func updateUIView(_ uiView: Probe, context: Context) { uiView.update = update }
    static func dismantleUIView(_ uiView: Probe, coordinator: ()) { uiView.detach() }

    final class Probe: UIView {
        var update: ((CGFloat, Bool) -> Void)?
        private weak var scroll: UIScrollView?
        private var left: CGFloat = 0
        private var right: CGFloat = 0
        private var horizontal = false

        override func layoutSubviews() { super.layoutSubviews(); attach() }
        override func didMoveToWindow() { super.didMoveToWindow(); attach() }

        private func attach() {
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            let next = window == nil ? nil : ancestor as? UIScrollView
            guard next !== scroll else { return }
            detach()
            scroll = next
            next?.panGestureRecognizer.addTarget(self, action: #selector(pan(_:)))
        }

        func detach() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(pan(_:)))
            scroll = nil
        }

        @objc private func pan(_ pan: UIPanGestureRecognizer) {
            guard let scroll else { return }
            let translation = pan.translation(in: scroll)
            switch pan.state {
            case .began:
                let velocity = pan.velocity(in: scroll)
                horizontal = abs(velocity.x) > abs(velocity.y)
                let inset = scroll.adjustedContentInset
                let range = max(0, scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width)
                left = min(range, max(0, scroll.contentOffset.x + inset.left))
                right = range - left
            case .changed, .ended:
                guard horizontal else { return }
                let distance = max(0, translation.x - left) + min(0, translation.x + right)
                update?(distance, pan.state == .ended)
                if pan.state == .ended { horizontal = false }
            case .failed, .cancelled:
                horizontal = false
                update?(0, false)
            default: break
            }
        }
    }
}
