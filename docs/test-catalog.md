# テスト一覧と変更時の必須手順

この一覧はソースの宣言と対応表から生成する。成功件数や品質合格の記録ではない。
Theoryの入力展開・条件付きskip・CI実行件数は別の検証記録で確認する。
同じテストを複数分類から参照するため、分類別宣言数の合計は実行件数ではない。
対応付けは変更時に確認すべきテストを示し、各ファイルの全動作を検証済みとは保証しない。

1. 編集前に対象ファイル名・機能・ケース名で下記のsearchを実行する。
2. 新仕様・未検出の不具合にはテストを更新する。既存ケースで十分なら不要な編集をしない。
3. 該当ケース・十分性の理由・実行環境・結果を検証記録へ残す。
4. 対応関係・宣言名・実行方法が変わったらwriteし、check --baseで対象を確認する。
   未登録コード・未登録テスト・古い一覧はCIを失敗させる。
   テスト本文の編集は一律に要求しない。十分性は変更内容と実行結果から確認する。
   一覧の再生成はテスト実行の代わりにならない。

```bash
python3 tools/test_catalog.py search 曜日
python3 tools/test_catalog.py write
python3 tools/test_catalog.py check --base <編集前のコミット>
```

CIはpushのbefore、PRのbase、手動実行ではHEADの親を比較する。
ファイルの削除や移動でも以前の対応テストを検査する。
取得・解析・保存をまたぐテストは、関連する複数の対象から参照する。

| 対象 | 宣言数 | 検証する環境 |
|---|---:|---|
| [時間割変更・曜日・行除外・原文保持](test-catalog/xlsx.md) | 37 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [原本取得・更新・保存・File Provider](test-catalog/material.md) | 35 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [ローカルDB・移行・半期削除](test-catalog/database.md) | 40 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [日本時間・学校年度・日付表示](test-catalog/date.md) | 9 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [リンク・検索・設定保持](test-catalog/links.md) | 10 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [名称対応・パッケージ・認証取得](test-catalog/mapping.md) | 36 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [学校行事API・年度別保存](test-catalog/events.md) | 13 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [時間割・今日の予定・授業時刻・授業名](test-catalog/timetable.md) | 76 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [試験・返却PDF](test-catalog/special.md) | 45 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [Strict PDF・文字・位置・罫線](test-catalog/pdf.md) | 115 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [PDF復旧・OCR・構造・Validator・端末内Provider](test-catalog/recovery.md) | 210 | Linux Swift／Apple Native（PDFKit・VisionはApple限定） |
| [確認訂正・画像比較・入力変更・実操作](test-catalog/manual.md) | 89 | Apple iOS26/27＋Linux契約検査。実機・モデル品質は別確認 |
| [通知許可・実配信・設定・バックグラウンド](test-catalog/notifications.md) | 14 | Apple iOS26/27 UI＋Native。自然なバックグラウンドは実機限定 |
| [通常画面・設定・実Switch・UI fixture・登録一覧](test-catalog/app-ui.md) | 102 | Apple iOS26/27。LinuxはPython契約検査のみ |
| [ファイル選択・再選択・背景・キャンセル](test-catalog/picker.md) | 6 | Apple iOS26/27 UI＋Nativeレイアウト |
| [IPA・AltStore・公開ゲート・ビルド・一時領域](test-catalog/release.md) | 88 | Linux Python／Apple iPhone SDK。AltStore導入は実機限定 |
| [独立した架空PDF・原文契約・固定期待値](test-catalog/fixtures.md) | 13 | Linux契約検査。PDF描画・OCRはApple限定 |
| [テスト一覧・対象検索・宣言整合性・CI接続](test-catalog/test-catalog.md) | 54 | Linux Python（隔離Gitリポジトリ） |
| [Windows OCR候補のApple原画素比較（認識器の研究）](test-catalog/ocr-transfer-screen.md) | 9 | Apple macOS26／配布SDK27。iPhone・文書全体・採用合格は対象外 |
| [iOS CPU Runtimeの原確率・CTC照合（研究）](test-catalog/ocr-ios-runtime-parity.md) | 13 | iOS26／27 Simulator実プロセス＋実iPhoneSDKリンク。物理iPhone・全文書採用は別確認 |
| [全PDF原画素・実罫線からのOCR領域取得比較（研究）](test-catalog/ocr-full-source-transfer.md) | 26 | macOS26/PDFKit/Vision・実RecoveryRasterGrid。各条件444値×2描画条件、初期探索であり正式採用・iPhone品質ではない |
| [独立架空PDFの17クラス・5日全時限比較（研究）](test-catalog/ocr-document-qualification.md) | 4 | Apple SDK26、2字体×通常／試験／返却の6job。本文・クラス取得の比較で正式採用や実機合格とは別 |
| [ASCII OCRのiOS 2入力・2出力CPU照合（研究）](test-catalog/ocr-ios-ascii-runtime-parity.md) | 20 | iOS26／27 Simulatorのnative Swift前処理＋C API。iPhone SDKリンクと実機実行は別 |
| [OCR研究の有限数値レシート・原文の非送信](test-catalog/ocr-research-receipt.md) | 5 | Linux Python。実推論／精度合格は各Apple研究jobで別検証 |
| [全17クラス・5日・全時限の原PDF2x固定比較](test-catalog/ocr-full-scope-source2x.md) | 9 | Apple SDK26。既使用の独立架空6資料、現行2048 V6の失敗とは別条件 |
| [従来型Vision・原画素4倍反復の認識器探索](test-catalog/ocr-legacy-line-screen.md) | 5 | Linux比較器／Mac SDK26 Native Vision（研究専用） |
| [原教室コード・英語専用VisionとEnglishV1の独立比較](test-catalog/ocr-code-english-screen.md) | 8 | Linux契約検査／Mac SDK26 Native Vision（研究専用） |
