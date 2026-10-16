# iOS ASCII CPU parity (research only)

The fixed English V1 model has two inputs (`x`, `valid_width` INT64[1]) and two
outputs (`probabilities`, `reject_probability`). The V6 single-input runtime proof
does not establish this contract. No application or Strict source is compiled here.

Run `TKPK_PARITY_IOS=26 bash tools/ocr-ios-ascii-runtime-parity/run.sh` on the matching
Apple runner, or choose 27 with its matching Xcode. The workflow runs both without
cancelling the other job. Inputs are the already consumed independent fictional
144-field screen, two frames per field. This is not fresh accuracy evaluation.

The unchanged native Swift transform receives only original RGB8 pixels. All 292
transforms (including four asymmetric control images) must equal reference bytes,
widths and hashes. C++ receives the native transform's actual values, not reference
FP32 files. It constructs and reads back the actual INT64 OrtValue used for Run.
All 288 full probability tensors must differ from CPU reference by at most 5e-5,
with exactly equal greedy literals, CTC intervals and every piece's .85 decision.
The reject tensor's original full value, domain, tolerance and <=.05 decision must
also agree; equal greedy text alone is insufficient. No optional execution provider
is registered. Models and official runtime are pinned, downloaded separately, and
never packaged into the app by this study.

Owned simulator boot, selected-Xcode frontend, actual spawned UDID/OS/PID checks,
120-second per-result deadline and cleanup reuse the previous qualified helper.
The Swift transform process reports its actual Runtime/UDID/PID; the separate C++
inference process reports its own actual UDID/PID and compiled iOS Simulator target.
Both are checked independently and named separately in the receipt. The C++
Runtime is established by its actual owned Simulator spawn, not a second OS-version
API read in that process.
No global device-list query is inserted after boot. The actual iPhone SDK is linked
as a separate check; simulator execution does not prove physical iPhone performance,
full-source acquisition, reader accuracy, Builder/Validator success or adoption.
Temporary assets, probability files and the owned simulator are removed on exit.
No cache, artifact, school material, oracle, cloud inference or additional training.
