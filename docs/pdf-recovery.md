# PDF端末内復旧の設計と実装状況

この文書は開発中の実装と検証範囲を記録する。3文書の前処理・復旧開始・プレビュー・採用・モデル管理を接続した。Apple SDKによるビルド・UI検証と実機確認は別に記録し、その成功を確認するまで配布可能とは扱わない。追加モデルは評価中で、検証済み配信Manifestはまだ空である。

## 確定した方針

対象は通常時間割・試験時間割・試験返却時間割のPDF。時間割変更XLSXと学校行事APIは対象外。既存Strict Parserを常に先に実行し、復旧対象となる書式・文字位置・表構造の失敗だけを復旧待ちへ記録する。破損・暗号化・入力上限・重複クラス・キャンセル・保存失敗をAIで成功へ変更しない。

順序はStrict Parser、決定論的なルール復旧、OSの端末内モデル、追加取得した端末内モデル、安全な失敗。取得済みの文字・座標・罫線・読み順を再利用する。Readerの途中成果にはcomplete / partial / rasterOnlyを付け、Reader全体の完了と個別ページの状態を区別する。未取得ページや部分取得を完全な文書として扱わない。画像化は必要なページごとに行い、文書認識の結果からセル候補を作る。ページ画像をLLMへ送らない。

3 OSはコードや推論Runtimeを共有しない。RecoveryDocument / RecoveryResult / RecoveryValidator / RecoveryJob / RecoveryMetadataの意味を合わせる。各言語のenumやJSONの表記は内部形式とし、Providerが返す自由形式のデータを正式Analysisとして保存しない。

## 実装した安全境界

- 値はpresent / empty / unreadable / missing / ambiguousを区別する。読めない授業を空き時間へ変えない。
- 全クラス・全日・全時限の範囲、日付・年度・学期、結合時限、並記数、時刻を検証する。試験・返却では既定17クラスと5日の完全性が必要。PDFページ数の一致を正しさの根拠にしない。
- 原文Sourceの位置とセル所属、科目・教員・教室ごとのEvidence、クラス・日付・時限の見出し領域を検証する。原文に文字があるだけでは受理しない。未割当の原文Sourceは、セルの外にあっても拒否する。
- 時刻は日付・時限・位置と原文に結び付ける。別日の時刻を共通時刻として流用しない。共通時刻は文書内の時刻表見出し・領域・対象日の完全性で適用範囲を証明する。任意の `day="*"` を受理しない。繰り返された各ページの時刻表も位置・値の一致を個別に検証する。連続時限は原文の専用時刻か、証明済みの最初と最後の時刻から決定論的に求める。
- 返却の通常時刻は、その5日に適用するPDF注記を要求する。モデルの知識から補完しない。年度・時刻・EvidenceをAIが決める経路は作らない。
- 決定論的に全フィールドの原文所属が判明したセルはルールで復旧し、モデルをロードしない。Schema 2 / Validator 4では、原文ラベルや列見出しに結び付いたRoleScopeを別に持ち、AIへ原文atom IDの割当案だけを要求する。値は原文から再構築し、役割領域・原文順序・並記対応・全sourceの完全partitionを検証する。所属や空欄の独立証拠が不足する候補は採用しない。
- 型・構造・Validatorの不正な出力は終端の失敗。複数モデルを試し続けて通る結果を探さない。Runtimeの非対応や実行不能は次Providerへ進められる。iOSの一時的なモデル未準備は待機する。
- 確認の再利用はPDF SHA、結果、文書全体の意味・Evidence、モデルと各Versionの一致に限定する。初回は利用者による採用が必要。指紋照合だけでValidatorを省略しない。
- モバイルの更新確認では復旧待ちを記録するだけで、重いモデルをロードしない。失敗・中止でも前回正常結果を保持する。新原本未反映の表示を維持する。

## 原本照合による上限付き手動補助

OCRは選択した必要ページをすべて取得してから信頼度を確認する。取得時のPDFバイト列とSHA、元のtop1・順序付きtop5・文字ごとの位置・信頼度を保持し、0.85未満の候補を自動採用しない。通常の文字・表構造・原本全体のink検証を完了したうえで、低信頼の文字列が一つの科目・教員・教室の本文フィールドに所属すると証明できる場合だけ、文書全体で最大3フィールドの原本照合へ進む。4件以上、未取得ページ、未知のink、見出し・年度・クラス・日付・時限・時刻・役割・並記区切りの不確かさは終端の失敗とする。

各項目には実際に取得した原本画素の切り抜きと元の読取文字を表示する。全文は256 UTF-16単位以内とし、各項目の「原本と一致することを確認」は初めは未選択で、編集すると確認を解除する。印刷された文字を空欄に変更しない。入力は元OCRの上書きではなく、対象フィールド・PDF SHA・取得記録SHA・文書全体の指紋・順序付き元Source ID・元の切り抜き領域・確認日時を持つ別の利用者確認記録として保存する。AIやOCRが正しく読んだ結果として扱わない。

一時的な非アクティブ状態では重い処理を止め、照合途中の値と確認状態を保持する。同じ原本の状態更新では入力を消さず、原本のハッシュ・保存先・選択年度が変わった場合は破棄する。送信時に原本SHAを再確認し、その後に資料全体のプレビューと別の明示的な採用を要求する。失敗・取消でも前回正常結果を保持する。

iOSはSchema 2 / Validator 6 / ManualAssistanceSchema 1を使用する。追加した取得記録・Source信頼度・利用者確認記録はnilの場合にJSONへ出力せず、既存の有効なValidator 4・5の明示確認は元の指紋と確認日時を保って再検証する。既存OCRのcoverage証明が欠けた監査に、新しい証明や信頼度を後付けしない。Linuxの実ソース・実XCTestで、1〜3件の正式変換・4件拒否・原文保持・誤った所属／指紋／信頼度／順序の拒否・保存後の証明保持を確認した。Apple SDK・実アプリUI・実機の確認は別に扱う。

## モデルとプライバシー

追加モデルは検証済みManifestのmodelId / version / URL / size / SHA-256 / runtime / minimumOS / minimumMemory / recommendedBackend / licenseで固定する。取得・ハッシュ検証・動作確認後にactive pointerを切り替える。切替前の失敗やキャンセルでは旧モデルを保持し、同じbytesの版更新でも旧版の所有ファイルを整理する。所有一時ファイルの回収APIは使用中モデルを保護する。起動前の所有ファイル回収と、設定からのダウンロード・削除操作を接続した。Core AIは検証済みアーカイブと準備済みbundleを組で切り替える。実行中のモデルはジョブごとのleaseで保護し、中止後もRuntime終了まで次の処理とモデル変更を待つ。

Qwen3-0.6Bは最初の比較基準で、最終採用モデルではない。公開Manifest・モデルURLはまだ設定していない。モデルファイル容量と実行時メモリは別に計測し、実資料に近い非公開ケースと対象端末で候補を比較する。

PDF・画像・OCR文字・科目・教員・Prompt・復旧結果を外部LLMへ送るProviderは追加しない。モデル取得のネット通信と学校資料の送信は分ける。新しい取得UIには容量と「学校の資料は外部へ送信されません」を表示する。復旧文書・結果・確認記録は学校データと同じ保護と保存期限を適用する。

原文Sourceは一度だけID・元セル・ページ別に索引化する。セル内印字の検査は位置候補を絞るが、背の高いSourceや別セル・見出しからまたがる印字も残す。全候補・非一致比較・文字列の取り込みと連結は共有の処理上限を消費し、内側のループで中止を確認する。同期の確認APIも上限超過では失敗する。前処理・検証・Provider実行は画面の実行スレッドから分離し、取消を推論Taskへ伝え、終了を待ってからモデルleaseを解放する。採用前後の原本・保存期間の照合は画面側に残す。

## 未確定な役割を扱う契約

セル内の原文をすべて使っていても、科目と教員を入れ替えれば誤った結果になる。固定Bindingsとは別にRoleScopeを持ち、原文ラベル・役割列・既存書式・並記領域から役割を証明する。一意な割当はRulesで処理する。

折り返されたラベルの間に本文だけの行が入る場合も、原文groupの順序付き連鎖を最大3群まで有界探索し、対応済みの役割ラベルと完全一致する候補をルールで作る。64群・512glyph・有限の空隙cutと共有の処理上限を守り、内側で取消を確認する。ラベルの上下・右側にある最寄りのcutへ正規化し、既存の独立証明で原文文字の一致、左側の全ラベル消費、唯一の役割、領域の非重複、本文の完全partitionを検証する。異なるラベル／本文の割当が残る場合は採用しない。値は原文から再構築し、既存Validatorと利用者確認を通す。新しい文字・任意座標・未読の補完は認めない。全ページのクラス・年度・時限・位置・原文inventoryはモデル取得前に検証する。

Schemaは2、Validatorは4、RecoveryVersionは2、構造提案Promptは3。非隣接ラベルの有界探索を含むRulesのmodelVersion／runtimeVersionは3で、RulesのPromptVersionは1。構造を提案したProviderのMetadataをDocumentとResultに保持し、文書全体の指紋にも含める。以前のValidatorによる確認は再利用しない。

## 接続と残る確認

- Strict失敗のReader captureを再利用し、欠落・不完全ページだけVisionで画像化・文書認識する。全文を巨大Promptへ渡さず、対象セルと独立見出しをまとめる。OCRの未認識inkが残るセルを空欄として採用しない。
- 前景Coordinatorは取得・中止・モデル待機・元PDF確認・全クラスのプレビュー・明示採用を管理する。バックグラウンド移行・期間切替・選択変更で中止し、前回正常結果を保持する。
- 採用直前に原本SHA・選択したstoredName・現在のStrict失敗とRecoveryJob・保存期間を再確認する。正式Analysisの単一payloadへRecoveryDocument / Result / Metadata / Acceptanceを格納し、既存SQLite transactionで原子的に保存する。ホームにも新原本未反映を表示する。
- Apple SDKでの型/API接続、OSごとのUI表示、Visionの実画像認識、iPhone上の推論・メモリ・中止は引き続き検証する。公開fixtureだけで誤採用率を証明しない。
- 追加モデルを実際に比較した結果、現候補の品質は配信基準を満たしていない。Manifestを空に保ち、未合格モデルの自動配信・採用を行わない。SystemLanguageModelが利用可能な端末の経路とルール復旧は追加モデル不要。

## 検証

公開テストは全て架空の入力で、学校資料の名前だけを置き換えた資料ではない。通常時間割、17クラス・5日・ページ分割された試験/返却、連続時限、日付ごとに異なる時刻、PDF注記のfixtureを用意している。未読/空欄、隣セルEvidence、文字の省略、重複・欠落、誤ったヘッダー、重なったセル、別日の時刻流用、未割当文字、モデル切替失敗、キャンセル、前回結果の保持を回帰検証する。

最重要指標は「間違った結果を正しいと判定して採用した件数」。公開fixtureだけの成功率を実資料での精度や誤採用率として扱わない。

## iOSの接続状況

SystemLanguageModel / Foundation Modelsの@Generable ProviderとVision RecognizeDocumentsRequestのページ単位処理を追加した。SystemLanguageModelのavailabilityを使い、機種名を固定しない。順序はiOS 27でSystemLanguageModel → Core AI → llama.cpp、iOS 26でSystemLanguageModel → llama.cpp。Foundation ModelsのGuided Generationに加え、Core AIのGuided wrapperとllama.cppのgrammar制約付きC Runtime adapterを接続した。

CoreAILanguageModelはSDKへ直接追加された型ではなく、Appleの `coreai-models` の `CoreAILM` product / `CoreAILanguageModels` moduleで提供されるラッパー。調査した公式リポジトリのrevisionは `52c84ba874b2c57adcede08a671ce96ed1b3f433`。同Packageのminimum iOSは27なので、iOS 26本体からは小さいObjective-C bridgeで別frameworkを動的に読み込む。device向けSDK27で公式CoreAILM依存frameworkをビルド・同梱し、iOS 26や未対応環境ではllama.cppへ進む。Core AI tokenizerは完全同梱が必須で、学校情報を扱う実行中の外部取得fallbackを禁止する。llama.cppは公式b11371のXCFrameworkをSHA固定でビルド時に取得し、deviceへ組み込む。公式配布にsimulator sliceがないためsimulatorのllama実行は非対応。これらのnative compileはCIで確認する。

LinuxのSwiftホストテストではFoundation側の契約・Validator・Engine・ModelStoreを確認する。ModelStore/指紋の検証にはLinuxだけSwift Cryptoを使い、iOS本体はCryptoKit。Foundation Models/Vision、CoreAIとllama runtimeのApple SDKコンパイルはCIで成功した。実端末のモデル推論・メモリと実資料の品質は未検証。`tools/test-parsing.sh` と `tools/test-materials.sh` を使う。

## この作業での検証（2026-10-04 UTC）

LinuxでiOS Swift302件とPython58件が成功。構造提案・起動前完全性チェック・名称変更・ETag・授業領域内の配役校正・時刻順・小数境界の未読画素・モデル削除失敗と再起動の回帰を含む。返却日付列の昇順、表示領域外へ平行移動した表の拒否、旧解析版の同一SHA再解析、罫線グラフと画素・文字比較の処理上限／内側ループの取消、重複した時限Evidenceによる二次探索の回避も確認した。WindowsとAndroidの実OS検証は各版の記録を参照する。

年度見出しの矛盾・不正桁数・漢数字や年数のない令和表記は全3文書種別で拒否し、一致する和暦／西暦・Unicode互換数字と元文字範囲を保持する。通常Parser21・特殊Parser22に更新し、直前版の同一SHA成功も再解析する。2MB内の65,536個のsingleton code spaceを実CMap decoderで検証し、重複・範囲外・内側取消を確認した。680個の完全校正セルと680個の1行セル、74,000個の表外文字を持つ10万glyph未満の入力で高さ索引による復旧を確認し、取消途中の校正は再利用しない。Builderの取消・上限超過を構造提案へ送らない。LinuxではPDFKit・Vision・SwiftUIを実行していない。

iOSの[最終検証CI28](https://github.com/n624-dev/takupoke-ios/actions/runs/37178413397)（実行回1）は、配布チェック、[Native Mac350件](https://github.com/n624-dev/takupoke-ios/actions/runs/37178413397/job/111365828261)、[SDK27のiPhone向けReleaseビルド](https://github.com/n624-dev/takupoke-ios/actions/runs/37178413397/job/111365828249)、OS26/27のUI各2組の計7必須ジョブが成功した。検証対象は `07dc01940fee8d42aa705fd3d285f6e10625a4ea`。Python58件とファイル選択UI3件も成功した。各OSのUI26項目をA13/B13へ分けて選択し、OS26は25件成功とVoiceOver専用1項目の予定どおりのskip、OS27は26件成功。両OSでOS文字サイズの3追加確認、計6件も成功した。通常時間割の元PDF表示・閉じる操作、3文書種別と並記授業の明示採用・実アプリ再起動後の保持、採用前に閉じた場合の前回正常結果、モデル管理導線、ホーム／時間割の正式データ更新時の詳細閉鎖と処理中だけの詳細保持を確認した。採用UIテストは事前にValidatorを通した完全架空のPreviewを一時テストコピーへ渡し、実際の採用・保存・再起動を検証する。生成モデルの実推論精度の検証とは分ける。feature branchの公開ジョブは予定どおりskipし、この作業からReleaseやAltStore Sourceは公開していない。

学校行事の年度別キャッシュでは、破損JSON・内容や型の不正・symlink・サイズ超過・年度不一致が他の正常年度を読めなくする問題を修正した。破損元bytesと正常年度を保持し、ディレクトリ・読取りのI/Oや保護エラー、取消では利用可能状態へ変更しない。別年度の正常取得後も警告を残し、当該年度の検証済み原子的保存が成功してから解消する。両OSの実UIで正常年度の詳細と取得可能状態、別年度更新後の警告維持、同年度修復、実アプリ再起動後の保持を確認し、実際の警告画像も照合した。

ホームでは今日の学校年度、週表示では全7日の学校年度の保存済み範囲を確認する。過去年度だけの保存は未取得の案内を消さず、授業がないと断定しない。当年度に別日の行事だけがある正常応答は、未取得と区別する。固定した2033年3月31日と3月28日〜4月3日の週を使い、過去年度のみ・当年度のみ・両年度、当日の授業あり／なしを含む5構成を両OSの実UIで確認した。同じfixtureから実Library・Storeへの保存・再読込みと実TimetableDayScheduleを確認する独立ホスト検証も成功したが、公式Swift件数には加算しない。時計と起動処理の置換は一時テストコピー内だけで、本体へテスト用hookは追加していない。学校API・PDFの本番通信は行わない。

以前の[CI23](https://github.com/n624-dev/takupoke-ios/actions/runs/37154616177)は `2e4d26d0fb5ce33314cf3abdda98d09700fe2d0a` のNative Mac343件・UI各OS24項目と全7ジョブ成功を確認したcheckpointである。CI17の詳細操作の失敗もそこで解消した。追加キャッシュ／年度UIの途中では、CI24の年度ラベル照合、CI25のfixture API誤用、CI26の非空保存条件を満たさないfixtureと入力値の観測時期で失敗した。CI26のOS27 Aは時間切れ、CI27の残るジョブはCI28へ切り替えてcancelledとした。最終CI28の成功とは区別し、各実行の[失敗と修正の履歴](verification.md#2026-10-04-pdf端末内復旧学校行事の年度別保持開発中)を残す。

日本語画像PDFの実Vision OCRはOS27で成功し、OS26ではconfidence約0.358を安全に拒否した。CropBox、画像の上端座標、罫線、未読インクと空欄の検査は両OSで確認した。Native Mac350件には白文字・上塗り・不可視描画・文字と交差する線・切り抜き外本文を扱う架空PDFと、実PDFKit thumbnailのCropBox画像を参照画像と比較する検証を含む。Quartzの近軸線は線幅2・折返し高さ0.19・miter limit100で想定領域外の40画素を観測し、同じ線のlimit10では0画素だった。この実対照を回帰へ固定し、Readerの拒否を維持する。校正索引・680短セルの復旧・モデル保存先の新規／既存rootのバックアップ除外属性も成功した。物理iPhoneでの推論・メモリ・実際のバックアップの動作は未確認。

追加モデル候補はまだ配信承認しない。Linux CPUの実llama.cpp出力6件を本番の構造検証・再構築・Validatorへ渡した検証では6件とも安全に拒否し、誤採用は0件だった。同じ架空入力の正しい候補IDは成功したが、実端末推論や実資料での復旧精度を示すものではない。承認済みcatalogは空のまま維持する。

追加診断では同じ本番C bridgeとllama.cpp b11371を使い、Linux CPUで2B・4B・Phi系も実推論した。4Bの自由応答は折り返しラベルを識別できたが、本番の構造提案Schemaでは本文IDの混入やcutの欠落が続いた。役割ごとにラベルIDだけを提案させる研究用の指示は、1件の開発入力で3役割とも正しく、原文から最寄りcutを付けた候補が実際の構造証明・通常時間割の再構築・Rules・Validator 4を通過した。指示を固定した別の完全架空6入力では、全役割の原文ID完全一致は0件で、3問い合わせの合計は約24〜59秒、fresh processの最大RSSは約4.65GiBだった。単一の開発入力成功をモデル品質合格として扱わない。同じ証明可能なラベル連鎖は決定論的な有界探索でも解決できるため、これらはモデルの出力を比較する対照入力であり、AIが必要な復旧精度の評価ではない。iPhone 14・iOS 27.0.1でのCore AI／llama.cppの推論と利用可能メモリは未確認。

有界探索とRules版3はLinux Swift308件で成功した。通常時間割の非隣接ラベルはProviderのavailability／推論を一度も呼ばず、試験・返却も全17クラス・5日の完全性を保ってBuilder・Rules・Engine・Validatorを通過した。欠けたラベル、非対応役割、重なった役割、未知の左列文字、有限cutの欠落、処理上限と内側取消を拒否する。Provider自身の上限停止・元文書の完全性・Metadataの回帰には、拡張前の未解決入力を完全架空の変更不能なpreparation fixtureとして保存して使う。異なる証明済みpartitionが現れた場合は終端の曖昧エラーとし、AIで選び直さない。この追加のApple SDK／Native Mac／実機確認は、従来のCI成功とは分けて記録する。

追加取得モデルの保存先はバックアップ対象外属性を設定します。管理画面の確認時にも既存ディレクトリへ属性を再適用します。Linuxでは保存処理、Macでは新規・既存ディレクトリの属性と残存モデルの保持を確認しました。実際のiCloud／端末バックアップの動作は未確認です。

検証の負荷回帰には、5ページ・680セル・各項目24群の架空返却レイアウトを使う。iOSの実Builderは固定項目を行単位でまとめ、Sourceは2,388件となる。この前処理からRules・Validatorへ進む陽性と、同じ架空文字・元の群位置を持つ49,308 Sourceの独立した契約入力を区別する。後者はBuilderの実到達件数ではなく、索引・全所属・取消・上限の検証範囲を確認するための入力である。最新debug実行で、この独立契約のValidatorはLinux約1.18秒、Mac約1.25秒だった（端末の処理時間保証ではない）。索引・workerとProvider接続はApple SDKでコンパイルされ、共有上限・取消の契約はNative Macテストで確認した。ホームの詳細を安定したList親から表示する修正は両OSの実アプリUIで成功した。


### 共通fieldExtraction指示

SystemLanguageModel、llama.cpp、別ビルドのCoreAI runtimeのfieldExtractionは、OS共通の指示資産を使う。2939 UTF-8 bytes/SHA256 `c24039ae4317a433a14f01697d77813424a3a1c20a70327189964b2fc60bb188` を実loaderが検証し、読めて一意な確定本文をPRESENTにする条件、roleScopes.emptyVerifiedと固定bindingのblankFieldsの区別、元sources配列順、全non-PRESENTの空value/evidenceを明記する。状態は既存native schemaの綴りに従い、fieldExtractionのpromptVersionは4、変更していないstructureProposalの成功metadataは3、RecoveryVersion2/Schema2/Validator4を保つ。Strict/Rules/Validator、runtime・モデル・配信catalogは変更しない。

通常時間割のRecoveryは、既存Builderがunsupported/periodHeadingで止まった場合に限り、原本の文字・罫線・画素から独立した表を再構築する。各ページの閉じた罫線内に1曜日の見出し帯、1〜8の時限セル、既知クラスの左見出しと完全な本文行が必要で、文書全体の5曜日と全クラス×5×8の一意なコマを検証する。高さの1/3や1ページ内の5曜日という従来資料の配置をこの経路には要求しない。Strictと従来Recoveryを維持し、曖昧・取消・上限超過は再試行しない。既存32Mの共有処理上限は最初の試行と追加経路で同じインスタンスを使い、補充しない。

追加経路の非空セルは3種類の完全な同一行ラベルと科目本文を必要とする。原文の行全体の高さと罫線内の空隙から役割帯を作り、文字bboxの拡大や隣セルからの補完を行わず、既存のinlineLabel証明・Validatorで唯一の所属を確認する。OCR入力の担当・教室の空欄は元画素で独立に証明し、全ページの未割当文字、OCRページの未読ink、未知クラスの罫線行を捨てない。この経路はAIへ構造を問い合わせない。独立した架空原本2件の各40コマと全正式授業値を、元PNGの画素と描画フォントの文字座標を保持したテストで確認し、Linux回帰317件が成功した。これはOCR出力のテストではなく、Visionの文字精度・実機動作・モデル品質の証明は含まない。

研究branchの同一ソース3c90d6eを使ったCI37200758660では、Macのnative359件すべて成功し、iPhone向けSDK27のapp/runtimeビルドと、実app及びCoreAI SwiftPM bundle内の同一資産byte/SHA照合が成功した。推論は行っていないため、指示の整合性・組込み確認を精度向上や追加モデル品質合格とは扱わない。共通HEAD/COPY対照と評価済み利用者参照文は別課題として保存し、過去の弱い指示や実測出力を変更・再実行しない。資産と仕様は [tools/recovery-prompt-contracts](../tools/recovery-prompt-contracts/README.md) に記録する。

### Vision文書の表・セル取得

Visionの `Container.text` はコンテナ内の全文を返す。表の文字が欠けていたという実測ではなく、これまで平坦な行へ落としていたネイティブの表・結合セルの所属を取得記録へ保持する変更である。`tables`、表の `rows` / `columns`、セルの `rowRange` / `columnRange` と `content.text.lines`、元の正規化polygonをそのまま記録する。セルの原文・候補順位・信頼度・文字の元座標を平坦な行と一意に照合し、既存のページ内行順とSourceの所属を変更しない。両軸の不一致、別セルによる同じ行の重複所属、対応する行の欠落・曖昧さは拒否する。

ネイティブの表番号や行・列範囲を時限・クラスへ変換せず、認識領域を罫線の代わりにしない。文字のないネイティブセルも、授業が空欄である証明にはならない。入れ子の表はこの取得経路では明示的に拒否する。従来の画素被覆・罫線による所属検証、0.85の認識信頼度、全体プレビューと別操作の採用を維持する。追加した取得記録も原本指紋へ含まれ、記録のない旧取得データのJSON byteは変更しない。

Linuxでは本番の取得記録・照合コードを完全架空入力でコンパイルして検証した。Apple SDKによる追加adapterの型検証、Visionの実出力との対応と復旧精度、実機動作は未確認である。APIは [Appleの文書コンテナ](https://developer.apple.com/documentation/vision/documentobservation/container)、[表](https://developer.apple.com/documentation/vision/documentobservation/container/table)、[セル](https://developer.apple.com/documentation/vision/documentobservation/container/table/cell) の仕様に基づく。追加モデルの品質合格や配信承認には用いない。
