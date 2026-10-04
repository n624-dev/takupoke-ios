# One finite captured-line text OCR diagnostic

Independent source phase based on `ab8927db8db4f6809989ff46b47208e0f1dba61b`.
`prepare.py` selects **every** top1 observation with finite confidence below the unchanged `.85` guard from the previously captured two half-page requests. Selection never reads text or character boxes. Nine observed lines produce nine fixed integral ROIs, using floor(min)-2 / ceil(max)+2 and clipping only to the original image bounds; maximum16 requests.

Native inputs are unchanged fictional PDF assembly/input pins plus the geometry-only ROI manifest. The native probe renders the first literal page once with the original thumbnail statements, verifies originalCG metadata, PNG bytes and original provider pixels against captured SHA values **before requests**, and applies `CGImage.cropping` with no resize. Verification reads BGRA into canonical RGBA for hashing only; that buffer never enters OCR. The original CGImage and its lossless crops enter OCR.

The same modern `RecognizeTextRequest` accurate Japanese/English configuration uses no correction, autodetection or custom words. The default minimum height `.03125` is checked without changing it. Top1 raw strings/confidence/native order and API-returned range boxes retain both local and original coordinates, including both x/y offsets. Range boxes are not asserted to be precise glyph extents or unique ownership.

One source push starts this branch's opt-in native workflow. No other page or full-page request executes. No model download, correction, expected values, gold, threshold relaxation, application adapter or state change. Printed labels/classes/periods and errors are evaluated independently after capture. This component observation does not qualify recovery, empty states, formal tuples, models or physical iPhone behavior.
