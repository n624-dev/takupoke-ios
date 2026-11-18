import SwiftUI
import UIKit

extension TimetableView {
    var weekGrid: some View {
        let bounds = weekBounds
        let weeks = [-7, 0, 7].compactMap { weekStart.addingDays($0) }.filter(bounds.contains)
        // The date is the identity. Promoting a prepared page preserves its live
        // layout and scroll view; there is no image-to-view handoff on arrival.
        let revision = Array(detailRevision.dropFirst()) + [mainColor.selection.rawValue,
            String(describing: gridDynamicTypeSize), String(Double(gridViewportWidth)),
            String(Double(standardPeriodColumnWidth)), String(Double(periodColumnWidth))]
        let pages = weeks.map { WeekPage(id: $0, revision: revision, content: AnyView(weekPage(on: $0))) }
        return WeekPages(pages: pages, selection: weekStart, viewportWidth: gridViewportWidth,
                         pull: weekPull, accent: weekControlColor) { source, target in
            if weekStart == source, weekBounds.contains(target) { weekStart = target }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: WeekGridWidthKey.self, value: proxy.size.width)
        })
        .background(periodColumnMeasurement(standard: true).dynamicTypeSize(.large))
        .background(periodColumnMeasurement(standard: false).dynamicTypeSize(.large...))
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
    }

    private func weekPage(on week: SchoolDate) -> some View {
        let days = TimetableSchedule.displayedDays(weekStart: week, classes: selectedClasses,
            timetable: timetable, changes: changes, events: events, includesChanges: includesChanges,
            isInternationalStudent: isInternationalStudent, specials: specials,
            matchedByRule: isMappedInternational, sourceIndex: daySchedule.sourceIndex)
        let columns = days.map(dayLayout)
        let eventsOnly = !columns.isEmpty && columns.allSatisfy { $0.fullDayEventTitle != nil }
        let rowHeights = gridRowHeights(columns, days: days)
        return VStack(spacing: 0) {
            ScrollView(.horizontal) {
                WeekColumnsLayout(widths: [periodColumnWidth] + columns.map(\.width), spacing: gridSpacing) {
                    Group {
                        if eventsOnly { Color.clear }
                        else { Text("時限").font(periodHeadingFont) }
                    }
                    .frame(width: periodColumnWidth)
                    ForEach(columns, id: \.day) { column in dayHeaderCell(column) }
                    Group {
                        if eventsOnly {
                            Color.clear.frame(width: periodColumnWidth, height: gridRowHeight)
                        } else {
                            VStack(spacing: gridSpacing) {
                                ForEach(1...8, id: \.self) { period in
                                    let commonTime = commonPeriodTime(period, days: days)
                                    VStack(spacing: 2) {
                                        Text("\(period)").font(periodNumberFont)
                                        if let commonTime {
                                            Text(TimetableDisplayText.periodTime(commonTime))
                                                .font(periodClockFont).foregroundStyle(.secondary)
                                        }
                                    }
                                    .multilineTextAlignment(.center)
                                    .frame(width: periodColumnWidth, height: rowHeights[period - 1], alignment: .center)
                                }
                            }
                        }
                    }
                    // This probe starts at the first lesson, so the header's
                    // final bottom is read from geometry, never fed back into layout.
                    .background(WeekPullObserver(week: week, pull: weekPull))
                    ForEach(columns, id: \.day) { column in
                        if eventsOnly, let title = column.fullDayEventTitle {
                            fullDayEventCard(title, width: column.width, height: nil)
                        } else {
                            dayColumn(column, days: days, rowHeights: rowHeights)
                        }
                    }
                }
                .padding(.trailing, gridSpacing)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            .fixedSize(horizontal: false, vertical: true)
            .dynamicTypeSize(.large...)
            .modifier(WeekGridAccessibility(label: "\(selectedClasses.map(TimetableDisplayText.className).joined(separator: "・"))の週の時間割"))
            weekEvents(on: week, embedded: true)
                .modifier(WeekFooterHandoff(motion: weekPull.motion, week: week))
        }
    }

    func weekEvents(on week: SchoolDate, embedded: Bool = false) -> some View {
        let rows = (0..<7).compactMap { week.addingDays($0) }.compactMap { day -> (SchoolDate, [String])? in
            let titles = TimetableSchedule.events(on: day, analysis: events).map(\.title)
            return titles.isEmpty ? nil : (day, titles)
        }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if embedded { Divider().padding(.bottom, 8) }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        Text(TimetableDisplayText.kana("\(entry.0.month)/\(entry.0.day) " + entry.1.joined(separator: "・")))
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(embedded ? EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20) : EdgeInsets())
            }
        }
    }
}

// Measure all natural headers before placing either row. Each week owns its
// final header height, including wrapped events and Dynamic Type.
private struct WeekColumnsLayout: Layout {
    let widths: [CGFloat]
    let spacing: CGFloat

    private func rowHeights(_ subviews: Subviews) -> (CGFloat, CGFloat) {
        var header: CGFloat = 0, body: CGFloat = 0
        for (index, width) in widths.enumerated() where index + widths.count < subviews.count {
            header = max(header, subviews[index].sizeThatFits(.init(width: width, height: nil)).height)
            body = max(body, subviews[index + widths.count].sizeThatFits(.init(width: width, height: nil)).height)
        }
        return (header, body)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (header, body) = rowHeights(subviews)
        return CGSize(width: widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * spacing,
                      height: header + spacing + body)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (header, body) = rowHeights(subviews)
        var x = bounds.minX
        for (index, width) in widths.enumerated() where index + widths.count < subviews.count {
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                                  proposal: .init(width: width, height: header))
            subviews[index + widths.count].place(at: CGPoint(x: x, y: bounds.minY + header + spacing),
                anchor: .topLeading, proposal: .init(width: width, height: body))
            x += width + spacing
        }
    }
}

private struct WeekPage: Identifiable, View, Equatable {
    let id: SchoolDate
    let revision: [String]
    let content: AnyView
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.revision == rhs.revision }
    var body: some View { content }
}

private struct WeekPageMeasurement: Equatable {
    let size: CGSize
    let revision: [String]
}

extension EnvironmentValues {
    @Entry var isDisplayedTimetableWeek = false
}

private struct WeekGridAccessibility: ViewModifier {
    @Environment(\.isDisplayedTimetableWeek) private var isDisplayed
    let label: String

    func body(content: Content) -> some View {
        content.accessibilityIdentifier(isDisplayed ? "timetable-week-grid" : "")
            .accessibilityLabel(isDisplayed ? label : "")
            .accessibilityHidden(!isDisplayed)
    }
}

private struct WeekPages: View {
    let pages: [WeekPage]
    let selection: SchoolDate
    let viewportWidth: CGFloat
    let pull: WeekPullProgress
    let accent: WeekControlAccent
    let arrive: (SchoolDate, SchoolDate) -> Void
    @ObservedObject private var motion: WeekPageMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pages: [WeekPage], selection: SchoolDate, viewportWidth: CGFloat, pull: WeekPullProgress,
         accent: WeekControlAccent, arrive: @escaping (SchoolDate, SchoolDate) -> Void) {
        self.pages = pages; self.selection = selection; self.pull = pull
        self.viewportWidth = viewportWidth
        self.accent = accent; self.arrive = arrive
        motion = pull.motion
    }

    var body: some View {
        WeekPagesLayout(currentIndex: pages.firstIndex { $0.id == selection } ?? 0,
                        reservedHeight: motion.transition?.height) {
            ForEach(pages) { page in
                let isDisplayed = page.id == selection
                page
                    .onGeometryChange(for: WeekPageMeasurement.self) {
                        WeekPageMeasurement(size: $0.size, revision: page.revision)
                    } action: { motion.measurements[page.id] = $0 }
                    .offset(x: motion.offset(for: page.id, selected: selection, viewportWidth: viewportWidth))
                    .opacity(motion.opacity(for: page.id, selected: selection))
                    .allowsHitTesting(isDisplayed && motion.transition == nil)
                    .accessibilityElement(children: .contain)
                    .accessibilityHidden(!isDisplayed)
                    .environment(\.isDisplayedTimetableWeek, isDisplayed)
            }
        }
        .clipped()
        // Glass is deliberately outside the page clip, with measured clearance
        // from all four visible edges (including short, event-only weeks).
        .overlay {
            WeekPullOverlay(pull: pull, previous: pages.first { $0.id < selection }?.id,
                            next: pages.first { $0.id > selection }?.id, accent: accent)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .onAppear { configure() }
        .onChange(of: selection) { _, _ in
            motion.cancel(); pull.update(distance: 0, visible: .zero, center: 0); configure()
        }
        .onChange(of: pages.map(\.revision)) { _, _ in
            pull.completeWeekMove(); pull.update(distance: 0, visible: .zero, center: 0); configure()
        }
        .onChange(of: reduceMotion) { _, _ in pull.completeWeekMove(); configure() }
        .onDisappear { pull.completeWeekMove(); pull.update(distance: 0, visible: .zero, center: 0) }
    }

    private func configure() {
        motion.selection = selection
        motion.available = Set(pages.map(\.id))
        motion.revisions = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0.revision) })
        motion.reduceMotion = reduceMotion
        motion.arrive = arrive
        motion.retain(weeks: motion.available)
        motion.resetNeighborScrolls(selected: selection)
    }
}

private struct WeekPagesLayout: Layout {
    let currentIndex: Int
    let reservedHeight: CGFloat?
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.indices.contains(currentIndex) else { return .zero }
        if let width = proposal.width, let reservedHeight {
            return CGSize(width: width, height: reservedHeight)
        }
        let natural = subviews[currentIndex].sizeThatFits(.init(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? natural.width, height: reservedHeight ?? natural.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pageProposal = ProposedViewSize(width: bounds.width, height: nil)
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading, proposal: pageProposal)
        }
    }
}

private struct WeekGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// Progress only invalidates the small badge, not the pages or source matching.
@MainActor
final class WeekPullProgress: ObservableObject {
    fileprivate let motion = WeekPageMotion()
    @Published private(set) var distance: CGFloat = 0
    private(set) var center: CGFloat = 0
    private(set) var visible: CGRect = .zero

    func completeWeekMove() { motion.complete() }
    func cancelWeekMove() { motion.cancel() }

    func update(distance: CGFloat, visible: CGRect, center: CGFloat) {
        self.visible = visible; self.center = center
        if self.distance != distance { self.distance = distance }
    }
}

@MainActor
private final class WeekPageMotion: NSObject, ObservableObject {
    struct Transition {
        let id = UUID()
        let source: SchoolDate
        let destination: SchoolDate
        let rubber: CGFloat
        let width: CGFloat
        let direction: CGFloat
        let targetHeight: CGFloat
        var height: CGFloat
        var slideProgress: CGFloat = 0
    }
    private final class ScrollReference {
        weak var value: UIScrollView?
        init(_ value: UIScrollView) { self.value = value }
    }
    @Published private(set) var transition: Transition?
    var selection: SchoolDate?
    var available = Set<SchoolDate>()
    var measurements: [SchoolDate: WeekPageMeasurement] = [:]
    var revisions: [SchoolDate: [String]] = [:]
    var reduceMotion = false
    var arrive: ((SchoolDate, SchoolDate) -> Void)?
    private var scrolls: [SchoolDate: ScrollReference] = [:]
    private var displayLink: CADisplayLink?
    private weak var heldScroll: UIScrollView?
    private var slideStartedAt: CFTimeInterval?
    private var heightAdjustment: (startedAt: CFTimeInterval, initialHeight: CGFloat)?

    func register(_ scroll: UIScrollView, week: SchoolDate) {
        scrolls[week] = ScrollReference(scroll)
    }
    func retain(weeks: Set<SchoolDate>) {
        scrolls = scrolls.filter { weeks.contains($0.key) }
        measurements = measurements.filter { weeks.contains($0.key) }
    }
    func resetNeighborScrolls(selected: SchoolDate) {
        for (week, reference) in scrolls where week != selected {
            guard let scroll = reference.value else { continue }
            let leading = -scroll.adjustedContentInset.left
            if scroll.contentOffset.x != leading {
                scroll.setContentOffset(CGPoint(x: leading, y: scroll.contentOffset.y), animated: false)
            }
        }
    }
    func isReady(_ week: SchoolDate?) -> Bool {
        guard let week, available.contains(week), let scroll = scrolls[week]?.value,
              scroll.window != nil, scroll.bounds.width > 0, let measured = measurements[week],
              measured.revision == revisions[week] else { return false }
        let size = measured.size
        return size.height > 0 && abs(size.width - scroll.bounds.width) < 1
    }
    func begin(from week: SchoolDate, days: Int, scroll: UIScrollView) {
        guard transition == nil, selection == week, let destination = week.addingDays(days),
              isReady(week), isReady(destination), let current = measurements[week]?.size,
              let target = measurements[destination]?.size else { return }
        let minimum = -scroll.adjustedContentInset.left
        let maximum = max(minimum, scroll.contentSize.width - scroll.bounds.width + scroll.adjustedContentInset.right)
        let releasedOffset = scroll.layer.presentation()?.bounds.origin.x ?? scroll.contentOffset.x
        let rubber = WeekEdgePull.rubberBandOffset(offset: releasedOffset - minimum,
                                                  scrollRange: maximum - minimum)
        let edge = releasedOffset + rubber
        // Read the native rubber band before disabling it. Returning the scroll
        // to its edge and translating the entire old page preserves visible x.
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            heldScroll = scroll
            scroll.isScrollEnabled = false
            scroll.setContentOffset(CGPoint(x: edge, y: scroll.contentOffset.y), animated: false)
            transition = Transition(source: week, destination: destination, rubber: rubber,
                width: scroll.bounds.width, direction: days > 0 ? 1 : -1,
                targetHeight: target.height, height: current.height)
        }
        // Commit the release position, then move on the first display callback.
        // Starting a SwiftUI animation there would wait for a second handoff.
        let link = CADisplayLink(target: self, selector: #selector(advanceSlide(_:)))
        displayLink = link; link.add(to: .main, forMode: .common)
    }
    @objc private func advanceSlide(_ link: CADisplayLink) {
        guard let value = transition else { stopDisplayLink(); return }
        let startedAt = slideStartedAt ?? link.timestamp
        slideStartedAt = startedAt
        let duration = reduceMotion ? 0.15 : 0.25
        let elapsed = min(1, max(0, (link.targetTimestamp - startedAt) / duration))
        let progress = CGFloat(elapsed + elapsed * (1 - elapsed) / 2)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { transition?.slideProgress = progress }
        if elapsed == 1 {
            stopDisplayLink()
            settle(id: value.id)
        }
    }
    private func settle(id: UUID) {
        guard let value = transition, value.id == id else { return }
        if reduceMotion || abs(value.height - value.targetHeight) < 1 { finish(id: id); return }
        // Present each reserved height directly. Implicitly animating a frame
        // inside List also animates its content's position during re-layout.
        heightAdjustment = (CACurrentMediaTime(), value.height)
        let link = CADisplayLink(target: self, selector: #selector(adjustHeight(_:)))
        displayLink = link; link.add(to: .main, forMode: .common)
    }
    @objc private func adjustHeight(_ link: CADisplayLink) {
        guard let value = transition, let adjustment = heightAdjustment else { return }
        let progress = min(1, max(0, (link.targetTimestamp - adjustment.startedAt) / 0.2))
        if progress == 1 { finish(id: value.id); return }
        let fraction = CGFloat(progress * progress * (3 - 2 * progress))
        let height = adjustment.initialHeight + (value.targetHeight - adjustment.initialHeight) * fraction
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { transition?.height = height }
    }
    private func stopDisplayLink() {
        displayLink?.invalidate(); displayLink = nil
        slideStartedAt = nil
        heightAdjustment = nil
    }
    private func finish(id: UUID) {
        guard let value = transition, value.id == id else { return }
        stopDisplayLink()
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            arrive?(value.source, value.destination)
            transition = nil
            heldScroll?.isScrollEnabled = true
            heldScroll = nil
        }
    }
    func complete() {
        if let transition { finish(id: transition.id) }
    }
    func cancel() {
        stopDisplayLink()
        heldScroll?.isScrollEnabled = true
        heldScroll = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { transition = nil }
    }
    func offset(for week: SchoolDate, selected: SchoolDate, viewportWidth: CGFloat) -> CGFloat {
        if let value = transition {
            if week == value.source {
                if reduceMotion { return value.rubber }
                return value.rubber - (value.direction * value.width + value.rubber) * value.slideProgress
            }
            if week == value.destination {
                if reduceMotion { return 0 }
                return (value.direction * value.width + value.rubber) * (1 - value.slideProgress)
            }
        }
        guard !reduceMotion, week != selected else { return 0 }
        return week < selected ? -viewportWidth : viewportWidth
    }
    func opacity(for week: SchoolDate, selected: SchoolDate) -> Double {
        guard let value = transition else { return week == selected ? 1 : 0 }
        if week == value.source { return reduceMotion ? Double(1 - value.slideProgress) : 1 }
        if week == value.destination { return reduceMotion ? Double(value.slideProgress) : 1 }
        return 0
    }
}

private struct WeekFooterHandoff: ViewModifier {
    @ObservedObject var motion: WeekPageMotion
    let week: SchoolDate
    func body(content: Content) -> some View {
        // Only the grid was rubber-banding. Start the footer at its own
        // release position and have it cover the remaining distance with the grid.
        let value = motion.transition.flatMap { $0.source == week ? $0 : nil }
        let remaining = motion.reduceMotion ? 1 : 1 - (value?.slideProgress ?? 0)
        content.offset(x: -(value?.rubber ?? 0) * remaining)
    }
}

private struct WeekPullOverlay: View {
    @ObservedObject var pull: WeekPullProgress
    let previous: SchoolDate?
    let next: SchoolDate?
    let accent: WeekControlAccent
    var body: some View {
        let distance = pull.distance
        if distance != 0, let destination = distance > 0 ? previous : next {
            let progress = min(abs(distance) / WeekEdgePull.threshold, 1)
            GeometryReader { geometry in
                let origin = geometry.frame(in: .global).origin
                WeekBadgePosition(visible: pull.visible.offsetBy(dx: -origin.x, dy: -origin.y),
                                  preferredY: pull.center - origin.y, previous: distance > 0) {
                    ViewThatFits {
                        WeekPullBadge(previous: distance > 0, ready: progress == 1, date: destination,
                                      progress: progress, accent: accent, compact: false).fixedSize()
                        WeekPullBadge(previous: distance > 0, ready: progress == 1, date: destination,
                                      progress: progress, accent: accent, compact: true).fixedSize()
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            }
        }
    }
}

private struct WeekBadgePosition: Layout {
    let visible: CGRect
    let preferredY: CGFloat
    let previous: Bool
    let margin: CGFloat = 10
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let badge = subviews.first else { return }
        let viewport = visible.offsetBy(dx: bounds.minX, dy: bounds.minY).intersection(bounds)
        guard viewport.width > margin * 2, viewport.height > margin * 2 else {
            badge.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .zero)
            return
        }
        let available = CGSize(width: viewport.width - margin * 2, height: viewport.height - margin * 2)
        let size = badge.sizeThatFits(ProposedViewSize(available))
        let frame = WeekEdgePull.badgeFrame(visible: viewport, preferredY: preferredY + bounds.minY,
                                          size: size, previous: previous, margin: margin)
        badge.place(at: CGPoint(x: frame.midX, y: frame.midY), anchor: .center, proposal: ProposedViewSize(size))
    }
}

private struct WeekPullBadge: View {
    let previous: Bool
    let ready: Bool
    let date: SchoolDate
    let progress: CGFloat
    let accent: WeekControlAccent
    let compact: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var ring: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.3), lineWidth: 2)
            Circle().trim(from: 0, to: progress).stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: previous ? "chevron.left" : "chevron.right").foregroundStyle(accent)
        }.frame(width: 27, height: 27)
    }
    private var label: some View {
        let releaseTitle = previous ? "離すと前週へ" : "離すと翌週へ"
        return VStack(spacing: 3) {
            ZStack {
                Text(releaseTitle).hidden().accessibilityHidden(true)
                Text(ready ? releaseTitle : (previous ? "前週" : "翌週"))
            }
            Text("\(date.month)/\(date.day)〜").monospacedDigit()
        }
    }
    var body: some View {
        Group {
            if compact { HStack(spacing: 7) { ring; label } }
            else { VStack(spacing: 3) { ring; label } }
        }
        .font(.caption.weight(.semibold)).foregroundStyle(.primary).padding(7)
        .background { if reduceTransparency { RoundedRectangle(cornerRadius: 14).fill(.background) } }
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Observe the horizontal scroll view's own pan. No competing gesture recognizer
/// is installed, so wide content keeps priority over switching weeks.
private struct WeekPullObserver: UIViewRepresentable {
    @Environment(\.isDisplayedTimetableWeek) private var isDisplayed
    let week: SchoolDate
    let pull: WeekPullProgress
    func makeUIView(context: Context) -> Probe {
        let view = Probe(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        view.week = week
        view.progress = pull
        view.isDisplayed = isDisplayed
        view.attach()
    }
    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.detach() }

    final class Probe: UIView {
        var week: SchoolDate?
        weak var progress: WeekPullProgress?
        var isDisplayed = false
        private weak var scroll: UIScrollView?
        private var pull: WeekEdgePull?
        override func layoutSubviews() { super.layoutSubviews(); attach() }
        override func didMoveToWindow() { super.didMoveToWindow(); attach() }
        func attach() {
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            let next = window == nil ? nil : ancestor as? UIScrollView
            if next !== scroll {
                detach(); scroll = next
                next?.panGestureRecognizer.addTarget(self, action: #selector(pan(_:)))
            }
            if let scroll, let week { progress?.motion.register(scroll, week: week) }
            if let scroll, scroll.accessibilityElementsHidden == isDisplayed {
                scroll.accessibilityElementsHidden = !isDisplayed
            }
        }
        func detach() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(pan(_:)))
            scroll?.accessibilityElementsHidden = false
            scroll = nil; pull = nil
        }
        private func visibleRect(of scroll: UIScrollView) -> CGRect {
            guard let window else { return scroll.bounds }
            var rect = scroll.convert(window.safeAreaLayoutGuide.layoutFrame, from: window)
            var ancestor = scroll.superview
            while let view = ancestor {
                if let list = view as? UIScrollView {
                    rect = rect.intersection(scroll.convert(list.bounds.inset(by: list.adjustedContentInset), from: list))
                } else if view.clipsToBounds {
                    rect = rect.intersection(scroll.convert(view.bounds, from: view))
                }
                ancestor = view.superview
            }
            var responder: UIResponder? = scroll
            while let current = responder {
                if let controller = current as? UIViewController {
                    if let bar = controller.navigationController?.navigationBar, !bar.isHidden, bar.window === window {
                        let bottom = scroll.convert(bar.bounds, from: bar).maxY
                        if bottom > rect.minY && bottom < rect.maxY {
                            rect = CGRect(x: rect.minX, y: bottom, width: rect.width, height: rect.maxY - bottom)
                        }
                    }
                    if let bar = controller.tabBarController?.tabBar, !bar.isHidden, bar.window === window {
                        let top = scroll.convert(bar.bounds, from: bar).minY
                        if top > rect.minY && top < rect.maxY { rect.size.height = top - rect.minY }
                    }
                }
                responder = current.next
            }
            return rect.intersection(scroll.bounds)
        }
        @objc private func pan(_ pan: UIPanGestureRecognizer) {
            guard let scroll, let week, let progress, progress.motion.selection == week,
                  progress.motion.transition == nil else { return }
            let translation = pan.translation(in: scroll)
            switch pan.state {
            case .began:
                let inset = scroll.adjustedContentInset
                pull = WeekEdgePull(velocity: pan.velocity(in: scroll), offset: scroll.contentOffset.x + inset.left,
                    scrollRange: scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width)
            case .changed:
                guard let pull, let window else { return }
                let distance = pull.distance(for: translation)
                let target = week.addingDays(distance > 0 ? -7 : 7)
                let viewport = visibleRect(of: scroll).offsetBy(dx: -scroll.bounds.minX, dy: -scroll.bounds.minY)
                let headerBottom = convert(CGPoint.zero, to: scroll).y - scroll.bounds.minY
                let bodyTop = min(viewport.maxY, max(viewport.minY, headerBottom))
                let body = CGRect(x: viewport.minX, y: bodyTop, width: viewport.width, height: viewport.maxY - bodyTop)
                let visible = body.height >= 70 ? body : viewport
                guard !visible.isEmpty else { return }
                let windowVisible = scroll.convert(visible.offsetBy(dx: scroll.bounds.minX, dy: scroll.bounds.minY), to: window)
                let center = WeekEdgePull.badgeCenter(visible: visible, headerHeight: headerBottom)
                progress.update(distance: progress.motion.isReady(target) ? distance : 0, visible: windowVisible,
                    center: windowVisible.minY + center - visible.minY)
            case .ended:
                let distance = pull?.distance(for: translation) ?? 0
                pull = nil
                progress.update(distance: 0, visible: .zero, center: 0)
                let days = WeekEdgePull.weekOffset(onRelease: distance,
                    previous: progress.motion.isReady(week.addingDays(-7)), next: progress.motion.isReady(week.addingDays(7)))
                if days != 0 { progress.motion.begin(from: week, days: days, scroll: scroll) }
            case .failed, .cancelled:
                pull = nil; progress.update(distance: 0, visible: .zero, center: 0)
            default: break
            }
        }
    }
}
