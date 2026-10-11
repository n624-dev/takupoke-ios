# UIテストの失敗索引

UIの変更・実行前に、ケース名・ファイル名・操作・エラー・OSで検索する。
各項目は観測、試した変更、確認範囲だけを短く記す。詳細はリンク先を読む。
新しい失敗は次の試行前に追記する。未確認の原因を確定扱いしない。

全項目と過去の関連記録の比較は[2026-10-11の横断確認](ui-failure-patterns-20261011.md)を参照する。
順序の因果を断定しない最新判断は[方針再評価](ui-notification-reassessment-20261011.md)、
253失敗ジョブの原ログ再取得範囲は[照合一覧](ui-failure-log-audit-20261011.md)に記録する。

## U54 再起動後のリンク追加メニューが出ない（全体372、iOS26 B）

- 対象：bf1749aの`testLinkPreferencesSurviveRelaunch`。ケース176.396秒で失敗。
  最初の実長押し・お気に入り解除は成功。terminate／一回launch後の追加メニューが45秒内にない。
- 観測：二回目も行は全表示・hittableで、所有Buttonへ2秒の長押しを一回送った。
  操作後の架空画面は白く、後続AXは一覧を返す。BrowserView／Closeは観測していない。
  U42のブラウザへの遷移と同じ原因だとは断定しない。初回と再起動後の状態を区別する。
- 記録：操作後画像55495bytes、SHA256
  `3f7a16bd86a563f9e8c5838bf81d5d5eb90db66b0c99cf94e5e12be5fb544d71`を照合して確認した。
  架空画像はGitへ保存しない。リンク判定領域の既存修正は維持し、操作点を往復しない。
- 状態：この時点で26 Bの残りは実行中。取消・再試行・メニュー期待値の緩和はしない。
  原因は未確定。元の失敗を保持し、別ケースの候補成功に加算しない。
- 根拠：[372通常26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38170244888/job/114567895714)。

## U53 設定ボタンの文言再照会が停止（全体372、iOS27 A）

- 対象：bf1749aの`testFileFailuresKeepResultsAndStayInTheirOwnDetails`。
  実14件中13成功・1失敗、1981.480秒。失敗ケース274.900秒。
- 観測：設定タブ選択と時間割ファイルの存在は確認したが、tap前の表示範囲計算で
  `unobscuredViewport`の`element.label`照会がsnapshot timeoutになった。
  取得エラーの分離・前回結果保持の画面検証へは未到達。製品PDF解析失敗とは別。
- 比較：U05／U09のAX照会停止と関連する。初期設定footerの操作は専用の
  `tapSetupNext`を使い、スクロール本文のhelperから次へは操作していない。
  文言再照会を除く候補を検討する。原因・候補の効果は未確定。
- 観測追加：失敗後のAXサービス観測は実行した。logBytes4194305で上限超過し
  eventsはlimited、直近10分は失敗発生時刻を含まない。稼働状態から原因は証明できない。
  VoiceOverTouchの非稼働はこのAでは異常の証拠ではない。
- 状態：372は公開不可。26 Bを停止せず完了まで確認する。未実行の26 A／訂正26は未評価。
- 根拠：[372通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38170244888/job/114561354480)。

## U52 発話観測待ちでも移動失敗・再起動後Switchも未反映（対象50、iOS27）

- 対象：a87f9a9の元の設定／VoiceOver2件。2失敗・244.509秒。取消なし。
- VoiceOver：実見出しtap後45秒のquery開始期限内に発話取得なし、観測0。
  元の実moveへ進んだがindex0でAX Code3、完了move0。ケース93.000秒。
  観測待ちだけでは解消せず、見出し選択や初期化状態の原因は未確定。
- Switch：最初のON→OFF→ONはUI・保存値とも成功。再起動後4回目ON→OFFだけ未反映。
  行とnative controlは状態1一致・hittable・表示包含。実tap1回後45秒でも双方1。
  新pidのsetter記録がなく、設定case151.508秒で失敗。U43と同じ操作段階で再発した。
  各cold起動のSystem UI準備は確認済みで、その観測だけでは実入力の成立を保証しない。
- 状態：候補は不合格。main／Release／AltStore Sourceは更新しない。
  待機を成功した改善にせず、再tap・SDK変更・期待値注入で救済しない。
- 根拠：[対象50](https://github.com/n624-dev/takupoke-ios/actions/runs/38166330630/job/114549542656)。

## U51 手動訂正3項目がjob期限で終了（全体371、iOS27）

- 対象：694a862の`testThreeFieldsRequireEachAcknowledgementAndFourRefuses`。
- 観測：GitHubのcheck annotationは「The job has exceeded the maximum execution time of 45m0s」。
  jobは18:16:58〜19:11:58 UTCでcancelled。こちらから停止操作はしていない。
  個別caseの完了ログは取得できず、成功件数・処理中断点・清掃完了は未確認。
- 比較：同じcaseの全体370は成功。371の他2訂正27も成功した。
  VoiceOverのAX Code3とは別の実行エラーで、アプリ・Simulatorの下位原因は未確定。
- 状態：訂正仕様の成否は未評価。期限の延長・期待値変更・再試行の救済は行わない。
  残りの26 Aと対象50は停止しない。新しい実行前にU51と起動系の記録を検索する。
- 根拠：[371手動訂正3項目](https://github.com/n624-dev/takupoke-ios/actions/runs/38163060293/job/114540080170)。

## U50 実見出しtap後も最初の移動が失敗（全体371、iOS27 B）

- 対象：694a862の通常27B、元の11件。10成功・VoiceOverのみ46.665秒で失敗。
- 観測：enable1、実見出しの一意・表示包含・hittableと物理tap1回を確認。
  最初のmove index0でAXVoiceOverAutomationErrorDomain Code3、完了move0。
- 比較：同じソースの対象49では18回の移動と元の3項目検査が成功した。
  enableからtap完了まで対象49は36.568秒、371は1.897秒。タップだけでは安定しない。
  差は実要素照会と実操作の所要時間で、sleepは導入していない。時間差は因果の証明ではない。
  U48はtap後のcurrentSpeechを1回試してNo speech available、移動自体は未評価だった。
- 状態：371は公開不可。残りのActionsは停止せず監視する。読み上げ期待値の救済なし。
- 根拠：[371通常27B](https://github.com/n624-dev/takupoke-ios/actions/runs/38163060293/job/114540080074)。

## U49 除外保存後の再起動でprocess取得失敗（全体370、iOS26 A）

- 対象：2b94d1cの`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`。
  除外選択・確認・保存後、terminateから再起動する1回のapp.launchで失敗した。
- 観測：前processのnotRunningとSpringBoardの応答を確認した後、
  NSPOSIXErrorDomain Code3／No such process、Failed to get launch progress。
  ケース213.588秒。初回起動・操作は成立しており、起動後の保持確認は未評価。
- 比較：U40／U41の起動系と関連するが、今回は同じケースの保存後再起動である。
  U46のAXVoiceOverAutomationErrorDomainとは別domain。製品やSDKの下位原因は未確定。
- 状態：元の14件中13成功・1失敗、1894.654秒。通知区間は未実行。
  残りを取消せず完了まで確認した。370はfailure、公開skipで新しい配布物なし。
  起動再試行・期限延長・case省略は行わず、VoiceOver候補の成功にも加算しない。
- 根拠：[370通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38156030685/job/114528035630)。

## U48 実見出しtap後も初期発話取得で失敗（対象48、iOS27）

- 対象：70cb0f5の設定／VoiceOver2件。設定317.960秒は成功、VoiceOver47.495秒は失敗。
- 観測：enable1、実見出し一意・frame包含・hittableを確認し、1回の物理tapを完了。
  currentSpeechはNo speech available、speech-complete0・移動0。
- 比較：U47の取得単独に加えてtouchも成立したが、初期取得は解消しなかった。
  初期発話取得を移動前の必須条件としたため、touch後の実移動はまだ評価していない。
  発話の取得失敗から、focusがないことや後続移動が必ず失敗することは証明できない。
- 次の比較：不採用の初期currentSpeechと前後ログ3行を撤回する。
  実見出し1回touchを保持し、元の最大60回の実移動・3項目の期待値で検証する。
  これはtouchなしのU46へ戻す試行ではない。初期発話による救済も再試行も行わない。
- 状態：対象48はfailure、取消なし。新ソースの全体・公開は開始していない。
- 根拠：[対象48](https://github.com/n624-dev/takupoke-ios/actions/runs/38160134344/job/114531118898)。

## U47 初期発話取得だけでもNo speech available（対象47、iOS27）

- 対象：b114a0fの設定／VoiceOver2件。設定300.740秒は成功、VoiceOver70.403秒は失敗。
- 観測：enable後isEnabled1、currentSpeech開始後にcom.apple.xctest.voiceoverservice
  Code3／No speech available。speech-completeも移動開始も0件。
  U46のAXVoiceOverAutomationErrorDomain Code3とは別domainで、整数だけで同一原因としない。
- 比較：初期発話の取得1回では解消しなかった。非空の追加条件は導入前レビューで撤回済み。
  現在focusがないことや、Simulatorの下位不具合までを証明した結果ではない。
- 次の比較：VoiceOver有効化後、実画面の受動的な時間割見出しへ物理tapを1回行う。
  実要素・有限で表示されたframeから操作点を求め、画面位置を決め打ちしない。
  その後の実発話取得と最大60回の移動、元の3項目の期待値を維持する。
  tapの再試行・focus値や発話の注入・SDK変更は行わない。効果は未確認。
- 状態：対象47はfailure、取消なし。新ソースの全体検査・公開は開始していない。
- 根拠：[対象47](https://github.com/n624-dev/takupoke-ios/actions/runs/38158591600/job/114526584843)。
  [Apple VoiceOver gestures](https://support.apple.com/guide/iphone/iph3e2e2281/ios)は
  実項目へのtap／touchで項目を選択し発話する操作を説明する。APIエラーの解消保証ではない。

## U46 有効化後の最初のVoiceOver移動が失敗（全体370、iOS27 B）

- 対象：2b94d1cの通常27B、元の11件。10件成功、VoiceOverのみ55.523秒で失敗。
- 観測：enable後のisEnabledは1。move-start index0の直後にCode3で失敗し、
  move-completeは0件。失敗は最初の命令で、名前の期待値判定には到達していない。
- 比較：観測46では同じソースの設定／VoiceOverが成功し、19回の実移動が完了した。
  短い成功は全体での安定性を証明しなかった。U45の新規device分離も不採用のまま。
- 次の比較：最初の移動前に実currentSpeechを一度取得する。戻り値は成功データに使わない。
  有効フラグだけで実際の発話・focus準備を証明できない不足を対象にする。
  改善効果は未証明。命令再試行・固定待機・skip・AXラベル代替は導入しない。
  3項目の期待値は元の実移動結果に対して維持し、初期発話で代替しない。
- 状態：27Bはfailure。残りのActionsを取消せず確認する。370は公開不可。
- 根拠：[370通常27B](https://github.com/n624-dev/takupoke-ios/actions/runs/38156030685/job/114519233325)。
  [Apple currentSpeech](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice/currentspeech())は
  現在focus中の要素の発話を返すAPI。Code3の一般的な解消条件ではない。

## U45 新規SimulatorでもVoiceOver命令失敗（診断45、iOS27）

- 対象：1c86938の設定→VoiceOver、元の2ケース。設定は298.766秒で成功、
  VoiceOverは73.107秒でmoveForwardの同じAXVoiceOverAutomationErrorDomain Code3。
- 観測：設定区間の厳密な1件完了照合後、別の所有Simulatorへ移り、
  同じビルドで次のRunnerを実行した。bootstatus109.1秒。実分離は通ったが解消しない。
  失敗した移動回数とenable後の実isEnabledは記録がなく未確定。
- 比較：U44の長い前区間や同一deviceだけではエラーを説明できない。
  新規device分離を合格した改善として維持せず、同じ条件の全体再実行は行わない。
  読み上げ期待値・操作・SDKは固定。命令エラーをskip・AXラベルで救済しない。
- 状態：診断45はfailure。人による取消は行わず終了まで確認した。全体検査・公開へ進めない。
- 根拠：[診断45](https://github.com/n624-dev/takupoke-ios/actions/runs/38152235655/job/114507889386)。
  途中取得ログは更新が遅れ、設定後の終了停止と誤って説明したが、最終ログでは
  次区間へ進んでいた。遅れたログから処理停止を断定しない。

## U44 VoiceOver移動命令だけが再発（全体369、iOS27 B）

- 対象：643be57の`testVoiceOverReadsTimetableCard`。元の11件区間は
  1235.630秒、他10件成功、VoiceOverのみ失敗。読み上げ期待値は変更していない。
- 観測：実System UI準備・cold起動・時間割遷移後、moveForwardが
  AXVoiceOverAutomationErrorDomain Code3で失敗。ケース全体132.691秒。
  失敗した移動回数と下位原因は未確定。ラベルの存在で読み上げを代替しない。
- 比較：U43と同じ命令エラーだが、再起動後を含むSwitch4回のUI・保存値は
  今回すべて1→0→1→0で成功。各cold起動前の準備だけでは再発を防げなかった。
  PDF修正以外のUI構成・SDK・操作・ケースは368と同じ。製品の原因とは断定しない。
- 次の比較：VoiceOverの同じケースを別Runner・新しい所有27Simulatorへ分離する。
  同じビルドを再利用し、実移動・3項目の読み上げ・全選択の完了照合を維持する。
  再試行・skip・期限延長で救済しない。成功するか、最善の方式かは未証明。
- 状態：5事前ジョブ成功、27B失敗。旧許可に基づく取消要求が新しい禁止指示の
  直前に送信され、369はcancelled、27Aと後続検証は未完了。369は未公開。
  以後は失敗後もActionsを停止せず、残りの結果を確認する。
- 根拠：[369通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38149074887/job/114498668741)。

## U43 再起動後のSwitch入力未反映とVoiceOver命令失敗（全体367、iOS27 B）

- 対象：4c43707の`testSettingsAccountDataAndFileDetails`と
  `testVoiceOverReadsTimetableCard`。元の11件区間は2失敗・1065.248秒。
- Switchの観測：同じ最初のプロセスのON→OFF→ONはUI／保存値とも成功。
  再起動後の4回目ON→OFFだけ、一回の実tap後45秒経っても両方1のままだった。
  行／Native trackは表示・hittable・状態一致を確認。新しいpidでsetter記録がない。
  123.856秒で失敗し、押し直しや期待値注入で救済しない。
- VoiceOverの観測：別の新規起動後、moveForwardがAXVoiceOverAutomationErrorDomain
  Code3で失敗。41.526秒。失敗した移動回数・下位原因は未確定。
  再取得した過去253原ログに同じdomainはなかった。全履歴の不存在証明ではない。
- 比較：U04／U19の入力未反映は参照するが、初回ではなく再起動後であることを保持。
  初回だけ成功したSystem UI準備を新規プロセスへキャッシュしていた。
  次は各cold起動前に実System UIを確認する小さい比較とする。
  操作点・SDK・通知順序・実スイッチ／読み上げの期待値は固定する。
  2件が同じ原因であることも、この候補で解消することも未証明。
- 状態：リンクの長押し74.740秒と最初の起動は成功。5/12事前検査は成功したが、
  通知区間・文字サイズ・対応26へは未到達。必須失敗とソース照合後に残りを中止。
  367は未公開。元の成功を新しいソースの全体合格に流用しない。
- 根拠：[367通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38135873350/job/114459721158)。

- 小さい比較の結果：d402ed5の[診断44](https://github.com/n624-dev/takupoke-ios/actions/runs/38138647623)で
  同じ27の設定・VoiceOver2件が失敗0で完了。準備を各cold起動前に確認し、
  再起動後のOFFと実読み上げを元の操作・期待値で確認した。
  全体368でも対象2件は成功した。共通原因や一般的解消の証明ではない。

- 公開ソースの確認：d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)は全13検査が成功。
  再起動後を含むスイッチ4回のUI・保存値1→0→1→0と実読み上げを確認した。
  一回の最終構成の結果であり、下位原因や恒常的安定性は未証明。

## U42 長押しがメニューではなくブラウザを開く（全体366、iOS26 B）

- 対象：e4f2fbfの`testLinkPreferencesSurviveRelaunch`。
  最初の解除操作で失敗。可視行・内側テキスト・hittableを確認し、
  所有Buttonへ2秒の物理長押しを一回行った。45秒内に解除メニューがなかった。
- 観測：114.294秒・失敗1。操作前の架空画像には一覧と対象行があり、
  操作後の画像は白いブラウザ画面への遷移。失敗時AXにはBrowserViewとCloseがある。
  primary actionへ進んだ観測で、通知要求の未返答や起動失敗とは区別する。
- 過去比較：全体339・346と過去試行37670677438にも解除メニュー不在がある。
  テキスト中央の座標とNative Buttonの長押しは既に比較済み。
  操作点を往復せず、新しい比較はメニュー所有Buttonのhit-test形状を明示する。
  原因・候補の成功は未確定で、既存の長押し・保存・再起動のケースを維持する。
- 状態：元の11件区間は予定skip1・失敗1。通知区間・追加文字サイズに進まず、
  26通知device分離は未評価。27 A/Bと手動訂正27の3ケース、26の原本変更、
  Native・配布検査の8ジョブは成功したが、全体合格ではない。
  必須失敗とソースを照合後、利用者の許可に従い残りを中止。366は未公開。
- 根拠：[366通常26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38130333787/job/114449755554)。
  架空画像は所有一時領域だけで確認し、Gitへ保存しない。

- 小さい比較の結果：ee9ef9fの[診断43](https://github.com/n624-dev/takupoke-ios/actions/runs/38135043792)で
  同じ26の1ケースが95.367秒・失敗0で完了。Button自身のinteraction形状だけを追加し、
  元の長押し・実メニュー・保存・再起動を確認。全体合格や下位原因の確定ではない。

- 公開ソースの確認：d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)は全13検査が成功。
  両OSで元の2秒長押し・実メニュー・保存・再起動を確認した。
  一回の最終構成の結果であり、下位原因や恒常的安定性は未証明。

## U41 最初のケースでapp.launchが期限切れ（全体365、iOS27 B）

- 対象：710d0c4の`testChangedAccountDataNoticeOpensSharedAcquisition`。
  27側の準備・device共有・順序は成功した364から変更していない。
- 観測：bootstatus終了後、最初のapp.launchがXcodeの起動timeoutで失敗した。
  217.268秒・失敗1。後続10件は成功したが、元の11件区間は不合格。
  通知区間・追加文字サイズ・対応26 Bには進まなかった。
- 比較：U40は26の2区間目の起動。今回は27の最初の起動であり、
  許可要求前の停止。debugger-versionのnoURLは成功した364にもあるため原因と断定しない。
- 状態：26のdevice分離は未評価。必須27 Bの失敗とソースを照合後、
  公開不可が確定した365の残りを、利用者の既存許可に従って中止した。
  既存の成功や後続10件で、このケースの失敗を救済しない。
- 方針：順序・SDK・再起動の往復はしない。fixtureと起動構成の整合性を先に確認する。
  下位原因は未確定。製品APIの変更、期限延長、許可注入、ケースの再試行は行わない。
- 根拠：[365通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38127078166/job/114433735062)。

- 公開ソースの確認：d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)は全13検査が成功。
  各cold起動前の実応答確認を使い、元の初回起動ケースも完了した。
  一回の最終構成の結果であり、下位原因や恒常的安定性は未証明。

## U40 通常14件成功後の別Runnerでアプリ起動失敗（全体364、iOS26 A）

- 対象：83d3fb5の`testChangedDataProducesOneLocalNotification`。
  同じ所有Simulatorで通常14件1707.475秒・失敗0を確認後、別Runnerへ移った。
- 観測：`app.launch()`中にDTServiceHubのprocess再開が失敗した。
  XCTestの再起動後は0件・失敗0と表示されたが、対象ケースはfailing testで終了した。
  許可要求・Allow・保存・配信へ進んだ証拠はない。0件の集計を成功とは扱わない。
- 比較：27 A/B・26 Bと手動訂正6件、Native・配布検査は成功した。
  U38と同じく事後診断はdevice-not-booted／unknown-sessionだが、
  今回は設定タブ操作前の起動で停止した。Simulator停止の下位原因は未確定。
- 状態：11/12事前検査成功、26 A失敗、公開ジョブskip。364は未公開。
  通知の先頭・最後を往復して再実行しない。許可APIの未返答とも区別する。
- 次の比較：26の通知区間だけ新しい所有Simulatorへ分離する案を評価する。
  成功済み区間を再試行せず、ビルド・ケース・実操作・期限・全体の照合を維持する。
  既存deviceの再起動を繰り返すU35の案とは区別し、解消済みとは扱わない。
- 根拠：[364通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38122306542/job/114425991933)。

- 公開ソースの確認：d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)は全13検査が成功。
  26の通知deviceを分離し、実許可・保存・新規通知配信まで確認した。
  一回の最終構成の結果であり、下位原因や恒常的安定性は未証明。

## U39 通知を先頭へ分離すると初回未返答が再発（全体363、iOS27 B）

- 対象：2f68a90の`testNotificationControlsAndAppearance`。同じビルドとdeviceを使い、
  通知を最初の独立Runnerへ移した。設定遷移と実Switch一回のBindingは成功した。
- 観測：実要求の同期戻りあり、45秒内のAllow・callback・保存ONなし。
  1ケース100.948秒・失敗1。後続と文字サイズを実行せず失敗終了した。
  U38の設定タブ停止を再現したという意味ではなく、U37の初回未返答が再発した。
- 比較：同じ363の27 Aの先頭通知は実Allow・保存・配信まで79.679秒で成功した。
  残るAは中止したため全件成功ではない。先頭なら常に失敗するという意味ではない。
- 結論：この構成の363は公開条件未達。順序を失敗原因と断定しない。
  通知を先頭に移す構成は不採用。全体362では他の画面ケースの後に
  27 A・Bの実許可が成功していた。次は元の前提操作を先に保ち、通知だけを
  最後の独立Runnerへ分離する。固定sleep・期限延長・テスト再試行は追加しない。
  下位原因は未確定で、待機時間だけを原因と断定しない。
- 状態：必須27 Bが失敗したため対応26 Bは開始しなかった。公開不可が確定した
  363の残りは利用者の許可に基づき中止する。既存成功を次のソースへ流用しない。
- 根拠：[363通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38120972871/job/114415615207)。

## U38 設定タブ操作後にRunnerが再起動（全体362、iOS26 B）

- 対象：d2ccbd4の`testNotificationControlsAndAppearance`。設定タブの実tap後、
  12.82秒のidle待ちを最後に記録が途切れ、約169秒後にXcodeがRunnerを再起動した。
  通知画面・許可要求へ進んだ記録はなく、U37の未返答とは停止段階が異なる。
- 結果：後続8ケースは予定skip1・失敗0だったが、Xcodeの最終結果は通知ケースを
  failing testとして終了した。全件成功と扱わず、文字サイズ追加と公開は開始しなかった。
  終了時のdevice-not-bootedは事後診断であり、タブ停止の原因の証明ではない。
- 状態：Runnerの終了がcrashかtest timeoutか、下位原因は未確定。
  同じ全体362の通常27 A・B、26 A、手動訂正6ジョブ、Native・配布検査は成功した。
- 次の比較：通知ケースを同一ジョブの別Runnerで先に実行する。
  同じビルド・所有Simulatorを使い、対象ケースを重複させず、各区間と全選択の
  完了を検証する。期限・実操作・期待値・全13公開条件を維持する。
- 根拠：[362通常26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38116598744/job/114402796799)。

## U37 所有Device Hub画面を指定しても初回許可が未返答（診断41、iOS27）

- 対象：d2ccbd4の通知2ケース。通常SDK27.0で、bootstatus後に所有UDIDの画面を指定した。
  初回配信は98.378秒で失敗、次の通知設定は実Allow・callback・保存まで266.544秒で成功。
  全2件・1失敗、計364.922秒。秒数はケース全体である。
- 観測：初回はSDK同期戻りあり・callbackなし、45秒内のAllow・保存ONなし。
  OSログ取得は終了0・423,231 bytes、3サービスの稼働を観測した。
  26は2件成功、計252.676秒。実Allow・保存・配信・再起動を確認した。
- 結論：所有画面を指定する準備だけでは初回未返答を解消できない。
  openの正常終了は、実際の画面表示や通知提示の証明ではない。下位原因は未確定。
  製品・45秒・実操作・全13条件は変更しない。
- 根拠：[41通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38116201187/job/114401469377)、
  [通常26](https://github.com/n624-dev/takupoke-ios/actions/runs/38116201187/job/114401469320)。
- 並行検証：同じソースの全体362は、この結果確定前に開始した。
  その全13結果は別に確認し、個別ケースの成功を公開条件へ代用しない。

## U36 27.1 betaでも同じRuntimeの通知要求が未返答（診断40、iOS27）

- 対象：4bba1b6の通知2ケース。Xcode27.1 build27A9269、実SDK27.1、Runtime27.0を
  事前確認した。27は90.421／115.772秒で両方失敗、計206.194秒。秒数はケース全体。
- 観測：実Switchから要求へ進み、同期戻りあり・callbackなし。45秒内にAllowも保存ONもなし。
  所有SimulatorのOSログ409,568 bytes・取得終了0。要求を受けたOSサービスも観測した。
  26は113.338／176.167秒、計289.505秒で2件成功。初回の実Allow・配信と保存・再起動を確認。
- 結論：ツールチェーンを旧27.1 betaへ替えるだけでは解消しない。通常配布SDKは変更しない。
  OS内部／XCTest／fixtureの下位原因は未確定。API変更やSDKの修正完了と断定しない。
- 根拠：[40通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38114822271/job/114397520767)、
  [通常26](https://github.com/n624-dev/takupoke-ios/actions/runs/38114822271/job/114397520932)。

## U35 実install後の初回テスト前再起動でも許可が未返答（診断39、iOS27）

- 対象：b34bd1fの通知2ケース。27は初回111.183秒で失敗、次の通知設定は
  実Allow・callback・保存・再起動まで393.528秒で成功。計504.710秒、1失敗。
  26は2件成功（222.672秒）。秒数はケース全体の時間。
- 観測：初回bootstatus・実install・所有deviceの再起動bootstatus完了後に実行したが、
  初回要求は同期戻りあり・callbackなし。局所OSログ382,966 bytes・取得終了0。
  次プロセスの実要求は36.613秒でcallbackに到達した。
- 結論：Webの再起動報告は、この事前準備では再現改善しなかった。恒常的な準備へ残さない。
  既存の製品・実操作・45秒・全13条件は維持する。
- 次の比較：同じiOS27.0 Runtimeで、Runnerにある27.1ツールチェーンだけを追加比較する。
  通常配布SDKは変更せず、品質合格や公開前の全体検証へ代用しない。
- 根拠：[39通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38113398465/job/114393417764)。

## U34 Device Hubを開いても初回の許可が未返答（診断38、iOS27）

- 対象：249037bの通知2ケース。27は初回110.116秒で失敗、次の通知設定は
  実Allow・callback・保存・再起動まで222.650秒で成功。計332.767秒、1失敗。
- 観測：初回要求は同期戻りあり・callbackなし。局所OSログ取得は終了0・401,299 bytes。
  Device Hubの不存在エラーはなく、画面を開くだけでは未返答が解消しない。
  26は2件成功（232.329秒）。初回・次プロセスの違いは原因の確定ではない。
- 新しい根拠：[Apple Forums 849449の返信](https://developer.apple.com/forums/thread/849449)に
  同じUserNotificationsの未返答とSimulator再起動での改善報告がある。本文のAlarmKitとは区別する。
- 次の比較：初回テスト前に実アプリinstall後、所有Simulatorを一度再起動する準備案。
  効果は未評価。製品・実許可・操作数・45秒・全13条件を維持する。
- 根拠：[38通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38112276765/job/114390139488)、
  [全履歴の比較](ui-failure-patterns-20261011.md)。

## U33 Xcode27にないSimulator.appの起動で停止（全体361）

- 対象：aa73758の通常27 A／B。UIビルドは成功したが、追加した画面起動で
  `Simulator.app`がないため終了1。XCTestを開始しておらず通知停止の再現評価ではない。
- 原因：Xcode27のDevice Hubへの変更を考慮せず、旧Simulatorのパスを使用した修正ミス。
  起動処理を選択Xcode内の実在するアプリに合わせる。Device Hubに旧UDID引数は渡さない。
- 根拠：[361通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38111810296/job/114388890989)、
  [通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38111810296/job/114388890984)、
  [AppleのDevice Hub案内](https://developer.apple.com/documentation/xcode/device-hub)、
  [argentの当事者報告](https://github.com/software-mansion/argent/issues/406)。
- 状態：公開不可が確定した旧実行の中止を利用者が追加許可し、361はcancelledまで確認。
  全13条件は維持し、361は未公開。
  従来の通知callback停止（U32）をこの新しい起動エラーと同一原因にしない。

## U32 標準タブ操作でも通知許可が未返答（診断37、iOS27）

- 対象：f4c656a（製品とテスト実装は1e220d7と同じ）の両通知ケース。
  配信110.495秒・設定103.681秒で失敗、2件2失敗（214.177秒）。
- 観測：標準タブtapの選択・設定画面への遷移は成功した。
  その後の実通知要求は同期戻りあり、45秒内のAllow・callback・保存ONなし。
  OSログは終了0・395,152 bytesで、usernotificationsdのrequest Authorizationを保持した。
- 状態：タブの不発とは別の停止。接続終了errorは成功例にもあり、根拠なしに原因としない。
  26は2件成功（318.247秒）。実Allow・callback・保存・再起動・新規配信を確認した。
- 次の扱い：利用者の指示に従い診断の追加を停止する。未コミットのOS書式・時刻の
  診断拡張は取り消した。27の停止原因は未確定で、37は公開条件を満たさない。
  製品コード・実操作・45秒・全13条件は維持する。
- 根拠：[診断37通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38110490234/job/114384843641)。

## U31 通知要求はOSサービスへ届くが許可画面が現れない（診断36、iOS27）

- 対象：185a65fの両通知ケース。93.462／86.784秒で失敗、全2件2失敗（180.246秒）。
- 観測：同期SDKは戻るが、45秒内にAllow・callback・保存ONはない。
  局所80秒ログは取得終了0・393,226 bytes。`usernotificationsd`のrequest Authorizationを
  今回初めて保持できた。SpringBoardの許可・grantedは保持された記録にない。
- 限界：OSログの固定語彙と上限内の選択であり、ないことはOS内の呼出し不存在の証明ではない。
  接続無効化・errorは成功した26にもあり、それだけで原因とは断定しない。
- 次の比較：U30のタブ操作を標準hit pointへ変更する候補1e220d7は、この27の結果取得前に
  push済み。27の許可停止を直す変更とは扱わない。実要求・45秒・実Allowを維持する。
- 根拠：[診断36通常27](https://github.com/n624-dev/takupoke-ios/actions/runs/38109734983/job/114382626520)。

## U30 初回の設定タブ操作後に選択が変わらない（診断36、iOS26）

- 対象：185a65fの通知配信ケース。設定タブ一回の実操作後もホームが選択されたまま。
  88.320秒で失敗。許可要求まで進んでおらず、通知callback停止とは別の失敗。
- 観測：タブバー・ボタンの表示枠、enabled・hittableを確認して中心を一回タップ。
  45秒内の現在の設定タブの選択は確認できなかった。期限後の階層もホームを示す。
- 同じ実行の次ケース：通知設定は144.637秒で成功。実Allow・callback・保存を確認した。
  全2件中1失敗（232.957秒）。OS観測は取得終了0・890,980 bytesで、許可の記録を保持。
- 状態：一回のタップが選択へ反映されない原因は未確定。次ケースの成功で救済しない。
  押し直し、選択の注入、期限延長は行わない。
- 根拠：[診断36通常26](https://github.com/n624-dev/takupoke-ios/actions/runs/38109734983/job/114382626599)。

## U29 通知設定の許可待ちと局所OSログの切捨て（全体360、iOS27 B）

- 対象：9b3ac23の通知設定。110.618秒で失敗、全12件中1失敗（1536.453秒）。
  同じ全体の27 Aの通知配信は51.544秒で成功した。
- 観測：SDK同期呼出しは戻り、45秒内のAllow・callback・保存ONなし。
  要求時刻の80秒ログは取得終了0・332,389 bytesだった。
- 診断の限界：全イベントの末尾80件だけを残したため、画面照会に伴う
  SpringBoardの接続・表示ログで埋まり、許可要求の記録を保持できていない。
  サービス稼働・固定語彙の表示だけから下位原因を断定しない。
- 次の比較：許可・通知・エラーに関係するイベントを優先し、元の順序を保持して
  上限内に選ぶ。各読み取り失敗は別々に扱い、他の段階の観測を失わせない。
  製品コード・実操作・45秒・一回要求を維持する。360は公開不可。
- 根拠：[360通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38107075743/job/114374844570)。

## U28 通知2ケースとも許可待ち・OS観測も取得不能（診断35、iOS27）

- 対象：9b3ac23の通知2ケース。27は98.863／91.982秒で失敗、全2件2失敗
  （190.845秒）。26は108.371／172.518秒で成功（280.890秒）。
- 観測：27は実Switch操作後requesting=trueのまま、45秒内のAllow・保存ONなし。
  OS診断は両OSともunavailable、27の所有記録取得もunavailableで、OS状態は判別不能。
  26では実AllowとSDKの同期戻り・callback・保存・実配信を確認した。
- 状態：固定語彙を増やしても取得不能だった。今回の27では同期戻りの記録自体も
  未取得で、U27と同じ段階と断定しない。読み取りコマンドの失敗箇所は未記録。
- 次の扱い：全体360はこの結果の取得前に開始済みで、継続して全ジョブを確認する。
  検査を除外せず、製品の解析・通知規則を原因未確定のまま追加変更しない。
- 根拠：[診断35](https://github.com/n624-dev/takupoke-ios/actions/runs/38106669988)。

## U27 同期SDK呼出しは戻るが通知許可の返答がない（両OS診断34）

- 対象：9d1eb79、通知2ケース。26は2件成功（281.769秒）。27は配信150.763秒で失敗、
  設定は成功、全2件中1失敗（353.754秒）。
- 観測：27の初回要求は同期呼出し後の記録があり、45秒以内のcallback・Allowがない。
  続くプロセスの要求ではcallbackが返った。要求時刻の80秒ログは取得終了0・76,108 bytes。
  SDK呼出し自体の同期停止ではない。OSの提示・返答停止の原因は未確定。
- 診断の限界：固定語彙が少なく、提示の詳細状態は判別できない。26の成功経路では
  清掃前の観測呼出しが抜けており、同じOS観測の成功例には使えない。
- 次の比較：架空Simulatorだけで固定語彙の提示・待機状態を増やし、成功時にも清掃前に
  読み取り専用で観測する。実要求・45秒・一回操作・全体公開条件は維持する。
- 根拠：[診断34](https://github.com/n624-dev/takupoke-ios/actions/runs/38081878973)。

## U26 通知許可の応答停止がiOS26でも再発（全体359）

- 対象：`testChangedDataProducesOneLocalNotification`、e191bf3の26 A。
- 観測：許可の完了を確認できず121.029秒で失敗、15件中14成功・1失敗
  （1662.604秒）。同じ359の26 Bの通知設定は成功した。
- 状態：U25と同じ要求後の停止段階。27固有の障害とは断定しない。
- 次の観測：9d1eb79の両OS診断はこのログ取得前に開始済み。
  SDK呼出しの戻りと、要求時刻の局所ログを確認する。条件・許可の注入は行わない。
- 根拠：[359通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018/job/114287713351)。

## U25 通知設定ケースでも許可要求が応答しない（iOS27、全体359）

- 対象：`testNotificationControlsAndAppearance`、e191bf3の27 B。
- 観測：許可待ちが98.613秒で失敗。全12件中11成功・1失敗（1583.366秒）。
  初期設定75.428秒は成功し、U23の表示枠修正の確認と通知停止を分ける。
- 状態：U24と同じ要求後の停止段階。終了時10分の診断は約22分前の失敗を含まない。
  現在の要求直前のラベルだけでは、SDKの同期呼出しが戻ったかも分からない。
- 次の観測：架空アプリだけにSDK呼出し直後のラベルを追加し、未返答の要求時刻から
  有界な局所OSログを取得する。実許可・保存・配信・45秒・一回の要求は維持する。
  製品の通知・PDF規則は原因未確定のまま追加変更しない。359は公開不可。
- 根拠：[359通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018/job/114287713301)。

## U24 ビルド後のSimulator起動でも通知の応答停止が再発（iOS27、全体358）

- 対象：`testChangedDataProducesOneLocalNotification`、5cfc575の27 A。
- 観測：実Switch一回・requesting=true・実SDK要求を確認したが、45秒内に
  Allow・callbackがなく103.590秒で失敗。全15件中14件成功・1件失敗だった。
- 状態：U21・U22と同じ停止段階。1305b27の個別成功を一般的な解消とは扱わない。
  ビルド後にSimulatorを起動しても再発したため、その順序だけを原因・解決としない。
- 診断の限界：終了時は3サービス稼働、ログ取得終了0・3,860,984 bytesだった。
  診断は終了直前10分で、約28分前の要求を含まない。要求時の状態の証明には使えない。
- 次の検証：359はこの失敗ログ取得前に開始済み。表示枠のみの修正であり、
  通知停止の修正比較としては数えない。再発時は要求時刻の局所ログが必要。
- 根拠：[358通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38075094896/job/114280469251)。

- 後続の結果：d402ed5の全体368は全13検査が成功し、
  実通知許可・保存・再起動・配信を確認した。通知の実装と45秒は変更していない。
  間欠的な停止の一般的な原因・解消の証明にはしない。

## U23 初期設定footerの表示枠が取得できない（iOS27、全体358）

- 対象：`testSetupCanBeSkippedAndOffersAllFiles`、`ApplicationChecks+Navigation.swift`。
- 観測：時間割ファイル画面の試験見出しを探す際、次へボタンは一件存在したが、
  枠の照会に再試行が入り、有限の正の寸法という即時検査で失敗した（44.271秒）。
  実際の枠の数値は未記録。遷移やアニメーションが原因とは断定しない。
- 状態：U10の操作可能性の照会とは異なる受動的な寸法取得の失敗。
  同じ27 Bの通知許可・保存は成功し、全12件中11件成功・1件失敗だった。
  358は公開不可。ほかの実行中ジョブは中止せず完了を確認する。
- 次の比較：存在するfooterの不明な枠を「不在」として扱わず、表示範囲未確定とする。
  既存の6回・各2秒の待機内で再観測し、未確定時はスクロールしない。
  完全な包含・一意性・実操作の検査は維持し、待機切れは失敗とする。
- 根拠：[358通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38075094896/job/114280469182)。

- 確認範囲：表示枠の未確定を区別したd402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)で、
  両OSの初期設定ケース、通常4ジョブ、全13必須チェックが成功した。
  既存の待機内で表示枠と完全包含を検証した。枠取得が失敗した一般的な原因は未確定。

## U22 通知2ケースの診断で初回許可だけが停止（iOS27）

- 対象：9e28e63の通知2ケース診断、U21と同じ実SDK要求経路。
- 観測：通知配信134.000秒で失敗、続く通知設定325.871秒で成功。
  初回要求には45秒内の許可画面・callbackがなく、次の要求には実Allowと返答があった。
- 状態：原因未確定。終了時にはSpringBoard・lsd・usernotificationsdが稼働、終了値0。
  この事後観測を要求時の準備完了の証明にしない。OSログは取得不能／上限超過で区別不能。
- 次の比較：既に開始していた1305b27ではビルド後に所有Simulatorを起動する。
  以後の失敗観測はログを対象bundle・許可／接続エラーへ絞り、終了値とサイズを区別する。
  許可・保存・配信・45秒・一回操作は維持する。失敗ケースの成功扱いは行わない。
- 根拠：[診断27](https://github.com/n624-dev/takupoke-ios/actions/runs/38073321707/job/114275050342)。

## U21 通知許可のOS応答停止が再発（iOS27、全体357）

- 対象：`testChangedDataProducesOneLocalNotification`、実通知許可要求。
- 観測：操作前の撮影を除いたc490e2dで、実Switch一回・requesting=true・SDK要求を
  確認したが、45秒内に許可画面・Allow・callbackがない。106.390秒で失敗した。
  期限後のアプリ画像とSystem画像は同一SHAで、許可画面がない。
- 状態：U18と同じ停止段階がMainActor bridgeでも再発した。actor変更だけで一般的に
  解消したとは扱わない。Simulatorの通知サービス側と要求経路を追加観測する。
- 確認範囲：他の事前11ジョブは成功。26 Aは15件成功、27 Bの通知設定も成功した。
  公開ジョブはskipで357は未公開。PDF修正・実資料の成否とは別に扱う。
- 根拠：[357通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38068857906/job/114262118118)。

- 比較結果：ビルド／初回起動を分離した1305b27の通知2ケースは両OSで成功した。
  最終d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)
  も通常4ジョブ・全13検査を通過し、実許可・保存・再起動・実配信を確認した。
  一回の比較と公開ソースの検証結果であり、OS応答停止の一般的な原因は未確定。

## U20 操作前の診断撮影が期限切れ（iOS26、全体356）

- 対象：`testChangedDataProducesOneLocalNotification`、
  `ApplicationChecks+Notifications.swift`、`recoveryScreenshot`。
- 観測：OFFと保存false・notRequested・前景を確認した後、操作前の
  `app.screenshot()`が約54秒で「Timed out while requesting screenshot」となった。
  実Switch・OS許可要求には進んでいない。15件中1失敗、14件成功。
- 状態：XCTestの撮影停止の原因は未確定。同じ356の27 Aと26 Bの通知ケースは成功した。
- 次の比較：正常経路にある不要な診断撮影だけを外す。実コントロールの現在の枠・
  0/1から決める一回tap、実Allow、45秒、保存・実配信・再起動の検証は維持する。
  失敗時の撮影と原本確認などの画像検証は残す。条件緩和・押し直し・許可注入は行わない。
- 根拠：[356通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38064917285/job/114250712952)。

- 確認範囲：d402ed5の[全体368・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/38139451725)で、両OSの通常4ジョブが成功。
  実Switch・実Allow・保存・再起動・実配信の条件を維持して確認した。
  複数の起動準備・Runner分離を含む最終構成での確認であり、停止の下位原因は未確定。

## U18 実通知要求の後に許可画面・callbackがない（iOS27、全体354）

- 対象：`testChangedDataProducesOneLocalNotification`、ScheduleNotificationsの許可要求。
- 観測：一回の実Switchでrequesting=true、SDK要求の記録あり。45秒内にAllowも
  callbackもなく失敗（98.277秒）。期限後のアプリ画像とSystem画像は同一SHAで、
  アプリのAXにも許可画面はない。別の27 Bでは同じ許可・保存のケースが成功した。
- 状態：原因未確定。nonisolated asyncの要求開始とUIのactor境界を確認する。
  実許可・保存・配信の検査、45秒、一回のOS要求を維持する。
- 比較変更：要求開始をMainActor上に保つ。実bridgeのSDK呼出actor・返答の
  動作検査は成功した。
- 確認範囲：65767afの355通常27 Aで実Allow・callback・保存・配信まで成功
  （65.948秒）。一回の比較結果であり、一般的な原因解消や全体合格とは区別する。
  357では同じ停止段階が再発した（U21）。
- 根拠：[354通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38040538159/job/114179897970)。

## U19 行除外の実Switch操作後に値が変わらない（iOS27、全体354）

- 対象：`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`、3行目。
- 観測：行・子Switchは0、一意な実trackを確認して一回pressしたが、15秒内に1に
  変わらず失敗（98.496秒）。位置の記録からイベント合成まで約5秒を要した。
- 状態：原因未確定。観測した画面座標の保持と、現在の実コントロールに相対した
  一回のtapを比較する。選択・103行の保存・取消し・再起動の検証は維持する。
- 比較変更：観測した0/1に応じた実trackへ、コントロール相対の一回tapを使う。
  期限・操作数・保存の期待値は変えない。
- 確認範囲：同じ355の27 Aで103行の選択・取消し・保存・再起動まで成功
  （141.983秒）。他のOS・ケースと配布前全体は別に検証する。
- 根拠：[354通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38040538159/job/114179897970)。

## U17 入力直前の診断照会がAX停止（iOS27、全体353）

- 対象：単項目訂正の背景復帰後、Lifecycle.swiftのeditStage、Input.swift。
- 観測：実消去・空欄・確認解除・キーボードを確認した後、診断用のAny.existsが
  約200秒停止した。次のtypeTextより前の失敗。ケース679.908秒・失敗1。
- 次の比較：診断は既知の段階・IDだけを記録し、成功経路で追加のexists・
  debugDescriptionを照会しない。入力には現在の一意な要素配列を使う。
  実入力の全文・確認解除・背景の同一プロセス・保存の検査は維持する。
- 確認範囲：5d378cdの354では単項目27のケース全体が576.487秒・失敗0だった。
  他のケースや355の配布前合格には代用しない。
- 根拠：[353単項目27](https://github.com/n624-dev/takupoke-ios/actions/runs/38036952573/job/114169411384)。

## U15 実通知要求後に許可画面が現れない（iOS27、全体352）

- 対象：`testNotificationControlsAndAppearance`、requestAuthorization、SpringBoard。
- 観測：実Switch一回でrequesting=true、実SDK要求記録あり。45秒内にcallbackも
  Allowも現れず、SpringBoard照会はkAXErrorServerNotFound。期限後の画面画像にも
  許可画面はない。許可タップには進んでいない。単なるタップ失敗とは扱わない。
- 状態：原因未確定。同じ352の26 Bと27 Aは許可・保存まで成功した。
  353はこのログ取得前に開始済みで、原因解消の新比較とは数えない。
- 根拠：[352通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252633)。

## U16 一回の起動でプロセスIDを取得できない（iOS27、全体352）

- 対象：`testSettingsAccountDataAndFileDetails`、ApplicationChecks.swift、app.launch。
- 観測：前プロセス終了を確認した後、一回のlaunch中に約200秒を経て
  「does not have a process ID」で停止。次の別ケースは起動して成功した。
- 状態：原因未確定。押し直し・再起動による救済や成功扱いは行わない。
- 根拠：[352通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252633)。

## U14 原本再照合後のメニューが操作不可（iOS27、全体352）

- 対象：`testChangedOriginalCannotSubmitOrReplaceLastGood`、
  `ManualAssistanceChecks+Navigation.swift`、架空原本のハッシュを変更。
- 観測：消去・全文入力・完了を2回通過。2回目のメニューは一意に存在し、
  画面内の250×42の領域を持つが、操作可能性の即時検査で失敗した。
  enabledとhittableの個別値は未記録で、アニメーション原因とは断定しない。
- 次の比較：既存45秒以内で現在の一意なボタンの包含・enabled・hittableを
  観測し、成立した場合だけ一回タップする。不成立なら最後の観測値を残す。
- 確認範囲：修正4292872の353ではケース全体が255.717秒・失敗0で完了した。
  新しい配布ソース5d378cdの354は別に検証する。
- 根拠：[352失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252608)。

## U13 通常画面15件成功後にジョブ予算で中断（iOS26、全体352）

- 対象：Application iOS 26 UI A、ios-release.yml、timeout-minutes、清掃。
- 観測：15件すべて成功したが、準備・ビルドを含む45分のジョブ予算で
  清掃中に自動中断した。外側の完了照合には到達せず、公開合格へ数えない。
- 次の比較：通常UIジョブの準備・検査・清掃の総予算を60分にする。
  各操作の45秒、全ケース、完了件数照合、cancelledの公開拒否は維持する。
- 確認範囲：353の通常4ジョブは完了まで成功した。26 Aのジョブ時間は
  32分41秒で旧45分内でもあり、予算変更だけの効果とは断定しない。
- 355の26 Aは全15件成功・ジョブ46分09秒で完了した。本体の完了も開始から
  45分35秒後で、旧ジョブ予算を超えた。個々の操作の期限は維持している。
- 根拠：[352中断ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252535)。

## U01 消去ボタンのAX取得停止（iOS27、全体348）

- 対象：`testChangedOriginalCannotSubmitOrReplaceLastGood`、
  `ManualAssistanceChecks+Input.swift`、`manual-clear-*`、AX snapshot timeout。
- 観測：`clear.waitForExistence`で停止。消去の物理タップ前に失敗した。
- 試行：e285172でボタン全体を有界スクロールで表示してから入力要素を取得。
  349では消去・確認解除・入力まで通過したが、ケース全体はU02で失敗した。
- 根拠：[348失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38021457932/job/114123316256)、
  [詳細](verification.md#2026-10-10-strict解析の退行調査と曜日行の一括除外検証中)。

## U02 入力後の完了ボタンが操作不可（iOS27、全体349）

- 対象：同じ原本変更ケース、`ManualAssistanceChecks+Input.swift`、
  `manual-edit-done`、keyboard toolbar、`isHittable`。
- 観測：入力値・確認解除は正しく、完了ボタンは存在したがhittable=false。
  完了タップ前に失敗した。単に表示待ちが短かったとは断定できない。
  同じ349の3項目訂正27は成功しており、iOS27で毎回失敗するとは扱わない。
- 試行：693cf079で製品の完了をsheetのnavigation barへ移した。
  実ボタンの包含・enabled・hittableと一回のタップを要求する。
  350の原本変更27は成功。全体はU08・U09で失敗し、一般的な原因解消とは扱わない。
- 根拠：[349失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38023085810/job/114128234002)、
  [350の検証](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042)。

## U03 画面寸法警告（iOS27、手動訂正、未解決）

- 検索語：`PDFRecoveryView.swift`、`Invalid frame dimension`、scroll、画像プレビュー。
- 観測：失敗した348・349だけでなく、成功した347の全3ケースや348の3項目訂正にも出る。
- 状態：原因は未確定。U01・U02の原因とも、修正済みとも扱わない。
- 根拠：[347全体](https://github.com/n624-dev/takupoke-ios/actions/runs/37984539555)、
  [詳細](verification.md)、[改善記録](ocr-improvement-log.md)。

## U04 Switch操作後もUI・保存値が変わらない

- 検索語：`ApplicationChecks`、AI・OCR、通知、Switch、Binding、再起動、OFF。
- 観測：行・子コントロール・操作点の違いで不発があり、原因確定前の変更も失敗した。
- 対応：実Switchの一意性、観測した0/1、包含・操作可能性から一回だけ操作する。
  UI・保存値・ON/OFF両方の再起動保持まで検証する。押し直しは行わない。
- 確認範囲：22c8ee2の両OS focusedと全13検査は成功。全OS・全版への保証ではない。
- 根拠：[全体37811661856](https://github.com/n624-dev/takupoke-ios/actions/runs/37811661856)、
  [詳細](ocr-improvement-log.md#修正版の結果と短時間の処理中状態を取り逃したqa)。

## U05 画面外・不在要素のAX照会が停止する

- 検索語：List、keyboard、`firstMatch.exists`、viewport、snapshot、行除外。
- 観測：不在keyboardの探索停止と、画面外の除外Switchの存在待ちは別の失敗だった。
- 対応：実在keyboard配列の一回観測、有界な実スクロール、一意なListへの検索を使う。
  不在・画面外・存在・操作可能を区別し、全包含と探索上限を維持する。
- 根拠：[keyboard失敗37789317942](https://github.com/n624-dev/takupoke-ios/actions/runs/37789317942)、
  [行除外失敗37884065885](https://github.com/n624-dev/takupoke-ios/actions/runs/37884065885)、
  [詳細](ocr-improvement-log.md#キーボードが開いていない段階のax探索停止)。

## U06 通知設定のOS応答が期限内に返らない

- 検索語：iOS27、`notificationSettings`、authorization=pending、active、45秒。
- 観測：Switch操作前の設定取得待ちで失敗した例がある。U04の操作不発とは分ける。
- 対応：不要なOFF時のOS照会を除き、実callbackとMainActorの観測を別に記録する。
  許可・設定値の注入や待機期限の緩和はしない。間欠性の原因は未確定。
- 根拠：[342](https://github.com/n624-dev/takupoke-ios/actions/runs/37905575598)、
  [詳細](verification.md)。

## U07 テスト未実行なのにActionsがsuccess

- 検索語：Mac Bash、空配列、`unbound variable`、cleanup trap、XCTest完了件数。
- 観測：37724583586では起動前に終了し、XCTest完了0なのにジョブがsuccessだった。
- 対応：清掃前の終了値を保持し、選択したケースの完了・件数・重複・skipを独立照合する。
  Actions表示だけではUI成功と認めない。
- 根拠：[実行37724583586](https://github.com/n624-dev/takupoke-ios/actions/runs/37724583586)、
  [詳細](ocr-improvement-log.md#配布前の実行件数確認mac-bashの空配列で未実行成功を拒否)。

## U08 実Switch操作後の通知許可待ち（iOS27、全体350）

- 対象：`testChangedDataProducesOneLocalNotification`、`ApplicationChecks+Notifications.swift`、
  `requestAuthorization`、requesting=true、notification-transition-unresolved。
- 観測：一回の操作後にrequesting=trueになり、45秒内に許可画面・ONへ進まなかった。
  失敗時のSystem画像にもダイアログがない。U04の操作不発、U06の事前照会とは別に扱う。
- 状態：OS要求とcallbackのどこで止まったかは未確定。押し直し・許可注入で救済しない。
- 次の比較：実requestAuthorizationを一回のcallback経路で受け、実返答以外でONにしない。
  QAだけに要求開始・callback到達の固定ラベルを記録する。実OSでの効果は未確認。
- 根拠：[350失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042/job/114135377793)。

## U11 消去済み入力の古いAX照会が期限切れ（iOS27、全体351）

- 対象：原本変更ケース、ManualAssistanceChecks+Input、clear、空入力のvalue照会。
- 観測：一回の実clearで入力9bytesから0bytes・確認falseになったが、
  変更前に取得した入力要素の照会が停止し、空値の期待が期限切れになった。
- 次の比較：型の変化を固定せず、現在のIDに一致する実要素を一回ずつ取得する。
  空値・確認解除・全文置換・実入力の条件と45秒は維持する。
- 根拠：[351失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38030340274/job/114149898742)。

## U12 通知許可操作の中継が共通期限を消費（iOS27、全体351）

- 対象：通知配信ケース、ApplicationChecks+Notifications、Allow、共通45秒。
- 観測：実許可画面の観測後、QAボタン経由のinterrupt処理に進んだ。
  実Allow・UIのON・保存trueまで到達したが、次の待機の残り時間が0になって失敗した。
- 次の比較：現在の一意な実許可ボタンを一回操作し、許可待ちからON・保存まで
  一つの45秒の検証で確認する。期限切れを成功にせず、押し直し・許可注入はしない。
- 根拠：[351失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38030340274/job/114149898669)。

## U10 初期設定footerの受動照会で操作点エラー（iOS27、全体350）

- 対象：`testSetupCanBeSkippedAndOffersAllFiles`、`ApplicationChecks+Navigation.swift`、
  unobscuredViewport、次へ、`Activation point invalid`、hittability。
- 観測：試験時間割の見出しを表示するviewport計算中、footerのisHittable照会が失敗した。
  この箇所では次へを押していない。見出しの存在・不在だけの失敗とも分ける。
- 次の比較：受動的な遮蔽範囲は実footerの一意な有限の表示枠から計算する。
  実Buttonを押す際の有効・操作可能・包含と一回操作の条件は維持する。
- 根拠：[350 B失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042/job/114135377831)。

## U09 行事注意文のAX照会停止（iOS27、全体350）

- 対象：`testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates`、`ApplicationChecks+Events.swift`、
  boundaryWeek、`firstMatch.exists`、snapshot timeout。
- 観測：時間割への遷移と週表示を確認した後、注意文の存在照会で停止した。
  文字の存在／不在の結果は未取得である。
- 状態：U05の不在要素探索と比較する。存在・不在・個数の期待値を緩めない。
- 次の比較：実在配列を一回観測し、従来と同じ存在／不在を要求する。
  不在授業も同じ観測へ変更する。実UIでの効果は未確認。
- 根拠：[350失敗ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042/job/114135377793)。
