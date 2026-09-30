import Foundation

enum MappingError: Error, LocalizedError {
    case invalidPackage, invalidResponse, authentication, unavailable, storage, changedDuringDownload

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "名称データの形式または整合性を確認できませんでした。"
        case .invalidResponse: return "名称データの配信応答を確認できませんでした。"
        case .authentication: return "認証を完了できませんでした。"
        case .unavailable: return "名称データを取得できませんでした。"
        case .storage: return "名称データを保存できませんでした。"
        case .changedDuringDownload: return "取得中に名称データが更新されました。もう一度お試しください。"
        }
    }
}

struct MappingRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let classes: [String]?
    let internationalStudent: Bool?
}

struct TeacherContextRule: Codable, Equatable {
    let alias: String
    let fullName: String
    let subject: String
    let className: String
    let schoolYear: Int
}

struct ChangePresentation: Equatable {
    let before: TimetableLessonNames
    let after: TimetableLessonNames

    static func source(_ change: ScheduleChange) -> Self {
        Self(before: TimetableLessonNames(subject: change.before_subject),
             after: TimetableLessonNames(subject: change.after_subject,
                                         teacher: change.teacher, room: change.room))
    }
}

struct SavedMapping: Codable, Equatable {
    let revision: String
    let version: String
    let schemaVersion: Int
    let archiveETag: String
    let archiveSHA256: String
    let publishedAt: String
    let fetchedAt: Date
    let rules: MappingRules
}
