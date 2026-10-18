"""Run the actual list summary and before-name methods without SwiftUI."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]


class TimetableChangeNameTests(unittest.TestCase):
    def test_home_subject_rendering_uses_formal_name_for_all_content_kinds_without_changing_cell_names(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute home subject presentation")
        source = (ROOT / "Takupoke/HomeLessonRow.swift").read_text()
        program = '''import Foundation
enum PDFDisplayText { static func continuous(_ value: String) -> String { value } }
struct Row {
    var names: TimetableLessonNames
    var usesRawMetadata: Bool
SUBJECT
    var rendered: String { subjectText }
}
@main struct Probe {
    static func main() {
        for raw in [true, false] {
            let names = TimetableLessonNames(subject: "架空略A", subjectFullName: "架空正式科目A・B")
            precondition(Row(names: names, usesRawMetadata: raw).rendered == "架空正式科目A•B")
            precondition(names.cellSubject == "架空略A" && names.subject == "架空略A")
            let fallback = TimetableLessonNames(subject: "架空未登録C", subjectFullName: " ")
            precondition(Row(names: fallback, usesRawMetadata: raw).rendered == "架空未登録C")
            precondition(Row(names: TimetableLessonNames(subject: ""), usesRawMetadata: raw).rendered == "変更を確認")
        }
    }
}
'''.replace("SUBJECT", block(source, "private var subjectText:"))
        with tempfile.TemporaryDirectory(prefix="home-formal-names-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", "-module-cache-path", str(path / "modules"),
                            str(ROOT / "Takupoke/TimetableLessonNames.swift"), str(path / "probe.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_list_uses_formal_names_for_explicit_and_inferred_subjects_with_source_fallback(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production list presentation")
        presentation = (ROOT / "Takupoke/TimetablePresentation.swift").read_text()
        view = (ROOT / "Takupoke/TimetableView+Changes.swift").read_text()
        program = '''import Foundation
enum PDFDisplayText { static func continuous(_ value: String) -> String { value } }
struct ScheduleChange { var before_subject = "", after_subject = "" }
struct PDFLesson { var names: TimetableLessonNames; var className = "1_ZZ" }
struct ChangeSelection { var change: ScheduleChange; var baseLessons: [PDFLesson] = [] }
struct Names { var before: TimetableLessonNames, after: TimetableLessonNames }
// Mapping rules have separate native tests. This double checks that the UI
// requests mapped names for both the XLSX fields and inferred normal lessons.
struct MappingModel {
    func mapped(_ value: String) -> TimetableLessonNames {
        TimetableLessonNames(subject: value,
            subjectFullName: value == "架空略A" ? "架空正式科目A" : nil)
    }
    func names(for change: ScheduleChange) -> Names {
        Names(before: mapped(change.before_subject), after: mapped(change.after_subject))
    }
    func names(for lesson: PDFLesson) -> TimetableLessonNames {
        precondition(lesson.className == "1_ZZ")
        return mapped(lesson.names.subject)
    }
}
struct Presentation {
    var mappings = MappingModel()
BEFORE
}
struct ListView {
    var mappings = MappingModel(), presentation = Presentation()
DELEGATE
SUMMARY
    func rendered(_ selection: ChangeSelection) -> String { changeSummary(selection) }
}
@main struct Probe {
    static func main() {
        let view = ListView()
        let explicit = ChangeSelection(change: ScheduleChange(before_subject: "架空略A", after_subject: "架空略A"))
        precondition(view.rendered(explicit) == "架空正式科目A → 架空正式科目A")
        let inferred = ChangeSelection(change: ScheduleChange(after_subject: "架空未登録B"), baseLessons: [
            PDFLesson(names: TimetableLessonNames(subject: "架空略A")),
            PDFLesson(names: TimetableLessonNames(subject: "架空略A")),
            PDFLesson(names: TimetableLessonNames(subject: " 架空未登録C ")),
            PDFLesson(names: TimetableLessonNames(subject: " "))])
        precondition(view.rendered(inferred) == "架空正式科目A・架空未登録C → 架空未登録B")
        precondition(view.rendered(ChangeSelection(change: ScheduleChange())) == "記載なし → 記載なし")
        precondition(explicit.change.before_subject == "架空略A")
        precondition(inferred.baseLessons[0].names.cellSubject == "架空略A")
    }
}
'''.replace("BEFORE", block(presentation, "func beforeSubject("))
        program = program.replace("DELEGATE", block(view, "func beforeSubject("))
        program = program.replace("SUMMARY", block(view, "private func changeSummary("))
        with tempfile.TemporaryDirectory(prefix="change-list-names-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"),
                            str(ROOT / "Takupoke/TimetableLessonNames.swift"),
                            str(path / "probe.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)


if __name__ == "__main__":
    unittest.main()
