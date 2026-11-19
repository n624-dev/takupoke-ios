import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

extension TimetableView {
    var weekGrid: some View {
        // The date is the identity. Promoting a prepared page preserves its live
        // layout and scroll view; there is no image-to-view handoff on arrival.
        let revision = detailRevision + [mainColor.selection.rawValue,
            String(describing: gridDynamicTypeSize), String(Double(gridViewportWidth)),
            String(Double(standardPeriodColumnWidth)), String(Double(periodColumnWidth))]
        return WeekPages(selection: weekStart, bounds: weekBounds, revision: revision,
                         viewportWidth: gridViewportWidth, pull: weekPull, accent: weekControlColor,
                         content: { AnyView(weekPage(on: $0)) },
                         arrive: { source, target in
                             if weekStart == source, weekBounds.contains(target) { weekStart = target }
                         })
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
    let content: () -> AnyView
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.revision == rhs.revision }
    var body: some View { content() }
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
    let selection: SchoolDate
    let bounds: ClosedRange<SchoolDate>
    let revision: [String]
    let viewportWidth: CGFloat
    let pull: WeekPullProgress
    let accent: WeekControlAccent
    let content: (SchoolDate) -> AnyView
    let arrive: (SchoolDate, SchoolDate) -> Void
    private let motion: WeekPageMotion
    @ObservedObject private var preparation: WeekPagePreparation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(selection: SchoolDate, bounds: ClosedRange<SchoolDate>, revision: [String],
         viewportWidth: CGFloat, pull: WeekPullProgress, accent: WeekControlAccent,
         content: @escaping (SchoolDate) -> AnyView, arrive: @escaping (SchoolDate, SchoolDate) -> Void) {
        self.selection = selection; self.bounds = bounds; self.revision = revision
        self.pull = pull; self.content = content
        self.viewportWidth = viewportWidth
        self.accent = accent; self.arrive = arrive
        motion = pull.motion
        preparation = pull.motion.preparation
    }

    var body: some View {
        let window = preparation.window
        let weeks = WeekEdgePull.preparedWeeks(selected: window?.source ?? selection, arriving: window?.arrival,
                                              within: bounds)
        let pages = weeks.map { week in WeekPage(id: week, revision: revision, content: { content(week) }) }
        WeekPagesCanvas(pages: pages, currentIndex: weeks.firstIndex(of: selection) ?? 0,
                        selection: selection, viewportWidth: viewportWidth, motion: motion)
        .clipped()
        .background(WeekTransitionPullObserver(pull: pull))
        // Glass is deliberately outside the page clip, with measured clearance
        // from all four visible edges (including short, event-only weeks).
        .overlay {
            WeekPullOverlay(pull: pull, previous: adjacentWeek(-7), next: adjacentWeek(7), accent: accent)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .onAppear { motion.selection = selection; configure(weeks) }
        .onChange(of: selection) { _, _ in
            if motion.selection != selection {
                pull.cancelWeekMove()
                motion.selection = selection
            }
            configure(weeks)
        }
        .onChange(of: weeks) { _, _ in configure(weeks) }
        .onChange(of: bounds) { _, _ in
            pull.cancelWeekMove(); configure(weeks)
        }
        .onChange(of: revision) { _, _ in
            pull.completeWeekMove(); configure(weeks)
        }
        .onChange(of: reduceMotion) { _, _ in pull.completeWeekMove(); configure(weeks) }
        .onDisappear { pull.completeWeekMove() }
    }

    private func adjacentWeek(_ days: Int) -> SchoolDate? {
        guard let week = selection.addingDays(days), bounds.contains(week) else { return nil }
        return week
    }

    private func configure(_ weeks: [SchoolDate]) {
        motion.bounds = bounds
        motion.available = Set(weeks)
        motion.revision = revision
        motion.reduceMotion = reduceMotion
        motion.arrive = arrive
        motion.retain(weeks: motion.available)
        motion.resetNeighborScrolls(selected: selection)
        motion.scheduleQueuedMove()
    }
}

// The prepared pages stay fixed while the display link updates their position.
// Building page content depends on the week window rather than on every frame.
private struct WeekPagesCanvas: View {
    let pages: [WeekPage]
    let currentIndex: Int
    let selection: SchoolDate
    let viewportWidth: CGFloat
    @ObservedObject var motion: WeekPageMotion

    var body: some View {
        WeekPagesLayout(currentIndex: currentIndex, reservedHeight: motion.reservedHeight) {
            ForEach(pages) { page in
                let isDisplayed = page.id == selection
                page.equatable()
                    .onGeometryChange(for: WeekPageMeasurement.self) {
                        WeekPageMeasurement(size: $0.size, revision: page.revision)
                    } action: { motion.measure($0, week: page.id) }
                    .offset(x: motion.offset(for: page.id, selected: selection, viewportWidth: viewportWidth))
                    .opacity(motion.opacity(for: page.id, selected: selection))
                    .allowsHitTesting(isDisplayed && motion.transition == nil)
                    .accessibilityElement(children: .contain)
                    .accessibilityHidden(!isDisplayed)
                    .environment(\.isDisplayedTimetableWeek, isDisplayed)
            }
        }
    }
}

@MainActor
private final class WeekPagePreparation: ObservableObject {
    struct Window: Equatable {
        let source: SchoolDate
        let arrival: SchoolDate
    }
    @Published private(set) var window: Window?

    func prepare(source: SchoolDate, arrival: SchoolDate) {
        let next = Window(source: source, arrival: arrival)
        if window != next { window = next }
    }
    func reset() {
        if window != nil { window = nil }
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

    func completeWeekMove() {
        motion.complete()
        update(distance: 0, visible: .zero, center: 0)
    }
    func cancelWeekMove() {
        motion.cancel()
        update(distance: 0, visible: .zero, center: 0)
    }

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
        var slideProgress: CGFloat = 0
    }
    private final class ScrollReference {
        weak var value: UIScrollView?
        weak var probe: WeekPullObserver.Probe?
        init(_ value: UIScrollView, probe: WeekPullObserver.Probe) {
            self.value = value; self.probe = probe
        }
    }
    @Published private(set) var transition: Transition?
    @Published private(set) var reservedHeight: CGFloat?
    let preparation = WeekPagePreparation()
    var selection: SchoolDate?
    var bounds: ClosedRange<SchoolDate>?
    var available = Set<SchoolDate>()
    var revision: [String] = []
    var reduceMotion = false
    var arrive: ((SchoolDate, SchoolDate) -> Void)?
    private var scrolls: [SchoolDate: ScrollReference] = [:]
    private var measurements: [SchoolDate: WeekPageMeasurement] = [:]
    private var releases = WeekPullReleases()
    private var deferredReleases = WeekDeferredPulls()
    private var queuedMoveScheduled = false
    private(set) var inputGeneration = UUID()
    private(set) var trackingTransitionTouch = false
    private(set) var transitionTouchWeek: SchoolDate?
    var nextInputWeek: SchoolDate? { releases.lastDestination ?? transition?.destination ?? selection }
    var hasDeferredReleases: Bool { !deferredReleases.isEmpty }
    private var displayLink: CADisplayLink?
    private weak var heldScroll: UIScrollView?
    private var slideStartedAt: CFTimeInterval?
    private var heightAdjustment: (startedAt: CFTimeInterval?, initialHeight: CGFloat, targetHeight: CGFloat)?

    func register(_ scroll: UIScrollView, week: SchoolDate, probe: WeekPullObserver.Probe) {
        if scrolls[week]?.value !== scroll || scrolls[week]?.probe !== probe {
            scrolls[week] = ScrollReference(scroll, probe: probe)
        }
        scheduleQueuedMove()
    }
    func measure(_ measurement: WeekPageMeasurement, week: SchoolDate) {
        measurements[week] = measurement
        scheduleQueuedMove()
    }
    func scroll(for week: SchoolDate) -> UIScrollView? {
        scrolls[week]?.value
    }
    func startingPosition(on week: SchoolDate) -> WeekHorizontalPosition? {
        guard isReady(week), let scroll = scroll(for: week) else { return nil }
        let inset = scroll.adjustedContentInset
        return WeekHorizontalPosition(offset: scroll.contentOffset.x + inset.left,
            range: scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width)
    }
    func track(_ translation: CGPoint, from start: WeekHorizontalPosition, on scroll: UIScrollView) -> CGFloat {
        let next = start.offset(after: translation) - scroll.adjustedContentInset.left
        if abs(scroll.contentOffset.x - next) > 0.01 {
            scroll.setContentOffset(CGPoint(x: next, y: scroll.contentOffset.y), animated: false)
        }
        return start.pullDistance(after: translation)
    }
    func gridContains(_ point: CGPoint, on week: SchoolDate) -> Bool {
        scrolls[week]?.probe?.inputFrameInWindow()?.contains(point) == true
    }
    func showPull(_ distance: CGFloat, on week: SchoolDate) {
        scrolls[week]?.probe?.showPull(distance)
    }
    func setTransitionTouch(active: Bool, week: SchoolDate?) {
        trackingTransitionTouch = active; transitionTouchWeek = week
    }
    func canStartInPage(_ week: SchoolDate) -> Bool {
        selection == week && transition == nil && releases.isEmpty && !hasDeferredReleases && !trackingTransitionTouch
    }
    func canMove(from week: SchoolDate, by days: Int) -> Bool {
        guard let destination = week.addingDays(days) else { return false }
        return bounds?.contains(destination) == true
    }
    func prepareBeyondPull(from week: SchoolDate, distance: CGFloat) {
        guard transition == nil, heightAdjustment == nil, selection == week, distance != 0 else { return }
        let days = distance > 0 ? -7 : 7
        guard canMove(from: week, by: days), let target = week.addingDays(days) else { return }
        preparation.prepare(source: week, arrival: target)
    }
    func clearUnusedPreparation() {
        if releases.isEmpty && transition == nil && heightAdjustment == nil { preparation.reset() }
    }
    func release(from week: SchoolDate, distance: CGFloat) {
        guard nextInputWeek == week, let bounds else { return }
        releases.append(from: week, distance: distance, within: bounds)
        startQueuedMove()
        clearUnusedPreparation()
    }
    func releaseEarly(_ release: WeekDeferredPulls.Contact) {
        deferredReleases.append(release)
        processReleasedContacts()
    }
    func scheduleQueuedMove() {
        guard (!releases.isEmpty || hasDeferredReleases), !queuedMoveScheduled else { return }
        queuedMoveScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.queuedMoveScheduled = false
            self.processReleasedContacts()
        }
    }
    private func processReleasedContacts() {
        startQueuedMove()
        while let week = nextInputWeek, let scroll = scroll(for: week) {
            var queue = deferredReleases
            guard let contact = queue.consume(on: week, startingPosition: { self.startingPosition(on: week) }) else { return }
            deferredReleases = queue
            release(from: week, distance: track(contact.translation, from: contact.start, on: scroll))
        }
    }
    private func startQueuedMove() {
        guard transition == nil, let week = selection, let scroll = scroll(for: week),
              let current = measurements[week]?.size else { return }
        // Readiness checks use the same registered views and measured revisions
        // as the subsequent move. Copy the queue to avoid overlapping access.
        var queue = releases
        guard let move = queue.consume(from: week, isReady: { self.isReady($0) }),
              let target = measurements[move.destination]?.size else { return }
        releases = queue
        begin(from: week, to: move.destination, scroll: scroll, currentHeight: current.height, targetHeight: target.height)
    }
    func retain(weeks: Set<SchoolDate>) {
        scrolls = scrolls.filter { weeks.contains($0.key) }
        measurements = measurements.filter { weeks.contains($0.key) }
    }
    func resetNeighborScrolls(selected: SchoolDate) {
        for (week, reference) in scrolls where week != selected && week != transition?.source
            && week != transition?.destination && week != transitionTouchWeek {
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
              measured.revision == revision else { return false }
        let size = measured.size
        return size.height > 0 && abs(size.width - scroll.bounds.width) < 1
    }
    private func begin(from week: SchoolDate, to destination: SchoolDate, scroll: UIScrollView,
                       currentHeight: CGFloat, targetHeight: CGFloat) {
        let initialHeight = reservedHeight ?? currentHeight
        if heightAdjustment != nil { finishHeight(reserving: initialHeight) }
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
            reservedHeight = initialHeight
            transition = Transition(source: week, destination: destination, rubber: rubber,
                width: scroll.bounds.width, direction: destination > week ? 1 : -1, targetHeight: targetHeight)
            preparation.prepare(source: week, arrival: destination)
        }
        // Commit the release position, then move on the first display callback.
        // Starting a SwiftUI animation there would wait for a second handoff.
        let link = CADisplayLink(target: self, selector: #selector(advanceFrame(_:)))
        let preferred = Float(scroll.window?.screen.maximumFramesPerSecond ?? 60)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, preferred), maximum: preferred, preferred: preferred)
        displayLink = link; link.add(to: .main, forMode: .common)
    }
    @objc private func advanceFrame(_ link: CADisplayLink) {
        guard let value = transition else { adjustHeight(link); return }
        let startedAt = slideStartedAt ?? link.timestamp
        slideStartedAt = startedAt
        let duration = reduceMotion ? 0.15 : 0.25
        let elapsed = min(1, max(0, (link.targetTimestamp - startedAt) / duration))
        let progress = CGFloat(elapsed + elapsed * (1 - elapsed) / 2)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { transition?.slideProgress = progress }
        if elapsed == 1 {
            slideStartedAt = nil
            settle(id: value.id)
        }
    }
    private func settle(id: UUID) {
        guard let value = transition, value.id == id else { return }
        guard let initialHeight = reservedHeight else { cancel(); return }
        if !reduceMotion, abs(initialHeight - value.targetHeight) >= 1 {
            // Keep the page window and display link through the handoff.
            // Rebuilding them here would add work to the first height frame.
            heightAdjustment = (nil, initialHeight, value.targetHeight)
        }
        promote(value)
        defer { scheduleQueuedMove() }
        if heightAdjustment == nil { finishHeight() }
    }
    private func adjustHeight(_ link: CADisplayLink) {
        guard let adjustment = heightAdjustment else { stopDisplayLink(); return }
        // Wait for the first height display callback to start the 0.2-second
        // motion, so a late landing frame cannot skip initial row heights.
        let startedAt = adjustment.startedAt ?? link.timestamp
        heightAdjustment?.startedAt = startedAt
        let progress = min(1, max(0, (link.targetTimestamp - startedAt) / 0.2))
        if progress == 1 { finishHeight(); return }
        let fraction = CGFloat(progress * progress * (3 - 2 * progress))
        let height = adjustment.initialHeight + (adjustment.targetHeight - adjustment.initialHeight) * fraction
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { reservedHeight = height }
    }
    private func stopDisplayLink() {
        displayLink?.invalidate(); displayLink = nil
        slideStartedAt = nil
        heightAdjustment = nil
    }
    private func promote(_ value: Transition) {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            selection = value.destination
            arrive?(value.source, value.destination)
            transition = nil
            heldScroll?.isScrollEnabled = true
            heldScroll = nil
        }
    }
    private func finishHeight(reserving height: CGFloat? = nil) {
        stopDisplayLink()
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            // A continuing move replaces the window synchronously in begin.
            if height == nil { preparation.reset() }
            reservedHeight = height
        }
    }
    func complete() {
        invalidateInput()
        if let transition { promote(transition) }
        if reservedHeight != nil { finishHeight() }
    }
    func cancel() {
        invalidateInput()
        stopDisplayLink()
        heldScroll?.isScrollEnabled = true
        heldScroll = nil
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { transition = nil; preparation.reset(); reservedHeight = nil }
    }
    private func invalidateInput() {
        inputGeneration = UUID()
        trackingTransitionTouch = false
        transitionTouchWeek = nil
        releases.cancel()
        deferredReleases.cancel()
        clearUnusedPreparation()
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
        private var inputGeneration: UUID?
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
            if let scroll, let week { progress?.motion.register(scroll, week: week, probe: self) }
            if let scroll, scroll.accessibilityElementsHidden == isDisplayed {
                scroll.accessibilityElementsHidden = !isDisplayed
            }
        }
        func detach() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(pan(_:)))
            scroll?.accessibilityElementsHidden = false
            scroll = nil; pull = nil; inputGeneration = nil
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
        func inputFrameInWindow() -> CGRect? {
            guard let scroll, let window else { return nil }
            return scroll.convert(visibleRect(of: scroll), to: window)
        }
        func showPull(_ distance: CGFloat) {
            guard let scroll, let week, let progress, let window else { return }
            let viewport = visibleRect(of: scroll).offsetBy(dx: -scroll.bounds.minX, dy: -scroll.bounds.minY)
            let headerBottom = convert(CGPoint.zero, to: scroll).y - scroll.bounds.minY
            let bodyTop = min(viewport.maxY, max(viewport.minY, headerBottom))
            let body = CGRect(x: viewport.minX, y: bodyTop, width: viewport.width, height: viewport.maxY - bodyTop)
            let visible = body.height >= 70 ? body : viewport
            guard !visible.isEmpty else { return }
            let windowVisible = scroll.convert(visible.offsetBy(dx: scroll.bounds.minX, dy: scroll.bounds.minY), to: window)
            let center = WeekEdgePull.badgeCenter(visible: visible, headerHeight: headerBottom)
            let canMove = progress.motion.canMove(from: week, by: distance > 0 ? -7 : 7)
            progress.update(distance: canMove ? distance : 0, visible: windowVisible,
                center: windowVisible.minY + center - visible.minY)
        }
        @objc private func pan(_ pan: UIPanGestureRecognizer) {
            guard let scroll, let week, let progress else { return }
            let motion = progress.motion
            let translation = pan.translation(in: scroll)
            switch pan.state {
            case .began:
                guard motion.canStartInPage(week) else { return }
                inputGeneration = motion.inputGeneration
                let inset = scroll.adjustedContentInset
                pull = WeekEdgePull(velocity: pan.velocity(in: scroll), offset: scroll.contentOffset.x + inset.left,
                    scrollRange: scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width)
            case .changed:
                guard inputGeneration == motion.inputGeneration, let pull else { return }
                let distance = pull.distance(for: translation)
                motion.prepareBeyondPull(from: week, distance: distance)
                showPull(distance)
            case .ended:
                guard inputGeneration == motion.inputGeneration else { return }
                let distance = pull?.distance(for: translation) ?? 0
                pull = nil; inputGeneration = nil
                progress.update(distance: 0, visible: .zero, center: 0)
                motion.release(from: week, distance: distance)
            case .failed, .cancelled:
                guard inputGeneration == motion.inputGeneration else { return }
                pull = nil; inputGeneration = nil
                progress.update(distance: 0, visible: .zero, center: 0)
                motion.clearUnusedPreparation()
            default: break
            }
        }
    }
}

// A touch's native target cannot change halfway through a page swap. Observe
// the contacts that start during that swap without taking over the window's
// gesture recognizers. Settled pages still use their own UIScrollView pans.
private struct WeekTransitionPullObserver: UIViewRepresentable {
    let pull: WeekPullProgress

    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.isUserInteractionEnabled = false
        return probe
    }
    func updateUIView(_ probe: Probe, context: Context) { probe.progress = pull }
    static func dismantleUIView(_ probe: Probe, coordinator: ()) { probe.detach() }

    final class Probe: UIView {
        private struct Contact {
            let origin: CGPoint
            let generation: UUID
            var week: SchoolDate?
            var start: WeekHorizontalPosition?
            var isHorizontal: Bool?
            var translation: CGPoint = .zero
        }

        weak var progress: WeekPullProgress?
        private weak var observingWindow: UIWindow?
        private var contact: Contact?
        private lazy var observer = TouchObserver(
            began: { [weak self] in self?.beginContact(at: $0) ?? false },
            moved: { [weak self] in self?.trackContact(at: $0) },
            ended: { [weak self] in self?.endContact(at: $0) },
            cancelled: { [weak self] in self?.cancelContact() })

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window !== observingWindow else { return }
            detach()
            observingWindow = window
            window?.addGestureRecognizer(observer)
        }
        func detach() {
            cancelContact()
            observingWindow?.removeGestureRecognizer(observer)
            observingWindow = nil
        }

        private func beginContact(at point: CGPoint) -> Bool {
            guard let progress, let window, convert(bounds, to: window).contains(point),
                  let selected = progress.motion.selection else { return false }
            let motion = progress.motion
            let incoming = motion.transition?.destination
            guard !motion.canStartInPage(selected), !motion.trackingTransitionTouch,
                  motion.gridContains(point, on: selected) ||
                  incoming.map({ motion.gridContains(point, on: $0) }) == true else { return false }
            // A prior unmeasured release may still determine this contact's
            // logical week. Keep the original physical origin in that case.
            let week = motion.hasDeferredReleases ? nil : motion.nextInputWeek
            let start = week.flatMap { motion.startingPosition(on: $0) }
            contact = Contact(origin: point, generation: motion.inputGeneration, week: week, start: start)
            motion.setTransitionTouch(active: true, week: week)
            return true
        }

        private func trackContact(at point: CGPoint) {
            guard var contact, let motion = progress?.motion, motion.inputGeneration == contact.generation else { return }
            let translation = CGPoint(x: point.x - contact.origin.x, y: point.y - contact.origin.y)
            contact.translation = translation
            if contact.isHorizontal == nil, max(abs(translation.x), abs(translation.y)) >= 8 {
                contact.isHorizontal = abs(translation.x) > abs(translation.y)
            }
            if contact.week == nil, !motion.hasDeferredReleases {
                contact.week = motion.nextInputWeek
                motion.setTransitionTouch(active: true, week: contact.week)
            }
            if contact.start == nil, let week = contact.week { contact.start = motion.startingPosition(on: week) }
            self.contact = contact
            guard contact.isHorizontal == true, let week = contact.week,
                  let start = contact.start, let scroll = motion.scroll(for: week) else { return }
            let distance = motion.track(translation, from: start, on: scroll)
            if motion.selection == week, motion.transition == nil {
                motion.prepareBeyondPull(from: week, distance: distance)
                motion.showPull(distance, on: week)
            }
        }

        private func endContact(at point: CGPoint) {
            trackContact(at: point)
            guard let ended = contact, let progress, ended.generation == progress.motion.inputGeneration,
                  ended.isHorizontal == true else { cancelContact(); return }
            contact = nil
            progress.motion.setTransitionTouch(active: false, week: nil)
            progress.update(distance: 0, visible: .zero, center: 0)
            progress.motion.releaseEarly(.init(week: ended.week, start: ended.start, translation: ended.translation))
        }

        private func cancelContact() {
            guard let contact else { return }
            self.contact = nil
            guard let progress, contact.generation == progress.motion.inputGeneration else { return }
            progress.motion.setTransitionTouch(active: false, week: nil)
            progress.motion.clearUnusedPreparation()
            progress.update(distance: 0, visible: .zero, center: 0)
        }
    }

    final class TouchObserver: UIGestureRecognizer {
        private let began: (CGPoint) -> Bool
        private let moved: (CGPoint) -> Void
        private let ended: (CGPoint) -> Void
        private let cancelled: () -> Void
        private weak var touch: UITouch?

        init(began: @escaping (CGPoint) -> Bool, moved: @escaping (CGPoint) -> Void,
             ended: @escaping (CGPoint) -> Void, cancelled: @escaping () -> Void) {
            self.began = began; self.moved = moved; self.ended = ended; self.cancelled = cancelled
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard touch == nil, touches.count == 1, let first = touches.first, began(first.location(in: view)) else {
                fail(); return
            }
            touch = first
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch, touches.contains(touch) { moved(touch.location(in: view)) }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch, touches.contains(touch) else { return }
            self.touch = nil
            ended(touch.location(in: view))
            state = .failed
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { fail() }
        override func reset() {
            if touch != nil { touch = nil; cancelled() }
            super.reset()
        }
        private func fail() {
            if touch != nil { touch = nil; cancelled() }
            state = .failed
        }
    }
}
