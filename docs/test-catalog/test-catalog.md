# テスト一覧・対象検索・更新強制・CI接続

対応ソース・テストのSHA-256：
`07100f142bc4de0d382ac913564d8b873f762cd74aa30a49043a65d4f6251aaf`

環境：Linux Python（隔離Gitリポジトリ）

```bash
python3 -B -m unittest discover -s tests -p test_test_catalog.py -v
```

## 変更時に確認するソース

- [.github/workflows/ios-release.yml](../../.github/workflows/ios-release.yml)
- [tests/test-catalog.json](../../tests/test-catalog.json)
- [tools/test_catalog.py](../../tools/test_catalog.py)
- [tools/test_catalog_inventory.py](../../tools/test_catalog_inventory.py)

## [tests/test_test_catalog.py](../../tests/test_test_catalog.py)

- `test_changed_runtime_requires_corresponding_test_and_updated_document`（宣言行 62）
- `test_comments_and_formatting_do_not_qualify_as_a_test_change`（宣言行 73）
- `test_new_source_without_mapping_is_rejected`（宣言行 81）
- `test_unregistered_test_and_missing_registered_file_are_rejected`（宣言行 86）
- `test_deleting_tests_cannot_qualify_runtime_changes`（宣言行 95）
- `test_document_only_changes_do_not_require_test_edits`（宣言行 102）
- `test_renamed_source_keeps_the_previous_test_requirement`（宣言行 106）
- `test_new_corresponding_case_file_can_qualify_existing_runtime_changes`（宣言行 115）
- `test_stale_or_obsolete_generated_documents_are_rejected`（宣言行 124）
- `test_integration_case_can_cover_two_sources_without_duplicate_source_ownership`（宣言行 133）
- `test_search_finds_case_and_source_names`（宣言行 145）
- `test_inventory_distinguishes_declarations_from_theory_expansions`（宣言行 149）
- `test_workflow_enforces_changed_code_against_event_base`（宣言行 157）
