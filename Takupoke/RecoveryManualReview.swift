import Foundation

/// Comparison uses complete slot identities and literal lesson multisets. It
/// never aligns parallel lessons by position or infers missing previous cells.
enum RecoveryManualComparison {
    struct Slot: Hashable, Comparable, Sendable {
        let className: String
        let day: String
        let period: Int
        static func < (a:Self,b:Self) -> Bool {
            (a.className,a.day,a.period) < (b.className,b.day,b.period)
        }
    }
    struct Scope: Equatable, Sendable {
        let kind: String
        let schoolYear: Int
        let term: String?
        let classes: [String]
        let days: [String]
        let slots: [Slot]
    }
    struct Lesson: Equatable, Sendable {
        let subject: String
        let teacher: String
        let room: String
        let spanStart: Int
        let spanEnd: Int
        let time: String?
        private var literal: Data {
            // Length framing preserves whitespace, Unicode bytes and nil.
            var output=Data()
            for value in [Optional(subject),Optional(teacher),Optional(room),Optional(String(spanStart)),Optional(String(spanEnd)),time] {
                if let value { output.append(Data("\(value.utf8.count):".utf8));output.append(Data(value.utf8)) }
                else { output.append(Data("-:".utf8)) }
            }
            return output
        }
        static func == (a:Self,b:Self) -> Bool { a.literal == b.literal }
        fileprivate static func < (a:Self,b:Self) -> Bool { a.literal.lexicographicallyPrecedes(b.literal) }
    }
    struct Snapshot: Sendable {
        let scope: Scope
        // An explicit empty array proves a blank cell; a missing key does not.
        let entries: [Slot:[Lesson]]
        var complete: Bool {
            !scope.slots.isEmpty && Set(scope.slots).count == scope.slots.count &&
                Set(entries.keys) == Set(scope.slots) &&
                Set(scope.classes).count == scope.classes.count && Set(scope.days).count == scope.days.count &&
                Set(scope.slots.map(\.className)) == Set(scope.classes) && Set(scope.slots.map(\.day)) == Set(scope.days)
        }
    }
    struct Change: Identifiable, Sendable {
        let slot: Slot
        let before: [Lesson]
        let after: [Lesson]
        var id: Slot { slot }
    }
    struct Result: Sendable {
        let available: Bool
        let changes: [Change]
    }
    static func compare(_ current:Snapshot,previous:Snapshot?) -> Result {
        guard let previous,current.complete,previous.complete,
              current.scope.kind == previous.scope.kind,
              current.scope.schoolYear == previous.scope.schoolYear,current.scope.term == previous.scope.term,
              Set(current.scope.classes) == Set(previous.scope.classes),Set(current.scope.days) == Set(previous.scope.days),
              Set(current.scope.slots) == Set(previous.scope.slots) else { return Result(available:false,changes:[]) }
        let changes=current.scope.slots.sorted().compactMap { slot -> Change? in
            let before=previous.entries[slot]!.sorted { $0 < $1 },after=current.entries[slot]!.sorted { $0 < $1 }
            return before == after ? nil : Change(slot:slot,before:before,after:after)
        }
        return Result(available:true,changes:changes)
    }
}

/// Pixel bounds for display only. No OCR or role proof is created here.
enum RecoveryManualImageGeometry {
    struct Bounds: Equatable { let x:Double;let y:Double;let width:Double;let height:Double }
    private static func valid(_ bounds:Bounds) -> Bool {
        let right:Double=bounds.x+bounds.width,bottom:Double=bounds.y+bounds.height
        let values:[Double]=[bounds.x,bounds.y,bounds.width,bounds.height,right,bottom]
        return values.allSatisfy(\.isFinite) && bounds.x>=0 && bounds.y>=0 && bounds.width>0 && bounds.height>0
    }
    static func normalizedHighlight(container:Bounds,target:Bounds) -> Bounds? {
        guard valid(container),valid(target),
              target.x >= container.x,target.y >= container.y,
              target.x+target.width <= container.x+container.width,target.y+target.height <= container.y+container.height else { return nil }
        return Bounds(x:(target.x-container.x)/container.width,y:(target.y-container.y)/container.height,
                      width:target.width/container.width,height:target.height/container.height)
    }
}
