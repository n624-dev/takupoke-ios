import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

enum RecoveryValidator {
    static let schemaVersion = 2
    static let version = 4
    private static func text(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping.components(separatedBy: .whitespacesAndNewlines).joined()
    }
    static let specialClasses = ["1_1", "1_2", "1_3"] + (2...5).flatMap { year in ["CN", "ES", "IT"].map { "\(year)_\($0)" } } + ["AI_1", "AI_2"]
    static let knownClasses = specialClasses + ["1_CN", "1_ES", "1_IT"]
    private static func dayLabels(_ day: String, kind: RecoveryDocumentKind) -> [String] {
        if kind == .timetable { let label = ["1": "月", "2": "火", "3": "水", "4": "木", "5": "金"][day] ?? "?"; return [label, label + "曜", label + "曜日"] }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return [] }
        return [day, "\(parts[0])/\(parts[1])/\(parts[2])", "\(parts[1])/\(parts[2])", "\(parts[1])月\(parts[2])日"]
    }
    private static func classLabels(_ cls: String) -> [String] {
        [cls, cls.replacingOccurrences(of: "_", with: "-"), cls.replacingOccurrences(of: "_", with: ""), cls.hasPrefix("AI_") ? cls.replacingOccurrences(of: "AI_", with: "") + "年" : cls]
    }
    static func validate(_ doc: RecoveryDocument, _ result: RecoveryResult, inputOnly: Bool = false, unresolvedCellIds: Set<String> = []) -> RecoveryValidation {
        let work = RecoveryValidationWork()
        do {
            let index = try RecoverySourceIndex(doc.sources,work:work)
            return try validate(doc,result,inputOnly:inputOnly,unresolvedCellIds:unresolvedCellIds,index:index,work:work)
        } catch { return RecoveryValidation(errors:["validationLimit"]) }
    }
    static func validate(_ doc:RecoveryDocument,_ result:RecoveryResult,inputOnly:Bool = false,unresolvedCellIds:Set<String> = [],check:@escaping () throws -> Void) throws -> RecoveryValidation {
        let work = RecoveryValidationWork(check:check)
        let index = try RecoverySourceIndex(doc.sources,work:work)
        return try validate(doc,result,inputOnly:inputOnly,unresolvedCellIds:unresolvedCellIds,index:index,work:work)
    }
    static func validate(_ doc:RecoveryDocument,_ result:RecoveryResult,inputOnly:Bool = false,unresolvedCellIds:Set<String> = [],index:RecoverySourceIndex,work:RecoveryValidationWork) throws -> RecoveryValidation {
        let result = validation(doc,result,inputOnly:inputOnly,unresolvedCellIds:unresolvedCellIds,index:index,work:work)
        try work.finish()
        return result
    }
    private static func validation(_ doc:RecoveryDocument,_ result:RecoveryResult,inputOnly:Bool,unresolvedCellIds:Set<String>,index:RecoverySourceIndex,work:RecoveryValidationWork) -> RecoveryValidation {
        guard inputOnly || unresolvedCellIds.isEmpty else { return RecoveryValidation(errors:["unresolvedStructure"]) }
        guard (1900...9998).contains(doc.schoolYear), (1...64).contains(doc.classes.count), (1...31).contains(doc.days.count), (1...20000).contains(doc.cells.count), doc.sources.count <= 100000, result.cells.count <= 20000 else { return RecoveryValidation(errors: ["inputLimit"]) }
        var errors = [String]()
        func check(_ ok: Bool, _ code: String) { if work.charge(), !ok && !errors.contains(code) { errors.append(code) } }
        // Bound all source-reference inventories before any flattening/joins. Counts
        // are charged even when the later proof rejects a reference.
        for cell in doc.cells {
            let size = cell.sourceIds.count + cell.slots.count + cell.classHeaderIds.count + cell.dayHeaderIds.count + cell.periodHeaderIds.count
            guard work.charge(size + 1), cell.roleScopes.count <= 12, cell.lessonBindings.count <= 4 else { return RecoveryValidation(errors:["inputLimit"]) }
            for scope in cell.roleScopes { guard work.charge(scope.labelSourceIds.count) else { return RecoveryValidation(errors:["validationLimit"]) } }
            for binding in cell.lessonBindings { guard work.charge(binding.subject.count + binding.teacher.count + binding.room.count) else { return RecoveryValidation(errors:["validationLimit"]) } }
        }
        for values in [doc.dayEvidence,doc.classEvidence,doc.periodEvidence,doc.clockEvidence] {
            for ids in values.values { guard work.charge(ids.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) } }
        }
        guard doc.annotations.count <= 20000, doc.clockBindings.count <= 20000, doc.clockReplicas.count <= 20000 else { return RecoveryValidation(errors:["inputLimit"]) }
        for annotation in doc.annotations { guard work.charge(annotation.sourceIds.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) } }
        for binding in doc.clockBindings.values { guard work.charge(binding.dayHeaderIds.count + binding.periodHeaderIds.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) } }
        for replicas in doc.clockReplicas.values {
            guard work.charge(replicas.count) else { return RecoveryValidation(errors:["validationLimit"]) }
            for binding in replicas { guard work.charge(binding.dayHeaderIds.count + binding.periodHeaderIds.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) } }
        }
        for ids in [doc.yearEvidence,doc.termEvidence,doc.timeEvidence,doc.normalTimeNoteEvidence,doc.commonClockEvidence] {
            guard work.charge(ids.count) else { return RecoveryValidation(errors:["validationLimit"]) }
        }
        for cell in result.cells {
            guard work.charge(), cell.lessons.count <= 4 else { return RecoveryValidation(errors:["inputLimit"]) }
            for lesson in cell.lessons {
                guard [lesson.subject,lesson.teacher,lesson.room].allSatisfy({ $0.value.utf16.count <= 1024 }) else { return RecoveryValidation(errors:["fieldLimit"]) }
                guard work.charge(lesson.subject.evidence.count + lesson.teacher.evidence.count + lesson.room.evidence.count + lesson.dateEvidence.count + lesson.periodEvidence.count) else { return RecoveryValidation(errors:["validationLimit"]) }
            }
        }
        var pageCells = [Int:[RecoveryCell]](), classCells = [String:[RecoveryCell]](), dayCells = [String:[RecoveryCell]](), periodCells = [Int:[RecoveryCell]]()
        for cell in doc.cells {
            guard work.charge(cell.slots.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) }
            pageCells[cell.page,default:[]].append(cell)
            if let slot = cell.slots.first {
                classCells[slot.className,default:[]].append(cell)
                dayCells[slot.day,default:[]].append(cell)
            }
            for period in Set(cell.slots.map(\.period)) { periodCells[period,default:[]].append(cell) }
        }
        check(unresolvedCellIds.isSubset(of:Set(doc.cells.filter { !$0.confirmedEmpty && !$0.sourceIds.isEmpty }.map(\.id))),"unresolvedStructure")
        check([RecoveryDocumentKind.timetable, .exam, .return].contains(doc.kind), "documentKind")
        check(doc.pdfHash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil && result.pdfHash == doc.pdfHash, "sourceHash")
        check(doc.complete && (1...20000).contains(doc.cells.count) && doc.sources.count <= 100000, "incompleteDocument")
        check(doc.structureMetadata == nil || doc.structureMetadata == result.metadata,"structureMetadata")
        check(result.kind == doc.kind && result.schoolYear == doc.schoolYear && result.term == doc.term, "documentIdentity")
        check((1900...9998).contains(doc.schoolYear) && (doc.kind != .timetable || ["前期", "後期"].contains(doc.term ?? "")), "yearTerm")
        check(result.metadata.recoverySchemaVersion == schemaVersion && result.metadata.validatorVersion == version &&
              [result.metadata.provider, result.metadata.modelId, result.metadata.modelVersion, result.metadata.runtimeVersion,
               result.metadata.promptVersion, result.metadata.osVersion, result.metadata.recoveryVersion].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "versions")
        check(!doc.classes.isEmpty && Set(doc.classes).count == doc.classes.count && Set(doc.classes).isSubset(of: Set(RecoveryValidator.knownClasses)) && !doc.days.isEmpty && Set(doc.days).count == doc.days.count, "scope")
        if doc.kind != .timetable { check(Set(doc.classes) == Set(RecoveryValidator.specialClasses) && doc.days.count == 5, "specialScope") }
        let maxPeriod = doc.kind == .exam ? 6 : 8
        var periodIds = [Int:Set<String>]()
        for period in 1...maxPeriod {
            let ids = doc.periodEvidence[String(period),default:[]]
            guard work.charge(ids.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) }
            periodIds[period] = Set(ids)
        }
        func periodMembers(_ ids:[String],period:Int) -> [String] {
            let allowed = periodIds[period,default:[]]
            var matching = [String]()
            for id in ids {
                guard work.charge() else { return [] }
                if allowed.contains(id) { matching.append(id) }
            }
            return matching
        }
        if doc.kind == .timetable { check(doc.days.sorted() == ["1", "2", "3", "4", "5"], "weekdays") }
        else {
            let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
            for day in doc.days {
                let valid = formatter.date(from: day).map { formatter.string(from: $0) == day && day >= "\(doc.schoolYear)-04-01" && day < "\(doc.schoolYear + 1)-04-01" } ?? false
                check(valid, "dates")
            }
        }
        let required = Set(doc.classes.flatMap { cls in doc.days.flatMap { day in (1...maxPeriod).map { RecoverySlot(className: cls, day: day, period: $0) } } })
        check(doc.requiredSlots.count == required.count && Set(doc.requiredSlots) == required, "requiredScope")
        let slots = doc.cells.flatMap(\.slots)
        check(slots.count == required.count && Set(slots) == required, "coverage")
        check(Set(doc.cells.map(\.id)).count == doc.cells.count && Set(doc.sources.map(\.id)).count == doc.sources.count, "duplicateIds")
        let sources = index.byId
        var cells = [String: RecoveredCell](); for cell in result.cells { cells[cell.cellId] = cell }
        check(cells.count == result.cells.count, "duplicateCells")
        check(Set(cells.keys) == Set(doc.cells.map(\.id)), "resultCoverage")
        func original(_ ids:[String]) -> String { index.original(ids,work:work) ?? "" }
        func evidence(_ ids: [String], _ allowed: [String], _ value: String? = nil) -> Bool {
            guard work.charge(ids.count + allowed.count), !ids.isEmpty, Set(ids).count == ids.count else { return false }
            let allowedIds = Set(allowed)
            guard ids.allSatisfy({ allowedIds.contains($0) && sources[$0] != nil }) else { return false }
            guard let value else { return true }
            guard work.charge(value.utf8.count) else { return false }
            return !text(value).isEmpty && text(original(ids)) == text(value)
        }
        let order = index.order
        func ordered(_ ids: [String]) -> Bool { guard work.charge(ids.count) else { return false }; let values = ids.compactMap { order[$0] }; return values.count == ids.count && zip(values, values.dropFirst()).allSatisfy { $0 < $1 } }
        func header(_ ids: [String], _ allowed: [String], _ labels: [String], cell: RecoveryCell? = nil, region: RecoveryHeaderRegion? = nil) -> Bool {
            guard evidence(ids, allowed), ordered(ids) else { return false }
            let joinedMatches = labels.map(text).contains(text(original(ids)))
            guard let cell else { return joinedMatches || ids.allSatisfy { id in sources[id].map { labels.map(text).contains(text($0.text)) } ?? false } }
            guard joinedMatches else { return false }
            guard let region, region.page == cell.page, region.box.valid else { return false }
            let aligned = region.axis == .above ? region.box.y + region.box.height <= cell.box.y && min(region.box.x + region.box.width, cell.box.x + cell.box.width) > max(region.box.x, cell.box.x) : region.box.x + region.box.width <= cell.box.x && min(region.box.y + region.box.height, cell.box.y + cell.box.height) > max(region.box.y, cell.box.y)
            return aligned && ids.allSatisfy { id in sources[id].map { $0.page == region.page && region.box.contains($0.box) } ?? false }
        }
        check(doc.sources.allSatisfy { $0.page > 0 && $0.box.valid && $0.text.utf16.count <= 4096 }, "sourceLimit")
        check(evidence(doc.yearEvidence, doc.yearEvidence), "yearEvidence")
        check(header(doc.yearEvidence, doc.yearEvidence, ["\(doc.schoolYear)年度", "令和\(doc.schoolYear - 2018)年度"]), "yearEvidenceText")
        if let term = doc.term { check(header(doc.termEvidence, doc.termEvidence, [term]), "termEvidence") }
        for cls in doc.classes { check(doc.classEvidence[cls].map { evidence($0, $0) } ?? false, "classEvidence") }
        for day in doc.days { check(doc.dayEvidence[day].map { header($0, $0, dayLabels(day, kind: doc.kind)) } ?? false, "dayEvidence") }
        for p in 1...maxPeriod { check(doc.periodEvidence[String(p)].map { header($0, $0, [String(p), "\(p)限", "\(p)時限", "\(p)時限目", "第\(p)時限"]) } ?? false, "periodEvidence") }
        let normalTimes = ["08:50〜09:35", "09:35〜10:20", "10:30〜11:15", "11:15〜12:00", "12:50〜13:35", "13:35〜14:20", "14:30〜15:15", "15:15〜16:00"]
        let noteValid: Bool = {
            guard doc.kind == .return, evidence(doc.normalTimeNoteEvidence, doc.normalTimeNoteEvidence), doc.days.count == 5 else { return false }
            let dates = doc.days.sorted().map { $0.split(separator:"-").compactMap { Int($0) } }
            guard dates.allSatisfy({ $0.count == 3 }) else { return false }
            let first = dates[0], start = dates[1], end = dates[4]
            guard start[1] == end[1] else { return false }
            let expected = "\(first[1])月\(first[2])日の時間割は以下のとおり\(start[1])月\(start[2])日〜\(end[2])日は通常の授業日どおりの授業時間"
            let pages = Dictionary(grouping:doc.normalTimeNoteEvidence,by:{ sources[$0]?.page ?? 0 })
            return !pages.isEmpty && Set(pages.keys).isSubset(of:Set(doc.cells.map(\.page))) && pages.values.allSatisfy { ids in
                let raw = text(original(ids)).replacingOccurrences(of:"~",with:"〜").replacingOccurrences(of:"です。",with:"").replacingOccurrences(of:"。",with:"")
                return raw == expected
            }
        }()
        func clockText(_ raw: String) -> String? {
            let value = text(raw).replacingOccurrences(of: "~", with: "〜").replacingOccurrences(of: "～", with: "〜")
            let pieces = value.components(separatedBy: "〜")
            guard pieces.count == 2 else { return nil }
            var times = [String]()
            for p in pieces {
                let bits = p.split(separator: ":").compactMap { Int($0) }
                guard bits.count == 2, (0...23).contains(bits[0]), (0...59).contains(bits[1]) else { return nil }
                times.append(String(format:"%02d:%02d",bits[0],bits[1]))
            }
            return times.joined(separator:"〜")
        }
        func clockBound(_ day: String, _ start: Int, _ end: Int, _ clock: String) -> Bool {
            guard (1...maxPeriod).contains(start), (1...maxPeriod).contains(end), start <= end else { return false }
            let suffix = start == end ? String(start) : "\(start)-\(end)"
            let key = "\(day):\(suffix)", ids = doc.clockEvidence["\(day):\(suffix)"] ?? []
            guard let primary = doc.clockBindings[key] else { return false }
            if primary.derivedSpan {
                let firstKey = "\(day):\(start)", lastKey = "\(day):\(end)"
                guard evidence(ids,doc.timeEvidence+doc.normalTimeNoteEvidence), start < end, primary.day == day, primary.spanStart == start, primary.spanEnd == end,
                      primary.periodHeaderIds.isEmpty, primary.dayHeaderIds.isEmpty, !primary.commonScope,
                      doc.clockReplicas[key,default:[]].isEmpty,
                      let first = doc.times[firstKey], let last = doc.times[lastKey],
                      first.components(separatedBy:"〜").first! + "〜" + last.components(separatedBy:"〜").last! == clock,
                      Set(ids) == Set((doc.clockEvidence[firstKey,default:[]] + doc.clockEvidence[lastKey,default:[]]).filter { sources[$0]?.page == primary.page }),
                      ids.allSatisfy({ id in sources[id].map { $0.page == primary.page && primary.box.contains($0.box) } ?? false }) else { return false }
                func endpoint(_ period: Int,_ value: String) -> Bool {
                    clockBound(day,period,period,value) || doc.kind == .return && day != doc.days.sorted().first && noteValid && value == normalTimes[period-1] && evidence(doc.clockEvidence["\(day):\(period)",default:[]],doc.normalTimeNoteEvidence)
                }
                return endpoint(start,first) && endpoint(end,last)
            }
            guard evidence(ids,doc.timeEvidence) else { return false }
            let bindings = [primary] + (doc.clockReplicas[key] ?? [])
            guard Set(bindings.map(\.page)).count == bindings.count else { return false }
            var owned = Set<String>()
            return bindings.allSatisfy { binding in
                let ids = ids.filter { sources[$0]?.page == binding.page }
                owned.formUnion(ids)
                guard binding.day == day, binding.spanStart == start, binding.spanEnd == end,
                  binding.page > 0, binding.box.valid, evidence(ids, doc.timeEvidence), clockText(original(ids)) == clock, ids.allSatisfy({ id in sources[id].map { $0.page == binding.page && binding.box.contains($0.box) } ?? false }) else { return false }
            let parts = clock.components(separatedBy: "〜")
            guard parts.count == 2, parts[0] < parts[1] else { return false }
            let virtual = RecoveryCell(id: "clock", page: binding.page, box: binding.box, inputState: .complete, slots: [], sourceIds: ids, blankFields: [])
            let labels = start == end ? [String(start), "\(start)限", "\(start)時限", "\(start)時限目", "第\(start)時限"] : ["\(start)・\(end)時限連続", "\(start)〜\(end)時限連続", "\(start)〜\(end)限", "\(start)-\(end)限"]
            let allowed = start == end ? doc.periodEvidence[String(start)] ?? [] : binding.periodHeaderIds
            guard header(binding.periodHeaderIds, allowed, labels, cell: virtual, region: binding.periodRegion) else { return false }

            if binding.commonScope {
                guard binding.dayHeaderIds.isEmpty, binding.dayRegion == nil,
                      let region = doc.commonClockRegions[String(binding.page)], region.page == binding.page,
                      region.axis == .above, region.box.y + region.box.height <= binding.box.y,
                      evidence(doc.commonClockEvidence.filter { sources[$0]?.page == binding.page }, doc.commonClockEvidence),
                      doc.commonClockEvidence.filter { sources[$0]?.page == binding.page }.allSatisfy({ id in sources[id].map { $0.page == binding.page && region.box.contains($0.box) } ?? false }) else { return false }
                if doc.kind == .exam {
                    return header(doc.commonClockEvidence.filter { sources[$0]?.page == binding.page }, doc.commonClockEvidence, ["試験時間割", "試験時間", "試験時刻"]) && Set(pageCells[binding.page,default:[]].flatMap { $0.slots.map(\.day) }) == Set(doc.days)
                }
                if doc.kind == .return, day == doc.days.sorted().first {
                    let parts = day.split(separator: "-").compactMap { Int($0) }
                    guard parts.count == 3 else { return false }
                    return header(doc.commonClockEvidence.filter { sources[$0]?.page == binding.page }, doc.commonClockEvidence, ["\(parts[1])月\(parts[2])日の時間割は以下のとおりです。", "\(parts[1])月\(parts[2])日の時間割は以下のとおり"])
                }
                return false
            }
            return header(binding.dayHeaderIds, doc.dayEvidence[day] ?? [], dayLabels(day, kind: doc.kind), cell: virtual, region: binding.dayRegion)
            } && owned == Set(ids)
        }
        let validClocks = doc.clockBindings.filter { key, binding in
            let clock = binding.spanStart == binding.spanEnd ? doc.times[key] : doc.spanTimes[key]
            return clock.map { clockBound(binding.day, binding.spanStart, binding.spanEnd, $0) } ?? false
        }.flatMap { key,binding in [binding] + (doc.clockReplicas[key] ?? []) }
        for cls in doc.classes { check(Set(doc.classEvidence[cls] ?? []) == Set(classCells[cls,default:[]].flatMap(\.classHeaderIds)), "classEvidence") }
        for day in doc.days { check(Set(doc.dayEvidence[day] ?? []) == Set(dayCells[day,default:[]].flatMap(\.dayHeaderIds) + validClocks.filter { $0.day == day }.flatMap(\.dayHeaderIds)), "dayHeaderCoverage") }
        for period in 1...maxPeriod {
            let allowed = doc.periodEvidence[String(period)] ?? []
            let bound = periodMembers(periodCells[period,default:[]].flatMap(\.periodHeaderIds),period:period) + validClocks.filter { $0.spanStart == period && $0.spanEnd == period }.flatMap(\.periodHeaderIds)
            check(Set(allowed) == Set(bound), "periodHeaderCoverage")
        }
        for values in pageCells.values {
            var active = [RecoveryCell]()
            for cell in values.sorted(by: { $0.box.x < $1.box.x }) {
                guard work.charge(active.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) }
                active.removeAll { $0.box.x + $0.box.width <= cell.box.x }
                guard work.charge(active.count + 1) else { return RecoveryValidation(errors:["validationLimit"]) }
                check(!active.contains { min($0.box.y + $0.box.height, cell.box.y + cell.box.height) > max($0.box.y, cell.box.y) }, "cellOverlap")
                active.append(cell)
            }
        }
        for annotation in doc.annotations {
            guard work.charge(pageCells[annotation.page,default:[]].count + annotation.sourceIds.count) else { return RecoveryValidation(errors:["validationLimit"]) }
            check(annotation.page > 0 && annotation.box.valid && annotation.tableBox.valid && evidence(annotation.sourceIds, annotation.sourceIds) &&
                (annotation.box.x + annotation.box.width <= annotation.tableBox.x || annotation.box.x >= annotation.tableBox.x + annotation.tableBox.width || annotation.box.y + annotation.box.height <= annotation.tableBox.y || annotation.box.y >= annotation.tableBox.y + annotation.tableBox.height) &&
                annotation.sourceIds.allSatisfy { id in sources[id].map { $0.page == annotation.page && annotation.box.contains($0.box) } ?? false } &&
                pageCells[annotation.page,default:[]].allSatisfy { annotation.tableBox.contains($0.box) }, "annotationEvidence")
        }
        var classified = Set(doc.cells.flatMap(\.sourceIds) + doc.yearEvidence + (doc.term == nil ? [] : doc.termEvidence))
        classified.formUnion(doc.cells.flatMap { $0.roleScopes.flatMap(\.labelSourceIds) })
        classified.formUnion(doc.annotations.flatMap(\.sourceIds))
        classified.formUnion(doc.commonClockEvidence)
        for cls in doc.classes { classified.formUnion(doc.classEvidence[cls] ?? []) }
        for day in doc.days { classified.formUnion(doc.dayEvidence[day] ?? []) }
        for period in 1...maxPeriod { classified.formUnion(doc.periodEvidence[String(period)] ?? []) }
        if doc.kind != .timetable {
            for key in Set(doc.times.keys).union(doc.spanTimes.keys) {
                classified.formUnion(doc.clockEvidence[key] ?? [])
                classified.formUnion(doc.clockBindings[key]?.periodHeaderIds ?? [])
                classified.formUnion(doc.clockReplicas[key,default:[]].flatMap(\.periodHeaderIds))
            }
            if doc.kind == .return { classified.formUnion(doc.normalTimeNoteEvidence) }
        }
        check(Set(doc.sources.map(\.id)) == classified, "unclassifiedSource")
        if doc.kind != .timetable {
            let spanKeys = Set(doc.cells.compactMap { cell -> String? in guard cell.slots.count > 1, let slot = cell.slots.first, let first = cell.slots.map(\.period).min(), let last = cell.slots.map(\.period).max() else { return nil }; return "\(slot.day):\(first)-\(last)" })
            let clockKeys = Set(doc.times.keys).union(spanKeys)
            check(Set(doc.spanTimes.keys) == spanKeys && Set(doc.clockEvidence.keys) == clockKeys && Set(doc.clockBindings.keys).isSubset(of: clockKeys) && Set(doc.clockReplicas.keys).isSubset(of:Set(doc.clockBindings.keys)), "clockScope")
            check(Set(doc.timeEvidence).isSubset(of: Set(doc.clockEvidence.values.flatMap { $0 })), "clockCoverage")
            check(doc.times.count == doc.days.count * maxPeriod && evidence(doc.timeEvidence, doc.timeEvidence), "times")
            for day in doc.days {
                var previous = "00:00"
                for p in 1...maxPeriod {
                    let clock = doc.times["\(day):\(p)"] ?? ""
                    let valid = clock.range(of: "^(?:[01][0-9]|2[0-3]):[0-5][0-9]〜(?:[01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil
                    check(valid, "clock")
                    let key = "\(day):\(p)"
                    let clockIds = doc.clockEvidence[key] ?? []
                    let explicit = clockBound(day, p, p, clock)
                    let normal = doc.kind == .return && day != doc.days.sorted().first && noteValid && clock == normalTimes[p - 1] && evidence(clockIds, doc.normalTimeNoteEvidence)
                    check(explicit || normal, "clockEvidence")
                    check(doc.clockBindings[key] == nil || explicit, "clockBinding")
                    if doc.kind == .return && day != doc.days.sorted().first { check(noteValid && clock == normalTimes[p - 1], "normalTimeCondition") }
                    if valid { let parts = clock.components(separatedBy: "〜"); check(parts[0] >= previous && parts[1] > parts[0], "clockOrder"); previous = parts[1] }
                }
            }
            if doc.kind == .return { check(noteValid, "normalTimeNote") }
        }
        for cell in doc.cells {
            guard work.charge(cell.sourceIds.count + index.byCell[cell.id,default:[]].count + 1) else { return RecoveryValidation(errors:["validationLimit"]) }
            let ownedIds = Set(index.byCell[cell.id,default:[]].map(\.id))
            check(ownedIds == Set(cell.sourceIds), "sourceInventory")
            let sourceIds = Set(cell.sourceIds)
            check(index.intersections(page:cell.page,box:cell.box,work:work) { $0.cellId == cell.id && sourceIds.contains($0.id) }, "unassignedCellText")
            check(cell.inputState == .complete && cell.box.valid && cell.page > 0, "incompleteCell")
            check(Set(cell.sourceIds).count == cell.sourceIds.count && cell.sourceIds.allSatisfy { id in sources[id].map { $0.cellId == cell.id && $0.page == cell.page && cell.box.contains($0.box) } ?? false }, "sourcePosition")
            if let slot = cell.slots.first {
                check(header(cell.classHeaderIds, doc.classEvidence[slot.className] ?? [], classLabels(slot.className), cell: cell, region: cell.classRegion), "classBinding")
                check(header(cell.dayHeaderIds, doc.dayEvidence[slot.day] ?? [], dayLabels(slot.day, kind: doc.kind), cell: cell, region: cell.dayRegion), "dayBinding")
                check(cell.slots.allSatisfy { s in let ids = periodMembers(cell.periodHeaderIds,period:s.period); return header(ids, doc.periodEvidence[String(s.period)] ?? [], [String(s.period), "\(s.period)限", "\(s.period)時限", "\(s.period)時限目", "第\(s.period)時限"], cell: cell, region: cell.periodRegions[String(s.period)]) }, "periodBinding")
            }
            let periods = cell.slots.map(\.period).sorted()
            check(!cell.slots.isEmpty && Set(cell.slots.map { $0.className + "/" + $0.day }).count == 1 && zip(periods, periods.dropFirst()).allSatisfy { $1 == $0 + 1 }, "span")
            if doc.kind != .timetable, periods.count > 1, let slot = cell.slots.first {
                let key = "\(slot.day):\(periods.first!)-\(periods.last!)"
                check(doc.spanTimes[key].map { clockBound(slot.day, periods.first!, periods.last!, $0) && $0.range(of: "^(?:[01][0-9]|2[0-3]):[0-5][0-9]〜(?:[01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil } ?? false, "spanTimeEvidence")
                if doc.kind == .return && slot.day != doc.days.sorted().first {
                    let first = periods.first!, last = periods.last!
                    if (1...normalTimes.count).contains(first) && (1...normalTimes.count).contains(last) {
                        let expected = String(normalTimes[first-1].prefix(5)) + "〜" + String(normalTimes[last-1].suffix(5))
                        check(noteValid && doc.spanTimes[key] == expected, "normalSpanTimeCondition")
                    } else { check(false, "normalSpanTimeCondition") }
                }
            }
            let bindingIncomplete = inputOnly && unresolvedCellIds.contains(cell.id)
            let bindingIds = cell.lessonBindings.flatMap { $0.subject + $0.teacher + $0.room }
            let labelIds = cell.roleScopes.flatMap(\.labelSourceIds), labelSet = Set(cell.roleScopes.flatMap(\.labelSourceIds))
            let bodyIds = cell.sourceIds.filter { !labelSet.contains($0) }
            let bindingSet = Set(bindingIds)
            if !cell.parallelSeparators.isEmpty {
                check(cell.bindingMode == .fixed && cell.parallelCount == 2 && cell.lessonBindings.count == 2 && Set(cell.parallelSeparators.keys) == Set(RecoveryRole.allCases.map(\.rawValue)) && Set(cell.parallelSeparators.values).count == 3, "parallelEvidence")
                if cell.lessonBindings.count == 2 {
                    for role in RecoveryRole.allCases {
                        guard let separator = cell.parallelSeparators[role.rawValue].flatMap({ sources[$0] }) else { check(false,"parallelEvidence"); continue }
                        func ids(_ b: RecoveryLessonBinding) -> [String] { role == .subject ? b.subject : role == .teacher ? b.teacher : b.room }
                        let left = ids(cell.lessonBindings[0]), right = ids(cell.lessonBindings[1])
                        check(["・","･"].contains(separator.text) && sourceIds.contains(separator.id) && !bindingSet.contains(separator.id) &&
                            left.allSatisfy { id in sources[id].map { $0.box.x+$0.box.width <= separator.box.x && abs($0.box.y+$0.box.height/2-separator.box.y-separator.box.height/2) <= 2 } ?? false } &&
                            right.allSatisfy { id in sources[id].map { $0.box.x >= separator.box.x+separator.box.width && abs($0.box.y+$0.box.height/2-separator.box.y-separator.box.height/2) <= 2 } ?? false }, "parallelEvidence")
                    }
                }
            }
            if cell.bindingMode == .fixed {
                check(!cell.lessonBindings.contains { binding in [binding.subject,binding.teacher,binding.room].contains { ids in RecoveryRole.hasLabelPrefix(original(ids)) } }, "unboundRoleLabel")
                check(cell.roleScopes.isEmpty && (cell.confirmedEmpty ? cell.lessonBindings.isEmpty : bindingIncomplete || cell.lessonBindings.count == cell.parallelCount && Set(bindingIds).count == bindingIds.count && Set(bindingIds) == Set(cell.sourceIds).subtracting(cell.parallelSeparators.values)), "lessonBinding")
            } else {
                check(cell.parallelSeparators.isEmpty && !cell.confirmedEmpty && cell.lessonBindings.isEmpty && (1...4).contains(cell.parallelCount) && (bindingIncomplete || cell.roleScopes.count == cell.parallelCount * 3) && Set(labelIds).count == labelIds.count, "roleScope")
                let keys = cell.roleScopes.map { "\($0.lessonIndex):\($0.role.rawValue)" }
                check(Set(keys).count == keys.count && (bindingIncomplete || Set(keys) == Set((0..<max(0, min(cell.parallelCount, 4))).flatMap { i in RecoveryRole.allCases.map { "\(i):\($0.rawValue)" } })), "roleScope")
                for scope in cell.roleScopes {
                    let virtual = RecoveryCell(id: cell.id, page: cell.page, box: scope.box, inputState: .complete, slots: [], sourceIds: [], blankFields: [])
                    let labels = scope.role.labels.flatMap { [$0, $0 + ":", $0 + "："] }
                    check(scope.page == cell.page && cell.box.contains(scope.box) && (scope.proof == .columnHeader || scope.labelSourceIds.allSatisfy { sourceIds.contains($0) }) &&
                          (scope.proof != .inlineLabel || cell.box.contains(scope.labelRegion.box)) &&
                          header(scope.labelSourceIds, scope.proof == .inlineLabel ? cell.sourceIds : scope.labelSourceIds, labels, cell: virtual, region: scope.labelRegion), "roleEvidence")
                    check(!scope.emptyVerified || !bodyIds.contains { id in sources[id].map { scope.box.contains($0.box) } ?? false }, "falseBlankField")
                }
                for (i, scope) in cell.roleScopes.enumerated() { check(!cell.roleScopes.prefix(i).contains { min($0.box.x + $0.box.width, scope.box.x + scope.box.width) > max($0.box.x, scope.box.x) && min($0.box.y + $0.box.height, scope.box.y + scope.box.height) > max($0.box.y, scope.box.y) }, "roleScopeOverlap") }
            }
            if inputOnly { continue }
            guard let recovered = cells[cell.id] else { continue }
            if recovered.state == .empty { check(cell.confirmedEmpty && cell.sourceIds.isEmpty && recovered.lessons.isEmpty, "falseEmpty"); continue }
            check(!cell.confirmedEmpty && recovered.state == .present && (1...4).contains(cell.parallelCount) && recovered.lessons.count == cell.parallelCount, "cellState")
            for (lessonIndex, lesson) in recovered.lessons.enumerated() {
                let binding = cell.lessonBindings.indices.contains(lessonIndex) ? cell.lessonBindings[lessonIndex] : RecoveryLessonBinding(subject: [], teacher: [], room: [])
                for (name, field) in [("subject", lesson.subject), ("teacher", lesson.teacher), ("room", lesson.room)] {
                    check(field.value.utf16.count <= 1024, "fieldLimit")
                    if cell.bindingMode == .fixed {
                        if field.state == .empty { let ids = name == "subject" ? binding.subject : name == "teacher" ? binding.teacher : binding.room; check(ids.isEmpty && name != "subject" && field.value.isEmpty && field.evidence.isEmpty && cell.blankFields.contains(name), "falseBlankField") }
                        else { let ids = name == "subject" ? binding.subject : name == "teacher" ? binding.teacher : binding.room
                            check(field.state == .present && field.evidence == ids && ordered(field.evidence) && evidence(field.evidence, ids, field.value), "fieldEvidence") }
                    } else if let scope = cell.roleScopes.first(where: { $0.lessonIndex == lessonIndex && $0.role.rawValue == name }) {
                        if field.state == .empty { check(name != "subject" && scope.emptyVerified && field.value.isEmpty && field.evidence.isEmpty, "falseBlankField") }
                        else { check(field.state == .present && ordered(field.evidence) && evidence(field.evidence, bodyIds, field.value) && field.evidence.allSatisfy { id in sources[id].map { scope.box.contains($0.box) } ?? false }, "fieldEvidence") }
                    } else { check(false, "roleScope") }
                }
                check(cell.slots.first.flatMap { doc.dayEvidence[$0.day] }.map { _ in evidence(lesson.dateEvidence, cell.dayHeaderIds) } ?? false, "lessonDateEvidence")
                let headerIds = cell.periodHeaderIds
                check(evidence(lesson.periodEvidence, headerIds) && cell.slots.allSatisfy { slot in !periodMembers(lesson.periodEvidence,period:slot.period).isEmpty }, "lessonPeriodEvidence")
            }
            if cell.bindingMode == .roleProposal {
                let used = recovered.lessons.flatMap { $0.subject.evidence + $0.teacher.evidence + $0.room.evidence }
                check(Set(used).count == used.count && Set(used) == Set(cell.sourceIds).subtracting(labelIds), "rolePartition")
            }
            check(recovered.lessons.enumerated().allSatisfy { i, lesson in !recovered.lessons.prefix(i).contains(lesson) }, "parallelDuplicate")
        }
        return RecoveryValidation(errors: errors)
    }
    static func inputErrors(_ doc: RecoveryDocument, unresolvedCellIds:Set<String> = []) -> [String] {
        validate(doc, RecoveryResult(pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: doc.schoolYear, term: doc.term, cells: doc.cells.map { RecoveredCell(cellId: $0.id, state: .missing, lessons: []) }, metadata: doc.structureMetadata ?? RecoveryMetadata(provider: "rule", modelId: "rules", modelVersion: "1", runtimeVersion: "1", promptVersion: "1", recoverySchemaVersion: schemaVersion, validatorVersion: version, osVersion: "preflight")), inputOnly: true,unresolvedCellIds:unresolvedCellIds).errors
    }
    static func inputErrors(_ doc:RecoveryDocument,unresolvedCellIds:Set<String> = [],check:@escaping () throws -> Void) throws -> [String] {
        let work = RecoveryValidationWork(check:check)
        let index = try RecoverySourceIndex(doc.sources,work:work)
        return try inputErrors(doc,unresolvedCellIds:unresolvedCellIds,index:index,work:work)
    }
    static func inputErrors(_ doc:RecoveryDocument,unresolvedCellIds:Set<String> = [],index:RecoverySourceIndex,work:RecoveryValidationWork) throws -> [String] {
        let placeholder = RecoveryResult(pdfHash:doc.pdfHash,kind:doc.kind,schoolYear:doc.schoolYear,term:doc.term,cells:doc.cells.map { RecoveredCell(cellId:$0.id,state:.missing,lessons:[]) },metadata:doc.structureMetadata ?? RecoveryMetadata(provider:"rule",modelId:"rules",modelVersion:"1",runtimeVersion:"1",promptVersion:"1",recoverySchemaVersion:schemaVersion,validatorVersion:version,osVersion:"preflight"))
        return try validate(doc,placeholder,inputOnly:true,unresolvedCellIds:unresolvedCellIds,index:index,work:work).errors
    }
    static func previouslyAccepted(_ adopted: RecoveryAdopted?, hash: String) -> Bool {
        #if canImport(CryptoKit) || canImport(Crypto)
        guard let adopted, adopted.document.pdfHash == hash else { return false }
        return (try? canReuse(adopted.acceptance,document:adopted.document,result:adopted.result)) == true
        #else
        return false
        #endif
    }
    #if canImport(CryptoKit) || canImport(Crypto)
    static func fingerprint<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
    static func canReuse(_ acceptance: RecoveryAcceptance, document: RecoveryDocument, result: RecoveryResult) throws -> Bool {
        let resultHash = try fingerprint(result)
        let scopeHash = try fingerprint(document)
        return acceptance.pdfHash == document.pdfHash && acceptance.resultHash == resultHash &&
            acceptance.scopeHash == scopeHash && acceptance.metadata == result.metadata && validate(document, result).canAdopt
    }
    #endif
}
