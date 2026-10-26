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
