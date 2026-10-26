# CIのAppleツールチェーン更新（2026-10-26）

利用者の更新指示を受け、配布済み449.1/source67273c0を基準とする。
着手時は配布/通常26/27にXcode・SDK27.0、手動訂正26/NativeにXcode26.6を固定していた。
まず既存Development workflowの手動input apple_inventoryでmacos-26/xcode-27の
実installed Xcode version/build・両device SDK・iOS runtime version/availabilityを読み取る。
インストール・選択変更・Simulator作成・学校通信・cache/artifactの保存は行わない。
初回比較では既存のportable/契約jobと正式15条件は減らさず、正式workflowは変更しなかった。

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

## 先行比較の完了

source256277270e10d956d36dcd93f953ac208e2e46eb/run40357278572/attempt1は全9job成功終端。
公式一覧と実inventoryの27.1/27A9275・SDK27.1、27.2 RC/27B48・SDK27.2、
26.6/17F113・iOS SDK26.5が一致した。Runtime27.0/27.1の共存も実一覧で確認した。
Nativeは27.1が688件/予定skip1/失敗0（113.047秒）、27.2が同688件（113.500秒）、
26.6が同688件（140.308秒）。Pickerは27.1の元3件/失敗0（355.511秒）、
27.2も元3件/失敗0（488.814秒）に加えて、元のtransition/layout検査がPASS。
portable599件/失敗0（69.731秒）、Python288件/予定skip22/失敗0（101.747秒）も成功した。
全9完了logを一度だけ所有stateへ保存し、同じ終端run/logは再照会しない。
27.2 RCの結果はこのNative/Picker範囲であり、全アプリ/実機/正式全15の成功ではない。

次のmain push一回専用に、別の新規GPT-6.1 Sol/High ios_ci_20261026_main_pre_actions_reviewが
patch515行/26963bytes SHA256 24e6761f6756079a8a7756f0a4916b48dd368bb2aa313ef5472d727b90860db5、
正式workflow470行/20264bytes ebf844ef…、relaunch117行/4989bytes 9c677594…、
manifest263行/12254bytes 0baae5ae…、runner201行/11120bytes fb32945a…、
runtime26/27各36行（02020a17…/db2bfe0a…）の全行/bytes/hashとcurrent sourceを確認し、
具体的指摘なし。主担当も現code差分の同一性と限定結果・全15の未完了を照合して使用する。
このreviewは次の正式main一回だけへ使い、限定review/旧449.1の成功は転用しない。

## 正式CIの経過

main/featureへsource7b73f1e13d03792b9a0f10b302a09e5599e0fe03をatomic pushし、
run40361714059/attempt1を16:42:40 UTCに開始した。専用main reviewはこの開始で消費済み。
予定した17:30 UTCの確認は17:31に一度だけ行い、Distribution、Native、通常27のA/B、
手動27の元4caseの計8必須jobが成功終端だった。全8完了logを一度ずつ保存した。
DistributionはPython288件/予定skip22/失敗0（86.385秒）、Nativeは688件/予定skip1/
失敗0（126.472秒）。通常27Aは元17件+別の通知1件の完了を確認した。
通常27B、手動27の4caseも成功し、SDK27.1/27A9275による実buildを確認した。
26Bは17:20:17、26Aと手動26の3caseは17:25:42ごろに開始し、残る手動26一件は待機中。
失敗はなく、元の全15条件と公開の確認は継続中。26Aの従来43〜48分と待機caseを踏まえ、
次のGitHub確認は18:15 UTC（翌03:15 JST）とした。終端run/logの反復取得はしない。

18:15 UTCの予定確認では全18job終端・13事前成功・単項目訂正26失敗・公開依存skip。
通常26のA/Bと他の訂正26三件は成功した。新6完了logとartifact0を一度確認し、
このrun/log/artifactは再照会しない。N155へ対処前の事実、完了ログ、過去詳細/旧現コードの
比較を記録した。旧Xcode26.6の単項目訂正26は、全文入力後の一回Switch接触が取消しとなり、
元45秒でACK value1が成立しなかった。27.1による通常26の成功を、この手動失敗の成功へ合算しない。

次の候補b6c8ebdは正式手動26も配布SDK27.1へ揃え、既存の厳密なRuntime26.5準備を追加する。
Native26.6/実SDK26.5と任意の旧手動probeは保持する。全Swift製品/helper/元4case×両OS/
一回接触/45秒/背景同一process/保存再起動と全15gateは同一。既存manifestのSDK設定期待に
加え、両手動laneのSDK変数・実操作前のRuntime準備を要求する。候補とN155根拠を隔離branchへ
pushしてからLinux/Swift6.1.2のmanifest全28件/失敗0（5.835秒）、catalog450/check --base7b73f1eを確認した。
これは新SDKで実手動操作が成功する証明や、旧SDKのgesture取消しの根本原因の特定ではない。

次の正式main開始一回専用の新規GPT-6.1 Sol/High ios_ci_20261026_n155_main_pre_actions_reviewは、
code patch50行/2668bytes SHA256 ff205cdc7bc7fe8fa10f9d0610dcfd9c8b2fb1157515776b5bce6b5885b29357、
workflow473行/20414bytes eca2601b…、runtime26 36行/2168bytes 02020a17…、
手動runner83行/5313bytes fd123f23…、公開gate86行/3819bytes c0851fa7…、
manifest263行/12254bytes 0baae5ae…の全行/bytes/hashを読み、具体的指摘なし。
主担当が現差分との同一性、元ケース/全15/失敗伝播と文書の未確認範囲を照合した。
このreviewは次のmain push一回だけへ使用する。前runの成功部分を新sourceへ合算しない。

## 451.1の公開と最終確認

source34c40d29dd67baaa7a7f2ebc342f1ac072505557/run40376846634/attempt1を18:20:21 UTCに開始し、
20:24:28 UTCに成功終端した。予定19:10/19:25/20:25 UTCのまとめ照会で新完了logだけを取得した。
19:25時点で27 Bも成功し、26の実開始と前回Bの51分・配布約21分を踏まえて次を20:25とした。
同じsource/run/attemptの全15必須条件が成功し、全18表示job終端・構成skip3・artifact0を確認。
全15実jobのログ、終端run、artifact0はそれぞれ一度だけ取得し、この実行を再照会しない。

正式の全通常UI/手動訂正はXcode27.1/27A9275、iOS SDK27.1とRuntime26.5/27.0を使った。
通常Aは各OS元17件と別通知1件、Bは元基本/通知/VoiceOver/OS文字サイズ3設定の厳密完了に成功。
手動27の単項目/原本変更/三項目/明示選択は921.974/422.297/469.273/762.785秒、
手動26は646.694/277.997/551.109/1291.524秒で各一件/失敗0。
元の実入力・独立した一回ACK・背景同一process・採用/保存/再起動・第4拒否と各期限は保持した。
Native26.6は688件/予定skip1/失敗0（158.287秒）、配布jobの27.1も688件/予定skip1/
失敗0（147.060秒）。配布jobの実Picker3件/失敗0（363.449秒）と元transition/layout、
iPhone Releaseビルドも成功した。DistributionはPython288件/予定skip22/失敗0（92.679秒）。
最初のSDK更新runのN155失敗と、旧SDKのgesture取消し原因が未確定であることは保持する。

完了publisherの実出力から[0.1.451（451.1）](https://github.com/n624-dev/takupoke-ios/releases/tag/v0.1.451-build.451.1)を特定した。
通常Release/Latest、公開4添付の匿名取得・全サイズ/SHA256とAPI digestの一致、
IPA内のversion0.1.451/build451.1/source34c40d2・最低OS26.0・SDKiphoneos27.1/
XcodeBuild27A9275・縦向き・AppIcon/Assets.carと公開1024pxアイコンを確認した。
既存のIPA/source検証器で法務/プライバシー・内部診断非同梱も照合し、固定Latest AltStore Sourceは
同Release添付と完全一致した。所有検証レシートを保持し、消費済みのダウンロード4添付だけを回収した。
物理iPhoneでのAltStore導入・更新、実学校PDF、issue66/67の実機性能は未確認。
27.2 RCは先行Native/Picker比較の成功範囲に限定し、正式全UI/実機成功へ拡大しない。
確認結果の文書pushはActionsを起動しない作業branchだけに行い、公開source/mainは変更しない。
