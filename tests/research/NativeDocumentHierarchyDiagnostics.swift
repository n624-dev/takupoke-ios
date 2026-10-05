import Foundation

/// Research metadata only. This never repairs a missing box or emits a layout.
enum NativeDocumentHierarchyDiagnostics {
    static func rangeFailure(_ range: RecoveryOCRRange?, width: Int, height: Int) -> String? {
        guard let range else { return "missing" }
        guard [range.x, range.y, range.width, range.height, range.x + range.width,
               range.y + range.height].allSatisfy(\.isFinite) else { return "nonfinite" }
        guard range.width > 0, range.height > 0 else { return "nonpositive" }
        return range.isInside(width: width, height: height) ? nil : "outsidePage"
    }

    static func mapping(_ page: RecoveryOCRPage) throws -> [String: Any] {
        var counts = [String: Int](), samples = [[String: Any]](), total = 0
        for line in page.lines {
            guard let top1 = line.candidates.first else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
            for (index, character) in top1.characters.enumerated() {
                total += 1
                guard total <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                if total % 128 == 0 { try Task.checkCancellation() }
                let kind = rangeFailure(character.range, width: page.width, height: page.height) ?? "valid"
                let category = character.text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
                    ? "whitespace" : "nonWhitespace"
                counts[kind + ":" + category, default: 0] += 1
                if kind != "valid", samples.count < 16 {
                    var sample: [String: Any] = ["lineOrder": line.nativeOrder, "characterIndex": index,
                        "category": category, "failure": kind,
                        "characterUTF8": Array(character.text.utf8.prefix(16)),
                        "omittedCharacterBytes": max(0, character.text.utf8.count - 16),
                        "top1UTF8": Array(top1.text.utf8.prefix(128)),
                        "omittedTop1Bytes": max(0, top1.text.utf8.count - 128),
                        "confidenceDoubleBits": String(top1.confidence.bitPattern, radix: 16)]
                    if let range = character.range {
                        // Bits retain nonfinite numbers safely in JSON and prevent a
                        // formatting round trip from hiding a tiny boundary excess.
                        sample["pixelRangeDoubleBits"] = [range.x, range.y, range.width, range.height]
                            .map { String($0.bitPattern, radix: 16) }
                    }
                    samples.append(sample)
                }
            }
        }
        let failed = counts.filter { !$0.key.hasPrefix("valid:") }.values.reduce(0, +)
        return ["top1Characters": total, "failedCharacters": failed, "counts": counts,
            "firstFailures": samples, "omittedFailureSamples": max(0, failed - samples.count),
            "coordinates": "unchanged production pixel ranges; no clipping or substitution"]
    }

    static func spans(_ page: RecoveryOCRPage) throws -> [String: Any] {
        var inventory = [[String: Any]](), total = 0
        for document in page.structure?.documents ?? [] {
            for table in document.tables {
                var unique = Set<[Int]>()
                for groups in [table.rows, table.columns] {
                    for group in groups {
                        for cell in group {
                            total += 1
                            guard total <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                            if total % 128 == 0 { try Task.checkCancellation() }
                            unique.insert([cell.rowLower, cell.rowUpper, cell.columnLower, cell.columnUpper])
                        }
                    }
                }
                let ordered = unique.sorted { $0.lexicographicallyPrecedes($1) }
                guard inventory.count < 1000 else { throw RecoveryOCRAcquisitionFailure.limit }
                inventory.append(["documentOrder": document.nativeOrder, "tableOrder": table.nativeOrder,
                    "rowGroups": table.rows.count, "columnGroups": table.columns.count,
                    "uniqueNativeRanges": ordered.count, "firstNativeRanges": Array(ordered.prefix(32)),
                    "omittedNativeRanges": max(0, ordered.count - 32)])
            }
        }
        return ["tables": inventory, "cellAppearances": total,
            "rangeConvention": "unchanged native ClosedRange lower/upper; no topology inference"]
    }
}
