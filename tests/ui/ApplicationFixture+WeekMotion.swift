import SwiftUI
import UIKit
import CryptoKit

// This observer is compiled into the fictional UI fixture only. It never moves
// a page, changes a gesture, or returns an expected animation position.
@MainActor
final class FixtureWeekMotionRecorder: NSObject, ObservableObject {
    static let shared = FixtureWeekMotionRecorder()
    private final class Reference {
        weak var view: UIView?
        init(_ view: UIView) { self.view = view }
    }
    @Published private(set) var report = "[]"
    private var bodies: [String: Reference] = [:]
    private weak var source: UIView?
    private weak var target: UIView?
    weak var row: UIView?
    private var link: CADisplayLink?
    private var releasedAt: CFTimeInterval = 0
    private var arrivedAt: CFTimeInterval?
    private var finishedAt: CFTimeInterval?
    private var releasePoint: CGPoint?
    private var samples: [[String: Double]] = []
    private var missingFrames: [Double] = []
    private var records: [[String: Any]] = []
    private var fingerDown = false
    private var badge: [String: Any] = [:]
    private var badgeImage: UIImage?
    private var badgeFrame: CGRect?
    private var badgeLink: CADisplayLink?
    private var waitedForBadgeFrame = false
    private var badgeDrawAttempts = 0
    private weak var dragBody: UIView?
    var visible = CGRect.zero
    private var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--week-motion-probe") }

    func register(week: String, body: UIView) {
        guard enabled else { return }
        bodies = bodies.filter { $0.value.view != nil }
        bodies[week] = Reference(body)
    }
    func began(body: UIView) {
        guard enabled else { return }
        cancelBadgeCapture()
        dragBody = body; fingerDown = true
        badge = [:]; badgeImage = nil; badgeFrame = nil
        waitedForBadgeFrame = false; badgeDrawAttempts = 0
    }
    func released(body: UIView) {
        guard enabled else { return }
        releasedAt = CACurrentMediaTime()
        releasePoint = point(body)
        cancelBadgeCapture()
    }
    func cancelBadgeCapture() {
        fingerDown = false
        stopBadgeSampling()
    }
    private func stopBadgeSampling() {
        badgeLink?.invalidate()
        badgeLink = nil
    }
    func begin(source: String, target: String) {
        guard enabled else { return }
        self.source = bodies[source]?.view; self.target = bodies[target]?.view
        samples = []; missingFrames = []; arrivedAt = nil; finishedAt = nil
        link?.invalidate()
        let display = CADisplayLink(target: self, selector: #selector(sample))
        let preferred = Float(self.source?.window?.screen.maximumFramesPerSecond ?? 60)
        display.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, preferred), maximum: preferred, preferred: preferred)
        link = display; display.add(to: .main, forMode: .common)
    }
    func arrived() { if enabled { arrivedAt = CACurrentMediaTime() } }
    func finished() { if enabled { finishedAt = CACurrentMediaTime() } }
    private func point(_ view: UIView?) -> CGPoint? {
        guard let view, let window = view.window else { return nil }
        let layer = view.layer.presentation() ?? view.layer
        let root = window.layer.presentation() ?? window.layer
        return layer.convert(.zero, to: root)
    }
    @objc private func sample() {
        let now = CACurrentMediaTime()
        if let a = point(source), let b = point(target), let row {
            let height = (row.layer.presentation() ?? row.layer).bounds.height
            samples.append(["t": now - releasedAt, "sourceX": a.x, "sourceY": a.y,
                            "targetX": b.x, "targetY": b.y, "rowHeight": height])
        } else {
            missingFrames.append(now - releasedAt)
        }
        if finishedAt.map({ now - $0 >= 0.15 }) == true || now - releasedAt > 1.5 {
            link?.invalidate(); link = nil
            if let bytes = badgeImage?.pngData() {
                let name = "takupoke-week-badge-\(records.count).png"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                do {
                    try bytes.write(to: url, options: .atomic)
                    badge["pngBytes"] = bytes.count
                    badge["pngSHA256"] = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                } catch {
                    print("Week badge image could not be saved: \(error)")
                }
            }
            badgeImage = nil
            var record: [String: Any] = ["arrived": arrivedAt.map { $0 - releasedAt } ?? -1,
                "finished": finishedAt.map { $0 - releasedAt } ?? -1,
                "samples": samples, "missingGeometryFrames": missingFrames, "badge": badge,
                "badgeReadyObserved": badgeFrame != nil, "badgeDrawAttempts": badgeDrawAttempts]
            if let releasePoint {
                record["releaseX"] = Double(releasePoint.x)
                record["releaseY"] = Double(releasePoint.y)
            }
            records.append(record)
            if let bytes = try? JSONSerialization.data(withJSONObject: records, options: [.sortedKeys]),
               let value = String(data: bytes, encoding: .utf8) {
                report = value
                print("TAKUPOKE_WEEK_MOTION " + value)
            }
        }
    }
    func captureBadge(frame: CGRect) {
        guard enabled, fingerDown, badgeImage == nil, badgeDrawAttempts < 2,
              frame.minX.isFinite, frame.minY.isFinite, frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0 else { return }
        badgeFrame = frame
        guard badgeLink == nil else { return }
        let display = CADisplayLink(target: self, selector: #selector(sampleBadge))
        badgeLink = display
        display.add(to: .main, forMode: .common)
    }

    @objc private func sampleBadge() {
        guard fingerDown, let frame = badgeFrame, let window = dragBody?.window else { return }
        // Wait for a display opportunity after SwiftUI reported the ready geometry.
        guard waitedForBadgeFrame else { waitedForBadgeFrame = true; return }
        badgeDrawAttempts += 1
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        var drewWindow = false
        let image = renderer.image { _ in
            drewWindow = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        if badgeDrawAttempts == 2 || drewWindow { stopBadgeSampling() }
        guard drewWindow else { return }
        func rectangle(_ value: CGRect) -> [String: Double] {
            ["x": value.minX, "y": value.minY, "width": value.width, "height": value.height]
        }
        badgeImage = image
        badge = ["frame": rectangle(frame), "visible": rectangle(visible)]
    }
}

struct FixtureWeekRowBounds: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        FixtureWeekMotionRecorder.shared.row = view
    }
}

struct FixtureWeekMotionStatus: View {
    @ObservedObject private var recorder = FixtureWeekMotionRecorder.shared
    var body: some View {
        Text("Week motion").font(.system(size: 1)).foregroundStyle(.clear)
            .frame(width: 1, height: 1).allowsHitTesting(false)
            .accessibilityIdentifier("fixture-week-motion").accessibilityValue(recorder.report)
    }
}

@MainActor
final class FixtureWeekSequenceRecorder: ObservableObject {
    static let shared = FixtureWeekSequenceRecorder()

    private struct Event: Encodable {
        let kind: String
        let week: String?
        let target: String?
        let phase: String?
        let deferred: Bool?
        let time: CFTimeInterval
    }
    private var events: [Event] = []
    @Published private(set) var report = "[]"

    func observe(_ kind: String, week: SchoolDate?, target: SchoolDate? = nil, phase: String? = nil, deferred: Bool? = nil) {
        guard ProcessInfo.processInfo.arguments.contains("--week-sequence-probe") else { return }
        events.append(Event(kind: kind, week: week?.iso8601, target: target?.iso8601,
                            phase: phase, deferred: deferred, time: CACurrentMediaTime()))
        if let data = try? JSONEncoder().encode(events), let value = String(data: data, encoding: .utf8) {
            report = value
            print("TAKUPOKE_WEEK_SEQUENCE " + value)
        }
    }
}

struct FixtureWeekSequenceStatus: View {
    @ObservedObject private var recorder = FixtureWeekSequenceRecorder.shared
    var body: some View {
        Text("Week sequence").font(.system(size: 1)).foregroundStyle(.clear)
            .frame(width: 1, height: 1).allowsHitTesting(false)
            .accessibilityIdentifier("fixture-week-sequence").accessibilityValue(recorder.report)
    }
}

struct FixtureWeekBadgeCapture: ViewModifier {
    private struct Observation: Equatable {
        let ready: Bool
        let frame: CGRect
    }

    let ready: Bool
    func body(content: Content) -> some View {
        let ready = ready
        return content.onGeometryChange(for: Observation.self) { proxy in
            Observation(ready: ready, frame: proxy.frame(in: .global))
        } action: { observation in
            if observation.ready { FixtureWeekMotionRecorder.shared.captureBadge(frame: observation.frame) }
        }
    }
}
