# One-page, two-region ordinary OCR comparison

This independent component diagnostic renders only page one of the unchanged
original fictional literal PDF once, using the same extracted `.read` thumbnail
statements. It runs exactly two ordinary `RecognizeTextRequest` requests, one on
each lossless `CGImage.cropping` region: integer midpoint minus/plus 16 pixels,
32-pixel overlap, full height, no resizing. At original width 984 the regions are
left x=0,width=508 and right x=476,width=508. There is no full-page OCR request and
no other page request. The unchanged preparation helpers verify both original
input PDFs/source pins, but the native process reads only the selected PDF page.

It retains the accurate Japanese/English settings from the previous diagnostic,
with language correction/automatic detection disabled, no custom words, unchanged
minimum text height, native supported language/revision receipts, and the original
0.85 confidence predicate as a diagnostic only. No expected digits or drawing
source enter the native process. Native region order/top-1 text/confidence and
unmodified Character-range boxes are retained. Original top-left coordinates are
derived only by adding the crop x offset; no clipping or geometry correction is
applied. Repeated boxes do not prove precise character geometry.

Original and both crop CGImages record width/height/bits per component/bits per
pixel/bytes per row/bitmapInfo/alphaInfo/color space and lossless PNG+SHA before OCR.
The original PNG is emitted before requests; each crop record is emitted after its
request, so a process kill may leave the current crop unknown. Apple documents
[`CGImage.cropping(to:)`](https://developer.apple.com/documentation/coregraphics/cgimage/cropping(to:))
as creating a bitmap image from the specified rectangle; this probe passes the
crop CGImage directly to OCR and never decodes or resizes its PNG.

This tests a single input-width question after the original ten-page text probe
missed all physically printed period 5–8 positions despite their visible native
pixels. It is neither a preset sweep nor a quality/recovery qualification. No
period is filled in; no missing cell becomes empty. No app pipeline, generation
model, model download, validator/adoption/last-good update runs. If this comparison
does not improve observed text, do not loop this method. A separate branch's one
push triggers native SDK compilation and this finite two-request run, without a
manual duplicate, Actions cache/artifact, main, Release or AltStore writes.
