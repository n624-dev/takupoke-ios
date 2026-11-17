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
        model = (ROOT / "Takupoke/MappingModels.swift").read_text()
        view = (ROOT / "Takupoke/TimetableView+Changes.swift").read_text()
        self.assertIn("selection.comparison.summary", view)
        program = '''import Foundation
enum PDFDisplayText { static func continuous(_ value: String) -> String { value } }
struct ScheduleChange {
    var detailPeriods: [Int]? = [1]
    var before_subject = "", after_subject = "", teacher = "", room = ""
    var isCancellation = false, isMakeup = false, cardKindLabel = "変更"
}
MODELS
@main struct Probe {
    static func main() {
        let mapped = TimetableLessonNames(subject: "架空略A", subjectFullName: "架空正式科目A")
        let base = ChangeBaseCandidate(names: mapped, source: "通常時間割")
        let names = ChangePresentation(before: .init(subject: ""), after: .init(subject: "架空未登録B"))
        let change = ScheduleChange()
        let inferred = ChangeComparison(change: change, names: names, candidates: [1: [base]])
        precondition(inferred.summary == "科目変更　架空正式科目A → 架空未登録B")
        precondition(ChangeComparison(change: change, names: names, candidates: [1: [base, base]]).summary == "時間割変更　変更後の科目 架空未登録B")
        let explicit = ChangePresentation(before: mapped, after: .init(subject: "架空正式科目A"))
        precondition(ChangeComparison(change: change, names: explicit, candidates: [:]).summary == "時間割変更　科目 架空正式科目A")
        precondition(base.names.cellSubject == "架空略A")
    }
}
'''.replace("MODELS", "\n".join(block(model, name) for name in
                         ("struct ChangePresentation:", "struct ChangeBaseCandidate:", "struct ChangeComparison {")))
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
