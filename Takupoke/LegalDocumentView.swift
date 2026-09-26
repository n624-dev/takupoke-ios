import SwiftUI

struct LegalDocumentView: View {
    enum Document: String {
        case terms, privacy
        var title: String { self == .terms ? "利用規約" : "プライバシーポリシー" }
    }
    let document: Document

    private var paragraphs: [String] {
        guard let url = Bundle.main.url(forResource: document.rawValue, withExtension: "txt", subdirectory: "LegalDocuments"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ["文書を読み込めませんでした。"]
        }
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    if paragraph.hasPrefix("## ") {
                        Text(String(paragraph.dropFirst(3))).font(.headline).padding(.top, 8)
                    } else { Text(paragraph).font(.body) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding().textSelection(.enabled)
        }.navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
    }
}
