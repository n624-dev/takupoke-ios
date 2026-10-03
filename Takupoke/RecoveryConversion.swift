import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// One verified payload goes through the existing transactional Analysis save.
enum RecoveryConversion {
    static func adopted(_ preview: RecoveryPreview, now: Date = Date()) throws -> RecoveryAdopted {
        guard RecoveryValidator.validate(preview.document, preview.result).canAdopt else { throw PDFParseError(code:.ambiguous) }
        return RecoveryAdopted(document:preview.document,result:preview.result,acceptance:RecoveryAcceptance(pdfHash:preview.document.pdfHash,resultHash:try RecoveryValidator.fingerprint(preview.result),scopeHash:try RecoveryValidator.fingerprint(preview.document),metadata:preview.result.metadata,acceptedAt:now))
    }
    static func timetable(_ preview: RecoveryPreview) throws -> PDFAnalysis {
        guard preview.document.kind == .timetable else { throw PDFParseError(code:.storage) }
        let adopted = try adopted(preview), cells = Dictionary(uniqueKeysWithValues:preview.document.cells.map { ($0.id,$0) })
        var lessons = [PDFLesson]()
        for output in preview.result.cells where output.state == .present {
            guard let cell = cells[output.cellId] else { throw PDFParseError(code:.storage) }
            for slot in cell.slots {
                guard let weekday = Int(slot.day) else { throw PDFParseError(code:.storage) }
                for lesson in output.lessons {
                    lessons.append(PDFLesson(className:slot.className,weekday:weekday,period:slot.period,names:TimetableLessonNames(subject:lesson.subject.value,teacher:lesson.teacher.value,room:lesson.room.value),sourceText:[lesson.subject.value,lesson.teacher.value,lesson.room.value].joined(separator:"\n"),page:cell.page))
                }
            }
        }
        return PDFAnalysis(kind:.timetable,sourceDigest:preview.source.digest,sourceName:preview.source.originalName,parsedAt:adopted.acceptance.acceptedAt,schoolYear:preview.document.schoolYear,term:preview.document.term,lessons:lessons,events:[],notices:["端末内の復旧結果を確認して採用しました。"],recovery:adopted)
    }
    static func special(_ preview: RecoveryPreview) throws -> SpecialScheduleAnalysis {
        guard preview.document.kind != .timetable else { throw PDFParseError(code:.storage) }
        let adopted = try adopted(preview), doc = preview.document
        let cells = Dictionary(uniqueKeysWithValues:doc.cells.map { ($0.id,$0) })
        var lessons = [SpecialScheduleLesson]()
        for output in preview.result.cells where output.state == .present {
            guard let cell = cells[output.cellId], let first = cell.slots.map(\.period).min(), let last = cell.slots.map(\.period).max() else { throw PDFParseError(code:.storage) }
            for slot in cell.slots {
                let time = first == last ? doc.times["\(slot.day):\(first)"] : doc.spanTimes["\(slot.day):\(first)-\(last)"]
                for lesson in output.lessons {
                    lessons.append(SpecialScheduleLesson(date:slot.day,className:slot.className,period:slot.period,spanStart:first,spanEnd:last,timeRange:time,lines:[lesson.subject.value,lesson.teacher.value,lesson.room.value],page:cell.page))
                }
            }
        }
        guard let day = doc.days.sorted().first else { throw PDFParseError(code:.storage) }
        let periodTimes = Dictionary(uniqueKeysWithValues:(1...(doc.kind == .exam ? 6 : 8)).compactMap { p in doc.times["\(day):\(p)"].map { (p,$0) } })
        return SpecialScheduleAnalysis(kind:doc.kind == .exam ? .exam : .examReturn,sourceDigest:preview.source.digest,sourceName:preview.source.originalName,parsedAt:adopted.acceptance.acceptedAt,schoolYear:doc.schoolYear,coveredDates:doc.days.sorted(),coveredClasses:doc.classes.sorted(),periodTimes:periodTimes,lessons:lessons,recovery:adopted)
    }
    static func verifyFile(_ source: RecoverySelectedSource, check: () throws -> Void) throws {
        guard SchoolDataPeriod.current() == source.period else { throw PDFParseError(code:.cancelled) }
        let file = try FileHandle(forReadingFrom:source.url); defer { try? file.close() }
        var hash = SHA256(), count = 0
        while true {
            try check()
            guard let bytes = try file.read(upToCount:65536), !bytes.isEmpty else { break }
            count += bytes.count; guard count <= MaterialLibrary.maximumBytes else { throw PDFParseError(code:.limit) }; hash.update(data:bytes)
        }
        guard count > 0, hash.finalize().map({ String(format:"%02x",$0) }).joined() == source.digest else { throw PDFParseError(code:.storage) }
        try check()
    }
}
