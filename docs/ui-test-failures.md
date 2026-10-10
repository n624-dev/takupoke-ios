# UIテストの失敗索引

UIの変更・実行前に、ケース名・ファイル名・操作・エラー・OSで検索する。
各項目は観測、試した変更、確認範囲だけを短く記す。詳細はリンク先を読む。
新しい失敗は次の試行前に追記する。未確認の原因を確定扱いしない。

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
