# iOS Vision: same two original PDFs, acquisition only

[Actual CI 37206582959](https://github.com/n624-dev/takupoke-ios/actions/runs/37206582959) completed successfully from [source 0294fd6](https://github.com/n624-dev/takupoke-ios/tree/0294fd6eb8d8c5695ed7de6302523d1c46dc284e/tools/vision-acquisition-probe). Apple iOS Simulator SDK 27.0 compiled the source-extracted original `PDFRecoveryRecognition.read` method; each of ten pages received one `RecognizeDocumentsRequest`. No language model, Core AI, gold text, drawing plan, new OCR preset, or second native measurement was used.

| Observation | Actual result |
| --- | --- |
| Public `.read` API returns | 10/10 pages |
| Completed post-observation diagnostics | 10/10 pages |
| Operational errors | 0 |
| Pages passing the original `.layouts` confidence/box predicates as diagnostics | 0/10 |
| Low-confidence lines | 41 of 79 emitted lines |
| Invalid character-box predicates | 9: year-first `2`, x = −0.0265 to −0.1021 pixel |
| Page-one lesson body values matching the literal original | 6/6 diagnostic values, including one empty value |
| Verified blank/ink coverage or formal recovery assessments | 0 / unassessed |

Both page-one subjects, teacher text, and room text were correctly observed; the blank-teacher control returned `担当：` without a body. That does **not** independently prove an EMPTY cell. Body-line confidences were about 0.915–0.981. Correct-looking period/class candidates also returned confidence below the unchanged 0.85 floor, so every page fails that diagnostic. The nine negative year-character x coordinates independently fail the existing nonnegative box condition. Nothing was clamped or repaired.

Some printed periods, including 5–8, are absent from the serialized `document.text.lines`. Structured tables and the full transcript were not serialized. The [official API](https://developer.apple.com/documentation/vision/documentobservation/container/text-swift.property) describes container text as “All the text found within the container”; separate table-cell APIs do not establish that these numbers exist only there. Whole Vision omission versus line/structure representation remains undetermined. This evidence does not justify a duplicate table merge or establish an intrinsic OCR-model limitation.

These are the exact already-consumed Windows development PDF bytes, rebuilt losslessly from the same pinned original PNGs. iOS `.read` actually rendered 984×197 and 984×201 pixels, while the original PNG width is 1025. `.read` uses a fractional thumbnail size; `.layouts` rounds up and also constructs a raster. The helper never called `.layouts`, Builder, Rules, Validator, or formal conversion. Character-box area is not original ink coverage. **0/10 diagnostic passes is not a 0/2 formal-recovery accuracy result**, and correct body text alone is not a qualification pass. Rendering, confidence calibration, segmentation, and representation contributions cannot be isolated by this single experiment.

Actual host: Apple M1 (Virtual), 3 logical CPUs, 7,516,192,768 bytes host RAM; iOS 27.0 simulator / SDK 27.0, Xcode 27.0. Native command elapsed 49.85 seconds for all pages. These are host-backed simulator observations, not physical iPhone memory, speed, UI, or minimum-device evidence. No model catalog was activated. The finite measurement is complete; no threshold/preset/model sweep follows it.

[Results](results.json), [per-page causes](ten-page-causes.json), [execution identity](execution.json), [exact raw bytes](raw-evidence.json), [three independent reviews](independent-reviews.json), [read-only API investigation](api-investigation.json), and [source freeze](source-freeze.json) retain the evidence. SHA-256 values for all eight files are in [checksums.json](checksums.json). Native JSONL is 91,880 bytes, SHA `d5ce20d53565920930f365db47e7f24828ea2217f827e1ff2cb72ce7de39a191`; complete decoded job log is 150,944 bytes, SHA `803a4e325570871d4c037ecd5e9dcb5de3aa348e20b86972f8952b449c8d7071`. The cause list is posthoc comparison against separate original literals; none entered native inference.
