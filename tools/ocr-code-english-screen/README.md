# Original code glyphs: native English versus fixed EnglishV1

Research only; no application, Strict, default route, model catalogue or adopted data changes.

The current consumed whole-PDF cohort's residual errors are predominantly missing I and O/0.
This separately frozen screen draws192 short, fictional codes (16 literals ×6 sizes ×2 already consumed fonts).
Readers receive only numbered original RGB8 byte files/dimensions/hashes, without word/font/size metadata.
VNRecognizeTextRequest revision3 uses accurate/en-US/correctionOFF/no customWords and a CGImage backed by exactly
those bytes, independently read back before each actual call. No enlargement or interpolation is introduced.
Fixed EnglishV1 runs the existing Windows transform on the same original bytes. No model training occurs.

The comparator reads the oracle only after both192-call readers finish. It prints every original native candidate,
character range, confidence, CTC piece and source hash before any comparison failure. It reports literal accuracy,
native0.85 wrong outputs and the model's own0.85/reject0.05/padding wrong outputs separately; there is no voting,
confidence-domain conversion, name table or automatic result selection. API/character geometry errors fail after
their original output is retained. A native rectangle outside the small input is counted separately, never clamped.

This metric is explicitly literal recognition, not the old crop-containment metric, physical field ownership,
whole-document conversion, unseen-font quality, iOS runtime or physical-phone qualification. Model/crop results
from earlier screens are not directly comparable without independently matching their actual pixels.
The mixed-language legacy screen's two high-score complementary gains were Japanese variants, not evidence of a
room-code improvement. This English-only study must establish its own relevant result before any broader study.

Run `bash tools/ocr-code-english-screen/run.sh` on SDK26. Only owned scratch is removed. No cache/artifact is used.
