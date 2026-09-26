import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testPersistenceFailureAndNewSourceKeepLastGoodResult() throws {
        try temporary { root in
            var fail = false
            let library = try MaterialLibrary(root: root) { data, url in
                if fail { throw ChangeParseError(code: .storage) }
                try data.write(to: url, options: .atomic)
            }
            func acquire(_ digest: String) throws {
                let staged = library.newStagingURL()
                try Data("PK synthetic".utf8).write(to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                                   byteCount: 12, digest: digest, modifiedAt: nil)
            }
            try acquire("source-a")
            let records = try ChangeNormalizer.parse(example, defaultYear: nil)
            let good = ChangeAnalysis(sourceDigest: "source-a", sourceName: "架空資料.xlsx", defaultYear: nil, parsedAt: Date(), records: records)
            try library.saveChangeAnalysis(good)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.records, records)
            try acquire("source-b")
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            try library.recordParseFailure(ChangeParseError(code: .date, row: 2), defaultYear: 2032)
            XCTAssertEqual(library.state.changeAnalysis?.records, records)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeParseAttempt?.failure?.code, .date)
            fail = true
            var next = good
            next.sourceDigest = "source-b"
            XCTAssertThrowsError(try library.saveChangeAnalysis(next))
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-a")
            fail = false
            try library.saveChangeAnalysis(next)
            XCTAssertNil(library.state.changeParseAttempt?.failure)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-b")
            var legacy = library.state
            legacy.changeAnalysis?.version = 1
            legacy.changeParseAttempt?.failure = ChangeParseError(code: .unsupported, row: 3)
            try JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("library.json"), options: .atomic)
            let reopened = try MaterialLibrary(root: root)
            XCTAssertEqual(reopened.state.changeAnalysis?.version, 1)
            XCTAssertEqual(reopened.state.changeAnalysis?.records, records)
            XCTAssertEqual(reopened.state.changeParseAttempt?.failure?.code, .unsupported)
        }
    }
}
