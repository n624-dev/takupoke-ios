import SwiftUI

struct SetupView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @AppStorage("timetableSelectedClasses") private var selectedClasses = ""
    @EnvironmentObject private var notifications: ScheduleNotifications
    @State private var step = 0
    @AppStorage("notificationsSetupCompleted") private var notificationsSetupCompleted = false
    @State private var permissionTask: Task<Void, Never>?
    let finish: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: AccountDataSettingsView(setupMode: true)
                case 1:
                    MaterialsView(model: materials, specialSchedules: specialSchedules,
                                  schoolEvents: schoolEvents, mappings: mappings, setupMode: true)
                case 2:
                    TimetablePrimaryClassSelection(classes: TimetableSchedule.selectableClasses, value: $selectedClasses, setupMode: true)
                default:
                    List {
                        Text("時間割変更や試験時間割の更新を通知します。通知の種類は設定で変更できます。")
                    }
                    .navigationTitle("通知")
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if step > 0 { Button("戻る") { step -= 1 }.disabled(permissionTask != nil) }
                    Spacer()
                    Text("\(step + 1) / 4").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(step != 3 ? "次へ" : notificationsSetupCompleted ? "はじめる" : "通知をオンにする") {
                        if step < 3 {
                            step += 1
                        } else if notificationsSetupCompleted {
                            finish()
                        } else {
                            permissionTask = Task {
                                await notifications.enableFromSetup()
                                guard !Task.isCancelled else { return }
                                permissionTask = nil
                                finish()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(permissionTask != nil)
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("あとで設定") {
                        permissionTask?.cancel()
                        permissionTask = nil
                        finish()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
