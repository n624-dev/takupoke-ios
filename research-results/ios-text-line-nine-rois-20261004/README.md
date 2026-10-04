# Fixed captured-line OCR comparison (fictional data only)

Native source `3e319d1d2b8e86db4aba73f489d9de0b72803f8f`, [run37217403883](https://github.com/n624-dev/takupoke-ios/actions/runs/37217403883), attempt1. One finite9-request phase. SDK/12Python checks/native execution/owned cleanup succeeded. No document OCR, whole-page OCR, model download or production source changes ran in this phase.

All nine top1 observations below `.85` in the immutable prior half-page capture selected geometry-only ROIs. `floor(min)-2` / `ceil(max)+2`, clipped to the original image, was frozen before execution. Every ROI contains only lossless original pixels, with no resize. Raw candidate text, expected values and posthoc drawing evidence were absent from native ROI selection/input. Original PDFSHA `233dec852ec7e43c93c70c42d8f88238a0c2e8aef146445c4b94d674bb6cc187`, originalPNG SHA `1778ddd50e7d267b77b561df7e0fc17eae82fa68693bd2d74c76132f738ade57`, originalRGBA SHA `ea88aabe36bfd799029b644f42467a47c9cf9e32f0691807b2b156ea1daf58b9` were unchanged. The original renderer statements/21 immutable helper and workflow files remain pinned in source/input receipts.

Native original and crop CGImages use8bits/component,32bits/pixel, stride3936, bitmap8194, alpha2 and DeviceRGB. Crop strides retaining the original row width are recorded, and all decoded RGBA slices exactly match their original regions. The probe verified original format, PNG and provider pixel SHA before requests.9planned/attempted/returned/serialized,0operational errors. Actual native wall149.075s includes uninstrumented render/startup; the receipts retain per-ROI time without attributing framework internals.

| Targeted9 printed positions | Prior half-page | New line ROI |
|---|---:|---:|
| Matching text and physical observation center |9|8|
| Matching text/range centers plus unchanged confidence/box guards |0|1|

Only the title improved from confidence`.5` to`1` and passed the diagnostic guards. Year remained`.5` with one negative original character range x; all six targeted period labels(1,2,4,6,7,8) remained`.3` or`.5`, so0/6passed. The printed class`5_ES` regressed to two observations`5` and`LES`; it is a recognition error, not repaired evidence. The character `5` at the class position is **not** evidence for period5. This route stops here because it did not recover the needed period/class confidence reliably.

`月`, period3 and period5 were high-confidence prior observations and remain explicitly **unrequested** in this phase. `derived-evidence.json` independently compares all12printed header positions across the prior full-page, prior half-page and new line observations, separating raw text inventory, literal UTF8 match, whitespace-removed diagnostic comparison, observation/range position and guards. Thus inventory text cannot stand in for correct positioning. All raw input/output bytes are preserved; whitespace removal occurs only in named posthoc metrics. Range boxes are native API responses, not precise glyph extents or unique ownership.

Reproduce from this folder with Pillow available:

```sh
python3 analyze.py native-raw.jsonl ../ios-text-crop-one-page-20261004 roi-manifest.json .
```

The prior folder is immutable commit`ab8927db8db4f6809989ff46b47208e0f1dba61b` data. Its raw capture SHA is `feeb3cdd4ea2f930f305cc94050c8ba5ba018a10ba259f7a14abc8823ca8b78c`; required predecessor file hashes are listed in the publication manifest.

No new source adapter, corrected/filled text, EMPTY state, tuple binding, Rules/Validator acceptance, manual adoption or last-good changes were claimed. Physical iPhone behavior and recovery/model quality remain unqualified. All evidence is independently invented fictional material; no actual school PDF or its data entered this source, native execution or publication.
