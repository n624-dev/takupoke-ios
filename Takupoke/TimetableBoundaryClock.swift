import Foundation

/// Publish only a changed school date or set of active cards. The view reads
/// a fresh Date on other model redraws instead of retaining the last timer tick.
@MainActor
final class TimetableBoundaryClock {
    struct Interval: Equatable {
        let id:String
        let start:Date
        let end:Date
    }
    typealias Action = @MainActor () -> Void
    typealias Scheduler = @MainActor (Date,@escaping Action) -> Action
    private struct Signature:Equatable { let day:SchoolDate; let active:Set<String> }
    private let now:@MainActor () -> Date
    private let schedule:Scheduler
    private let changed:Action
    private var intervals = [Interval]()
    private var signature:Signature?
    private var cancellation:Action?
    private var generation = UUID()
    private var running = false
    var currentDate:Date { now() }

    init(now:@escaping @MainActor () -> Date,schedule:@escaping Scheduler,changed:@escaping Action) {
        self.now = now; self.schedule = schedule; self.changed = changed
    }
    private func snapshot(at date:Date) -> Signature {
        Signature(day:TimetableDaySchedule.schoolDay(at:date),active:Set(intervals.compactMap {
            $0.start <= date && date < $0.end ? $0.id:nil
        }))
    }
    func configure(_ values:[Interval]) {
        intervals = values.filter { $0.start.timeIntervalSinceReferenceDate.isFinite &&
            $0.end.timeIntervalSinceReferenceDate.isFinite && $0.start < $0.end }
        let date = now()
        signature = snapshot(at:date) // The caller's model change already redraws with a fresh Date.
        reschedule(at:date)
    }
    func start() { running = true; refresh() }
    func stop() {
        running = false; generation = UUID(); cancellation?(); cancellation = nil
    }
    func clear() { stop(); intervals.removeAll(keepingCapacity:false); signature = nil }
    func refresh() {
        guard running else { return }
        let date = now()
        let current = snapshot(at:date)
        let differs = signature.map { $0 != current } ?? false
        signature = current
        if differs { changed() }
        reschedule(at:date)
    }
    private func reschedule(at date:Date) {
        generation = UUID(); cancellation?(); cancellation = nil
        guard running else { return }
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Asia/Tokyo")!
        guard var next = calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:date)) else { return }
        for interval in intervals {
            if date < interval.start { next = min(next,interval.start) }
            if date < interval.end { next = min(next,interval.end) }
        }
        let token = generation
        cancellation = schedule(next) { [weak self] in
            guard let self, running, generation == token else { return }
            cancellation = nil; refresh()
        }
    }
}
