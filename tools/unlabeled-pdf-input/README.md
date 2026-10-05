# Lossless invented image-only PDF input

This research adapter materializes the already consumed, entirely invented unlabelled 40-slot development image as one image-only PDF. It preserves the original 3740×800 RGB pixels, the public pinned Noto Sans CJK JP Regular font, all drawing positions and text. It does not create another heldout case or change the oracle. Source records and a font license are tracked; PDF, PNG and font binaries are temporary and must never be committed.

The adapter runs only the pinned pixel renderer's `render` function. It never invokes the renderer's creation entry point, reads the evaluator glyph/role inventory, or reads a formal oracle. The PDF has no text or font objects. It uses a lossless RGB FlateDecode image with `Interpolate false`, 3740×800 MediaBox/CropBox and rotation zero. Original source top-left pixels map to PDF bottom-left coordinates by `(x,800-y)`.

Install Python dependencies from `requirements.txt`, provide the public font whose SHA256 is `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a`, and run:

```sh
mkdir /tmp/owned-invented-pdf
printf 'unlabeled-pdf-input-v1\n' > /tmp/owned-invented-pdf/.owned-unlabeled-pdf-input
python3 tools/unlabeled-pdf-input/generate_pdf.py --font /path/to/NotoSansCJK-Regular.ttc --owned-output /tmp/owned-invented-pdf
python3 -m unittest discover -s tools/unlabeled-pdf-input -p 'test_*.py'
```

The owned directory must exist and contain the exact marker; existing outputs are never overwritten. Before writing the PDF, PyMuPDF decodes the actual embedded image and renders the actual page at 1×. Both must equal the original RGB/RGBA bytes. The receipt separates PNG, PDF, embedded RGB and rendered RGBA hashes. This check is independent of the later Apple/Windows PDF renderer: each native renderer must record its own dimensions, transform and pixel hashes. Same PDF bytes do not imply same cross-OS rendered pixels.

The fixed PDF SHA256 is `7ceb34d191dc48a5d6bc072e75898172cd20f356f6c9c312f558635d6a454323` (41545 bytes). This is preparation evidence only. Native Reader status, OCR confidence, full-page ink/source ownership, the unchanged Validator and formal 40-slot comparison remain separate measurement stages. Native OCR receives actual PDF-rendered pixels only; gold is assertion-only after results return. No model calls, production adapter activation or OCR/model qualification are established by these tests. Delete the owned temporary outputs after all consumers finish.
