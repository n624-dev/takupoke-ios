// Typecheck-only support for unrelated app domain types. All Apple framework
// types (Vision, UIKit, PDFKit, CryptoKit) come from the actual iPhone SDK.
// This does not claim whole-app typechecking or raster/Builder execution.
import Foundation
enum RecoveryInputState: Sendable { case complete }
struct PDFParseError: Error {
    enum Code { case unreadable, limit, ambiguous, cancelled }
    enum Stage { case characterMapping, rasterInput }
    let code: Code
    var page: Int? = nil
    var stage: Stage? = nil
}
enum MaterialLibrary { static let maximumBytes = 50 * 1024 * 1024 }
struct PDFGlyph: Sendable {
    let text: String
    let x: Double; let y: Double; let width: Double; let height: Double
    let sourceLine: Int; let sourceOrder: Int
}
struct PDFRule: Sendable {}
struct PDFPageLayout: Sendable {
    let width: Double; let height: Double
    let glyphs: [PDFGlyph]; let lines: [PDFRule]
}
struct RecoveryRasterGrid: Sendable {
    static func fromRGBA(width: Int, height: Int, pixels: [UInt8], check: () throws -> Void) throws -> Self { Self() }
    func rules(check: () throws -> Void) throws -> [PDFRule] { [] }
    func preparingRules(_ rules: [PDFRule], check: () throws -> Void) throws -> Self { self }
}
