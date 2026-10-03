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
- 決定論的に全フィールドの原文所属が判明したセルはルールで復旧し、モデルをロードしない。Schema / Validator version 2では、原文ラベルや列見出しに結び付いたRoleScopeを別に持ち、AIへ原文atom IDの割当案だけを要求する。値は原文から再構築し、役割領域・原文順序・並記対応・全sourceの完全partitionを検証する。所属や空欄の独立証拠が不足する候補は採用しない。
- 型・構造・Validatorの不正な出力は終端の失敗。複数モデルを試し続けて通る結果を探さない。Runtimeの非対応や実行不能は次Providerへ進められる。iOSの一時的なモデル未準備は待機する。
- 確認の再利用はPDF SHA、結果、文書全体の意味・Evidence、モデルと各Versionの一致に限定する。初回は利用者による採用が必要。指紋照合だけでValidatorを省略しない。
- モバイルの更新確認では復旧待ちを記録するだけで、重いモデルをロードしない。失敗・中止でも前回正常結果を保持する。新原本未反映の表示を維持する。

## モデルとプライバシー

追加モデルは検証済みManifestのmodelId / version / URL / size / SHA-256 / runtime / minimumOS / minimumMemory / recommendedBackend / licenseで固定する。取得・ハッシュ検証・動作確認後にactive pointerを切り替える。切替前の失敗やキャンセルでは旧モデルを保持し、同じbytesの版更新でも旧版の所有ファイルを整理する。所有一時ファイルの回収APIは使用中モデルを保護する。起動前の所有ファイル回収と、設定からのダウンロード・削除操作を接続した。Core AIは検証済みアーカイブと準備済みbundleを組で切り替える。実行中のモデルはジョブごとのleaseで保護し、中止後もRuntime終了まで次の処理とモデル変更を待つ。

Qwen3-0.6Bは最初の比較基準で、最終採用モデルではない。公開Manifest・モデルURLはまだ設定していない。モデルファイル容量と実行時メモリは別に計測し、実資料に近い非公開ケースと対象端末で候補を比較する。

PDF・画像・OCR文字・科目・教員・Prompt・復旧結果を外部LLMへ送るProviderは追加しない。モデル取得のネット通信と学校資料の送信は分ける。新しい取得UIには容量と「学校の資料は外部へ送信されません」を表示する。復旧文書・結果・確認記録は学校データと同じ保護と保存期限を適用する。

## 未確定な役割を扱う契約

セル内の原文をすべて使っていても、科目と教員を入れ替えれば誤った結果になり得る。次の契約では、固定Bindingsとは別に、アプリが原文ラベル・役割列の見出し・既存書式の役割領域・並記列から作るRoleScopeを持たせる。AIは新しい文字や座標を作らず、既存の原文atom IDの割当案を返す。原文順序・矩形・役割領域・完全partition・並記対応・空欄証明をValidatorで確認し、正式値は原文から再構築する。一意に決められる割当は先にルールで処理する。

固定BindingsとRoleScopeの両経路を実装し、ラベル並び替え・外部列見出し・原文再構築を架空ケースで検証した。独立した役割の根拠がない無ラベルの折返し・欠落を、AIの知識と確認ボタンだけで確定扱いにしない。RoleScopeへの全atom所属が一意ならモデルを呼ばずRulesで復旧する。現契約で安全に確定できない入力が生成AIによって新しく成功するとは保証せず、利用可能なモデルだけで不明を埋めない。Schema / Validator versionは2で、Document全体のfingerprintにRoleScopeも含める。

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

LinuxのSwiftホストテストではFoundation側の契約・Validator・Engine・ModelStoreを確認する。ModelStore/指紋の検証にはLinuxだけSwift Cryptoを使い、iOS本体はCryptoKit。Foundation Models/VisionのApple SDKコンパイルとiPhoneでの処理は未検証。`tools/test-parsing.sh` と `tools/test-materials.sh` を使う。

## この作業でのローカル検証（2026-10-03 UTC）

LinuxでiOS Swift240件が成功。iOS Python55件、Android core98件、Windows Core227件・Integration141件、パッケージライセンス収集13件は前の基盤検証記録。iOSの材料保存/HTTP失敗保持の単体実行も成功。Androidはdebug APKのassembleまで成功。Windowsは実SDKを参照したProviderとAppViewModelのC#コンパイルが成功（UI/XAMLと実OS実行は含まない）。公開fixture・SDK接続のコンパイルを確認した結果で、学校資料の復旧精度と実機動作の確認ではない。

サブエージェント3名が各OSの追加コードを反復レビューし、別の1名が更新・中止・期間切替のバグ調査を並行実施した。Evidenceの省略/誤ったセル/孤立Source/見出しへの偽装/別日時刻、iOSの保存失敗後の再試行、Windowsのjob原子的保存とキャンセル後snapshot、Androidの未反映警告の指摘を修正し、架空回帰ケースへ追加した。RoleScopeを実装後に独立レビューし、交換・省略・隣セル取り込みが拒否されることを追加確認した。一意な割当は先にRulesへ回す。

追加の並行調査で、iOSの更新原本へのPDF表示差替え、Androidの閲覧中原本更新への追従、WindowsのPDF描画例外・二重起動・旧要求失敗の競合と、同一SHA選び直し後の失敗キャッシュ失効を修正した。Windowsの監視再登録では受信済み通知を保持し、空登録・取消では破棄する。Androidでは処理中の通知を世代付きで保留し、observer管理をMainへ直列化、安定した原本の読取通知連鎖を有限にして、observer起点の確認では学校行事API・revisionを取得しない。Windowsは実ファイル通知と再選択の保存境界、Androidは通知queueの回帰を確認する。PDF画面の実OS描画は未検証。
