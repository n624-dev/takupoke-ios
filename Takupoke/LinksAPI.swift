import Foundation

enum LinkOpeningMode: String {
    case external
    case inApp

    func destination(for url: URL, opposite: Bool = false) -> LinkOpeningMode {
        guard url.scheme?.lowercased() == "https" else { return .external }
        if opposite { return self == .external ? .inApp : .external }
        return self
    }
}

enum LinksError: LocalizedError {
    case invalidResponse, unavailable, storage

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "一覧のデータを確認できませんでした。保存済みの一覧は保持しています。"
        case .unavailable: return "一覧を取得できませんでした。通信状態を確認して再試行してください。"
        case .storage: return "一覧を保存できませんでした。保存済みの一覧は保持しています。"
        }
    }
}

struct LinkItem: Codable, Equatable, Identifiable {
    let id: String
    let categoryId: String
    let label: String
    let href: String
    let color: String
    let visible: Bool
    let sortOrder: Int
    let recommended: Bool
    let recommendationOrder: Int
    let searchAliases: [String]
    let searchTerms: String

    var url: URL? { URL(string: href) }
}

struct LinkCategory: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let sortOrder: Int
    let buttons: [LinkItem]
}

struct LinksPayload: Codable, Equatable {
    let version: String
    let linksVersion: String
    let categories: [LinkCategory]

    static let maximumBytes = 3_000_000
    static let colors: Set<String> = [
        "sky", "blue", "emerald", "green", "amber", "yellow", "orange", "rose",
        "red", "indigo", "purple", "pink", "teal", "slate", "gray"
    ]

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes,
              let payload = try? JSONDecoder().decode(Self.self, from: data),
              payload.isValid else { throw LinksError.invalidResponse }
        return payload
    }

    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 100 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    private static func validText(_ value: String, max: Int) -> Bool {
        !value.isEmpty && value.count <= max && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validURL(_ value: String) -> Bool {
        guard value.utf8.count <= 2048,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) || $0.value == 92
              }), let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "jrshikoku" { return value.lowercased().hasPrefix("jrshikoku:") }
        return scheme == "https" && value.lowercased().hasPrefix("https://") &&
            url.host != nil && url.user == nil && url.password == nil
    }

    private var isValid: Bool {
        guard version == "v1", linksVersion.hasPrefix("sha256-"), linksVersion.utf8.count == 71,
              linksVersion.utf8.dropFirst(7).allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              !categories.isEmpty, categories.count <= 100 else { return false }
        var categoryIDs = Set<String>()
        var linkIDs = Set<String>()
        for category in categories {
            guard Self.validID(category.id), categoryIDs.insert(category.id).inserted,
                  Self.validText(category.label, max: 80) else { return false }
            for item in category.buttons {
                guard Self.validID(item.id), linkIDs.insert(item.id).inserted,
                      item.categoryId == category.id, Self.validText(item.label, max: 80),
                      Self.validURL(item.href), Self.colors.contains(item.color),
                      item.searchAliases.count <= 20,
                      item.searchAliases.allSatisfy({ Self.validText($0, max: 80) }),
                      !item.searchTerms.isEmpty, item.searchTerms.count <= 5_000 else { return false }
            }
        }
        return linkIDs.count <= 800
    }
}

struct SavedLinks: Codable, Equatable {
    let payload: LinksPayload
    let apiETag: String
    let checkedAt: Date
    var revision: String? = nil
}

enum LinksResponse {
    static func validETag(_ value: String) -> Bool {
        let tag = value.hasPrefix("W/\"") ? String(value.dropFirst(2)) : value
        return tag.utf8.count >= 3 && tag.utf8.count <= 256 && tag.first == "\"" && tag.last == "\"" &&
            tag.utf8.dropFirst().dropLast().allSatisfy { (32...126).contains($0) && $0 != 34 }
    }

    static func decode(status: Int, data: Data, receivedETag: String?, saved: SavedLinks?,
                       checkedAt: Date = Date()) throws -> SavedLinks {
        guard status == 200 || status == 304 else { throw LinksError.unavailable }
        guard let receivedETag, validETag(receivedETag) else { throw LinksError.invalidResponse }
        switch status {
        case 200:
            return SavedLinks(payload: try LinksPayload.decode(data), apiETag: receivedETag, checkedAt: checkedAt)
        case 304:
            guard data.isEmpty, let saved,
                  receivedETag.replacingOccurrences(of: "W/", with: "") ==
                    saved.apiETag.replacingOccurrences(of: "W/", with: "") else {
                throw LinksError.invalidResponse
            }
            return SavedLinks(payload: saved.payload, apiETag: receivedETag, checkedAt: checkedAt)
        default:
            throw LinksError.invalidResponse
        }
    }
}
