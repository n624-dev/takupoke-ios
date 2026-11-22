import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var mainColor: MainColorModel
    @AppStorage("linkOpeningMode") private var linkOpeningMode = LinkOpeningMode.inApp.rawValue
    @AppStorage(SyllabusLinkPolicy.storageKey) private var syllabusDepartmentID = ""
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    @AppStorage("timetableSelectedClasses") private var selectedClasses = ""
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var times: TimetableTimesModel
    @State private var showingSetup = false

    private var colorSelection: Binding<MainColor> {
        Binding(get: { mainColor.selection }, set: { mainColor.select($0) })
    }

    @ViewBuilder private func dataLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        if mainColor.selection.usesLightYellowIcons(in: scheme) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(MainColor.lightYellowIcon)
            }
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("データ") {
                    NavigationLink {
                        MaterialsView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                                      mappings: mappings)
                    } label: {
                        dataLabel("時間割ファイル", systemImage: "folder")
                    }
                    NavigationLink {
                        SchoolEventsSettingsView(model: schoolEvents)
                    } label: {
                        dataLabel("学校行事", systemImage: "calendar")
                    }
                    NavigationLink {
                        AccountDataSettingsView()
                    } label: {
                        HStack {
                            dataLabel("リンク・名称・授業時刻", systemImage: "arrow.down.circle")
                            Spacer()
                            if (mappings.current != nil && mappings.updateAvailable) || (links.saved != nil && links.updateAvailable) || (times.current != nil && times.updateAvailable) { Text("更新あり").font(.caption).foregroundStyle(.orange) }
                            else if mappings.failed || links.failed || times.failed { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                        }
                    }
                }
                Section("アプリ設定") {
                    NavigationLink {
                        TimetablePrimaryClassSelection(classes: TimetableSchedule.selectableClasses, value: $selectedClasses)
                    } label: {
                        LabeledContent("クラス", value: selectedClasses.isEmpty ? "未選択" :
                            TimetableDisplayText.classNames(selectedClasses.split(separator: "|").map(String.init)))
                    }
                    Toggle("AI・OCRを使用する", isOn: Binding(get: { useAiFeatures }, set: { useAiFeatures = $0; LocalAIFeaturePolicy.setEnabled($0) }))
                        .accessibilityIdentifier("use-ai-features")
                    NavigationLink("端末内AIモデル") { RecoveryModelSettingsView() }
                    NavigationLink("通知") { NotificationSettingsView() }
                    NavigationLink("カウントダウン") { CountdownManagementView(events: schoolEvents) }
                        .accessibilityIdentifier("countdown-settings")
                    Picker("メインカラー", selection: colorSelection) {
                        ForEach(MainColor.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("シラバスの学科", selection: $syllabusDepartmentID) {
                        Text("学科を選択しない").tag("")
                        ForEach(SyllabusLinkPolicy.departments) { department in
                            Text(department.name).tag(department.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("syllabus-department")
                    Picker("リンクの開き方", selection: $linkOpeningMode) {
                        Text("デフォルトのブラウザ").tag(LinkOpeningMode.external.rawValue)
                        Text("アプリ内で開く").tag(LinkOpeningMode.inApp.rawValue)
                    }
                    .pickerStyle(.menu)
                }
                Section("サポート") {
                    Button("初期設定") { showingSetup = true }
                    NavigationLink("使い方") { UsageHelpView() }
                    NavigationLink("このアプリについて") { AboutView() }
                }
            }
            .navigationTitle("設定")
            .fullScreenCover(isPresented: $showingSetup) {
                SetupView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                          mappings: mappings, finish: { showingSetup = false })
            }
        }
    }
}
