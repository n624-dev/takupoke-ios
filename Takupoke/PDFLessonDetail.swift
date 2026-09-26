import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PDFLessonDetail: View {
    let lesson: PDFLesson
    @ObservedObject var mappings: MappingModel
    private var names: TimetableLessonNames { mappings.names(for: lesson) }
    var body: some View {
        List {
            Section {
                Text(PDFDisplayText.continuous(names.detailSubject)).font(.title3)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: "\(lesson.period)限")
                LabeledContent("教員", value: names.detailTeacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(names.detailTeacher))
                LabeledContent("教室", value: names.detailRoom.isEmpty ? "記載なし" : PDFDisplayText.continuous(names.detailRoom))
            }
            Section("PDFの記載名") {
                LabeledContent("科目", value: PDFDisplayText.continuous(lesson.names.subject))
                LabeledContent("教員", value: lesson.names.teacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.teacher))
                LabeledContent("教室", value: lesson.names.room.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.room))
            }
            Section {
                DisclosureGroup("元のセルの記載") { Text(PDFDisplayText.continuous(lesson.sourceText)).textSelection(.enabled) }
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
