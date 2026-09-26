import Foundation

struct SpecialScheduleRecord: Codable {
    let kind: SpecialScheduleKind
    let originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    let analysis: SpecialScheduleAnalysis
}

struct SpecialScheduleSource: Codable {
    let kind: SpecialScheduleKind
    let originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    var lastCheckedAt: Date? = nil
    var failure: PDFParseError?
    var grant: SourceGrant?
}
