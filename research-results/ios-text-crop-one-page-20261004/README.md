# Two lossless crops retain all eight printed periods on one page

The one finite [native run 37212811710, attempt 1](https://github.com/n624-dev/takupoke-ios/actions/runs/37212811710)
at source `685ea5ba9f055c619b560b1c8a88698b5790b8f8` succeeded: two planned
requests, two returned/serialized region records, zero operational errors. The
original page was rendered once and received no full-page OCR request. Only page
one of the unchanged fictional literal PDF was used; no other page was measured.

The left crop returns printed periods `1,2,3,4`; the right returns `5,6,7,8`.
All eight raw Character-range box centers map to their original header cells without
sharing an identical box with another nonspace character, and all overlap the
original drawing ink boxes. All eight range boxes are also fully contained in
their printed header cells, recorded as a separate metric. The previous ordinary full-page run retained only
`1,2,3,4` on this page. These are component observations, not eight qualified
semantic tuples or a whole-document quality result.

| Evidence | Result |
| --- | --- |
| Exact raw periods at original positions | 8 / 8 |
| Periods 5–8 at original positions | 4 / 4 |
| Unchanged 0.85 confidence + original box predicates | 2 / 8 (periods 3 and 5) |
| Original PNG byte-equal to prior full-page PNG | Yes |
| Both crop RGBA pixel arrays equal original slices | Yes |

The original CGImage is 984×197, cropped at x=0,width=508 and x=476,width=508:
32 pixels overlap, full height, no resize. All three images have 8 bits/component,
32 bits/pixel, bytesPerRow=3936, bitmapInfo=8194, alphaInfo=2 and DeviceRGB with
three components. Native original/crop metadata and PNG hashes are retained.
The original PNG SHA-256 is
`1778ddd50e7d267b77b561df7e0fc17eae82fa68693bd2d74c76132f738ade57`.
All three images were decoded, hash checked and visually inspected. The crop
pixel checks compare each decoded RGBA sample with the matching original slice.

OCR settings remain accurate recognition, revision 3 on the iOS 27.0 simulator,
priority `ja-JP`/`en-US`, correction and automatic detection disabled, no custom
words, default minimum text height fraction 0.03125, one top candidate. The actual
supported languages and settings are recorded. There is no text normalization,
box clipping, rescaling, inserted period, expected-value input, model download or
model request. Original source/image/PDF pins are unchanged. Drawing source and
the previous page record are posthoc evidence only and never entered this run.

Periods 3 and 5 have confidence 1; periods 1,2,4,6,7,8 have confidence 0.5. The
class label also has confidence 0.5. Both region-wide original diagnostics fail.
The unchanged confidence threshold blocks qualification; it has not been lowered
or treated as calibrated equally across APIs. Raw range boxes do not prove precise
glyph extents or unique cell ownership. Both overlapping regions' observations
remain separately identified, without a merged or deduplicated source transcript.

Image subdivision changes the returned observations while preserving sampled
pixels. This supports further bounded spatial preprocessing work. It does not
identify a proprietary detector/model/ROI/stride algorithm or an internal failure
stage. No inference is made about other pages, documents, physical iPhone quality,
empty cells, validator/semantic tuple binding, rules, adoption or last-good data.
Production and generation model qualification remain unchanged; formal assessed
count is zero. No repeated measurement or preset sweep followed this result.

Native process time was about 148.6 seconds, with recorded region times of about
43.5 and 3.3 seconds. Process time includes startup/render/serialization; the
uninstrumented remainder cannot be assigned to a particular operation. Bootstatus
reported already booted, and the boot command has no individual timer. CI confirms
Python suites of 3+1+2=6 tests and actual Apple SDK compilation; the corrected region
receipt parser was also checked locally by producer and root.

`native-raw.jsonl` preserves the exact native stdout bytes: 101809 bytes, SHA-256
`feeb3cdd4ea2f930f305cc94050c8ba5ba018a10ba259f7a14abc8823ca8b78c`.
The previous page-one JSONL is an exact selected line from the
[independent ordinary run](https://github.com/n624-dev/takupoke-ios/tree/0f74e19d65659b3a0c0e344cdf253ab4bc122dcf/research-results/ios-text-ocr-original-two-20261004),
with the whole-source and excerpt hashes in `previous-reference.json`.

From this folder, reproduce pixel/inverse-coordinate/eight-position diagnostics
offline using Python and Pillow:

```sh
python3 analyze.py native-raw.jsonl previous-page-one.jsonl input-manifest.json drawing-source.json /tmp/text-crop-offline-output
```

The generated evidence is deterministic and PNG hashes match `native-render/`.
This data-only publication triggers no extra OCR, cache/artifact, main, Release or
AltStore write.
