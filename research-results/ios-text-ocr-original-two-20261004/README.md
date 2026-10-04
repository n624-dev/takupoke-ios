# Ordinary accurate text OCR: same original two PDFs

The one finite [native run 37210746428, attempt 1](https://github.com/n624-dev/takupoke-ios/actions/runs/37210746428)
at source `c9f9480b400189b92c6d7753c7ccb1c2957f56ef` succeeded. It compiled against
the actual iOS simulator SDK and made ten `RecognizeTextRequest` requests on iOS
27.0, revision 3: ten planned, attempted, returned and serialized pages, zero
operational errors. It did not call document OCR, app recovery or a language
model. Native processing took about 149 seconds; this is a simulator observation,
not physical iPhone validation or a formal recovery qualification.

Settings were accurate recognition, priority languages `ja-JP`/`en-US`, language
correction and automatic language detection disabled, no custom words, one top
candidate, and the unchanged native minimum height fraction `0.03125`. Supported
languages and actual revision/settings are in the raw environment record.

| Printed evidence | Exact raw text at original position | Original confidence and box predicates pass |
| --- | ---: | ---: |
| Periods 1–8 | 36 / 80 | 7 / 80 |
| Class labels | 10 / 10 | 0 / 10 |
| Weekdays | 10 / 10 | 9 / 10 |
| Nonblank printed subject/teacher/room values | 5 / 5 | 5 / 5 |

Period positions by digit were `1:9, 2:9, 3:10, 4:8, 5:0, 6:0, 7:0, 8:0`.
The [previous independent document OCR phase](https://github.com/n624-dev/takupoke-ios/tree/d49b135f65b18e946edd506c28fd90da6e61df0d/research-results/ios-vision-hierarchy-20261004)
found 33/80: this comparison gains four positions and loses one, with 32 shared.
Both phases lack all 40 physically printed period 5–8 positions. Current raw
top-1 lines contain no standalone period candidates `5`, `6`, `7` or `8`.
Those digits can appear inside class/year strings; such occurrences are not period
evidence. `rawExactSubstringExists` deliberately counts raw substring presence
separately from position: it is 52/80 and is not the 36/80 positional result.

The captured PNGs are lossless encodings of the same CGImages passed to text OCR,
encoded before each request. All ten decode with matching recorded hashes and
dimensions (984×197 / 984×201). All eight period labels are readable on all ten
PNGs in manual inspection. Original drawing ink boxes mapped to actual image
dimensions contain dark pixels in 80/80 regions, including all 40 period 5–8
regions. Pixel counts alone do not identify a digit; the images support the
separate manual visibility observation. The previous document run did not save
native images, so matching source/render recipe does not prove its pixel bytes
were identical.

Class labels are retained exactly but have confidence 0.3 or 0.5, below the
unchanged 0.85 predicate. Every page fails the original combined diagnostics.
Confidence is not presumed calibrated equally across the two APIs. Individual
Swift Character range boxes are retained exactly as returned; accurate OCR boxes
are not assumed to have precise glyph geometry. The position analysis excludes
identical box sharing with other nonspace characters, without claiming that this
proves precise boundaries or unique cell ownership.

These results do not justify changing the production OCR path or lowering its
threshold. No period was inserted, no missing observation was called empty, and
the blank teacher value is excluded from the printed-value count. Rules/cells,
source-text ownership, semantic tuple binding, validator output, explicit adoption,
last-good data and physical device behavior remain unassessed. The results cannot
identify the framework's internal detection, model or threshold cause, or prove
absence from latent candidates. Existing generation models remain unqualified.

Files preserve the exact native stdout bytes (`native-raw.jsonl`, SHA-256
`af08b6eae78ec40902de6cec9304182aab22aa3cb32f4348b1a438fb49e684f0`, 382507 bytes),
native execution/source/settings receipts, the immutable input manifest, all ten
decoded native PNGs, and offline comparison evidence. `drawing-source/` is solely
posthoc fictional evidence and was never passed into the native process. The
source pins, original helper/input files and both original PDF SHA-256 values are
unchanged. Original raw output is retained without text normalization or box
correction. No Actions artifact/cache, main branch, release or AltStore changes
are involved. Publication changes only this results directory and does not
trigger another native request.

To reproduce the current-run text/position/ink diagnostics offline with Python
and Pillow from this directory:

```sh
python3 analyze.py native-raw.jsonl input-manifest.json drawing-source /tmp/text-ocr-offline-output
```

The generated `derived-evidence.json` is deterministic; generated PNG hashes match
`native-render/`. `render-inspection.json` separately records the manual inspection
and pins the previous public evidence used for the four gains/one loss comparison.
