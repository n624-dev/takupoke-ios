# Actual iOS vector Reader: partial decoding then paint-work limit

[Native run 37221805739](https://github.com/n624-dev/takupoke-ios/actions/runs/37221805739) completed with source `0d31e79e98692b009ea8414888a558fa91c7f340` and unchanged production runtime `a25e93e` (parser 22). Both source binaries compiled against the actual iOS 27 simulator SDK; 12 helper tests and 4 generator tests passed. One owned simulator made exactly four baseline Reader calls and six current Reader calls. This is simulator evidence, not physical-device or model qualification.

All five required log streams were restored with numbered chunks, exact byte counts and SHA-256. Transport success did **not** imply parsing success:

| Cohort | Planned / attempted / recorded | Reader returned | Analysis returned | Actual result |
|---|---:|---:|---:|---|
| Baseline `71d28af`, primary v1 and diagnostic v2 pairs | 4 / 4 / 4 | 0 | 0 | `unsupported`, `characterMapping` |
| Current, primary v1 and diagnostic v2 pairs plus parallel mismatch | 5 / 5 / 5 | 0 | 0 | `limit` after partial text acquisition, at the paths step |
| Current, unreadable opaque body | 1 / 1 / 1 | 0 | 0 | `unsupported`, `characterMapping` |

The current main pair captured 8,749 partial glyphs per input; the controls captured 12,646 and the parallel mismatch 8,741. The captured text-only layouts report zero rules; partial internal path rules were not exported. Capture remained `partial`, with `readerCompleted=false` and `complete=false`. The helper exported partial counts/states/layout hashes, not the partial glyph arrays. No complete layout, Strict result, Recovery result, 680-slot comparison, blank-cell proof, persistence or manual adoption was assessed. The parallel negative reached a work limit and is unassessed; that limit is not counted as a correct semantic refusal. The opaque negative's typed unsupported refusal is recorded separately, without an EMPTY claim or a claim that its entire body was decoded.

Static counters on the same pinned fictional PDFs isolate the work-limit source. Each of the five affected inputs has 1,094 stroked segments; parsed operators are at most 13,965, graphics-stack depth zero, one concurrent path, and two vertices per path. Thus callback, stack, path, vertex and rule-count guards cannot explain their `limit`. The exact production `PDFPathReader.overlapsText` scans every glyph box for every disjoint stroke, charging the shared `maximumPaintWork=1,000,000` budget. If all main-page strokes and glyphs are disjoint, that full page would require 9,571,406 collision charges. This is a conditional static total, not an emitted native operation counter. The actual code/trace plus elimination of the other guards identify the paint-work guard. The production owner handles the algorithm correction; no limit was raised in this probe.

Only the independently invented public [generator](../../tools/independent-wide-timetable/README.md), fixed source and public pinned font produced these inputs. Primary v1 remains the regression; v2 only varies unused font selection. No uploaded/private PDF, image, teacher, subject, room, timetable association or OCR output was used. PDF/font binaries are absent from Git and were temporary CI files. OCR requests and model invocations were both zero.

The first [run 37221400765](https://github.com/n624-dev/takupoke-ios/actions/runs/37221400765) failed compiling an omitted public constant dependency before any Reader call. Its failure is preserved as an execution result with native calls zero, separate from this finite cohort.

`*.raw.json` are gzip/base64 storage envelopes for the original UTF-8 bytes, with original byte counts and hashes. Decode with `analyze.py`; storage never replaces original bytes. `expected.json` is independently generated assertion data and entered no Reader/parser/recovery call. The analyzer compares literal slots only if an actual Analysis exists; here it makes no 680-slot assessment.

```sh
python3 -B analyze.py . /tmp/ios-vector-derived.json
```

The output reproduces `derived-evidence.json`. `static_budget.py` can recompute the source counters from locally regenerated fictional PDFs using pinned PyMuPDF; its output names the conditional estimates and the unexported native counters explicitly. This data-only publication invokes no additional native measurement.
