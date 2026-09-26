import SwiftUI

struct SetupView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @AppStorage("timetableSelectedClasses") private var selectedClasses = ""
    @State private var step = 0
    let finish: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: AccountDataSettingsView()
                case 1:
                    MaterialsView(model: materials, specialSchedules: specialSchedules,
                                  schoolEvents: schoolEvents, mappings: mappings, setupMode: true)
                default:
                    TimetablePrimaryClassSelection(classes: TimetableSchedule.selectableClasses, value: $selectedClasses)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if step > 0 { Button("戻る") { step -= 1 } }
                    Spacer()
                    Text("\(step + 1) / 3").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(step == 2 ? "はじめる" : "次へ") {
                        if step == 2 { finish() } else { step += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("あとで設定", action: finish) }
            }
        }
        .interactiveDismissDisabled()
    }
}
