import Foundation
import Vision
import CoreGraphics
import CoreText
import CryptoKit

/// Two independent fictional drawings; no PDF, school layout, model oracle or
/// expected OCR transcript is loaded. The probe measures native correspondence.
@available(macOS 26.0, *)
@main struct NativeDocumentHierarchyProbe {
    static let width = 1024, height = 720
    static func draw(merged: Bool) throws -> (CGImage, String) {
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        let image = rgba.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            context.setStrokeColor(gray: 0, alpha: 1); context.setLineWidth(2)
            for y in [140, 280, 420, 560] {
                context.move(to: CGPoint(x: 90, y: CGFloat(y))); context.addLine(to: CGPoint(x: 930, y: CGFloat(y)))
            }
            for x in [90, 370, 650, 930] {
                context.move(to: CGPoint(x: CGFloat(x), y: merged && x == 370 ? 280 : 140))
                context.addLine(to: CGPoint(x: CGFloat(x), y: 560))
            }
            context.strokePath()
            func text(_ value: String, _ x: Int, _ y: Int, size: CGFloat = 23) {
                let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
                let attributed = NSAttributedString(string: value, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)])
                context.textPosition = CGPoint(x: CGFloat(x), y: CGFloat(y))
                CTLineDraw(CTLineCreateWithAttributedString(attributed as CFAttributedString), context)
            }
            text("Entirely fictional research table", 90, 635, size: 28)
            for (column, value) in ["Fictional label A", "Fictional label B", "Fictional label C"].enumerated() {
                text(value, 110 + column * 280, 490)
            }
            for (column, value) in ["Fictional amber", "Fictional cyan", "Fictional teal"].enumerated() {
                text(value, 110 + column * 280, 350)
            }
            if merged {
                text("Fictional merged cell", 125, 210)
                text("Fictional marker", 670, 210)
            } else {
                for (column, value) in ["Fictional item AX", "Fictional item BY", "Fictional item CZ"].enumerated() {
                    text(value, 110 + column * 280, 210)
                }
            }
            return context.makeImage()
        }
        guard let image else { throw NSError(domain: "FictionalDrawing", code: 1) }
        let hash = SHA256.hash(data: Data(rgba)).map { String(format: "%02x", $0) }.joined()
        return (image, hash)
    }
    static func signature(_ candidates: [RecoveryOCRCandidate]) -> Data {
        // Diagnostic comparison independent of private production lookup keys.
        // Boundaries and native Double bits, not canonical Unicode or JSON numbers.
        var value = Data()
        func integer(_ number: UInt64) {
            var big = number.bigEndian
            withUnsafeBytes(of: &big) { value.append(contentsOf: $0) }
        }
        func text(_ text: String) { integer(UInt64(text.utf8.count)); value.append(contentsOf: text.utf8) }
        integer(UInt64(candidates.count))
        for candidate in candidates {
            text(candidate.text); integer(candidate.confidence.bitPattern); integer(UInt64(candidate.characters.count))
            for character in candidate.characters {
                text(character.text)
                if let box = character.range {
                    integer(1); for number in [box.x, box.y, box.width, box.height] { integer(number.bitPattern) }
                } else { integer(0) }
            }
        }
        return value
    }
    static func nativeSignature(_ line: RecognizedTextObservation) -> Data {
        // Also measure unscaled framework CGRect bits, separately from production
        // pixel-coordinate correspondence. No rounding or matching tolerance.
        var value = Data()
        func integer(_ number: UInt64) {
            var big = number.bigEndian
            withUnsafeBytes(of: &big) { value.append(contentsOf: $0) }
        }
        func text(_ text: String) { integer(UInt64(text.utf8.count)); value.append(contentsOf: text.utf8) }
        let candidates = line.topCandidates(5)
        integer(UInt64(candidates.count))
        for candidate in candidates {
            let string = candidate.string
            text(string); integer(Double(candidate.confidence).bitPattern); integer(UInt64(string.count))
            for start in string.indices {
                let end = string.index(after: start)
                text(String(string[start..<end]))
                if let rectangle = candidate.boundingBox(for: start..<end) {
                    let b = rectangle.boundingBox.cgRect
                    integer(1)
                    for number in [b.minX, b.minY, b.width, b.height] { integer(Double(number).bitPattern) }
                } else { integer(0) }
            }
        }
        return value
    }
    static func measure(_ page: RecoveryOCRPage, observations: [DocumentObservation]) throws -> [String: Int] {
        var counts = ["flatLines": page.lines.count, "nativeTables": 0, "uniqueMergedSpans": 0,
                      "cellLineAppearances": 0, "uniqueRawMatches": 0, "missingRawMatches": 0,
                      "ambiguousRawMatches": 0, "sameUUID": 0, "sameUUIDExactRaw": 0,
                      "sameUUIDDifferentRaw": 0, "differentUUIDExactRaw": 0,
                      "uniqueNativeRawMatches": 0, "missingNativeRawMatches": 0,
                      "ambiguousNativeRawMatches": 0, "sameUUIDNativeExactRaw": 0]
        for (documentOrder, document) in page.structure!.documents.enumerated() {
            guard observations.indices.contains(documentOrder) else { throw NSError(domain: "NativeInventory", code: 3) }
            let native = observations[documentOrder].document
            let flat = native.text.lines
            guard flat.count == document.lineOrders.count else { throw NSError(domain: "NativeInventory", code: 1) }
            var byRaw = [Data: [Int]](), byUUID = [UUID: [Int]](), byNativeRaw = [Data: [Int]]()
            for local in flat.indices {
                guard page.lines.indices.contains(document.lineOrders[local]) else { throw NSError(domain: "NativeInventory", code: 4) }
                let captured = page.lines[document.lineOrders[local]]
                byRaw[signature(captured.candidates), default: []].append(local)
                byUUID[flat[local].uuid, default: []].append(local)
                byNativeRaw[nativeSignature(flat[local]), default: []].append(local)
                // Independently verify that the adapter did not replace top1 text.
                guard let top1 = flat[local].topCandidates(1).first, let capturedTop1 = captured.candidates.first,
                      top1.string.utf8.elementsEqual(capturedTop1.text.utf8) else {
                    throw NSError(domain: "FlatRawRetention", code: 1)
                }
            }
            counts["nativeTables", default: 0] += document.tables.count
            for (tableOrder, table) in document.tables.enumerated() {
                guard native.tables.indices.contains(tableOrder) else { throw NSError(domain: "NativeInventory", code: 5) }
                var mergedSpans = Set<String>()
                for (axis, groups) in [table.rows, table.columns].enumerated() {
                    let originals = axis == 0 ? native.tables[tableOrder].rows : native.tables[tableOrder].columns
                    for (groupOrder, group) in groups.enumerated() {
                        guard originals.indices.contains(groupOrder) else { throw NSError(domain: "NativeInventory", code: 6) }
                        for (cellOrder, cell) in group.enumerated() {
                            guard originals[groupOrder].indices.contains(cellOrder) else { throw NSError(domain: "NativeInventory", code: 7) }
                            if cell.rowUpper > cell.rowLower || cell.columnUpper > cell.columnLower {
                                mergedSpans.insert("\(cell.rowLower):\(cell.rowUpper):\(cell.columnLower):\(cell.columnUpper)")
                            }
                            let nativeLines = originals[groupOrder][cellOrder].content.text.lines
                            guard nativeLines.count == cell.lines.count else { throw NSError(domain: "NativeInventory", code: 2) }
                            for (local, line) in cell.lines.enumerated() {
                                counts["cellLineAppearances", default: 0] += 1
                                let raw = signature(line.candidates), matches = byRaw[raw] ?? []
                                if matches.count == 1 { counts["uniqueRawMatches", default: 0] += 1 }
                                else if matches.isEmpty { counts["missingRawMatches", default: 0] += 1 }
                                else { counts["ambiguousRawMatches", default: 0] += 1 }
                                let uuidMatches = byUUID[nativeLines[local].uuid] ?? []
                                let nativeRaw = nativeSignature(nativeLines[local]), nativeMatches = byNativeRaw[nativeRaw] ?? []
                                if nativeMatches.count == 1 { counts["uniqueNativeRawMatches", default: 0] += 1 }
                                else if nativeMatches.isEmpty { counts["missingNativeRawMatches", default: 0] += 1 }
                                else { counts["ambiguousNativeRawMatches", default: 0] += 1 }
                                if !uuidMatches.isEmpty {
                                    counts["sameUUID", default: 0] += 1
                                    if uuidMatches.contains(where: { signature(page.lines[document.lineOrders[$0]].candidates) == raw }) {
                                        counts["sameUUIDExactRaw", default: 0] += 1
                                    } else { counts["sameUUIDDifferentRaw", default: 0] += 1 }
                                    if uuidMatches.contains(where: { nativeSignature(flat[$0]) == nativeRaw }) {
                                        counts["sameUUIDNativeExactRaw", default: 0] += 1
                                    }
                                } else if matches.count == 1 { counts["differentUUIDExactRaw", default: 0] += 1 }
                            }
                        }
                    }
                }
                counts["uniqueMergedSpans", default: 0] += mergedSpans.count
            }
        }
        return counts
    }
    static func main() async {
        var outcomes = [[String: Any]](), compatible = true, attempted = 0
        for merged in [false, true] {
            var result: [String: Any] = ["case": merged ? "independent-merged" : "independent-rectangular",
                "rawSource": "independent CoreGraphics drawing", "semanticTimetableQuality": "UNASSESSED"]
            do {
                try Task.checkCancellation()
                let (image, hash) = try draw(merged: merged)
                result["pixelSHA256"] = hash
                attempted += 1
                let observations = try await RecognizeDocumentsRequest().perform(on: image)
                result["nativeDocumentCount"] = observations.count
                var work = 0
                let page = try RecoveryVisionCapture.page(1, width: width, height: height,
                    observations: observations, work: &work, check: { try Task.checkCancellation() })
                result["captureWork"] = work
                let counts = try measure(page, observations: observations)
                result["correspondence"] = counts
                var hierarchyPassed = false
                do {
                    let links = try RecoveryOCRStructure.links(page.structure!, page: page, consume: { try Task.checkCancellation() })
                    result["linkedUniqueNativeCells"] = links.count
                    result["hierarchyDisposition"] = "PASS_EXACT_RAW_CORRESPONDENCE"
                    hierarchyPassed = true
                } catch {
                    result["hierarchyDisposition"] = "REFUSED"
                    result["hierarchyFailure"] = String(describing: error).prefix(160).description
                }
                do {
                    let draft = RecoveryOCRAcquisitionDraft(sourcePDFHash: hash, documentPageCount: 1, requiredOCRPages: [1], pages: [page])
                    let assessment = try draft.assess()
                    result["fullAcquisitionDisposition"] = assessment.directLayoutsAllowed ? "DIRECT_LAYOUTS_ALLOWED" : "LOW_CONFIDENCE_REFUSED"
                    result["lowConfidenceNativeCount"] = assessment.lowConfidenceNativeOrders[1]?.count ?? 0
                } catch {
                    result["fullAcquisitionDisposition"] = "REFUSED"
                    result["fullAcquisitionFailure"] = String(describing: error).prefix(160).description
                }
                let exercised = counts["nativeTables", default: 0] > 0 && counts["cellLineAppearances", default: 0] > 0
                    && (!merged || counts["uniqueMergedSpans", default: 0] > 0)
                let pass = exercised && hierarchyPassed && counts["missingRawMatches", default: 0] == 0
                    && counts["ambiguousRawMatches", default: 0] == 0
                    && counts["missingNativeRawMatches", default: 0] == 0
                    && counts["ambiguousNativeRawMatches", default: 0] == 0
                result["expectedNativeStructureObserved"] = exercised
                result["correspondenceControlPassed"] = pass
                compatible = compatible && pass
            } catch {
                result["correspondenceControlPassed"] = false
                result["operationalFailure"] = String(describing: error).prefix(160).description
                compatible = false
            }
            outcomes.append(result)
        }
        let report: [String: Any] = ["schemaVersion": 1, "sourceSHA": ProcessInfo.processInfo.environment["GITHUB_SHA"] ?? "",
            "runID": ProcessInfo.processInfo.environment["GITHUB_RUN_ID"] ?? "", "runAttempt": ProcessInfo.processInfo.environment["GITHUB_RUN_ATTEMPT"] ?? "",
            "nativeCallsAttempted": attempted, "maximumNativeCalls": 2, "retries": 0,
            "cases": outcomes, "nativeHierarchyCorrespondencePassed": compatible && attempted == 2,
            "wholeDocumentAdoption": "NOT_ATTEMPTED", "modelQualification": "UNASSESSED"]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            guard data.count <= 65_536 else { throw NSError(domain: "ReportBound", code: 1) }
            print("TAKUPOKE-NATIVE-HIERARCHY-1 " + String(decoding: data, as: UTF8.self))
        } catch { print("TAKUPOKE-NATIVE-HIERARCHY-REPORT-FAILED"); exit(2) }
        if !compatible || attempted != 2 { exit(1) }
    }
}
