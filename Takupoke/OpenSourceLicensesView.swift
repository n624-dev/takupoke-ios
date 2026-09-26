import SwiftUI

private enum OpenSourceLicense: String, CaseIterable, Identifiable {
    case zipFoundation = "ZIPFoundation"
    case denpaSchedule = "denpa-schedule-csv"
    case grdb = "GRDB"

    var id: String { rawValue }
    var title: String { self == .grdb ? "GRDB.swift" : rawValue }

    var text: String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "txt", subdirectory: "LicenseDocuments"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "ライセンス情報を読み取れません。"
        }
        return text
    }
}

struct OpenSourceLicensesView: View {
    var body: some View {
        List(OpenSourceLicense.allCases) { license in
            NavigationLink(license.title) {
                ScrollView {
                    Text(license.text)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .navigationTitle(license.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationTitle("オープンソースライセンス")
    }
}
