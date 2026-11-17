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
        let bounds = weekBounds
        let previous = weekStart.addingDays(-7).flatMap { bounds.contains($0) ? $0 : nil }
        let next = weekStart.addingDays(7).flatMap { bounds.contains($0) ? $0 : nil }
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
            .background(WeekPullObserver(headerHeight: dayHeaderHeight + gridSpacing, ready: { scroll in
                if let slide = weekSlide, slide.destination == weekStart {
                    weekPull.canvas?.mountIncoming(scroll, slide: slide)
                }
            }) { distance, center in
                guard weekSlide == nil else { return }
                let allowed = distance > 0 ? previous != nil : next != nil
                weekPull.update(distance: allowed ? distance : 0, center: center)
            } release: { distance, scroll, visible in
                weekPull.update(distance: 0, center: 0)
                let days = WeekEdgePull.weekOffset(onRelease: distance, previous: previous != nil, next: next != nil)
                guard weekSlide == nil, days != 0, let target = weekStart.addingDays(days) else { return }
                let slide = WeekGridSlide(scroll: scroll, visible: visible, days: days, destination: target)
                if let slide { weekPull.canvas?.freeze(slide) }
                weekSlide = slide
                moveWeek(days)
            })
        }
        .scrollBounceBehavior(.always, axes: .horizontal)
        .id(weekStart)
        .overlay {
            WeekPullOverlay(pull: weekPull, previous: previous, next: next, accent: weekControlColor)
                .allowsHitTesting(false)
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
        .modifier(WeekGridPresentation(pull: weekPull, slide: weekSlide, week: weekStart) { id in
            if weekSlide?.id == id { weekSlide = nil }
        })
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

// Only the overlay subscribes to progress. Dragging leaves the timetable
// grid, change list and source matching outside the per-frame update.
final class WeekPullProgress: ObservableObject {
    fileprivate weak var canvas: WeekSlideCanvas?
    @Published private(set) var distance: CGFloat = 0
    private(set) var center: CGFloat = 0

    func update(distance: CGFloat, center: CGFloat) {
        self.center = center
        if self.distance != distance { self.distance = distance }
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
            GeometryReader { proxy in
                WeekPullBadge(previous: distance > 0, ready: progress == 1, date: destination,
                              progress: progress, accent: accent)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: distance > 0 ? .leading : .trailing)
                    .position(x: proxy.size.width / 2, y: pull.center)
            }
        }
    }
}

private struct WeekPullBadge: View {
    let previous: Bool
    let ready: Bool
    let date: SchoolDate
    let progress: CGFloat
    let accent: WeekControlAccent
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.3), lineWidth: 2)
                Circle().trim(from: 0, to: progress).stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: previous ? "chevron.left" : "chevron.right")
                    .foregroundStyle(accent)
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
    let headerHeight: CGFloat
    let ready: (UIScrollView) -> Void
    let update: (CGFloat, CGFloat) -> Void
    let release: (CGFloat, UIScrollView, CGRect) -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: Probe, context: Context) {
        uiView.headerHeight = headerHeight
        uiView.ready = ready
        uiView.reportScroll()
        uiView.update = update
        uiView.release = release
    }
    static func dismantleUIView(_ uiView: Probe, coordinator: ()) { uiView.detach() }

    final class Probe: UIView {
        var headerHeight: CGFloat = 0
        var ready: ((UIScrollView) -> Void)?
        func reportScroll() { if let scroll { ready?(scroll) } }
        var update: ((CGFloat, CGFloat) -> Void)?
        var release: ((CGFloat, UIScrollView, CGRect) -> Void)?
        private var badgeCenterY: CGFloat = 0
        private weak var scroll: UIScrollView?
        private var pull: WeekEdgePull?

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
            reportScroll()
        }

        func detach() {
            scroll?.panGestureRecognizer.removeTarget(self, action: #selector(pan(_:)))
            scroll = nil
            pull = nil
        }

        // Work in the horizontal scroll view’s bounds coordinates (including its contentOffset).
        // The enclosing List may be scrolled several periods down and the tab bar can float over it.
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
                        if top > rect.minY && top < rect.maxY {
                            rect.size.height = top - rect.minY
                        }
                    }
                }
                responder = current.next
            }
            return rect.intersection(scroll.bounds)
        }

        @objc private func pan(_ pan: UIPanGestureRecognizer) {
            guard let scroll else { return }
            let translation = pan.translation(in: scroll)
            switch pan.state {
            case .began:
                let inset = scroll.adjustedContentInset
                pull = WeekEdgePull(velocity: pan.velocity(in: scroll), offset: scroll.contentOffset.x + inset.left,
                                    scrollRange: scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width)
                let visible = visibleRect(of: scroll)
                guard !visible.isEmpty else { pull = nil; return }
                badgeCenterY = WeekEdgePull.badgeCenter(visible: visible.offsetBy(dx: -scroll.bounds.minX, dy: -scroll.bounds.minY),
                                                  headerHeight: headerHeight)
            case .changed:
                if let pull { update?(pull.distance(for: translation), badgeCenterY) }
            case .ended:
                if let pull { release?(pull.distance(for: translation), scroll, visibleRect(of: scroll)) }
                pull = nil
            case .failed, .cancelled:
                pull = nil
                update?(0, badgeCenterY)
            default: break
            }
        }
    }
}

// Capture only the outgoing pixels that are on screen, before the native scroll view starts bouncing back.
@MainActor
final class WeekGridSlide: Identifiable {
    let id = UUID()
    let destination: SchoolDate
    let height: CGFloat
    let incomingOffset: CGFloat
    let snapshot: UIView
    let rect: CGRect

    init?(scroll: UIScrollView, visible: CGRect, days: Int, destination: SchoolDate) {
        guard !visible.isEmpty, scroll.bounds.width > 0 else { return nil }
        let inset = scroll.adjustedContentInset
        self.destination = destination
        height = scroll.bounds.height
        incomingOffset = WeekEdgePull.incomingOffset(viewportWidth: scroll.bounds.width,
            offset: scroll.contentOffset.x + inset.left,
            scrollRange: scroll.contentSize.width + inset.left + inset.right - scroll.bounds.width, days: days)
        rect = visible.offsetBy(dx: -scroll.bounds.minX, dy: -scroll.bounds.minY)
        snapshot = Self.capture(scroll, rect: visible, updated: false)
    }

    static func capture(_ scroll: UIScrollView, rect: CGRect, updated: Bool) -> UIView {
        if let view = scroll.resizableSnapshotView(from: rect, afterScreenUpdates: updated, withCapInsets: .zero) {
            return view
        }
        let image = UIGraphicsImageRenderer(size: rect.size).image { context in
            context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            scroll.layer.render(in: context.cgContext)
        }
        return UIImageView(image: image)
    }
}

private struct WeekGridCurtain: UIViewRepresentable {
    let pull: WeekPullProgress
    let slide: WeekGridSlide?
    let reduceMotion: Bool
    let arrived: (UUID) -> Void

    func makeUIView(context: Context) -> WeekSlideCanvas {
        let canvas = WeekSlideCanvas()
        pull.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: WeekSlideCanvas, context: Context) {
        pull.canvas = canvas
        canvas.reduceMotion = reduceMotion
        canvas.arrived = arrived
        if let slide {
            canvas.freeze(slide)
        } else {
            canvas.clear()
        }
    }

    static func dismantleUIView(_ canvas: WeekSlideCanvas, coordinator: ()) { canvas.clear() }
}

// This host survives replacement of the horizontal scroll view. Its layers have explicit start
// and end values so a SwiftUI layout pass cannot coalesce the release position with the destination.
fileprivate final class WeekSlideCanvas: UIView {
    var reduceMotion = false
    var arrived: ((UUID) -> Void)?
    private var slide: WeekGridSlide?
    private weak var incoming: UIScrollView?
    private let outgoingPage = UIView()
    private let incomingPage = UIView()
    private var scheduled: CADisplayLink?
    private var started = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isHidden = true
        clipsToBounds = true
        backgroundColor = .secondarySystemGroupedBackground
        outgoingPage.backgroundColor = .secondarySystemGroupedBackground
        incomingPage.backgroundColor = .secondarySystemGroupedBackground
        addSubview(outgoingPage)
        addSubview(incomingPage)
    }

    required init?(coder: NSCoder) { return nil }

    func freeze(_ next: WeekGridSlide) {
        guard slide !== next else { return }
        clear()
        slide = next
        outgoingPage.frame = bounds
        outgoingPage.addSubview(next.snapshot)
        next.snapshot.frame = next.rect
        incomingPage.isHidden = true
        isHidden = false
    }

    func mountIncoming(_ scroll: UIScrollView, slide next: WeekGridSlide) {
        // The observer reports the rendered week's identity, including if UIKit reuses its scroll view.
        freeze(next)
        incoming = scroll
        scheduleIfReady()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { scheduled?.invalidate(); scheduled = nil } else { scheduleIfReady() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleIfReady()
    }

    private func scheduleIfReady() {
        guard slide != nil, incoming != nil, window != nil, !bounds.isEmpty,
              !started, scheduled == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(startOnDisplay))
        scheduled = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func startOnDisplay() {
        guard let slide, let incoming, let window, incoming.window === window,
              !incoming.bounds.isEmpty, !bounds.isEmpty else { return }
        scheduled?.invalidate()
        scheduled = nil
        started = true

        // Only the part currently on screen is needed. Rows outside the new short week
        // show the usual row background until the vertical height settles.
        incoming.layoutIfNeeded()
        let local = slide.rect.intersection(CGRect(origin: .zero, size: incoming.bounds.size))
        if !local.isEmpty {
            let visible = local.offsetBy(dx: incoming.bounds.minX, dy: incoming.bounds.minY)
            let snapshot = WeekGridSlide.capture(incoming, rect: visible, updated: true)
            incomingPage.addSubview(snapshot)
            snapshot.frame = local
        }
        outgoingPage.frame = bounds
        incomingPage.frame = bounds
        incomingPage.isHidden = false

        let duration = reduceMotion ? 0.15 : 0.25
        let start = CACurrentMediaTime()
        let travel = slide.incomingOffset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.slide === slide else { return }
                self.isHidden = true
                self.arrived?(slide.id)
            }
        }
        if reduceMotion {
            animate(outgoingPage.layer, key: "opacity", from: 1, to: 0, duration: duration, start: start)
            animate(incomingPage.layer, key: "opacity", from: 0, to: 1, duration: duration, start: start)
        } else {
            let x = bounds.midX
            animate(outgoingPage.layer, key: "position.x", from: x, to: x - travel, duration: duration, start: start)
            animate(incomingPage.layer, key: "position.x", from: x + travel, to: x, duration: duration, start: start)
        }
        CATransaction.commit()
    }

    private func animate(_ layer: CALayer, key: String, from: CGFloat, to: CGFloat,
                         duration: CFTimeInterval, start: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = from
        animation.toValue = to
        animation.beginTime = layer.convertTime(start, from: nil)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .backwards
        layer.setValue(to, forKeyPath: key)
        layer.add(animation, forKey: "week-handoff")
    }

    func clear() {
        guard slide != nil || scheduled != nil else { return }
        scheduled?.invalidate()
        scheduled = nil
        slide = nil
        incoming = nil
        started = false
        isHidden = true
        for page in [outgoingPage, incomingPage] {
            page.layer.removeAnimation(forKey: "week-handoff")
            page.alpha = 1
            page.subviews.forEach { $0.removeFromSuperview() }
        }
    }
}

private struct WeekGridPresentation: ViewModifier {
    let pull: WeekPullProgress
    let slide: WeekGridSlide?
    let week: SchoolDate
    let finish: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var naturalHeight: CGFloat = 0
    @State private var settledHeight: CGFloat?

    init(pull: WeekPullProgress, slide: WeekGridSlide?, week: SchoolDate, finish: @escaping (UUID) -> Void) {
        self.pull = pull
        self.slide = slide
        self.week = week
        self.finish = finish
    }

    func body(content: Content) -> some View {
        let active = slide.flatMap { $0.destination == week ? $0 : nil }
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
            .frame(height: active.map { settledHeight ?? $0.height }, alignment: .top)
            .overlay {
                WeekGridCurtain(pull: pull, slide: active, reduceMotion: reduceMotion) { id in
                    guard let active, active.id == id else { return }
                    if reduceMotion || naturalHeight <= 0 || abs(active.height - naturalHeight) < 1 {
                        finish(id)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2), completionCriteria: .removed) {
                            settledHeight = naturalHeight
                        } completion: { finish(id) }
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
            .clipped()
            .allowsHitTesting(active == nil)
            .onChange(of: active?.id) { _, id in
                if id == nil {
                    settledHeight = nil
                    if let slide { finish(slide.id) }
                }
            }
            .task(id: active?.id) {
                // A List can recycle a row before its incoming scroll view is mounted.
                guard let active else { return }
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                finish(active.id)
            }
            .onDisappear {
                settledHeight = nil
                if let slide { finish(slide.id) }
            }
    }
}
