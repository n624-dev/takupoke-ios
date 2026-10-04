# OS共通fieldExtraction指示の組込み確認

iOSの3実Providerと別ビルドのCoreAI runtimeへ、共通のfieldExtraction指示を組み込みました。指示は2939 UTF-8 bytes、SHA256 `c24039ae4317a433a14f01697d77813424a3a1c20a70327189964b2fc60bb188` です。実loaderが同梱資産の長さ・SHAを検証してから使います。[共通資産と各課題の仕様](../../tools/recovery-prompt-contracts/README.md)はHEAD選択、確定済みBODYのCOPY、評価済み利用者参照文、本番fieldExtractionを別課題として管理しています。

読めて一意に割り当てられた本文をPRESENTにする条件を明記し、roleScopes.emptyVerifiedと固定bindingのblankFieldsを区別しました。証拠は元sources配列順で、PRESENT以外はvalue/evidenceが空です。状態名は各既存native schemaの綴りに従います。fieldExtractionは指示版4、変更していないstructureProposalの成功記録は3、RecoveryVersion2/Schema2/Validator4を維持します。

実ソース [3c90d6e](https://github.com/n624-dev/takupoke-ios/commit/3c90d6e202efa6f38e43a6a01ee4cddcca5b9aa9) を使った [CI 37200758660](https://github.com/n624-dev/takupoke-ios/actions/runs/37200758660) で、Macのnative回帰359件がすべて成功しました。実際の同梱資産の読み込み、改変・過大・不正入力の拒否、field版4とstructure版3の記録も含みます。iPhone向けXcode27 SDKビルドも成功し、生成されたアプリ本体とCoreAI SwiftPM resource bundle内の指示がともに2939 bytes/c240 SHAであることを照合しました。これは実機推論ではありません。

[共通資産CI 37200758652](https://github.com/n624-dev/takupoke-ios/actions/runs/37200758652) では7件の検証と30件の厳密JSON境界例が成功しています。ローカルの既存Python58件も成功しました。[checks.json](checks.json) にソース、job ID、資産識別子、取得した実行ログのbytes/SHAを記録しています。fixtureと検証入力はすべて架空です。

新しいモデル推論やダウンロードは行っていません。指示の説明不足と組込みの修正であり、精度向上・追加モデル品質合格・catalog有効化の証明ではありません。過去の実測指示と出力は変更しません。CoreAIの物理端末での推論とメモリは未確認のままで、従来のsimulator SDKでCoreAIモジュールが提供されなかった実結果も保持します。
