# CIのAppleツールチェーン更新（2026-10-26）

利用者の更新指示を受け、配布済み449.1/source67273c0を基準とする。
現在は配布/通常26/27にXcode・SDK27.0、手動訂正26/NativeにXcode26.6を固定している。
まず既存Development workflowの手動input apple_inventoryでmacos-26/xcode-27の
実installed Xcode version/build・両device SDK・iOS runtime version/availabilityを読み取る。
インストール・選択変更・Simulator作成・学校通信・cache/artifactの保存は行わない。
既存のportable/契約jobと正式15条件は減らさず、正式workflowはまだ変更しない。

編集前にdevelopment-policy/roadmap/test-maintenance-policy/test-catalogと対象検索を確認。
Xcode/SDK/runtime/27.1で失敗索引を検索し、U36（旧27.1 betaでも通知未返答）、
U60/U61（26.5取得とexport形式）、N76/N77（27.1 RuntimeとiPhone16非互換/観測一覧）
の詳細と当時/現行の版固定・選択を照合した。新しい版があるだけで旧失敗解消と断定せず、
実際のSDK・Runtime・device互換を確認して候補を決める。最低対応iOS26と元UI期待/期限は維持する。

inventoryはread-onlyの開発診断であり、新しいアプリ仕様ではない。
既存workflow source paths/catalog検査で接続と宣言を確認し、不要な模倣テストは追加しない。
Actions開始前にはこの一回専用の新規GPT-6.1 Sol/High code-only reviewを行う。

公式搭載一覧（利用者提示、xcode-27-arm64 image20261022.0305.3）で27.1/27A9275が標準、
27.2 RC/27B48と両iOS SDKを確認した。macos-26 image20261013.0424.1の標準は26.6/17F113で変更なし。
旧U36の27.1 beta/27A9269とはbuildが異なる。27.1 RuntimeはiPhone Duo用として掲載されており、
今回も元iPhone16/Runtime27.0と26.5を維持してSDKの差だけを先に比較する。

初回の既存Development workflow一回へinventory2runner、Native3版（26.6/27.1/27.2）、
Picker元3case×新2版をまとめ、既存portable/契約も維持する。正式配布はまだ27.0。
Runtime準備は明示した27.0/27.1/27.2のSDKと実SDKの完全一致を要求し、既定は元27.0。
選ぶRuntime/登録済みunavailable拒否/download/import/所有回収は変えない。
新2版の正対照・SDK不一致/未知指定の拒否・両Runtime固定を実script境界で追加検証する。

ローカルはRuntime準備2件/失敗0（2.338秒）、実runner14件/失敗0（26.933秒）、
catalog14件/失敗0（0.316秒）、source paths3件/失敗0（0.012秒）、catalog450が成功。
manifest28件は27成功/Swift不在skip1で、不足の補完filterを誤り0件となったN154を記録した。
正しい未実行caseとinstalled toolchainを使用して補完する。Appleの新SDK実行はまだ未確認。

初回専用の新規GPT-6.1 Sol/High ios_ci_20261026_probe_pre_actions_reviewは、
patch217行/11401bytes SHA256 c3f16f98…、workflow173行/7570bytes 1bad0f37…、
runtime26 36行/2168bytes 02020a17…、runtime27 36行/2156bytes db2bfe0a…の全行/bytes/hashを
確認し、具体的指摘なし。主担当が現差分との同一性を確認して、この9job比較一回だけへ使う。
正式/mainや別の比較へは転用しない。

不足していた既存Swift helperの一件は、正しい宣言名とSwift6.1.2で成功（1.943秒）。初回manifestの27成功と併せて全28caseを確認したが、別実行であることを保持する。最初の0件を成功に数えない。現在code diffの全SHA256 c3f16f98c134aa3686a47ad7a104e404c6e4c5d9abea402065b320f5bcceff76は専用reviewと同一。次はsdk27=both-new/native_pdf=true/picker=true/apple_inventory=trueの既存Development workflow一回を開始する。

初回比較40357278572/source2562772を継続中に、主担当が通常CIの27.1候補を準備した。
正式の4通常UI・27訂正・iPhone buildの8jobは27.1を明示し、SDK事前照合にも27.1を渡す。
26の従来Native/訂正は公式搭載標準26.6/SDK26.5を使用する。既存の全15条件・依存関係・
全ケース・期限・Runtime26.5/27.0・iPhone16は維持する。SDK設定を要求する既存workflow契約の
固定版期待を27.1へ追随し、実SDK照合変数が両laneへ渡ることも要求する。
この準備は限定比較の成功を仮定せず、mainへは比較結果と別の新規reviewを確認してから進める。

27.1正式CI候補のmanifestは、既存Swift toolchainを設定した一回で全28件/失敗0（5.828秒）。通常lane/元手動4条件×両OS/全必須gateの固定期待を保持し、新しいSDK設定を要求する。開発手順/方針の現在版を27.1へ合わせ、過去の検証表の旧版結果は保持した。配布済み449.1の成功を新候補の合格へ数えない。

比較専用relaunch workflowも既定27.1と明示27.0/27.2、26側の新SDK選択へ追随する。
旧guardは登録された27系の最大版を27.0と要求し、Duo専用27.1と共存する正しい27.0も拒否する。
新guardは元の実27.0がavailableであることを要求し、実runnerは引き続き27.0だけを選択する。
新しいSDK選択・共存27.0+27.1の正対照、SDKずれ・27.1しかない時の拒否を既存実shell caseへ足す。
Xcode26.6の実iOS SDKは26.5なので、その事前照合も行い、旧fakeのSDK26.6成功を26.5へ訂正した。
入力・期限・元case/OSの選択と全15の公開gateは変更しない。

27.1正式候補の全Python確認は288件/失敗0（75.658秒）、専用font研究環境のsetUpClass2件のみ予定skip。
比較workflow追随後の関連runner14件/失敗0（28.566秒）、manifest28件/失敗0（5.615秒）も成功。
その後に追加した27.2明示指定/27.0+27.1共存/旧27.0指定の正対照と不一致拒否は、
既存preflight一件（4.411秒）と既定OS/SDK一件（0.000秒）で再確認した。
全体/追加分の実行範囲を区別し、Apple比較40357278572と正式全15の実行結果は別に残す。
