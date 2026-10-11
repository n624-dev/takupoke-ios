# UI失敗の横断確認（2026-10-11）

直近で繰り返す通知停止は、実SwitchからOS要求へ進んだ後、初回の許可画面と
callbackを受け取れない段階である。API変更や製品の保存失敗と断定できない。
同じXcode・Runnerで成功と失敗があり、26でも再発している。
Apple Developer Forumsには同じUserNotificationsの未返答とSimulator再起動での改善報告がある。
これは次の比較の根拠であり、Appleによる原因確認・修正保証ではない。

## 確認範囲

[失敗索引](ui-test-failures.md)のU01〜U33全33項目と、そこから参照する
[検証記録](verification.md)、[改善記録](ocr-improvement-log.md)、
[実行時間](ci-performance.md)を確認した。索引の作成前にある許可画面の未操作、
Switchの不発、AXの探索停止、runner bootstrap失敗も比較に含めた。
33は索引項目数であり、失敗ケース数や実行回数ではない。警告・複数ケースの要約を含む。
すべての過去Actionsログを今回再取得したという意味でもない。

原ログの再照合は355の27 A／B、357の27 A、360の27 A／B、
診断38の26／27に実施した。原資料・学校本文は取得せず、架空UIのログだけを使った。

## 全索引を停止段階で比較

| 段階 | 索引 | 共通する観測と限界 |
|---|---|---|
| 要素・表示枠・起動・画像の取得 | U01、U02、U05、U09、U10、U11、U14、U16、U17、U20、U23 | 操作前のAX照会や撮影、起動で停止。存在・可視・操作可能を同一視できない。通知APIの未応答とは分ける |
| 操作からBinding／選択への配送 | U04、U19、U30 | 一回の物理操作後に値が変わらない。SDK tap完了は製品setterに届いた証明ではない |
| 許可要求前のOS設定取得 | U06 | 設定のcallbackが返らない。通知がOFFの不要な照会を除いたが、OS停止の一般的解消ではない |
| 実要求後の許可提示・返答 | U08、U15、U18、U21、U22、U24、U25、U26、U27、U28、U29、U31、U32 | requesting=true、実要求あり、45秒内にAllow・callback・保存ONなし。後期の観測では同期SDK戻りとOSサービス受信も確認 |
| 表示済み許可画面のテスト操作 | U12 | Allow・callback・保存には到達したが、中継操作が共通期限を消費。画面自体がない失敗とは異なる |
| runner・予算・完了判定 | U07、U13、U33 | 未実行成功、清掃中の予算切れ、起動アプリの不存在。アプリの仕様不合格へ混ぜない |
| 成功時にもある警告 | U03 | Invalid frame dimensionは成功ケースにもある。失敗原因や解消済みと扱わない |

索引以前の37760047573は、画像に許可画面が存在するがテストがAllowを操作しない例だった。
現在のU31／U32とは違う。37974710845はrunnerのbootstrapで終了し、ケース開始0件だった。
外側Switchのtap比較37978618022は両OSでBindingへ届かず、OS許可要求の比較にならなかった。
これらの失敗を、通知の同じ障害の再現回数へ合算しない。

## UI以外の今回の失敗

[Strictの色互換性の検証記録](verification.md#2026-10-10-可視色の互換性修正)には、
62decb4のApple SDKのoptional／型推論、テスト対象の型、226cb5eのテスト配置・構文による
コンパイル失敗がある。これらは実装・テストコードの不備で、Simulatorの間欠性とは分ける。
3f7d7df／a864f11では色の変換と実際のPDF描画が異なり、白文字の拒否や極薄CMYKの
期待が失敗した。正式採用に関係する実際の不具合であり、UIの不安定さを理由に無視しない。
最終3e58684では色定義だけのPDF描画へ変更し、同じ負例・命令上限・取消しを維持して
両SDKのNative検査が成功した。実際の学校PDF3種類の復旧は、引き続き未評価である。

## 成功と失敗の原ログ照合

次の5ジョブはすべてRunner `xcode-27-arm64`、イメージ `20261006.0244.1`、
Xcode build `27A266a`、Simulator SDK build `24A430`だった。
SDK buildは実行時OSのbuildと同じではない。Runtime識別子はiOS-27-0で、
実行時OSの詳細buildは今回の照合では未評価である。

秒数はXCTestケース全体の時間で、許可API単体の応答時間ではない。

| 実行・ジョブ | 対象 | 実測結果 |
|---|---|---|
| [355 27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38043348896/job/114187984624) | 初回許可・配信 | 65.948秒、実Allow・callback・保存・新規配信成功 |
| [355 27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38043348896/job/114187984668) | 許可・通知設定 | 135.362秒、実Allow・callback・保存・再起動成功 |
| [357 27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38068857906/job/114262118118) | 初回許可・配信 | 106.390秒、実要求後に画面・callbackなし |
| [360 27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38107075743/job/114374844543) | 初回許可・配信 | 51.544秒、実Allow・callback・保存・新規配信成功 |
| [360 27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38107075743/job/114374844570) | 許可・通知設定 | 110.618秒、同期SDK戻りあり、Allow・callbackなし |

355の65767afから249037bまで、製品ScheduleNotifications、NotificationSettingsView、
TakupokeApp、Info.plistはgit diffで差分0だった。3e58684から現在までの製品全体も差分0。
通知UIの共通関数の差分は、正常経路の診断撮影を除いたことだけで、実Allowと45秒は同じ。
したがって「新しいRunner版を踏んだ」「PDF修正が通知コードを書き換えた」だけでは説明できない。
同じバージョンのOS内部の間欠性や、生成fixture・XCTestの影響は否定していない。

初回ケースが失敗し次のプロセスで許可が成功するU22・U27・診断38は、初期化状態への
依存と整合する。ただしU28・U31・U32は両ケース失敗、359の26 Aにも再発があり、
単純な「最初の一回だけ」「27だけ」「アプリを再起動すれば必ず直る」とは言えない。
接続invalidated・errorは成功した26にもあり、それだけで原因としない。

## Webの一致と相違

- [Appleの通知許可API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:))はcallback版とasync版を掲載する。
  [許可要求の説明](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)は初回提示と以降の無提示を区別する。27専用の別要求経路は記載されていない。
- [Apple Forums 849449](https://developer.apple.com/forums/thread/849449)の本文はAlarmKitの拒否応答で、今回と異なる。
  返信はUserNotificationsで画面が出ずcompletionが呼ばれず、Simulator再起動で改善したとの当事者報告。
  今回の段階と一致するが、投稿には厳密な再現条件・build・Appleの原因確認がない。
- [Cabalmailの当事者記録872](https://github.com/cabalmail/cabal-infra/issues/872)には、27 betaでシステム許可画面をAXから取得できない報告がある。
  通知はvisionOSの表示済み画面、iOSはContactsであり、今回のUserNotifications未提示と同一視しない。
- [Device Hubの当事者報告](https://developer.apple.com/forums/thread/844792)はiOS17の入力停止。
  [argent 406](https://github.com/software-mansion/argent/issues/406)は旧Simulator.appの不存在で、U33に一致する。
  どちらも現在の通知要求の下位原因を証明しない。
- [Runner-images 12747](https://github.com/actions/runner-images/issues/12747)はAPNS device token取得失敗。
  ローカル通知の許可callbackとは異なり、Push entitlementを今回の修正として追加しない。
- [SagerNetの実装](https://github.com/SagerNet/sing-box-for-apple/blob/dev/SFI/ApplicationDelegate.swift)の
  OS通知サービスの説明はJAILBREAK限定かつ配信の話で、通常のSimulator初回許可へ転用しない。

Apple公式release notes、Forums、GitHubの当事者報告、runner-imagesを横断して検索した。
検索語はrequestAuthorization／getNotificationSettings／completion not called／hang／
iOS27／Xcode27／SpringBoard／kAXErrorServerNotFound／permission prompt。
無関係なdidReceive delegate・APNS・AlarmKit・ATTの問題を混ぜず、推測だけで製品を変更しない。

## 診断38の結果と次の比較

249037bの[38](https://github.com/n624-dev/takupoke-ios/actions/runs/38112276765)は完了した。
26は2件成功（64.194／168.135秒、計232.329秒）。27は初回110.116秒で失敗し、
次の通知設定222.650秒は実Allow・callback・保存・再起動まで成功（計332.767秒、1失敗）。
Device Hubの起動エラーは解消したが、画面を開くだけでは通知の一般的解消にはならない。
未返答要求の観測は同期戻りあり・callbackなし、OSログ401,299 bytes・取得終了0。
成功した次プロセスで初回Allowが出ており、最初の失敗を許可済み経路の失敗へ読み替えない。
利用者の実機355.1は許可済みONが成功し、実機の初回許可は未評価である。

次は上記の再起動報告を根拠に、初回テストを始める前の所有Simulatorの準備だけを比較する。
対象アプリを実installしてから所有deviceを一度再起動し、bootstatus完了後にXCTestを開始する案。
許可や保存値は注入せず、失敗したケースの押し直し・再実行、期限延長はしない。
製品と配布SDKは変えず、両OSの関連ケースと配布前の同一ソース全13チェックを維持する。
この起動準備の効果は未評価。従来の失敗結果は保持し、成功率は算出しない。
