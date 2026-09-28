# コードの構成

表示・解析規則・保存形式を維持したリファクタリングの配置です。ファイル数や行数だけを基準にせず、処理が分かれる境界で既存コードを移動します。SwiftUIの型、状態の所有者、ViewBuilder、modifierの順序を維持し、再解析・DB移行・設定初期化は伴いません。

## アプリ本体

| 領域 | 配置と役割 |
| --- | --- |
| タブ・ホーム・設定 | `ContentView` はタブと起動処理。`HomeView`・`SettingsView` は既存画面をそれぞれ保持。 |
| 時間割画面 | `TimetableView` は状態と画面全体。`WeekSection` は週の操作と状態表示、`Grid` はグリッド全体、`GridHeaders` は日付・時限の測定、`DayColumns` は日別の授業・行事カード配置、`Layout` は配置・高さの計算、`Cards` はカード、`Times` は時刻、`Navigation` は週移動、`Changes` は変更一覧、`Details` は詳細。 |
| 時間割統合 | `TimetableSchedule` は授業枠とクラス規則。`Blocks` は連続授業と重なり、`Events` は行事による日別の扱い、`Weeks` は表示日と週移動範囲。 |
| ファイル選択・解析結果画面 | `MaterialsView` と `FileSummary`（ファイル状態・要約）、`MaterialDocumentPicker`、`SpecialScheduleAnalysisView`、`PDFAnalysisView`、`PDFLessonDetail`、`SavedPDFView`、`ChangeAnalysisView`、`ChangePreviewView`。各画面の文言・寸法・構造は維持。 |
| 一覧 | `LinksView` は一覧と検索、`LinkRow` は行と色、`SafariLinkView` はブラウザ。`LinksAPI` は応答検証、`LinksStore` は保存。 |
| 名称対応表 | `MappingModels` は配信・保存モデル、`MappingRules` は照合規則、`Changes` は変更欄の分解と科目・クラス別教員照合、`MappingPackage` はZIP検証、`MappingStore` はSQLite、`MappingModel` は取得状態、`MappingSettingsView` は設定画面。認証は既存の `MappingOIDC`。 |
| ファイル取得 | `ScopedMaterialSelection` はアクセス権の保持と中止。`MaterialAccess` の `MaterialWorker` は取得・更新、`Analysis` は解析、`Provider` はFile Providerの読み取り。 |
| 資料保存 | `MaterialModels` は保存モデル、`MaterialLibrary` は原本の確定、`Analysis` は解析結果・失敗記録の保存、`Validation` は検証。DBは接続・初期化、現在の保存、`Snapshot` による検証付き読出し、レコード、DDL、旧形式処理に分離。 |
| PDF読み取り | `PDFKitReader` はページ読出し、`Diagnostics` は全文診断。`PDFPathReader` は罫線・矢印、`PDFCharacterGeometry` は文字の境界。 |
| PDF描画文字 | `PDFTextGeometry` は文字描画状態、`PDFUnicodeMap` は文字コードとフォント情報、`PDFDrawnTextReader` は演算子、`Fonts` はフォントリソースの読出し。 |
| 通常PDF解析 | `PDFAnalysis` はモデル、`PDFParseError` はエラー、`PDFGrid` はセルの位置関係。`PDFSchoolParser` と `Timetable`・`Events` は既存解析。旧行事PDFのタグ付け規則も維持。 |
| 試験・返却PDF | `SpecialSchedule` はモデル、`SpecialScheduleParser` は文書検証と共通セル処理、`Times` は時刻、`Pages` は各PDF書式の読出し。`SpecialScheduleRecord` は保存モデル。 |
| 試験・返却の取得状態 | `SpecialSchedulesModel` は状態と直列実行、`Startup` は起動時確認、`Analysis` は選択・再解析、`Provider` は原本の読出し。 |
| 行事API・診断 | `SchoolEventsAPI` は応答検証、`SchoolEventsStore` は保存。`PDFDiagnostics` は固定コードと数値の診断、`PDFFullReadDiagnostic` は全文診断モデル。 |
| XLSX | `ChangeAnalysis` はモデル、`ChangeNormalizer` は正規化、`Dates` は日付・曜日処理、`XLSXReader` はZIP・ブック検証、`Worksheet` はセル・式・結合セルの読出し、`BoundedXML` は上限つきXML読出し。 |

日付、文字表記、OIDC、URLSession通信、各画面モデルなど、既に一つの役割にまとまった処理はその単位を維持しています。ファイル分割のために通信・保存・キャンセルの順序や、トランザクションの範囲を変えません。

## テストとビルド

大きなテストは同じXCTestCaseのextensionへ移し、テスト名・入力・期待値・setUp/tearDownを保持します。PDFは通常時間割・行事・診断・PDFKit、時間割統合は変更・連続授業・行事、DBは旧形式・現在の保存、XLSXは正規化・ブック・プレビュー・保存、試験／返却は架空入力・解析・保存に分けています。

Xcodeプロジェクトと `Package.swift` の明示的なソース一覧を両方更新します。`tools/test-materials.sh` はSPMとは別にコンパイルするため、ここにも必要なモデルと処理を登録します。プラットフォームごとの `canImport` 条件とmacOS限定の対応表テストを維持します。

移動前後の実装行、テスト名一覧、ファイル登録を照合します。CIのSwiftテスト・iPhoneビルドは実機の画面比較とは区別し、結果を[検証記録](verification.md)に残します。

## ホームと時間割の共用処理

`HomeTodayView` は今日の行事・クラスごとの授業・詳細への操作を担当し、既存の行Viewは `HomeLessonRow` に置きます。`TimetableDaySchedule` は保存済み解析からの授業・時刻・不足状態と、日本時間での授業中判定を担当します。`TimetablePresentation` は両画面の変更前後の情報を共用し、`Details` に既存の授業詳細を置きます。週グリッドの描画は既存の `TimetableView` に残します。

## 2026-09-29の確認範囲

行数の多いファイルから、時間割・ホーム・ファイル選択・PDF解析画面、通常／試験PDF解析、XLSX、資料保存、名称照合、認証、行事・一覧の取得、File Presenterを確認しました。

- 分割した元ファイル：`TimetableView`、`TimetableView+Grid`、`HomeTodayView`、`TimetablePresentation`、`MaterialsView`、`MappingRules`、`ChangeNormalizer`、`XLSXReader`、`MaterialLibrary`、`LocalMaterialDatabase+Current`。
- 構成を維持した確認対象：`SpecialScheduleStore`、`PDFAnalysisView`、`TimetableView+Cards`、`PDFAnalysis`、`PDFPathReader`、`WebPDFDownloader`、`SchoolEventsModel`、`MappingOIDC`、`PDFKitReader`、`MaterialsModel`、`LinksModel`、`SpecialScheduleParser`、`TimetableSchedule`、`SelectedFilePresenter`。保存の確定・通信の終了・監視のロックといった一連の処理は、同じファイル内のまとまりを維持しています。

分割した10ファイルは、移動前後の実装行と118個のメソッド・プロパティの内容と順序を照合しました。XLSXのワークシート処理だけは既存の連続した処理を引数付きメソッドへ移し、呼出し位置と検証順序を維持しています。
