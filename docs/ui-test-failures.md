# UIテストの失敗索引

UIの変更・実行前に、ケース名・ファイル名・操作・エラー・OSで検索する。
各項目は観測、試した変更、確認範囲だけを短く記す。詳細はリンク先を読む。
新しい失敗は次の試行前に追記する。未確認の原因を確定扱いしない。

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
