# 独立架空PDFと最終ソースの検証

通常CIの必要7項目が、`f8b0ca476d6fe6c5627231b1f24f32e73cb816f1` で全て成功した。[実CI](https://github.com/n624-dev/takupoke-ios/actions/runs/37226523125) と [checks.json](checks.json) に実ログのバイト数・SHA256・ジョブIDを記録する。Linuxホスト344件、実Macネイティブ394件は失敗0。iPhone向け実SDKビルドも成功した。画面テストは52件中51件成功・失敗0・想定skip1件（iOS26でVoiceOver自動操作を使えないため）、別途6件のサイズ別テストも成功した。画面テストの保存確認は既存の架空UI入力によるもので、下記PDFを手動採用した実測ではない。

実Readerへ渡したのは、seedから新規に配置・結合・授業を設計した完全独立の架空PDFだけ。本文は「架空科目…／架空教員…／架空室…」、年度・学期も架空で、17クラスは既存公開ソースのcanonical集合を使った。学校原本は理解専用に分離され、生成コード・fixture・CI・Gitへの原本入力や内容コピーは0。原本のフォントや描画命令をコピーせず、公開Noto Sans JPの固定版とOFLライセンスを使う。PDF・PNG・フォントのバイナリはコミットせず、一時生成する。期待JSONは実解析後のassertionにだけ使い、Reader・Builderの文字、役割、空欄、座標を補う入力にはしない。一般の通常時間割に17クラス必須という条件は導入していない。

| 実Apple Readerからの測定 | 取得・解析結果 |
| --- | --- |
| wide v1ラベルなし本体 | 680/680枠、658授業行、年度・学期・クラス・並記・空欄が原文一致、余分な枠0 |
| 未使用フォントsetupだけを除いた診断v2本体 | 同じ680/680。元v1も成功しており、診断版への置換で解決扱いにしていない |
| 1450×990の高密度・黒字本体 | 同じ680/680、658授業行、余分な枠0 |
| wideラベル付きcontrol2版 | Readerはcomplete。Strictの後、並記を証明できない既存certificate境界でRecoveryが安全拒否 |
| 高密度・黒字ラベル付きcontrol | Readerはcomplete。fragmentAlignmentの曖昧性でRecoveryが安全拒否 |
| 科目2・教員1・教室2の不整合 | StrictとRecoveryの双方がparallelLessonsで拒否。1つの複合授業への誤採用0 |
| 読めない本文／高密度の濃色文字2版 | Readerが未対応として拒否、解析・680枠評価なし。色の可視性ガードは変更していない |

この比較は実PDF→Reader→Strict→Analysisによるvector文字・意味の検証で、OCRや追加AIモデルの品質合格ではない。ラベル付きcontrolの成功を本体成功の代用にせず、拒否結果も残す。[wide固定6ケースの全証拠](https://github.com/n624-dev/takupoke-ios/tree/ea0df352cf8486053cb5295b73d68a194f9019b0/research-results/ios-independent-wide-vector-parser24-20261004)、[密度4ケースの全証拠](https://github.com/n624-dev/takupoke-ios/tree/e501ea1f323ae02b5e95400cd6dbe6f4d7075f8e/research-results/ios-independent-density-vector-parser24-20261004) は別の有限測定で、OCR・モデル呼出しは全て0。ネイティブhelperでは正式DB保存・手動採用画面は未評価である。

Readerは選択しただけの未使用フォントやCMap metadataを、実表示文字の安全検査と分けて扱う。実表示した未対応文字・制御文字、破損CMap、取消・上限は拒否を保持する。罫線と文字の衝突確認は保守的な空間索引で候補を絞り、元のinclusive判定と共有100万処理上限を変えていない。wide本体の実paintWorkは281,679、高密度本体は352,949で、上限を増やさず取得できた。

Validator5とParser24は曖昧な並記の古い誤採用を再利用・表示・採用から拒否する。合法の採用済み同一hashは、本文・Evidence・モデル履歴・元acceptedAtを変えずValidatorのみ再証明できる場合に確認を引き継ぐ。13件の専用回帰で旧不正／改ざん／未確認previewの拒否、旧正常の引継ぎ、独立したstructurePrompt3とfieldPrompt4のmetadata、投影・永続化・表示の境界を確認した。schema2、既存意味Validatorの証明、共有32Mの作業上限を緩和していない。

過去の上限cancel、Picker snapshot実行エラー、古いSpecialテストseedのmetadata不整合は消さず、最終成功と分別した。最終UIseedの修正はテスト入力metadataを現行版へ合わせるだけで、過去fixtureの原文は変更していない。この2ファイルの公開はdata-onlyで、追加CI・PDF測定・モデル推論は開始しない。モデルcatalogは有効化せず、物理端末推論やOCR品質の認定も行わない。
