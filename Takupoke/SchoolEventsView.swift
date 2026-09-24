import SwiftUI

struct SchoolEventsSettingsSection: View {
    @ObservedObject var model: SchoolEventsModel
    @AppStorage("eventsSelectedSchoolYear") private var yearValue = ""

    private var year: Int? {
        let value = yearValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return SchoolDate.today().schoolYear }
        guard value.count == 4, let parsed = Int(value), (1900...9998).contains(parsed) else { return nil }
        return parsed
    }

    var body: some View {
        Section("学校行事") {
            TextField("学校年度（空欄なら現在の学校年度）", text: $yearValue)
                .keyboardType(.numberPad)
                .disabled(model.busy)
            if let year {
                if let saved = model.saved[year] {
                    Text("取得済み")
                        .font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink("詳細を見る") {
                        SchoolEventsResultView(saved: saved)
                    }
                    .accessibilityLabel("\(year)年度の学校行事の詳細を見る")
                } else {
                    Text("未取得")
                        .foregroundStyle(.secondary)
                }
                Button(model.saved[year] == nil ? "学校行事を取得" : "学校行事を更新") {
                    model.fetch(year: year)
                }
                    .disabled(!model.ready || model.busy)
            } else {
                Label("4桁の学校年度を入力してください。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if model.busy {
                HStack {
                    ProgressView()
                    Text("学校行事を取得中…")
                    Spacer()
                    Button("中止") { model.cancel() }
                }
            }
            if let message = model.message {
                Label(message, systemImage: model.failed ? "exclamationmark.triangle" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(model.failed ? Color.orange : Color.secondary)
            }
            if let message = model.sourceCheckMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text("APIが公開していない年度は取得できません。旧行事PDFの解析結果は時間割に使用しません。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SchoolEventsResultView: View {
    let saved: SavedSchoolEvents

    var body: some View {
        List {
            Section("取得結果") {
                LabeledContent("学校年度", value: "\(saved.payload.schoolYear)年度")
                LabeledContent("年度の期間", value: "\(saved.payload.schoolYear)年4月1日〜\(saved.payload.schoolYear + 1)年3月31日")
                LabeledContent("件数", value: "\(saved.payload.events.count)件")
                LabeledContent("最終取得") {
                    Text(saved.fetchedAt, format: .dateTime.year().month().day().hour().minute())
                }
            }
            ForEach(Array(saved.payload.events.enumerated()), id: \.offset) { _, event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline)
                    Text(event.startDate == event.endDate ? event.startDate :
                         "\(event.startDate)〜\(event.endDate)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(event.tag).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
        }
        .navigationTitle("学校行事")
    }
}
