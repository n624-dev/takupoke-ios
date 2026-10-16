# 独立架空PDFの17クラス・5日全時限比較（研究）

対応関係・宣言名・実行方法のSHA-256：
`b71b848a83c1e49f549b2462acf8e1aa472777fe0b57d5546c197dcc46b9af70`

環境：Apple SDK26、2字体×通常／試験／返却の6job。本文・クラス取得の比較で正式採用や実機合格とは別

```bash
bash tools/ocr-document-qualification/run.sh
TAKUPOKE_OCR_FULL_FONTS=<owned-pinned-fonts> python3 -B -m unittest discover -s tests -p test_ocr_document_qualification.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-document-qualification.yml](../../.github/workflows/ocr-document-qualification.yml)
- [tools/ocr-document-qualification/generate.py](../../tools/ocr-document-qualification/generate.py)
- [tools/ocr-document-qualification/protocol.json](../../tools/ocr-document-qualification/protocol.json)
- [tools/ocr-document-qualification/run.sh](../../tools/ocr-document-qualification/run.sh)

## [tests/test_ocr_document_qualification.py](../../tests/test_ocr_document_qualification.py)

- `test_all_six_frozen_sources_have_all_classes_days_periods_and_image_only_pixels`
- `test_frozen_case_reproduces_pdf_and_oracle_without_reading_model_output`
- `test_unknown_case_and_overwrite_are_rejected`

## [tests/RecoveryDocumentQualificationTests.swift](../../tests/RecoveryDocumentQualificationTests.swift)

- `testAcquireCompleteFrozenOriginalSource`
