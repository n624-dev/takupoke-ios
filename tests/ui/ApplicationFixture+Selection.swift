import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

@MainActor
enum SimulatorSelectionFixture {
    private static var busyGate: DispatchSemaphore?
    static func finishBusy() {
        guard let busyGate else { return }
        UserDefaults.standard.set(true, forKey: "fixture.selectionBusyReleased")
        busyGate.signal()
    }
    static var hasBusyGate: Bool { busyGate != nil }
    static func recordTrace(_ event: String) {
        let defaults = UserDefaults.standard
        let previous = defaults.stringArray(forKey: "fixture.selectionEvents") ?? []
        let events = Array((previous + [event]).suffix(12))
        defaults.set(events, forKey: "fixture.selectionEvents")
        defaults.set(events.joined(separator: " | "), forKey: "fixture.selectionTrace")
        print(event)
    }
    static var day: SchoolDate {
        let actual = SchoolDate.today()
        let period = SchoolDataPeriod.current()
        let monday = actual.displayWeekStart
        let half = (4...9).contains(monday.month) ? 1 : 2
        return monday.schoolYear == period.schoolYear && half == period.half
            ? monday : monday.addingDays(monday < actual ? 7 : -7)!
    }
    static func mutate(_ mode: String) {
        let model = ApplicationData.shared.materials
        guard !model.busy else { return }
        let gate = mode == "busy" ? DispatchSemaphore(value: 0) : nil
        busyGate = gate
        if gate != nil {
            UserDefaults.standard.set(false, forKey: "fixture.selectionBusyReleased")
            UserDefaults.standard.set("pending", forKey: "fixture.selectionBusyCompleted")
        }
        let raw: Data? =
            mode == "source"
            ? UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200)).pdfData { context in
                context.beginPage()
                ("架空の更新原本 \(UUID().uuidString)" as NSString).draw(
                    at: CGPoint(x: 10, y: 20), withAttributes: nil)
            } : nil
        model.perform(
            success: nil,
            completion: { success in
                if gate != nil {
                    UserDefaults.standard.set(
                        success ? "success" : "failure", forKey: "fixture.selectionBusyCompleted")
                }
                busyGate = nil
            }
        ) { worker, control in
            try control.check()
            guard let library = worker.library else { throw MaterialError.unavailable }
            if let gate {
                guard gate.wait(timeout: .now() + 60) == .success else { throw MaterialError.unavailable }
                try control.check()
                return
            }
            if let raw {
                let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
                let staging = library.newStagingURL()
                try raw.write(to: staging)
                try library.commit(
                    staged: staging, kind: .timetable, source: .init(grant: nil, childName: nil),
                    originalName: "fictional-updated-selection.pdf", byteCount: raw.count, digest: digest,
                    modifiedAt: nil)
            } else {
                guard var analysis = library.state.pdfAnalyses?[MaterialKind.timetable.rawValue] else {
                    throw MaterialError.unavailable
                }
                analysis.parsedAt = Date().addingTimeInterval(1)
                for index in analysis.lessons.indices {
                    let names = analysis.lessons[index].names
                    analysis.lessons[index].names = TimetableLessonNames(
                        subject: names.subject + "更新",
                        teacher: names.teacher, room: names.room, subjectFullName: names.subjectFullName,
                        teacherFullName: names.teacherFullName, roomFullName: names.roomFullName)
                }
                try library.savePDFAnalysis(analysis)
            }
            try control.check()
        }
    }
}
struct FixtureSelectionMutationControls: View {
    @ObservedObject private var model = ApplicationData.shared.materials
    @AppStorage("fixture.selectionBusyReleased") private var released = false
    @AppStorage("fixture.selectionBusyCompleted") private var completed = "none"
    var body: some View {
        VStack {
            Text(model.busy ? "架空処理中" : "架空待機中").accessibilityIdentifier("fixture-selection-busy")
            Text("released=\(released);completion=\(completed)")
                .accessibilityIdentifier("fixture-selection-busy-outcome")
            if model.busy && SimulatorSelectionFixture.hasBusyGate {
                Button("架空処理を終了") { SimulatorSelectionFixture.finishBusy() }
            }
            HStack {
                Button("架空処理のみ") { SimulatorSelectionFixture.mutate("busy") }
                Button("架空正式更新") { SimulatorSelectionFixture.mutate("formal") }
                Button("架空原本更新") { SimulatorSelectionFixture.mutate("source") }
            }.disabled(model.busy)
        }.font(.caption).padding(8).background(.regularMaterial)
    }
}
struct FixtureSelectionProbe: View {
    @ObservedObject private var model = ApplicationData.shared.materials
    @AppStorage("fixture.selectionTrace") private var trace = ""
    var body: some View {
        VStack(spacing: 0) {
            Text(
                (model.state.record(for: .timetable)?.digest ?? "none") + ":"
                    + (model.state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.lessons.first?.names.subject
                        ?? "none")
            )
            .accessibilityIdentifier("fixture-selection-data")
            Text(trace).lineLimit(1).accessibilityIdentifier("fixture-selection-trace")
        }.font(.caption2).allowsHitTesting(false)
    }
}
