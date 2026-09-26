import Foundation

extension MaterialLibrary {
    static func decodeLegacyManifest(_ data: Data) throws -> MaterialLibraryState {
        guard data.count <= 64 * 1024 * 1024 else { throw MaterialError.invalidState }
        let state = try JSONDecoder().decode(MaterialLibraryState.self, from: data)
        guard state.schemaVersion == 1,
              Set(state.records.map(\.kind)).count == state.records.count,
              state.records.allSatisfy({ Self.validStoredName($0.storedName, kind: $0.kind) }) else {
            throw MaterialError.invalidState
        }
        if let analysis = state.changeAnalysis {
            guard (1...ChangeAnalysis.parserVersion).contains(analysis.version),
                  !analysis.records.isEmpty, analysis.records.count <= ChangeNormalizer.maximumRecords else {
                throw MaterialError.invalidState
            }
        }
        for (key, analysis) in state.pdfAnalyses ?? [:] {
            guard key == analysis.kind.rawValue, Self.validPDFAnalysis(analysis) else { throw MaterialError.invalidState }
        }
        return state
    }

    private static func validStoredName(_ name: String, kind: MaterialKind) -> Bool {
        let suffix = "." + kind.fileExtension
        return name.hasSuffix(suffix) && UUID(uuidString: String(name.dropLast(suffix.count))) != nil
    }

    static func validPDFAnalysis(_ analysis: PDFAnalysis) -> Bool {
        guard (1...PDFAnalysis.parserVersion).contains(analysis.version), analysis.kind != .changes,
              analysis.lessons.count + analysis.events.count <= PDFSchoolParser.maximumRecords else { return false }
        switch analysis.kind {
        case .timetable: return !analysis.lessons.isEmpty && analysis.events.isEmpty &&
            analysis.lessons.allSatisfy { (1...5).contains($0.weekday) && (1...8).contains($0.period) && !$0.names.subject.isEmpty }
        case .events: return !analysis.events.isEmpty && analysis.lessons.isEmpty &&
            analysis.events.allSatisfy { ["共通", "詫間"].contains($0.scope) && !$0.title.isEmpty }
        case .changes: return false
        }
    }
}
