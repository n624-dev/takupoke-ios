# Ordinary accurate text OCR comparison

This independent diagnostic performs exactly ten `RecognizeTextRequest` requests,
one for each page of the same two immutable fictional image-only PDFs verified by
the unmodified `vision-acquisition-probe/prepare.py` and its manifest/source pins.
It does not execute `.read`, `.layouts`, `RecognizeDocumentsRequest`, an app
recovery pipeline or a generation model. The extracted original declarations are
compiled only to reuse the original error types; the extracted thumbnail
statements execute in `OriginalTextRaster.render` without any changes.

The original fractional thumbnail `CGSize` and `min(2, 2048/max(bounds))` remain
unchanged. Each CGImage is generated once, encoded to a bounded lossless PNG before
OCR, recorded with SHA-256/base64 bytes, and passed directly to its one OCR request.
No PNG is decoded for OCR. Native output retains observation order, top-1 text,
confidence, observation boxes, and every Swift Character range's raw API box or
missing response. The original `0.85...1` confidence and rectangle predicates are
recorded only as diagnostics; they neither filter text nor prevent later pages.
Range boxes are API responses, without a claim of precise character geometry.
No missing cell is called empty, no missing period is inserted, and formal quality
assessment remains unassessed.

Settings: `.accurate`, priority languages `ja-JP`, `en-US`, language correction and
automatic language detection disabled, no custom words, one top candidate. Native
runtime support is checked before requests; a missing language fails the finite
comparison instead of choosing another setting. There are no resolution, preset,
seed or revision sweeps. Expected values and drawing-source evidence never enter
the native process. Any later comparison uses raw results offline.

Apple API contracts consulted before implementation:

- [RecognizeTextRequest](https://developer.apple.com/documentation/vision/recognizetextrequest)
  is available from iOS 18; the comparison runs on the iOS 27 simulator.
- [recognitionLevel](https://developer.apple.com/documentation/vision/recognizetextrequest/recognitionlevel-swift.property)
  supports accurate recognition.
- [recognitionLanguages](https://developer.apple.com/documentation/vision/recognizetextrequest/recognitionlanguages)
  accepts `[Locale.Language]` in priority order;
  [supportedRecognitionLanguages](https://developer.apple.com/documentation/vision/recognizetextrequest/supportedrecognitionlanguages)
  reports runtime support.
- [usesLanguageCorrection](https://developer.apple.com/documentation/vision/recognizetextrequest/useslanguagecorrection)
  disabled returns raw recognition results.
- [boundingBox(for:)](https://developer.apple.com/documentation/vision/recognizedtext/boundingbox(for:))
  has normalized lower-left coordinates and is not always an exact character fit.
  Apple's [stable accurate API documentation](https://developer.apple.com/documentation/vision/vnrecognizedtext/boundingbox(for:))
  explicitly describes word precision even for individual character ranges; this
  diagnostic makes no stronger precision claim for the newer API.

The separate branch push workflow performs the finite native run once; do not
manually dispatch a duplicate. It uses an owned simulator, bounded raw transport,
job-local scratch cleanup, logs only, no Actions cache/artifact, and no release or
AltStore changes. Linux verifies immutable inputs and extraction; it does not
simulate Vision or claim native API compilation. The renderer PNGs also permit
posthoc inspection of whether original printed ink survives native rendering.
