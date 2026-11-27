## PR #238のiOS 27通常Aで配信データだけのテストに先行ケースの行事が残る（2026-11-27）

- `d963487`、[全体46003572284 試行1のiOS 27.0通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/46003572284/job/140523988502)、SDK 27.2。24件中23成功。`testStatusScreenUsesPublicResourcesAndDataRoutes` はステータスの実NavigationBarまで進み、13:58:53 UTCに `ApplicationChecks+Settings.swift:433` で集計の「更新確認済み」が10秒以内に成立せず失敗（29.025秒）。リンク・監視先への後続操作は未到達。ログ中の失敗用画像はホームで、この失敗時の集計画面を示していないため表示原因の根拠に含めない。
- 先行ケースでは現在年度の架空行事を `SchoolEventsAPI` に保存する。配信データだけのfixtureは行事の新規保存を省くが、リセット処理は製品の半期処理を通るため既存の公開行事を保持する。先行ケースの未確認行事が集計に加わり得る。先行ケースのストアを用いる対照でこの条件を確認し、配信データだけのfixtureを起動時に初期化する。製品の行事保持、集計判定、表示文言、XCTestの10秒を維持する。
- 同じジョブで合格した保存期間復旧テストの SwiftUI 警告が `record(_:)` に入り、失敗用の撮影を消費していた。以降の実失敗を撮影するため、Apple XCTestの `isFailure` を見て失敗の時だけ撮影し、記録自体は警告・失敗ともそのままXCTestへ渡す。 [Apple XCTest](https://developer.apple.com/documentation/xctest/xctissue-swift.struct/isfailure)
- 局所の初回Python対照は、`seed` 本体にある架空の破損JSONの `{` をSwiftの構文と区別しない抽出補助を使い、`IndexError` で停止した。`seed` の中は呼び出し順だけを照合し、実行するリセット関数だけを抽出する。
- 撮影条件の局所対照も、MainActorを持つ検査をSwiftのトップレベルから呼んで型検査で停止。実コードのMainActor隔離を守るため、対照の `@MainActor static func main()` から同じ経路を実行する。
- 実行前レビューで、新しい固定の起動記録が別のロガーの許可一覧にないため破棄されることを確認した。既存CIの実行中トレースへ直接記録し、その呼び出しを生成前の検査で照合する。

## #183・#193が解析と保存の同じエラー型を取得の一時障害と判定（2026-11-27）

- 13:58 UTC、`d963487` 基点のSwift 6.1.2／Linux。実パイプラインに、解析・検証・保存から `URLError.networkConnectionLost` と `MaterialError.providerReadFailed` を返した。自動確認と手動再取得の12組で、初回だけで終えるべき処理が再試行2回へ進んだ。原因は取得の期限切れだけが発生段階を見ており、残りの一時障害をエラー型だけで判定したこと。
- 発生段階を先に確認し、Providerの応答待ちと取得の間だけ一時障害として扱う。再試行2回、3秒待機、処理全体の期限、同期I/Oの終了待ちは元の条件で検証する。
- 修正後の38件はすべて成功。問題の12組はいずれも初回で終わり、取得段階で失敗した場合の計3回実行、旧処理の終端待ち、期限後の保存防止も通過した。

## #200・#202・#203の架空XLSXを表として読む箇所と解析する箇所を混同（2026-11-27）

- 13:48 UTC、`d963487` 基点の検証差分。Swift 6.1.2／Linuxで、`read(_:defaultYear:)` の戻り値 `[[String]]` を解析済みレコードとして扱い、`ChangeAnalysis` に存在しない `Equatable` を要求した。Swiftのビルドで失敗し、XCTestは未実行。
- 既存のWorkbookテストと同じ `ChangeNormalizer.parse` に表を渡して解析し、保存前後は既存データベースの正規エンコードを比較する。

## #189の限定CIで解析版を変更した差分が既存の5検査に失敗（2026-11-27）

- `c72b59e`、[46008534357のLinux Swift](https://github.com/n624-dev/takupoke-ios/actions/runs/46008534357/job/140537772716)、751件中746成功・5失敗。失敗は `RecoveryTests.swift` の5件すべてで、試験・返却解析版の期待39に対し作業枝が40を返した。追加した検査は通過。以前のローカル選択検査はこれら5件を含めていなかった。Appleジョブは別途追跡する。
- 新規に解析したファイルの実時刻検証を先行し、既存の解析や手動採用を自動的に更新するための解析版の変更を取り下げる。旧保存の更新規則は利用者の回答後に扱う。関連版の定数参照を検索し、選択検査に加えて確定コミットで全Swiftを実行する。
- 解析版39を維持した `bbd83b9` をSwift 6.1.2／Linux、SQLite 3.53.4で検証し、全751件が成功した。

## #122の局所対照でLinuxの既知のObservationリンク不良が再発（2026-11-27）

- 13:37 UTC、作業差分、Swift 6.1.2／Linux。週送りの個別観測の対照が `libswiftObservation.so` の `swift::threading::fatal` でリンク失敗。Apple向けのビルド・実画面には未到達。同日の検査追加時に動的リンクを指定し、以前の同じ組合せで不足するシンボルを扱っていなかった。
- `swiftObservation|threading::fatal` で#122の`1824b8b`に対する記録を照合。観測の対照は実行時のタイムゾーンへ依存しない架空日付を使い、Linuxだけ付属の静的標準ライブラリで確認する。本体の設定やAppleのランナーには適用しない。
- Linuxで対照が成功した後に全45件を実行し、失敗0。更新を重ねる旧 `advanceFrame` へ戻す対照は、Swiftの実行時に失敗した。

## PR #238のiOS 26通常Bで週の横移動直後に描画が止まる（2026-11-27）

- `d963487`、[全体46003572284 試行1のiOS 26.5通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/46003572284/job/140523988440)、SDK 27.2。ビルドと起動成功。13:29:02 UTC、先頭の `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` が `ApplicationChecks+WeekAppearance.swift:466` で停止。ケース46.926秒。復路の横到着0.215996秒から最初の着地実枠0.315344秒まで99.348ms、合格条件90ms。往路同区間83.037ms。両方向で実枠欠落、着地後の週本文再生成、計測用のグリッド診断取得、幾何の書き戻しはいずれも0。XCTestの失敗時に128091バイトの画像1枚を取得。Bの後続検査は未到達。
- `Height adjustment must keep drawing frames|horizontal-arrival|N185-CI9` でN183-CI22、N185-CI9、正式82860ce試行1を照合。復路の最後の横移動サンプルから着地実枠までメインスレッドCPUは82.775ms増加。同期の昇格・スクロール復帰は約1ms、配置設定自体は約0.28ms。CI上の単純な待機とは区別できるが、現時点の計測ではSwiftUIのどの処理へCPU時間を使ったかは未確定。同じ90ms、実接触、両方向の実枠、後続検査を維持して調べる。

## #189 PDFKitでだけコンパイルされるテストにOptionalの参照漏れを発見（2026-11-27）

- `2d155ad` のApple実行前レビュー。`#if canImport(PDFKit)` 内で、版によって存在しない可能性がある `consecutiveTimes` を直接添字参照していた。Linuxのテスト対象からはこの型エラーが見えなかった。Appleの実行は開始前。
- 版の検証に使う共通のアサーションを条件付きコンパイルの外へ移し、原本PDFKit読取は条件付きのままにする。時刻印字のある版とない版で同じアサーションを通し、個別セル・保存版・進行中判定の確認を維持する。

## #206 個別テストをファイル名で絞り込み、実行件数が0になった（2026-11-27）

- 13:17 UTC、Swift 6.1.2／Linux、`d963487` を基点とした任意OCR訂正解除の作業差分。テストの変更先ファイル `RecoveryManualAssistanceTests.swift` の名前で絞り込んだが、実際は `PDFParsingTests` のextensionのため一致0件だった。対象メソッド名で実行し、件数を確認する。成功件数には含めない。
- 13:21 UTC、対象メソッド名で再実行し、XCTestログに解除・高信頼項目の選択・4項目目の拒否の3件が出て、すべて成功した。

## #204 実行前レビューで読み取っていない細い列を空欄にできる条件を発見（2026-11-27）

- `a38ec55` の実行前レビューで、位置の証拠が縦方向だけだったため、同じ行に時限見出しの中心が通らない細い列があると、未読領域を含む行にも比較用の空欄を記録できることを確認した。既存の架空データ249件は通過していたが、時限の中心を通らない縦罫線を置く負例がなかった。
- 既存のStrict解析は維持し、比較用の証拠を保存する場合だけ、読んだ矩形が実罫線内の表の行を縦横とも覆うことを求める。細い未読列を追加しても元の授業解析が成立し、空欄比較だけができなくなる回帰を追加する。
- 同じレビューで、Strictとの比較用の時限単位正規化をCertified同士にも適用し、同じ本文で結合範囲だけ変わった場合の差分が消える条件を確認した。時限単位への正規化は以前の結果がStrictの時に限り、Certified同士の物理的な範囲比較を維持する。

## 最新PR #238の手動訂正CIで二段目の架空アプリのビルドが停止（2026-11-27）

- `05c4178253fa7d9ca7dbbecf389649e175af3ffd`、[45999245469 試行1のジョブ140508637695](https://github.com/n624-dev/takupoke-ios/actions/runs/45999245469/job/140508637695)。iOS 27.0／SDK 27.2、12:44:02 UTCにfailure。ビルド91.7秒。XCTest開始前に、生成された `PDFRecoveryCoordinator.swift` の91行と100行で `failure` が読取専用のため停止した。所有端末は未起動で失敗画像は取得できなかった。
- 先に直した `tools/manual_ui_project.py` の変換に加え、実ジョブはその前に `tools/app_test_project.py` の `--recovery-preview` も挿入する。後者が旧 `failure` へ代入していた。ローカル検査は各変換を別々に読んだため、連結後の最終ソースへの影響を見逃した。両方の変換で架空エラー用の同じ書込先を使い、製品側の公開プロパティは読み取り専用を維持する。
- 通常用と手動用それぞれの生成済みソースを検査し、手動用は実ランナーと同じ順序で両変換を適用する。架空エラーを設定する実コードと中止時の解除を型検査し、テストが旧プロパティに代入していた場合は失敗させる。
- 同じ試行の[iOS 27 Aジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/45999245469/job/140508637727)・[Bジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/45999245469/job/140508637711)は12:47:43 UTC、[元PDF変更の手動訂正ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/45999245469/job/140508637746)は12:49:36 UTCに同じ生成後の代入エラーで終端した。差分のコンパイル前に停止した別のUI回帰とは数えない。共有書込先の修正後、ローカルで生成器を含む20件とマニフェスト44件が成功した。
- 同じ試行は13:16:34 UTCに最後のiPhoneビルド確認が成功し、必須15件は成功3・失敗12。失敗したジョブは取り消さず終端まで確認した。共有書込先と追加対策は `d963487` の [46003572284 試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/46003572284/attempts/1) で検証する。配布前チェックとNative PDF・復旧は同じ修正版で成功した。

## PR #238のiPhoneビルド確認内でファイル選択の復帰照会が停止（2026-11-27）

- `ed130525868688ac3a88462dbd18f91e7df82a69`、[45982834993 試行1のジョブ140453704458](https://github.com/n624-dev/takupoke-ios/actions/runs/45982834993/job/140453704458)。iOS 27.0／SDK 27.2。`testReselectionThroughActualButtons` が433.106秒で失敗し、ファイル選択の3ケースは成功2・失敗1。12:32:32 UTCにfailure、XCTestの失敗画像あり。
- 最初の8回の選択・取消と詳細画面から戻った後の再選択・取消が成立。その後にホーム、設定へ一度ずつ触れ、設定の「ファイル選択」画面へ戻った。NavigationBarとTabBarの存在照会は返ったが、 リストの `waitForExistence(timeout: 10)` に付随する内部照会が反復し、`MaterialPickerTapChecks.swift:107` のXCTest snapshot timeoutで停止した。失敗画像にはファイル選択Listと設定タブがあり、次のボタン操作・背景復帰は未到達。実List照会の下位の停止理由は未確定。
- N83/N203と照合。N83は選択ボタンのhittable、N203は背景復帰後の画面外ボタンの列挙、今回はタブ復帰後のList存在照会。今の画面のNavigationBar・TabBar・Listの型と識別子と枠を同じsnapshotから採り、その試行の枠は画面が動くまで再利用する。30秒、30秒、10秒、8回と最後の5秒、実選択・実取消・背景復帰を保持する。

## #233 Linuxの架空認証テストで中止済みの通信が開始された（2026-11-27）

- 基点 `8d131dd` の作業差分、Swift 6.1.2 / Linux、ローカルの `test_browser_cancellation_authentication_and_transport_are_distinct`。SDK・Simulator・Actionsは未使用。中止済みのTaskをURLSessionへ渡したケースで、FoundationNetworkingの `TaskRegistry` が `didFailWithError` 中にSIGILLで停止した。先行試行は同じケースを通過しており、常時再現ではなかった。
- `OIDC|認証ブラウザ` でN45/N46を照合した。今回は架空通信の開始と中止の競合で、N45の本番403およびN46のブラウザーのキャッシュ条件とは発生段階が異なる。製品の認証通信を開始する前に中止を検査する。テストの中止・通信失敗・拒否を判定する条件は維持する。

## PR #238のiOS 27明示訂正ジョブが失敗（2026-11-27）

- ソース `ed130525868688ac3a88462dbd18f91e7df82a69`、[45982834993 試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45982834993/attempts/1) の [ジョブ140453704349](https://github.com/n624-dev/takupoke-ios/actions/runs/45982834993/job/140453704349)。設定はiOS 27.0／SDK 27.2。ケースは `testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`。11:01:28 UTCにfailure終端。ログ取得前の段階・原因は未確定。
- ここまでにDistributionとNative PDF・復旧が成功した。実行中の残りのジョブは維持し、失敗済みのジョブの新規ログと失敗索引を照合する。
- 完了ログでは3項目すべての入力・個別ACK・確認画面・プレビュー復帰まで成功。次の候補を探す `ManualAssistanceChecks+Navigation.swift:97` が2回目の探索で候補1〜9すべての `frame` を照会し、候補9のIdentity Bindingで失敗した。XCTestは同じAccessibility要素の型をlegacy側で `Other`、modern側で `StaticText` と報告。923.515秒・終了65、XCTest失敗画像あり。4項目目の拒否・採用・再起動は未到達。型の食い違いが起きた内部の原因は未確定。
- `Navigation.swift:97|Identity Binding|仮想` でN54の比較不能表示および正式43758697036の通常画面ボタン照会と、その時点のコードを照合。今回は非表示の候補にも個別にIdentity Bindingを行う配列展開が失敗した。リストの1回のsnapshotから型・識別子・画面内の枠を検査し、候補が画面内に来た時だけその1件を現在の実要素に結び付ける。同じ複数候補の探索を使う確認画面の値の照合にも適用し、画面内・一意・操作可能の条件、16回上限、実接触、拒否・保存・再起動の期待値を維持する。
- 変更後、LinuxのSwift UI構文検査、実ジオメトリ29件、候補を結び付ける順序を含むPython 3件が成功。限定CIで同一ケースの両OS・SDK 27.2を確認する。アプリ本体の訂正と採用の経路はこの修正の対象外。

## PR #238のiOS 26明示訂正ジョブが確認画面の待機で失敗（2026-11-27）

- 同じ `ed130525868688ac3a88462dbd18f91e7df82a69`、[45982834993 試行1のジョブ140453704352](https://github.com/n624-dev/takupoke-ios/actions/runs/45982834993/job/140453704352)。iOS 26／SDK 27.2、`testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`。11:57:24 UTCにfailure終端、ケース357.344秒、終了65、XCTest失敗画像あり。
- 最初の訂正を送信し、製品ログは `manual-submit-accepted` と `manual-review-ready` を記録した。失敗時の画面には入力した本文、確認画面の見出し、`review=true;preview=false` の診断が存在した。`ManualAssistanceChecks+Review.swift:45` では、スコープ付きの検索結果をさらに `StaticText` に結び付け直す `label` 取得がXCTest内部で再試行し、20秒の待機が期限切れになった。iOS 27での画面外の候補探索とは別の段階。両ケースとも後続の採用と再起動までは未到達。
- N173/N183のスコープ規則と、既存 `requireReview` の20秒境界を照合した。状態を読むだけの確認・プレビュー待機を共通化し、同じsnapshot上の `manual-observation` 直下の実状態を型・ID・一意性とともに読む。重複、別の画面の状態、型違い、遷移途中を架空境界で検査する。20秒上限、確認画面の本文・比較・採用不可の検査、採用を求めるプレビューの再照合完了条件、実接触と保存の検査を維持する。

- 後続の `aa0fdc92b9956e8ab38adbc2544224803f8adf70`、[限定45988507976 試行1のiOS 26ジョブ140470113897](https://github.com/n624-dev/takupoke-ios/actions/runs/45988507976/job/140470113897) は12:18:05 UTCにfailure終端。同じケース240.087秒、SDK 27.2、終了65。今回はXCTestが `Tap` と `Synthesize event` まで記録したが、製品の送信アクション・確認画面到達の記録はなく、失敗画面にも入力とチェック済み行、青色の送信ボタンが残っていた。前回は確認画面へ到達済みだったため、同じassertで停止していても到達段階が異なる。送信操作が届かなかった下位理由は未確定。
- 44633231836と44734888974で実枠取得後の操作・実配送を照合した。送信ボタンは専用ID・実ラベル・可視枠・有効・操作可能を確認した同じ観測から、画面座標上の中央へ時間指定の物理接触を一回送る。座標の固定、押し直し、期限延長は行わず、確認画面へ到達することを引き続き必須とする。

## #205 iOS 27の単項目訂正限定ジョブが失敗（2026-11-27）

- `1bdb577e2779620aa76cccb61b420ef22dd53e27`、[限定45983942933・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45983942933/attempts/1) の [iOS 27ジョブ140454629266](https://github.com/n624-dev/takupoke-ios/actions/runs/45983942933/job/140454629266)、要求iOS 27.0・SDK27.2。`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`。11:02:29 UTCにfailure終端。失敗段階・原因はログ照合前で未確定。iOS 26ジョブは継続する。
- 実行ログでは同一プロセスで編集・確認・プレビューの各背景復帰まで進んだ。採用ボタンを待つため今回追加した `visible` 呼出しがIDとラベルの両方を省略し、空IDの照会で16回を費やした（`Navigation.swift:261`、613.363秒、終了65、XCTest失敗画像あり）。採用と再起動は未到達。復帰後にプレビュー見出しと訂正1件の表示を確認してから探索に失敗した。
- `knownID|Navigation.swift:261` でN54・N85の実コードを照合。背景復帰後のプレビュー確認は既存20秒内に再照合の終了も待ち、採用時点の実ボタンは通常と同じラベル指定の有界探索で一意性・表示枠・有効・操作可能を検査する。実採用と再起動後の保存検証を維持する。再照合中の採用拒否と変更原本の拒否は独立したLinux回帰で確認する。
- 実行前レビューで、前景通知の直前も `running=false` になり得る点を確認した。背景時に専用の再照合待ち状態を設定し、原本再読取・処理ID・同じプレビューの照合が通った時だけ解除する。画面のボタンとコーディネーターの採用・追加訂正の両方がこの状態を検査する。回帰は前景通知前・再照合中・再照合完了後の状態を区別する。
- 同じ `1bdb577` の [旧iOS 26ジョブ140454629583](https://github.com/n624-dev/takupoke-ios/actions/runs/45983942933/job/140454629583) は11:26:41 UTCにfailure終端し、旧限定CIは成功0件・失敗2件。iOS 26の到達点・原因は新規ログ取得前で未確定。
- iOS 26も編集・確認・プレビューの同一プロセス復帰後に同じ空IDを16回探索して失敗した。700.122秒、XCTest失敗画像あり。導入したテスト側の探索ミスを両OSで確認した。共通修正 `7f2cf35` の [限定45989651382](https://github.com/n624-dev/takupoke-ios/actions/runs/45989651382) で採用と再起動まで照合する。

## #199 予約診断追加後に背景更新のLinuxテストがコンパイルできない（2026-11-27）

- 基点 `8d131dd` の作業差分、Swift 6.1.2／Linux。`test_background_refresh_waits_for_countdown_and_cancels_its_owned_plan` が11:13 UTCの実行で `BackgroundRefresh` を解決できず、既存の背景通知検査に入らなかった。予約成否の新規境界テストは成功。Actions・Simulatorは未使用。
- テストは `ApplicationData.refreshInBackground` を抽出し、OS境界の代替実装で実行する。実行日時を記録する境界の代替を追加し、拒否・二重呼出しでは記録せず、許可された処理だけ1回記録することも検査する。既存の通知の中止・待機判定は維持する。
- 修正後、同じLinuxの通知・背景更新検査13件は失敗0。実際のBGTaskSchedulerによる予約・実行はApple環境で別途確認する。

## #194 同一内容確認の作業領域が書込済みと判定される（2026-11-27）

- `8d131dd` の作業差分、Swift 6.1.2／SQLite 3.53.4／Linux。11:42:47 UTC `testUnchangedPipelineCommitsOnlyAcquisitionMetadataOnTheLiveDatabase` で作業領域の変更種別がnilとなり、保存済み解析の行を読み出す従来経路を通過した。直接の確認日時保存とロールバックは成功。68件中1ケースでアサーション2件が失敗。
- `PipelineSnapshot.open` は元の保存情報を作業領域へ写すため `persist` を呼ぶ。この初期化が解析の書込と同じフラグを立てていた。作業領域に元のsnapshotを確定した境界で変更追跡を始め、その後の解析・取得を区別する。フラグは通常保存や解析変更で初期化しない。
- 修正後の同じ68件は失敗0。作業領域を経由した場合も実SQLiteの文を確認し、変更のない解析や授業行を読み出さず、原本・前回解析・並び順・generation検査を保つことを確認した。
- 比較計測専用の一時テストは12:17 UTCの初回コンパイルで、既存レコードの `lastCheckedAt: Date?` を直接加算したため停止した。比較前の件数・時刻は未計測。既知の架空初期状態でも値を明示的に検証してから加算し、計測コードを製品差分から外す。
- 12:18の実行では二つの件数に同じ解析時刻を使い、`analysis` の原本・種別・版・条件・解析時刻の一意制約で停止した。計測用の解析時刻を件数ごとに分けてから保存する。製品の制約と正当な保存処理は維持する。

## #207 復旧失敗の型変更後に架空の背景処理検査がコンパイルできない（2026-11-27）

- 12:18 UTC、Swift 6.1.2／Linux、`fefecc2` の作業差分。`test_actual_background_methods_preserve_idle_draft_and_cancel_heavy_work` の架空コーディネーターが旧 `failure: String?` のままで、抽出した `invalidateManualIfSourceChanged` と `cancel` の `failureReason` を解決できなかった。同じ検証の残り5件は成功し、iOS Simulatorは未使用。
- 同じ本番メソッドを抽出する前景復帰検査と背景停止検査の両方を、新しい型付き状態に揃える。下流の原本保持、既存入力の扱い、中止、旧処理の保護を引き続き実メソッドで検査する。
- 実行前レビューでは、原本や対象が変わった際にコーディネーターが旧原本を解放すると、失敗専用の分岐に再開ボタンがなくなることを発見した。旧原本なしでも通常の開始経路で選択済み資料を取り直す操作を残す。処理上限や不適合の状態には同じ原本の再試行を出さない。
- 修正確認では、採用直前に対象が変わった場合も同じ状態になることを発見した。背景復帰前・操作中・採用直前のいずれで対象が変わっても「復旧を最初からやり直す」へ進める条件を回帰検査に含める。
- 同じ実行前確認で、手動訂正用の生成器が旧 `failure` への代入を埋め込むことを見つけた。製品の型付き状態と、生成時だけの架空資料の拒否表示を分け、元の架空四項目拒否の判定を維持する。新しい実行には未到達。

## #205 iOS 26の単項目訂正が架空ダイアログの表示で停止（2026-11-27）

- `7f2cf3532ee31a12d13bc20b928f0922381586f2` の[限定45989651382・iOS26ジョブ140473952748](https://github.com/n624-dev/takupoke-ios/actions/runs/45989651382/job/140473952748)は12:55:09 UTCに失敗。278.547秒。訂正の入力と確認チェックが成立し、実Toolbarの枠から中央へ0.1秒の接触を送ったが、45秒の間に架空ダイアログの選択肢は0件で、失敗画像にも編集画面が残った。背景復帰と再照合は未到達。iOS 27の同じ限定は12:56:19 UTCに成功。接触が届いたか、届いた後の表示が起きなかったかは旧ログで判別できない。
- 44622550899の類例を照合し、実Toolbar内で確定した同じ中央位置へXCTestのアプリ座標から一回接触する。アプリ側のボタン到達と、ダイアログ表示状態への変化の両方を架空テストのログに追加する。実操作、選択肢3点の検査、45秒の待機、以降の文字表示・入力保持・再照合・採用は維持する。

## #205 背景復帰後に再照合済みと判断する根拠が不足（2026-11-27）

- 全CIの実行前レビューで、`readyToAdopt` の条件は、背景へ移動する前に成立していた値でも満たせることを確認した。既存のSwift境界検査は中止・実ファイルの読み直し・採用の保護を通過しているが、iOS Simulatorでは復帰に伴って本当に検証したことまで判定できなかった。
- 架空の試験ビルドだけで、原本の検証・処理ID・既存プレビューの一致が成功した箇所を数える。背景へ移動する直前に観測した同じプロセスから、1回増加したことを同じ20秒の状態検査で要求する。採用のボタン操作・再起動後の保存検証はそのまま行う。
- 12:26 UTCのローカル生成器19件では、同じプレビューID検査が「追加訂正を始める」処理にもあるため、単独の挿入目印が重複して4件が生成時に停止した。復帰後に検証待ちを解除する連続した文を目印にし、追加訂正の照合で数が増えないことも検査する。
- 目印を限定した再試行では、生成器の架空条件が既存4箇所に復帰記録1箇所を加えた5箇所となり、旧件数の検査1件が失敗した。挿入された箇所を復帰経路内に限定する検査を併用し、5箇所で照合する。
- 架空開始時の旧 `failure` 代入を前提にした検査も、新設した架空拒否状態を `cancel` が解除してから開始することの検査に置き換える。
- 同時刻の統合候補Swift全体は、実行中に同じ作業ツリーの `RecoveryManualAssistanceTests.swift` を更新したためコンパイルを中断した。途中の行番号付きエラーは結果に算入しない。以後は確定したコミットを検証専用作業ツリーへ置き、修正は別の作業ツリーで続ける。

## #192・#193 統合候補の架空Provider境界4件がコンパイルできない（2026-11-27）

- `d515a75`、11:58 UTCにローカルPython全体366件を完了。Swift 6.1.2／Linuxで製品メソッドを抽出して動かす４件が、テスト側の型定義の不足で停止した。`test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration`、`test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success`、`test_batch_cancellation_is_separate_from_child_deadline`、`test_special_provider_refresh_keeps_cancellation_separate_from_failure`。新しい取得エラー型、処理対象、統一完了状態をテスト用の境界が提供できず、実検査には未到達。統合候補のSwift全体768件は成功した。
- 製品の抽出を維持し、架空の各境界に新しい型とメソッドを揃える。保存の前後・レビュー保持・中止・期限切れ・別資料の継続を検査する既存の期待値は維持する。
- 11:59 UTCの対象9件では、上記4件のうち3件が復旧。取得エラー型を実コードから抽出しても、一時障害を分類する下位関数が架空境界にないため残る1件はコンパイルで停止した。下位関数も本番コードから取り込み、取得エラーの扱いまで同じ実行経路を使う。
- 同じ対象9件を12:01 UTCに再実行し、すべて成功した。原本を保存するまで監視通知へ応答しないこと、中止時に保存しないこと、通常の完了・一時停止・繰り返し選択・レビュー保存を検査した。

## N56 最終回収の空snapshot guardが停止（2026-10-20）

- 正式419の全15CI・匿名公開物照合・最終文書push完了後、ローカル回収helperがios-416-second-jobs.jsonを0bytesと仮定しassertionで停止した。該当ファイルは削除せず保持。先に既知の所有transport probeとそのreceiptだけを削除し、pyc以降の回収・最終完了receipt作成には未到達。
- 対処前に記録。製品・テスト・公開物の失敗ではない。古い作業メモの0bytes記載と現ファイルのサイズ／種別、既存N52〜N55のsnapshot保持と今回のguardを照合してから回収対象を決める。古い期待値を根拠に非空ファイルを消さない。

- 照合結果：現snapshotは32bytes・messageだけを持つAPIエラーJSONで、空ファイルではなかった。非空の通信失敗証拠として保持し、0bytesという古いメモを訂正する。既知の所有pycだけを追加回収し、配布コード・CI・公開物は変更しない。

## N51〜N55の正式419.1での確認結果

- source1e3fe81ecad3890ba9086b88c0b0afb373ea5688／run39397264222・試行1の全15必須成功・全job終端・保存artifact0を確認し公開。Nativeの新4回帰、両OS通常UI・訂正8件、実Picker・iPhoneビルドも成功。匿名4添付／IPA内部／固定Sourceを照合した。
- N55候補の限定2実行は両OSとも成功し、元リンクの長押し・再起動保持と追加のprimary tap／Close復帰、元選択訂正caseの実入力／ACK／採用／保存を確認した。限定成功を正式検証へ合算せず、旧415〜418の失敗も保持する。AX・Files・bootstrapの下位原因や恒常的解消は断定しない。修正版の実機再確認は未確認。

## N54 正式417のiOS27単項目訂正がfailure終端（2026-10-20）

- source5dc52055dbcbf05f1a141c0f9159c5a57bff163c、run39299509568／attempt1、SDK27.0／iOS27、job118221535692。18:06:32Z開始・18:31:12Z failure、18:35頃のまとめ照会で確認。選択caseはtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground。失敗段階・原因は完了ログ未読で未確定。
- 対処前に事実を記録した。Distribution・Native・原本変更訂正・三項目訂正27は成功、通常UI A/Bと明示訂正27は継続中。取消しは行わず全終端まで確認する。417は全15必須の成功が揃わず、この時点で公開できない。
- 新完了ログと同ケース／同操作段階の過去詳細・実コードを照合してから候補を決める。N53の準備変更はまだ正式Pickerに到達しておらず、今回の失敗へ因果を推測しない。Strict本文・入口・通過経路、期待値・期限・実操作を変更せず、押し直しや無根拠の同条件再実行をしない。

- 完了ログSHA1c7160e69c69f28fe72b79f8e7e30025575b755c4d9818e1e41e14a5f32a5b00。857.626秒・1件失敗。入力・ACK・実背景／復帰・再入力後のreview遷移までは進み、比較不能表示manual-comparison-unavailableを探すvisibleのNavigation.swift:48 target.existsがsnapshot timeoutになった。scroll前はtarget=virtualized／owner=unknownと記録され、一回の実scroll後、629.60秒から対象の存在照会が停止した。scroll後の実際の可視・存在は照会不能で未確定。比較不能表示の可視確認とその後の採用／保存は完了したと扱わない。下位原因は未確定。

- 検索語：Navigation.swift:48／manual-comparison-unavailable／target.exists／knownID／snapshot。N35・U11・U17・U62・U67・U72を詳細まで読み、引継ぎ8bf6c8aのNavigation／Reviewと現行を照合した。Reviewは引継ぎと同一で、既知IDを渡さずfirstMatch.existsを評価していた。N35は必須ACK、今回は比較不能の必須表示で、診断ではないため省略しない。
- 候補はReview内の明示された6つの識別IDに、既存visibleのknownID引数を渡すだけ。画面外の非存在firstMatchへexistsを照会せず、現在の一致要素配列から実要素を取得する。本文期待値の行は元のlabel検索を維持する。16回scroll・有限frame・viewport全包含・hittable、全review値と比較不能表示の必須確認、20秒状態待機、同一process・実入力／ACK・採用／保存を維持する。製品やshared navigation本体、Strict全経路を編集しない。元単項目caseが今回の失敗を検出しており、両OSの同じcaseで候補を比較する。新しい期待値や成功値を注入しない。効果と下位原因の解消は未確認。

- Linuxの生成／契約17件（0.398秒）と既存ナビゲーション検査2件・実Swift geometry27件（失敗0、準備込み2.196秒）、Swift UI構文解析、catalog432が成功した。元caseが比較不能表示とその後の採用・保存を実際に検査するため重複ケースを増やさず、両OSの同じ単項目caseを限定比較する。fresh77のコード差分レビューはblockingなし。実UI成功と根本原因解消はまだ未確認。

- 限定focus15／run39304211900・試行1・source5fd0805cc41d47890e445c120cff7e59903df11dは両OS成功・全2job終端・保存artifact0。元の単項目caseは26で589.962秒、27で590.212秒、各1件・失敗0・厳密な完了件数も一致。比較不能の必須表示から採用・保存／再起動後の保持まで通過した。旧417の失敗を成功へ書き換えず、AX下位原因・恒常的解消を断定しない。旧417の26通常A/Bも取消さず終端まで確認し、次は同一ソースの正式全15を検証する。

## N53 正式416の公開ジョブがfailure終端（2026-10-20）

- sourcec8bc05136c11c53a9df18ac28b5593ac1cb8a970、run39277679329／attempt1、SDK27.0、公開job118197006764。17:16:18Z開始・17:33:03Z failure、17:40:11Zのまとめ照会で全実job終端を確認。失敗step・段階・原因と、Releaseの実際の公開状態は完了ログ取得前で未確定。
- 同じsource/attemptの14事前検査はすべて成功したが、全15必須の成功・公開確認には数えない。旧415やfocusの成功と合算せず、取消しも行っていない。
- 対処前に事実を記録。新完了ログと過去の同step／同ケース・当時／現行コードを照合してから候補を決める。公開条件・検査・待機の緩和、結果注入、押し直し、時間切れ成功、根拠のない同条件再試行はしない。Strict本文・全入口／通過経路は維持する。

- 完了ログSHAee735b1be299572cd2fdb6715d9461c1d654f323dddc3c324bbeb1a74613ab9c。Build unsigned IPA and matching AltStore Source内のPicker UIが失敗した。SDK27.0／iOS27、testReselectionThroughActualButtonsは260.666秒、MaterialPickerTapChecks.swift:157の標準Cancel存在30秒待機が失敗。ほか2ケースは成功、3件445.015秒／失敗1。実ボタン操作後の案内は存在するが、AXには標準Filesの操作部品がなく空containerだった。具体的な下位原因は未確定。
- 公開前照合とRelease添付stepはskipped、416は公開されていない。全18実job終端（必須15のうち14成功・1失敗、構成上skip3）・保存artifact0を確認した。14事前成功（Native591件・予定skip1、Python262件・予定skip21、通常UI4組・訂正8件）は今回の失敗を置き換えない。

- 検索語：MaterialPickerTapChecks／Picker／Cancel／選び直し／ファイル選択。現索引に同じCancel存在待機の登録はない。verificationの2026-09-29／09-30、失敗監査のPicker群とe6b431a／9dcc93bの実コードを照合した。旧件は要求の破棄・appearance・対象viewportであり、今回は5回目の表示でBUTTONとUIKit表示完了が記録され、案内だけ存在する。スクロール不成立や要求未発火を原因としない。
- 比較候補は製品ではなく準備手順に限定する。今回の初回bootは218.0秒で、その後に稼働中SimulatorとテストアプリのSwiftコンパイルが同居した。既存application UI runnerと同じく、停止中の所有Simulator向けにbuild-for-testingを完了し、その後bootstatus・同じビルドのtest-without-buildingへ分ける。初期化とコンパイルの競合を除く比較で、原因・改善は未確定。SDK27.0／Runtime27.0、元3ケースと全連続操作、Cancel30秒、厳密な完了件数と遷移検査は維持する。失敗時の同条件押し直し・自動再試行はしない。独立したshell比較でビルド／boot／実行失敗・欠落／重複／skip／遷移不成立をすべて拒否してから、限定Apple比較で評価する。

- 候補のLinux shell比較は1メソッド・8独立モードが成功（2.759秒）。ビルド／boot失敗で実行しないこと、同一引数のビルド再利用、UI非zeroと欠落・重複・skipの拒否、遷移失敗の拒否と所有領域の回収を確認した。catalog432とBash構文も成功。fresh75の対象コード差分レビューはblockingなし。標準FilesとCancelの実動作はLinuxでは確認しておらず、次の限定Apple比較を待つ。

- 限定比較159／run39297199813・試行1・source88fe9378b65a744aa760dffe93435956dab442ccは全4実job終端、必要3job成功・構成skip1・保存artifact0。SDK27.0の元Picker3件は失敗0／437.199秒、連続実操作ケース246.470秒、標準Cancelと案内消去、詳細・タブ・背景復帰、その後の全遷移検査も成功した。Swift515件（78.853秒）・Python263件（55.485秒、予定skip21）も失敗0。元失敗の再現はなく、競合が下位原因だったとは断定しない。正式な同一source全15・公開物照合は次の全体検証で確認する。

## N52 正式415のiOS27三項目訂正がfailure終端（2026-10-19）

- source095e4d9f69718f37a08b5640d951bf82ea8b5460、run39267940809／attempt1、iOS27／SDK27.0、job118113079971。14:21:13Z開始・14:39:31Z failure、14:53:39Zのまとめ照会で確認。ケースはtestThreeFieldsRequireEachAcknowledgementAndFourRefuses。失敗段階・原因は完了ログ取得前で未確定。
- 対処前に事実を記録した。415は全必須条件が揃わず公開できない。Native PDF・復旧は14:45:19Z成功、Distributionと原本変更訂正ケースも成功。他ジョブは継続し、失敗後も取消しない。成功部分や旧414を合算しない。
- 新完了ログ、過去の同ケース・同操作段階の詳細と当時／現行コードを照合してから候補を決める。固定座標・結果注入・押し直し・時間切れ成功・検査条件の緩和は禁止。Strict本文・入口・通過経路は維持する。

- 完了ログSHAa70f2243dd71d1e13992466bc659cf5fbe750b314a5c1e64ac96d56b766e46cb。561.997秒・1件失敗。第1・第2項目は全文入力・個別ACKと未完了submit=falseまで成功。第3項目の実clear一回と空入力待機は成功し、直後のInput.swift:75でACK SwitchのfirstMatch.value照会がsnapshot timeout。第3項目の実文字入力・確認操作には未到達。クラッシュ報告は0、下位原因は未確定。
- 検索語：ManualAssistanceChecks+Input／Clearing text／clear／ack／snapshot／iOS27。U05、U11、U17、U62、U72の詳細とb765302／e285172／現行コードを照合。U11は消去後の古いeditor、U17／U62は追加診断、U72は完了Buttonの再照会で、今回は必須のACK=0照会である。追加診断削除やACK条件省略を対処にしない。
- 比較候補は、現在の一致IDのnative Switch配列を一度取得し、一意性を確認した実要素から同じvalue0を要求する。U11／U72で採用した取得方法との比較であり、ACK解除の時点を移さず、clear一回・空値・実keyboard／全文置換・個別ACK・45秒・元case・全15公開gateを変更しない。製品とStrictも変更しない。AXの根本原因・候補の効果は未確認。

- source133bfd68f8ba023b589cc225a56308984de028fcの限定run39273783457／attempt1は両OS成功・全job終端・保存artifact0。26は373.650秒、27は481.371秒、元threecase各1件・失敗0・完了件数一致。clear直後の実ACK0、3項目の個別確認、比較review、4項目拒否、前回正常保持まで通過した。旧415の失敗は保持し、この個別成功を全15やAX下位原因の解消へ一般化しない。次は同じコードを正式全体へ通す。

## N51 特定日の3・4限だけ空欄となる実機報告（2026-10-19）

- 利用者から、明日の3・4限だけ空欄で、翌週の同じ曜日は正常との報告。添付画像で、同一クラスの週表示における特定日2時限の空欄を確認した。画像・授業本文・個人情報はリポジトリへ入れない。
- 調査開始HEAD b22ae4788c36251f83392f3ba991d254096b6faf、最新公開414.1。利用者端末の正確なアプリ版・OS／SDKと、当該日の変更内容・表示設定は未確定。CI実行はまだ開始していない。
- 対処前に事実を記録。通常時間割、日付ごとの変更・行事・特別時間割、留学生表示、グリッドの投影を過去詳細・実コードと照合する。原因・修正済みを現時点で断定しない。Strict本文・入口・通過経路は変更しない。
- 利用者の追加確認で「通常」なら授業が表示され、「変更込み」では留学生向け休講の影響で一般授業まで空欄になるとの報告を受領。slotは全変更行で通常／特殊授業を先に抑制し、blocks・共通時刻・週末列は後から留学生向け変更を隠す構造。元解析の破損とは区別する。既存のprefix／対応表テストは単独フィルタだけで、非表示の変更と通常授業の合成を検査していなかった。これを完全独立架空入力で比較する。

- 修正前の実製品ソースへ独立架空4回帰を追加して比較した結果、Linux Swift6.1.2で515件中3ケース・7assertionが期待どおり失敗（85.364秒）。通常授業・特殊授業・曜日振替の週末列が消えることを実行で再現し、残る512ケースは成功した。表示される通常の休講／補講優先の対照も成功。新しい別障害ではなくN51の修正前再現であり、未修正の結果を合格へ変更しない。

- 修正後は同じLinux Swift6.1.2・同じ4回帰を含む515件が失敗0（76.603秒、準備込み237.9秒）。Python262件も失敗0・予定skip2。prefix／名称対応、通常の優先順位、特殊空欄非補完、曜日振替・週末、共通時刻・原文保持の対照を確認した。実機修正版・全必須CI・公開はこの時点で未確認。

## N50 QA panelのpassive比較27がfailure終端（2026-10-19）

- sourcebfefc8c798ace4bb764d3cff6f0299fe1fbae2bd、workflow_dispatch run39166116513/attempt1、iOS27／SDK27.0、job117789289759。21:03:41Z開始・21:18:03Z failure、21:22Zのまとめ照会で確認。選択caseはtestNotificationControlsAndAppearance。失敗段階・原因は完了ログ取得前で未確定。
- 対処前に記録した。N49候補は実checkPermission開始前のQA panelをhit-testing無効にしたfixture差分だけ。タブ・通知の操作と合格条件は変更していない。この結果で26比較や正式公開へ進めず、新完了ログ・過去詳細・実コードを照合する。同じ条件の無変更再試行・押し直し・期限や期待の緩和はしない。

- 完了ログSHA64ea7c33154eff23e36079a5caf862c47e508467d0d7c1313655244ebf6e2257。127.467秒・1件失敗。初回設定tabの45秒selectedと通知行10秒navigationは成功し、実Switch一回のBindingとrequestAuthorizationの同期戻りまで進んだ。その後45秒内のAllow・callback・保存ONはない。requesting=true／value0／enabledfalseを観測。N49のtab段階の失敗とは異なる。
- app/Systemの失敗画像は同一SHA93d0909a0e66d131bb8c284944ad942a5fb1b8c4c0d3ca2884130a9763cea2d4・155281bytes。実OS要求時刻windowはreturned=true／callback=falseで、通知設定entry・not-requested・on-binding・auth-request・auth-returnedを記録した。SpringBoard/runningboardd/lsd/usernotificationsdはrunning/exit0。これだけで特定OS停止・fixtureが原因とは断定しない。
- U08/U12、U31〜U39、ui-failure-patterns-20261011、ui-notification-reassessment-20261011と当時の詳細・現ScheduleNotificationsを照合。旧SDK・install後再起動・Device Hub追加だけでは未返答を解消できなかった記録を再採用しない。許可APIを推測変更せず、固定sleep・許可注入・時間延長・押し直しは行わない。
- このfocusは通知case一件だけの新規Simulatorで、正式Bのbefore/settings/after/VoiceOver後の通知区間とは準備履歴が違う。先頭／最後の因果や最適性は再評価文書のとおり未証明であり、順序を修正原因としない。N50を成功へ読み替えず保持する。次はN49の実失敗OS26で同じ候補の入力／許可caseを独立比較する。27の全case成功は未達のままで、正式全15の公開条件を維持する。小さい対象が完了した段階だけを根拠に製品の許可経路を変更しない。

- 26の独立比較run39167760582／attempt1、sourceaa1be44676497a75249bbeaf9359387f2eaf71fc、job117794202427はSDK27.0／Runtime26.5で21:42:28Z成功。既存case一件222.888秒・失敗0・skip0、厳密な完了件数も一致。初回設定tab・通知行・実Allow（frameから一回）・callback・UI1／保存true・再起動保持・外観操作が通過。ログSHAe972e0519b64c4899528dbd3ae38decf84d7cd9cde91fa0abe1e5f636ff977cd。27単独のN50失敗と合算しない。候補の元失敗OSでの動作を確認したが、入力配送やOS未返答の原因解消の証明ではない。次は前提case群を維持した正式全体414で同じsourceの全15条件を確認する。

## N49 正式413のiOS26通常Bがfailure終端（2026-10-19）

- source3e172c29f0b782dab9a0fed20eebc0e8c1a04618、run39159687367/attempt1、SDK27.0／runtime26.5、通常B job117778439248。20:15:26Z開始・20:47:55Z failure、20:56Zのまとめ照会で確認。ケース・失敗段階・原因は完了ログ取得前で未確定。
- 他13事前gateは成功し、公開job117786122622は依存skipped。413は公開されていない。26通常A・訂正4件も成功した。別実行の成功を合算しない。
- 対処前に事実を記録。新しい完了ログ、過去の失敗索引の詳細と当時／現行コードを照合してから候補を決める。同条件の無変更再試行、固定座標、押し直し、時間切れ成功、検査条件の緩和は行わない。Strict本体・入口・通過経路は変更しない。

- 完了ログSHA98dd50049d40516a8da2c966dec96233f2a9c68a916c49c8f516cd7bb9bf5666。通常6件・設定1件・残り3件は失敗0、26のVoiceOverは予定skip。別RunnerのtestNotificationControlsAndAppearanceだけが80.801秒で失敗した。Navigation:43、初回の設定iconへの一回0.1秒接触後も45秒内に選択されず、通知行・許可要求には未到達。fixture-ready、Home準備、包含／hittable、実event合成までは成功した。
- 実iconは(306.25,779,28,28)、barは(0,769,393,83)、buttonは(272.25,773,95.75,54)。失敗後の画像SHA59d88719e472d3384847243f3ecd19862a688e047000ec24752800b96c09641d（300377bytes）とAXはいずれもHome選択。QA許可panelは開始時から中央に表示され、authorization=pending／scene=active／application=0。panelのButton自体はtabと重ならず、画像だけでoverlayの入力妨害とは断定できない。SpringBoard等の診断はrunning/exit0で、特定OS停止の証明もない。
- 検索語：testNotificationControlsAndAppearance／Native tab tap／U77／U63／U30。U77全文とverificationの400〜401、U63の標準tap・icon中心tap失敗と同点0.1秒比較59、U30を詳細まで読んだ。現tab helperは9ffdf0e／fd6e42cとbytes一致し、413の他caseでも同点が通過している。N48の26通知行・実配信も今回成功したが、今回Bの入力失敗を成功へ置き換えない。
- 次の比較候補は、通知設定へ入る前のテスト専用panelをhit-testing無効にする。実checkPermissionの既存begin観測が始まった後だけ従来のQA Buttonを入力対象に戻し、許可値・設定値を作らない。現在は通知画面の外でも対話overlayが存在し、通常アプリとの差があるため、その差を限定する比較である。overlayが原因とは未確定。タブの操作点・0.1秒・一回操作・45秒、通知画面10秒・実Allow／保存・実通知の条件、全15公開gateを維持する。実装後、既存の同じケースを小さい実OS比較で確認してから正式全体へ進む。

- 候補はfixtureだけ。既存requestをPublishedとして、その有無からQA panelのhasEnteredSettingsを観測し、最初の実checkPermissionより前はallowsHitTesting(false)にする。実タブ入力・製品・全期待値は変更なし。Swift構文／catalog431、UI manifest27件（Swift指定・skip0）8.843秒が成功。runner13件も失敗0（34.907秒）、fresh69はblockingなし。通知用UIの27比較を先に一回実行し、26は次の独立比較とする。既存testNotificationControlsAndAppearanceがタブ・実許可・保存・外観を通し、testChangedDataProducesOneLocalNotificationが実配信を別に確認するため、重複ケースは追加しない。

## N48 正式412のiOS26通常Aがfailure終端（2026-10-19）

- source98838f2c1d4aa8c46312c533c0fe4279fa1e83d0、run39152448603/attempt1、iOS26 UI A job117757628234。18:43:29Z開始・19:27:33Z failure。完了ログ取得前でケース/操作/原因は未確定。他の13事前gateは成功し、公開job117767674058は依存skipped。412は公開されていない。単項目訂正26は19:24:39Z成功。
- 対処を決める前に記録。N47と過去のUI失敗の詳細、当該コード、新しい完了ログを照合し、同じ条件の無変更再試行や検査緩和をしない。Strictとその入口・通過経路は変更しない。

- 完了ログSHAae32986d8c8c2bb19e45ab66bef128963a70ee09a50113a561dde1fd152148d5。通常Aの14テストは失敗0/1499.660秒で成功。分離したtestChangedDataProducesOneLocalNotificationがApplicationChecks.swift:94のXCTAssertTrueで73.636秒失敗した。除外の操作ではなく通知単体ケースの待機失敗。サービス診断はSpringBoard/runningboardd/lsd/usernotificationsdが全running・exit0であり、特定サービス停止とは断定しない。

- 検索語：testChangedDataProducesOneLocalNotification／通知行／ApplicationChecks.swift:94／native tap。U75の同じSDK27.0・Runtime26.5・同じ(48,603.5)へのapp-relative tap失敗、U30/U63の実接触未反映、U06の許可前OS照会を詳細まで照合した。ea8401dのopenNotificationSettingsは現988とbytes同じで、起動・設定tab・全包含までは今回も成功した。失敗後のlabelは(32,593.3,32,20.3)、rowは(16,577.3,361,52.3)で位置が一致し、スクロール不足や通知許可未返答の証拠ではない。
- 次の比較は同じ観測labelの中心を実native elementへ結び、tab/Switchで既に使用している0.1秒のbrief contactを一回行う。app-relative座標のtapから入力方法だけを変える。保存した画面位置・押し直し・ナビゲーション注入を使わず、元の10秒nav待機・45秒実Allow／保存・新規実通知1件とrevisionの証明を維持する。既存の当該UIcaseが遷移不成立を検出しており、重複caseは追加しない。製品・Strict・入口は不変。恒常的解消や下位原因を検証前に断定しない。

- Swift UI構文解析とcatalog整合（431登録）が成功。Python UI manifest27件はSwiftをPATHへ指定してskipなし/失敗0（7.867秒）、runner13件も失敗0（34.421秒）。fresh68のコード差分レビューにblockingなし。実UIは次の正式413で全15条件を確認し、412の成功部分を合算しない。

## N47 正式411のiOS27通常UI A・単項目訂正がfailure終端（2026-10-19）

- sourcea0fed9b4666ec692b136823eff9482bb2a69849c、run39149191816／attempt1、SDK27。通常UI A job117739517081は17:22:59Z開始・17:58:43Z failure。単項目訂正job117739517113は17:34:33Z開始・17:58:16Z failure。18:00Zのメタデータで確認。
- 対処前に記録。ケース内の段階・原因は完了ログ取得前で未確定。通常UI Bと他の訂正3件・Native・Distributionは成功。iOS26 Bは実行中で取消しない。依存skippedは成功にしない。
- 411は全必須条件が揃わず公開できない。原ログと失敗索引の関連詳細・同じコードを照合してから対処する。Strict・検査条件・待機上限は緩めない。

- 完了ログSHAはA d6803817f30529e3d2a78c2a57d6c505a0e649045d79796845695eed714041b1、単項目04b90e08a70643eae9ccd49520c4370bf4837f14d41a77abeb746c13eee4faea。AはtestChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch、Navigation:186。除外groupのy730.33〜782.67に対しviewport129〜769、次の大swipeでy62.67〜115へ行き過ぎ、6回上限で完全包含しなかった。通常他ケースは続行した。
- 単項目は背景復帰と再入力・完了を通過し、assertSubmitEnabled(false)の元predicate評価後にInput:49の追加manual-input-state.exists照会でsnapshot timeout。実submitの待機結果は失敗前に出力しておらず成功と断定しない。
- 検索語：testChangeRows／visible／scroll／manual-input-state／Input、U73/U67/U62/U17の詳細と当時のコードを照合。今回は大スクロールの反復行き過ぎと、元待機後の追加診断。既往の必須frame照会・ACK操作不発とは分ける。
- 比較候補：既に実frameを取得できた対象は観測viewport中心との差だけを上限付きdragで補正し、不在の探索は元swipeを維持する。6回・2秒・完全包含・実control一回操作は維持。純粋geometryの往復対照と無効frame拒否を追加する。単項目は追加診断existsを取得済みoutcome出力へ置換し、元enabled predicate／期限／completed assertと後続全操作を保持する。製品・Strict・入口は変更しない。次の実行前に根拠もpushする。ローカルで実geometry XCTest7件が0失敗、Python262件0失敗・予定skip15（PATH上のSwiftなし等）、Swift UIソースの構文解析・catalog整合が成功。実UI通過を意味しない。

## N46 公開前レビューで除外全解除・認証取消のcache条件を検出（2026-10-19）

- 補正済み資料で再レビューすると除外全解除の確定が無効になる。初回L token後のM/T認証シート取消で既存cacheが残る。WindowsレビューのJWKS待ち時間によるcache期限延長もiOSで同じ構造を確認。公開前、Actions未開始。レビュー48/49の現行差分を記録し、既存の全体再解析と期限・取消条件を緩めずに修正する。

## N45 本番OIDC認可開始が環境からHTTP403（2026-10-19）

- 認証サーバー506278cのCloudflare本番成功後、両nativeクライアントのlinks専用standard認可開始GETを各1回実行した。どちらもHTTP403。ログイン・token交換は実行していない。
- 現時点でクライアント未登録や学内認証不良とは断定できない。ネットワーク経路・本番のアクセス制御と、worker/両ブラウザの架空環境成功を区別する。403を認証成功にしない。同じ条件で再試行しない。
- 既存のWindowsクライアント登録済み記録を保持し、実機の学内/学外・Microsoft認証・callbackの完了は未確認として残す。

## N44 正式名称表示409のiOS26通常画面Bが失敗終端（2026-10-18）

- source2ccd0bacf9657228230daf34e2b95a27d006b145、run39060029511／attempt1、job117482754365。
  Application iOS26 UI Bは19:25:02Z開始、19:49:28Zにfailure終端。19:53Zのまとめ照会で確認。
- ログ取得前でケース・失敗段階・原因はまだ未確定。iOS27のA／B・訂正4件とNativeは成功。
  iOS26の変更原本・3項目訂正は成功し、A・単項目・明示選択は実行中。取消しない。
- 409の必須検査が揃わないため公開しない。正式名称表示の問題か、既往のUI／OS依存の問題かを
  原ログ・失敗索引の詳細・当時のコードと照合してから対処を決める。
  条件緩和・押し直し・結果注入で成功にしない。対処前に事実を記録した。
- 原ログでは `testLinkPreferencesSurviveRelaunch` が88.793秒で失敗。
  最初の一覧で、架空リンクAのお気に入り状態・全表示・hittableを確認し、実rowを一回長押しした後、
  「お気に入りを解除」Buttonの45秒待機がSettings.swift:309で失敗した。
  失敗時のAXには元のお気に入り付きrowが残り、メニューはない。正式名称の表示箇所ではない。
  U42の初回ブラウザ遷移・U54の再起動後メニュー不発と、当時／現行コードを照合してから候補を決める。
  「再起動後」とした初回の転記は、解除／追加の操作順を実ソースで照合し「最初」に訂正した。
- 架空の操作前後画像をサイズ・SHA照合して確認した。操作後は白いapp画像、後続AXは元の一覧。
  U42のBrowserView到達・U54の再起動後と条件が違う。長押し後のメニュー確認前に約13秒の
  app撮影・全AX取得がある。次はその観測を失敗後だけにし、同じ実メニューの45秒待機を直後に行う。
  押し直し・待機延長・成功注入はせず、System画面も失敗後だけ記録する。
  原因解消ではなく観測干渉を減らす比較であり、根拠を先にpushしてから実行する。

- 410／79dcf62／39065168877・attempt1は全15必須条件が成功し公開した。
  配布SDK27.0で同じリンクケースは27が157.527秒、26が88.675秒で実解除・再起動・再追加まで通過。
  26.6の焦点比較だけで合格扱いにせず、両OS通常UI・手動訂正8件・ビルドの成功を揃えた。
  今回の観測順序での成功であり、撮影が原因という証明・OS全般の恒常的解消ではない。

## N43 システム依存導入が非管理者権限で拒否（2026-10-18）

- N42の不足依存導入を試みた `apt-get update` は、apt設定の読取りとlists領域への書込みを
  Permission deniedとしてexit100。install段階は未実行、製品・テストは変更なし。
- 対処前に記録。N42／既存Linux開発手順の「システムを変更せず専用prefixへ展開」を照合した。
  現OSのSQLite runtimeは3.46.1-7+deb13u1。次は同じ版の公式Debian開発packageを所有領域へ展開し、
  headerとruntimeの版を合わせる。管理者権限や環境再接続を要求しない。
- 同版の推定Debian URLはHTTP404で、展開には進まなかった。配布索引の現存版を確認してから、
  同じ版のheaderと共有libraryを一組で展開する。製品テストの再実行はまだ行っていない。

## N42 Linux再導入環境の解析テストがSQLite header不足で停止（2026-10-18）

- source eb4f7c7、Debian13／公式Swift6.1.2、`bash tools/test-parsing.sh` の初回実行。
  依存取得後のビルドでGRDBSQLiteの `sqlite3.h file not found`、49.9秒・exit1。
  XCTestの実行には未到達。製品の解析失敗や実資料の品質失敗には数えない。
- 対処前に記録した。N39の新環境と `development.md` のLinux依存設置手順を照合する。
  既存のUbuntu／旧環境の設置先は現環境にはなく、Swiftのみ新規導入済み。
  次はOSの開発header／libraryの実在を確認し、不足依存を導入してから実行する。
  コード・期待結果・検査条件は変更しない。
- 公式Debian索引からSQLite3.53.4のheader・共有libraryを同じ専用prefixへ展開した後、
  Swift6.1.2の全504件が失敗0で完了（実行118.896秒、準備・ビルド込み359.5秒）。
  システムSQLiteとの混在、製品・期待結果の変更はない。

## N41 最新版で時間割変更の初回除外が「解析を中止した」となる実機報告（2026-10-18）

- 利用者報告：最新版、行を除外して解析すると一度失敗し、表示は「解析を中止した」相当。
  正確な文面・OS・除外行・次に成功する操作・版番号は未確定。学校資料は取得していない。
- 現コードeb4f7c7／公開408.1のXLSX経路を読取り調査中。396.1の受付前に画面を閉じる問題とは
  同一原因と断定しない。U19／U49／U05、396.1の詳細記録と現コードを照合する。
  現コードは受付後に原本を再取得し、同一性・SHA・年度・警告行を照合してから全残存行を再解析する。
  `cancelled` は利用者取消のほか確認対象不一致にも使われるため、報告だけで取消操作とは判定しない。
- 発火条件を再現する前に製品修正や解消済みの扱いはしない。架空入力での確認と実機報告を分ける。
- [全経路の調査](change-row-exclusion-audit-20261018.md)へ、取消理由の混在、受付後の画面消失、
  年度・失敗表示・自動確認の不整合を記録した。状態メソッドのSwift実行と実機原因を区別する。

## N40 本体再照合スクリプトの固定件数assertが失敗（2026-10-17）

- source cd56ae2、Linuxの読取り専用監査で、`.swift`の件数208かつ変更3件という一時スクリプトのassertが停止した。
  件数を数える対象と、以前の本体205ファイル不変の記録が一致するかは未確認。
  公開テスト・アプリの失敗ではなく、Strictの開始／再試行bytes照合へはまだ進んでいない。
- 対処前に記録した。固定件数に関するN30と、git tree・変更pathの実在一覧・以前の検証記録を照合する。
  製品・検査条件を変更せず、対象を確認してから監査を組み直す。新規Actionsはまだ開始していない。
- N30詳細と実treeを照合すると、Takupoke内は202ファイル、Swiftだけなら174だった。
  Package2ファイルとXcode project4ファイルを合わせた208ファイルのうち、変更は元のOCR専用3ファイル。
  以前の不変205という対象全体の数を、誤ってSwiftだけの件数へ使っていた。
  次は元の208全ファイルと別のVendor21ファイルをbytes照合し、追加／削除の拒否・3ファイル限定・Strict開始／再試行の一致も要求する。
  コード・公開テストは変更せず、この根拠を先にpushしてから読取り監査を再実行する。
- da1c7a4で根拠をpushした後、元の208全ファイルとVendor21ファイルをbytes照合した。
  追加／削除なし、OCR専用3ファイル以外の205ファイルとVendor21ファイルは不変で、
  Strict開始／再試行メソッドも元のbytesと一致した。全75commitの空白検査も成功。
  その後の正式408全15チェックも成功した。監査対象の誤りを修正した結果で、製品や公開テストは変更していない。

## N39 再開環境に作業ディレクトリが存在しない（2026-10-17）

- AltStore Source更新の再開時、既定cwd `/workspace/takupoke-ios` のプロセス生成がNo such file or directoryで拒否された。
  `/bin/sh` の診断はbashのみ対応として拒否され、bash・cwd `/` のpwdは成功した。
- 環境の状態はrunning／接続あり。`/workspace` は存在したが、リポジトリと前の内部作業フォルダは存在しなかった。
  テスト・新規Actions・配布処理はまだ開始していない。観測事実をリポジトリ外の内部記録へ先に保存した。
- 環境の再起動を依頼せず、利用者承認済みのremoteから開発branchを新規cloneした。
  HEADはcd56ae2776e9447295a3aced24975c131728a9ecでリモートと一致しclean、mainは8bf6c8aのまま。
  既存変更を破棄せず、学校PDFや削除済み資料も再取得していない。
- N16のtransport切断と、今回のcwd選択／clone後の実状態を照合した。
  N16は同じ作業場所の最小呼出しが回復した事例で、今回は元のディレクトリ自体がなかった。
  原因を同一視せず、リポジトリ復元後の読取り・空白検査・一覧検査の成功を別に記録する。

## N38 配布記録更新時のworkflow参照パス誤り（2026-10-17）

- source d40ba835の配布後、文書だけのpush対象を確認するローカル読取りで、
  `sed .github/workflows/development.yml` が「No such file or directory」となった。
  全15検証・開発版公開・公開添付照合はその前に成功しており、テストや配布の失敗ではない。
- 対処前に事実を記録した。存在するworkflow名と発火対象はまだ再照合していない。
  コード・検査条件・Actionsの再実行は変更しない。
- N28の不足Git objectと当時の取得方針を読み、今回は旧commitではなく参照ファイル名の誤りと区別した。
  `rg --files .github/workflows` と実コードを照合すると、開発検査は `test-tools.yml` で、
  `ios-release.yml` はmainへのpushまたは明示dispatchが対象だった。
  現在の各push対象にもMarkdownはなく、今回の文書だけのpushで新規Actionsを開始しないことを確認した。
  workflowの編集・再実行・Git objectの追加取得は不要だった。

## N37 訂正探索改訂commitのpushがHTTP401で失敗（2026-10-16）

- ローカル968deb0329e5f1d6514827ef914098bdd509a63b作成後、既存のgh credential helper指定pushがHTTP401で終了1。
  RPC failed／unexpected disconnect／Everything up-to-dateが混在し、remote到達は未確認。
- コード差分レビュー31・空白検査は完了済み。新規Actionsの開始を推測しない。
- 対処前に記録し、N14の認証詳細・既存GH_TOKEN／保存helper／remoteの実状態を秘密値を出さず確認する。
  API回数制限や認証失効をこの応答だけから断定せず、再接続依頼を先に行わない。
- 既存GH_TOKENのuser APIは終了0・n624-dev。保存credentialはなく、明示helperのcredential fillは成功し、
  そのpasswordと既存GH_TOKENは一致（値は出力しない）。http extraheader設定はない。
  読取りremoteはa58a83dで、968deb0は未反映だった。N14にもAPI要求ごとに応答が異なる記録がある。
  原因は未確定のため認証を置換せず、次は同じhelperにHTTP/1.1とCache-Control:no-cacheだけをコマンド単位で指定する。
  新規コード差分レビュー・未送信各commitの空白検査後に一回試し、remote到達とActions開始を別に確認する。
- 新規レビュー32後、同じcredentialにHTTP/1.1／no-cacheだけを指定したpushは終了0で、remoteは465a11dへ進んだ。
  未送信968deb0／465a11dの各空白検査も成功した。認証の再接続・置換は行っていない。
  この限定条件の成功から401の下位原因や恒常解消、Actionsの合格は断定しない。

## N36 全15実行の明示選択iOS26が失敗終端（2026-10-16）

- source9274ca7711fcc970eb87c9dfa10a788e45ae30e1、run38965830079／attempt1、job117206109045。
- testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunchは21:32:58開始、22:03:57にfailure終端。
  22:07照会で確認した。26の元単項目は成功したが、通常A／B・元3項目は実行中で取り消さない。
- このsourceの非公開draft415398713は公開しない。focused両OS成功と、今回の全体実行を区別する。
- ログ取得前で失敗段階は未確定。対処前に事実を記録し、新規原ログと過去の詳細・当時コードを照合する。
- 原ログでは1131.203秒・1件失敗。3項目入力・全ACK・レビューは通過し、第四メニューを表示する
  visibleの16回探索が尽きた。第四項目の操作・拒否・保存／再起動へ未到達。
  初回queryが選んだcell-1-1のTextは、次回frameが表示範囲内でもhittable条件を満たさず、
  そのIDへ固定した探索が末尾まで進んで一回反転し、元の行へ戻る前に上限へ達した。
  なぜそのTextがhittableでなかったかの下位原因は未確定。preview=true／draft=nil／lastgood-preservedは残った。
- N25／N32とU05詳細、旧82ca252・現OneCorrection／Navigation／純粋な幾何helperを照合した。
  N25は全列挙0件、N32は第四操作後のstatus、今回は第四操作前の「任意の別授業」の候補選択である。
- この目的は固定の第二授業ではなく、現在以外の実際に操作できる別授業を一つ選ぶことである。
  既存visibleへ任意候補queryを明示した場合だけ、各回にmaterializeされた候補の実frame・全包含・hittableを照合し、
  満たす実Textを返す。最初の不操作候補IDへ固定しない。通常の入力／ACK探索の既定動作は維持する。
  共通の16回上限・一回反転・物理スクロール・不成立時失敗・第四項目一回操作・全assert／期限は保持する。
  純粋な選択関数の対照では、先頭の表示済みだが不操作の候補だけで後続の操作可能な候補を失わないことと、
  不可視・不正枠・不操作だけなら選ばないことを実ソースで検証する。先に根拠をpushしてから改訂する。

## N35 メニュー小分割ソースのfocused iOS27も失敗終端（2026-10-16）

- source f5bb0f242330967fb1450db90945b26900971cee、run38959258252／attempt1、job117169905629。
- 20:02:06開始、20:31:51にfailure終端。20:35照会で確認した。このrunは両OS終端、26はN33のコンパイル失敗。
- 27の新規ログ取得前で失敗段階は未確定。N32と同じ原因かは照合してから記録する。
- 新source5d7099eのfocused38961358839は両OS実行中で、取り消さない。失敗事実を対処前に記録した。
- 原ログでは1237.201秒・1件失敗。教室の原画像確認・全文入力・完了・keyboard非表示の後、
  3項目の最初の科目ACKを表示するNavigation.swift:45のtarget.existsでsnapshot query timeoutになった。
  この回は第四項目・上限statusへ未到達で、N32のstatus不在と同じ失敗ではない。
- U72／U67／U62／U17の詳細と実Input／Navigation、引継ぎ8bf6c8aのInputを読んだ。
  過去は追加診断やframe照会の停止で、今回は必須ACKの画面外存在照会。共通2ファイルは引継ぎと差分ゼロ。
  現在の消去Buttonは既存knownIDの配列探索を使う一方、ACKの初回visibleはtarget.existsを使用している。
  下位原因は未確定。待機延長・押し直し・ACK省略は行わず、この旧sourceをそのまま再実行しない。
- 5d7099eの両OS実行はこの失敗観測より前に開始済みである。まずその実測を確認し、
  同じ停止がある場合は既存knownID方式との違いを根拠に必要な照会だけを改訂する。恒常的な解消とは扱わない。

## N34 プレビュー式移動後のQA生成markerが不一致（2026-10-16、Linux）

- HEAD7c3a067の未コミットView分割／statusナビゲーション、manual系37件・2.945秒、errors4・予定skip4。
- tools/manual_ui_project.pyのonceがmanual UI fixture insertion point missing or duplicatedで停止した。
  この差分の新しいActionsは未開始。SDK成功やUI品質の失敗とは扱わない。
- 対処前に記録した。N29の完全行照合、生成器の実markerと移動したViewの実行を照合してから改訂する。
- 全4errorsは同じmanual_ui_project.py:97のプレビュー見出しmarkerで、20個の字下げを含む完全行が一致しなかった。
  Sectionの本文はN33の移動前後で字下げ除去後の全bytesが一致している。
  N29と実際の完全行照合規則を読んだうえで、marker／replacementの字下げだけを新しい8個へ合わせる。
  onceの一意・存在検査、実見出しの識別子、表示・操作・合格条件は維持する。先にpushしてから修正する。

## N33 式分割後のfocused iOS26が再び失敗終端（2026-10-16）

- source f5bb0f242330967fb1450db90945b26900971cee、run38959258252／attempt1、job117169905187。
- Native input iOS26は20:02:07開始、20:12:53にfailure終端。20:17照会で確認した。同runの27は実行中で取り消さない。
- ログ取得前で失敗段階は未確定。N31のメニュー式分割をSDK26での解消と扱わない。
- 対処前に事実を記録し、新規完了ログとN31の原ログ・実コードを照合してから次の対処を決める。
- 原ログではXcode26.6／arm64 simulatorのPDFRecoveryView.swift:124の既存補助入力説明Textで、
  同じtype-check時間の診断となった。ビルド失敗、XCTest未開始。先の小分割だけでは不十分だった。
  N31のButton診断と異なる式へ移ったこと、現在も大きいbodyに全分岐が入っていることを実コードで照合した。
- 引継ぎView・現在の生成View・開発方針のView分割条件を照合した。同じView型・State所有者・List・条件・modifier順序を保ち、
  読取結果プレビューの3個のSectionだけを同型のprivate @ViewBuilder関数へそのまま移す。
  新しいcontainerやAnyViewは加えず、手動編集／レビュー・Coordinator・Strict全経路・テスト条件は変更しない。
  N32のstatus表示用の実スクロール追加と合わせ、次の新規レビュー後に両SDKで再検証する。
  この記録を先にpushしてから分割し、SDK26.6の成功を確認するまで解消と記載しない。

## N32 独立した明示選択訂正のfocused iOS27も失敗終端（2026-10-16）

- source f1abea00ac91c6898ca1c8fe5128bef1f3ac7e17、run38956671414／attempt1、job117161157407。
- Native input iOS27は19:40:48開始、20:01:59にfailure終端。20:15の照会で確認した。
- 同じrunの26はN31のSDKコンパイル失敗。27の失敗段階・原因はログ取得前で未確定で、同じ原因とは扱わない。
- 対処前に事実を記録した。新規完了ログと過去の詳細・当時コードを照合し、次の試行前に根拠をpushする。
- 両OSが終端となった。新source f5bb0f2のfocused38959258252は進行中で、取消さない。
- 新規原ログではコンパイル成功後858.692秒・1件失敗。追加2／3項目の入力・全ACK・レビューを通過し、
  別授業の実IDを表示して、第四項目の実メニューを一回長押し・実Buttonを一回tapした。
  その後OneCorrection.swift:123の上限statusのwaitForExistenceが失敗。保存／再起動は未到達。
  AXはpreview=true／draft=nil／running=false／lastgood-preservedで、3項目説明はy40.7（navigation下より上）、
  授業行側が表示されている。上限status自体はAXに存在せず、拒否メッセージ表示の成功とはまだ数えない。
- U05の詳細リンク・N25・旧82ca252と現OneCorrection／Navigation／Viewを照合した。
  N25は第四メニューの表示前だったが、今回は表示・実操作後の先頭status確認である。
  旧コードからこのstatusだけを無スクロールで存在待ちしていた。既存review／previewは有界visibleで上側を表示している。
- 対処候補はstatus照会の前にも既存visible(towardTop:true)を使い、実スクロールで表示することだけ。
  元の正確な文言・wait期限・第四項目一回操作・3項目保持・保存／再起動のassertは維持する。
  製品コード・共通Navigation・時間上限・合格条件は変えない。根拠を先にpushしてから追加する。

## N31 独立した明示選択訂正のfocused iOS26が失敗（2026-10-16）

- source f1abea00ac91c6898ca1c8fe5128bef1f3ac7e17、run38956671414／attempt1、job117161156858。
- Native input iOS26は19:40:50開始、19:51:16にfailure終端。同じ実行のiOS27は19:59照会時点で実行中で、取り消さない。
- 指定ケースはtestSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch。失敗段階・原因はログ取得前で未確定。成功・未完了を推測しない。
- 原ログと過去の詳細・当時コードを照合してから対処を決め、次の試行前に根拠をpushする。
- 新規完了ログではXcode26.6／arm64 simulatorのPDFRecoveryView.swift:64の訂正Buttonで、
  the compiler is unable to type-check this expression in reasonable time。ビルド失敗でXCTestは未開始。
  iOS27の途中状態やSwift504件の成功は、このSDK26.6のコンパイル成功へ読み替えない。
- type-check／ViewBuilder／コンパイル／PDFRecoveryViewで索引を検索し、N03・N20・N21の詳細と実コードを読んだ。
  過去はtry・import・生成stub宣言の不足で、今回はネストしたForEach／contextMenu内の式の診断である。
  引継ぎ8bf6c8aのViewにはこの訂正メニューがなく、現在のQA生成は追加メニュー自体を置換していない。
- 同じPDFRecoveryView内の型を明示した小さなmenu／button関数へ追加部分だけ分ける。
  nativeCapture条件・役割集合・対象ID・無効条件・表示・標準contextMenu・操作は維持する。
  Strict・Coordinator・認識／採用条件・テスト期限は変えない。新規の模擬コンパイル成功は作らず、両SDKで再検証する。
  この根拠を先にpushしてから分割する。

## N30 UIケース追加後のローカル契約検査2件が旧件数で失敗（2026-10-16）

- HEADbbf1980の未コミットUI分割、Linux Python258件・30.813秒、失敗2・予定skip11。
  test_qa_only_owner_resolution_and_existing_caps_are_preservedがfunc testの4対旧3、
  test_all_six_manual_checks_reject_borrowed_source_or_attemptがmanual jobの8対旧6で失敗した。
  新しいApple実行・コードpushはまだ開始していない。製品／Strictは8616156と同じ。
- 対処前に記録し、N18の登録件数不一致・元の2検査・追加した第4ケースと両OSの必須集合を照合する。
  元3ケースと元13必須jobの包含、借用source／attempt・未完了・欠落の拒否を維持する。
- 実コードではどちらも固定された旧件数のassertで、幾何helperや公開判定の失敗ではなかった。
  新しい宣言4／手動8へ更新し、元の借用source／attempt拒否のloopは8件すべてへ拡張する。
  元13件だけでは新しい15件の配布条件を通れない追加検査と、元3ケースの本文byte一致も確認する。
  この事実・対処を先にpushしてから再検証する。実操作・幾何・時間・完了のassertは除かない。

## N29 UI分割patchのrunner行照合が失敗（2026-10-16、Linux）

- HEAD0943e0aからの未コミット分割patchが、tools/test-manual-ui.shのexpected行不一致で停止した。
  テスト・Actionsの新規試行は開始していない。適用範囲はstatusと実差分で確認する。
- 対処前に記録し、N23の段落照合失敗と、今回のrunnerの実際の完了集合行・patchを照合する。
  検証の期待値を減らさず、実在する行を指定して4ケース全件の登録へ進む。
- statusは索引Markdownだけの変更で、分割コードは一切適用されていなかった。
  実際のexpected集合は1行で、patchが複数行の断片として指定していた。N23と同じ完全行照合の誤り。
  この記録を先にpushし、実際の1行全体を指定して編集する。期待集合と照合は4件へ追加するだけとする。

## N28 過去コード照合用のGit objectがローカルにない（2026-10-16）

- N27調査でgit show 694a862:tools/manual_ui_project.pyがinvalid object nameで停止した。
  現在のソース・テスト・進行中Actionsは変更していない。旧コードの実照合はこの時点で未完了。
- 対処前に記録した。索引・詳細にある完全SHA694a862d7599fa678c28f1f29a71d9707137523bを対象に、
  現在のbranch／worktreeを変えず読み取り用に必要なcommitだけ取得し、その実ソースと照合する。
  N27の当時コード照合の記載は、この取得・照合を終えるまで完了と扱わない。次のUI試行前に根拠をpushする。
- ローカルcloneはshallowだった。完全SHAだけをdepth1でfetchし、当時の手動訂正ケース・runner・workflowを読んだ。
  当時も元3ケースを別job・45分で検証しており、新しい選択シナリオはなかった。
  元branch／HEAD／worktreeを変更せず照合できた。旧U51は途中ログ不明のまま保持し、今回と同じ下位原因とは断定しない。

## N27 明示訂正追加ケースのjobがcancelled終端（2026-10-16、iOS27）

- ソース20a1c0f70461988443d74acc2a5bdb83be88622b、全13実行38948658443・attempt1、
  job117134911132のtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundが
  19:24:51UTCにcompleted／cancelledとなった。開始18:38:36UTC、手動訂正jobの設定上限は45分。
- 現在はmetadata上の結果だけで、停止操作・XCTestの完了件数・取消理由は未確認。
  主担当からActions取消は行っていない。時間切れを成功にせず、この実行から配布しない。
  対処を決める前に記録し、新規完了ログを一回取得して過去詳細と実コードを照合する。
  他jobは取消さず、依存関係による未実行も成功へ数えない。
- 新規完了ログとcheck annotationを各1回取得した。annotationは
  The job has exceeded the maximum execution time of 45m0s。XCTest開始18:50:43、完了0件。
  既存入力／実背景／再編集／1項目保存／再起動は19:06:16までに完了した。
  追加段階は教員／教室選択・3入力・全ACKを終え、19:23:53の3項目レビュー状態で進行中に中断した。
  第四項目の修正した探索には未到達で、N25を解消した実測とは扱わない。
- U51の45分上限・U07の完了必須、N25、当時と現在のケース／runner／完了guardを照合した。
  今回はコンパイル・準備だけで約12分、既存段階約15.5分、新しい段階は約18分でも未完了だった。
  操作を削らず、新しい明示選択だけを独立した第4ケースにする。元3ケースは保持する。
- 配布前matrixへ新ケースを両OSで追加し、必須集合を元13件の包含を保った15件にする。
  元ケース45分・全操作の期限・16回の探索上限・一回操作・完了件数・失敗時の公開拒否は維持する。
  focused実行にも新ケースを登録し、その新ケースだけ配布前と同じ45分を与える。元3ケースの35分は維持する。
  この事実・照合・候補を先にpushしてからテストを分割し、関連UIを両OSで検証した後に全15へ進む。

## N26 私有Tesseract比較の設定事前検査が失敗（2026-10-16、Linux）

- ソースf5a44c8の変更していない192原コード生成器を参照する私有比較で、
  Tesseract5.5.0・eng・PSM13の設定事前検査がAssertionErrorとなった。
  --print-parameters出力のload_system_dawg／load_freq_dawgを0として検出する検査で停止。
- 192画像の生成・OCR呼出し・採点はまだ開始していない。Tesseractの精度・成功件数はない。
  対処前に事実を記録し、実際の設定出力と過去の非UI準備失敗を照合する。
  アプリ・Strict・進行中の全13実行には変更しない。
- 実出力は両設定とも1だった。N12／N17の準備失敗詳細と私有比較コード、
  公式5.5.0のtesseract.cpp／capi.hを照合した。CLIの-cはInit後のSetVariable経由であり、
  モデル初期化前の辞書読込停止を、この照会の成功終了だけでは立証できない。
- 同じ固定設定をInitへ渡す設定ファイルにし、実認識と同じengを指定した事前照会で両方0を要求する。
  確認した同じ設定ファイルを各実呼出しへ渡す。元の0条件・LSTM／PSM13・原画素・一回実行は緩めない。
  この照合と候補を先にpushしてから確認し、0を確認できなければOCRへ進まない。
- d654dadの記録push後、同じengと初期化用設定ファイルの事前出力で両設定0を確認した。
  その固定設定で192回の私有CLI比較が完了し、実行エラー0だった。初回事前検査の失敗は保持する。
  当該比較は44/192一致・V1比で改善1／悪化125の否定的結果で、精度合格・採用・iOS検証ではない。

## N25 明示訂正追加後のiOS27・1項目UIが失敗（2026-10-16）

- ソース82ca25222a6a7dce880f0feb3c1378b2fea4b144、全13実行38943603378・attempt1、
  job117117707227のtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundが
  18:29:57UTCにfailureとなった。iOS27／Xcode27の対象である。
- 現在はmetadata上の結果だけで、既存背景保持・新規明示選択・保存・再起動のどの段階かは未確認。
  対処を決める前に事実を記録し、新規完了ログを一回取得して過去の詳細と実コードを照合する。
  同実行の他jobは取り消さず、未実行・依存skipを成功に数えない。配布は保留する。
- 新規完了ログを一回取得した。1427.616秒・1件失敗で、既存の背景保持／再編集／1項目保存／再起動は通過。
  新しい教員／教室の実メニュー操作・3項目入力・個別ACK・再レビューも通過し、
  OneCorrection.swift:113の「現在とは別の訂正メニューがある」検査で失敗した。3項目保存は未実行。
  直前にrequirePreviewが先頭見出しへ戻しており、全メニューの無スクロール列挙は0件。
  失敗時AXにはpreview=true・running=false・lastgood-preservedと先頭の採用見出しがある。
- U05の画面外List要素、U67／U72の復帰・照会停止と現在のNavigation／OneCorrection／Viewを照合する。
  今回はsnapshot timeoutではなく、先頭へ移動した状態で仮想化された授業行を未表示のまま列挙した段階。
  未表示を実フィールド不在と決めず、第四項目の実メニュー操作・拒否・保存を省かない修正を検討する。
  この事実と照合記録を次のUI試行前にpushし、閾値・待機・Strictは変更しない。
- 候補は第四項目の探索だけを、現在の対象を除外した実identifierのqueryと既存visible helperへ置き換える。
  先頭見出し位置から既存16回上限の実スクロールで別授業の実メニューを表示し、その実IDから対象を取得する。
  元の一回の長押し・メニュー実Button・第四項目拒否・lastgood保持・3項目保存／再起動の条件を維持する。
  View／Coordinator／Strictと既存Navigation helperには変更を加えない。Apple実行での効果は未確認。

## N24 新規完了ログ保存用JavaScriptの構文エラー（2026-10-16）

- ソース82ca252の完了Native job117117707173を取得するJavaScriptがmissing ) after argument listで停止した。
  解析時の停止なのでログ要求・保存は開始していない。jobはmetadata上successで、CI失敗ではない。
- 対処前に事実を記録し、N17の同じログ取得準備の失敗と今回の入力を照合する。
- 保存用map式が文字列連結の記号を欠いていた。取得条件・ログ内容・検証は変えず、その一文字を修正する。
  この記録を先にpushしてから新しい完了ログを一回取得する。Actionsの再試行・取消はしない。

## N23 文書patchの行照合が失敗（2026-10-16、Linux）

- HEAD 057abb4の未コミットN22改訂中、apply_patchがpdf-recovery.mdのexpected lines不一致で停止した。
  テスト・CI・アプリ実行は始めていない。対処前に事実を記録し、元の行とpatchを照合する。
- patchが段落一行の前半だけを完全行として指定していた。変更は適用されていない。
  N19の末尾空行とは別の文脈指定ミス。不要な同一文言の置換を除き、必要な追記だけを行う。
  この記録を先にpushし、コード・文書の差分と空白を改めて照合する。

## N22 import修正後のSwift jobも失敗（2026-10-16）

- e03069dの開発38941894390、Swift job117111324746が17:47:35UTCにfailureとなり全job終端。
  N20のimportは追加済み。現時点はmetadataのみで、コンパイル・新テスト・既存退行のどこかは未確認。
- 対処を決める前に事実を記録し、この新規完了ログを一回取得して過去詳細・実コードと照合する。
  後続7d0b172はtest stubだけの修正であり、このSwift failureの修正済みとは扱わない。
- 新規ログを一回取得し、Swift504件が63.399秒で完了、失敗1・他503成功だった。
  既存testManualEverySourceHashSnapshotParentCropAndTargetIsBoundのmutation0だけが、
  RecoveryManualAssistanceTests.swift:366のXCTAssertFalseで失敗した。新規4ケースは成功。
  mutationの内容・新schema2との関係は実コードを照合してから判断する。
- 旧基準8bf6c8aと現コードを照合した。mutation0は有効な従来schema1記録の版番号だけを2へ変える。
  新validationErrorsはschema2という番号だけで訂正集合全体を明示選択と見なし、その変更を受理していた。
  不明版の期待値を3へずらして通さず、この既存拒否テストはそのまま維持する。
- 新schema2記録には実際に要求した選択対象の順序付き集合も保持し、全記録で同じ非空・重複なし・
  最大3・正規順の集合が存在することを必須にする。必須低信頼欄は引き続き別に追加・検証する。
  旧schema1はこの追加値nilだけを許し、nilは保存JSONへ出力しない。番号だけの変更を拒否する。
  元document／取得／Source／crop／値の検査と最大3を維持し、新記録の集合欠落・変更・重複も検査する。
  この原因・対処を先にpushし、実装改訂と新規レビュー19の改訂確認後に次の試行へ進む。
- N22判明前に開始した7d0b172の38942373783も全job終端。Python117112948468はsuccess、
  Swift117112948936は17:51:49UTCにfailure。selectedTargets修正前のソースである。
  新完了ログだけを取得し、同じmutation失敗かを確認する。実行は取り消していない。
- 7d0b172の新規2ログで、Swift504件・失敗1（82.550秒）は同じmutation0、
  Python250件・失敗0（38.016秒、予定skip21）と実背景保持／取消probe成功を確認した。
  selectedTargets改訂後8616156のPython117114454633も250件・失敗0（58.398秒、予定skip21）。
  取消probe成功はN21の当該コンパイル不備の比較結果であり、N22のSwift合格やUI品質合格とは分ける。
- 8616156の38942820388は必須2job成功・任意Native未起動skipで全job終端。
  Swift117114454197は17:55:44UTC成功、504件・失敗0（80.784秒）。新規4件と、
  期待値を変えていない元mutation拒否テストが成功した。新規完了ログを一回取得して確認した。
  これはN20／N22の当該コード比較結果で、Apple UI・学校資料・実機の合格ではない。

## N21 新訂正ソースの開発CIが失敗（2026-10-16）

- 98a1dfbの38941628612は全job終端。Python job117110426999が17:43:00UTCにfailure、
  Swift job117110427480が17:44:31にfailure、任意Native PDFは未起動skip。
- import修正後e03069dの38941894390もPython job117111324776が17:44:58にfailure。
  Swiftは進行中。e03069dの全13実行38942018267はDistribution testsが進行中。
- 現段階はmetadata上の失敗で、詳細・同じ原因かは未確認。N20のimportだけが原因と断定しない。
  対処を決める前に事実を記録し、新しく完了した各ログを一回取得して過去詳細・実コードと照合する。
  全実行を取消さず、未実行を成功に数えない。
- 新規3ログを各1回取得。旧SwiftはRecoveryManualAssistance.swift:330のSHA256未解決で停止し、
  N20の静的指摘と一致。Pythonは両ソースとも250件・errors1・予定skip21で、
  test_actual_background_methods_preserve_idle_draft_and_cancel_heavy_workが生成するmain.swift:19で
  previewRasters／manualInitialValuesを見つけられずコンパイル停止した。動作assertへは未到達。
- 旧／現test_manual_input_lifecycle.pyと製品cancel／suspendForInactivity、U68／U72の背景保持詳細を照合した。
  このPythonは製品メソッドをFoundationだけの依存stubへ切り出して実コンパイル・実行するが、
  cancelに追加した2つの保持状態がstubの宣言になかった。製品の背景処理自体を変更した結果ではない。
  stubへ2つの非空状態を追加し、背景保持・明示cancelでの両方の消去を実assertする。
  既存の原入力・画像・レビュー・取消・実callback・保持のassertは省略しない。
  LinuxローカルにはSwiftがなく予定skipとなるため、このコンパイルをローカル成功とは扱わない。
  この診断を先にpushしてからstubを修正し、新規差分レビューの後に新ソースで再検証する。
- e03069dの全13実行38942018267も17:45:53UTCにDistribution testsがfailure、
  残るnative／UI／iPhoneは依存失敗によるskipで全体終端となった。必須合格0として扱う。
  新規のDistributionログを一回取得し、同じstub不備かを照合する。
- Distributionも250件・errors1・予定skip21で、同じ2宣言の不足だった。
  改訂後のLinux manual系37件・失敗0（1.946秒、Swift未設置の予定skip4）、一覧421・空白検査は成功。
  これは失敗したSwift stub実行の合格ではない。新規レビュー18はblockingなし。

## N20 新規SHA256参照のimport不足を静的検出（2026-10-16）

- ソース98a1dfb、開発CI38941628612は進行中で、失敗ログはまだ取得していない。
  主担当がRecoveryManualAssistance.swiftの新規SHA256参照と、先頭のimport Foundationのみを照合した。
  CryptoKit／CryptoのimportとSHA256 alias／再exportは当該ファイル・本体に見つからなかった。
  現時点は静的に判明したコンパイル不備で、CIの終了結果やUI失敗とは記載しない。
- 対処前に事実を記録。既存RecoveryValidator.swiftはcanImportに応じたCryptoKit／Crypto importを使う。
  同じ条件付きimportを新規参照のあるOCR手動補助ファイルだけへ追加する。
  ハッシュの種類・検査・Strict全経路は変えない。文書を先にpushし、新規レビュー16で改訂差分を確認する。
  進行中の旧ソースCIは取消せず完了確認し、新ソースの実行結果と区別する。

## N19 配布前文書の空白検査で末尾空行を検出（2026-10-16、Linux）

- HEAD 4a0294fの未コミット文書追加後、git diff --checkがocr-improvement-log.md:1234と
  verification.md:7588のnew blank line at EOFを報告した。コード・Appleテストの失敗ではない。
- 対処前に事実を記録し、今回の末尾差分と過去の空白検査記録を照合する。
- 今回は文書追記patchの最後に空行を含めたもので、2文書の末尾が改行2個になっていた。
  索引に同じ末尾空行の過去詳細はない。新規追記の最後の空行だけを除き、本文・検査条件は変えない。
  この事実と根拠を文書だけで先にpushし、修正後に作業差分全体と送信コミットを再検査する。

## N18 選択訂正draftのPython既存検査2件が失敗（2026-10-16、Linux）

- HEAD f1475dfの未コミットOCR本文選択訂正。test_manual_*.pyのローカル実行で、
  test_assertions_completion_guard_and_result_bundle_remainと
  test_raster_ab_preserves_old_rendering_and_uses_same_physical_predicateがFAILと表示された。
- この時点ではassertの詳細・新規コードか既存テストの結合条件かは未確認。
  実行を止めず残りの結果を収集する。Swift／UIKitはこの環境に存在せず、Appleでの新訂正実行は未開始。
  直前のf8df970の研究・開発CIは別ソースで全必須jobが成功している。
- 対処を決める前に事実を記録し、当該テストと過去N12／N15／手動訂正UI詳細を照合する。
- 全37件が完了し、失敗2・Swift未設置による予定skip4。詳細は既存の採用1件のsource文字列と、
  fieldsExist呼出し総数4の照合で、それぞれ動的expectedCount化／新選択2回追加により一致しなかった。
  U07の実完了件数必須、元UIの背景／ACK／再起動保存の詳細を照合した。
- 元の「1件訂正→正式保存→再起動確認」を新しい3件の保存だけで置換しない。
  元の保存確認を保持し、その成功後に独立した架空初期状態から新選択3件の別操作段階を追加する。
  これは失敗した操作の再試行ではない。新しいfields存在確認も実際に実行し、総数の登録を更新する。
  全ケース完了・ACK・画像・原文・3上限・再起動保存の条件は維持する。この根拠を先にpushしてから改訂する。

## N17 完了ログ取得のローカル構文解析エラー（2026-10-16）

- ソースf8df970の完了確認を組み立てたJavaScriptが、ログ抜粋用の正規表現で
  Unterminated groupを返して実行前に停止した。GitHub要求やログ取得は開始していない。
  実行中CI・アプリ・Strict・訂正機能の合否とは別の取得準備失敗である。
- 対処を決める前に事実を記録。N12／N15の準備コマンド失敗と今回の正規表現を照合する。
- 今回はregex literal内で括弧の前を二重のbackslashにしたため、括弧が未閉鎖のgroupとして解釈された。
  N12のshell終端衝突やN15の対象path選択とは異なる、抜粋表示だけの構文ミスである。
  定型ログの選別には文字列includesを使い、不要なregexとescapeを除く。
  この事実・照合を文書だけで先にpushし、新規完了ログの要求へ進む。CIの再試行・取消はしない。

## N14追記：別ソースの新規完了ログは取得できた（2026-10-16）

- 8729dcdの新しい完了6件の全範囲ログと両iOS・開発CIログは、同じMCPで各1回取得できた。
  取得後の候補原行・JSON再構成は検証記録へ分離した。
- 旧5605be7の取得できなかったログを再要求したわけではなく、その未確認範囲を埋めていない。
  成功した別要求だけでは切断原因・認証状態・恒常解消は確定しない。有限数値noticeも保持する。

## N16 調査コマンド開始時の実行transport切断（2026-10-16、Linux）

- ソース8729dcd、公開モデルの設定を非公開作業領域へ取得する読取り調査の開始時、
  exec-server transport disconnectedでプロセス生成が拒否された。モデル推論・テストの失敗ではない。
- 直後の最小pwd確認は成功。環境再起動の依頼や実行中Actionsの取消はしていない。
  元コマンドの出力先設定ファイルも未生成で、取得処理の実行は確認できない。
- N14はGitHubログの別MCP／外部転送先での失敗で、今回のプロセス生成拒否とは段階が異なる。
  同一原因とは断定しない。最小ローカル呼出しが回復しているため、事実を先にpushし、別調査コマンドを進める。

## N15 レビュー用差分の再照合コマンドが不一致（2026-10-16、Linux）

- ソース9b1ab623の未コミット研究候補、Actions開始前のローカルpush前検査。
- レビュー済み71,443 bytes／dd1f21f6の差分と、別途path選択で生成した68,993 bytes／8bf4cfc2が
  一致せずassertで停止した。新しいActions・commit・pushは実行していない。
- この時点ではpath選択差かコード変更か未判定。レビュー済み差分の原生成条件と現差分を照合する。
- N12の準備コマンド失敗詳細と現コマンドを照合した。今回は別の選択フィルタが
  tests/test-catalog.jsonを除外していたため、レビュー対象13pathと一致していなかった。
  レビュー原差分に記録された全13pathで読み取り比較すると、71,443 bytes／SHA-256
  dd1f21f6d2c7861119955969407756b8b510315914c175b9c57cb3393f62383aが完全一致した。
  コードの差替えや再試験ではなく、誤った再照合path選択を訂正する。
  この事実と照合を文書だけで先にpushし、その後に同じレビュー済みコードを送る。

## N14 成功した全範囲通常jobのログ転送が切断（2026-10-16）

- ソース5605be7、研究38930731975のf2-timetable SDK26 job117073735530はsuccess完了。
  他の新規完了2件とまとめてログを要求した際、このjobだけMCPがTransport closedを返し、
  decoded contentを取得できなかった。他2件の初回ログは取得・ローカル保存した。
- ログ転送の失敗であり、このjobのActions失敗ではない。原行・件数・サマリーの再計算は未完了。
  対処案を決める前に事実を記録し、転送条件・過去ログ取得の制限を調べる。
  成功済みログの反復取得や推測による記録補完は行っていない。

- 過去N06のCLI外部ログ保存先拒否と今回の応答を照合した。今回は接続ツールのTransport closedで、
  同時要求3件のうち約329万文字・366万文字の2件は取得できた。失敗したjobの応答サイズは不明。
  サイズ上限・一時障害・同時転送のどれかは未確定で、GitHub認証401とは報告されていない。
- 次は未取得のこの完了ログだけを、他の転送がない状態で単独1回要求する。
  同時要求3→1という取得条件の限定比較で、成功済みログは取り直さない。
  再発時は解消扱いにせず、取得できなかった範囲を残す。この根拠を先にpushする。

- 単独の要求でも同じTransport closedで取得できなかった。並行数だけでは解消していない。
  接続ツールのdecoded contentは未取得のままで、成功済みログや品質数値を推測して補わない。
  通常のGitHub CLIによるjob metadata取得は成功しており、認証401は観測していない。
- 同じ接続ツールを繰り返さず、公式RESTのjob単位ダウンロードをCLIで1回だけ試す。
  過去のrun全体ログCLIとは対象endpointが異なるが、外部保存先への拒否が再発する可能性は残る。
  redirect先や認証値を表示せず、失敗時の署名URLを含み得るstderrも公開しない。

- job単位のCLIダウンロードも終了1・受信0bytesで取得できなかった。署名URLを表示しないためstderrは
  公開せず、HTTP statusを抽出できなかった。拒否理由・認証の失効はこの観測では断定しない。
  外部ログ転送経路の同条件再試行は止める。未取得の原ログを取得・再計算済みとは扱わない。

- check-run annotationのCLI要求も401 Bad credentialsだった。一方、GH_TOKENは存在し、
  gh auth statusは終了0・logged-in表示で、保存helperは未設定。既存pushは明示gh helperで成功していた。
  tokenの値は出力していない。metadataの成功と特定APIの401を区別し、過剰監視やrate limitとは断定しない。
- 同じ公開リポジトリのannotationは、認証なしの公式RESTで200取得できた。
  その観測を根拠に、未取得jobログも公開resourceとして認証なしの公式RESTを1回試す。
  redirect先を表示せず、成功時は所有ローカルgzipへ直接streamし、署名URL・認証値は保存しない。
  APIが拒否した場合は非公開の別経路へ回避せず、未取得として残す。

- 認証なしの公式job-log endpointはredirect後の保存先でTunnel connection failed:403 Forbiddenとなった。
  ログ本文は取得していない。署名URLは表示しておらず、この転送先への再試行・別経路回避は行わない。
  公開annotation／metadataは取得できるため、今後の研究には本文を含まない有限の数値レシートも
  noticeへ出す。原全文ログの再計算の代用にはせず、CI内で検査した結果とローカル原行照合を区別する。

## N13 全範囲比較の試験f1が完了失敗（2026-10-16、SDK26）

- ソース5605be7cc8b19a342020d5cb340e2d4073005cf5、研究38930731975・試行1、
  Complete source f1-exam SDK26 job117073735909は16:17:14〜16:24:13UTCにfailureで完了した。
  16:25:38UTCの開始時刻から算出したまとめ確認で観測した。
- 同じ研究のf2通常は成功、他4jobは実行中。小規模研究38930731925と開発CIは成功しているが、
  全範囲6件の完了・品質合格とは別である。実行は取消していない。
- 失敗段階・原因はまだ未確認。対処案を選ぶ前に事実を記録し、完了ログと過去の詳細・コードを照合する。
  アプリ本体・Strictと全経路は未変更で、実資料は取得していない。

- 完了ログでは、元Swift取得と両描画のNNは完了していた。current2048はV6実1339回・ASCII0回、
  source2x4096はV6実1649回・ASCII17回。後段比較のclass_assignmentが、期待クラス名のbboxを
  一意に包含する実取得セルがないため例外停止した。どのクラス・取得セルが原因かはログだけで未確定。
- current2048のクラス列候補はmissingOrAmbiguousTopLeftClassLabel、source2x4096には17実セルの列があった。
  小規模bc52f56の同じclass_assignmentのguardと照合し、条件を変更していないことを確認した。
  N11のnative2048上限例外・N10の原JSON行破損とは別の、後段の物理所属検査である。
- 取得geometryはclass検査後にprintするため、この例外では実セル一覧が原ログへ残らない。
  未観測のセルを推測補完せず、現行2048でクラス名を測定できたとは扱わない。
  4096の残る全本文／class指標も、このjobの比較receiptがないため合格とは数えない。
- 対象コードの包含guard・原セル・score・既定Strictは緩めない。次の比較条件は、以前v3で実測改善した
  本来の候補入力source2x4096だけに固定し、全17クラス・5日・全時限の要求を保持する別実行とする。
  元2048 Visionは元座標の本文baselineとして保持し、2048 V6の失敗を空や成功へ変換しない。
  当初の2条件比較の失敗履歴も保持する。別の対象入力を測るもので、当初実行の解消や未使用評価とは呼ばない。
  新しい取得記録は既存比較器へ入れる前に実geometryを出力し、失敗時もセル一覧を記録できるようにする。
  これらの事実・照合・次条件の根拠を先にpushしてから実行する。

- 16:33UTCの次の予定確認では、同じ研究のf1-return job117073735933（16:30:32UTC）と
  f2-return job117073736067（16:28:55UTC）もfailure完了した。f1通常とf2試験は実行中。
  この2失敗の段階・原因はまだ未確認で、f1試験と同一原因とは断定しない。全実行を取消していない。

- 16:41UTCの次の予定確認で全6jobが完了した。f1通常job117073736688はsuccess（16:35:29UTC）、
  f2試験job117073737099はfailure（16:33:56UTC）。全体は通常2成功・試験／返却4失敗である。
  f2試験の失敗段階はこの確認時点では未確認。成功・未実行で失敗を相殺せず、取消はしていない。

- 公開annotationでは、残る試験／返却3jobも同じcompare.py:82の
  Assertion class name has no unique actual physical cellを報告した。
  各jobの全文原行・実呼出し数・どの描画条件かはN14により未取得で、f1試験の数値を流用しない。
  通常2jobのsuccessも品質数値は未取得である。全6job・同一ソースの完了確認と、原行再計算は区別する。

## N12 全範囲比較の準備コマンドが構文エラーで停止（2026-10-16、Linuxローカル）

- HEAD bc52f56d26d2399305950f88714229815513d886、全範囲比較の未コミット準備。
  一覧登録・run.shへprotocol出力追加・README作成をまとめたローカルshell呼出が失敗した。
- Pythonはunterminated triple-quoted string literal、shellはunexpected EOFを報告した。
  後続の生成済みコードを検査する処理は未実行で、Apple／NN／精度比較には到達していない。
  既に完了済みの独立生成3テスト13.027秒・失敗0とは別の準備エラーである。
- 対処案を選ぶ前に事実を記録。実際に変更されたファイルと過去の索引・該当コードを照合する。
  実行中のbc52f56のActionsはこの未コミット準備と別で、取消していない。本体・Strictは未変更。

- 準備コマンドと現ファイルを照合すると、外側のshell here-documentと、そのPython文字列内の
  追加予定here-documentがともにPYを終端としていた。内側の終端が外側を先に閉じ、
  Pythonを途中で切った後、残りをshellが実行しようとした。テストや製品コードの不合格ではない。
- 同種の構文エラーを索引で検索したが過去項目は見つからない。N05の宣言登録不一致とは段階・原因が異なる。
  現在の一覧には新groupが追加されず、run.shのprotocol markerも未追加、READMEも未作成だった。
  当該Pythonは構文解析段階で失敗しており、その中の書込みは開始していない。
- 次は差分適用ツールでファイル編集を分離し、shell文字列へ入れ子の終端を埋め込まない。
  この事実・照合・対処の根拠を先にpushしてから、未実行の一覧・shell構文・対象検証へ進む。
  完全なApple実行や一般的な再発防止を成功済みとは扱わない。

## N11 全文書の2描画条件比較が完了失敗（2026-10-16、SDK26）

- ソース188cc91def401eea4e7b00d8cc5f95719d2c6c46、研究38921530894・試行1、
  SDK26 job117042389792は15:13:42UTCにfailureで完了。15:16UTCのまとめ確認で観測した。
- 同じソースの開発CIは必須2job成功。研究の失敗段階と原因はまだ未確認で、
  2条件の描画完了・原ログ完全性・精度改善を成功とは扱わない。
- 対処案を選ぶ前に事実を記録。実行は取消していない。本体・Strict・経路は未変更。

- 完了ログでは、Swiftテスト開始後35.188秒で元のRecoveryVisionCapture.swift:14が
  `RecoveryOCRAcquisitionFailure.limit`を投げた。Swiftコンパイルは成功しており、
  2条件の取得完了marker・NN開始・比較receiptには到達していない。
- 該当の元コードとa4a853eを照合すると、Vision captureとacquisitionのwidth／height上限は2048。
  v2で追加した通常3440pxはそのまま渡せない。RasterGridの4096上限とは別の契約である。
  N06のMac27 framework例外・N07のSimulator照会停止とは条件・段階が異なる。
- 次の比較ではVisionの入力と元captureを現行2048のまま保持する。4096候補はV6用の
  原画素・罫線・領域取得だけを測り、Vision未実行を空出力や成功へ変換しない。
  元Visionと候補V6は各自の原座標・物理セルで割当を検査した後、同じPDFの同じ本文targetで比較する。
  同じ画素の認識器比較とは呼ばず、V6の2048／4096差を別に再集計する。
  元の2048上限・全墨・所有・score・Strictの条件は緩めない。再試行前に事実と根拠をpushする。

- 7c27f70／研究38923287440・SDK26 job117048353703は成功。Visionは元2048の6回だけ、
  4096候補に対する未実行は明示した。V6の2条件・各444本文値を完了し、
  元2048上限は維持している。4096のVisionが実行可能になったという解消ではない。

## N10 全文書比較の取得済みログ再集計でJSON行の復元が停止（2026-10-16、ローカル）

- ソースa4a853e、研究38919732549・試行1、SDK26 job117036235118は成功完了。
  比較器は6資料・444本文値・実ONNX724回／Vision6回のreceiptを出した。
- 完了ログを1回取得・ローカル保存した後、原記録の独立再集計スクリプトが
  JSONDecodeError（line1 column38）で停止した。どの原記録・転送・行境界に
  原因があるかは未確定。Actions成功とローカル再集計の失敗を区別する。
- 対処案を選ぶ前に事実を記録。文字／原観測枠／物理所属を分けた精度の結論と、
  ログから全444値を独立再計算できたとの主張はまだ行わない。

- 原ログを選別せず確認すると、FIELD444／GEOMETRY6／SUMMARY6／RECOGNITION724／RECEIPT1は
  すべてJSONとして読み取れた。Vision原記録は340行が読めたが2行は途中接合され、
  f2-timetableの途中からf2-examへつながる箇所と、XCTest終了文が混ざる箇所を確認した。
  原ファイルのnative captureと比較器の集計そのものが破損した証拠ではない。
- 当該Swiftのprint出力とXCTestの並行したstdout／stderrをteeするコード、
  過去N09の別実行の画像SHA問題と、以前のログ分割再組立記録を照合した。
  今回の欠けたVision行を推測補完せず、全行復元やVision全原記録の独立再計算は主張しない。
- 次の候補はSwiftテスト中の大量原記録printをやめ、終了後に別Pythonプロセスから
  保存済みの元captureを一度だけ出力する。観測枠・文字・confidence・元順位はそのまま、
  読めた件数と全ID／nativeOrderも検査する。元認識や品質条件は変更しない。
  再試行前にこの事実・根拠をpushし、まだ解消済みとはしない。

- 7c27f70の出力分離条件ではVision391行・6資料の全nativeOrderが各receiptの行数と一致し、
  全888本文記録・1461V6原記録・12サマリーもJSONとして再計算できた。
  この実行では原記録接合は再発しなかった。欠けたa4a853eの原行を補完したことにはしない。

## N09 別研究実行間の元PNGハッシュ一致が未成立（2026-10-16、ローカル再照合）

- iOS26実推論40e1aab／job117005147322の保存済み288記録と、dff1e9dの
  Mac認識器比較job116993096105の保存済みPaddleV6記録を、ローカルPythonで照合した。
- 最初の対象で入力FP32のSHA一致検査は通ったが、元PNGのSHA一致検査でassert失敗した。
  全288件の元画像一致や、先の正解との結合はこの検査では確認できていない。
- 対処を選ぶ前に事実を記録。iOS内の288回のnative／参照の全確率一致は別の同実行内の結果であり、
  この別実行間の画像同一性失敗で成功へ付け替えない。元画像を再取得する検証は開始していない。

- 事実push後に全保存記録を集計すると、ID・frame対応288件、入力テンソルSHA一致288件、
  元PNG SHA一致0件、認識文字一致288件だった。PNGの差だけから元画素の差・圧縮だけの差を断定しない。
  原画素の同一性を示す追加記録はないため、別実行を結合した新しい精度主張は行わず、再推論もしない。

## N08 清掃回帰テストのmock呼出し形状期待が不一致（2026-10-16、ローカル）

- 3839b98を基準にした未コミット差分、Linux／Python3.12、対象10件中1失敗。
  test_shutdown_nonzero_does_not_replace_successful_owned_deleteの87行でassertEqualが失敗した。
- 観測：shutdown非ゼロ後にdeleteは実際に呼ばれた。mockのargsはコマンドtupleを
  第1引数に持つ形で、テストはその外側のtupleがない形を期待していた。
  Apple実行・製品・モデルの失敗ではない。対処を決める前に記録した。

- N05のテスト宣言問題と今回のassert失敗を分け、compare.commandのcheck_output(args, ...)と
  新規mockのcall_args_listを照合した。delete実行の期待内容は維持し、検査対象をargs[0]へ直す。
  先にこの事実・根拠をpushし、その後に再検査する。期限・認識・清掃条件は変更しない。

## N07 iOS27 CPU照合がSimulator状態照会で時間切れ（2026-10-16）

- 新しい限定比較782ad0d／38912610294のiOS27 job117011938274も14:09:13UTCにfailureで完了。
  予定所要時間を超えた14:12UTCの最初の確認で観測した。失敗段階はまだ未確定で対処前に追記した。
  同じソースのiOS26 job117011938993は実行中、取消していない。

- ソース40e1aabe68cafd2419cf52d0c707a9546e5080f5、実行38910595845・試行1。
  job117005147744は13:55:47UTCにfailureで完了。予定確認13:58UTCで初めて観測した。
- 実iPhone SDK27／Simulator SDK27のC++リンクは成功。完全架空PDFの6ページ／144領域を描画した。
  `simctl bootstatus -b`後の`simctl list devices -j`が120秒で時間切れになった。
  native推論開始・ORT_IOS_READY・確率照合の完了記録はなく、iOS27のモデル実行成功に数えない。
- 清掃の所有Simulator shutdownも60秒で時間切れ。finallyのdeleteはコード上で実行されるが、
  完了ログにdeleteの出力がないため、当該UDIDの消去完了をログだけから独立確認できない。
- 対処を選ぶ前に事実を記録。原因は未確定で、N06のMac Vision認識例外とは失敗段階が異なる。
  同実行のiOS26 job117005147322は成功。別OSの成功でiOS27の失敗を上書きしない。
  本体・Strict・その経路は不変、公開版も変更していない。

- 照合：U33／U34／U35とverificationのDevice Hub準備・U65詳細、
  現行tools/test-app-ui.shのboot_simulatorを読んだ。通知未返答・アプリlaunch失敗と
  今回のsimctl状態照会停止は異なる。画面起動は通知問題の解消を証明していない。
  一方、既存の成功したUI実行は選択Xcodeの実在フロントエンドを起動しているが、今回のCLI研究は開いていない。
- 次の限定比較：研究だけに同じ選択XcodeのSimulator／Device Hub起動を追加し、
  元のbootstatus・実UDIDのBooted照合・120秒・全288確率検査を維持する。
  各simctl段階・実所要時間・終了状態と所有device消去結果を記録する。
  OS停止の原因がフロントエンド不在だったとの断定ではなく、起動条件の差を一つ比較する。
  再起動・再実行による救済や期限延長はしない。製品の経路は変えない。

- 782ad0dの完了ログ：Device Hub起動・bootstatus100.073秒・所有deviceの画面URL起動は成功した。
  続く全device一覧が124.294秒で時間切れ。所有UDIDのshutdown14.453秒・delete19.761秒は成功した。
  フロントエンド起動で一覧停止は解消せず、元の条件を繰り返さない。
- 次の比較候補：全deviceの一覧ではなく、所有UDIDへSDKでビルドした専用Swift実行器を一回spawnし、
  その実プロセスのSimulator環境UDIDとProcessInfoのOS版を独立に照合する。
  元のbootstatusと360秒、実行上限120秒、端末ID／OSの一致、全288確率検査は必須のまま。
  実端末内の応答・一致がなければ失敗とする。一覧timeoutを握り潰して先へ進む経路は作らない。
  特定UDIDの清掃が応答したという今回の差に基づく対照で、OS停止の下位原因の確定ではない。

- v2の3c3bcba／38914275770では、iOS26／27の両方で所有UDID内の実Swiftプロセスによる
  ID・OS・Simulator条件・PID照合、292変換の全bytes一致、288回の全確率一致、清掃が成功した。
  全device一覧を使わない別の起動証明の成功であり、N07の全device APIの恒常的解消とはしない。
  旧782ad0dのiOS26 job117011938993も成功で完了し、同実行全体のiOS27失敗は維持する。

## N06 Apple OCR認識器比較のSDK27が完了失敗（2026-10-16）

- 限定診断ソース65fafd2、実行38908560099も完了failure。
  2026-10-16T13:32:58UTCの最初の予定確認で観測した。
  この時点では対照中の認識例外か準備／ビルドかをまだ確定せず、対処前に追記した。
  完了原ログ確認後、コンパイル成功・全12呼出し／全12エラーと確定した。
  元thumbnailは既に8bit／32bpp、PNG往復・DeviceRGBへのRGBA8コピーでも同じ元画素SHAで、
  別の512×160 CoreText対照も含めてDocumentsはunknownError、accurate Textは
  `e5rt_e5_compiler_compile call failed`（11）。
  特定PDFの形式だけでは説明できず、Mac27の認識Runtime実行失敗として保持する。
  iPhoneにも同じ失敗があるとは断定せず、同条件での再試行・OS再起動依頼は行わない。

- ソースdff1e9d8b618099304c544ee42ec0e7c01a5cb4a、研究実行38907039537・試行1、
  SDK27 job116993096462は13:21:06UTCにfailureで完了した。
  SDK26は最初の完了確認時点で実行中で、取消していない。
  後でSDK26 jobは13:25:53UTCに成功完了し、SDK27は失敗のままであることを確認した。
- 完了ログのCLI取得は外部ログ保存先へのアクセス拒否で失敗した。
  この段階で製品・OCR・ビルド・依存のいずれが原因かは未確定。次の検証は開始していない。
  その後、接続ツールで完了原ログを取得。macOS27.0.1／Xcode27.0（27A266a）で新規9件、
  依存・字体・固定モデル取得とSwift実行ファイルのコンパイルを通過し、
  `vision extract`が`TextRecognition.CRImageReaderError.unknownError`を返して停止した。
  各ページの完了記録は出力されておらず、完了ページ・実Vision呼出し数は確定しない。
  ONNX認識段階は未到達。失敗条件を同じまま再実行せず、入力画像の形式と独立した対照を先に診断する。
- 対処前に事実を記録し、接続ツールで新しい完了ログを取得してから、過去の記録とコードを照合する。
  研究以外のアプリ本体・Strict・経路は不変で、公開版も変更していない。

## N05 OCR比較用Pythonテストの宣言名が一覧に登録されない（2026-10-16、ローカル）

- 基準8bf6c8aからの未コミット研究差分、Linux／Python3.12。
  `tools/test_catalog.py write`と`check --base 8bf6c8a45c6b41b3e78ae9e5615424fd827d4cfc`が
  `No test declarations: tests/test_ocr_windows_transfer.py`で失敗した。
- 続けて実行された対象unittestは9件・失敗0だが、一覧生成／検査の成功には数えない。
  Apple SDK・Vision・ONNXの実比較はまだ実行していない。
- 研究追加だけでアプリ・Strict・呼び出し経路に変更はない。
  対処を選ぶ前に観測を記録した。その後、一覧の`cases`と既存Pythonテストを照合し、
  Pythonは`test_`開始の宣言だけを登録する一方、新規9ケースがSwift式の`testCamelCase`だったと確認した。
  新規テスト名だけを既存Pythonの規約へ揃える。期待値・本文・検査器は変更しない。
  修正記録push後、一覧write／checkと新規9件が成功した。既存を含むPython全199件も成功（予定skip9）。
  Apple上の実認識や製品精度の合格には数えない。

## U77 通知設定caseのタブ操作が選択へ反映されない（旧全体400、iOS26 B）

- 対象：fd6e42cc254a6c1e2e7ed134b1a425d37b3c5919、Actions38695099094・試行1、job116306569871。
- 環境：Xcode27.0・Runtime26.5、通知用の別RunnerのtestNotificationControlsAndAppearance。
- 観測：ApplicationChecks+Navigation.swift:43で「Native tab tap did not select its current control」。
  1件・1失敗（88.787秒）、この区間全体127.9秒。前の通常区間・26の予定VoiceOver skipは完了している。
- 次の対処を決める前に記録。400は既にU76で公開不可。別ソースの401は実行中で、失敗を成功へ置き換えない。
- U63／U75の全文・詳細記録と9ffdf0eのtab helperを照合した。現行tabの本文は9ffdf0eと全bytes一致。
  400の前区間でも同じ設定icon枠への接触は成功している。今回は通知用の新所有Simulatorの最初の設定tabで、
  アイコン一回0.1秒接触後も45秒内に選択されない。原因・配送先は未特定。
  既に開始済み401の同経路を確認し、根拠なくSDK・押す位置・接触時間・期限・期待を変更しない。
- 全体401・試行1の同caseは202.613秒・失敗0で成功した。tab helper・SDK・実操作は変更していない。
  この実行での非再発であり、入力配送の下位原因・恒常的安定性の証明ではない。

## U76 手動訂正3項目の実行中にSpringBoardがクラッシュ（全体400、iOS27）

- 対象：fd6e42cc254a6c1e2e7ed134b1a425d37b3c5919、Actions38695099094・試行1、job116290206394。
- 環境：Xcode27.0・iOS27 Simulator、testThreeFieldsRequireEachAcknowledgementAndFourRefuses。
- 観測：buildは成功。07:11:09 UTCにXCTestが「Critical process SpringBoard crashed in (null)」を報告し、
  1件・1失敗（400.883秒）、処理全体469.2秒で終了した。ビルド失敗ではない。
- 対処案・次の実行を決める前に記録。クラッシュの下位原因・その時点のUI操作は未特定。
  全体400は公開不可。残りのジョブを取り消さず、新しい完了ログを確認する。
- 詳細：最初のlaunchのautomation session準備で発生し、fixture-ready・3項目入力前。
  診断collectorはmatchingTextReports0、crashCause unassessedで、SpringBoardのクラッシュ原因は分からない。
- 照合：U65のNSPOSIX launch失敗とU51の同caseのjob期限超過、および各詳細記録・当時の条件を読んだ。
  今回は別のOSプロセスのクラッシュであり、同じ原因とは断定しない。
  成功した399の同case（474.543秒）から400まで、製品・手動case・実行scriptの差分は0。
  400の差分は通常UIのhelper公開範囲1行だけで、手動プロジェクトはそのファイルをコンパイルしない。
- 次の評価：この記録と文書更新をmainへ反映するときに、新規Runner・所有Simulatorで全必須検査を行う。
  製品修正の根拠はなく、SDK・操作・待機・期待値・公開条件は変更しない。
  400の失敗を上書きせず、別実行・同一ソース／試行の全13成功を要求する。
  部分的な再実行の成功を旧試行の成功と組み合わせて公開せず、旧400も取消しない。
- 新規全体401・試行1の同caseは381.511秒・失敗0で成功した。
  SDK・手動case・製品・待機条件を変更せず実行した結果であり、SpringBoardの原因・恒常的解消の証明ではない。

## N04 UI readiness追加のSwiftアクセス制御エラー（全体399）

- 対象：52a945e1dfb905efcd3e56dc79864dd48f9a7fa3、Actions38694211705・試行1、job116287218592。
- SDK／OS：Xcode27.0、iOS27 UI Bのビルド。ApplicationChecks+Timetable.swift:140。
- 観測：bodyViewportが別ファイルのprivate宣言であり呼び出せず、UIビルドが失敗した（55.0秒）。
  XCTest未開始。週範囲操作候補の実行評価にも未到達で、398の操作失敗とは区別する。
- 対処を決める前に記録。全体399は公開不可、残りを取消さず確認する。
- N03のコンパイル失敗記録と、Navigationの実宣言・既存contentViewport／footer除外処理を照合した。
  テストmodule内のbodyViewportをinternalへ変え、元の包含・footer除外条件をそのまま共有する。
  呼出側を弱い範囲判定へ置き換えず、待機・操作・期待を変えない。実行評価は次のCIで確認する。
- 同じ399のUI A job116287218594も同じアクセス制御でビルド失敗（76.5秒）、XCTest未開始。

## 2026-10-15 全体398：週範囲ボタンがhittableでない

- 対象：7f340c8c34eebbd627c887ebdad40785f0e23def、Actions38686133870・試行1、job116270999395。
- OS／SDK：iOS26.5 Simulator、Xcode27.0。通常UI BのtestHomeTimetableAndWeekCalendar。
- 観測：ApplicationChecks+Timetable.swift:134で週範囲Buttonのhittable検査が失敗。
  表示文字は「10月12日から10月18日」、frameは{{114.3,332.0},{164.3,32.0}}。
  XCTestは6件中1失敗、730.539秒。テスト開始前の失敗ではない。
- 原因未確定。対処案・次の実行を決める前に記録した。
  全体398を成功・配布可能と扱わず、残るジョブは取消さず確認する。
- 照合：U65の同caseは起動前process handle失敗、今回は起動・詳細表示・dismissジェスチャ後の段階。
  U73のindexed-query修正とea8401d時点のNavigation／Recovery helperを全文で比較した。
  今回のcalendarはfirstMatchのままで、dismissLessonはdrag後のsheet消失を確認していない。
  398の原ログにはXCTest標準tapの内部scroll／3回再試行とhit point {-1,-1}がある。
  同条件の397は成功しており、製品のカレンダーやdismissの原因解明とは断定しない。
- 候補：元の5秒の存在待機を、詳細sheetの消失・一意・表示包含・enabled・hittableの待機へ強化する。
  現在のindexed要素を取り、実frame中心へ一回だけ物理tapする。押し直し・固定画面座標・期限延長はしない。
  元の週選択表示・キャンセル・前後週操作の期待を維持する。改善は未確認、次の両OSで評価する。

## N03 追加した復旧テストのコンパイルエラー（2026-10-15）

- 対象：f188972ベース作業差分の2回目、Debian13/Swift6.1.2/Linux、SQLite3.53.4。
- 観測：製品moduleのビルド後、追加したRecoveryFunctionalCoverageTestsのfunctionalPreview呼出しにtry不足。
  RecoveryRecertificationTestsはTimetableLessonNames.subject（let）を直接代入していた。
  テスト実行前に終了1、219.8秒。SQLite異常終了の再評価には未到達。
- 修正：既存helperのthrowsと名称型の不変性を読み、try追加と名称値全体の置換に限定する。
  期待値・採用条件を変えず、改変拒否のassertを維持する。3回目は全497件・失敗0。
- 対処前に記録。N01の固定版期待の問題とN02のDB実行時Signal11とは別のコンパイル問題。

## N02 ローカルSQLite検査でSignal11（2026-10-15）

- 対象：f188972ベースの未コミット作業差分、Debian13/x86_64、公式Swift6.1.2、Linux。
- 実行：初回tools/test-parsing.sh。古いtest版期待更新前のsnapshotでビルド成功。
- 観測：LocalDatabaseTests.testConstraintsRejectWrongKindMutationAndReferencedOriginalDeletion開始直後にSignal11。
  Swiftのbacktraceは取得不能。プロセス終了まで234.9秒。全体成功として扱わない。
- SQLite開発headerは3.53.4、リンク先symlinkの本体は未設置、システムは別版。原因は未確定。
- 実測：システムSQLite3.46.1と、導入したheader／static library3.53.4が異なる。
  symlink先に対応する3.53.4の共有libraryを同じ配布元から導入し、次の検査は同じ版へ揃える。
  3回目は対象DB検査を含む全497件・失敗0。環境の版整合を確認した結果であり、製品の解消とは扱わない。
- 対処前に記録。既存N01のParser固定期待値失敗とは異なり、XCTestのassert到達前の異常終了。

## N01 非UI：特殊Parser版の固定期待値が旧29（2026-10-14、ローカルSwift）

- 2558df1からの実装中差分、Swift6.1.2/Linux、492件中4失敗。
  RecoveryTestsのSpecialScopeVersion／UnusedFontReaderVersion／ParallelAlignmentVersion／
  OCRCoverageVersionで、設定30と期待29が不一致。UI・端末・モデルの失敗ではない。
- 同種の版更新記録（verificationの2026-10-13）とソースを比較。
  返却ラベルの変更を同一SHAでも反映する版更新であり、旧解析29の再解析を追加で検査する。
  元の旧成功／失敗の再解析と現行版での無限再解析拒否は保持する。
- 再実行結果は[検証記録](verification.md)へ残す。最初の失敗を成功へ置き換えない。

## 2026-10-13 全体392での候補確認範囲

source8219fa5・38408608816・試行1の全13と公開が成功。
U71の手動26・3項目は543.430秒で全個別ACK／4項目拒否が成立した。
U72の単項目は27で937.006秒、26で794.103秒、背景復帰・再編集・保存・再起動まで成立。
U73の元初期設定caseも両OSで成功した。U74は設定を別Runnerへ分け、
27で229.649秒、26で208.900秒、元の4回Switch／UIと保存／再起動保持が成立。
別RunnerのVoiceOver27は56.351秒・実18移動／元の3項目が成立した。
U75は通知行の操作を変えず、26 Aの元通知case82.454秒で成立した。
一回の全体通過を、下位原因・恒常的解消・旧条件の成功へ一般化しない。
旧391も取消せず全結果を確認し、U74とU75の失敗・公開skipを残した。
詳細：[公開と検証](verification.md)。実資料の復旧とモデル品質は別の未評価項目。

## U75 通知行の実tap後に詳細画面へ移らない（旧全体391、iOS26 A）

- 対象：ea8401d・38400839141・試行1、job115332787120、配布SDK27.0／Runtime26.5。
  testChangedDataProducesOneLocalNotification、ApplicationChecks.swift:94。
- 観測：通常14件は1573.521秒・失敗0。別Runner／新所有Simulatorの通知caseは
  screen("通知")の10秒nav待機でXCTAssertTrue失敗。1件・失敗1・109.373秒。
  初回fixture-readyと設定tabへの遷移は成立。実通知行labelへの一回tap後も設定画面。
  通知許可・配信には未到達。初報のfixture-ready失敗という推測を原ログで訂正した。
- 状態：旧391はBのU74に加えてAのこの失敗でも公開不可、取消しなしで終端まで確認。
  原ログとU30／U63の入力未反映、U06の事前照会、旧Navigation helperを比較する。
  U40／U41／U49／U59／U65の起動失敗と、U32／U35の許可未返答とは段階が異なる。
  既に開始済み392の同じA経路の結果を確認し、根拠なく起動・SDK・待機を変更しない。

## U74 AI／OCR確認未反映とVoiceOver命令失敗の再発（全体391、iOS27 B）

- 対象：ea8401d・38400839141・試行1、job115308282486、SDK／Runtime27.0。
- 観測：testSettingsAccountDataAndFileDetailsのSettings.swift:36で
  Physical AI/OCR switch tap did not update both UI and stored permission。
  testVoiceOverReadsTimetableCardでAXVoiceOverAutomationErrorDomain Code3、
  Failed to send moveForward command。元11件・失敗2（予期しない失敗1）・1234.173秒。
- 全文照合：初回0→1→0→1は成立。再起動後pid41698の4回目1→0だけ、
  同じ子Switch相対点へ0.1秒接触一回後もUI／保存値が1。U43／U52／U55の段階が再発。
  heading接触と45秒の発話観測0の後、最初のmoveForwardが失敗、完了move0。
  U66と同じ接触方式。新しい原因や失敗済み条件との違いを捏造しない。
  後処理のAXサービスとsetterログはtimeoutで取得不能。不在の証拠ではない。
  391は公開不可。残りを取消さず確認し、待機延長・注入・条件緩和・除外を行わない。

## U73 初期設定caseの可視領域照会がsnapshot timeout（全体390、iOS27 B）

- 対象：ca32c41・38394647214・試行1、job115287057618、SDK／Runtime27.0。
  testSetupCanBeSkippedAndOffersAllFiles、ApplicationChecks+Navigation.swift:139。
- 観測：Failed to get matching snapshot: Timed out while evaluating UI query。
  元11ケースは失敗1・1466.729秒。case本体254.639秒、対応26 Bは依存でskip。
  4資料の見出し取得後、学校行事Buttonの探索でscrollした後のtarget.frameが停止。
  学校行事へ移動する実tap前。footerや既取得のframe省略で解決したとは扱わない。
- 状態：具体操作・行139の値取得・旧関連失敗を原ログとコードで照合してから判断する。
  390は公開不可。条件の緩和・ケース除外・再試行をせず、残りを取消さず確認する。
- 候補：同じlabel-prefix queryの最初の要素をindexed queryで取得する一行。
  frame・全包含・hittable・6回scroll・5秒存在待機・一回tapの条件は維持。
  既存sectionの方式と比較し、製品／SDKは追加変更しない。
  391の元ケースは88.710秒で成功した。一回の通過で恒常的解消を証明しない。

## U72 単項目訂正のUI照会がsnapshot timeout（全体389、iOS27）

- 対象：1b368f5・38390616754・試行1、job115273821054、SDK／Runtime27.0。
  testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground、504.261秒。
- 観測：ManualAssistanceChecks+Input.swift:96でTimed out while evaluating UI query。
  ケース1件・失敗1。最初のACK・実背景3／復帰4・同じprocessは成立。
  復帰後の再入力で、完了ボタンの存在・hittable照会後にframe再照会が停止。
  完了tapと二度目のACKは未実行。frame値の取得成功は未記録。
- 状態：先に観測を保存し、原ログ全文・行96のコード・過去の同じ照会失敗を
  読んでから対処を決める。待機延長・ケース省略・再試行はしない。
  389は必須チェック未達で公開不可。残りを取消さず確認する。
- 候補：存在待機後、現在の実Button配列の一意な要素を使う。
  元のframe包含・enabled・hittableを省かず、45秒・一回tap・入力全文／保存を維持。
  U11等の実要素方式と比較し、取得不能は失敗のまま。効果／原因は未確認。

## U71 3項目訂正の確認SwitchがONにならない（全体388、iOS26）

- 対象：f6e13a6・38382434192・試行1、job115263683048、Xcode26.6の手動訂正26。
  testThreeFieldsRequireEachAcknowledgementAndFourRefuses、321.968秒。
- 観測：第2項目の科目Switchを一回tap後、45秒のvalue1待機が期限切れ。
  第1項目の教室は確認ON。第2項目は入力全文の一致とkeyboard非表示、子Switchの
  可視・一意性・包含・hittableを確認し、実frame中心をtapしたが、valueは0のまま。
  保存診断も科目ack=falseで、科目のack Bindingイベントはない。ケース1件・失敗1。
  Input.swift:40はacknowledge内の待機であり、初報のforegroundという見出しを訂正した。
- 状態：先に観測を保存。発生した具体操作・前後のstate・下位原因は原ログ全文と
  既往／当時のコードを照合してから判断する。待機延長・期待値変更・自動再試行はしない。
  388の必須チェックは未達で公開不可。残りのActionsは取消さず確認する。
- 候補：同じ包含済みの実中心を、子Switch相対の一回0.1秒接触で操作する。
  U19の画面座標方式に戻さず、U64の実コードと比較。中心・45秒・value1・
  保存・個別確認の元条件は維持し、製品／SDKには差分を追加しない。効果は未評価。

# UIテストの失敗索引

## N165 状態追従の正式CIで通常iOS27 Bがfailure終端（2026-11-06）

予定01:25 UTCの一括照会でsource77d57a5042dc1607a85170527db6a3c50f532600/run42136180150/attempt1、job127625751340の通常iOS27 Bが00:29:39Z開始・00:53:58Z failure終端と観測した。指定Xcode/SDK27.1/Runtime27.0、具体case/失敗stage/原因は完了log未読で未確定。対処案選択前の事実として記録する。Distribution/Native700/通常27 A/訂正27元四件は成功したが、正式全15は未成立。通常26 B/訂正26/公開は依存skip、通常26 Aも別にfailureとなり全15表示job終端・取消しなし・公開未実施。新7実job完了logだけ一度取得し、取得済み2log/過去の終端runは再照会しない。終端artifactは一度確認する。

## N166 同じ正式CIの通常iOS26 Aもfailure終端（2026-11-06）

同じsource77d57a5/run42136180150/attempt1、job127641280412は01:02:34Z開始・01:15:40Zにfailure。指定Xcode/SDK27.1/Runtime26.5、具体case/失敗stage/原因は完了log未読で未確定として対処前に記録する。全job終端・公開依存skip・取消しなし。これから新logと過去の詳細、当時/現在コードを照合し、記録と修正根拠をpushする前に再試行しない。

## U69 コード欄の標準AX結合ラベルと旧期待の不一致（全体386、iOS27 A）

- 対象：7211993・38372705306・試行1、job115213800552、ApplicationChecks+Settings.swift:212。
  testFileFailuresKeepResultsAndStayInTheirOwnDetails、80.436秒。
- 観測：実コード欄のlabelは「エラーコード、P12 / R126（1ページ目）」で、値だけの期待と不一致。
  標準LabeledContentのラベルと値がAX上で結合されている。資料本文や内部確認箇所の混入ではない。
- 状態：まず観測を保存し、製品表示と既存AX契約を照合する。UIの待機・操作・SDKを変えない。
  同じjobのRecoveryClosingも失敗しており、全文を別途確認する。残りは取消さない。
- 既に開始済み387（71cdb45・job115220966638）も同じ未修正期待で不一致、96.605秒。
  14ケースの他13件は成功し、U70は同じhelperのまま成功した。次は固定差分のAX期待一行だけを検証する。

## U70 Settingsの「時間割ファイル」存在再照会が停止（全体386、iOS27 A）

- 対象：7211993・38372705306・試行1、job115213800552、Navigation.swift:58。
  testRecoveryClosingKeepsFormalAndModelManagementIsAccessible、207.575秒。
- 観測：一回の設定tab操作、selectedと設定navの成立後、tap helperの待機でAX snapshot timeout。
  09:21:43にボタンを検索、09:21:43〜49にwaitForExistence、retry1／2を経て09:24:41に停止。
  詳細画面／復旧シートの操作には未到達。元14件の全体は1703.117秒・失敗2。
- 比較：U05の存在・画面外探索とU17／U62の再照会を読むが、今回は必須ボタンの取得である。
  戻り値・実frameは記録されておらず、設定変更や特定の余白を原因と断定しない。
  この箇所は今回の製品／helper差分ゼロ。既に開始済み387の同ケースを確認し、根拠なく操作を変えない。
- 根拠：[386通常27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38372705306/job/115213800552)。
- 比較実測：既に開始済み387の同じケースはhelper／SDK／操作を変更せず成功。
  一回の比較であり、AX根本原因や恒常的解消は未証明。必須ボタンや後続の検証を省いていない。

UIの変更・実行前に、ケース名・ファイル名・操作・エラー・OSで検索する。
各項目は観測、試した変更、確認範囲だけを短く記す。詳細はリンク先を読む。
新しい失敗は次の試行前に追記する。未確認の原因を確定扱いしない。

全項目と過去の関連記録の比較は[2026-10-11の横断確認](ui-failure-patterns-20261011.md)を参照する。
順序の因果を断定しない最新判断は[方針再評価](ui-notification-reassessment-20261011.md)、
253失敗ジョブの原ログ再取得範囲は[照合一覧](ui-failure-log-audit-20261011.md)に記録する。


## U68 単項目の背景復帰後、process一致検査の再照会が停止（全体384、iOS27）

- 対象：1ead97ba9029a5f9370c26cd2f22d957b57a32e1、38350398047・試行1、job115141547638、SDK27.0。
  testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground。
- 観測：入力・表示の173.534秒は完了し、実背景state3と復帰state4を観測。
  process診断の実取得は成功し、expectedとobservedが一致。直後のOneCorrection.swift:31で
  同じlabelを一致assert用に再取得しsnapshot timeout。ケース447.324秒・失敗1、準備込み498.9秒。
- 状態：下位原因未確定。U67候補のrequirePreviewへ到達しておらず、その変更の失敗とは扱わない。
  先に観測を保存・pushし、U17の背景復帰後診断と旧／現コードを比較する。
  恒常的原因を断定せず、残りのActionsは取消さない。今回の公開条件は未達。
- 補足：原ログ全文で最初の取得・同一IDの診断を確認し、初報の「診断照会の停止」を訂正した。
  候補は復帰後の実label取得を一回にして、同じ実測値を診断と元の一致assertで共用する。
  期待IDの注入、プロセス比較の削除、背景／再編集／保存条件の変更は行わない。
- 根拠：[384単項目27](https://github.com/n624-dev/takupoke-ios/actions/runs/38350398047/job/115141547638)。
- 候補実測：c82cd3aの全体385では27単項目786.704秒、26単項目664.059秒・失敗0。
  実取得process IDが元のIDと一致し、後続の入力／ACK・レビュー・保存・再起動まで成功。
  全13と公開も成功した。取得値の共用による一回の通過をAXの恒常的解消へ一般化しない。

## U67 3項目訂正のpreview復帰確認でUI query timeout（全体383、iOS27）

- 対象：1f128ebf60204a906d6fe25add79d8b5ad35a696、38347122608・試行1、job115131299235。
  SDK27.0、testThreeFieldsRequireEachAcknowledgementAndFourRefuses。
- 観測：ManualAssistanceChecks+Review.swift:56、requirePreviewのUI照会で
  Failed to get matching snapshots: Timed out while evaluating UI query。
  実ケース877.056秒・1件失敗、UI準備込み944.9秒。
- 直前：3項目の入力と個別ACKは成立し、レビューへの移行を観測した。
  その後のpreview復帰確認で停止。採用せず閉じる・再起動・4項目拒否は今回完了したと扱わない。
- 状態：下位原因は未確定。製品Strictの固定番号以外、UI操作・fixture・workflowは382と差分ゼロ。
  先に観測を保存・pushし、既往のUI query／preview／3項目ケースと当時のコードを比較する。
  残りのActionsは取消さず確認する。Native550件・予定skip1・失敗0を公開合格へ代用しない。
- 比較：U62／U17／U11の全文と当時のInput.swiftを読み、今回は元predicateの後の診断existsと照合。
  候補は追加state照会の一行だけを、取得済み待機結果の出力へ変更する。元20秒・completed・
  実preview headerと後続の拒否／正常結果保持は維持。preview成立自体は観測できていない。
- 候補実測：1ead97bの384・job115141547791は567.596秒・失敗0。wait-outcome=1と元の
  実header・閉じる／4項目拒否まで成功。一般的AX原因・恒常的解消・全体公開合格は未証明。
- 根拠：[383の3項目27](https://github.com/n624-dev/takupoke-ios/actions/runs/38347122608/job/115131299235)。
- 最新実測：c82cd3aの全体385は27の459.252秒、26の554.837秒・失敗0。
  wait-outcome=1・実header・個別ACK・閉じる・4項目拒否・正常結果保持を維持し、全13と公開も成功。

## U66 VoiceOverのmoveForwardが返答エラー（全体381、iOS27 B）

- 対象：4fb4480a0a7859a0273a94024919eaba0521f745、38332379818・試行1、job115085118202。
  SDK27.0／Runtime27.0。testVoiceOverReadsTimetableCard・ApplicationChecks+Timetable.swift:0。
- 観測：AXVoiceOverAutomationErrorDomain Code3「Failed to send moveForward command」。
  ケース95.164秒・失敗1。通常の元11件は1219.128秒・他10件成功・失敗1。
  通知Runnerと追加文字サイズは未実行であり、今回の公開条件は未達。
- 状態：下位原因は未確定。Strict・UIと配布workflowを380と照合した時点ではUI差分ゼロ。
  先に観測を保存・pushし、関連する全文・当時のコードと今回を次に読む。
  残るActionsは取消さず確認する。Native548件と手動訂正27の3件は成功している。
- 比較：U43〜U50／U52と対象50／51を再読し、tap／発話待ち／新規deviceの失敗条件を照合。
  同じ実見出し相対点への一回接触だけを0.1秒へ変更したbf82e50の対象38335966194は
  設定293.330秒→VoiceOver54.277秒・2件失敗0。実18moveと元の3項目読み上げを確認した。
  touchの再送・SDK変更・期待値の緩和なし。単独成功から原因・全体合格を断定しない。
- 全体：708556aの新382では27 Bの元11件939.237秒・失敗0、VoiceOver51.283秒で
  実18move／元の3項目が成功した。通知と追加サイズ3条件も完了した。
  旧381は取消しなしで終端まで確認、残る26 Aも成功、公開は依存skip。
  この一回から下位原因や恒常的解消を断定せず、382の全13／公開は別途確認する。
- 公開：382は同じsource／実行／試行の全13成功と公開・匿名添付照合まで完了した。
  U66の今回非再発を下位原因・恒常的安定性の証明にはしない。
- 根拠：[381通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38332379818/job/115085118202)。

## U65 通常ホームcaseでアプリ起動のprocess handleを取得できない（全体379、iOS26 B）

- 対象：983e523・38218043172・試行1、job114718041872の
  testHomeTimetableAndWeekCalendar。進行中の取得ログで20.503秒のfailedを確認した。
- 観測：SDK26.5／Runtime26.5のSimulatorがjp.n624.takupoke.app-checksを起動できず、
  NSPOSIXErrorDomain Code3「No such process」、process handleもlaunch errorも返らない記録がある。
  下位原因は未確定。
- 終端：元の11件は983.760秒・予定VoiceOver skip1・失敗1。ホームcaseだけが失敗。
  設定caseは263.900秒でUI／保存0→1→0→1と再起動後1→0まで成功した。
  通知Runner／追加文字サイズは未実行。379は公開不可で、他のActionsは取消さない。
- 照合：U40／U41／U49／U59の起動記録と旧2b94d1c／373da5fのlaunchReady本文を読んだ。
  U49と同じNSPOSIX domainだが、今回は同一caseの再起動でなく、次caseのsetUp。
  前caseは成功し、前processのterminate／notRunningとSpringBoard応答後に一回launchが失敗。
  U41のdebugger-version欠落は成功時にもあり、この記録だけで原因とは判定しない。
- 候補の根拠：26 Bは旧SDK26.5、配布IPAと26 AはSDK27.0。
  同じRuntime26.5の26 Aは対象57・全体378で起動／再起動を含め成功した実測がある。
  Bだけを配布SDKに合わせ、失敗の直前case＋ホームcaseを元の順序で比較する案を評価する。
  SDK不具合の証明とは扱わず、起動の再試行・期限延長・期待値変更・SDK往復はしない。
- 状態：観測事実を47cbb46で先に保存・pushし、照合と根拠を4a68088でpushした。
  候補1560d59の開発100と、配布SDK27.0／Runtime26.5の既存2件比較61は成功。
  比較は直前case46.605秒→ホームcase60.977秒・失敗0。起動の再試行はない。
  379は取消しなしで全完了・11事前検査成功／U65失敗・公開skip。
  局所成功から下位原因や恒常的解消を断定せず、新しい全13を別途確認する。
  全体380の26 Bでも同じ直前case33.203秒→ホーム65.738秒が成功し、
  Bの全検査も元の11件・予定skip1・失敗0、通知159.523秒と追加サイズ3条件まで成功。
  U65は今回再発しなかった。同じsource／実行／試行の全13成功後、0.1.380を公開した。
  匿名取得で配布ソース・版・ハッシュ・固定Sourceを照合済み。下位原因は未確定。
- 根拠：[379通常26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38218043172/job/114718041872)。

## U64 初回AI／OCRのnative Switch操作が反映されない（全体378、iOS26 B）

- 比較結果：[focused60](https://github.com/n624-dev/takupoke-ios/actions/runs/38212443898)・917e807で
  同じ観測点の一回0.1秒接触は26／27成功（383.462／259.601秒）。
  元のUI／保存値／再起動後保持・45秒を維持。原因証明と全体合格は未完了。

- 対象：841a389・38207478769・試行1、job114680370204の設定／ファイル詳細case。
- 観測：SDK26.5・Runtime26.5。初回起動と設定タブへの一回0.1秒接触は成功。
  AI／OCRのUI・保存は0。子Switchの一意性・可視・0状態を確認し、
  実trackの観測点（frameと0状態から算出）へtapを一回合成した。
  45秒内にUI・保存の1はなく、期限後も双方0。ケース74.956秒で失敗。
- 区別：U55などの再起動後4回目でなく、最初の0→1。U04の入力未反映と関連する。
  U43／U52／U55では同じ4回目の未反映が再発済みで、個別成功から一般的解消を断定しない。
  U19の354は保存した画面座標への0.1秒press。379はnative control相対の0.1秒pressであり、
  接触方式自体は既出だが、失敗済みの画面座標方式へ戻していないことをソースで照合した。
  同じ全体の27設定caseは成功。SDK不具合・製品Binding・接触時間の原因は未確定。
- 結果：元の11件は予定VoiceOver skip1・失敗1・893.871秒。
  通知Runnerと追加文字サイズは未実行。378は公開不可、残りのActionsは取消さない。
- 次比較：U63のタブで両OSの一回0.1秒接触が成功した実測を参照し、
  Switchも同じ実点・45秒・UI／保存・再起動条件で接触方式だけ比較する候補。
  通常tapの成立や原因の証明とは扱わず、長押し・押し直し・値注入・期待値変更で救済しない。
- 根拠：[全体378・26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38207478769/job/114680370204)。

## U63 時間割タブの実tap後もホーム選択が残る（全体377、iOS26 A）

- 対象：4fb54a8・38197595058・試行1、共通時刻／行事のみ週のcase・job114652344006。
- 観測：SDK27.0・実Runtime26.5。時間割buttonの枠・enabled・hittableを確認し、
  標準button.tapを一回実行したが、45秒内の現在の選択は未成立。
  期限後の階層・独立した架空画面画像はホーム選択のまま。ケース64.658秒・失敗1。
  元の通常14件中13件は成功、1件失敗。別Runner通知は未実行であり成功に数えない。
- 比較：U30は旧SDK26系の設定タブ外枠中心、今回は配布SDK27の時間割タブ標準hit point。
  標準tapの実点は記録されておらず、誤った点だったとは断定しない。
- 候補：ボタンに属する一意な可視Imageの実枠を照合し、その中心へ一回だけ実tapする。
  外枠中心へ戻す方式と区別し、存在・所属・包含を証明できなければ拒否する。
  native選択と画面遷移、45秒を維持する。SDKの変更・押し直し・値注入は行わない。
  325674fの対象比較58は27成功108.648秒、26失敗82.609秒。
  26の実Image中心を一回tapしてもホーム選択のまま45秒を超えた。
  26はSDK27.0・Runtime26.5で全体377と同じ。アイコン中心化だけでは解決しない。
  その後9ffdf0eの比較59では、同じ点で一回の接触を0.1秒保持し、
  26は203.429秒、27は117.816秒で元のcaseが成功した。
  通常／行事のみと3文字サイズ、native selected・画面を確認した。
  普通のtap成立・失敗原因・共通helper全体の影響は証明せず、全13を別途確認する。
  SDK不具合や製品のタブ処理が原因とは未確定。
- 根拠：[全体377・26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38197595058/job/114652344006)。

## U62 確認Switch操作後の診断用frame照会が停止（全体377、iOS26）

- 対象：4fb54a8・38197595058・試行1、3項目訂正・job114652344042。
- 観測：第1項目は実入力・一回の確認tap・value1まで成功した。
  第2項目は全文入力とkeyboard非表示を確認し、実Switch中心を一回tapした。
  直後のInput.swift:33の診断printがrow.frameを照会し、snapshot timeoutで失敗。
  ケース339.171秒・失敗1。value1の必須待機へは進んでいない。
- 比較：U17の入力前、U11の消去後と同様に追加AX診断の停止を参照するが、
  今回は確認tap直後。入力未反映・製品クラッシュ・SDKの原因とは未確定。
  事後の所有appログは15秒で取得timeout、クラッシュレポート一致0は原因の証明でない。
- 候補：tap直後の診断は固定段階・IDだけ記録し、追加frame／valueを照会しない。
  元の一回の実tap、45秒内のvalue1待機、個別確認・4項目拒否・保存条件を維持する。
  候補を実装し、元のdiagnostic markerを維持したローカル184件は成功。
  c60f872のfocused9は26／27とも一回の元のケースが成功（462.326／396.765秒）。
  一般的原因・配布前全体合格は未確認。残るActionsは取消さず確認する。
- 根拠：[全体377・3項目26](https://github.com/n624-dev/takupoke-ios/actions/runs/38197595058/job/114652344042)。

## U61 Runtime取得物の形式を誤って固定した（診断56）

- 対象：607631d・診断38195655722・試行1、rows／26／SDK27.0。
- 観測：26.5／23F77／arm64・8.52GBの取得は成功した。
  Installing／Doneの後、exportedBundleとしてexportされたが、
  事前処理が従来のdmg一件を要求したため失敗。UIは未実行。
- 誤り：Apple手順の旧形式を現在SDKへ固定した。Runtime取得失敗ではない。
- 修正対象：取得後に実際のavailable Runtimeを照会する。
  既に26.5が利用可能なら再importせず、所有export領域回収後にも26.5を検査する。
  未installのdmgだけ従来import経路を使い、別版・欠落は拒否する。
- 根拠：[診断56](https://github.com/n624-dev/takupoke-ios/actions/runs/38195655722/job/114637584557)。

## U60 配布SDK比較に必要なiOS26.5 Runtimeがない（診断55）

- 対象：acf884a・診断38195173505・試行1、rows／26／SDK27.0。
- 観測：実Xcode27.0・build27A266a・実SDK27.0は確認できたが、
  最高available26系Runtimeが26.5である条件に不合格。UIは未実行。
  Runnerはxcode-27-arm64／20261006.0244.1。
- 照合：この版の公式搭載一覧のiOS Runtimeは27.0のみ。
  Xcode27の26.5対応や起動品質の不合格を示す結果ではない。
- 次の条件：Apple公式の版指定取得・importで26.5を用意できるか確認する。
  別OSへ切り替えず、取得後も実SDKと26.5の検査を維持する。
- 根拠：[診断55](https://github.com/n624-dev/takupoke-ios/actions/runs/38195173505/job/114636120558)、
  [Runner搭載一覧](https://github.com/actions/runner-images/blob/xcode-27-arm64/20261006.0244/images/macos/xcode-27-arm64-Readme.md)。

## U59 通常区間の初回launch timeoutと次ケースのpid 0（全体376、iOS26 A）

- 対象：373da5fの最初の`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`。
  setUp内の一回のapp.launchが71.998秒でtimeout。除外操作・保存・再起動には未到達。
  直後の`testEmptyDataCanBeConfigured`はpid 0のbackground assertion取得失敗、15.105秒。
- 観測：両方ともSpringBoardのforeground・有限frameを確認した後に失敗。
  初回timeoutの後、DTServiceHubがpid18555へのsignal19送信でerror3を記録。
  次のケースではpid18577をterminateした後に起動・操作が成立している。
  timeout後のlaunch workerが次ケースへ影響したか、アプリ終了原因は未確定。
- 比較：U49は同名caseの保存後再起動であり、今回は初回setUp。
  U58の通知用新規deviceとも区間が異なる。U40／U41と起動系の症状を比較する。
- 状態：途中で起動失敗2件を確認し、376は公開不可。残りは取消さず確認する。
  製品・SDK・期限・実操作を変更せず、終了時のlifecycleと下位エラーを確認する。
- 最終確認：14件・失敗2・1248.584秒、通知区間は未実行。26 Bは全区間成功。
  376はfailureで全ジョブ完了し、公開skip・配布物なし。取消しなし。
  pid18555／18577のinit-enter記録はなく、下位原因は未確定。
  事後のserviceログは直前10分だけで約20分前の起動失敗を含まなかった。
- 根拠：[376通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38188845694/job/114624106481)。

## U58 通知用の新規deviceで初回launchタイムアウト（全体375、iOS26 A）

- 対象：b9289aeの`testChangedDataProducesOneLocalNotification`、83.592秒で失敗。
  元の通常14件は1542.733秒・失敗0。通知は別Runner・別の所有deviceの初回起動で失敗した。
- 観測：boot174.6秒の完了後、SpringBoardのforegroundと有限frameを確認。
  `ApplicationChecks.swift:86`の一回の`app.launch()`がXcode経由の起動タイムアウト。
  FBSOpenApplicationServiceErrorDomain1／RequestDenied、FBProcessExit64、RBSRequestErrorDomain5。
  lifecycleはcapture-missing-or-limited。アプリ初期化到達と下位原因は未確定。
- 比較：U40の長いbatch後の別Runner、U49の保存後再起動と区別する。
  U08の通知許可要求には到達しておらず、許可経路やPDF解析の失敗とは扱わない。
  同じ375の26 B通知、27 A／B通知、手動訂正6ジョブは成功した。
- 状態：375の全ジョブ完了を取消しなしで確認。公開ジョブskip、配布物なし。
  launch再試行・待ち時間延長・case省略・製品変更はまだ行っていない。
- 根拠：[375通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38182423428/job/114607278933)。

## U56 年度入力操作後に4桁の一致が成立しない（全体374、iOS27 A）

- 対象：bd5ddb7の`testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair`。
  71.211秒で失敗。実tap後にKeyboardが存在し、typeText後の10秒内に2032との一致が成立しなかった。
- 状態：focus不足・入力欠落・古いvalue照会のいずれかは未確定。実入力値は未記録。
  製品変更・期限延長・値注入で補わず、失敗時の現在の値／keyboard個数を観測して区別する。
- 根拠：[374 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38178184681/job/114585332317)。

## U57 worker開始後の実終了操作で待機へ戻らない（全体374、iOS27 A）

- 対象：bd5ddb7の`testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork`。
  67.670秒で失敗。ホームでbusy開始とfalse／pendingを確認後、実終了Buttonを一回操作。
  その後10秒内の待機表示が成立しなかった。開始の失敗ではない。
- 状態：終了操作未到達かworker完了待ちかは、失敗時の解放／完了値が未記録で判断できない。
  元の60秒gate・実終了操作・successと元データ保持を維持し、期限切れを救済しない。
- 根拠：[374 A](https://github.com/n624-dev/takupoke-ios/actions/runs/38178184681/job/114585332317)。

## U55 再起動後4回目のAI/OCR操作が未反映（全体373、iOS27 B）

- 対象：1606222の`testSettingsAccountDataAndFileDetails`、184.277秒で失敗。
  元の11件中10成功・1失敗、1379.984秒。VoiceOverは65.424秒・18move・元の3項目で成功。
- 観測：最初のpid50822で0→1→0→1のUI／保存と各setterが成功。
  再起動後pid52848では状態1一致・全表示・hittableのnative trackを一回操作したが、
  45秒後も双方1、新pidのsetter記録なし。U43／U52と同じ操作段階で再発した。
- 状態：373は公開不可。通知Runner／追加文字サイズ／対応26 Bは未実行。
  27 Aは停止せず確認する。発話待ち、System UI準備、文言照会除去をこの失敗の解消としない。
- 比較候補：このcaseは最初の起動で作ったai／storedのXCUIElementを再起動後も保持している。
  新プロセス・設定画面に入った後に同じIDのqueryを作り直す小さい比較を検討する。
  古いqueryが原因とは未証明。操作点・一回操作・45秒・保存／再起動条件は固定する。
- AX診断：失敗時刻は観測10分内だが、4MiB超過でeventsはlimited。原因の証明には使えない。
- 根拠：[373通常27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/38174507842/job/114574170292)。

## U54 再起動後のリンク追加メニューが出ない（全体372、iOS26 B）

- 対象：bf1749aの`testLinkPreferencesSurviveRelaunch`。ケース176.396秒で失敗。
  最初の実長押し・お気に入り解除は成功。terminate／一回launch後の追加メニューが45秒内にない。
- 観測：二回目も行は全表示・hittableで、所有Buttonへ2秒の長押しを一回送った。
  操作後の架空画面は白く、後続AXは一覧を返す。BrowserView／Closeは観測していない。
  U42のブラウザへの遷移と同じ原因だとは断定しない。初回と再起動後の状態を区別する。
- 記録：操作後画像55495bytes、SHA256
  `3f7a16bd86a563f9e8c5838bf81d5d5eb90db66b0c99cf94e5e12be5fb544d71`を照合して確認した。
  架空画像はGitへ保存しない。リンク判定領域の既存修正は維持し、操作点を往復しない。
- 状態：26 Bは最終failure。実11件・予定skip1・失敗1、1295.583秒。取消・再試行・期待値緩和なし。
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

## N47〜N50 候補差分の正式414での結果

[run39169498233・attempt1](https://github.com/n624-dev/takupoke-ios/actions/runs/39169498233)／source `6c054df5c590dd5d6d05f2cca06936d79855df99`は、両OSの通常A/Bと訂正4ケースを含む全15必須チェックが成功。候補は観測範囲に基づくbounded drag、追加診断照会の削除、通知行の一回接触とQA panelの入力対象の限定。この正式実行では除外操作・単項目訂正・設定tabと実許可／配信が通過した。N49のQA panelは実checkPermission開始までpassiveにし、26の小さい比較は成功したが27単独比較N50は未返答で失敗した事実を残す。製品・期待条件は維持し、同じAX症状の恒常的解消とは断定しない。

## N55 正式418の選択訂正27と通常UI26Bで失敗（2026-10-20確認）

- source882a9c2b762fd735e3c5599d1a8d457f2c43d95d、run39308527009／attempt1。全実ジョブ終端、公開ジョブskipped。
- Manual correction iOS27 / testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch（job118252477631）とApplication iOS26 UI B（job118270964051）がfailure。具体的操作・原因は完了ログ照合前で未確定。依存する訂正26の4ケースは展開されず、成功に数えない。
- 対処を決める前に事実を記録。新しい完了ログだけを保存し、過去の同名ケース・操作の詳細とコードを照合する。正常Strict・入口・通過経路は変更しない。

- 完了ログ照合：27選択訂正はケース開始・完了0、Runnerのbootstrap中にEarly unexpected exit／XCTWaiter(StallHandling)で終了。ビルド142.4秒は成功し、実訂正には未到達。2026-10-09診断37974710845（verification）と同じ開始前の症状で、製品の訂正失敗とは数えない。現runnerはboot後にコンパイルするが、既存App／Picker runnerは停止中にビルドする。次はManualも同じ順に揃え、同一ビルド・全操作・厳密な完了条件を維持して比較する。原因確定ではない。
- 26BはtestLinkPreferencesSurviveRelaunchの最初の解除で87.134秒失敗。実row・hittable・全表示を確認し一回2秒長押ししたが、45秒内にメニューなし。失敗画像127723bytes／SHA256 7af983702f67c677ec14f54a1984e9a484086e90888152e7ed03bea0d8ee461aを照合すると架空URLのSafari画面へ遷移しており、AXの一覧だけから画面が変わらなかったとは判断しない。
- 検索語LinkPreferences／長押し／bootstrap／StallHandlingでN44・U42・U54とverificationの2026-10-09／10-11詳細、当時e4f2fbf／bf1749aと現LinkRow／Settings.swiftを照合した。U42と同じprimary actionへの遷移が、interaction形状の追加とN44観測順序変更後にも再発した。操作点を往復しない。
- 次の比較は製品の標準Menu(primaryAction:)へタップと長押しを同じ所有controlとしてまとめる。Apple公式Menu文書はtap/clickをprimary action、long pressをmenu表示として明記する（https://developer.apple.com/documentation/swiftui/menu）。Button＋別contextMenuの組合せから変更し、実メニューの解除・追加、再起動保持と45秒、長押し一回を維持する。候補の実効果・下位原因は未確認。Strictには触れない。

- N55候補の両OS限定比較は、リンクrun39392202975と元選択訂正run39392461496・各試行1で全job成功・artifact0。元の実操作と追加したprimary tap／nativeブラウザ／Close復帰を確認し、正確な完了件数・logを照合した。正式の同source全15と公開は次に確認し、限定成功や旧418を全体合格へ流用しない。
## N57 Issue 41の初回Linuxコンパイルがthrow式で停止（2026-10-22）

- 基点f38831e、作業ブランチcodex/fix-issues-41-43、Debian13/x86_64・Swift6.1.2、`bash tools/test-parsing.sh`の初回。製品SpecialScheduleStore.swift:42の`existingDatabase && !(try db.tableExists(...))`で、短絡演算子のrethrowsに対するtry不足をコンパイラが検出した。テスト実行前のコンパイル失敗であり、PDF削除・実資料通信・UI実行は発生していない。
- 対処前に記録。`operator can throw|rethrows|tableExists|Swift6.1.2`で索引を照合する。候補は条件を入れ子のifへ分ける通常のSwift構文修正で、DB欠損時の停止条件や回帰期待値を変えない。次の試行の前に候補と記録をブランチへpushする。
- 照合では同じ短絡演算子のエラーは既存記録になく、過去のLinuxコンパイル停止・SQLite異常終了とは発生箇所と段階が異なる。基点のstoreには今回追加したthrow条件自体がない。入れ子のif／guardへ分け、欠損時にthrowする判定を維持した。修正後の正規Linux Swift検査は517件・失敗0で完了（実行77.237秒、準備込み255.4秒）。

## N58 任意のLinux presentation補助リンクが準備段階で停止（2026-10-22）

- source4a856ba、Debian13／Swift6.1.2。実行中のSPM一時ビルドのobject群へ、SwiftUI importだけを外したpresentationと名称stubを直接リンクする補助検査を一回試した。swiftcがexit1で、検査本体の実行には到達していない。stderrを表示せずにCalledProcessErrorへ変換したため詳細は保持できず、原因は未確定。補助検査は成功件数に含めない。
- 対処前に記録。正規SPMのN57構文失敗と、独立手動リンクの今回の準備失敗を区別する。同じ条件で再試行せず、製品・期待値を変えない。追加したpresentation／モデル回帰は、元から予定したmacOSの正規SPM／Actionsで確認する。実行中のLinux正式検査は変更・中止していない。

## N59 追加Issue対応後のiOS27原本変更訂正ケースがfailure終端（2026-10-22）

- sourcec7994b7892d61b30356b6e9b04d7bc6d545830fc、run39706417881／試行1、iOS27・SDK27.0、job119587932866。testChangedOriginalCannotSubmitOrReplaceLastGoodがfailure終端。02:25頃の予定照会で確認した。ログ取得前で失敗段階・原因は未確定。
- 対処前に記録。DistributionとNative600件（予定skip1・失敗0）は成功、他UIとiPhoneビルドは継続中／待機。実行はキャンセルせず残る結果も確認する。新完了ログを読み、過去の同ケース・操作段階・OSと当時／今回のコードを照合してから対処を決める。期待値・実操作・期限を緩めない。

- 完了ログでは、実入力・ACK・レビュー遷移・比較不能表示の可視確認と、架空原本ハッシュ変更の一回の実タップ・mutation-complete確認まで通過した。その後Cases.swift:36のレビュー再確認ボタンをtapするvisible(app.buttons[title].firstMatch)が、既知IDを渡さず存在／frameを照会し、Navigation.swift:49のsnapshot timeoutになった。591.928秒・1件失敗。再確認の実タップと以降の旧正常結果保持は未確認。クラッシュ報告0、AXの下位原因は未確定。
- 検索語：manual-submit／target.exists／Navigation.swift:49／原本変更／snapshot。N54・U01・U02・U11・U14を詳細まで読み、5fd0805の既知ID委譲と現行Navigation／Review／Inputを照合した。初期のInput.assertSubmitEnabled(false)という仮説は、実際のCases.swift:36とログのボタンlabelに一致せず棄却した。N54は比較不能表示、今回は原本変更後のレビュー再確認ボタンであり、U14のメニュー操作・U11の消去後valueとも段階が異なる。N54後の共有visible／Reviewは今回も維持され、再確認ボタン本体だけにはQA識別IDがなかった。
- 候補はQA生成viewだけにmanual-review-submit識別IDを追加し、既存tap helperからvisibleのknownIDへ渡す。原本変更と三項目訂正の同じ再確認ボタン2呼出しをそろえる。実際の一致要素配列から取得し、16回以内の有界scroll・実frame・viewport包含・hittable・一回の物理tap・既存の状態待機と全期待値を維持する。製品、入力／ACK／原本変更／旧正常結果保持の検証条件は変更しない。一般的なAX問題の解消を断定せず、既存ケースの両OS結果で確認する。

- 候補b1ca475のローカル確認：Pythonのmanual UI生成／runner／scroll検査23件と、その中で実行するSwift GeometryControls27件は失敗0。変更したSwift2ファイルの構文解析、一覧check --base c7994b7、空白検査も成功。QA差分のみを新規GPT-6.1 Sol／Highでレビューし、意図外変更・検証弱体化の指摘なし。実シミュレータ上の効果は次の全体CIで確認する。

## N60 追加Issue対応後の通常UI27Bがfailure終端（2026-10-22）

- sourcec7994b7892d61b30356b6e9b04d7bc6d545830fc、run39706417881／試行1、iOS27・SDK27、job119587932831。02:44の予定照会でApplication iOS27 UI Bのfailureを確認。ケース名・段階・原因はログ取得前で未確定。対処を決める前に記録し、新完了ログと過去の詳細／コードを照合する。
- N59候補の全体run39712114838はこの失敗の観測前02:34に開始済みで、現在ランナー待機。通常UI Bには候補変更がなく、同じ失敗への再試行として意図的に開始したものではない。いずれもキャンセルせず、依存skipを成功に数えない。

- 完了ログの6件中1失敗はtestRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption、Recovery.swift:113、201.010秒。プレビュー表示・架空PNG（273788bytes／SHA256 aace16348301e1a680c6ff0ad0666e6e862ee9f121e01548d0fe508f2efa8f70）取得まで成功。画像では教員／教室欄が下端にあり、AXでも最初に実frameを取得したが、recoveryVisibleの最初のdragがy794→205の589pt。直後に対象がAXから消え、その後は不在の前方探索を続けて末尾100%へ到達した。シート自体は残り、採用ボタンは未操作。Strict・復旧処理の失敗や対象データ消失とは断定しない。
- 検索語RecoveryPreviewOriginalBlank／Recovery target／sheet viewport／recoveryVisible／bounded dragで索引と詳細を照合。N47の実frame取得済み行を大swipeが通り越す問題、U05の仮想化した画面外要素、9dcc93bのsheet所有範囲とocr-improvement-logの当時詳細、現NavigationのN47幾何補正を読んだ。Recovery helperは9dcc93bから同じ大drag分岐で、一般画面だけに適用したN47補正がなかった。今回もsheet所有範囲・passive rowの安全条件は必要なので、一般画面の座標操作をそのまま移さない。
- 候補は既存ObservedScreenGeometry.scrollDragが実frameから返す中心方向・viewport高さ1/3以内の距離を、既存recoveryDragへ渡す。対象不在の探索、12回上限、完全包含、実PDF表示・採用前保持・実採用・再起動保持の期待は維持する。既存の幾何7件は上下補正／上限／無効frameを検査し、元の実UIケースが今回の探索失敗を検出しているため、同じ内容のテストは追加しない。両OSでの実効果は未確認。

- 候補fa2efa1のDebian13／Swift6.1.2ローカル検査はObservedScreenGeometry7件とPython UI manifest／runner40件が失敗0。変更Swiftの構文解析・catalog check --base b9df827も成功。コード差分だけの新規GPT-6.1 Sol／Highレビューはblockingなし。これらは実UI通過ではなく、次の全体CIで確認する。

## N61 初回修正の単項目訂正26がfailure終端（2026-10-22）

- source4a856ba25309fdd370ceb62a74c90fd74326370e、run39702652277／試行1、job119589878745。単項目訂正iOS26が02:57:43にfailure終端、03:12の予定照会で確認。ログ取得前で具体的な段階・原因は未確定。対処を決める前に記録した。
- 同じ実行の原本変更26と三項目26は成功、選択訂正26は継続。追加IssueとN59／N60候補の全体実行はこの失敗の観測前に開始済み。キャンセルせず、次の修正／試行を判断する前に新完了ログと過去詳細を照合する。

- 完了ログはManualAssistanceChecks.swift:13の最初のapp.launchで、pid30773へのbackground assertion取得がtimeout。43.638秒・失敗1、fixture-ready待機・訂正入力・背景復帰には未到達。クラッシュ報告は0で、下位原因は未確定。
- 検索語background assertion／launch／U40／U41／U49／U59／U65で各詳細とverificationの376、2b94d1cの起動helperと現Manual.launch／runnerを照合した。U59は通常26の初回timeout後にpid0、今回は単独訂正の最初の起動で非zero pid。U49の保存後再起動、U40の長いbatch後とも段階が異なる。今回のIssue修正とN59／N60候補はManualAssistanceChecks.swift・runnerを変更していない。証拠から製品やSDKを推測変更せず、既に開始済みの実行結果を確認する。新しい起動再試行や期限延長は追加しない。

## N62 スクロール候補の三項目訂正27がfailure終端（2026-10-22）

- source60d71bf94d13e7a7b5e0d7d03b6a07abb8777058、run39713366215／試行1、job119610118487。04:10の予定照会で03:59:39のfailure終端を確認。具体的な段階・原因はログ取得前で未確定。対処を決める前に記録し、同じソース条件の直前b9df827での三項目27成功と、過去詳細／コードを照合する。
- 最新の原本変更27・Nativeは成功、他UIは継続中。N60差分はApplicationChecks+Recoveryだけで、この訂正ケースの実装はb9df827と同じ。新しい実行は開始せず、既存実行は取消しない。

- 完了ログはケース開始・完了0で、PickerTapChecks-Runnerが準備中のEarly unexpected exit／XCTWaiter(StallHandling) handleStalledWaitで停止。診断はreportsScanned7／matchingTextReports0／xcresultFailures空で、下位原因を確定できない。N55と2026-10-09の診断37974710845詳細、旧／現runnerのbuild-before-bootを照合し、N55候補後にも同じ開始前症状が出たことを記録する。直前b9df827の同ケースは実入力・ACK・再確認・4項目拒否まで成功したが、その成功を最新の未実行へ合算しない。新たな根拠のないSDK往復・起動再試行・期待の変更は行わず、開始済み実行の残る結果を確認する。

- N59候補b9df827の原本変更27は316.218秒で成功し、実manual-review-submitタップと原本不一致表示・旧正常結果保持が成立。Native600件（skip1・失敗0）と27の通常A/B・訂正4件・iPhoneビルドはすべて成功した。N60候補60d71bfの原本変更27も成功。これらを一般的なAX問題の恒常的解消とは扱わず、未完了の26や最新全体成功へ流用しない。
- 初回4a856baのrun39702652277は取消しなしで全ジョブ終端。必須15件中14成功、N61の起動失敗1件、公開skip。全体成功とは扱わない。

- 05:20のまとめ照会で、b9df827の同一実行・試行の必須15件が全成功し、N61と同じ単項目26も完了したことを新たに確認。三項目27の完了ログは499.870秒で成功。60d71bfとの差分でManualケース／起動／runnerが同一bytesであることも確認した。最新60d71bfは05:38:31に全job終端し、必須10成功・Runner開始前失敗1・依存訂正26未展開4。通常A/B両OSとNative600件（skip1・失敗0）は成功した。N60候補の実効果はこの通常UIで通過した。
- この新しい比較証拠に基づき、製品／QAソース・SDK・操作・期限を変更せず、同じ60d71bfの失敗jobと依存jobだけを独立して再検証する。成功済み通常UIやNativeの全体再実行はしない。過去2026-10-09の同一ソース独立検証と同様、開始前Runner障害の対処効果や下位原因を捏造せず、初回失敗を保持して別試行として記録する。XCTest内の再起動再試行は追加しない。空のコード差分を新規GPT-6.1 Sol／Highへ渡し、意図外変更・検証弱体化なしを確認した。

## N63 独立再検証の選択訂正26がfailure終端（2026-10-22）

- source60d71bf94d13e7a7b5e0d7d03b6a07abb8777058、run39713366215／試行2、job119667908298。06:45の予定まとめ照会で06:20:30のfailure終端を確認。具体的な操作段階・原因はログ取得前で未確定。対処を決める前に記録し、同一ソースの前回成功と過去詳細／コードを照合する。
- 再実行した三項目27と依存する原本変更26・単項目26・三項目26は成功。全job終端、最新実行はfailure、公開skip。試行1のRunner開始前失敗は保持し、試行2の別失敗を合格へ置き換えない。

- 原ログは472.563秒・1件失敗。最初の明示科目訂正・ACK・reviewとpreviewまで通過し、同じ授業へ教員を追加する前のmenu探索で16回上限。attempt1ではcell-1-0-0の科目Textがy194〜214.33、ownerは153.67〜248.67で表示範囲内だったがhittableを満たさず、full upward panでvirtualizeし、末尾から一回反転して元行へ戻る前に上限になった。最終AXでも同IDはy163〜183.33に存在。なぜhittableでなかったかは未確定。
- SelectedHighConfidence／no-progress／hittableでN36・N25・N32・U05の詳細と旧9274ca7・現Navigation／OneCorrection／純粋幾何を照合した。N36は任意の別授業だったので可視候補を選び直したが、今回は選択済みの同じ授業に教員を追加する必要があり、別候補へ代えると検証を弱める。従来locateは画面内の非操作対象では方向を変えず、大きな探索panへ進んでいた。
- 候補は、実際に存在し完全包含しているがhittableでない同じ対象だけを、観測viewportの中央方向へ最大240ptか高さ1/3以内のpassive-row panで移す。操作対象ID・実hittable要求・全包含・16回・一回反転・実長押し／実menu選択・入力／ACK／第4拒否／採用／再起動の期待値を維持する。移動で操作可能になるとは断定せず、中央でも不操作なら失敗を維持する。純粋幾何の上下／無効／既定経路の対照を追加し、両OSの既存選択訂正caseで検証する。

## N64 N63候補のローカル補助検査が終了1（2026-10-22）

- source4164a14、Debian13／Swift6.1.2、Python manual_scroll_navigation／manual_ui_project／manual_ui_runnerの候補初回実行。コマンド終了1を確認し、詳細ログを読む前に記録した。原因・失敗したケースは未確定。実シミュレータのActionsは未開始。過去詳細とログを照合し、対処根拠をpushするまで再実行しない。

- ログは新規幾何2ケースの追加後、埋込みSwift実行前の宣言数guard（期待27・実29）で停止。製品や幾何のassert失敗ではない。N05の宣言一覧不一致の詳細と当時の登録方針を照合し、今回はPython内の厳密な実行数guardだけが旧値だった。新規2件を含む29を要求し、全ケース完了照合は維持する。N63の中央寄せ後に既存のno-progress反転が選ばれた場合も、passive開始行と同じ方向のpanを使うよう整合させた。

- N63候補bcd672fの修正後ローカル検査はPython23件・埋込みSwift幾何29件が失敗0。Swift構文解析とcatalog check --base 60d71bfも成功。コード差分だけの新規GPT-6.1 Sol／Highレビューはblockingなし。まず既存の選択訂正ケースを両OSだけで実行し、追加Issueの製品変更とはソースと結果を分ける。

## N65 追加Issue47〜58の初回Linux検査（2026-10-22）

- source2a22448からの未コミット追加Issue差分、Debian13/Swift6.1.2、正規tools/test-parsing.sh初回。529件中29 assertion失敗（27 unexpected）、全体failure。観測後・対処前に記録。ログ /tmp/additional-ios-parsing.log。Workbook種別保存の再読込でinvalidStateが複数発生した。他の失敗はこれから全件を読み、過去の詳細と当時コードを照合する。次の試行前に根拠と修正をpushする。

- 全失敗は追加した2テストに限定。年度203/1899は既存の先行guardが.dateを投げ、新設.defaultYearより先に終了した。9999は新guardで拒否した。2a22448のparse全文を照合し、同じ入力を二重検査せず先頭の年度guardを1900〜9998/.defaultYearへ統一する。入力保護を緩めない。
- 27件のunexpectedは、稼働中のMaterialLibraryを保持したままopenLibraryを2回呼んだため。LocalDatabaseTests.testSecondRuntimeOwnerCannotCollectActiveStagingのとおり同時owner拒否は既存の必要条件で、SQLite破損や新kindのdecode失敗ではない。所有スコープを終了してから再読込する回帰に修正する。N02のSQLite header/runtime異常終了・N57のコンパイル停止・N03のテスト記述誤りを詳細照合し、今回のlock拒否と区別した。製品の二重起動拒否・永続化条件は変更しない。

## N66 選択訂正の幾何候補を両OS単独確認した実行がfailure終端（2026-10-22）

- source2a22448c7bc170645bf668a4a93648cf278051e8、workflow manual-input-native-probe、run39736574478/試行1。06:51:20開始、予定付近のまとめ照会でfailure終端を確認。OS・job・失敗段階はログ未取得で未確定。対処前に記録した。N63候補だけのsnapshotで、追加Issue47〜58の製品変更は含まない。新完了ログを読み、過去詳細・当時コードと照合してから対処を決める。取消し・同条件の盲目的再試行はしない。

- 完了ログ：iOS27/job119683558693は既存の選択訂正case1件が1120.109秒で成功。iOS26/job119683558425は185.712秒、Input.swift:42の最初の科目ACKで45秒value1待機が失敗。入力全文「架空選択科目」と消去・textイベントは成立。包含済み子Switchはframe(300,658.67,63,28)、hittable=true、実中心(331.5,672.67)へ一回0.1秒接触したが、ackイベントなし／UI0／保存診断ack=false。N63の後続同一授業menu探索には未到達で、幾何候補の26への効果は確認できない。全体成功には数えない。
- 検索語SelectedHighConfidence／Input.swift:42／ACK／U71でU71・U64・N63・N47〜N50の詳細と1b368f5／2a22448のInput・生成QA overlayを照合。U71は三項目の第2科目・標準tap、今回は選択訂正の最初の科目・候補後の0.1秒接触で、同じBinding未発火が再発した。画面内位置・診断panel非hit条件・native値から製品の確認ロジックを推測変更せず、押し直し・値注入・期待緩和・待機延長をしない。
- 同じACK helperを使う選択26はb9df827の同一全体run39712114838で成功し、60d71bf/試行2も最初のACKを通過してN63の後続探索へ進んでいる。新しい47〜58は製品の年度・通知・監視・表示経路を変更するため、次は全体の必須回帰を一度実行する。これはACKの修復を断定する同条件の単独再試行ではない。N66の失敗を保持し、新しいソースの全体結果と混同しない。

## N67 追加Issue全体425の27系ジョブが早期failure（2026-10-22）

- source0f15eba12cc76c2dfbb4cc50d09394c3a74395b7、run39742405286/試行1。07:50頃のまとめ照会で、27の通常UI A/Bと手動訂正4件が開始後1〜2分でfailure終端、依存26はskipと確認。Distributionは成功、Native・iPhone buildは継続中。ログ取得前で失敗段階・原因は未確定。対処前に記録し、新完了ログを比較してから判断する。残る実行は取消しない。

- 6ジョブの完了ログは全てテスト開始前のコンパイル失敗。MaterialsView+FileSummary:58、MaterialAccess:52、ChangeAnalysisView:41が不正年度を区別するInt?を、旧ChangeParseAttemptのInt専用matches/needsAnalysisへ渡していた。N57/N03のコンパイル失敗詳細と60d71bfの各呼出しを照合。今回のSwiftUI/workerはLinux SPM対象外なので構文検査では検出できなかった。N66の実接触未反映とは別で、UIケースは未実行。
- 候補は成功解析と同じく、失敗解析cacheにも「現在年度を確定できない」状態を渡せるようにし、nil/範囲外はcache一致・自動解析要求の双方をfalseにする。不正年度を今日へ戻さず、valid年のdigest/version/同意比較と失敗cache抑制を維持する。SPM内の実関数でnil・範囲外・validの対照を追加する。製品の型契約に合わせる修正で、UI操作・期待を変更しない。

## N68 追加Issue全体425のNativeがfailure終端（2026-10-22）

- source0f15eba、run39742405286/試行1、macOS26/Apple Swift、job119703281016。07:55予定照会でfailureを確認。失敗段階・ケースはログ取得前で未確定。N67修正候補は旧Nativeの結果確認前に作成しており別ソースでローカル検査中。対処前に記録し、全失敗と過去詳細を照合してから判断する。iPhone buildは未完了で取消さない。

- Nativeログの失敗は追加MappingPackageTests:251/267/270の3つのqueue.writeだけで、async testからGRDBのasync overloadが選ばれたがawaitがなかった。テスト本体実行前のコンパイル停止。N03/N57の詳細とGRDBのwrite定義・既存同期storeを照合し、今回は非同期テスト側の呼出し契約の差だった。3つの実SQLite書込みをtry awaitにし、認証・ZIP検証・triggerによる保存失敗・bytes保持・復旧・再起動の条件は維持する。製品storeの同期トランザクションは変更しない。

- 08:08の予定まとめ照会で425は取消しなしで全job終端。最後のiPhone build/job119703281082もfailure。具体的な段階はログ取得前で未確定、対処前に記録した。最新修正fcc6ee2の全体426/run39744113444はqueuedで、開始前を成功扱いしない。

- iPhone buildの完了ログもHost testsのMappingPackageTests同3箇所のawait不足で停止しており、N68と同じ修正対象だった。Picker UI等は継続して完了し、ジョブは取消していない。最新426のNativeは08:03:36にsuccessとなり、型契約・追加Mac回帰の候補がAppleホストで通過した。残るUI・iPhone buildは別途確認する。

## N69 Issue59の初回Linux回帰で既存セル時刻テストが失敗（2026-10-22）

- sourcefcc6ee2からの未コミットIssue59差分、Debian13/Swift6.1.2、tools/test-parsing.sh。533件中1 assertion失敗。SpecialScheduleTests.swift:231、testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessonsで実値11:10〜11:50／期待13:35〜14:20。ログ/tmp/issue59-ios-parsing.log。対処前に記録した。既存テストの入力・過去失敗詳細・当時コードを確認してから判断し、根拠と修正をpushするまで再試行しない。

- N01・N65・N67・N68の詳細とfcc6ee2のSpecialSchedule.timeRange、該当テスト全文を照合した。失敗は実parserの通常日・専用日・結合セルassertionではなく、最後の架空oldSingleに保存済み11:10〜11:50を与えつつ通常時刻への上書きを要求した既存期待だけだった。#59はまさに保存済み時計を日付sortで上書きしない仕様であり、この1期待を明示入力11:10〜11:50の保持へ更新する。実parserの全日・全時限、通常日13:35〜14:20、結合セル、時刻未保存のoldPair12:50〜14:20は維持する。新たな独立回帰は元列順[2,1,3,4,5]と通常列順、保存再読込、空枠、変更、進捗、fragmentを検査し、製品の誤動作に合わせて期待値を生成しない。

## N70 Issue59のPython検査で生成一覧の行リンク不一致（2026-10-22）

- source8d2c7f9、Debian13/Swift6.1.2、Python全264件・skip2中1失敗。ログ/tmp/issue59-ios-python.log。Strict一覧の文字列比較にL41/L42の差を観測した。対処前に記録し、失敗ケース・生成内容と既存の一覧規則を確認してから判断する。SPMは同時点でコンパイル中。

- N05の生成一覧と宣言規約の詳細、test_pdf_branch_catalog.pyの全文比較、tools/pdf_branch_catalog.pyの生成規則、fcc6ee2からのparser差分を照合した。今回は宣言漏れではなく、先頭日を保存する2行追加で既存枝の位置だけが移った。生成コマンドwrite/checkで23箇所の行リンクだけを更新し、枝番号・分類・条件・件数は不変。テスト本文や比較条件は変更しない。

- N69/N70修正後のLinux正規SPM533件は失敗0、Python264件は予定skip2・失敗0。新規の保存再起動回帰は旧形式でtimeRangeのないレコードも含めて通過した。Apple UI・PDFKit・実機はこの結果には含めない。

## N71 全体426の選択訂正26がfailure終端（2026-10-22）

- sourcefcc6ee2、run39744113444/試行1、iOS26、job119728249451。09:05の予定まとめ照会でfailure終端を確認。具体的な失敗段階はログ未取得で未確定。対処前に記録した。27系・Native・iPhone buildは成功、残る26は継続中。Issue59を含む別sourceee6720dの全体427/run39750668724は、この観測前に開始済みで現在待機。いずれも取消せず、失敗ログと過去詳細・当時コードを照合してから判断する。

## N72 Issue59込み全体427の選択訂正26がfailure終端（2026-10-22）

- sourceee6720d、run39750668724/試行1、iOS26、job119760813849。次の作業再開時のまとめ照会で10:22:01のfailure終端を確認。具体的な段階はログ未取得で未確定。対処前に記録。最新27の6UI・Native・iPhone buildと26の通常B・原本変更・三項目は成功、26の通常Aと単項目は継続中。全体成功ではなく、残りを取消さず確認し、新旧の選択26のログと過去詳細・コードを照合する。

- N71完了ログは236.064秒・1件失敗。最初の科目clearのButtonはframe(317,587.33,44,44)、enabled/hittable=trueで一回tapしたが、45秒後も入力「架空科」・ack=false、Binding診断は初期draft1件のみでclearイベントなし。U11（消去済み古いAX照会）とN52（消去後ACK照会）とは異なり、消去actionの成立を確認できない。事後診断のsimctl logは回収timeoutで停止し、下位原因は未確定。全体426は取消しなしで全終端し、必須14成功・選択26失敗1・公開skip。
- N72完了ログはManualAssistanceChecks.swift:13の最初のapp.launchでpid21857へのbackground assertion取得がtimeout、19.649秒・1件失敗。fixture-ready・入力・clear・ACKには未到達。診断reportsScanned5、matchingTextReports0、xcresultとunified-log取得は15秒timeoutで、下位原因を確定できない。N61・U40/U41/U49/U59/U65の詳細と2a22448・fcc6ee2・ee6720dのlaunch/Input全文を照合した。N61と同じ初回非zero pid、U49の保存後再起動やU59の直前timeout後pid0とは異なる。Issue59はこのlaunch/Input/runnerを変更しておらず、fccとeeの各ファイルSHAも同一。
- 最新427の選択27は同じ操作と入力を成功している。起動の未成立と旧426の消去未成立を同じ障害と断定せず、製品・SDK・入力やACKの期待・期限・操作を推測変更しない。最新427の残る通常26A・単項目26を終端まで確認してから、初回失敗を保持した同一sourceの選択26だけの独立検証を判断する。

- 10:55の予定まとめ照会で427は取消しなしで全job終端し、必須14成功・選択26の初回起動失敗1・公開skipと確認した。通常26Aと単項目26も成功。新規Issueの最終まとめ検索でも追加は59までだった。最新同sourceでは選択27と他3件の訂正26が実操作・採用・再起動まで成功しているため、訂正操作に未到達の選択26だけを、製品・QAコード・SDK・期限を変えずに独立検証する。N61/N62の開始前障害時の限定検証と同じく、初回失敗は保持し恒常的解消を主張しない。成功済み14ジョブは再実行しない。実行対象ee6720dとの差分0行を新規GPT-6.1 Sol/Highが開始前レビューし、意図外変更・検証弱体化なし。

- 全体427/試行2の独立選択26/job119783828823は11:27:05にsuccess終端。再実行したのは1ジョブだけで、元の初回起動失敗を保持する。初回の必須14成功と今回の同source独立成功を確認した。公開は別のmain実行で、公開ゲートが要求する同じrun/attempt/sourceの必須検証を通してから行う。

## N73 公開用全体428の通常26Aがfailure終端（2026-10-22）

- sourced713ed6、main pushのrun39771133485/試行1、SDK27.0/Runtime26.5、job119812164540。13:10の予定まとめ照会で12:48:40のfailure終端を確認。具体的なケース・段階はログ未取得で未確定。対処前に記録した。取消しなしで全job終端し、Native・27系・通常26B・手動26の4件は成功、公開は依存skipで未実行。失敗ログと過去の該当記録・当時コードを照合してから判断する。

- 完了ログ取得はconnectorがAzure BlobNotFound/404、ghの別経路も配信先Forbiddenで失敗した。失敗したUI段階はまだ不明で、製品やQAの対処は決めていない。GitHubのjob/check-runの失敗注記と別のログ取得経路を確認する。

- GitHub check-runのfailure annotationは「The hosted runner lost communication with the server」。通常のXCTest assertion failureではなく、ホストとの通信断がジョブの終端理由と確認した。どのケースまで実行できたかと、通信断の下位原因（ネットワーク・資源不足・runner終了等）はログ取得不能のため未確定。これらを製品の修正完了として扱わない。
- lost communication/hosted runner/heartbeat/通信断で索引・検証記録・CI計測を検索し、同じhost通信断の過去項目はなかった。N61/N72の初回app.launch失敗とは、ジョブ全体のホスト接続喪失という段階が異なる。ee6720dの全体427では通常26Aが成功しており、ee6720dと現在d713ed6の製品・全テスト・tools/workflowは同一bytes（差分0）と確認した。現在428の他13事前検査も成功している。
- この新しいホスト障害の注記と同一コードでの成功に基づき、同じd713ed6の通常26Aと依存する公開ジョブだけを新しいhostで独立検証する。製品・QA・SDK・操作・期限や公開ゲートを変更せず、初回失敗を保持する。公開ジョブ自身のAPIゲートが同じrun/attempt/sourceの全必須成功を確認できたときだけ公開する。新規開始前レビューを行い、記録push後に開始する。

## N74 全体428/試行2の公開ビルドがfailure終端（2026-10-22）

- sourced713ed6、run39771133485/試行2、公開job119869233348（SDK27.0）。14:35の予定照会で14:09:09のfailure終端を確認。具体的な段階・原因はログ未取得で未確定。対処前に記録した。N73の通常26Aは新しいhostで13:58:54にsuccessとなり、他13事前検査も成功。公開処理の成否はログを確認するまで断定せず、失敗段階と過去詳細・当時コードを照合してから対処を決める。

- 完了ログの失敗は公開ビルド内のPicker UI。MaterialPickerTapChecks.testReselectionThroughActualButtons、277.719秒、137行のchoose-1 ButtonのwaitForExistence(5)がAX snapshot timeoutになった。直前のchoose-0のCancelと案内消失、navbar/tab/list存在、choose-1.existsとframe取得までは成立。次のButton実tapには未到達。3件中他2件は成功、総377.949秒、IPA生成・公開照合には進んでいない。
- MaterialPickerTapChecks/Picker/Cancel/選び直し/ファイル選択で索引・監査・検証を検索し、N53、verificationの233〜237、U72/N54の実要素再照会の詳細を読んだ。N53は5回目のFiles Cancel不在、今回は次の元リストButton存在照会の停止で、製品presentation未成立とは区別する。233で同一コードの再実行が別段階でも停止した過去も保持し、待ち期限や一般的なAX改善を推測しない。
- 新たに取得したee6720d/全体427のiPhone buildログでは、同じPicker3件と完了件数検査が全成功（本ケース313.966秒）。ee6720dとd713ed6の全製品・テスト・tools/workflowは同一bytesで、Pickerの製品とUI helperは前回公開419からも未変更とgit差分で照合した。最新mainの通常・訂正両OSも全成功している。
- 新しい同一実装の完了ログと今回の失敗段階に基づき、製品・QA・SDK・元3ケース・連続実操作・30/8/5秒の期限・全完了照合・公開ゲートを変えず、公開jobだけを新しいhost/所有Simulatorで独立検証する。初回失敗を保持し、候補を恒常的解消とは呼ばない。同じ停止が再発した場合はこの根拠だけで再実行を繰り返さず、観測方法の修正を改めて評価する。コード差分0行の新規レビューと記録push後に開始する。

- N74後の公開job単独検証/試行3/job119887900316は成功。元Picker3件・全連続操作と厳密な完了照合、Host616件（予定skip1・失敗0）、iPhone Release buildが通過した。公開ゲートは14:58:59に同じrun/attempt/sourceの全必須成功をAPIで確認し、14:59:16に428.3を公開した。N73のhost通信断とN74のAX停止を成功へ書き換えず保持し、恒常的解消は主張しない。

## N75 追加issue 60〜63の初回Python検査（2026-10-23）

- source7e5712cを基点とする未コミット差分、codex/fix-issues-60-63、Debian13／Swift6.1.2、`python3 -B -m unittest discover -s tests -p 'test_*.py'`。264件、failure1／error2／予定skip2。ログ /tmp/followup-ios-python-first.log。
- 対処前の観測: UI manifestのallが29件で、既存の固定期待27件と不一致。通知設定ライフサイクル2件は実ソースから抽出したSwift probeのコンパイル段階でerror。製品のAppleビルド・実UIの失敗と同一視しない。通知probeの具体的なコンパイル診断はこれから照合する。
- Foundationの別実行は544件すべて成功したが、Pythonの失敗を成功へ読み替えない。過去の該当詳細とprobe抽出元、追加2件の登録・必須ゲートを照合してから対処し、次の試行前に記録・修正をpushする。

- N75照合: コンパイル診断はgeneration/pending/reconcileTask/baseline/loadedの未定義。OS bridgeの終端を従来の次メソッドresetForRetentionで探すprobeが、新しく間に置いたsuspendForUnavailableDataも抽出していた。N57の製品throw構文・N68の非同期GRDB呼出しと詳細/旧コードを照合し、今回はprobeの関数抽出範囲の差であると確認した。実bridgeの直後のinstanceメソッドを境界とし、実OSオブジェクト・取消・許可のassertionは維持する。
- manifestは初回失敗資料の警告導線と、破損マーカーの明示確認復旧の2ケースを新設したため27→29へ更新する。2ケースのA登録を個別assertし、全ソース宣言の一意性・両OS・既存公開ゲートは維持する。記録と候補をCI対象外ブランチへpushしてからPythonを再実行する。

## N76 追加issue60〜63のApple検証で複数jobが早期失敗

- ソースc1334875fef47cc444095cc5e7deb2e61fc44a2d、PR64、run39906381266／試行1、2026-10-23。Distribution成功後、iPhone build outside development distribution（120259634159）、iOS27通常UI A/B（120259634156/120259634213）、訂正4job（120259634228/120259634237/120259634242/120259634330）が14〜47秒でfailure終端。iOS26依存jobはskip。Nativeは05:39時点で実行中。
- ログ取得前でコンパイル/実操作のどちらか・原因は未確定。対処方針を決める前に観測を記録する。既存の成功やskipをApple実操作の成功に数えず、残りのjobを取消しせず確認する。

- 完了ログ7件はすべてsimctl createのSimError403／Incompatible device、exit147。訂正ログはiPhone16とiOS27.1（24A94425）を作成できないと明記し、アプリのビルド・実操作へ未到達。SDKはXcode27.0／27A266a。N53の実Files Cancel待機、N68の製品コンパイル停止と詳細/当時のコードを照合し、今回の作成失敗と区別した。SimError/Incompatible device/runtime unavailableの索引検索に同型の既往記録はない。
- runnerがavailableな同majorの最大minorを選ぶため、成功済み428.3の27.0から27.1へ意図せず変わった。候補はshippingSDKと同じ27.0を明示して準備・選択すること。26.5比較、両OS全ケース、期限、厳密な完了照合、公開ゲートは維持する。27.1の下位互換性・恒常的な作成成功は未確定。準備helperは別minorを消さず、既に登録済みの27.0がunavailableなら置換せず失敗し、欠損時だけ所有tempへdownload/importする。

- 元run39906381266は全実job終端。Native627件（予定skip1、112.511秒）成功、Distribution成功、7job失敗・依存skipで公開不可。残りも取消しせず確認した。

## N77 iOS27のruntime選択runner検査の観測一覧が空

2026-10-23、Debian13 / Python3.12.14、source3054127、隔離ブランチcodex/fix-ios27-runtime-compatibility。`python3 -B -m unittest discover -s tests -p 'test_*ui_runner.py'` の19件中、追加test_shipping_27_uses_exact_27_0_when_newer_minor_is_availableだけが失敗。runner自体のexit0 assertionは通過したが、テスト100行のsimctl create件数が期待1に対して0。ログ/tmp/ios-runtime-runners-first.log。準備helperの独立9モードは成功。テストの観測範囲・製品の選択のどちらが原因かは対処方針決定前の時点で未確定。

- c133487のrun_runnerは返却前に観測をxcodebuildだけへ絞っており、新しいsimctl assertionが対象を受け取っていなかった。N75のprobe抽出範囲不一致とN03の追加テストコンパイル失敗の詳細を照合した。今回は実runnerの失敗でもruntime不一致でもない。既存テストの返却契約は維持し、新ケースだけ全コマンド観測を要求する。simctl create1回・27.0必須、他のbuild/boot/実行/回収・欠落拒否条件は変更しない。修正/記録を隔離ブランチへpush後に再試行する。

## N78 追加issue比較の原本変更訂正テストが失敗

2026-10-23、sourcee33a3cd583b62a3945ab5a8a02ce989f4e2ccf0f、run39907749454／試行1、iOS27 / Xcode27.0。testChangedOriginalCannotSubmitOrReplaceLastGoodのjob120264024705が06:02:37〜06:18:13 UTCでfailure終端した。06:30の予定照会で観測し、対処方針の決定前に記録した。完了ログ未読で、失敗操作・下位原因は未確定。他の訂正3件・Native・iPhone/Pickerは成功。通常27 A/Bと依存26は未完了で、取消しは行わず確認する。

## N79 追加issue比較の通常iOS27 Aの画面操作stepが失敗

2026-10-23 06:30 UTCのjob metadataで、sourcee33a3cd／run39907749454／試行1、job120264024511のExercise app screens with synthetic dataがfailure終端、後処理成功・Complete job進行中と観測した。job全体の終端と失敗case/操作は完了ログ未読で未確定。対処方針決定前にこの観測を記録する。残りのjobは取消しせず確認する。

- N78完了ログはNavigation.swift:92の選択済み受動CellのstaticTexts再列挙でUI query timeout、562.561秒・1件失敗。直前に原本変更後の再照合まで進み、受動Cellの実際の子要素を調べた後で同じ列挙を繰り返していた。N54/N59の詳細と5fd0805/e33a3cdの実Navigation/Review/ケースを照合。既知IDの無いsubmit照会とは異なり、今回はスクロール開始点の観測の再取得。候補は1回の実要素/枠観測をその試行内だけ保持し、反転しなければ同じ受動行を再検査しないこと。16操作・包含・hittable・受動条件・反転上限と最終必須確認を維持する。AXの下位原因は未確定。
- N79完了ログは新しい復旧UIケースのSettings.swift:13、復旧ボタンの1回のtap後、Cancelが10秒で存在しない。初期marker=0/old=1とボタンhittableは通過し、確認操作・初期化・復旧の保存には未到達。通常16件中この1件のみ失敗、全体1846.299秒。U30/U63の一回の標準tapが未反映の詳細/旧コードと比較し、今回はタブではなく標準Textボタンであり、実action成立は未確認。候補は現在の実枠・画面包含・enabled/hittableから一回の0.1秒接触を行い、QA生成コピーだけで元のaction成立を数値記録すること。押し直し・状態注入・待機延長はせず、Cancel10秒・前後の実bytes・実初期化・再起動の期待を維持する。製品のconfirmationDialogは推測変更しない。

## N80 手動訂正UIのローカル構造検査で受動行の表記が不一致

2026-10-23、source0e1e81b2af778f97ef9b23065b559c94de0001e4、codex/fix-retention-and-manual-ui-observation、Debian13／Python3.12.14／Swift6.1.2。`test_manual_scroll_navigation.py`は2件と実Swift幾何29条件が成功。その後の`test_manual_ui_project.py`は17件中1件失敗（0.305秒）。`test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps`の295行が`$0.buttons.count==0 && $0.switches.count==0`を要求し、現ソースで見つからなかった。ログは/tmp/ios-n78-project-first.log。製品・実機の実行失敗ではなくソース文字列検査の失敗として、対処を決める前に記録する。後続manifest検査は未実行。過去詳細と旧コードを照合してから修正し、次の試行前にpushする。

- `test_manual_ui_project`検索で対応一覧を確認。N75/N77の詳細とe33a3cdのテスト・Navigation.swiftを読み、旧実装では無名closureの`$0`、現実装では試行内の観測保持に使う明示引数`cell`と確認した。6種の操作可能な子要素を拒否する条件は全て同じで、今回の失敗は引数表記を固定した観測の不一致。3つの文字列検査だけを明示引数へ更新し、6種の拒否・実枠・キーボード回避・16操作の上限・反転制限・必須最終確認は維持する。幾何29条件の実Swift結果と実iOSプローブは別に評価し、この検査の成功を実操作成功の代用にしない。記録と修正を隔離ブランチへpush後に再試行する。

## N81 保存期間マーカー復旧の焦点iOS27が失敗

2026-10-23 06:58 UTCのまとめ照会で、sourcead121935fc86f7f7e585211cdb3cc68df3e106ac、run39913424181／試行1、job120281415571（Relaunch diagnosis iOS27）が06:58:03 failure終端と確認。Xcode27.0／Runtime27.0準備は成功し、Exercise launch…stepが06:45:32〜06:57:55で失敗した。対象はtestRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData一件。完了ログ未読のため、失敗操作・action成立・下位原因は未確定。対処を決める前に記録した。別runの原本変更訂正27はsuccess、26は実行中で混同しない。完了ログとN79/U30/U63の詳細・当時コードを照合し、根拠と変更をpushするまで次の試行を開始しない。
- 最初は限定の復旧1ケースと、同じ原本変更訂正を両OSで比較する。通常29件・元訂正4件×両OS・公開ゲートは維持する。候補/記録を隔離ブランチへpush後にローカル検査し、新規Actions前に同じ開始前レビューへ修正差分を渡す。

- N81完了ログはSettings.swift:16、最初のCancel不在で47.380秒・1件失敗。実枠(89,432.33,215,34.33)・画面包含・enabled/hittableを確認し、一回0.1秒のイベント合成を通過した。N79とe33a3cd/ad121935のコード、U30/U63の詳細と当時の操作を再照合した。接触時間変更だけでは今回の症状を解消しなかった。製品Group上のpresentationか入力未到達かは未確定。
- N81のQA action観測はアプリ側printだけで、xcodebuildのXCTestログにはtargetの標準出力が取り込まれず、既存の所有ファイル採取にも含まれていなかった。N79で必要としたaction成立の証拠を得られなかったため、次は診断比較として同じ実action後とBindingのon/offを既存の所有ファイルへ固定語彙だけで記録・回収する。失敗時に実AX階層もmessageへ残す。製品・操作・Cancel10秒・実bytes・保存・再起動条件は変えず、解消候補として成功を期待した盲目的再試行とは区別する。generatorの元ソース復元一致・挿入点欠落拒否と、採取の本文／symlink／容量拒否をローカルで検査する。記録・差分をpush後に検査し、新規レビュー後に診断を開始する。

## N82 所有ログ観測を追加した復旧診断の操作stepが失敗

2026-10-23 07:16 UTCの予定照会で、source89209ba2ff4eeea4001651e78b100b87f21e9615、run39915334599／試行1、job120287537241、Xcode27.0／Runtime27.0の準備は成功、復旧1ケースのExercise…stepが07:03:46〜07:13:10にfailureと確認。job全体はin_progress表示。action/Bindingの固定語彙を所有ログへ追加した診断条件で、製品・接触・Cancel10秒は前回と同じ。新ログ未読で、action成立と失敗箇所は未確定として対処前に記録した。全終端と所有ログ・AX階層を確認し、過去詳細/コードと照合した根拠をpushする前に次の試行を行わない。

- N82の完了ログでSettings.swift:16のCancel不在を確認（31.184秒、1件失敗）。所有ログは実actionの後とBinding onを記録し、AX階層に可視Popover・確認Sheet・本文・破壊的な確定Buttonを含む。さらに固有のシステム要素PopoverDismissRegion／「ポップアップを閉じる」があり、Cancelボタンだけがない。N79/N81の未確定だった入力未到達／表示未成立という候補と区別できた。89209ba/e33a3cdのContentView・ケース、U30/U63の詳細と旧コードを照合した。今回の原因は確認が出ていないことではなく、標準Popoverで省略されるCancelを必須にしたテストの操作契約だった。製品のGroup・confirmationDialogは変更しない。
- 修正候補は最初の10秒で実確認Buttonの表示とhittableを必須とし、Cancelが実在するときは従来通り一回tap、ないときは一意な実Popoverと固有の実PopoverDismissRegionを必須にする。実枠中心が画面内・Popover外・元の復旧ボタン外でhittableのときだけ一回0.1秒接触し、確認Buttonが10秒で消えることも必須にする。失敗したCancelの押し直しやfallbackではなく、観測された標準表示形式に応じた取消し操作。取消し後の保存bytesと、改めて明示確定した後の初期化・保持・再起動は全て維持する。候補と根拠をpushしてから局所検査し、新規レビュー後に実OSで確認する。

- N82候補の開始前レビューでP2の検証不足を指摘されたため、まだActionsは開始していない。従来のproofは管理マーカーが現在期間か／旧ファイルの有無と、設定・公開・元ファイルの固定値確認であり、「取消し前後bytes一致」という記録は不正確だった。QAだけに実4ファイルのSHA-256観測を追加する。初回と実presentationのcloseを観測した後のhashを比較し、閉じる前の古い画面値を成功へ使わない。実closeカウンターと確認Button消失を同じ10秒で必須にする。復旧完了後も実ファイルを再取得し公開／元ファイルhashが初回と一致することを追加する。観測は状態イベント時に一つの末端Viewだけへ通知し、polling・状態注入・期待値の書込みは行わない。主担当が修正し、同じ未使用の開始前レビューへ差分を再提示してから実行する。

## N83 最新PR全体のiPhoneビルド確認が失敗

2026-10-23 07:49 UTCの予定まとめ照会で、source2ecf52d2850420638c51ec5d490987d6bc97006f、run39917995520／試行1、job120296624941（Check iPhone build outside development distribution）が07:34:27〜07:45:45でfailure終端と確認。SDK27.0／Runtime27.0準備は成功し、Build unsigned IPA and matching AltStore Source stepで失敗。完了ログ未読のため、Native/Picker/端末向け構築の具体的な失敗段階と原因は未確定として対処前に記録した。Distribution267件・Native627件・原本変更27は成功、他の通常/訂正と依存26は未完了。両OSの復旧焦点は各1件success終端。残る実行を取消しせず、新完了ログと過去詳細/当時コードを照合し、根拠をpushする前に再試行しない。

- N83完了ログはMaterialPickerTapChecks.swift:146、testReselectionThroughActualButtonsのchoose-2.isHittableで失敗（240.123秒）。choose-1の実Cancelと案内消失、choose-2への一回スクロール、存在・有限枠・包含の確認は成立。その後の同じButton照会が約31秒間隔で2回繰り返され、次の実tapには未到達だった。元Picker3件中ほか2件は成功、全373.128秒・失敗1。
- 検索語MaterialPickerTapChecks/testReselectionThroughActualButtons/choose-2/Button is not hittable/Pickerで索引と詳細を読み、N53・N74とverificationの233〜237、当時d713ed6のrevealを照合した。N53の実Files Cancel不在とは異なり、N74同様に次の元リスト照会で停止した段階。e33a3cdの最新成功と2ecf52dのPicker製品6入力・テスト・generator・build/runner/workflowは全bytes一致だが、N74は同じ根拠だけで再実行を繰り返さないと記録しているため、同条件の盲目的再実行は選ばない。
- 今回はrevealが同じ試行で得た一意な実Button・有限枠・viewportを保持し、UI操作を挟まず直ちに実hittableを一回確認する観測候補。従来は存在と枠を確認した後で再びwaitForExistence・枠・viewport全体を取得していた。8回のスクロール上限・逆方向の事前移動・30/30/10秒のnative存在待機・最後の5秒存在待機・有限／完全包含・hittable・実tap・元11回の連続選択／Cancelと8/30秒・3ケース完了照合は維持する。一意性と実観測の座標ログを追加し、hittable不成立ではtapせず失敗する。製品・Strict・ファイル取得処理は変えず、下位原因や恒常的解消は未確定。
- 比較には既存test-tools.ymlのpicker入力を用い、配布と同じ27.0を準備して3ケース全て実行する。helperの既存9モード・Picker runner検査と実UI3ケースがSDK準備と操作を覆うため、新しいソース文字列だけの検査は増やさない。workflowをPicker対応表へ追加して一覧を再生成する。記録と候補を隔離ブランチへpush後に局所検査し、新規GPT-6.1 Sol／Highレビュー後だけ比較を開始する。現在の全体runは取消しせず残りを確認する。

## N84 Picker比較workflowの一覧生成で所有元が重複

2026-10-23、source2ecf52dからの未コミットPicker観測候補、Debian13／Python3.12.14。`python3 -B tools/test_catalog.py write`がDuplicate source ownership: .github/workflows/test-tools.ymlでexit1。新しいPicker対応表へ追加したworkflowが既に別groupに登録されていたという観測で、UI実行や候補の局所テストには未到達。対処前に記録した。現在とHEADの所有group・チェック対応を読んで重複と必要な検証の差を照合し、修正・根拠を隔離ブランチへpushしてから一覧生成を再試行する。

- N84照合ではHEADのtest-catalog groupがworkflow全体の単独所有元で、test_test_catalog／manifest／application runnerの既存検査へ対応付けていた。Picker groupへの二重追加だけを取り消し、既存の所有・チェックを維持する。変更するPicker観測コード自体は既存Picker groupの3実UIケース／runnerへ登録済みで、今回のSDK準備helperも既存9モードで確認済み。対応を減らす修正ではなく、誤った二重所有の取消しである。候補全体と記録をpush後に一覧write/checkを再実行する。


## N85 main432の単項目訂正27が失敗

2026-10-23 13:08 UTCの再開時まとめ照会で、source9945e1544cf2b88221952c7fa22e63ca6af0ea82、run39924632738／試行1、job120318445518、iOS27 / SDK27.0 / Runtime27.0、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundの実操作step（08:43:00〜08:56:53 UTC）がfailure終端と確認。ログ未読で、具体的な操作・失敗箇所・原因は未確定として対処前に記録した。全job終端を確認し、取消しなし。main432は単項目27と通常26Bの失敗により手動26／公開が依存skip、公開は未実施。旧PRもPickerと訂正26の失敗を保持する。これから新完了ログを読み、索引の過去詳細と当時／現在コードを照合し、修正根拠をpushする前に再試行しない。


## N86 main432の通常26Bが失敗

2026-10-23 13:08 UTCの再開時まとめ照会で、source9945e1544cf2b88221952c7fa22e63ca6af0ea82、run39924632738／試行1、job120333009228、iOS26.5 / SDK27.0、通常UI Bの実操作step（09:05:55〜09:23:42 UTC）がfailure終端と確認。ログ未読で、具体的な操作・失敗箇所・原因は未確定として対処前に記録した。全job終端を確認し、取消しなし。main432は単項目27と通常26Bの失敗により手動26／公開が依存skip、公開は未実施。旧PRもPickerと訂正26の失敗を保持する。これから新完了ログを読み、索引の過去詳細と当時／現在コードを照合し、修正根拠をpushする前に再試行しない。


## N87 旧PR全体の単項目訂正26が失敗

2026-10-23 13:08 UTCの再開時まとめ照会で、source2ecf52d2850420638c51ec5d490987d6bc97006f、run39917995520／試行1、job120315291565、iOS26.5 / SDK26.6、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundの実操作step（08:19:41〜08:30:36 UTC）がfailure終端と確認。ログ未読で、具体的な操作・失敗箇所・原因は未確定として対処前に記録した。全job終端を確認し、取消しなし。main432は単項目27と通常26Bの失敗により手動26／公開が依存skip、公開は未実施。旧PRもPickerと訂正26の失敗を保持する。これから新完了ログを読み、索引の過去詳細と当時／現在コードを照合し、修正根拠をpushする前に再試行しない。


## N88 旧PR全体の明示選択訂正26が失敗

2026-10-23 13:08 UTCの再開時まとめ照会で、source2ecf52d2850420638c51ec5d490987d6bc97006f、run39917995520／試行1、job120315291599、iOS26.5 / SDK26.6、testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunchの実操作step（08:20:26〜08:36:15 UTC）がfailure終端と確認。ログ未読で、具体的な操作・失敗箇所・原因は未確定として対処前に記録した。全job終端を確認し、取消しなし。main432は単項目27と通常26Bの失敗により手動26／公開が依存skip、公開は未実施。旧PRもPickerと訂正26の失敗を保持する。これから新完了ログを読み、索引の過去詳細と当時／現在コードを照合し、修正根拠をpushする前に再試行しない。


## N89 旧PR全体の原本変更訂正26が失敗

2026-10-23 13:08 UTCの再開時まとめ照会で、source2ecf52d2850420638c51ec5d490987d6bc97006f、run39917995520／試行1、job120315291673、iOS26.5 / SDK26.6、testChangedOriginalCannotSubmitOrReplaceLastGoodの実操作step（08:19:41〜08:30:04 UTC）がfailure終端と確認。ログ未読で、具体的な操作・失敗箇所・原因は未確定として対処前に記録した。全job終端を確認し、取消しなし。main432は単項目27と通常26Bの失敗により手動26／公開が依存skip、公開は未実施。旧PRもPickerと訂正26の失敗を保持する。これから新完了ログを読み、索引の過去詳細と当時／現在コードを照合し、修正根拠をpushする前に再試行しない。


### N85〜N89の完了ログと過去詳細の照合

- N85は表示サイズ変更の実menu操作後、同じ入力を古いAny/firstMatchで存在照会して停止（Navigation.swift:48、422.439秒）。ACKとsubmit=trueは成立。U11/U72/N59の詳細、1b368f5/2a22448/現在のInput・OneCorrectionを読んだ。既知IDを持つclear/reviewと異なり、サイズ変更後のinputだけknownIDを渡していなかった。候補は入力／ACK／submitの既知IDを明示して、その試行の実要素を取得する変更。全包含・hittable・16探索・入力全文・背景／同一process・保存は維持する。
- N88は最初のACK後の古いrow照会が約30秒ずつ停止し45秒待機を消費（255.306秒）。取得後の実AXは外側／内側Switchともvalue1、実診断ack=true、継続行にkind=ackのfalse→trueイベントを含んだ。Binding未発火ではない。U11/U72の詳細と同じ現要素方式へ、各native predicate評価で一致IDの実Switchを一度取得してvalue1を必須にする。期限45秒・一回の実接触・期待値は維持する。
- N87は最初のACKは成功し、背景後の再編集とkeyboard消失・入力全文も成立したが、二度目の接触後は実AX value0／診断ack=false、イベントは再編集までで二度目ackなし（312.742秒）。N88とは区別する。U71/U64/N66の詳細と当時のInputを読み、接触時間・点を往復せず現状維持する。新しい現要素取得で通るとは断定せず、native入力の届き先をQAだけの観測で調べる。
- N89は実clear・全文typing後、完了Buttonの45秒存在待機はtrue、その直後の別配列照会が0件（Input.swift:104、141.889秒）。U72/当時1b368f5と現在の二段階照会を比較し、現在一意な実Buttonと有効・hittable・包含を同じ45秒native predicateで捕捉し、その一個を一回tapする候補。0件で成功扱いせず、曖昧も拒否し、keyboard消失と現在入力全文を必須にする。
- N86は最初のリンク解除の実2秒長押し後に45秒menu不在（84.107秒）。失敗画面127329bytes／SHA256 87935bbd87611075c6cdb4058768a89820350575c273a824c29215ca74ff744eは架空URLのSafariを表示した。一方AXは元の一覧を返しており、画像を照合してprimary actionへの遷移を確認した。U42/U54/N44/N55とverification 7999以降、旧dfb185cの標準Menu変更と現在LinkRowを照合した。Menu(primaryAction:)変更後にも再発した段階。製品や操作点・長押し時間を推測変更せず、QA限定のUIWindow入力観測で実touchのphase／座標／native view classを固定形式だけ記録する。元のsendEventを必ず一回通し、値／状態の代入・gesture追加・再入力はしない。公開製品へ観測コードを含めない。候補・根拠を隔離ブランチへpushしてから局所検査し、新規レビュー後に焦点比較する。

## N90 main433の明示選択訂正26が失敗

2026-10-23 14:58 UTCの予定まとめ照会で、source1d0e4f91aa80d62da09807c835928882bbce077f、run39964623999／attempt1、job120471460199、iOS26／SDK26.6（実Runtimeは完了ログで照合予定）、testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunchの実操作step（14:32:19〜14:46:10 UTC）がfailure終端と確認した。完了ログは未読で、具体的な操作・失敗段階・原因は未確定として対処前に記録する。同じmainの原本変更26はsuccess、ほか通常26 A/Bは継続中で取消ししない。これから新しい完了ログ、過去の詳細記録、当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。

## N91 main433の三項目訂正26が失敗

2026-10-23 14:58 UTCの予定まとめ照会で、source1d0e4f91aa80d62da09807c835928882bbce077f、run39964623999／attempt1、job120471460227、iOS26／SDK26.6（実Runtimeは完了ログで照合予定）、testThreeFieldsRequireEachAcknowledgementAndFourRefusesの実操作step（14:32:21〜14:44:28 UTC）がfailure終端と確認した。完了ログは未読で、具体的な操作・失敗段階・原因は未確定として対処前に記録する。同じmainの原本変更26はsuccess、ほか通常26 A/Bは継続中で取消ししない。これから新しい完了ログ、過去の詳細記録、当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。

## N92 main433の単項目訂正26が失敗

2026-10-23 14:58 UTCの予定まとめ照会で、source1d0e4f91aa80d62da09807c835928882bbce077f、run39964623999／attempt1、job120471460316、iOS26／SDK26.6（実Runtimeは完了ログで照合予定）、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundの実操作step（14:32:19〜14:47:23 UTC）がfailure終端と確認した。完了ログは未読で、具体的な操作・失敗段階・原因は未確定として対処前に記録する。同じsourceの直前の両OS焦点では成功しており、恒常的解消とは主張していない。mainの原本変更26はsuccess、ほか通常26 A/Bは継続中で取消ししない。これから新しい完了ログ、過去の詳細記録、当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。

### N90〜N92の完了ログで確認した段階

全3件の実Runtimeは26.5。N90は最初の科目clearのButton実枠(317,587.33,44,44)・enabled/hittable確認後、一回tapの45秒native空文字待機がtimeout。実診断は元入力「架空科」のまま（Input.swift:80、203.473秒）で、入力／ACKには未到達。N92も最初のclearで同じ枠と条件を通過し、45秒後も元入力「架空科」のまま（Input.swift:80、214.103秒）。N91はNavigation.swift:35のUI照会timeout、132.555秒で、具体的な照会先は周辺ログと現在の行番号をこれから照合する。これらの観測後も対処はまだ選んでいない。原本変更26/job120471460166は405.854秒、clear2回・実ACK・完了照合を通過してsuccess。単一の成功から失敗が解消したとはせず、過去のclear／現要素取得の詳細と旧コードを読んで比較する。

- 検索語clear／消去／contentShape／borderless／Navigation.swift:35／descendantsでN71、U01、U11、N52、N83と該当詳細を読み、fcc6ee2／1b368f5と現行のView・Input・Navigationを照合した。N90/N92はN71と同じ未消去だが、今回は実入力traceがある。実接触はどちらも(339,609.33)のCellHostingViewに届いた後、約0.12秒でcancelled。Bindingは初期draft1件だけでclearなし。同じ実枠で成功した原本変更26の2回は約0.058／0.080秒後にendedと実clearを記録した。U11の「消去は成立した後の古いAX」と異なる。触れた位置の誤りやguard拒否は未確定で、接触時間・点の変更はしない。
- 製品の既存borderless ButtonはImageラベルに44ptのframeだけを持ち、明示したcontentShapeがなかった。候補はその同じラベルの全44ptをRectangleで明示する一行だけ。見た目、Buttonの種類、元action、canClear／draft一致／reviewなし等のguard、値・ACK・focus操作は維持する。hit領域が下位原因だったとの断定はせず、QA生成コピーだけでguard拒否を2つのBoolのhashとして記録し、実clear未発火と区別できるようにする。guardはそのまま残し、値や入力を注入しない。
- N91は最初のroomのclearを探す1回目の実passive Cellドラッグ後、全アプリAny descendantsの一致ID配列照会が約45秒停止した。有限なviewport・受動行の実frameと16探索を維持し、既知のclearだけは同じ復旧Listの実Buttonとして検索する候補。editorのnative型は固定せず他の経路は維持する。重複IDは新たに拒否する。N83と同じく、既にvisibleが確認したclearの直後の重複存在待機を除き、現在の実frame／enabled／hittableを一度確認して一回tapする。45秒の空文字待機・ACK取消し・実keyboard・全文入力・完了・保存は変更しない。AX下位原因は未確定。
- 新しい製品hit領域を扱うため、個別成功だけで判断せず、既存4ケースを各26／27の独立jobで比較する。診断workflowにallを追加して元4件×両OSへ展開し、各caseの元45／35分と厳密な完了照合を維持する。公開workflow・全15必須gateは変更しない。候補と根拠を隔離ブランチへpushしてからローカル検査し、新規GPT-6.1 Sol／Highのimmutable差分レビュー後だけActionsを開始する。


## N93 消去領域比較の原本変更訂正26が失敗

2026-10-23 15:30 UTCの予定まとめ照会で、sourced2b1c40dc9abac4dcb5a1670b6613f1a4501de3f、run39975811589／attempt1、job120489977754、iOS26／SDK26.6、testChangedOriginalCannotSubmitOrReplaceLastGoodの実操作step（15:09:24〜15:25:12 UTC）がfailure、job全体も15:25:23にfailure終端と確認した。完了ログは未読で、具体的な操作・失敗箇所・Runtime・原因は未確定として対処前に記録する。同じ比較の単項目26はsuccess、他は継続中で取消ししない。新完了ログと過去詳細／当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。

## N94 消去領域比較の三項目訂正26の実操作stepが失敗

2026-10-23 15:30 UTCの予定まとめ照会で、sourced2b1c40dc9abac4dcb5a1670b6613f1a4501de3f、run39975811589／attempt1、job120489977827、iOS26／SDK26.6、testThreeFieldsRequireEachAcknowledgementAndFourRefusesの実操作step（15:09:27〜15:30:10 UTC）がfailure、jobはComplete job進行中と確認した。完了ログは未読で、具体的な操作・失敗箇所・Runtime・原因は未確定として対処前に記録する。同じ比較の単項目26はsuccess、他は継続中で取消ししない。新完了ログと過去詳細／当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。


### N93／N94の新しい完了ログの観測

両件の実Runtimeは26.5。N93は最初のclearと全文入力・完了後の全文一致を通過した。ACKの外側実枠(16,646.33,361,52.33)／内側(300,658.67,63,28)・enabled/hittable・包含を確認して一回0.1秒pressしたが、45秒でnative value1にならず、Input.swift:49、227.365秒で失敗。実traceは(331.67,672.67)のUISwitch内部へbegan後、約0.146秒でcancelled。診断は入力「架空変更前確認」／ack=false、clearとtextのBindingはあるがackはない。消去の元guard拒否とも、N89の完了Button消失とも異なる。原因と対処はまだ選んでいない。

N94は最初のroomの実clear・全文入力・完了後の全文一致と、ACKの枠／包含／hittable確認まで通過した。Input.swift:35の一回の内側Switch相対pressを合成する際、無名の「0」Switchを祖先Any一致→配列index0→Switch子配列index0として再解決し、複数のsnapshot query timeoutで止まった。afterログと実ACKへのtouchはなく、45秒state待機にも未到達（326.136秒）。N91のclear探索とは違い、既に取得した内側native Switchの接触前再解決である。同じrunの単項目26は732.497秒・失敗0で元ケース完了照合を通過した。この個別成功を全件の解消とはしない。

検索語ack／cancelled／allElementsBoundByAccessibilityElement／Input.swift:35でU19、U64、U71、N66、N87、N88の詳細とf6e13a6／1b368f5／現行Inputを読んだ。従来は子Switch firstMatchから、現行は配列indexで得た子要素から同じ実中心へ0.1秒接触している。取得後もqueryがindexと親子の経路を再評価することが今回のログで判明した。接触方式自体とN93のcancelled原因は別に評価する。

- N94の候補は既知ACKの検索を同じ復旧ListのSwitchへ限定し、外側と内側の取得にXCTestのallElementsBoundByAccessibilityElementを使う。index位置で祖先を再評価する経路から、実際に観測したaccessibility要素のidentityへ結び付ける。内側の一意性・finite frame・外側とviewportへの完全包含、enabled/hittable、同じ実中心・一回0.1秒接触・native value1の45秒・全文／保存／再起動を維持する。前状態0も接触前のguardへ追加する。追加の診断用exists/frameと二重hittable照会は接触直前から除き、元の実枠・値・enabled/hittableを一回ずつ観測して出力する。
- N93のcancelled原因をidentity取得だけで修復できるとは主張しない。N87/N66の同症状を保持し、接触時間／点を変更せず、次はN94の明確な再解決停止を避ける候補の同じhelperと、残る4ケース×両OSを正式全体で評価する。N93の個別成功を得るためだけの同条件再試行はしない。製品は既に比較中の44pt領域の一行から追加変更せず、Strict・元case・全15必須公開gateを維持する。候補と根拠を隔離ブランチへpushしてから局所検査し、予約済みの未使用main専用レビューに追加差分を提示してから開始する。


## N95 main434の原本変更訂正26が失敗

2026-10-23 17:05 UTCの予定一括照会で、sourceea049e3fd7cdd73874db575ac8236176040a58d5、run39981083179／attempt1、job120538197020、iOS26／SDK26.6、testChangedOriginalCannotSubmitOrReplaceLastGoodの実操作step（16:48:07〜16:55:30 UTC）がfailure、job全体も16:55:37にfailure終端と確認した。完了ログは未読で、具体的な失敗段階・Runtime・原因は未確定として対処前に記録する。新しいaccessibility identity候補を含む同mainの27系はすべてsuccess、26通常A/Bと他の訂正3種類は継続中で取消ししない。新完了ログ、過去詳細、当時と現在のコードを照合し、根拠と候補をpushする前に再試行しない。

完了ログの実Runtimeは26.5。build-for-testingは90.6秒、初回bootstatusは69.5秒で成功。ケースは開始したがManualAssistanceChecks.swift:13の最初のapp.launchがXcode経由の起動timeoutとなり、63.393秒で失敗した。fixture-ready・clear・入力・ACKには未到達。unified-log取得は終了0で、16:53:54のtestmanagerdは対象bundleについてcurrent statesなし／pid0／not runningを記録し、その後の対象アプリの状態更新や初期化ログは含まれなかった。get_app_containerは終了2、xcresultと診断exportは終了0、報告は5件走査・一致0。これだけで未install・クラッシュ・製品原因のいずれとも断定しない。DebuggerVersionStore/no debugger versionも単独では原因を示さない。対処案の選択前にこれらの観測を追記した。

検索語launch／background assertion／cold／SpringBoard／no debugger versionでU40/U41/U49/U59/U65、N61/N62/N72の詳細と710d0c4・d402ed5・2b94d1cの通常起動helper、現行通常／訂正helper・runnerを比較した。N61/N72は初回の非zero pid assertion、U49は保存後、U40は別Runnerであり、今回は最初のXcode起動timeout。現訂正runnerは既にbuild-before-bootで、そこを往復しない。通常のcold起動には前process停止と一回のHome後のSpringBoard foreground／有限frame観測があるが、訂正はbootstatus後に直にlaunchしていた。候補はこの既存の準備を訂正の初回と保存後の一回起動へそろえるQAだけの変更。停止未成立・OS応答なしは失敗し、対象を予備起動せず、app.launchは一回だけ、fixture-readyと全実操作／保存proofは維持する。U49/U59では同準備後にも失敗しており、これをXcode起動timeoutの万能な解消とは主張しない。製品・SDK・install／reboot・XCTest再試行・既存の各期限・全15公開gateは変更しない。未到達だった準備の実状態を次の単一全体実行で観測し、元の失敗は保持する。

## N96 main434の通常26 Aが失敗

2026-10-23 17:30 UTCの予定一括照会で、sourceea049e3fd7cdd73874db575ac8236176040a58d5、run39981083179／attempt1、job120529181970、Application iOS 26 UI A（配布SDK27.0／Runtime26.5を要求）が17:11:02にfailure終端と確認した。完了ログは未読で、実SDK／Runtime・該当case・具体的段階・下位原因は未確定として対処前に記録する。同mainの残る訂正26の3件はすべてsuccess、通常26 Bは継続中。N95の起動準備候補を含む新main435は17:12:48作成で、この失敗を観測する前に開始済み。どちらも取消しせず、新しい完了ログと過去詳細／当時と現在のコードを照合してから対処を判断する。

完了ログではSDK27.0／Runtime26.5、通常16件中15成功・1失敗。testFirstFailedSpecialDocumentsWarnOnHomeAndWeekAndOpenTheirDetailsの63.601秒失敗で、最初の試験詳細表示／戻るは成功し、次の返却資料Buttonを通常tap helperが全画面swipe上下に往復して6探索を消費した。Navigation.swift:59の完全包含assertが失敗し、二番目のButtonのtap前に停止。最終実AXで返却Buttonは(16,742.3,361,52.3)、下端794.6は実tab bar上端769より下にあり、警告とButtonは存在した。起動／警告欠落／詳細アクションの不達とは断定しない。通知区間は基本suite失敗のため未実行。対処候補の選択前に具体的な段階を追記した。

検索語FirstFailedSpecial／Navigation.swift:59／viewport／往復／scrollDragでN47/N60/U05の詳細と、98838f2の当時差分・b9df827/60d71bfと現Navigationを読んだ。N47は除外行、N60は復旧sheetの行で同じ大swipe行き過ぎを記録し、実frameからviewport中心へ上限付きdragを行う既存visibleへ補正済みだが、今回のcaseはそのvisibleで警告Textを出した後、別の旧tap helperをButtonへ使っていた。候補はこのcaseの資料Buttonだけを既存visibleで出し、一意なButton・元5秒存在・完全包含・enabled/hittableを確認して一回tapする変更。6探索と既存の有界幾何を再利用し、共通tap・製品・期待値・詳細往復・保存後起動・公開gateは変更しない。既存geometry7件と元実caseが該当失敗を検出するため模倣テストを増やさない。main435はこの失敗観測前に開始済みでまだ公開可能。候補と記録を隔離ブランチへpushして局所検査するが、稼働中mainを更新せず、その結果を確認してから次の実行の要否を判断する。

## N97 main435の明示選択訂正27が失敗

2026-10-23 17:56 UTCの予定一括照会で、source00bdafc224881baef8ea3aa509a370808410b4ca、run39993209125／attempt1、job120550717406、testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch（iOS27／SDK27.0を要求）が17:38:44にfailure終端と確認した。ログは未読で、実Runtime／SDK・具体的な操作・失敗段階・原因は未確定として対処前に記録する。同じmainの通常27A・他訂正27の3種類・Native・Distributionはsuccess。通常27Bと通常26Aは継続中で取消ししない。旧main434はすべて終端し、26Bもsuccess、N95/N96のため公開skipと確認した。次の候補や再試行を選ぶ前に新完了ログ、過去詳細と当時／現在のコードを照合する。

完了ログはSDK27.0／Runtime27.0、初回HomeとSpringBoard foreground／有限frameを確認し、一回起動後にfixture・選択・実入力とACKを通過。929.310秒でNavigation.swift:60のframe照会が「No matches found for Identity Binding」で失敗した。直前のsubmit=false観測は成功し、その後のteacher ACKを探す新しいvisibleの最初の反復で、外側Switchをaccessibility identityで列挙（t919.21）してからList／Navigation／Keyboard／List枠を照会し、t924.52の同Switch.frameでidentityが見つからなくなった。対象IDはinput snapshotに存在するが、そのidentityの不在と論理的IDの不在を同一視しない。このvisibleの中ではまだscroll／接触しておらず、teacherの次のACKにも未到達。N94の既存index経路から内側への接触合成が停止した段階とは異なる。対処を選ぶ前に事実を追記した。

検索語Identity Binding／ack／Navigation.swift:60／allElementsBoundByAccessibilityElementでU11/N85/N88/N94と旧1b368f5／9cd340eの差分・現Navigation/Inputを照合した。外側は可視化するための論理ID検索、内側は接触する実native identityという寿命を分ける必要がある。候補はviewportの全観測を先に済ませ、外側の既知ID・同ListのSwitch検索をindex-boundで得て直ちにframe/hittableを観測する。内側への一回接触はN94候補のaccessibility identityを維持し、旧global Any祖先の入れ子index接触へ戻さない。これは外側までidentityへ固定した9cd340eとの差を、新しいframe前のidentity不在から選ぶもの。16探索・一意性・受動Cell・全包含・hittable・一回接触・native value1／全文／保存proofの期待と各期限は維持する。N93の取消し原因やOSの下位原因は依然未確定。候補を隔離ブランチへpush後、既存4ケースと幾何・生成／manifest契約を確認し、新規レビュー後だけ次の実行を開始する。

## N98 main435の通常26 Bが失敗

2026-10-23 19:04 UTCの予定一括照会で、source00bdafc224881baef8ea3aa509a370808410b4ca、run39993209125／attempt1、job120576836154、Application iOS 26 UI B（配布SDK27.0／Runtime26.5を要求）が18:31:03開始・18:55:01にfailure終端と確認した。完了ログは未読で、実SDK／Runtime・case・失敗段階・原因は未確定として対処前に記録する。435は取消しなしで全job終端し、選択27のN97とこの不合格のため公開skip。新main436はその観測前18:00:21作成で、訂正27全4種類・通常27B・Native・Distributionの7事前検査がsuccess、通常27Aと通常26Bが継続中でまだ公開可能。新完了ログ・過去詳細・当時と現在のコードを照合してから対処の要否を判断する。

実SDK27.0／Runtime26.5。testHomeTimetableAndWeekCalendarの最初の時間割tabで、一意な実iconの包含／hittable確認と一回0.1秒press後も45秒内にselectedにならず、Navigation.swift:43、132.302秒で失敗した。基本6件中ほか5件は成功し、その後の通知／VoiceOver／文字サイズ区間は基本suite失敗で未実行。実image193401bytes／SHA256 94c94482fccc89fdd3cf3d4533ee98931c7ed652f08a52ffb43e555695f23f5eを43片から所有一時領域へ復元・長さ／hash照合して目視し、実画面・AXともHome選択を確認した。通知panelや別sheetはない。押した実iconは(222.83,780.33,29,25)、barは(0,769,393,83)。このcaseは入力traceの対象ではなく、native touchが届いたview／cancelled等は未観測で、下位原因は未確定。

Native tab／HomeTimetable／時間割／U63でN49/U77/U63と398の詳細、9ffdf0eの当時差分・fd6e42c／現tab helperを照合した。N49/U77は通知設定の対話QA panelがあったが、今回は通常Homeの初回tabでpanelなし。U63のicon中心tap後と同じ選択未反映だが、現状はその後の0.1秒比較条件であり、時間・点を往復させない。現在436はこの失敗観測前に開始した別のN96/N97候補で、tab helper・本case・fixture flagは435と同一bytes。製品・SDK・操作・期待／期限を推測変更せず、追加の同条件再試行を開始せず、既に実行中の436の元必須ケースを最後まで確認する。原因や恒常的解消を他ケースの成功から断定しない。

## N99 追加Issue68/78の修正前回帰確認（2026-10-23）

- source e62359877962a73bfbcb2eecd13944bd927c5527、Debian13/x86_64・Swift6.1.2、学校本番通信なし、`bash tools/test-parsing.sh`の一回目。20:43:50 UTC、SchoolEventsAPITests.testNearLimitPayloadRemainsReadableAfterSavingItsMetadataEnvelope の再読込で failedYears が空でなく、saved[2032] がnil。999,990 bytesの完全架空payloadはdecodeとsaveを通過した。修正案を選ぶ前に記録。期待値の全payload出力が大きかったため、以後は同一性をBoolで比較して失敗ログ量を抑える（同じ完全比較を維持）。
- 20:44:03 UTC、SpecialScheduleTests.testInterruptedEmptySpecialDatabaseCanFinishInitializationWithoutLosingSources は最初のstore作成でinvalidState。原本0件、空SQLiteをGRDBで作成してcloseした初期化中断状態。20:44:12全体終了、546件・3失敗（1unexpected）、実行73.944秒・準備込み241.1秒。両新規ケースのみ失敗（行事2assert、DB1throw）。物理iOS/SwiftUI検査ではない。

- 対処前に検索語SchoolEventsStore／SpecialScheduleStore／missing database／initial／1.000.000で索引を検索。行事のこの境界失敗は既存記録なし。DBはN57詳細と基点f38831e、Issue41修正後・現行e623598を比較した。f38831eは既存欠損でもCREATEし原本を孤児扱いできたため、その再初期化へ戻さない。新候補は原本がなく、sqlite_masterが完全に空かつuser_version/application_idが0の場合だけ初回の二表を単一transactionで作成する。任意の他schema/非zero version/原本ありの拒否とlegacy移行を維持する。行事はpayloadの1MB検証を維持し、保存全体には2048bytesのメタデータ枠を追加、同じ上限をsave/load双方へ適用する。候補・負の対照・記録を隔離branchへpushしてから次のローカル実行を行う。

## N100 追加Issue69/99の修正前回帰確認（2026-10-23）

- 0f97ce8525f3c6208272bf2c84368335a86abc30のsource/testsを隔離コピーしたLinux Swift6.1.2の一回目（`bash tools/test-parsing.sh`、ログ/tmp/takupoke-post436-strings-before.log）。20:53:07 UTC LinksTests.testLateSearchTermsRemainMatchesWithExactPrefixAndSubstringPriorityが後方の完全/前方/部分・かな展開一致で4assert失敗、score=-1。20:53:53 ParsingTests.testCachedStringWeekdayDecodesSpreadsheetEscapesOnceは最初の土_x000D_でweekdayMismatch、printedWeekdayは未復号、calculatedWeekday土。対処選択前に記録。全体は終了待ち。学校本番通信・実機UIは未実施。typed-date/BOM新規回帰7d16c28はこのコピー後に追加され、本実行には含まれない。

- N100全体は549件/5失敗（1unexpected）、実行73秒台・準備込み240.9秒で終了。検索語decodedString／_x000／escape／文字列復号／検索減点／LinkSearchで既存索引を照合したが同じ分岐の失敗記録なし。Issue47〜58検証本文とb781311当時のWorksheet/LinkSearch、現行0f97ce8を読んだ。前回shared/inline/richへの復号追加ではstr分岐が残り、同じ既存decoderをstrへ一回適用する候補とする。検索減点は199までに制限し、完全一致の最小801が前方一致最大800を上回り、部分一致も非負を保つ。元順は現行LinksViewのposition比較を維持。期待値・許容payload上限・数式許可・未復号literal保護を緩めない。候補と記録をpushしてから次を実行する。次の全体は新規typed-date回帰も初めて含めるが、その製品分岐は未変更。

## N101 追加XLSX回帰fixtureの同名ZIP作成で停止（2026-10-23）

- source8d2ad6425fd321167969c714ed0037150b117e58、Debian13/Swift6.1.2の正規SPM。20:59台、testCachedStringWeekdayDecodesSpreadsheetEscapesOnceとtestTypedDateCellsUseTheirWrittenCalendarDateAndBomIsAcceptedが二回目のfixture ZIP作成でCocoa516（同名file既存）。readerの二入力目に未到達。前者の最初のstr復号は成功、後者date-only/BOMの読み取りも成功したが、元の括弧教員を保持するnormalizerへのテスト期待が架空科目Aだけだったため1assert失敗。製品のtyped datetimeはこの実行では未検証。対処選択前に観測を記録。検索/全体の残りは完了待ち。

- N101比較:同名／already exists／Cocoa516で過去索引を照合し同じZIP fixture失敗なし。失敗時8d2ad64と既存testMetadataAndValidatedWeekdayFormulasのindex別URL、testRichTextNumericDatesAndSparseCells（括弧教員自体を除く入力）、testMetadataAndValidatedWeekdayFormulas（括弧を維持する入力）の本文を読んだ。候補は新規fixtureを入力ごとの所有URLへ分け、元の括弧保持を正しく検査するQAだけの修正。製品・数式許可・復号/UTF16期待は変更しない。次から多数の修正を検証する間だけ所有SPM一時領域を一つ保持してincremental buildし、終了時回収する。標準runnerと同じpackage/source/fixture/config/security/cache分離、pinned依存とjobs2を使い、CI cache/artifactにはしない。fixture候補と本記録をpushしてから実行する。

## N102 typed-dateの交差確認で実readerの日付処理失敗（2026-10-23）

- source f82c6bedab4679f145a9852c9e3cb9ae3ae5228aの所有SPM一時領域、Debian13/Swift6.1.2、21:03:52 UTC。fixture修正後の限定3件中、後方検索・str escapeは成功。testTypedDateCellsUseTheirWrittenCalendarDateAndBomIsAcceptedはdate-only/BOM対照後、最初の2032-07-10T00:00:00.000で本番normalizer Dateエラーrow2。Cocoa516はなく入力へ到達した。修正選択前に記録。Windows26と同じt=d生値経路がiOSにも該当した。

- date／typed／XLSX／BOM／Cocoa516で過去索引を検索し、N101のfixture未到達との差と既存testRichTextNumericDatesAndSparseCells、f82c6beのWorksheet/ChangeNormalizer+Datesを読んだ。従来numeric serialだけを暦日に正規化し、t=dは生のままだった。候補はt=dに限りdate-only/ISO datetime全体を検証し、元に記載された暦日を使う。T時刻0〜23/0〜59/0〜59、fraction1〜9桁、offsetはZまたは±14:00まで（14時は00分だけ）。端末timezoneへ変換せず、任意文字列・数式の許可は拡大しない。原文の他欄と括弧教員保持を維持する。次の実行前に候補と記録をpushする。

## N103 名称対応の追加4条件を修正前に再現（2026-10-23）

- sourcebf6d3ec1d38f4b82e0c202528ae5c54ac604d7c6、所有SPM一時領域、Linux Swift6.1.2、21:10:52 UTC、MappingRulesTests15件中追加4件で12assert失敗。完全一致科目のcanonicalがnil、一般規則nilを留学生trueと判定、条件付き教員の幅違いを分離できず、留prefix省略略科のcanonical/末尾教員/留判定も失敗した。既存11件は成功。Windowsの独立Core回帰でも同じ4条件（一般scopeの2対照含む5件）が失敗、既存10件は成功。対処選択前に記録。実学校資料/通信/SwiftUI UIなし。

- N103照合:canonicalSubject／条件付き／international／mapping／留学生で索引検索。N68はMacのasync test書込みawait不足で、今回の動作失敗とは別。b781311と現行MappingRules/Changes、Issue45/47〜58検証、既存testScopedInternationalRuleSurvivesGenericExactAliasBeforeLessonReplacementを読んだ。既存51のクラス専用規則優先を保持する。追加したglobal一般vs専用留学生の対照だけは期待falseが既存仕様と反したためtrueへ訂正する（新規assertの誤り1件、同scopeの一般誤分類とは区別）。候補はまずクラスscopeを選び、その中で生表記完全一致→幅正規化の直接一致→留prefix省略を選ぶ共通候補関数にcanonical/分類をそろえる。一般nilをtrue集合から捨てず、全選択候補がtrueのときだけ留学生判定する。条件付き教員も年度/クラス/科目を維持し生alias完全一致→幅正規化一意候補だけ採用する。元原文や配信規則は書換えない。76の表示件数へ既存teacherContextsを加える低影響の一行変更は、v1空contexts/v2非空の既存decode検査と式の照合を記録し、実装を写すだけのテストは追加しない。Windowsは既に条件付き件数を独立表示し76非該当。候補/根拠をpushしてから再実行する。

## N104 変更/特別授業の追加時計条件の修正前確認（2026-10-23）

- source4f6f7da7ed4f365b8e9aa700d2dc41775091cf5b、Linux Swift6.1.2、所有SPM一時領域、TimetableClockEvidenceTests8件・13失敗（1unexpected）。必要kindが片側未取得でも変更card/common/detailが確定しactive=true（8assert）、非表示の試験時計が返却のcommon時計をnilにする（2assert）、見た目だけ結合した独立特別セルの9:25gapもactive（2assert）。旧4件は成功。新規の通常変更の検証はcustom fixtureのvalidatedでinvalidDataとなり、default含め未到達（1throw）。Windowsは独立Coreで同8ケースが全失敗し、通常変更・補講の10:25/12:25 gapも実再現した。対処選択前に記録。
- 時刻fixtureを読むとv1は1〜8限全件を要求するが、新規入力は2〜5限だけだった。既存testNormalVisualMergesRespectBreaksAndLunchWithDefaultAndDateSpecificClocksの全8限+5分を参照し、今回も8限すべて整合した同offsetへ直すQA変更だけを先行pushする。schemaの制約は緩めず、Windowsのfixtureにも実Validatedを要求する。次は未到達だった通常変更のケースだけを比較し、他の既知失敗を修正なしで再実行しない。

- N104の8限fixture訂正後、source7cffecc・21:20:31 UTCの通常変更だけの限定比較は1件/8assert失敗。default/日付別時刻、変更/補講、10:25/12:25で全てactive=true。validatedは成功し入力まで到達、開始/外側終了の対照は成功。製品の72条件もiOSで実再現した。

- N104対処前照合:ClockEvidence／休憩／昼休／commonPeriodTime／cardTimeで索引を検索し、N51詳細、Issue60〜63検証、b781311とc815640/currentのclockコードを読んだ。N51の非表示変更を先に除く選別は維持。60の元セル全体置換と62の通常カードの個別時限判定を後退させず、今回の別分岐だけ修正する。候補は非表示specialをcommonの根拠から除き（変更の時刻根拠には全必要資料を維持）、APIが要求するkindの欠落時は変更card/common/detailの時計を未確認にする。授業中は普通/通常日の変更を個別時限で判定、特別資料は元の各セルの時計を使い、元の明示連続range全体が含まれるときだけその連続性を保持する。資料間で必要な区間集合が一致しない場合は未確認とし、既知specialカード単体の時計は残す。候補/比較根拠をpushしてから検査する。

## N105 補助store失敗でHomeの正常時間割が隠れる（2026-10-23）

source6c09dfd1151c888c3c3fcff29f846eaf1903e8ed、Linux Swift6.1.2、所有SPM一時領域、21:45:19 UTC。SpecialAvailabilityTests3件中新規testHomeKeepsLoadedLessonsWhenIndependentStoresAreUnavailableだけが18assert失敗、既存2件は成功、unexpected0、0.102秒。通常/特別/行事の全27組合せで、補助storeがloading/failedだと通常資料readyでもHome.ready=false、補助のfailedが主資料のloadFailed=trueになる。SwiftUI実操作はまだ未実行。現行のAND/ORをそのまま抽出した段階であり、対処選択前に事実を記録する。

N105対処前照合:HomeTodayView/loadFailed/学校行事は未取得/FirstFailedSpecialを検索し、N51とN96の詳細、c815640のHome/週表示、現行モデルのloadIfNeededとavailabilityを比較した。N51の非表示変更の優先順位やN96のButton探索は今回の原因ではなく維持する。候補は主資料のready/failedだけで授業一覧を選び、特別/行事の独立した失敗・読込中を同じHome/週へ表示すること。行事ready=falseを未取得と呼ばず、再読込と通常時間割が参考表示である警告を付ける。正常に読み込んだ年度の一部破損もcacheWarningで明示する。元ファイル削除・解析条件・期限・操作helperは変更しない。候補と記録をpushしてから再実行する。

## N106 新しいHome実操作の登録後に固定件数assertが失敗（2026-10-23）

source0c9c460dd997e0be71555a363b64d1541005d7d7、Linux Python3、21:51 UTC。test_ui_test_manifest.py28件中test_all_source_tests_are_assigned_once_and_both_os_checks_are_requiredだけ失敗、4.185秒。登録済み全case数のassertが29を要求し、新規1件を含む実際の30と不一致（line477）。重複/未登録のvalidate_sourceは通過した。Swift構文parseは成功、N105同条件3件も失敗0（0.002秒）。UIは未実行。対処選択前に記録。

N106照合:manifest/固定件数/登録件数/assigned_onceで索引を検索し、N84の所有重複の記録とc815640のmanifest/検査を読んだ。N84は一つのsourceの二重group登録で今回と異なる。今回の新caseは既存source内でAへ一度登録され、両OSの完了照合対象が1件増えたため、固定の総数を30へ増やし、そのcaseのA所属もassertする。元29件、重複/欠落拒否、全15gate、期限は維持する。候補と記録をpushしてから再実行。

## N107 リンク個人設定のエラー消失・修復後の操作不能（2026-10-23）

source8ff6b588f26af64704f357fefb099ea6f22fea4e、Linux Swift6.1.2/Python3、22:05:35 UTC、test_corrupt_preferences_remain_visible_after_revision_success_and_can_be_reloaded。コンパイル成功後の本番LinksModel/Storeで5つの動作assertが失敗しprobeがexit1、Python1件error、2.761秒。revision成功で個人設定のエラーがnilになり、修復したJSONをloadIfNeededが読み直さず、favorite/hidden/colorの全編集が復旧しない。壊れたbytes保持と初回エラー判定は成功。revision通信とUIラッパーだけfake、実ネットワーク/SwiftUI画面は未実行。対処選択前に事実を記録する。

N107照合:同じ検索の過去試行はなく、c815640/currentのloadIfNeeded/revision/changePreferencesとLinkPreferencesStoreを比較した。readyは一覧cacheの準備、preferencesReadyは独立した個人設定である。候補は個人設定エラーを独立したPublished状態へ保持し、一覧ready後も失敗した設定だけ再読込すること。再読込と成功した個人編集だけが当該エラーを解除し、revision/認証結果とは分ける。Home/一覧/取得画面/一覧詳細へ同じ警告と明示再読込を出す。ファイル保持、既存個人値、一覧のエラー・busy・世代取消は変更しない。候補/根拠をpush後に局所検査する。

## N108 原本取得と解析エラーの分類を修正前に再現（2026-10-23）

source5e78e584c3ef661cb9c45c7eda03cb693d2b5a79、Linux Swift6.1.2、22:13:36 UTC、所有SPM一時領域。FileRefreshTests13件とPDFParsingTestsの新規1件、合計14件/18assert失敗/ unexpected0（0.108秒）。無変更抽出の自動更新ループは元PDFのunsupported/page2・変更のdefaultYear・取得tooLarge/accessExpired・取消をproviderReadFailedへ置換し、取消後にも次の対象を処理した。特別PDFの診断wrapperは4種のMaterialErrorとCancellationErrorをPDF unreadableへ変えた。解析エラー自体のcode/page/diagnostic保持の対照は成功。取得/保存workerとSwiftUI実操作は今回の限定検査では実行していない。対処選択前に記録する。

N108照合:providerReadFailed/診断/取得・解析で索引を検索し、N17のローカル完了ログ解析エラー詳細は今回の製品分類と異なることを確認。c815640/currentの自動更新ループ、診断attaching、MaterialWorkerとSpecial側catchを比較した。取得と解析の実エラーはworkerが既に保持しており、外側だけがまとめて通信失敗にしていた。候補は通常の失敗では残りの対象を確認したうえで最初の実エラーをそのまま返し、取消は次の対象へ進めず、その場で同じエラーを返すこと。解析診断は従来どおりtraceを付け、特別PDFのMaterialError/Swift取消だけはPDFParseErrorへ変換しない。前回正常データ、元ソース、Strict、既存attachingのfallbackは変更しない。候補/根拠をpushしてから同じ限定ケースを再実行する。

## N109 所有子孫の取り残しと二回目中止による回収中断（2026-10-23）

sourceec1bfdc11695fec846024c0864d9cd4cb7e0a897、Linux Python3、22:30 UTC。test_parallel_buildは4件中親exit7/TERM無視子孫の新規1件だけ失敗（3.823秒）、関数復帰後もchildが実行中。test_timed_commandは4件中新規の二重signalケースが両wrapperの2subtestで失敗（0.541秒）。初回SIGINTが実childへ届くmarkerを確認してからSIGTERMを送ると143終了、期待した初回130を失いcleanupを完遂しない。正常/単回取消/従来のtimed group検査は成功。各テストfinallyで所有PIDをSIGKILLして回収済み。次の対処選択前に記録する。

N109照合:parallel_build/timed_command/SIGTERM/process groupの索引に同じ二条件の過去試行はなかった。c815640と現行のfinally、既存timedのgroup監視と従来の単回取消テストを比較した。候補はparallelでもleader waitとgroup生存を分け、全groupへTERM後の共通15秒期限で残存をKILLすること。両wrapperは最初のsignalだけを保持し、cleanup中の追加要求では例外を再送しない。通常cleanupに初めて来た中止も記録し、owned回収/handler復元/finishの後にそのコードを返す。productionの15秒・正常/失敗コード・childの通常trap猶予を維持する。候補と根拠をpushしてから再実行する。

## N110 OCR parityのTERMで所有Simulatorのfinallyが実行されない（2026-10-23）

sourceb4405cff33652aea163a52ec868e6697504a9cb3、Linux Python3、22:37:35 UTC、新規test_term_during_create_and_boot_removes_only_the_owned_device。両compare×create応答前/boot後の4subtestが全て-15終了で失敗（1件/4fail、0.180秒）。実mainのowned-device try/finallyを無変更実行し、fake create以外のshutdown/deleteへ到達しなかった。Apple commands/bootだけfake、モデル準備・実Simulatorは実行していない。probe自体は全回収済み。対処選択前に記録。

N110照合:SIGTERM/所有Simulator/compare.pyの検索から従来のboot準備・shutdown失敗対照と今回N109のsignal中断制御を読み、c815640/currentの両mainと共有remove_owned_simulatorを比較した。従来のboot準備は今回の既定TERM終了とは別。候補は作成前に所有処理のsignal scopeを置き、作成応答からUDIDを受け渡すまでは取消を記録だけにして、所有ID確定後にunwindすること。cleanup開始後の追加signalは記録・最初の終了コードを維持し、process終了処理やstderr取得に失敗しても所有Simulatorのshutdown/deleteを試みてからhandlerを戻す。実Runtime/boot期限/推論/成功条件・未所有deviceは変更しない。候補と根拠をpush後に同じ独立process検査を再実行する。

## N111 入れ子・共有研究コードのworkflow対象漏れ（2026-10-23）

source8b5ffd81b1be1a1fa59c443ce13747c2a5d0079f、Linux Python3、22:45:55 UTC、test_workflow_source_paths3件中9subtest失敗、0.002秒。実push pathsを読み、単一*が/を越えない既知のGitHub仕様で照合した。開発用の入れ子2入力、英字研究の共有3入力、V6 parityの共有4入力が非選択。root単層のpy対照は成功。実Actionsは開始していない。対処選択前に記録する。

N111照合:workflow/paths/発火対象で索引を検索し、従来の手動workflow名照合の記録は今回のpath漏れとは異なる。c815640/currentの3filtersと実read.py/run.shの共有import/requirements/prepare/framesを比較した。候補は開発用をtools/**へ、英字研究を実共有code_tailとWindows共通toolsへ、V6を実Windows共通toolsへ広げること。両parityへ新しい所有Simulator取消テストのpathと実行も追加する。branch制限、公開全15gate、実推論と数値/Runtime条件、期限は変えず、現在の隔離branchへのpushはActions対象外のまま。候補/記録をpush後に対象選択検査を再実行する。

## N113 追加修正群のPython全体検査で1件失敗（2026-10-23）

source c18c13887cc4f6de4611b5241acd393d287022b0、Linux/Swift6.1.2/Python3.12、全体unittest初回275件/失敗1/skip2、62.517秒。Swift全体564件は失敗0（76.632秒）。失敗ケースと段階はログを次に照合する。Actions/Apple UIではない。修正方針は未選択。全ログは所有ローカル/tmp/takupoke-ios-c18-full-python.log。

N113追加観測/照合:失敗はtest_document_matches_every_fixed_source_branchの文書一致。75/86でPDFDiagnostics.swiftへ5行の型保持helperが加わり、R032の参照行だけL100→L105へ移っていた。実際の生成差分は当該リンク1行だけ。旧aa6450fのattachingと現在の同methodのR032条件は同一。索引のcatalog/一覧でN84（所有重複）とN106（追加件数）の詳細を読み、今回の行番号生成漏れと異なることを確認。候補は既存generatorで一覧を再生成する文書修正のみ。解析規則・番号・テスト期待を変えない。隔離branchへpush後に一覧の2件を再確認する。

## N114 detached前処理の親取消が非同期境界へ届かない（2026-10-23）

sourcee2f83a6＋未commitのCancellationLinkedTask/2件回帰、Linux Swift6.1.2。既存と同じworker.valueをawaitするprototypeで、2件中1件が2.003秒で失敗。workerが30秒の非同期sleepへ入ったことを同期し、その後親をcancelしても取消/cleanupのexpectationが2秒内にfulfilledしない。finally相当のテスト末尾で所有workerを明示cancelしてjoinし、成功/元のエラーの対照は通過。Visionの実停止やメモリ時間の測定ではない。次の方針選択前に記録する。

N114照合:detached/非active/取消で既存復旧policyとN109/110の所有cleanup記録を検索。N109/110はOS子process/Simulatorで今回のSwift taskとは別。aa6450f/currentの前処理awaitと、同Coordinatorのモデルworkerの既存withTaskCancellationHandlerを比較した。前処理だけ同じ取消接続が欠ける。候補はworker handleを保持し、親取消からworker.cancelを呼んでvalueの終了待ちを維持する共通Foundation helperへ渡すこと。既存control/operation/保存直前checkと旧task待ちは保持する。Vision内部の取消対応/実停止時間はApple環境で別確認であり、非同期sleepの通過で代用しない。候補と根拠をpush後に2件を再実行する。

## N115 学年の交差回帰fixtureが同名ZIPを再作成（2026-10-23）

sourceb741b1c＋未commitのWorkbook回帰、Linux Swift6.1.2、1件/予期しない失敗1、0.011秒。grade1の初回ZIP/parseは成功、次loopの同名fictional-grade.xlsx作成がCocoa516/File existsで失敗し、先頭ゼロのparserへ未到達。製品の学年不具合の証拠には使わない。既存ParsingTests.writeとTypedDateCellsのURL生成を比較し、ZIP writerは新規専用、従来loopはUUID付URLを使う。fixtureのURLだけ各loop固有へ変更する候補をpush後に再実行する。期待class/全展開/原本内容は維持する。

## N116 先頭ゼロ学年が「全」展開と選択classで一致しない（2026-10-23）

sourceb0b83e0、Linux Swift6.1.2、独立XLSX ZIP→実Reader/Normalizerの1件が0.015秒でunknownAll/row3に失敗。grade1は通過、grade01のCN行とgrade1の全行でknownのkeyが一致しない。Winも同じ7条件中5失敗（200ms）、1/1.0だけ成功。N115の重複ZIP作成は固有URL候補で解消しparserへ到達。次の修正選択前の観測で、実機/実資料の頻度は未検証。

N116照合:years/学年/UnknownAllで索引を検索し、今回の先頭ゼロに対応する以前の試行はない。aa6450f/currentの単一年の戻り値と既存rangeのString(Int)を比較した。双方ともIntで範囲検証後に生tokenを返す単一年だけが不一致。候補は検証済みIntを文字列へ戻し、rangeと同じ標準keyへそろえる。元のAI、全半角正規化、小数.0の前段number、拒否範囲と全展開は保持する。iOS解析版8→9、Win7→8として旧cacheを再解析対象にする。対処/根拠をpush後に架空ZIP回帰を再実行する。

## N118 通知の拒否警告が通常の照合成功で消える（2026-10-23）

source4905b9d＋未commitのactual-method回帰、Linux Swift6.1.2/Python3.12。checkPermission/OS callback bridge/deliveryAllowed/applyの製品本文をそのままコンパイルし、OS応答とsnapshot/storage境界だけstubにした。初回1件が1.592秒で失敗。拒否の確認→baselineのみのapply成功の直後に、拒否警告保持のpreconditionが失敗。実OS設定操作/SwiftUIではなく、権限を回避して配信したとの主張でもない。先に観測を記録し、対処は次に選択する。

N118照合:checkPermission/deliveryAllowed/拒否警告で索引を検索し、以前の許可callback/通知サービス拒否の詳細とaa6450f/currentの許可確認/apply末尾を比較した。以前のcallback輸送は実OS値を保持するため維持する。今回は保存/送信エラーと許可エラーが同じmessageを上書きする状態設計が原因。候補は独立したpermissionMessageを追加し、checkPermissionと配信可否の同じOS読取りで更新すること。apply成功は従来の保存/送信messageだけ解除し、両OFFはOS照会を省いてpermissionMessageを解除する。画面復帰時に同じcheckPermissionを実行し、保存したON/OFFは書き換えない。WindowsはStatusが実OS SettingLabelと独立DeliveryStateを合成し、今回の一つのmessageを消す経路とは異なる。候補と根拠をpush後に回帰を再実行する。

## N119 通知診断の収集上限とFloat32研究比較の未検出（2026-10-23）

source250f4af＋追加実境界回帰、Linux Python3.12/NumPy2.3.5。2件/3assert失敗（0.064秒）。collectの実log呼出しを6MiBの架空stdout子processへ接続するとcaptured=6291456文字で4MiB+1の上限を超過。ASCII比較は0.05直前Float32と丸め後Float32の両方向で本番selectorの判断が異なるのにcompare_rejectが例外を出さない。実Simulator/実OCR/実学校通信なし。対処選択前の観測記録。

N119照合:notification_service_trace/4MiB/reject/Float32で索引を検索し、N58時点の診断limited記録と現observe_commandの匿名spool分岐、旧aa6450f/currentのcollect/compare_rejectを比較。N58は大容量ログの証拠欠落で、収集前メモリ上限は未検証だった。候補82は既存のmax_bytes=4MiBを通知logにも渡すだけとし、既存fake OS境界は匿名fileへの書込みを再現する既存spooled_responsesへ接続。期限/失敗/形式不正/limitedの分類と機密出力拒否を保持する。候補97はselectorと同じPython floatへ変換後に0.05を照合し、独立の数値差/shape/finite/unit-domainとbyte照合は維持する。両方とも研究・診断toolであり、アプリ認識品質や実Vision取消の成功を主張しない。候補と根拠をpush後に関連全検査を再実行する。

## N120 完全被覆の密なOCR画素が照合の処理上限に達する（2026-10-23）

source1f69939＋追加RecoveryBuilder Raster回帰、Linux Swift6.1.2。1000x1000/2000文字領域/96000黒画素、query全体、順序正逆×未取得1画素の有無4条件すべてPDFParseError.limit（1件/4unexpected、11.449秒）。同期取消対照は保持。完全被覆の条件もlimitとなることを観測した。Builder/Vision/実機の測定ではない。対処選択前に記録する。

N120照合:hasUncoveredInk/RasterCoverage/32_000_000で索引を検索し、該当する密な文字面積の以前の試行はない。aa6450f/currentのmask優先・pixel-center・±1比較と既存rule mask/取消/上限回帰を比較。候補は最初の未maskインクでだけquery範囲の文字被覆maskを有界構築し、各画素の全box探索を置換する。全てruleで覆われた場合は文字maskも作らず、既存mask優先を保つ。構築とscanは同じ32Mと128workごとのcheckを共有し、pixel-center/±1/union/順序を変えない。

既存上限ケース「2000個の領域外box＋全queryの1box」は、実際には完全被覆を二乗探索で落としていたため、新実装では安全な成功を確認する対照へ変更する。上限自体は同じ2000個のquery全体boxでmask構築32Mを超える独立対照を保持し、単なる上限引上げで通さない。元の未取得画素/罫線変更/取消/小数境界も維持する。候補と根拠をpush後に関連Raster回帰を再実行する。

## N112 main437のiOS27通常UI Aが失敗（2026-10-23）

sourceaa6450f3a3487f4ac08ffce1e0b8b79a58302b07、run40030800385/attempt1、job120678859899、Application iOS27 UI A（SDK/Runtime27.0を要求）が22:42:35 UTCにfailure終端、22:55予定照会で確認。ログは未読で実SDK/Runtime・case・失敗段階は未確定。27Bと27訂正4件、Distribution/Nativeはsuccess。依存する26A/訂正26はskip、26Bは22:46:29開始で継続、取り消さない。新失敗の詳細と過去記録/当時コードを照合する前に対処を選ばず、元公開sourceを別worktreeへ固定する。

N112完了ログ:SDK27.0、通常suite17件中16成功・新規testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecoverだけ93.013秒で失敗。最初の一回app.launch後、automation session9.94秒→idle69.99秒→foreground71.00秒の間に「jp.n624.takupoke.app-checks crashed」とXcodeが報告した。fixture-ready・警告・再読込・授業card・復帰操作には未到達。debugger version lookup警告だけから原因を選ばず、fixture seed/初回起動と現実のcrash詳細を比較する。

N112照合:最初のpid12327のlifecycleは22:17:05のinit-enter/seed-enterだけでseed-completeがない。現行ApplicationFixtureの新caseだけはweekday1〜7で通常analysisを作るが、MaterialLibrary.validPDFAnalysisの通常契約は1〜5だけであり、seedのsavePDFAnalysisが投げるとApp.initがfatalErrorする。N95のXcode起動timeoutとはseed到達と入力制約が異なる。c815640/aa6450f/currentの通常fixture、保存validation、既存EventsYear/Selectionの日付overlayとN95詳細を比較した。候補は週末行を元の1〜5へ戻し、このcaseだけ既存と同じ一時projectの日付overlayで表示日を月曜へ固定すること。破損注入flagとは別のday flagを再起動にも残し、原本復帰後も同じ正常授業を確認する。製品の平日制約/エラー処理/既存操作・期限・全30 UIケースと全15gateは変えない。既存の実caseが初期化・警告・詳細・復旧を検証するため、曜日条件を写すだけのテストは追加しない。新focus groupはその元case1件を各OSのshippingSDKで比較するだけ。候補と根拠をpushしてからlocal/新規immutable review/Actionsへ進む。

## N117 補助store復旧の焦点比較が両OSで失敗終端（2026-10-23）

source0379c19ab3381f8c537a5ad06905489cc7cac463、run40037895971/attempt1。job120701760934 iOS27/SDK27.0は23:08:11〜23:22:08、job120701761145 iOS26.5/SDK27.0は23:08:11〜23:18:46でfailure。auxiliary-storeの元caseを1件ずつ要求、失敗の具体段階/原因はログ取得前で未確定。旧main437は未公開で残る26Bを継続し、Actionsは取消ししない。対処方針を選択する前の観測記録。N113〜116は別の追加修正branchで予約/記録済み。

N117ログ観測:両OSともseed-complete/fixture-readyへ到達し、実warnings表示、両再読込、Home授業card操作と「授業詳細」の実表示/科目確認まで成功。27のケース59.162秒、26は60.633秒。次のback(to:たくポケ)がNavigation.swift:9でnavigation bar内の先頭Buttonを探し、Buttonが0件で失敗。次の時間割tab/復旧後relaunchへは未到達。N112のseed失敗とは段階が異なり、通常weekday1..5の候補は両実Runtimeでseedを完了した。

N117照合:back/dismissLesson/sheet/授業詳細で索引を検索し、週calendarを詳細sheet消失まで待つ既存記録とN60のsheet内viewportを読んだ。Homeの旧c815640/currentはList-hostのsheetで授業詳細を表示し、pushの戻るButtonを提供しない。c815640/currentの既存dismissLessonは同じ実navigation bar中央から標準sheetを一回下方dragする。今回の新caseのback呼出しだけがpresentationと不一致。候補は既存dismissLessonへ置換し、詳細barの消失（元backと同じ10秒）とHome画面復帰を明示確認すること。製品、入力/再読込/復旧/relaunchの期待、SDK/期限/公開全15gateは変更しない。候補と根拠をpush後に局所検査し、毎回新規review後に焦点比較する。

## N121 統合候補のローカル全体でSwift/Python各1件失敗（2026-10-23）

source7559e271661bfe4687672f30a3bc41d78c376968、Linux Swift6.1.2/Python3.12。Swift569件中1失敗（69.260秒）、Python278件/skip2中1失敗（61.752秒）。Python末尾はDisabled permission branch insertion point missing、個別ケースとSwift失敗段階は詳細ログを次に照合する。対処方針未選択、公開Actionsは未開始。既存統合レビューは静的のみで、この失敗の通過とは扱わない。

## N122 旧main437の残るiOS26 UI Bが失敗終端（2026-10-23）

sourceaa6450f3a3487f4ac08ffce1e0b8b79a58302b07、run40030800385/attempt1、job120694621118、SDK27.0/Runtime26.5、22:46:29〜23:25:34 UTCでfailure。23:39の予定照会で確認。具体ケース/失敗段階はログ取得前で未確定。旧runの27AはN112として失敗済みで未公開、全jobを取消しせず終端確認した。新しい公開候補の次のActionsは詳細と旧/現コードを照合後に選択する。

N121詳細/照合:Swift失敗はRecoveryBuilderTests+Calibration.swiftのtestRasterRuleGraphStopsAtItsComparisonBudgetAndChecksCancellationInsidePass:229。graph上限/取消は成功、その末尾にある「2000個の範囲外box＋全query1box」の旧二乗探索上限assertだけが新maskで成功した。N120で更新したRaster専用ケースと同じ入力がCalibrationにも残っていた。aa6450f/currentの両回帰と実maskを比較し、同じ32M構築超過（query全体のbox2000件）へこの重複する上限入力も合わせる。graphの検査は変えない。

Python失敗はtest_notification_readiness_probe_observes_os_without_granting_or_saving。94でcheckPermissionの拒否状態が独立し、QA generatorの旧message/deniedMessage枝への挿入点が消えた。N75/N77のQA挿入点不一致の詳細と旧/現在のinstrument_notification_permission、実checkPermissionの差を照合した。新permissionMessageをクリアする実disabled枝へ観測を移し、値/許可/returnは元sourceどおりに復元できる既存roundtrip検査を維持する。production guardは改行するだけで動作を変えない。候補と根拠をpush後に該当回帰を実行する。

N122追加観測/照合:26Bは基本6件625.297秒、設定詳細339.720秒、setup/文字サイズ3件153.810秒、VoiceOverの完了まで通過。最後のtestNotificationControlsAndAppearanceが308.650秒、Notifications.swift:182で再起動後の「メインカラー/青」rowの即時existsに失敗した。通知許可/両ON/再起動保持と緑/既定解除は成功。青への一回tap直後は保存値を観測せずterminateしており、tapの成立と保存前/保存後のどこで失敗したかは未観測。failure時の実stored-color/AX/画面も採取していない。

theme-probe/mainColor/青/NotificationControlsで索引を検索し、N49の同case初回tabとU53の再起動後Switch取消の詳細、c815640/currentのColor.save/Picker binding/fixture/全caseを比較した。前二例とは段階が違い、Color.saveは同期のUserDefaults操作、現caseは既定解除だけ10秒の実保存待機を持つ。次は診断として青でも元と同じ10秒の保存確認をterminate前に要求し、元の再起動後row/保存blueのassertも保持する。未保存ならその場で実状態/画面を採取して失敗し、押し直し・保存値の注入・再起動後条件の緩和はしない。製品や接触点/SDKを推測変更しない。候補/記録のpushと新規review後に小さい両OS比較で確認する。

## N123 通知・外観の焦点比較が失敗終端（2026-10-23）

source8a72f725cb82a5f10ef9a5c04547c663243ae9d8、run40041293112/attempt1、23:43:54〜23:50:34 UTCでfailure。23:58の予定照会で確認。testNotificationControlsAndAppearanceを両OS/SDK27.0で要求した実行で、具体job・実Runtime・caseへの到達と失敗段階はまだ未確認。対処案を決める前の観測記録。main公開は開始しておらず、先に用意した公開reviewはこのまま別のActions開始へ転用しない。

N123ログ観測:job120712733334（27）は23:43:58〜23:45:15、job120712733549（26）は23:43:58〜23:50:33、両方とも生成AppChecksのbuild-for-testingでPDFRecoveryCoordinator.swift:123の「cannot find 'CancellationLinkedTask' in scope」。両SDK要求は27.0、Simulatorのcaseは未起動で、N122の青選択/保存/relaunchには到達していない。SPMのhelper検査成功とアプリ生成targetへの登録は別の境界だった。原因と対処は過去記録と明示source一覧を次に照合する。

N123照合:scope/compile/登録漏れで索引を検索し、N03（テストのthrows記述）・N67（SPM対象外UIの型契約）の詳細、aa6450f/現在のpbxproj、b741b1cの追加差分とapp_test_project.generateを読んだ。今回helperはSPMのsourcesだけに追加され、本番pbxprojのfileRef/group/source phaseには追加されていない。UIとManualの一時projectは本番projectのtargetを継承するため両方へ影響する。候補は本番targetの3参照へそのファイルを登録し、既存の配布Python検査へ全production Swiftファイルと実application targetのsource phase/group/buildFile/fileRefの対応を照合する回帰を追加すること。中止処理本体・実タップ・保存・再起動・SDK・期限・全15gateは変更しない。前の公開用reviewは未使用で破棄し、候補/記録を隔離branchへpush後に局所チェックと新規reviewを行う。

## N124 main438のApple Native検査が失敗（2026-10-24）

source9298ebeffc4919917d8b677c33778b0122a81914、run40044133872/attempt1、job120722273881、macos-26/Xcode26.6を指定したNative PDF and recovery testsが00:18:03〜00:20:27 UTCでfailure、00:30予定一括照会で観測。具体case/段階/原因はログ未確認で対処未選択。Distribution成功、27通常A/Bと訂正3件は実行中、訂正もう1件はqueue。公開条件は満たさず、残る全jobは取り消さず結果を確認する。

N124ログ観測:RecoveryBuilderTests+Raster.swift:241/247のnumeric literal memberでexpected named member of numeric literal、テストmoduleのコンパイル段階で停止。新しい浮動小数境界のケースを含むNative実テストは未開始。ローカルSwift6.1.2全569件成功との言語/生成ソースの差を次に照合し、製品のOCR画素結果の失敗とは断定しない。

N124照合:numeric literal/nextUp/nextDown/コンパイルで索引検索し、N03（追加テスト構文）・N67（SPM対象外の型）の詳細、aa6450fと境界追加616c548/現行テスト、test-parsing.shの原本コピーを比較。今のテストは5.5.nextDown等を使い、ローカル6.1.2では通ったがApple側はliteralのmemberとして構文拒否する。生成による文字列置換はない。候補は4つのmember receiverをDouble(5.5)/Double(2.5)と明示するだけで、隣接Doubleの値・比較順・4辺・製品本体・入力数・上限・取消を変えない。既存の同じ境界ケース/Raster7件で検証し、構文修正を写す別テストは追加しない。候補/根拠を隔離branchへpush後に検証し、新規reviewで次の公開開始を判断する。

## N125 旧main438の原本変更訂正ケースが失敗（2026-10-24）

source9298ebeffc4919917d8b677c33778b0122a81914、run40044133872/attempt1、job120722273968、iOS27指定のtestChangedOriginalCannotSubmitOrReplaceLastGoodが00:30:48〜00:41:50 UTCでfailure、00:46予定照会で確認。具体SDK/Runtime・case内失敗段階・原因はログ未確認、対処未選択。旧438の別訂正3件は成功、通常A/Bは継続。新439は本失敗を観測する前にテストの数値構文だけ変えて開始済みで、同じ訂正caseが00:42:51から実行中。新実行を修復済み/再発なしとは扱わず、残jobを取り消さない。

N125ログ観測:caseは00:38:37開始、152.706秒で失敗。ManualAssistanceChecks.swift:45の最初のapp.launchがXcode経由起動timeoutとなり、fixture-ready/入力/原本変更/保存拒否へ未到達。diagnosticsはoriginalExit65、inputDeliveryLines0、reportsScanned7/matchingTextReports0、owned-app-unified-logは15.09秒timeout、crashCause=unassessed。debugger nil lookup警告だけで原因を断定しない。新439の進行中caseは同じ製品/起動経路のままで、結果を待って比較する。

N125照合:原本変更/launch timeoutでN95の詳細と当時/現在のManualAssistanceChecks.launchを比較。今回はSDK27.0/Runtime27.0で、home-once後SpringBoardのstate4とframe393x852を確認しreadyを出した後に最初のtarget launchがtimeoutとなった。N95対処のsystem UI事前確認は既に現行へ含まれ、その確認の成功だけではtarget起動を保証しなかった。N112のseed-enter/fatalErrorとは実ログ到達の根拠が異なり、本件はapp内crashの証拠を得ていない。新439との当該製品/fixture/launchコード差分は空。新しい対処はまだ選ばず、既に開始済みの同caseの終端を待つ。

## N126 main439の単項目訂正27が失敗（2026-10-24）

source2a81f3aeb27b895744a6a8168291a2f9bfe24283、run40045677219/attempt1、job120727168151、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground/iOS27指定が00:38:30〜00:50:12 UTCでfailure、01:05の予定照会で確認。具体SDK/Runtime・失敗段階・原因はログ未確認、対処未選択。Three/Changedはsuccessで、N125の原本変更caseは同じ製品/起動コードの新439で通過したが、旧失敗原因の解消とは断定しない。通常27A/B・Selectedは継続し、取消ししない。

N126ログ観測:実case255.205秒。初回入力/ACK=trueと最初のpreview、背景復帰後の再編集操作には到達したが、ManualAssistanceChecks+Navigation.swift:59でmanual-ack-cell-1-0:0:subjectのisHittable判定が「Activation point invalid and no suggested hit points based on element frame」。当該接触操作へは未到達。inputDeliveryLines30、unified logは15.24秒timeout、crashCause=unassessed。N125の初回起動timeoutとは段階が異なる。ヒット判定前のframe/viewport/再query順と過去記録を次に照合する。

N126照合:Activation point invalid/hittabilityでU10の受動footer照会とN97のrecycled identity詳細、当時と現在のNavigation/ManualAssistanceGeometryを比較。今回は最初のACKは成功し、同じ原本を再確認後のreeditで、外側targetのframeは取得したが値を出さず、包含確認より先にisHittableを呼んでいた。N126時点の枠の正確な値は未観測。既存manualVisibleCandidateは有限/正の枠とviewport全包含を先に確認し、境界外/無効な候補ではhittability closureを呼ばないことを実Swift幾何検査で確認済み。

候補は通常targetもこの既存helperへ接続し、取得済みの同じframeを使って範囲外/無効なSwitchへのhit問い合わせを避けるQAだけの変更。問い合わせ前に実frame/viewportを記録し、包含済みtargetでは元のhittabilityを必須のまま保持する。16探索・受動Cell移動・接触の一回性・ACK/native値・全文/再編集/背景/保存/relaunch・各期限・全15gateは変えない。既存のhelper幾何ケースと元の単項目実UIケースが検出するため模倣テストは足さず、候補/根拠を隔離branchへpush後に局所検査と新規review、焦点比較で確認する。

開始前の追加照合:acknowledge(_:)の実本文は外側rowから唯一の内側native Switchを取り出し、inner/outer/viewport全包含・enabled/hittable・未確認値0を必須にして一回だけ接触する。外側rowは接触するcontrol自体ではないため、その受動探索に別のactivation pointを要求する必要はない。候補を具体化し、ACK rowに限って有限/全包含の実枠で発見を完了し、実際のinnerの全hit条件と状態確認をそのまま残す。通常Button/入力の発見では既存helperのhittabilityを維持する。最初のgeometry-only reviewは未使用で破棄し、実inner検査のコードcontextを含む新しい不変diffを別の新規reviewへ渡す。製品/期待値/期限/回数は変更せず、再度局所検査してから焦点比較を始める。

## N127 main440の通常画面26 Bが失敗（2026-10-24）

source1c3318181f9ba0cb1ed953079e9ba0240497a475、run40051510584/attempt1、job120753784746、Application iOS 26 UI B（Runtime26.5/SDK27.0指定）が02:28:37〜02:40:11 UTCでfailure。02:55予定照会（実取得02:54台）で確認した。Exercise app screens with synthetic dataは02:30:18開始で失敗。具体case・失敗段階・実OS/SDK・原因はログ未確認で対処未選択。通常27 A/B・Native・訂正27の4件・訂正26の3件は成功、通常26 Aと訂正26の明示選択は継続。公開条件を満たさず、残る実行を取り消さない。対処案を選ぶ前の観測記録。

N127ログ観測:実Runtimeはcom.apple.CoreSimulator.SimRuntime.iOS-26-5、Xcode27でbuild-for-testingは成功。所有Simulator ADB2FB25-A89F-4B97-B68C-6E3EE68FAF18のbootstatusはFinished、App simulator boot区間125.1秒。続くtest-without-buildingのdestination解決で「Unable to find a device matching」「no available devices matched」となり、compatible一覧はgeneric iOS Simulatorだけで具体deviceがない。02:37:24〜02:39:19のApp UI区間114.3秒で終了し、XCTest caseは未開始、TAKUPOKE_LIFECYCLEはcapture-unavailable。アプリ操作/通知/青保存のassert失敗ではない。所有deviceの消失/利用不能の原因は未確定で、起動済みという先行観測だけから後続の可用性を保証しない。過去のdestination/boot/host記録と、当時・現在のruntime準備/実行scriptを次に照合する。

N127照合:destination/Unable to find/no available/bootstatus/CoreSimulatorで索引検索し、N07・N76・N73/N74の詳細と当時のrunnerを読んだ。N07は全device一覧の停止、N76は別minorのsimctl create拒否、N73はhost通信断、N74はPicker実操作中のAX停止で、本件と同一原因とはしない。現行のcreate→停止中build→bootstatus→実UDID test-without-buildingはN73時点から同じ順序で、N76対処のruntime選択は26側を変更していない。直前439/source2a81f3aと今回1c331818の全差分は文書と訂正専用Input/Navigationだけで、通常UIの製品・ApplicationChecks/fixture・project generator・runner・runtime準備・workflowは同一bytes（当該差分0）。439の通常26 Bは02:16:28に同じ全操作を成功し、438の26 Bも01:48:31に成功している。

この同一コードの成功と、今回はcase開始前のdestination解決失敗だった新しい照合根拠に基づき、440の残る通常26 A・明示選択訂正26の終端を確認してから、同一sourceの失敗26 Bと依存する公開だけを新しいhost/所有deviceで一度独立検証する候補とする。bootやXCTestの失敗を同一job内で救済せず、製品・QA・OS/SDK・操作・期待・期限・全15gateは変更しない。原因の恒常的解消とは主張せず、同じdestination停止が再発した場合はこの根拠だけで再実行を繰り返さない。候補/根拠をCI対象外の枝へpushし、全job終端後、実行対象との差分0行に対する新規reviewを消費してから判断する。公開gate自身が要求する同一run/attempt/sourceの成功を満たさなければ公開しない。

03:20 UTCの予定照会で440/attempt1は全18job終端、13成功・N127失敗1件・4未実行（公開と指定外の3job）と確認した。残っていた通常26 A/job120754034500は03:17:51、明示選択訂正26/job120755137274は03:09:52に成功。訂正は両OSの全8件成功で、単項目26/job120755137246の実caseは800.305秒・1件/失敗0と厳格完了照合に成功した。取り消しは行っていない。公開gateのコードはN73/N74の当時d713ed6からも差分0と照合し、同じrun/attempt/sourceの条件を維持する。新hostでの独立検証の開始前レビューは、実行対象source1c331818から同じsourceへの空コード差分（0行、SHA256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855）だけを新規担当へ渡した。開始判断とreview結果は次に記録する。

新規GPT-6.1 Sol/High ios_n127_host_pre_actions_reviewは指定された空コード差分だけを読み、0行/0バイト・hash一致、差分内の指摘なしと回答した。主担当も実行sourceから作業枝までのコード差分が0で文書だけであることを再照合し、このreviewを同じ40051510584の失敗job限定再実行の開始1回だけへ使用する。別の開始へ使い回さない。記録はCI対象外の枝へpushしてから、GitHubの失敗job限定操作で開始する。

独立検証40051510584/attempt2の通常26 B/job120765045276は03:55:20 success終端（33分51秒）。元の全ケース・文字サイズ・通知/外観の実操作と完了照合を通過し、今回のhostではdestination停止は再発しなかった。ほか13件はGitHubが同じsource/attempt2へ引き継いだ成功で、当初の実行日時を保持している。公開job120772031013も04:22:04にsuccess、同一source/run/attemptの全15gate・全18job終端・artifact0・公開4添付の匿名照合を確認した。N127初回失敗を成功へ書き換えず、原因の恒常的解消とはしない。reviewはこの開始で消費済み。

## N128 84/91の両OS修正前回帰（2026-10-24、ローカル）

iOS source b6bd91f、Debian13/Swift6.1.2、04:44:53〜54 UTC、5ケース中4ケース失敗（30assert、0 unexpected、0.759秒）、compileは12.38秒で成功。testMixedHeightTimetableLinesKeepEstablishedVerticalOrderは分割断片あり/なし・Strict/Certifiedの全経路で科目/教員が逆順。testSpecialPeriodHeadingsDoNotTruncateNumericTokensは11時限・3桁分・Arabic/Osmanya数字前置を両完全Parserが拒否せず成功。testSpecialConsecutiveHeadingsDoNotAdoptNumericSuffixは誤った07:00〜08:00/07:00〜08:50を採用。testTruncatedSpecialClockCannotReplaceSavedGoodAnalysisは不正解析が実Storeを置換し、再openの旧record不一致。隣接した単独/連続見出しと全角・空白の正対照1ケースは成功した。ログ/tmp/takupoke-ios-84-91-before.log。実PDFKit/実機ではなく本番Geometry/Parser/Storeの実行で、製品は未変更。対処選択前の観測記録。

Windows source4bfc01c、Linux/.NET10.0.402、同じ04:44台の独立回帰は10展開中8失敗・2成功・skip0（203ms）。通常の完全Parserが分割あり/なしで架空教員Bを科目、架空科目Aを教員として採用し、不正な4種類の単独時刻を拒否せず、誤った連続時計2条件も採用した。全角/空白と隣接見出しの正対照2条件は成功。既存CS8602/xUnit2031警告は出たがcompileは成功し、実Core/Parserのassert段階の失敗。ログ/tmp/takupoke-win-84-91-before.log。Windows実UI・学校原本は未使用。対処案は過去記録・当時/現行コードの照合後に決める。

N128照合:行順/fragmentAlignment/fragmentOverlap/mixed-size/数値境界/periodHeadingで索引検索し、PDFの同型既往はなく、既存N102のXLSX日時全体検証は別経路だった。issue対象ea049e3から今回まで該当4ファイルの差分は0、固定239.1の元Grid/Timesにも同じ再sortと非境界regexがあることを実コードで確認した。84/91はissue本文がStrictとCertifiedの意図した差ではないと明示する共通不具合で、今回の例外はこの2条件に限定して文書化する。固定全文oracle/元の全対照は残す。

候補:84はcontentRowsが確定した縦の順序を維持し、横断片の整列/重なり拒否だけを従来どおり行う。91は数字の途中から始まる/終わる見出しを採用しない。ただし正対照にある同一行の単独時刻と独立連続時刻は空白正規化後に隣接するため、単純な前後negative-lookaroundで正常見出しまで拒否しない。既存regexで取得した完全見出しが隣接する範囲をまとめ、その外端がUnicode十進数字の途中なら範囲全体を除く。採用候補は元の時刻/順序/重複/件数検査を引き続き通す。範囲処理はsort後一巡とhash lookupで、prefix文字列の反復コピーや固定点の二乗走査を避ける。無効な連続見出しを採用しなければ、元の正しい単独時限からの時計算出は維持する。両OSでそれぞれ実装し、iOSの通常/特別版を34へ進める。Windowsの未配布11/8に集約し、既配布の10/7を再評価する。候補/記録を隔離枝へpushしてから同じ回帰を再実行する。

## N129 91候補のUnicode境界と独立連続時計回帰（2026-10-24、ローカル）

iOS sourcec23433c、Swift6.1.2、04:53:31 UTC、同じ5ケースで3assert失敗（1 unexpected、0.323秒）、compile37.36秒は成功。通常の行順・全角/隣接正対照・不正時計によるStore置換拒否は成功した。Osmanya数字前置だけは両Parserがなお拒否せず2assert失敗し、testSpecialConsecutiveHeadingsDoNotAdoptNumericSuffixは最初の条件でperiodHeading/b405をthrowした。Windows source36954cbは同じ10展開中8成功・2失敗（184ms）で、連続見出し2条件がReadTimesの件数P05をthrow。ログ/tmp/takupoke-ios-84-91-after.log、/tmp/takupoke-win-84-91-after.log。候補の成功を主張せず、対処選択前に観測を記録する。学校原本/実PDFKit/実機は未使用。

N129照合:N128の詳細とb6bd91f/c23433c、Windows4bfc01c/36954cbの同methodを比較。連続見出しは単独時計と同じ正規化行へ連結され、不正な外端の除外が単独時計も除いて件数不足へ進んだ。旧cellの単独時限からの算出は「連続時計がない」場合の既存処理であり、「不正な明示時計も欠落扱いにして採用する」という追加test期待は既存仕様から確定していなかった。AGENTSの「曖昧な内容は推測で反映しない」に合わせ、不正な認識済み見出しは解析失敗とし、欠落の場合の正常算出を別の正対照へ分離する。拒否の理由を偶然の件数不足にせず、数値境界違反そのものへ新しい固定番号R424/425を追加する（R423は撤回実験の予約なので再利用しない）。旧guard/番号は保持する。

OsmanyaはUTF16で2unitとなるが、FoundationのrangeOfCharacter境界照会では今回前置数字を検出しなかった。候補は行ごとのUTF16列を必要時に一回だけ作り、境界でsurrogate pairを明示復元してUnicode十進数字かを調べる。WindowsのRune検査は同条件を既に拒否しているので保持する。新しい拒否guardで不正明示時刻を必ず拒否し、連続見出し未記載の独立正対照は元cell経路の正しい08:50〜10:35を必須とする。既存の正常隣接/全半角/保存保持の入力・期待値は変えず、候補/根拠をpush後に6ケース/11展開として再検査する。

## N137 新規roleScopeの部分evidence正対照が全Validatorで拒否（2026-10-24、ローカル）

source19f75df、Linux Swift6.1.2、新規testOCRRoleScopePreviewCanSelectTheWholeFieldWithPartialProviderEvidenceのpreview前提assertが`rolePartition`で失敗した。選択した22件中1失敗/0unexpected（5.028秒）、うち再認証19件中1失敗（0.723秒）。compile成功、全captureの構成/attaching、訂正draftと完成結果の残assertは通過した。ログ/tmp/takupoke-ios93-scope.log。直前169557dの全592件は別途失敗0（75.459秒）。部分evidenceのfixtureを正常previewとした前提とValidator全体を、対処選択前に照合する。

N137照合:rolePartition/部分evidenceの過去索引と、db1d856/currentのmenu条件、Validator:462〜478を全文照合した。個別scopeのevidence検査だけでなく、全役割の重複なし和集合が本文全体と一致するrolePartitionを保持しているため、追加本文を落としたpreviewは正常ではない。直前の静的解釈はこの全体検査を見落としていた。候補は元の完全親一致menu条件へ戻し、同じ追加本文のfixtureを「欠落previewは拒否/訂正へ誘導しない」負対照にする。同じ全scopeを本番Rulesで再構成したpreviewは全Validatorを通り、全親を保って手動訂正・完成できることを正対照にする。元のValidatorや原本/画像/採用条件は一切緩めない。記録と候補をpush後に再検査する。

## N136 追加修正後の全Swift回帰で7失敗（2026-10-24、ローカル）

source f809489（実Foundation code04452c4まで、所有SPM projectへ同じ変更を反映）、Linux Swift6.1.2。全591件に7失敗/0unexpected、75.211秒、06:39:55 UTC終端。コンパイルは成功。ログ/tmp/takupoke-ios-remaining-all-swift.log。並行のPython全279件は成功/予定skip2（60.423秒）。焦点57/65件の成功とは別に、全体の失敗を対処選択前に記録する。次にcase/段階と当時/現コードを照合する。

N136詳細:7件はRecoveryTestsの5ケース（SpecialScope:134、OrdinaryRoleAlias:153、UnusedFontReader:164、ParallelAlignment:167/176、OCRCoverage:179/183）の固定「現行版33」と実34のassert差。旧版同hashの再試行・同じ現行版では再試行しない・events固定版の動作assert自体は通過した。製品の状態処理・時計・CMap・Native frameworkの失敗とはまだ扱わず、旧33を含めて再解析すべき84/91の版更新と照合する。

N136照合:parserVersion/固定33/版assertを検索し、1c331818公開時のRecoveryTestsと現f809489、84/91候補c23433c以降の両Parser版34を照合した。同じ固定版assertの失敗記録はない。今回は#84/91の旧33結果を更新する明示変更へ、既存7箇所の固定現行値33が追随していなかった。候補は現行期待を明示34へ更新し、過去21/22/24/29/30/32等の再試行・現行確定失敗非ループ・events版4の全assertは保持する。追加で公開33の成功/確定失敗が両Parser34で再解析され、34の成功/確定失敗はループしないことを要求する。動的定数で常に通る期待へ置き換えず、製品/合格条件/期限は変えない。記録と候補をpush後に全体を再検査する。

## N135 索引後の独立性能ハーネスがコンパイラ起動前に失敗（2026-10-24、ローカル）

source7df7a5b、Linux、所有snapshotハーネス/tmp/takupoke-projection-index-eeacs0uu。build.pyが存在しない固定swiftc pathを指定してFileNotFoundError。Swift compile/製品関数/計時はいずれも未開始。詳細/tmp/takupoke-ios-projection-index-build-status.log。既存の索引/時刻/ホーム回帰56件は別途成功（0.917秒）。対処選択前に事実を記録する。

N135照合:FileNotFoundError/ハーネスでN131詳細と保存済みbaseline flags/source hashを読んだ。N131はWindows入力pathで、今回はSwift executableだけが異なりsnapshot38source/driverの準備は完了している。候補はenv.shを読み、shutil.whichで実swiftc（/workspace/toolchains/swift-6.1.2/usr/bin/swiftc）を解決して実行する。snapshotの実source/入力/全query/checksum6206/1warmup+6samplesと-Oは変更しない。製品の失敗・性能結果へ一般化せず、記録をpush後に計測を再開する。

## N134 Windows統合全体で特別PDF回帰1件失敗（2026-10-24、ローカル）

source53cdf7e、Linux/.NET10.0.402。Core全体は成功した後、Integration全体340展開中1失敗/339成功（9秒）。ログ/tmp/takupoke-win35-integration-full.log。前の焦点fc5fdceの111件成功とは別sourceで、追加した複合塗り対照を含む全体の失敗。具体case/段階の詳細は次に読み、対処選択前の観測として記録する。

N134詳細:Core223件/失敗0。失敗は新規IndependentCompoundFillControlsKeepTheSpecialTimetable(returns:true, `10 10 1 30 re 11 10 1 30 re f`)で、実PdfPaintVisibility.Validate:148がP01をthrowした。試験の離れた塗り対照と全negative、他339件は成功。重なりではなく接触だけの2矩形を一つの塗り演算で描いた条件。製品条件を変える前に記録する。

N134照合:既存34の可視罫線/compound/接触を索引・Windows検証記録で検索し、fc5fdceと53cdf7eのPdfPaintVisibility.Paths/Validateが同じと確認した。Pathsは一つのfill演算の矩形ごとに_orderを増やし、Validateは接触した次の矩形を後続の上塗りと見なす。正の面積の重なりはPathsが既に全体拒否するので、同一fill内の隣接subpathは同時描画として同じorderを持つべきである。候補はfillのorderを一度だけ採番し全矩形へ使う。別演算の後続上塗り/文字/重なり拒否/limitsを保ち、元の完全返却7授業と接触PDFの期待を変えない。iOS側のcompound照会は既に正の面積だけを用い、Strictの可視性は変えない。候補と根拠をpush後、元の全体を再検査する。

## N133 Windows特別PDFの修正前可視性と新fixture（2026-10-24、ローカル）

source25e1fb4、Linux/.NET10.0.402、追加Special回帰8展開は1成功/7失敗（527ms）。compile成功、既存CS8602/xUnit2031警告。完全返却7授業は成功。一方試験のwriterは実font mapに未登録の文字でJsonElement.GetProperty/KeyNotFoundExceptionとなり、Reader実行前の失敗。返却の白本文/上塗り/未知alphaは例外を投げず拒否assertが失敗した。ログ/tmp/takupoke-win35-before.log。製品のSpecial visibilityは未変更。対処案を選ぶ前に事実を記録する。

N133照合:既存Windows33/34の実Reader可視性と現行SpecialGlyphsを照合。返却の正対照は実fontから7授業を得ており、3負対照も実Readerまで到達した。試験writerには見出し`1・2時限連続`の中点だけがsubsetから欠けていた。候補は架空文字集合に中点だけを追加して同じ実TTCから再生成（別名/実CID/OFL保持）し、glyph字形を別文字に差替えない。製品側は両種別でpaintを持ち、Specialの実PdfPig glyphを1回だけ取得してTextSequenceで束ね、実text-show演算ごとに順序を1増やして該当群をpaintへ渡す。空Tj/TJ内複数string/引用符の実校正結果を永続回帰へ移す。未消費/不正順序群は全体拒否し、既存Specialのfont/座標/字句は保持する。通常customtext engineは通常だけに保ち、gs検証はcontinue前へ置く。元の失敗と根拠/候補をpushしてから再検査する。

## N132 複合塗りの独立描画対照が期待と不一致（2026-10-24、ローカル）

source db1d856＋未commitの101候補/Native回帰、Linux Poppler pdftoppm 72dpi gray既定描画。完全架空300×400PDFの同一矩形二重subpath `10 10 1 30 re 10 10 1 30 re f*` に、白以外の画素が62あり、「白以外0」のassertが失敗した。PDFの作成/xref読込/描画/PGM寸法は成功。TemporaryDirectoryは回収済み。Apple/製品Readerは未実行、暗さやanti-aliasの寄与はまだ未調査。対処選択前に観測を記録する。

N132照合:alias/描画対照/paintedInk/画素0で旧索引を検索し、同じ複合塗り対照はない。旧NativeのpaintedInkは既定antialiasの白以外を数え、旧thin-fill正対照は正の画素だけを要求していた。今回追加のゼロ画素assertはまだApple実行していない。現/元PathReaderはsubpathを個別の矩形として扱い、Windows通常Readerは既に重なり拒否を持つ。まず同一PDF入力の既定/明示vector-antialias無効を比較し、全非白画素の値と範囲を記録する診断を行う。製品条件/Native期待はその観測前に変更せず、最初の62画素観測を保持する。記録/候補をpush後に診断を行う。

8aa8207後の診断:Poppler26.05.0で二重even-odd/逆向きnonzeroの既定非白62画素は181×1/223×60/251×1、AA無効でも境界62画素が残った（黒62）。単独f/f*は黒30、同向き二重nonzeroは黒30＋縁32で、anti-aliasだけがゼロでない原因とは断定しない。全canvas非白0を意味論の代用とする新しいassertが不適切。候補は元の全canvas正対照と製品の重なり拒否を維持し、新規の相殺対照だけ原矩形境界から離れた内部x10.25〜10.75/y15〜35を4倍描画・clipして白を厳格に要求する。同向き/部分相殺は同じ内部に実inkを必須とする。画素の閾値緩和・期待値注入はせず、独立Popplerも同じ内部を288dpiで観測する。旧テストのhelper既定値/解像度/判定は変えない。Apple実行はまだ未確認。

## N131 CMap比較ハーネスの準備失敗（2026-10-24、ローカル）

source iOS6b85e4a/Windows40bde67、Linux、05:30 UTC前後。独立計測の準備PythonがWindowsの実ファイルをParsing配下ではないpathで参照しFileNotFoundError。set -eのない親shellが続行し、未作成win-after projectをdotnet buildしてMSB1009、未作成DLL実行も失敗した。製品テストは別途iOS5件/Windows13件成功済みで、この失敗は製品parserの実行前。対処を選ぶ前の観測として記録する。

N131照合:索引のハーネス/FileNotFoundError/MSB1009検索で同一path準備失敗の旧記録はない。保存済みbeforeのcsprojと実ファイル一覧、6b85e4aの実CMapを照合した。候補はParsing配下の実ファイルをコピーし、準備から実行までset -eで停止する。製品コード・比較入力・3回中央値・期待値は変更しない。記録をpush後に計測を再開する。

## N130 Strict CMapの取消修正前回帰（2026-10-24、ローカル）

iOS source8107485、Linux Swift6.1.2、05:15:24 UTC、testStrictUnicodeMapChecksTaskCancellationBeforeParsingが1件/1失敗（0.004秒）、compile9.13秒成功。所有Semaphore gateを解放する前に実Taskをcancelしたが、有効な小CMapをPDF239UnicodeMap.readが正常decodeして返し、取消のassertが失敗した。固定sleepや結果注入はない。ログ/tmp/takupoke-ios-77-cancel-before.log。CMap本体は未変更で、対処案を選ぶ前に観測した。別の最適化済み実関数計測では65536 singletonのSwift中央値1.971677秒/Windows5.511566秒、入力/全対応/個数/checksumが正しいことを確認済み。Reader全体や実機の測定ではない。

Windows source29bde46、Linux/.NET10.0.402、CmapInnerWorkHonorsCallerCancellationは1件失敗（method121ms、全体132ms）。外側の既存取消位置を同じまま内部checkpointへ委譲しただけのcoreで、単一codespace/単一bfrangeの65536対応が16回目のcheckpointへ届かず正常終了し、OperationCanceledExceptionのassertが失敗した。compile成功、既知のCS8602/xUnit2031警告のみ。ログ/tmp/takupoke-win-77-cancel-before.log。mapping/拒否条件/内側loopは未変更で、対処選択前の観測。

N130照合:CMap/UnicodeMap/取消で索引検索し、N114詳細のdetached親取消とは違って今回は既にcancel済みのTask/渡されたcheckpointを同期parserが観測しないと確認した。固定239.1の元UnicodeMapと現行の関数を読み、同じspaces全走査が残る。Certified側は有界索引だが未使用controlの受理がStrictと違うため、受理条件ごとの移植はしない。Windowsのea6ac2f→29bde46はwrapperと同じ2取消位置のdelegate置換だけと照合した。

候補:65536位置のcovered索引を各parse内だけで持ち、範囲の可否確認とmarkの総走査を有限domainに限定する。元のl<=h/非重複と同値のguardを同じ番号で保ち、mappingの所属は索引で確認する。Strict固有の未使用control拒否・不正UTF16/width/重複・2MB/65536上限を維持する。token抽出/next/insert/範囲確認/markへ128作業単位ごとの取消確認を追加し、iOSの既定checkはTask取消、実font callerはengine.checkを渡す。Windowsのpublic CancellationToken/外側確認を保ち、同じ実coreのcheckpointを内側からも呼ぶ。新しい拒否条件は足さず、前後の最適化済み実関数を同一入力で再計測する。候補と根拠をpushしてから回帰を再実行する。

## N140 残件候補のApple先行検証が失敗（2026-10-24）

07:45:50 UTCの予定確認、source75344b2bf9af72b5873989e962beb2ee2e554166、test-tools run40074272822/attempt1。全5job終端。portable Swift job120814189982と契約検査120814190148はsuccess、Native26 job120814190120（07:33:07）、Native27 job120814190133（07:32:06）、Picker120814190082（07:40:27）はfailure。対処前に関数storeへ観測を記録したが、ローカル索引へ追記する直前に実行環境が切断し、書込みは実行されなかった。14:39 UTCの環境復帰後、保持した会話の事実をここへ永続化する。取消しは行っていない。全5jobの完了ログは接続済みGitHub経由で一度だけ取得済み、以後は同じrun/job状態やログを再取得しない。環境交換で/tmpと関数storeの元ログは失われたため、下記は切断中に読み取って記録した限定抜粋であり、原ログの保存があるとは扱わない。

Native両SDK（26.6/27.0）はtests/SchoolEventsSourceStatusTests.swift:7のprivate let hash:Stringが継承したNSObject.hash:Intと衝突し、overriding property must be as accessible / property hash with type String cannot override Intでテストmoduleのコンパイルが停止。XCTestは未実行。portable Linux Swift6.4は599件/失敗0（85.971秒）、契約Pythonは279件（71.526秒）の成功終端。両Apple失敗をLinux成功で置き換えない。

PickerはSDK/Runtime27.0で実build-for-testing成功、3件中2成功・1失敗、全428.174秒。testInstructionSurroundMatchesFilesBackgroundは94.801秒、testReselectionWithMissingAppearanceReturnは38.125秒で成功。testReselectionThroughActualButtonsは295.248秒、MaterialPickerTapChecks.swift:173。choose-1の実Cancel/案内消失と、choose-2の実Buttonタップ・案内存在（8秒）・Cancel存在（30秒）は成立。その次のCancel.tapが要素を再解決し、t128.30/t159.39のFind Cancel再照会後、UI query timeoutで失敗した。失敗したCancelのnative touch到達は未観測で、一般的なFiles/provider不具合と断定しない。

N140照合：catalogでSchoolEventsSourceStatus/MaterialPickerTapChecksを検索し、コンパイルのN03/N57/N67、Picker/Cancel/再照会のN53/N74/N83、native identityのN94/N97詳細と現Input/Navigation、公開440.2と現Pickerの実bytesを読んだ。Picker testは両版ともSHA256 d42c74c2cfc9694be4b9f83c6f24a570c9fa9ed07a35be12daa51725bd3bb2bcで同一。N53のCancel自体不在と異なり、今回は存在確認成功後のtap再解決が停止した。N97のidentity捕捉後に別viewport観測を行って要素が消えた件も保持し、捕捉後に別の診断照会やscrollを挟まない。

候補はテスト内のString hashをexpectedSourceHashへ改名するだけで、元fixture/期待値/全assertは保持する。Pickerは元30秒内に一意な標準Cancelの実accessibility要素を捕捉し、有限frame/enabled/hittableを確認したその要素へ直ちに一回tapする。曖昧・未表示・timeoutは失敗し、押し直しを行わない。選択ボタン・スクロール・案内の8秒/消失8秒・全11回の連続選択/Cancel・元3ケース・Runtime/SDK・全15公開gateは維持する。製品のFileProvider/Pickerは変更せず、OS側原因や恒常的解消は断定しない。候補と記録を隔離branchへpush後に局所確認し、次のActions前は別の新規GPT-6.1 Sol/Highによる不変code-only reviewを行う。切断前の未消費main公開reviewも破棄し、別開始へ転用しない。

## N142 修正後のApple先行検証でNative両SDKが失敗

2026-10-24 15:04 UTCの予定確認、source916841542c7395b4eeee8cf35eedc01341c1fd3f、test-tools run40104066472/attempt1。全5job終端でPicker120901982927/portableSwift120901983185/契約120901983104はsuccess、Native26/120901983169とNative27/120901983207はfailure。ログ未読で具体的ケース/失敗段階/原因は未確定。対処前の観測を索引へ記録する。取消しは行わず、新しい完了ログだけを一度取得する。このrunは正式公開の合格へ合算しない。

N142ログ詳細：両SDKともmoduleのコンパイルとNative XCTest実行に進み、688件・予定skip1・4assert失敗・unexpected0。SDK26は152.046秒、27は101.847秒。全失敗はtestNativeBackgroundContrastCannotCertifyHiddenLowContrastOrLateBackgroundTextのPDFTextGeometryTests+Visibility.swift:301で、旧期待R270に対してR426が返った4入力。その他の新しい状態API/実Model3件・clock/cache/recert/PDF回帰は成功した。Picker3件は失敗0・287.052秒（準備込460.4秒）で、元連続選択/Cancelケースも189.314秒で成功。Nativeの4失敗の原因選択前に詳細を追記した。元ログ5件は所有するworkspace stateへ保存し、再取得しない。

N142照合：compound/contrast/R270/R426で索引・issue101検証を検索し、N132の独立描画とN134の同時fill順序の詳細、公開1c331818と現PDFPathReader.paintの実コードを読んだ。追加R426は同じfill内の正の面積の重なりを文字との交差を見る前に全体拒否する。失敗した旧2入力は同一矩形二重even-oddと逆向き二重nonzeroで、この新しい固定枝の対象そのものだった。旧R270は文字を覆う背景が複数subpathの場合の拒否として残り、条件を弱めたり外したりしていない。Nativeの相殺/同向き/部分重なり拒否と単独/離れた/接触/別演算の正対照は両SDKとも成功した。

候補は旧2負入力を同じまま保持し、確定済みの前段R426への到達を固定literalで要求する。R270も意味を保って検査するため、文字を覆う矩形と離れた別矩形を一つのf/f*で塗る2負入力を追加し、R426の重なりguardを通った後でも複合背景を採用せずR270となることを必須にする。元の全入力、Throws/complete=false/pages非completeのassert、他のcontrast/late-background枝は保持する。製品・Strict・画素閾値/判定・公開gateは変更せず、候補/記録のpush後に新Native比較を行う。Pickerは同じsourceの元3ケースで成功したため、別の先行Picker再実行は増やさず、正式全15の公開jobでは従来どおり必須にする。

## N143 正式公開候補のiOS27画面検証6jobが失敗（2026-10-24）

2026-10-24 15:50:17 UTCの予定一括確認、sourcead01f9ec83b281c18a1f50088e343e802801b380、正式main run40106889321/attempt1。全15表示job終端。Distribution120910323994とNative120910668238はsuccess。通常27 B/120910668216とA/120910668227はExercise app screens with synthetic data、手動27三項目120910668240・一項目120910668257・明示選択120910668264・原本変更120910668324はExercise one manual case and require its exact completionでfailure。具体caseの実行到達・SDK内のエラー・原因は完了ログ未読で未確定。iOS26通常2系統/訂正matrixと公開は依存skipで未実行、構成上の開発3jobもskip。全15必須成功は成立せず未公開。取消しは行っていない。対処選択前の観測を記録し、新しい完了8実jobログだけを一度取得して、過去詳細と実際の旧/現行sourceを照合する。既存ケース/期限/公開gateは変更しない。

N143完了ログ詳細：6jobはいずれもSDK27.0でアプリのbuild-for-testingに失敗し、TimetableView+Cards.swift:167:53の同期nonisolated contextからMainActorのfits(_:font:width:lines:)を呼べないというActorIsolatedCall。実XCTest/UI操作は未開始。Simulator未bootの後続cleanup診断を製品起動失敗の原因と混同しない。NativeはSDK26.6で688件/予定skip1/失敗0（135.430秒）、状態APIの実Model3件とStrict独立比較3件も成功した。全8実jobログを所有stateへ一度だけ保存し、同じrun/job/logを再取得しない。対処選択前に具体的停止箇所を追記する。

N143照合：TimetableView/TimetableRenderCacheをcatalog検索し、actor/nonisolated/fits/ViewBuilder/コンパイルで失敗索引を検索した。N31のViewBuilder型推論とN67のSPM対象外SwiftUI型不一致を詳細・当時のPDFRecoveryView/MaterialsViewコードまで読み、旧公開1c331818とcache導入85a029a/現行Cardsを比較した。旧fitsはactor状態を参照しない直接UIFont計測だったが、候補はMainActor所有cacheを読む。local functionは暗黙にその隔離を持たず、Appleのアプリ型検査で拒否された。Linux構文parseやUIKitを含まないSPMの成功をアプリ型検査へ数えない。

修正候補はこの内側のfitsだけに@MainActorを明記する。呼出し元のSwiftUI描画・cache所有/計算・厳密なfont/width/文字列key・一行/複数行の式・0.5許容・全代替候補・二分探索・停止/上限は維持する。UIケース/期限/OS/SDK/全15公開条件は変更しない。同じアプリbuild-for-testingの6経路が今回の不備を直接検出したため、模擬UIKitのコンパイルや構文文字列を写す追加ケースは作らない。候補と根拠を隔離branchへpushしてから既存の局所契約/構文/catalogを確認し、新規のcode-only reviewを経て正式全15を開始する。次回は今回のbuild停止が約3〜5分だった事実から最初の確認を約8分後に設定し、build通過後は通常UIの実測所要時間で間隔を広げる。古い成功を合算しない。

## N144 正式候補442の通常iOS27 Aがfailure終端（2026-10-24）

2026-10-24 16:49 UTCの所要時間に基づく確認、source25fe013a04a740833630e1a5efc92b592c824465/run40109158354/attempt1。通常27 A/job120917406836は15:56:54Z開始・16:31:03Z終端、Exercise app screens with synthetic dataでfailure。具体case/操作段階/原因は完了ログ未読で未確定。Distribution・Native688/予定skip1/失敗0・訂正27全4caseは同runで成功し、N143のアプリbuild停止は4実build/訂正操作で再発しなかった。通常B/job120917406774は16:01:11Zから継続中、26 Aは依存skipで未実行。この時点で全15必須成功/公開は不成立だが、残jobを取消しせず終端まで確認する。対処選択前の観測を記録し、新しく失敗したAのログだけを一度取得する。既取得6成功jobのログと終端旧runは再取得しない。

N144完了ログ詳細：SDK27.0/Runtime27.0、build-for-testing成功後、通常Aの第1batch17件中16成功・1失敗（1585.449秒）。testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWorkが69.403秒で失敗、ApplicationChecks+Timetable.swift:79「Lesson card has no fully visible hit region」。Homeの最初の授業詳細は実open/closeまで進み、その後の段階・実AX/幾何は次に照合する。他の16件成功をこの必須caseや未実行の後続phaseへ代用しない。失敗時刻16:17:01Z、jobは残ケース実行後16:31:03Z終端。対処選択前にcase/停止段階を追記する。

N144実観測：Homeではbusy-only中の詳細保持、実正式更新/原本更新による詳細閉鎖まで成功し、時間割用の別processをcold launchして実tab操作へ進んだ。時間割の最初の対象Buttonはframe(47,681.3,64,146)、NavigationBar底165/TabBar上769で、中心754.3は表示域内だが下端827.3は遮られていた。最初のloopは中心が内側ならbreakする一方、直後のguardは全frame包含を要求するため、スクロールを一度も行わず拒否した。詳細tap自体には未到達。タブ選択は実Selectedで、Homeの保存/閉鎖失敗やアプリ型検査失敗とは異なる。

検索語：当該case/fully visible hit region/midY/contained/card frame/scrollDrag。U57の同じcaseのworker解放待機とbd5ddb7の実テスト、N47の部分行を大swipeで往復した詳細とa0fed9bのNavigation、公開1c331818/現在25fe013の実Timetableケースを照合した。今回のcaseは公開版と同一bytesで、N47で導入済みの観測frameによる有限scrollDragをまだ使用せず中心判定のままだった。既存ObservedScreenGeometryTestsの下端部分行/上端部分行/高さ1/3上限/無効・oversize・既可視拒否を読んだ。

候補はこのcaseの元8回loopで全包含/enabled/hittableを確認し、部分的な実frameには既存scrollDragのviewport中心方向・高さ1/3以内の移動を使う。不在の探索は元swipeを維持し、固定位置/押し直し/成功注入は行わない。全frame包含の元guard、実card一回tap、10秒詳細/元の5/10/15秒のworker・保存・閉鎖、両surface/再起動、全17ケースと後続phase/両OS/全15gateを維持する。製品・cache/Strict・共通geometry/既存helperは変更しない。既存7幾何ケースが同じ計算・拒否を、元の実UIケースが今回の不足を直接検出するため、同じ式を写す新ケースは作らない。候補と根拠を隔離branchへpush後に既存幾何・manifest・構文/catalogを確認し、元のcaseを両OSの限定比較で先に評価する。新しいActions開始前はその一回専用の新規code-only reviewerを作成する。残Bは取消しせず終端を確認する。

## N145 N144候補のローカル幾何harness準備が停止（2026-10-24）

source5139907390f2b587cbfad05641844d7faca11dc0、Linux Swift6.1.2、16:52:50 UTC。既存ObservedScreenGeometryTests.swiftをそのまま単独XCTestへ登録する所有harnessがexit1。Swift compile/7件の実行への到達と具体的停止箇所は保存log未読で未確定。並行の既存manifest/構文/catalogは継続中。ログ/workspace/.takupoke-task-state/ios-n144-geometry.log。製品/iOS実操作の失敗と混同せず、対処選択前の観測を記録する。

N145照合：停止はharnessの「@testable import TakupokeParsingが一つある」という準備assertionだった。実際の現テストはFoundation/XCTestをimportしており、同じtest targetのSupportを直接参照するためそのimportがない。Swift compile/実テストは未開始。N131/N135のハーネス準備で製品実行前に止まった詳細と現テスト全7宣言・Support本文を照合した。次は実source/既存テスト本文をbytesそのまま一緒にコンパイルし、7つの元test methodを標準XCTMainへ登録するだけにする。import置換や入力/期待値の変更は行わず、製品/ケース/既存geometry計算を変更しない。準備の前提修正と根拠をpush後に同じ7件を再確認する。最初のログも保持する。並行manifest28件/失敗0（4.940秒）と構文/catalog448/固定枝一覧は成功した。

N144限定比較結果：source00c945017957260779ba3a1e08ac58f6e81444eb/run40113800496/attempt1の両jobはsuccess終端。SDK27.0/Runtime27.0は元case1件/失敗0（155.925秒）、SDK26.6/Runtime26.5は1件/失敗0（180.913秒）。両surfaceで実busy-only中の詳細保持、実正式/原本更新後の詳細閉鎖、元の再起動/実一回tapを通過した。今回の観測時間割cardはy617.33〜763.33で全表示しており、失敗時のy681.3〜827.3の部分表示を同じ位置で再現したとは扱わない。既存7純幾何の部分行対照と区別し、後の元17件/全phaseでも同じcaseを維持する。2完了ログは一度だけ保存し再取得しない。API jobの途中step表示にSetUpと後続Exerciseが同時進行など不整合があったため、初期化停止の原因と推測せず、終端conclusionと実完了logを照合した。限定成功を全15/公開や一般的な恒常解消へ数えない。

## N146 正式候補443の通常iOS27 Aがfailure終端（2026-10-24）

2026-10-24 18:14 UTCの実測所要時間に基づく確認、source184f7edc3bdd808d8981f4fc0383c6cea1831f8c/run40115748177/attempt1。通常27 A/job120936874342は17:25:02Z開始・18:09:11Z終端、Exercise app screens with synthetic dataでfailure。具体case/操作段階/原因は完了ログ未読で未確定。通常27 B/job120936874291は18:01:06Zにsuccessで、訂正27全4case・Native・Distributionも同runで成功。26 Aと訂正26は依存skip、26 B/job120945516654は18:01:09Zから継続中。この時点で全15必須成功/公開は成立せず、残jobを取消さず終端まで確認する。N144候補のどの操作を通過したかは新しいログで確認し、限定比較の成功を正式caseや別の失敗の解消へ一般化しない。対処選択前に観測を記録し、新たに完了した3jobだけのログを一度取得する。既取得5成功logや旧終端runは再取得しない。

N146完了log詳細：アプリbuildは成功し、通常Aの最初の17件中16成功・1失敗（2232.224秒）。testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunchは218.426秒で失敗、ApplicationChecks+Changes.swift:31のXCTWaiterResult timeout2とcompleted1の不一致。17:35:22Zにassert、17:36:09Zにcase終端。具体的な待機条件と実UI/操作の到達は次に照合する。N144のHome/時間割詳細caseは両surfaceのbusy-only保持・正式/原本更新による閉鎖まで通過し、今回は同じcardの失敗ではない。通常Bと原本変更訂正の新しい成功logも一度だけ保存した。対処選択前に具体的case/段階を追記する。

N146実観測：3行目の最初の除外Switchで、外側(16,362.67,361,52.33)/内側(300,375,63,28)・全包含/操作可/双方0を確認し、同じ内側25%点(315.75,389)へ一回0.1秒pressした後、元15秒で1にならなかった。4行目/101行group/103行の保存へは未到達。内側index取得後の外側/viewport/状態観測と接触の再解決で各AX照会が約5〜12秒になり、t53付近の取得からt115の接触ログ、t130のevent合成、t147の再Findまで時間を要した。今回のcaseには入力traceがなく、実touchの到達/cancelled/Binding呼出の有無と下位原因は未観測で、遅延や製品Bindingを原因と断定しない。

照合：case名/change-skip/Switch/0.25/native/identityを索引・catalogで検索し、U19の同じ行3、U64の同じtrack/0.1秒、N94/N97の実要素identityと観測順序、N140の存在後の再解決を詳細まで読んだ。65767af/760304fの当時の通常helper、1b368f5/9cd340eに対応する現Input/Navigationと、公開1c331818/現184f7edのChangePreviewView/通常helper/行除外caseを比較した。製品Bindingと今回のcase/通常Switch helperは公開版と同一bytesで、現在の通常helperだけは内側をelement(boundBy:0)で保持している。N94のnested index再解決停止とは失敗の分類を分けるが、実touch直前まで同じ祖先を反復探索する経路の比較根拠とする。U19/U64の点や操作方法の往復、無根拠の同条件再試行は行わない。

候補は通常helperの周辺viewport/アプリ/外側枠・状態を先に観測し、元45秒のnative存在待機内で一意なallElementsBoundByAccessibilityElementを捕捉する。外側は論理ID検索のまま、内側だけ実identityとし、捕捉後は新たなviewport/外側探索を挟まない。内側/外側の有限正枠・全包含・enabled/hittable・既知0/1一致、元25/75%の同じ点・一回0.1秒press、呼出側の行3/4/groupの15秒、選択103行/取消/正式保存/再起動の全期待を維持する。曖昧/不在/無効は失敗し、押し直し・状態代入・期限延長はしない。元の行除外caseに既存の入力trace flagだけを追加し、未観測だったtouch経路を記録できるようにする。observerは既存のoriginal sendEventを一回通すだけで製品Binding/期待値を変更しない。原因・恒常解消は未確定。候補/根拠を隔離branchへpush後、既存manifest/runner/幾何と構文/catalogを確認し、新規review後に既存rows比較を両OSで行う。正式全15は別の新規review/同一sourceで要求し、残る旧26 Bは取消さず確認する。

## N147 N146候補のローカルUI契約検査が失敗（2026-10-24）

source4b232eb0447b354868a2eadbf86c8fcd6256cda5、Linux Swift6.1.2/Python、18:23:16 UTC。構文検査後に既存manifest28件を実行するローカルcommandがexit1。具体失敗case/段階は保存log未読で未確定。続くrunner13件は同commandのset -eによりまだ未実行。並行の既存幾何7件/失敗0（0.102秒、準備込1.828秒）、catalog448/固定枝/差分空白は成功した。ログ/workspace/.takupoke-task-state/ios-n146-manifest.log。対処選択前の観測を記録し、実Apple操作の失敗とは混同しない。

N147詳細/照合：manifest28件中27成功・1失敗（4.586秒）。test_notification_readiness_probe_observes_os_without_granting_or_savingの229行が通常Switch helperの「control.isEnabled, control.isHittable」という実guardを要求したが、候補は一度だけ使うenabled/hittableの局所aliasへ移していた。現testと公開1c331818/4b232ebのhelperを読み、値の検査が消えたのではなく字句契約の不一致と確認した。同じassertIn/文字列guardの失敗索引検索に同一箇所の既往失敗はない。対処は不要なaliasを除いて、元と同じ実controlのenabled/hittableを全幾何guardの中で一回ずつ直接確認すること。無効な枠の後に不要なAX照会も行わず、既存の契約テスト/全期待は一切編集しない。identity捕捉・元45秒/一回0.1秒/同じ点・caller15秒/保存/再起動は維持する。候補と本根拠をpush後に同じmanifest28件と、まだ未実行のrunner13件を確認する。未使用の385b5def…review artifactはこの差分で古くなったため破棄し、新しい不変差分で新規reviewを行う。

N147第2比較：f20e2d4の同じ28件は27成功・1失敗（4.337秒）、次の230行「row.isEnabled, row.isHittable」の字句契約で止まった。control側だけを読んで修正し、同じcaseが要求する外側とviewportの全契約まで確認しなかった準備不足で、runner13件はまだ未実行。全caseの期待と旧helper、N78/N80のソース形状契約と実条件の照合を読んだ。次はnative存在だけを待って外側の古い観測を再利用せず、元45秒の同じpredicate内でアプリ/viewport/外側枠・enabled/hittable・状態を直接確認し、その後に内側identityと全ての元guardを直接確認する。全て成立した同じ観測の内側/枠/0・1一致を捕捉し、完了後に余分なAX照会を挟まず元の一回接触を行う。全guardが同じ元45秒内で再評価され、古い外側値を待機後に採用しない。テスト期待や期限は変更せず、2回の失敗logは区別して保持する。次の試行前にこの差分/根拠をpushし、未使用review artifactも再生成する。

N146限定比較：sourceabd6d2f1b4285565e4a63800ab96c679cf120f29/run40121053050/attempt1は両job success。SDK27.0/Runtime27.0の元行除外case1件/失敗0（176.095秒）、SDK26.6/Runtime26.5も1件/失敗0（226.460秒）。行3/4と200〜300groupの3回とも元のnative点/0.1秒の一回接触、実value1、確認の取消しと確定・103行の除外保存・再起動保持を通過した。所要jobは約9分半。両完了logを一度だけ保存し、再取得しない。元失敗の実touch到達や下位原因の証明、全caller/全15/恒常解消へ一般化しない。新しい全体では同じ行除外に加え、共通helperを使う設定/通知の元ケースも両OSで維持する。旧443の26 Bも18:49:48Zにsuccessとなり全15表示job終端・8成功/通常27 Aの1失敗/構成依存skip6・artifact0。全9実job完了logは取得済みで同じ旧run/ログを再取得しない。

## N148 正式候補444の手動補正iOS26で入力消去待機が失敗（2026-10-24）

source1a5eb2d460cfb2b8b75b8fbaf592dc78bacafa0f/run40122891165/attempt1、job120970484475は19:49:08Z開始・20:00:55Zにfailure終端。SDK26.6（Simulator SDK26.5）/Runtime26.5のtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundが238.111秒・1失敗。ManualAssistanceChecks+Input.swift:89で、実clear後の元45秒待機がtimeout2となりcompleted1に一致しなかった。元PDF表示/拡大/等倍/閉鎖、未確認Switchとsubmit無効は通過。clearは(317,587.33,44,44)、表示viewport内・enabled/hittableを観測し、一回のButton.tapを合成した。待機後の実input-stateはcell-1-0:0:subject=架空科;ack=falseで、前の文字が残っていた。押下がBindingまで届いたか、touchの具体経路/取消し、下位原因は未確定。対処選択前の観測として記録する。

同一runのiOS27全条件（行除外17件中1ケース、Home/時間割詳細case含む）と26 B・26手動補正の他3条件はsuccess。26 Aは継続中、全15成功/公開は不成立。新しい完了5ログだけを一度取得し保存し、既取得8ログ/旧runを再取得しない。残りの実行はキャンセルしない。今回の失敗は入力clear操作であり、N146の通常行除外やFileProviderの取り下げ済み報告とは区別する。

N148詳細：実touchは(339,609.33)のCellHostingViewへbegan後、0.073秒でcancelled。Binding記録は初期draft一件だけでclear/clear-rejectedがなく、実action入口のguard拒否は観測されなかった。同じrunの原本変更26では同じ枠/点から0.069秒と0.058秒でendedして2回の消去に成功し、明示選択26でも0.069秒/0.080秒のendedと消去を通過した。接触の長短や点を原因と断定せず、待機延長/押し直しで救済しない。unified-logは11.13秒で出力上限に達したが、所有inputログ18行とxcresult-failureは正常取得。クラッシュ報告の走査5/対象一致0は原因不明と区別する。

照合：検索語clear/Native clear/消去/Input.swift/identity/cancelledでN71・N90/N92・N94/N97・U01/U11/U72・N140の詳細とfcc6ee2/d2b1c40/9cd340e/現行Navigation/Input/Viewを読んだ。N71/90/92と同じ未消去が、44pt contentShapeを既に持つ現行でも再発したため、この一行で恒常的に解消したとは扱わない。U11/N52は消去成立後の古い値/ACK照会で今回と異なる。N94/N140は最終実要素の再解決経路、N97は可視化途中のidentity寿命が違う。現在clearは可視化後もListのindex-bound queryを保持してButton.tapへ渡している。cancelledの下位原因とindex経路の関係は未証明だが、最終接触の対象を一意な現nativeとして検証できていない点は具体的に残る。

候補はvisibleの論理IDによる16探索/受動Cell操作/viewport先行観測をそのまま残し、clearが全表示かつhittableとなった最後だけ同じList/IDの実ButtonをallElementsBoundByAccessibilityElementで一度取得する。一意性・有限正枠・観測viewportへの全包含・enabled/hittableを再要求し、不在/曖昧/無効は失敗する。長寿命の外側identityをスクロール中へ持ち込まず、元Inputの同じ一回Button.tap/空欄45秒/ACK0/keyboard/全文入力/完了/保存/再起動を維持する。製品View/Binding/Strictは変更しない。候補がtouch取消しを解消するかは未検証とする。

同時に既存QA専用sendEvent observerへ、touchに付いた最大6recognizerのclass名末尾16文字・stateと3つのBoolだけを読み取りで追加する。元sendEventは一回、観測上限128・所有ログ64KiB・本文/label/target非収集を維持する。次に取消しが起きたときにgesture状態を区別する観測であり、操作/recognizer状態/期待結果を変更しない。収集側は既存旧形式も認める厳格な全行形式とし、範囲外state/Bool・7個以上・任意本文を拒否する対照を既存ケースへ追加する。既存4訂正case×両OSが共通clearの実到達と保存までを検出するため、操作を模倣するテストは増やさない。候補/事実/根拠を隔離branchへpush後にローカル契約・幾何・構文/catalogを確認し、その一回専用の新規review後に全8限定比較を行う。正式全15は別途同一source/run/attemptで要求する。

## N149 限定比較のdispatchが実行作成前に拒否（2026-10-24）

sourcebf3da563c88042805952f7749bc3a5810f97fdc0、manual-input-native-probe/case=allの作成要求がHTTP422「No ref found for: bf3da563c88042805952f7749bc3a5810f97fdc0」でexit1。指定はfull commit SHA、実行ID/試行はまだ作成されずテスト未開始。直前のfeature branch pushは成功し、ローカルのreview artifactとの同一性/clean treeも成功。対処を選ぶ前の事実として記録する。

N149照合：No ref found/422/dispatchを索引で検索し、同じ422の既往はない。旧N141はworkflow取得401で別条件。ローカルgh workflow run --helpは--refを「branch or tag」と明示し、今回のfull SHA指定がその契約外だった。旧1a5eb2dと現sourceのworkflow/case=all/両OS matrixは同一bytesと確認した。次は同じreview済みコードと今回の記録だけを含む隔離branch名をrefへ指定する。実行の作成時に一度だけhead SHAを取得し、この期待sourceと照合する。製品/QA/入力/期限/SDKは変更しない。前の要求ではActions自体が作成されていないため、新規reviewはまだ一回も開始へ消費しておらず、次の実際の限定比較一回へ使用する。別の実行へは転用しない。本記録をpush後に作成要求を修正する。

## N150 消去候補の限定比較が全8job failure終端（2026-10-24）

20:55 UTCの予定まとめ照会、source60075a3530df2ac3e1c88ce252c71e77f8d27b6e/run40130115422/attempt1。manual-input-native-probe/case=allの元4case×両OS全8jobがfailure。27の120979835807/964/836098/836122、26の120979836002/013/065/288は20:32:49〜20:35:32Zに終端した。具体的段階/ケース実行への到達/原因は完了ログ未読で未確定。対処選択前の事実として記録し、新しい全8完了ログだけを一度取得する。今回の限定成功や正式公開の成立はない。

旧正式444/run40122891165/attempt1の残26 A/job120970484512は20:32:06Zにsuccessとなり全18表示job終端。事前14件中13成功・N148の単項目26のみ失敗、公開は依存skip。取消しなし。未取得だった最後の26 Aログだけ取得し、旧13完了ログと他の終端runは再取得しない。保存artifact0もこの終端時に一度確認する。

N150完了log：全8件ともbuild-for-testingで生成されたTakupokeApp.swift:502:148が「cannot convert value of type SQL to expected argument type String」となりTEST BUILD FAILED。XCTest実操作は未開始で、N148候補のclearやgesture観測の効果は未評価。SDK27.0と26.6の双方で同じ型不一致がある。全8完了ログと旧正式444の最後の26 Aログを一度保存し、正式444のartifact0も確認済み。次の対処選択前に具体的段階を追記する。

N150照合：SQL/String/型推論/interpolation/コンパイルで索引を検索し、同じSQL推論失敗の記録はない。N03/N31/N67/N68の詳細と当時の型契約を読み、旧1a5eb2dと現60075a3のobserver・生成器を比較した。手動生成はApplicationFixtureをTakupokeApp.swiftへコピーしManualAssistanceFixtureのGRDB importも同じファイルへ追加するため、Linux parseだけではこのmodule全体の型解決を検出しない。新しいmapの戻り型/結合結果型には文脈がなく、実Apple診断では結果gesturesがSQLとして扱われていた。一意取得helperや実clearの実行失敗とは別の準備不備である。

候補はその一行の結合結果をString、map closureの戻り型もStringへ明示するだけ。各class末尾16文字・最大6・state/Bool/書式/上限128/元sendEvent一回は変更しない。String(describing:)等でSQLを文字列化せず、元の文字列を要求する。製品/geometry/clear操作/既存全期待/期限は不変。既存diagnosticsの新旧形式と範囲外拒否・project/manifest/runner/29幾何をそのまま使い、模擬UIKitコンパイルの成功は作らない。記録/候補をpush後に局所検査し、変更を含む新しい不変差分を新規reviewしてから、未開始だった元4case×両OSを再評価する。

## N151 正式445の通常iOS27 Bがfailure終端（2026-10-24）

22:11 UTCの予定確認、source3398f52c735e176d1691e9ca8d63c33164d1fa2a/run40135294847/attempt1。通常27 B/job120995758156は21:42:34Z開始・22:10:51Zにfailure終端。具体case/段階/原因は完了ログ未読で未確定、対処選択前に記録する。同runのDistribution・Native・訂正27の元4条件はsuccessで、通常27 Aは継続中。B系26は依存skip、全15成功/公開は不成立。新しく終端した実7jobログだけを一度取得し、旧run/限定8成功は再照会しない。残りの実行は取消ししない。

N151完了log：通常Bの基本6件中5成功・HomeTimetableAndWeekCalendarだけ77.337秒で失敗（全903.402秒）。Timetable.swift:176の詳細閉鎖後calendar実操作準備5秒がtimeout。時間割tab選択/最初のcard実tap/教員表示/元の詳細sheet下方dragは通過した。t57.90からのpredicateは詳細bar消失を確認し、t59.24のglobal label predicate query.countがt62.15/62.16に内部retryし、buttonのframe/操作可否・実calendar tapには未到達。入力trace対象caseではなくgesture到達原因は未観測。失敗後のAXは時間割bar、週Button一つ(119,332,155,32)、前/翌週と時間割を示す。画像289680bytes/SHA256 323ac614afcb5a1a26b54daa03be90b432d000246aba13afbf83dc17939fb08bを全65片から復元・長さ/hashを照合して目視し、sheet閉鎖・週Button表示を確認した。ただし画像時点は5秒期限の後であり、期限内のhittable成立の証明にはしない。

照合：HomeTimetableAndWeekCalendar/usable calendar/Detail must close/calendar/count/identityで索引・catalogを検索し、全体398の同じ週Button、U65の起動段階、U73のindexed query、N94/N97/N140の最終identityと寿命、N117の同じdismissLessonを詳細と当時/現sourceで比較した。7f340c8/52a945e/公開1c331818/現3398f52のcaseとNavigation/Recoveryを読んだ。全体398はsheetの背後のfirstMatchを存在だけでtapしてhitpoint無効、今回はその後に加えた全guardの中のquery.countで止まり実tap前である。製品の週picker/dismiss不具合や5秒不足を原因と断定しない。現在のreadinessはquery.countの後で同じqueryのindex0を再解決し、成功時も待機後にもう一度index0を操作する。

候補は元5秒のpredicate内で詳細bar消失・元bodyViewportを先に観測し、同じlabel条件の実Button配列をallElementsBoundByAccessibilityElementで一度得る。一意/exists/enabled/hittable/元の完全包含を全て保持し、その条件を満たした一個のnativeを捕捉して、待機後の再検索なしに元の50%中心へ一回tapする。複数はstickyな曖昧flagで失敗、0/無効/timeoutも失敗のまま。元PDFやpickerの製品/アニメーションを変更せず、詳細5秒・calendar準備5秒・週picker表示5秒・cancel・前後週の期待/両OS/全15gateを維持する。新しい模倣caseは作らず、元のcaseと既存home-launchの直前caseを同順で両OS/配布SDK27.0に通す。候補と根拠を隔離branchへpush後に構文/manifest/runner/既存幾何/catalogを確認し、新規review後だけ開始する。効果/恒常解消は未確認。

N151限定結果：6918212/run40137790557/attempt1は両SDK27.0のRuntime26.5/27.0で元2件が成功し、calendar caseは74.633/65.425秒。sheet閉鎖/全guard/元一回接触・週picker/取消/前後週まで通過した。両logを一度保存、同じrun/ログは再取得しない。これは旧内部query retryの下位原因や一般的解消の証明ではなく、正式全15は別の同一source実行で要求する。旧445の27 Aは43分20秒で成功し、残26 Aは22:25:55Zから継続中で取消しせず確認する。

## N152 正式446の三項目補正iOS26がfailure終端（2026-10-25）

00:05 UTCの予定確認、source883c9a00769d923de5c65eeef116bd183813d577/run40139246578/attempt1。三項目補正26/job121016749222は23:31:41Z開始・23:38:42Zにfailure終端。具体的段階/原因は完了ログ未読で未確定、対処案を選ぶ前に記録する。同runの27全条件と26 A・訂正26の単項目/明示選択/原本変更はsuccess、26 Bは継続中。全15成功/公開は不成立。新しい4完了jobのログだけを一度取得し、既取得9ログ/限定8成功は再取得しない。残る26 Bは取消しせず終端まで確認する。

N152完了log：元三項目caseは119.919秒・1失敗、ManualAssistanceChecks+Navigation.swift:170のvisible探索後assert。失敗した探索先は「通常時間割の詳細を見る」で、訂正/clear/入力にはまだ到達していない。直前の設定画面の「時間割ファイル」Buttonは(16,205.33,361,52.33)としてvisibleになったが、操作までAX照会が遅延し、実接触(196.67,231.67)はbegan後0.131秒でcancelled。後続の探索は依然設定の「アプリ設定」「サポート」の受動rowを上下し、一回反転後のno-progressを拒否した。最終AXも設定のままである。初報の入力欄のボタンという説明を訂正し、入口タップの未成立と、成立後の入力操作を区別する。ジェスチャー取消しの下位原因は未確定。新しい4ログを一度保存し、取得済みは再取得しない。

照合：時間割ファイル/Settings/tap helper/cancelled/native identityでU70（同じ入口の存在再照会停止）・U53（同入口前のlabel照会）・N94/N97/N140/N148の詳細と、旧1b368f5/公開1c331818/現883c9a0のmanual Navigation/launch/Viewを比較した。今回のvisibleはt29.53のhittable照会からt42台の返却まで遅れ、firstMatchのtapがFind/interrupt checkを再評価して実合成はt67台になった。U70の存在取得自体の停止、N148のclear、実復旧Listに到達してからの16探索とは段階が違う。clearのみは既に最終identity捕捉で、通常tap helperのfallbackだけは古いlabel/firstMatch queryをそのまま操作へ渡していた。取消しと再解決の因果・OSの下位原因は断定しない。

候補は通常tap helperが既に持つtitleをvisibleへ明示し、元の論理ID/16探索/viewport先行観測/受動Cell/一回反転を維持する。全表示かつhittableとなった最終段階で、既知IDがあればそれも残した同じtitleの実Button配列を一度だけidentityで取得し、元clearと同じ一意性/有限正枠/完全包含/enabled/hittableを要求して返す。clear/通常button以外やfixture menu固有操作は変更しない。元の一回Button.tap/中心・全45秒・入力全文/ACK/取消/4項目拒否/旧データ保持/背景/保存/再起動は維持し、不在/曖昧/無効は失敗する。新しいlabel照会を別AX getterで行わず、呼出し済みの固定titleを使う。

既存project契約の一行だけは、knownIDを保持した同じvisible委譲に新しいbuttonLabel引数も渡すAPIへ追随させる。結果やfixture期待を変えるものではなく、元の実操作4case×両OSを保持して共通helperの入口から保存まで検証する。模倣テストは追加せず、効果/恒常解消は未確認。事実/比較/候補を隔離branchへpush後に既存project/manifest/runner/29幾何/診断/構文/catalogを確認し、新規review後に全8限定比較を行う。元正式の残26 Bは取消しせず、完了/新ログ/artifact0を別に一度確認する。

N152限定比較：dfb62cb/run40145652153/attempt1の元4case×両OSは全8job成功。三項目26も434.859秒で入口から元ケース末尾まで通過し、単項目/原本変更/明示選択も両OSで失敗0・厳密完了照合に成功。全8logを一度保存し再取得しない。旧446は26 Bも45分24秒で成功して全18表示job終端・13事前成功/三項目26失敗1/構成依存skip4・全14実job完了log取得済み・artifact0。この限定成功を旧失敗の根本原因や恒常解消、正式公開・実機確認へ一般化しない。次の新source全15で全case/期限を維持する。

## N153 正式447の通常iOS27 Aがfailure終端（2026-10-25）

02:15 UTCの予定確認、sourced8d32e415dbbf5faac5ee928851e85d2ffa51c20/run40148629240/attempt1。通常27 A/job121035524811は00:57:38Z開始・01:42:24Zにfailure終端。具体case/段階/原因は完了ログ未読で未確定、対処選択前に事実を記録する。27 Bとその26 B/job121041550080はsuccess、Native/Distribution/訂正27全4条件もsuccess。全15表示jobは終端し、8事前成功・27 A失敗・構成依存6skip（公開は未実行）。残26 Bも02:08:52Zに成功し、取消しはしていない。新しいA/B26の2ログだけを一度取得し、終端時artifact0も一度確認する。既取得7ログ/旧run/限定8成功は再取得しない。全15成功/公開は不成立。

N153詳細：27 Aの基本17件中16成功、testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunchのみ417.753秒で失敗（全2280.045秒）。ApplicationChecks+Navigation.swift:130の実Keyboard配列取得でmatching snapshotのUI query timeout。直前はSettings/時間割ファイル/変更詳細へ移動し、103行件数/解析済み/除外範囲を通過した後、「変更後、架空科目C」をvisibleで探した。t153.82のsettled predicateでNavigationBar/TabBar/Cのqueryが内部retryし、t155以降app frameの取得とsnapshot要求が長く停止した。1:11:50にfatal、当該表示が消えたかAX取得だけが不成立か、プロセス/メモリ/OS等の下位原因は未確定。単にkeyboardが存在しなかったためと断定しない。次のcaseは新たに開始した。対処選択前に具体的観測を追記し、最初の採用前か再起動後かと元sourceを引き続き照合する。

N153追加照合：3/4/groupの実Switch接触とvalue1、確認取消/正式採用、103行・解析済み・範囲と残したC/消したBは初回に通過した。t108.74にpid13186をterminateし、一回起動したpid17476はfixture-readyまで成立。失敗は再起動後の103行/解析済み/範囲を確認した最後のC可視化である。次caseのsetupも同pid17476をterminateしており、ログだけでcrash/終了とは扱わない。pid17476のlifecycleはreadyまでで、停止中のmain threadの待ち先やCPU状態は未採取。U05の不在keyboard・U73/U70/U53のAX照会、N146の接触未反映、N151/N152の最終要素再解決と当時/currentのhelperを読んだが、今回はkeyboard以前のroot/frame/navbarまで応答が失われている。keyboard取得方式だけを推測変更しない。

次は製品/Swift helper/元行除外case/待機期限を変えず、同じ通常Aの元先行case（AuxiliaryReadFailures）と行除外caseを同順でiOS27/SDK27.0へ通す診断だけを行う。通常公開SHARDS/全15gateは変更しない。限定rows-contextだけに、該当caseのsnapshot要求後20秒間出力が止まったときのread-only sampleを追加する。現在のapp bundle実行pathとpsの実行pathが一致したpidだけを対象に、1秒/10ms sampling・command5秒・最大2process各1回・4MiB以内・main thread最大48symbol/既知library/文字種制限だけをconsoleへ出す。raw header/path/他thread/任意本文は出さず所有一時ファイルを回収する。アプリやAX serviceへ入力・kill・再起動は行わず、観測は停止原因の証明や合格の代用ではない。ケース/phase終了時はstop markerでwatcherを終え、元pipeline失敗・signal・cleanupは維持する。新しい観測という目的の限定再評価であり、同じ条件を根拠なく合格するまで反復しない。

同時にN148で追加したgesture列を通常runnerの古い入力ログ正規表現が全行拒否していた不整合を確認した。既存の厳格なmanual input_trace_linesを通常回収へ共用し、旧/新形式と128行/64KiB・本文拒否を同じに保つ。入力の生成・判定は変えず、正常な新観測行の欠落だけを直す。新しい診断にはowned executable不一致拒否、main thread以外/任意path/body/未知library拒否、48frames/2process上限、stop/非対象caseの無観測、実normal回収での新形式保持と本文排除の動作対照を追加する。候補/比較/根拠を隔離branchへpush後に検査し、その一回専用の新規code-only review後にだけ診断Actionsを開始する。今回の根本原因や修正候補の決定は追加観測後とする。

診断候補b60e566のローカル観測器7件/失敗0（0.051秒）、実shell runner14件/失敗0（23.071秒）、manifest28件/失敗0（4.805秒）、既存診断11件/失敗0（0.237秒）、shell構文/catalog450/check --base d8d32/固定枝一覧が成功。Appleのsample/実停止は未実行で、これらを原因解明やUI合格へ数えない。既取得447のDebugリンクlogにはTakupoke.debug.dylibがあるため、その固定libraryとSQLite/dispatch等の固定OS libraryもsymbol filterへ登録し、Debug本体frameが欠落しない正対照を加える。未知library/本文/path/他threadの拒否と全量上限は維持する。追加分も先にpushしてから同じ観測器とaffected catalog接続を確認する。

188fa00追加分をpush後、観測器7件/失敗0（0.045秒）、workflow source paths3件/失敗0（0.002秒）、catalog14件/失敗0（0.285秒）とcatalog450/check --base d8d32が成功した。新runner methodの宣言を含む生成一覧も更新した。これらはLinuxの拒否/正対照と実shell制御の確認であり、macOSのsample出力取得や停止原因の確認ではない。

次のrows-context/iOS27/SDK27.0限定dispatch一回専用に、新規GPT-6.1 Sol/High ios_n153_stack_pre_actions_reviewがpatch487行/24491bytes SHA256 9efc7d406285abb9668b97199ac831d3f212c2f9496a3cde03c1da83a50bf043、runner201行/11120bytes fb32945a…、manifest263行/12254bytes 0baae5ae…、既存bounded command18行/1048bytes 2ad91a52…の全969行/bytes/hashを確認し、具体的指摘なし。主担当も現差分と同一性/元の二件・全期限/局所結果/cleanupを照合した。このreviewは次の一回だけへ使用し、main pushや正式公開へ転用しない。

N153限定source2acdaf1306d6c762773708150d50476185b2e95a/run40155216742/attempt1は02:53:57Zにsuccess終端。予定03:10の一括照会で終端を確認し、唯一の完了logを一度だけ保存した。SDK/Runtime27.0、元AuxiliaryReadFailures130.724秒・行除外204.433秒、合計335.157秒/2件/失敗0。元3Switch一回接触/取消/103行採用/再起動後のC保持とB除外まで通過した。TAKUPOKE_APP_STACKは0行で、quiet20秒の停止は観測されずmacOS sampleの取得成否も未評価。旧417.753秒の下位原因や恒常解消を証明せず、この終端run/logを再照会しない。

限定前後のSwift製品/helper/元case/期限は同一bytesで、今回の成功だけを根拠にkeyboard等を変更しない。U05/U73/U70/U53/N146/N151/N152とd8d32/2acdaf1の照合結果を維持する。次は同じobserverを正式の通常27 Aだけでも有効にし、限定では未再現だった旧停止を、残る全case/既存phase/公開gateを保った実行内で採取可能にする。限定成功を正式合格へ繰り上げる変更ではなく、通常の全15を新しい同一source/run/attemptで確認しつつ追加観測する。失敗時は公開せず新しい事実から調べ、成功時のみ既存の全15gateで公開する。観測器の個数/対象case/所有path照合/出力制限/cleanup/全操作と期限は不変。他OS/他shard/手動訂正のenvは変更しない。

次のmain push/正式全15/条件成立時の公開一回専用には別の新規GPT-6.1 Sol/High ios_n153_main_pre_actions_reviewが、patch499行/24996bytes SHA256 1da3d56c3328ff77169f77d8dcd5b22ff58014ba51e7dedce1e40f5828ba47d8、正式workflow462行/19976bytes fe98bfe2…、runner201行/11120bytes fb32945a…、manifest263行/12254bytes 0baae5ae…、bounded command18行/1048bytes 2ad91a52…、既存input parser14行/739bytes 11d64447…の全1457行/70133bytes/hashを確認し、具体的指摘なし。主担当が現差分との同一性、元全15と失敗伝播/cleanup、限定結果の限界と全未送信commitの空白を照合してから使用する。限定専用review/成功は転用せず、同じ新source/run/attemptの正式全15を要求する。

正式source67273c0eb2c6fa2b0b950c7dce140a841954ed38/run40157376822/attempt1の03:58予定照会で事前7条件成功。通常27 Aは17件/失敗0（1812.814秒）と通知1件/失敗0（60.336秒）、行除外277.549秒で元103行採用/再起動/C保持/B除外を通過した。TAKUPOKE_APP_STACKは0行で、20秒静止や旧停止の下位原因は観測されておらず恒常解消とは扱わない。Native688件/予定skip1/失敗0（117.617秒）、Distribution Python287件/失敗0（94.315秒）、訂正27の単項目526.852秒・三項目422.375秒・明示選択851.182秒・原本変更262.058秒も成功。新しい7完了logだけ一度保存し、旧run/logは再取得しない。通常27 Bは03:29:25Z開始で継続、26 Aは03:57:27Z開始、全15/公開はまだ未完了。Bの開始遅延と旧32〜45分/26約45分を踏まえ、次のまとめ照会は04:55 UTCとする。取消しはしない。

N153後の正式source67273c0/run40157376822/attempt1は全15成功・全18終端・artifact0。元の通常Aの行除外/再起動保持は両OSで成功し、27 observerのsample出力は0行。旧AX停止の原因/恒常解消は未証明だが、元ケース/期限/全15を保った新sourceで449.1を公開し匿名4添付/IPA/固定Sourceを照合した。全15実logは一度保存し、この終端run/log/artifactは再照会しない。物理端末性能の未確認は66/67へ残し、UI合格と混同しない。

## N154 SDK更新準備のローカル検証filterが0件（2026-10-26）

base653eb55+候補patch SHA256 c3f16f98c134aa3686a47ad7a104e404c6e4c5d9abea402065b320f5bcceff76、Linux Python。manifest28件は27成功・1件がSwift不在で予定skip（3.826秒）。toolchains/env.shを読んだ後、補完のつもりで-k observed_screen_geometryを指定したが、実際の未実行case名はtest_link_menu_observes_one_press_before_diagnostics_and_never_accepts_timeoutであり、結果は0件/NO TESTS RAN。コードやUIの成功ではなく、主担当の検証選択の誤りとして対処前に記録する。ログci-update-manifest-check.log/ci-update-geometry-check.log。

N77の空観測と詳細を読み、今回は観測callbackではなくunittest filterが宣言名に一致しない違いを確認した。base/currentのtest_ui_test_manifest.pyは同じbytesで、該当caseはSwiftの実link menu helperを実行する。次は既存env.shと正しい一件の宣言名で実行するだけで、テスト本体/期待値/元UI操作/期限や製品には変更しない。最初のskipと0件を成功へ換算せず、記録を隔離branchへpushしてから不足分を確認する。

N154補完：既存env.shでSwift6.1.2を選び、正しいtest_link_menu_observes_one_press_before_diagnostics_and_never_accepts_timeoutを一件実行し失敗0（1.943秒）。元の一回press・menu欠落の拒否・診断境界を実helperのLinux harnessで確認した。これは実Simulator操作ではない。最初の27成功/1skipと補完1成功を区別し、0件の試行も記録に保持する。コードdiff SHA256 c3f16f98…はreview artifactと同一で、期待値は変更していない。

## N155 SDK更新後の正式CIで単項目補正iOS26がfailure終端（2026-10-26）

18:15 UTCの予定照会でsource7b73f1e13d03792b9a0f10b302a09e5599e0fe03/run40361714059/attempt1、job121732589765のtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundが17:25:43Z開始・17:40:18Zにfailure終端と確認した。手動26の指定Xcode26.6/SDK26.5は旧449.1と同じで、実Runtime・具体的失敗段階・原因は完了ログ未読のため未確定。対処案を選ぶ前の事実として記録する。同runの他13事前条件は成功し、公開は依存skip。全18表示jobは終端・取消しなし・公開未実施。新しい6実job完了ログだけ一度取得し、先に保存した8ログと旧runは再取得しない。終端artifact0を一度確認し、新ログ・過去詳細・当時/currentコードの比較と候補根拠をpushする前に再試行しない。

N155完了log：272.372秒・1失敗、Input.swift:56の元45秒ACK value1待機がtimeout。初回の消去・全文「架空手確認科目」入力・完了/keyboard閉鎖・ACK未確認value0は通過し、表示サイズ/原本同一再確認/背景/保存へ未到達。ACK外枠(16,646.33,361,52.33)、子Switch(300,658.67,63,28)、viewport(0,141,393,699)、keyboard absent、enabled/hittable=trueを観測。一意nativeの中心(331.5,672.67)へ一回0.1秒接触した。実touchは17:38:48.544664Z began・.706237Z cancelled（約0.162秒）、Binding観測はclear/textのみでackなし、最終input-stateもack=false。下位のgesture取消理由・OS/SDKとの因果は未確定。新6logを一度保存し、全14実jobログ取得済み・artifact0も一度確認済み。このrun/log/artifactは再照会しない。

照合はACK/cancelled/Input.swift/U71/N66/N93/N94/N97で検索し、U64/U71/N66/N93/N94/N97/N148の詳細、旧2a22448と現Input/Navigation/生成器・正式workflowを読んだ。N93の同じ内側中心への接触取消しと類似するが、今回の接触はN94後のnative identityから正常合成されており、その再解決停止とは違う。0.1秒方式でも未反映は既往があり、接触時間/点の往復・押し直し・ACK注入・待機延長を根拠なく行わない。通常27.1/Runtime26.5のA/Bは今回とも成功し、手動26だけは旧26.6/SDK26.5でビルドされていた。

利用者のSDK更新指示に沿った次の候補は、正式の手動26も配布と同じXcode/SDK27.1へ揃え、既存prepare-ios26-runtime.pyで元Runtime26.5を完全照合してから同じ4caseを実行すること。Nativeの旧26.6/実SDK26.5と任意の旧手動probeは維持し、27.1が旧SDKの取消し原因を修復したとは主張しない。実製品/Swift helper/全case/入力全文/独立ACK一回/45秒/背景同一process/保存再起動/全15gateには差分を加えない。通常26が既に同配布SDKで通過した新条件を手動26にも適用して、更新後IPAに使うSDKで両OSの実操作を検証する。既存manifestの固定SDK期待を更新し、両手動laneのSDK変数とRuntime準備が実操作より先にあることを要求する。新しい模倣caseは追加しない。候補・事実・比較を隔離branchへpushしてから関連検査を行い、新規専用review後に新sourceの正式全15を一回実行する。旧失敗の原因・恒常解消・全15成功はまだ未確認。


## N156 issue105/106修正のLinux Python検査でエラーを観測（2026-10-27）

source34c40d2に対する未コミット修正、Linux/Python3.14・Swift6.1.2。全Python検査の最初の実行は進行中にEを表示した。終了時のcase名・診断はまだ出力されておらず、SwiftUI/Apple SDKの失敗や製品原因とは断定しない。次の試行・対処決定前に完了結果と過去索引/該当コードを照合する。並行しているSwift Package検査は別の実行であり、同じ結果と扱わない。

N156完了診断：288件/3error/予定skip22、981.437秒。Assertion失敗ではなく、test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtimeの27.2/Runtime27.0+27.1対照がshell5秒、test_failed_or_duplicate_first_batch_stops_without_retry_or_size_checksのduplicate_result対照がshell15秒、test_actual_apply_keeps_denial_separate_from_storage_success_and_failureがSwiftコンパイル60秒でTimeoutExpired。いずれも実Simulator/UIではなく、今回変更していない既存のLinux境界検査。ホストRAM約2GB/swap約2.5GB使用、並行SPM/Pythonと別作業ビルドを観測した。N57の一時領域不足とは異なり、今回は空き約20GBで、/tmp容量エラーも未観測。期限/期待値を緩めず、同じホストの所有SPM完了後にこの3ケースだけを逐次実行して資源競合の候補を照合する。記録はPRを再起動しない別の記録refへpushしてから実行する。

N156逐次照合：SPM601件/失敗0・全工程1568.6秒の終了後に、同じ3ケースだけを元の期限/期待値で実行。shellの2ケースは成功し、通知Swift probeのコンパイルは同じ60秒で再びTimeoutExpired。3件/1error、72.557秒。製品assertやprobe実行には未到達で、並行SPMだけが原因だったとは断定しない。この観測を先に記録し、所有する残存compiler、/tmpと通常ディスク、N110の同じ実メソッド検証と現行probeを比較してから次の対処を決める。

N156対処前比較：所有compilerの残存はなく、SPM終了後も同じprobeだけがcompile60秒で停止したため、資源競合だけとは扱わない。既知記録はN110ではなくN118（通知拒否と保存成功）で、a183a2bから現在まで製品applyとこのprobeの[String:String]の境界型は同一だった。実OSのUNNotificationContent.userInfoは[AnyHashable:Any]（Apple公開宣言）であり、現在のstubは異なるString専用型のため「条件付きdowncastが何もしない」の診断も出ていた。候補ではこの非実行OS境界の型だけを実宣言へ合わせる。製品本文・全assert・コンパイル60秒/実行15秒・他caseは維持し、記録refへpush後に当該1件で比較する。

N156境界型の比較結果：同じ製品本文・全assert・60秒/15秒の期限を維持した[AnyHashable:Any]境界の当該1件は10.763秒/失敗0で完了した。元の[String:String]の型での直前の60秒停止と区別する。コンパイラ内部の根本原因や恒常的な時間を断定しない。shellの2件も元条件で成功済みだが、全288件をこの修正後に通し直した結果ではない。

N156最終ローカル結果：[AnyHashable:Any]境界を含む全Python288件を、同じ期待値・ケース・期限のまま単独実行し、149.469秒/失敗0/予定skip22で完了。初回981.437秒の3timeoutや、逐次の通知probe60秒停止を成功件数へ合算しない。元の通知製品本文・復旧/保存/OS応答のassertionは変更していない。


## N157 issue105/106修正のiOS27 Aがfailure終端（2026-10-27）

sourcec0605c4f2d008579b6c6f77d59a4d27bf44d80b6、run40453620829/attempt1、job122022215143。SDK27.1/Runtime27.0、開始05:25:26Z、終了05:57:04Z、05:58 UTCにfailureを確認。完了ログ未読のため、失敗case・操作・build/実行の段階・原因は未確定。製品のclock境界や期限切れ表示が原因とは断定しない。先行B/Native/iPhone build/手動27四件は成功、後続source86b1f3fは別実行で混同しない。対処決定前に記録し、全残ジョブを取消しせずに確認する。

N157完了log：build成功50.3秒、通常AのtestChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunchが145.127秒で失敗。Navigation.swift:223の元45秒の一意・全包含・操作可・状態一致native Switch観測が不成立。3行目の選択後、4行目の存在確認は成功したが、内側「0」Switchのframe再解決で内部retryとsnapshot採取が入り、接触前に失敗した。4行目へのtouch不達やBinding不発ではなく、接触へ未到達であり、下位原因は未確定。新規Home境界ケースは18.022秒で成功し、clock修正の失敗とは扱わない。ログは一度だけ取得し保存済み。

照合はcase名/change-skip/native identity/Navigation.swiftでN146/N147/N153と現helper/元caseを読み、N146当時184f7ed、N147後abd6d2f、公開main34c40d2と今回c0605c4の該当本文を比較する。N146は3行目の接触後value待機、N153は保存再起動後CのAX照会停止で、今回の4行目・接触前のnative再解決とは段階が違う。後続86b1f3fの通常Aは失敗観測前05:49:20Zに既に開始しており、通常helper/元case/期限は同一。推測の製品変更や無根拠の追加再実行を開始せず、この進行中の必須検証を終端まで確認する。一回の成功を恒常解消へ一般化しない。

N157後続の観測：source86b1f3f/run40455341102/attempt1の通常27 A/job122027886329は05:49:20Z開始・06:26:45Zにsuccess終端。元の行除外caseは149.499秒で行3/4/group一回操作・取消/103行の保存/再起動保持まで成功した。通常18件/失敗0（1691.169秒）と通知1件/失敗0（53.202秒）、新規Home境界は24.128秒で成功。helper/元case/全期限は失敗sourcec0605c4と同一であり、再実行はN157観測前に開始していた。旧AX再解決失敗の根本原因・恒常解消は未証明で、追加の無根拠な再試行やhelper変更は行わない。同sourceの27 B、訂正27四件、Native、iPhone Releaseも成功し、26は別途継続中。

## N158 issue106の旧時計実Home比較がfailure終端（2026-10-27）

source9cb40b1f4ebb42722106e200742cfe3b5b0bd05a、run40459050676/attempt1、job122039064294。SDK27.1/Runtime27.0を指定したhome-boundaries一件の診断は06:10:44Z開始・06:18:56Zにfailure終端、06:22 UTCの予定確認で観測した。完了ログ未読のため、製品/準備段階・具体assert・実Runtimeの確定と原因は未確認。旧時計処理が原因との結論や期待した負対照としての採用は、ログの実画面到達を照合してから行う。修正候補の正式CIとは別sourceであり、失敗・成功の件数を合算しない。次の試行・対処を決める前の事実として記録する。

N158完了log：指定どおりSDK27.1/Runtime27.0、build成功。実Home起動と架空授業cardの存在、境界前の「授業中」なし、開始境界の設定Button一回tapまで通過した。ApplicationChecks+Timetable.swift:13の元10秒待機がtimeout2、case35.696秒/失敗1。実AXのcard labelは「科目、架空境界確認科目A、時刻、08:50～09:35、教員、架空教員A、教室、架空教室A」のまま、授業中を含まなかった。終了側の操作へ未到達。これは単なるchanged件数ではなく、時計入力を制御した実SwiftUI画面の古い表示の観測である。

N158比較：N157の別のSwitch取得失敗と区別し、issue106の最小観測と公開main34c40d2/修正c0605c4/旧clock診断9cb40b1の実本文を照合。新規Home case・fixture・設定操作・元10秒の期待は同じで、診断のTimetableBoundaryClock.swiftだけをmain34c40d2の完全なbytesへ戻した。修正済みc0605c4は同じSDK/Runtimeの同case18.022秒で開始/終了の実表示を通過した。旧版の実画面不整合の再現対照として採用し、診断branchを製品へ統合しない。実機での頻度・フレーム時間や正式全15合格の証明には一般化しない。追加の同条件再実行は不要。

## N159 issue105/106修正の通常iOS26 Bが二sourceでfailure終端（2026-10-27）

06:52 UTCの実測所要時間に基づく一括確認で、先行sourcec0605c4/run40453620829/attempt1/job122031408841は06:08:59Z開始・06:26:54Zにfailure、後続source86b1f3f/run40455341102/attempt1/job122041356319は06:13:04Z開始・06:45:31Zにfailure終端と確認した。通常laneはSDK27.1/Runtime26.5を指定。完了ログ未読のため実Runtime、失敗case/操作/準備段階・原因、両者が同じ原因かは未確定。source22cb3f8/main run40461806832はこれらの失敗観測前06:33:25Zに開始済みで、旧二run/最新mainの成功を合算しない。対処案選択前に観測を記録し、新ログと過去の該当詳細/当時と現sourceを照合する。実行中は取消ししない。

N159先行c0605c4の実log：SDK27.1/Runtime26.5、build成功。testHomeTimetableAndWeekCalendarは60.258秒で失敗、ApplicationChecks.swift:101の起動準備fixture-ready元45秒が不成立。実AXはApplicationだけで子要素なし。pid98987はinit-enter/seed-enter/seed-complete/scene-constructionを記録し、root-task-enter/content-appeared/application-ready/fixture-readyは未観測。具体的な下位停止原因・crashとは断定しない。基本6件中ほか5件は成功し、通知/文字サイズ/VoiceOverの後続phaseは未実行。

N159後続86b1f3fの実log：同SDK/Runtime、buildと通常10件/文字サイズ段階は成功し、HomeTimetableは64.081秒で成功した。別RunnerのtestNotificationControlsAndAppearanceだけ136.458秒で失敗。Notifications.swift:112、元45秒の許可/有効化待機。通知画面へ移動、read不要の正規分岐authorization=notRequested/scene=active/application=0、実Switch外枠(16,165,361,52.333)/子(300,177.333,63,28)/双方0・操作可を確認し、一回0.1秒のnative接触を合成した。前後ともrequesting=false/changes=false/saved=false、実Binding/native許可要求のlifecycle記録なし。許可ダイアログへの進行は未到達で、U15のrequesting=true後のOS応答待ちとは異なる。接触の実配送先/取消し・下位原因は今回未採取。SpringBoard等の稼働情報だけから原因を推定しない。

N159照合：fixture-ready/launch/U65とnative Switch/notification/U64/U30/U15/U77/N146を検索して詳細と当時983e523/841a389/fd6e42c・公開34c40d2・今回c0605c4/86b1f3f/22cb3f8の本文を比較した。U65はprocess handle不在で今回はseed-complete後の空AX、U64は同種の接触未反映だが別のAI Switch、U15は実許可要求後で今回はその前。製品通知・通知case/許可probe/通常Switch helperは今回のdiffで未変更。旧fd6e42c後のpanel受動化も現行で保持されている。SDK/点/接触時間/45秒・元のUI/保存/再起動条件を推測変更せず、まだ実行中のmain22cb3f8（両失敗の観測前に開始）の元必須検証をまず確認する。無根拠の追加再実行は開始しない。

旧c0605c4/run40453620829は全15表示job終端、事前成功8/失敗2/依存・構成skip5、artifact0。全10実jobの完了logは一度取得済みで、この旧run/log/artifactを再照会しない。後続86b1f3fの訂正26の単項目480.844秒と三項目433.709秒は成功し、残る26 A/明示選択/原本変更は継続中。これらの成功を旧/後続の失敗へ置き換えない。

N159画像確認：失敗時のnotification-switch-unresolvedを36片から所有一時領域へ復元し、157849bytes/SHA256 b335f3ec688d7accf3fb66f9098ae3863971654de11e03f26689209ef9becbc8を照合して目視した。通知画面で両SwitchはOFF、許可ダイアログはなく、QAの「許可画面を確認」Buttonは画面中央より下にあり実Switchを視覚的に覆っていない。画像は期限後の状態であり、入力時点の配送先/gesture/Bindingの証明にはならない。画像の所有一時領域は確認後に回収し、公開ファイルへの画像添付はしない。

N159後続PRの終端：source86b1f3f/run40455341102の最後の26 A/job122045793511は07:15:30Zにsuccess。基本18件/失敗0（1815.309秒）と実通知1件/失敗0（95.251秒）、新規Home境界18.062秒、元行除外181.606秒で成功した。Home境界は同じ修正版の両Runtimeで成功。訂正26の明示選択1282.790秒・原本変更240.522秒も成功して四件すべて完了した。PR実行は全18表示job終端、14成功/26 Bの失敗1/依存・構成skip3、artifact0。全15実job完了logを一度だけ取得済み。この終端run/jobs/log/artifactを再照会せず、26 Bの失敗を他成功で救済しない。main22cb3f8/run40461806832ではLinux288件/予定skip22、Native691件/予定skip1、訂正27全四件、通常27 Bが成功し、元の26 Bは07:32:22Zから別途実行中。main全15/公開の成功はまだ未確認。

## N160 issue105/106取込み後mainの単項目訂正iOS26がfailure終端（2026-10-27）

08:21 UTCの実測所要時間に基づく一括確認でsource22cb3f8d5ed60800611c4f99af667d1d0b3bd15d/run40461806832/attempt1、job122070104137、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundが07:41:40Z開始・08:08:11Zにfailure終端と確認した。指定SDK27.1/Runtime26.5、実Runtime/ケース到達/具体失敗段階・原因は完了ログ未読のため未確定。mainの通常26 Bは元通知操作を含めsuccess、訂正26のほか三件もsuccess、通常26 Aだけ継続中。main全15/公開成功は未成立で、残実行は取消ししない。対処案選択前の事実として記録し、新しいログ・過去の該当詳細・当時と現sourceの照合後に候補を決める。

N160実log：SDK27.1/Runtime26.5、build成功。752.475秒/失敗1、Navigation.swift:90。初回入力/独立ACK、背景同一process、再編集と確認previewまで通過し、最後の「この資料全体の結果を使用」Buttonへの実接触前に失敗した。16探索の7回目、indexed対象の枠(16,697.333,361,100.667)とviewport(0,141,393,699)を観測し、既存manualVisibleCandidateによるindexed hittabilityは成立した。その後同じlabelのButtonをaccessibility identityで取り直し、別のframe/全包含/enabledを通過したが、native isHittableがActivation point invalidで例外を記録した。native側の正確な枠は未出力で、実touch/採用保存/再起動は未到達。入力trace68行、owned-app-logはoutput-capで終了。OSの下位原因や製品adoptの不具合とは断定しない。

N160照合：Activation point invalid/native Button/Navigation.swiftとN126/N152/N94/N97の詳細、旧2a81f3a/883c9a0/dfb62cbと公開34c40d2/今回22cb3f8のhelper・純幾何・元単項目caseを読んだ。N126は外側ACK rowへのhit照会で今回は採用Buttonの最終identity、N152は入口tapの再解決で今回はその後の保存直前。N152後も通常Buttonにはindexed対象のhit判定と、取り直したnative対象のhit判定が二重に残る。今回は最初が成立してから次が失敗し、同じ物理対象を別表現で照会する間隙がある。製品PDFRecoveryView/全期待と今回helperはP3修正で未変更。

候補では外側indexed対象を位置探索と全包含確認だけに使い、実Buttonの一意なnative identityを取得してから、その同じ要素の有限正枠/viewport完全包含/enabled/hittableを全て要求して一回だけ操作へ返す。現在のnative最終guardは一つも減らさず、indexed対象への重複hit照会だけを避ける。既存clear/通常tapに適用し、入力/ACK/代替候補やfixture menuは現状維持。native枠と既に観測したviewportを受動ログへ出し、追加AX照会は行わない。N152前のfirstMatch接触へ戻さず、16探索/一回反転/受動Cell/全45秒/元の入力全文・UI・保存・背景同一process・再起動と全15gateを保つ。下位原因・改善は未確定。候補とこの比較を非起動refへpush後に既存の幾何/project/runner/manifest/構文/catalogを確認し、新規code-only reviewの後に新sourceの正式全15で確認する。旧mainの残26 Aも取消しせず終端まで確認する。

N160候補の局所確認：非起動branchのsource200c4c9をpush後、Linux Swift6.1.2を現在の/home/ubuntu/.local/share設置先で明示して既存manual系Python39件/失敗0（23.143秒、skip0）と、その実行内の元純幾何29件/失敗0（0.206秒）を確認した。native helperのSwift構文とcatalog450/check --base22cb3f8、全commit空白も成功。元単項目case/全assert/45秒/一回操作/全15gateとテスト宣言を変更せず、同ケースと元四件×両OSが差分の検証を担うため模倣caseを追加しない。実iOSの改善はまだ未確認。

N160旧main終端：source22cb3f8/run40461806832の最後の26 Aは08:26:18Zにsuccess。元18件/失敗0（1563.927秒）と実通知1件/失敗0（99.023秒）、Home境界16.794秒、行除外156.936秒も成功した。旧main全18表示job終端、事前成功13/単項目26失敗1/構成・公開依存skip4、artifact0、全14実jobの完了log取得済み。この旧run/jobs/log/artifactを再照会しない。26 BのHome46.687秒と通知155.300秒は同sourceで成功しN159は非再発だが、旧起動/入力配送の下位原因・恒常解消とは一般化しない。旧失敗は全て保持し、公開は未実施。

N160追加実bytes照合（08:34 UTC）：git showで2a81f3aのgeometryより先にtarget.isHittableを呼ぶ本文と、883c9a0のclearだけnativeへbindする本文を確認した。dfb62cbから22cb3f8のNavigation.swift実diffは0行で、N152後の通常Button二段階観測が今回まで同一だったことを再確認した。この出力を当時コード比較の具体的根拠として補完する。候補は旧index/firstMatchへの接触へ戻していない。

N160新しい正式実行：新規専用reviewのcode hash一致と局所結果を確認後、mainを8e01eb6c7528453b5b7e71d95c99079ec9faec65へ通常fast-forward pushし、run40474382684/attempt1が08:33:53Zに開始。Distributionは288件/予定skip22/失敗0（88.275秒）で成功。元の両OS/手動訂正四件ずつ/全15を維持し、新sourceの全結果を確認中。旧22cb3f8の成功を取り込んだ判定にはしない。main同期時の元16/85行の未コミット追記は上流と元snapshot全行の順序保持を検査して保持し、今回所有のautostash4886c0fだけを回収した。

## N161 native Button観測整理後の通常iOS27 Bがfailure終端（2026-10-27）

08:58 UTCの実測所要時間に基づく一括確認で、source8e01eb6c7528453b5b7e71d95c99079ec9faec65/run40474382684/attempt1、job122089516799の通常iOS27 Bが08:35:33Z開始・08:56:17Zにfailure終端と確認した。指定SDK27.1/Runtime27.0、失敗case/操作/準備段階・実Runtimeと原因は完了ログ未読のため未確定。候補の変更対象は手動訂正Navigationで、通常UIへの因果は未確定。Native/原本変更27/三項目27はsuccess、通常27 A/単項目27/明示選択27は継続中、通常26 Bは依存skip。単項目のN160対策の成功・失敗とは混同せず、残実行を取消ししない。対処案選択前に記録し、新ログと過去の該当詳細・当時/current本文を照合する。

N161実log：SDK27.1/Runtime27.0、build成功。testLinkPreferencesSurviveRelaunchが358.215秒で失敗、Settings.swift:360のBrowserView?内部identifier prefixを使ったOther要素の元30秒存在待機中にmatching snapshot timeout。お気に入り解除/一回再起動/実追加メニュー/追加/復帰行hittable/本来のprimary tapは通過した。primary tap後の約98.76秒からBrowserViewの照会が停止し、内部retry後357.73秒で例外、native Close/閉鎖/一覧復帰のassertには未到達。通常6件中ほか5件は成功、後の設定/文字サイズ/VoiceOver/通知phaseは依存未実行。手動NavigationのN160とは実行するSwiftファイルも操作段階も違う。

N161照合：LinkPreferences/BrowserView/Safari/primary tap/localhostでU42/U54/N44と該当実装を検索し、e4f2fbf/bf1749aの当時case/SafariLinkViewをgit show、bf1749aから現8e01のSafariLinkViewのdiff0を確認した。U42/U54は本来の長押し後にブラウザが開く/白画面、今回は実メニュー二回と再起動保持が成立した後に、本来のprimary tapを確認する段階で停止している。操作点/2秒長押し/45秒/お気に入り期待を往復しない。現fixtureリンクはhttps://fixture.example.testで、Foundation URLProtocolはSFSafariViewControllerの別サービス通信を置換しない。ブラウザの読み込み/AX service/内部identifierのどれが下位原因かは未確定。

候補ではこのcaseの入力先をUI test processが所有する127.0.0.1の小さい固定HTML serverへ限定し、appの既存リンクモデルと本物のSFSafariViewControllerをそのまま通す。serverは初回起動より前に開始し同じcaseの再起動中も保持、tearDown/解放で回収する。入力HTMLの実表示を元の30秒で確認し、本物のnative Closeの存在/操作可/一回tap、実ページ消失/一覧復帰も維持する。SDK内部BrowserView?識別子の存在だけより実内容まで要求し、到達不能URL/DNS依存と私的識別子への依存を除く。公開アプリ/長押し/実メニュー/保存/再起動/全UI case/全15gate/元の期限を変えず、表示成功やOS結果は注入しない。serverのloopback限定・固定route/応答・bytes・停止を実ネットワークの局所テストで確認し、候補/比較を先にpushしてから検査する。改善・下位原因はまだ未確認。

N161候補の事前補正：LinkOpeningMode.destinationの実本文はHTTPSだけをinAppにするため、保存リンク自体をHTTPへ変えると外部ブラウザ経路へ変わることを確認した。保存リンクのHTTPS/ID/設定を維持し、実primary actionが製品の経路選択でSafariLinkViewを作成した後、その一時生成コピーのSFSafariViewControllerに渡す通信URLだけをloopbackへ置換する。URLProtocolで置換できない別プロセス通信の入力境界だけをfixture化し、経路選択/実controller/委譲/Closeは製品本文を使用する。実内部BrowserView?確認が追加されたdfb185cのdiffも読み、元のprimary action確認の目的・30秒/10秒を維持する。ルートURL不正/fixture欠落は明示失敗し、本物のブラウザ表示を偽装しない。

N161局所対照：候補b74b9b0の実Swift loopback helperをLinux6.1.2でコンパイルし、実HTTPのGET二回/内容bytes/固定404/POST405/未完了client中のstop/プロセス終了前のlistener回収を1件9.328秒で確認した。実生成Safari factoryのURL検証も元本文を抽出して実行し、正しいloopback、flagなしの元HTTPS維持、元リンクURL不一致・欠落・localhost別名・HTTPS・portなし/0・別path・query/fragment/userinfoの拒否を1件17.536秒で確認。Safariクラスだけは非Apple環境の境界stubで、実ブラウザUI成功ではない。その後errnoと固定response/closeの受動logだけを追加し、同じlocal二件を含む既存manifest/runner等で新sourceを確認する。既存UIケース31件・元の長押し/保存/再起動/primary action/native Closeの全操作と期限は維持する。

N161候補d54b864の局所結果：新旧の実fixture/generatorと元の全条件を含むmanifest30件/失敗0/skip0（46.399秒）、実shell runner14件/失敗0（37.908秒）、Swift構文/Python構文/catalog450/check --base8e01/空白が成功した。新しい二つの局所対照をこの新sourceでも含めて実行し、loopback限定の実HTTP、固定200/404/405、要求上限/2秒期限、停止中client/FD回収、元HTTPSと境界fixtureURLの分離・不正設定拒否を確認した。SFSafariViewController.init(url:)がHTTP/HTTPSを受け取ることもApple公式宣言で確認した（https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/init(url:)-5kpkn）。実Safari/AXの改善はまだ未検証なので、次は元のLinkPreferencesケース一件だけをshippingSDK27.1/Runtime27.0と26.5で比較する。限定成功は正式全15/公開に換算せず、後のmainには別の新規reviewで全15を要求する。

並行旧source8e01の単項目27/job122089516946は577.174秒で成功し、N160と同じ保存前Buttonのnative枠(16,697.333,361,100.667)/viewport(0,141,393,699)を記録して一回操作・採用保存・再起動まで通過した。元の失敗OS26の手動訂正はB27失敗により未実行なので解消の確認とは扱わない。通常27 Aも18件/失敗0（1795.822秒）、Home境界17.807秒・行除外410.210秒で成功。明示選択27も961.723秒で成功。旧26 Aは継続中で取消ししない。

N161候補の静的補正：最初のserverはSO_RCVTIMEOを各recvへ適用したため、少量を続けるclientには要求全体の2秒上限にならない点を主担当が確認した。実行失敗ではなく検査範囲の不足で、単なるidleでの回収成功を低速送信全般へ一般化しない。nonblocking socketと同じmonotonic deadlineをread/writeのpollに適用し、cancelも毎回観測する。新しい部分header連続送信の実対照を既存server caseへ追加し、停止がprocess終了に依存しない元の対照も維持する。修正/記録を非起動refへ先にpushしてから再検査する。

N161 global deadline補正後のmanifest全30件は41.318秒/失敗0/skip0で成功。部分headerを継続送信するclientも要求全体の2秒で打ち切り、TCPの正常EOF/ConnectionResetの双方を期限内閉鎖として観測した。timeout/未閉鎖は拒否したまま。送信完了後の固定status/bytesとlistener閉鎖だけを記録し、要求本文は出さない。既存runner14件（37.908秒）のスクリプト/生成起動APIには追加差分がなく、現sourceのSwift/Python構文/catalog450/checkを再確認する。次は一回専用の新規review後に、元LinkPreferences一件を両RuntimeのshippingSDK27.1で実行する。

N161限定26の実結果：source9745d33ba3867f0d308c000c61c11d2a2cbdcdd3/run40482955626/attempt1/job122117587842、SDK27.1/Runtime26.5は10:00:44Zにsuccess終端。元LinkPreferences一件159.203秒/失敗0。お気に入り解除/同じ保存状態の一回再起動/実追加/primary tapに続き、実SFSafariでHTTP200/205bytesの入力ページ表示、native Closeの実一回操作、ページ消失/一覧復帰を通過し、listener-closedも記録された。27側は継続中で両OS成功/正式全15へは換算しない。

同じ候補のローカルPython全290件は139.791秒/失敗0/予定skip22で成功した。新二件を含む全検査の結果であり、元288件の結果と合算しない。旧main8e01/run40474382684の26 Aは10:07時点で継続中、取り消さない。元のN160失敗OS26の手動訂正は未実行のため未確認のまま保持する。

## N162 loopback browser限定iOS27がcancelled終端（2026-10-27）

10:21 UTCのjob予算後の予定確認で、source9745d33ba3867f0d308c000c61c11d2a2cbdcdd3/run40482955626/attempt1/job122117587388は09:43:34Z開始・10:18:35Zにcancelled終端（35分01秒）と観測した。主担当から取消API/gh cancel等の操作は行っていない。workflow予算は30分。元SDK27.1/Runtime27.0の準備とexact source確認はsuccess、Exercise stepがin_progress表示のままで、完了ログ未読のためcase到達・停止段階・具体終了理由は未確定。26側の実ケース159.203秒のsuccessを27へ代用しない。対処決定前に事実を記録し、ログと過去のtimeout/cleanup/AX記録・当時/current本文を照合する。

N162の追加事実：check annotationは「The job has exceeded the maximum execution time of 30m0s」。job集約log取得は404/BlobNotFoundで、run log archiveもExerciseの27実行本文を回収できなかった。archive抽出時にOS名でなく名前内の27を選んだため26側の既取得checkout断片を再読した選択ミスも記録する。これは27の証拠ではなく、case到達/停止箇所は依然不明。artifact0、限定runは26 success/27 cancelledで終端。旧main8e01/run40474382684の26 Aは10:10:53Zにsuccess終端し18件2064.261秒・通知123.455秒・Home境界20.884秒・行除外195.529秒、全15表示は成功8/失敗1/skip6・artifact0・全9実jobのlog一度取得済み。終端runの反復取得はしない。

N162照合：timeout/cancel/cleanup/test-app-ui/timed_commandを検索し、N27/N07/N153詳細と20a1c0fの実runner、現9745d33のrunner/timed_command/manual_ui_diagnosticsを読んだ。N27は追加操作を終えきれず45分で中断し今回は一件の30分超過だが操作段階を示すlogが無い。N07はsimctl一覧とshutdownの停止を個別に観測していたが今回はそこまで断定できない。現timed_commandは計測とsignal時の所有group回収だけで、時間上限はなく、runnerのsimctl create/終了等には段階出力もない。実fixtureのserverは既にglobal2秒deadlineなので、そこや元AX30秒/Close10秒/SDK/実操作を推測変更しない。

次の限定27一回ではQA実行の外側だけを24分で失敗124にする有限監視を追加し、最大120秒の所有group終了と残4分のjob猶予でlog回収を試みる。runnerにはsimctl一覧/create/boot/frontend/終了の前後固定stageを受動出力する。元30分job予算を延ばさず、UI成功/期限切れの救済や再試行を加えない。正常終了値/出力/取消時の回収を既存wrapper検査で保持し、実processの時間切れ・子の終了を追加検証する。製品/browser fixture/元caseと全15gateは変更せず、候補/根拠を非起動refへpush後に検査、新規code-only review後に27だけを診断する。26成功の再実行はしない。

N162候補2b5e5c9の局所結果：Python wrapper5件/失敗0（7.029秒）、実shell runner14件/失敗0（41.905秒）、Bash構文/catalog450/check --base9745d33が成功。新しい実process対照は2秒deadlineで124を返し、TERMを無視する所有childを回収し、別groupへ影響しないことを確認した。既存の二重signal/終了済みleaderの子回収、正常出力/終了値も維持した。旧N07の782ad0dはrun.shからcompare.pyへ委譲する構成であり、今回をsimctl停止の再現と扱わない。Swift fixture/product/元case/期限は追加変更していない。

N162の新しい限定実行：新規GPT-6.1 Sol/High ios_n162_focused_pre_actions_reviewは実行対象code-only614行/31683bytes、SHA256 ec95c8222ad389d7c42595b483cf480e7b1e8203bd27316e69b9d7cb1422cbc4に具体的指摘なし。主担当がhash/未送信全commit空白と局所結果を確認し、一回だけrun40489089458/attempt1/sourcea07fee1838c51831c1b7c42fd659f7544ff73460をdispatchした。job122138198912は10:31:09Z開始、27だけの元LinkPreferences一件/SDK27.1/Runtime27.0。26の成功済み診断は再実行していない。このreviewは消費済みでmainや次の開始には転用しない。

同sourceのLinux Python全291件は148.983秒/失敗0/予定skip22で完了。追加deadline対照を含む一回の全体結果で、旧290件と合算しない。製品/Vendor/Package/projectの追加diff0を照合した。API/iOS IssueとPR記録も、mergedと未公開・限定成功と正式全15未成立を区別して更新した。元main作業領域の未commit16/85行も保持を再確認した。

N162新診断の終端：sourcea07fee1/run40489089458/attempt1/job122138198912は10:43:50Zにsuccess。実SDK27.1/Runtime27.0、元LinkPreferences一件123.707秒/失敗0。実HTTP200/205bytesのページ表示、元native Closeの操作/消失/一覧復帰を通過し、listener-closedと所有simulator shutdown/delete、cleanup-completeまで記録された。外側730.7秒で終了し24分deadlineは発火していない。build81.4秒、bootstatus248.5秒を区別した。artifact0・完了log一度取得済みで、この終端run/log/artifactは再照会しない。旧27の欠落logから停止箇所や恒常的解消は推定せず、N162のcancelledを成功へ書き換えない。26のsource9745d33/159.203秒と今回27の成功は限定比較であり、同一source/run/attemptの全15とは扱わない。

次のmain/正式全15一回には別の新規GPT-6.1 Sol/High ios_browser_main_final_pre_actions_reviewが同じcode-only614行/31683bytes/SHA256 ec95c8222ad389d7c42595b483cf480e7b1e8203bd27316e69b9d7cb1422cbc4を確認し具体的指摘なし。主担当が未変更hash・全未統合commit空白・元31 UIケースと全15gate・局所291件を照合してから通常fast-forward pushする。このreviewはmain開始一回だけに消費し、将来の別Actions開始には転用しない。限定成功では未実行の元N160/手動訂正26も含め、同じmain source/run/attemptで全条件を確認する。

## N163 loopback入力取込み後の正式iOS27 Aがfailure終端（2026-10-27）

12:00 UTCの過去実測/予算に基づく予定確認で、source7d4eca01e4bae3941ccad85f363190149a9becae/run40491344629/attempt1、通常27 A/job122146853367は11:06:41Z開始・11:54:46Zにfailure終端と観測した。指定SDK27.1/Runtime27.0、実Runtime/失敗case/具体stage/下位原因は完了log未読で未確定。Distribution291/Native691/訂正27全四件/通常27 Bは同sourceで成功したが、A失敗を救済せず正式全15未成立。通常26 A/訂正26は依存skip、通常26 B/job122163057616は11:29:00Zから継続中で取消ししない。対処案選択前に事実を記録し、新しい完了logと過去の該当詳細・当時/current本文を照合してから根拠を決める。追加の同条件再実行は開始しない。

N163実log：指定SDK27.1/Runtime27.0、build81.8秒/boot78.8秒は成功。基本18件中17成功、testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepairだけ151.951秒で失敗（基本全2380.611秒）。Events.swift:71の初回年度field tap後、元10秒のnative Keyboard存在待機が不成立。設定→学校行事への移動、空欄fieldのexists/hittable/上端確認と一回native field.tapまでは通過したが、最初の2032入力/修復/再取得/保存には未到達。事後AXはfield(32,220.3,329,22)が存在しplaceholderのまま、keyboardなし。入力配送/取消し/focusの下位原因は未採取で断定しない。Home境界は24.523秒、元行除外196.500秒で成功し、新しいブラウザcaseとは別ファイル/操作段階。通知の後続phaseは未実行。新logを一度保存した。

N163照合：EventCacheCorruption/Events.swift:71/keyboard/年度/focusを検索し、U56/U05/U04詳細、当時bd5ddb7/b9289aeの実Events caseと現7d4eca0のcase/SchoolEventsView/Navigation/FixtureInputDeliveryを読んだ。U56は実Keyboard成立後の4桁一致失敗、今回は初回Keyboard成立前であり、その後に追加した入力値診断には未到達。field探索/一回tap/Keyboard10秒はbd5ddb7以来同じ本文で、製品SchoolEventsViewのnumberPad/AppStorage/通常Listも今回のQA diff対象ではない。入力点や0.1秒へ推測変更せず、下位配送を観測する。

次の限定27診断は、元の直前EventAvailabilityと元CacheCorruptionの二caseを同順に選び、後者だけ既存のread-only touch配送traceと新しいUITextField編集開始/終了/変更・公開keyboard通知の固定stageを有効にする。UITextField/keyboard通知には値や文字列を出さず、Observerは読むだけでfocus/通知/結果を注入しない。hostのConnectHardwareKeyboard設定も二domainの読み取り値0/1/不明だけ観測し、設定を書き換えない。元一回field.tap/Keyboard10秒/4桁入力10秒/実修復・別年度保持・再取得・保存/再起動、31 UI caseと正式全15gateは変更しない。診断の外側24分失敗124/元30分jobも維持する。今回未観測のfocus/soft keyboard/入力取消しを区別する新しい観測条件で、恒常解消や製品原因は未確定。候補と根拠を非起動refへpushしてからlocal manifest/runner/構文/catalogを確認し、新規専用code-only review後に一回だけ開始する。

N163観測候補4556a8aの局所検査：manifest全30件/失敗0（46.969秒）、実shell runner全15件/失敗0（47.208秒）、Swift fixture構文/Bash構文/catalog450/check --base7d4eca0が成功した。新しいrunner対照は元二caseを一回ずつ同じ順/同じdeviceに選び、どちらが失敗しても成功へ救済しないこと、host keyboard設定はread二回だけでwriteを行わないことを確認した。collectorは新しい固定8stageだけを追加許可し、任意本文・symlink・上限超過拒否を維持した。実UIKit通知/Keyboard状態はまだ未確認で、次のshipping SDK診断で確認する。

次の27限定一回専用の新規GPT-6.1 Sol/High ios_year_input_focus_pre_actions_reviewはcode-only194行/12868bytes/SHA256 a652626caceae1fafbc63c2413ec5c23ac1fad2184892266828b054a6b151761を読み具体的指摘なし。主担当が現codeの同じhash/未統合全commit空白と局所結果を照合してから一回のdispatchだけに消費する。mainや将来の開始へ転用しない。過去完了logの保存分では元二caseは旧main22で136.756/110.912秒、8e01で125.000/109.192秒だった。新N163の直前case440.559秒という変動も保持し、24分を延ばさずに元の二caseを観測する。

N163の旧正式実行終端：source7d4eca0/run40491344629は全15表示job終端、8success/27 Aのfailure1/依存・構成skip6、artifact0。全9実jobの完了logは各一度取得済みで、この旧run/jobs/log/artifactを再照会しない。最後の通常26 Bは12:05:25Zにsuccess。元LinkPreferences90.330秒で実HTTP200/205bytes/native Close/一覧復帰/stopを通過し、通知228.916秒、OS文字サイズ3段階、B内15 XCTest完了（元VoiceOver予定skip1）も確認した。N163年度入力の失敗とはcase/shardが異なり、26 A/手動26未実行を成功へ数えず、新しい公開は行わない。

N163の限定観測source d4c1bce25a7b7efdf103152d1395e1f07400e815/run40501639254/attempt1/job122180519690は12:10:09Z開始。元直前caseとCacheCorruptionの二caseだけをshippingSDK27.1/Runtime27.0へ通す。専用reviewはこのdispatch一回へ消費済みで、結果はまだ未確認。

以下は独立したcodex/diagnose-native-adoption26-20261027/source1ac3a26cc8f1e50971457e0ff8b1db97dc96a20dの記録を保持する。診断workflowの選択追加はこの独立branchだけで、年度入力候補へコードを混在させていない。

N160の失敗OS確認を独立して進める根拠（2026-10-27）：元失敗22cb3f8/SDK27.1/Runtime26.5のnative Button二段階hit照会と、現main7d4eca0の一意nativeへbind後に全guardを保って一回観測する実diffを再度読んだ。N160の単項目27は既に577.174秒/今回696.403秒で元保存・再起動まで成功したが、26は後続通常27失敗の依存で二度未実行。旧probeは26だけ旧SDK26.5固定で、この失敗と同じSDK27.1では確認できない。

隔離診断branchだけで既存manual probeへOS選択と26のSDK選択を追加し、既定の両OS/旧26.6 toolchainは維持する。今回一回は26のみ/配布SDK27.1/元Runtime26.5/元単項目だけを選び、exact sourceと両SDK/Runtimeを事前確認する。UI/helper/全assert/35分と一回接触/保存/再起動・正式全15gateは変更しない。新しいhelperを元失敗OS/SDKで初めて検証するためで、旧失敗条件の同一source再試行や27成功の重複ではない。候補/根拠を非起動refへpush後、既存manifest/manual runnerとSDK選択の拒否対照を確認し、新規専用code-only review後に開始する。年度入力診断とは別sourceで、成功しても正式全15へ合算しない。

## N164 単項目26のSDK選択追加時にローカルmanifest契約検査が失敗（2026-10-27）

source74571d8d599788f484d41571a774502318e30f32、Linux/Python3、12:15 UTC確認。manual runner6件は4.835秒/失敗0。その後manifest全30件は12.985秒/失敗1/Swift未選択のskip3で終了1、後続catalog checkは未実行。UI/SDK実行やSwift失敗ではない。今回Swift本文は変更していないが設置済みSwiftをPATHへ選ばずmanifestを起動した事実も保持し、skip3を成功へ数えない。対処案選択前の観測として記録し、具体assertと従来契約/変更前後workflowを照合する。まだこの候補のActionsは開始していない。

N164照合：失敗assertはtest_manual_matrix_requires_every_unchanged_case_on_both_os_separatelyの旧probe文字列ios:[26,27]固定（792行）。N30/N29の登録/契約差分記録と7d4eca0の旧workflow・同test本文、74571d8の新workflowを比較した。正式全15の両OS固定は変更せず、任意probeの既定bothだけを維持して単OS選択を許す新仕様なので、probe側は既定bothと選択配列を検査する必要がある。さらに主担当の静的確認で、元のmatrix.includeを残すと非選択OSのincludeが独立行を追加し得る不足を見つけた。期待文字列だけを変えず、includeを除きrunner/developerをOS/SDK式へ移し、単OS指定が余分なOS行を生成しないことも要求する。

SDK拒否対照に加え、実workflowのruntime確認Python本文を実行して26.5のみを受理し、欠落/利用不可/26.6併存を拒否する対照も追加する。過去の35/45分・全case/正式gateを保持し、次は設置済みSwift6.1.2を明示して新規/元の関連検査を逐次実行する。失敗・初回skip3を消さず、修正/比較を先にpushしてから再検査する。

N164修正後：source28b71f4で設置Swift6.1.2を明示し、manual runner全7件/失敗0（4.715秒）とmanifest全30件/失敗0/skip0（47.550秒）、catalog450/checkが成功した。SDK二種の不一致拒否、選択Runtime26.5のみの受理と欠落/利用不可/26.6併存拒否を実workflow本文で確認し、任意probeの単OS配列にinclude行が混入しないことを要求した。初回manifest失敗1/skip3は保持する。製品/Swift UI case/期限/正式両OS全15は変更していない。

単項目26限定一回専用に新規GPT-6.1 Sol/High ios_manual26_focus_pre_actions_reviewが、元失敗22cb3f8以降の実行対象helper/共有generator/timed wrapperと新SDK選択/検査のcode-only266行/15257bytes/SHA256 1224dacb860e36777b39ee5d2714e6183c2246f9cbbd69cd2b0492f05f19bc1dを確認し具体的指摘なし。主担当が同じhash/全commit空白/元guardと局所結果を確認してから一回だけdispatchへ消費し、main/次回へ転用しない。選択はtestOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground、ios26、sdk26=27.1。正式公開の検証とは別記録にする。

単項目26の独立dispatchはrun40502795972/attempt1、source1ac3a26cc8f1e50971457e0ff8b1db97dc96a20d、12:19:01Z作成。専用reviewはこの一回に消費済み。元35分/一回操作/保存再起動と全15 gateは不変で、結果は未確認。

N163限定観測の終端：sourced4c1bce/run40501639254/attempt1/job122180519690は12:25:51Zにsuccess。shippingSDK27.1/Runtime27.0、元直前EventAvailability197.511秒/CacheCorruption160.451秒、二件とも失敗0で完了照合した。後者は実編集開始→公開Keyboard will/did show→実文字変更の順を記録し、同年度の再取得修復/他年度の正常結果と警告の保持/保存後の一回再起動まで通過した。host二domainのConnectHardwareKeyboardは双方unavailableであり、0/1や接続無しとは推定しない。build73.5秒/boot194.6秒/外側917.6秒、期限発火なし、artifact0、完了logは一度取得済み。この終端run/log/artifactは再照会しない。

N163の旧失敗時の編集/Keyboard通知は未採取のままで、今回非再発から原因や恒常解消を断定しない。元field.tap/Keyboard10秒/4桁10秒/全修復assertは同一で、入力方法/SDK/期限を往復しない。今回の固定通知/既存touch観測は31caseを含む通常Aでも該当caseだけ有効なので、単項目26の別比較の結果を確認してから、新規main専用reviewの後に同じ全15 gateの実行内で旧停止を観測可能にする。限定成功を正式全体へ合算せず、失敗なら新しい段階証拠で調査し、同条件を無根拠に再実行しない。

N160の元失敗OS/配布SDKの確認：source1ac3a26cc8f1e50971457e0ff8b1db97dc96a20d/run40502795972/attempt1/job122184437353は12:19:05Z開始・12:41:38Zにsuccess。実SDK27.1/Runtime26.5の事前guardが成功、元単項目一件645.014秒/失敗0。旧N160と同じ採用前Buttonのnative枠(16,697.333,361,100.667)/viewport(0,141,393,699)、最後のattempt7も確認し、元の一意/有限枠/完全包含/enabled/hittableと一回接触を通過、実採用・保存・一回再起動の保持まで完了した。build108.3秒/boot45.6秒、artifact0、完了log一度取得済みでこの終端run/log/artifactは再照会しない。新SDKで別Runtimeへ逃げず元26.5を選択し、未検証だった26を27成功で代用していない。下位OS一般の恒常解消は未証明。独立診断のSDK選択workflow変更はmain候補へ混在させず、結果も正式全15へ合算しない。

次の正式実行はN163の元年度入力/Keyboard10秒/全31caseを保ち、通常Aの該当caseにも固定編集/Keyboard通知と既存touch traceを残す。限定では未再現だった旧停止を、同じsource/run/attemptの通常全15検証内で観測できる新条件として確認する。入力方法/期限/期待/製品を推測変更したり成功を注入したりせず、失敗なら新証拠を先に記録して調査する。新規main一回専用のcode-only reviewと全commit/hash/局所結果照合後に通常fast-forwardし、元の必須集合が全部成功した場合だけ既存経路で公開する。

次のmain通常fast-forward一回専用の新規GPT-6.1 Sol/High ios_year_observation_main_pre_actions_reviewはcode-only194行/12868bytes/SHA256 a652626caceae1fafbc63c2413ec5c23ac1fad2184892266828b054a6b151761を確認し具体的指摘なし。主担当が元31case/全15gateと現codehash、局所検査と実shipping SDKの限定結果、全未統合commitの空白を照合して一回だけ使用する。限定用/過去レビューは使い回さず、このレビューも次回へ転用しない。N163の根本原因は未確定のまま、入力方法/待機期限/期待を保ち通常検証の該当caseへ同じ固定観測を残す。


### N165 完了ログの具体的観測

基本6件中5成功・testHomeTimetableAndWeekCalendarだけ50.124秒で失敗、全914.818秒。
ApplicationChecks+Timetable.swift:197の詳細閉鎖後calendar準備5秒。t40.21詳細bar消失、
t41.04 app/frame、t41.17 bar/frame、t41.61/41.90 tab存在/frame、t42.09 keyboard、
t42.73 footer配列、t43.05 calendar配列一件、t43.28 exists、t43.61 enabled、t43.92 hittable、
t44.18 contained内部の二度目exists、t44.40 frame再解決で内部retry1/2へ進み、期限内成立を得なかった。
操作は未実行。UI判定は今回の機能差分に含まれない。事後AXは時間割bar/週Buttonを示すが期限内
成立の証明にはしない。画像は281653bytes/SHA256
892ae41ca075a382a64a8c22036f7b91aeac437edb3c7588d5b3a5704bfe3ddd/63片。
N151のquery.count停止と異なり、実一件配列からenabled/hittableまで到達後、重複exists/frame照会で
停止した。これから旧source3398f52/6918212とcurrentの実helperを照合する。下位のAX停止原因は未確定。

### N166 完了ログの具体的観測

Runtime26.5の事前検査とbuild成功、01:06:52 boot開始・01:08:51 bootstatus成功、
01:09:48実操作phase開始。AuxiliaryReadFailuresは98.171秒で成功し、次の行除外caseは
内容確認/次へ/row3 Switch存在待機まで進んだ。01:15:31 xcodebuildは所有iPhone16がShutdown、
Runtime iOS26.5のbundleがnull、supportedArches空として、Installing built productsの
Unable to boot device because we cannot determine the runtime bundle/NSPOSIX2で停止した。
起動前のRuntime欠損ではなく実操作中の利用不能化である。cleanupのspawnもdevice未起動。
このlogだけでアプリの入力失敗・crash・SDK27.1の原因とは断定しない。U60/U61/N76の詳細と
当時/currentの準備・runnerを比較してから次の観測を選ぶ。正式runは全15表示job終端、実行9件の
ログを各一度取得、artifact0を一度確認した。依存skip6を成功へ数えず、このrun/logを再照会しない。

N165比較/候補：N151/U73/N94/N97/N140詳細と3398f52/6918212のcalendar、当時/現行Navigation・Recoveryを読んだ。
N151の配列取得後に行う別viewport照会は既に解消済みだが、今回はその後の同一Buttonのexistsを
contained内で重ね、最後にframeを再解決していた。候補は配列一意性→exists→一回frame→元のfinite/
viewport完全包含→enabled/hittableの順で同じ観測を各一回行う。元bodyViewport（bar/tab/keyboard/footer）
も5秒も変えない。一意性違反・不可視・無効・期限切れを全て失敗のまま保ち、同じnative中心へ一回だけ
実tapし元picker/取消/前後週を確認する。製品のアニメーションや週移動を変更せず、AX停止下位原因の
解消とは断定しない。元case/既存ObservedScreenGeometryTestsで条件の拒否と実操作を確認し模倣caseは足さない。

N166比較/次の観測：U60は事前欠損、U61はexport形式、N76は別minorのcreate拒否で、今回はbootと一件実操作
成功後のRuntime利用不能である。3054127の26準備と現行の差はSDK明示化だけで、26.5の取得・登録済み
unavailable拒否・所有領域回収後再確認は同じ。SDK/OS/device/boot順序を推測変更しない。新しい比較根拠として
boot完了時と失敗cleanup前のsimctl list -jを各一回/10秒/2MiBで読み、所有UUID/指定Runtimeの状態だけを
固定語でconsoleへ出す。パス/他device/任意エラー文は出さず、一時出力を回収する。再起動/再install/自動retryは
加えず、観測失敗をUI成功に変えない。サイズ超過/非zero/不正JSON/別device拒否の検査を追加する。
N165の候補を含む新sourceの正式全15をこの追加観測付きで確認する。今回の原因・恒常解消は未確認。
候補と本記録は局所再試行より先に隔離refへpushし、新規code-only review後のみ次のActionsを開始する。


## N167 次の正式CIの三項目補正iOS27が失敗終端（2026-11-06）

予定01:50 UTCの一括照会、source8cdf0663d192a566cada2288812358f5954bac58/run42144767317/attempt1、
job127654140894は01:36:41Z開始・01:47:10Z failure終端。SDK27.1/Runtime27.0を要求する
元testThreeFieldsRequireEachAcknowledgementAndFourRefusesで、具体操作/失敗stage/原因はlog未読で未確定。
対処案を決める前の観測として残す。Distribution/Native/原本変更は成功、他の通常UI/訂正は継続中。
公開条件は未成立。残りを取消さず、新しい完了4logだけ一度取得して旧詳細/旧現コードと照合する。

N167完了log：元三項目case303.722秒、Input.swift:56のteacher確認Switch native value1の45秒待機timeout。
room/subjectの全文置換・native ACK/Bindingは成功。teacherも全文一致・keyboard消失・一意な内側実Switchの
finite/外側とviewport完全包含/enabled/hittable/0を確認した。外側(16,646.33,361,52.33)、
内側(300,658.67,63,28)、viewport(0,141,393,699)、元の中心(331.67,672.67)で一回0.1秒接触。
入力traceはbegan→ended（約0.114秒）、UISwitchへの到達を示すが、45秒内valueは0、診断teacher ack=false、
teacherのack Bindingなし。N93と異なりcancelledではない。UIKit UISwitch自体のon/追跡/insideは旧観測にない。
検索語Input.swift:56/acknowledge/ended/cancelledでU19/U64/U71/N66/N87/N88/N93/N94/N97を詳細まで読み、
f6e13a6/1b368f5/9cd340e/現Input・現PDFRecoveryView Bindingを比較した。N66と同じ近傍枠だが、
位置・接触方式・Bindingを原因と断定せず、待機/点/時間を往復させない。8cdfと公開f709の元helper/製品Toggleは
同一bytes。既存traceは全gestureクラス名のsuffix16を採るため多くがestureRecognizerとなり区別できない。

次は製品/元case/45秒/一回接触を維持し、同じ三項目を両OSの既存focused workflowで実行して追加観測する。
fixtureのUIWindow observerは元sendEventを一回だけ呼び、元のbefore入力情報を保持したまま、実UISwitchの
isOn/isTracking/isTouchInsideを呼出前後に読み、任意本文を含まない6個Boolだけ同じbounded行へ加える。
gesture名は末尾の共通GestureRecognizerとmoduleを除いた先頭16文字で、同じクラス名文字種/6個上限を維持する。
元の128入力/64KiB/file所有/本文拒否とcleanupを保持し、新形式と範囲外/任意本文の負対照を加える。
観測は操作/gesture/Bindingを変更せず、確認ONを注入しない。候補と本比較を先に隔離refへpushし局所確認後、
この診断一回専用の新規code-only review後だけdispatchする。正式8cdfの残りは取消さず終端を確認する。

N167限定結果：sourceed76a288253a43a0179439d84b934bdecc66808e/run42147251375/attempt1は両job成功終端、
元の三項目caseはSDK27.1/Runtime27.0で386.450秒、SDK26.6/Runtime26.5で554.245秒・失敗0。
元の3入力/各native ACK/4項目拒否/採用・再起動保持まで通過し、UIKitコンパイルも成功した。
各log一度・artifact0一度を確認し、終端run/log/artifactを再照会しない。両OSの実Switch native traceは各6行、
began/endedと区別可能なUILongPress/UIPan/UIScrollView系を取得した。即時のsendEvent前後6Boolは成功時にも
全0で、後続のBinding/value1とは時点が異なる。この即時値を成功/失敗の判定に使わず、N167の根本原因や
恒常解消が判明したとは扱わない。製品・接触・元45秒/期待を推測変更しない。
次は同じread-only診断を正式にも保持し、失敗時に旧不十分なクラス情報との比較を可能にする。限定の2成功を
正式の代用にせず、新source/run/attemptで既存全15を要求する。旧8cdfの通常27 B/単項目/明示選択も成功し、
新3完了logを一度取得済み。通常27 A/26 Bと後続26 Aは取消さず終端を確認する。


## N168 新正式CIの単項目補正iOS27が失敗終端（2026-11-06）

予定03:15 UTCの一括照会、source01fe8af2f3deacf760b8187469958a2661388f6a/run42149866023/attempt1、
job127671002396は02:24:25Z開始・02:40:21Z failure。要求SDK27.1/Runtime27.0、元単項目case
の具体stage/操作/原因は未読で未確定として対処案選択前に記録する。他27 B/三項目/原本変更/
明示選択/Native/Distributionは成功。27 A/26 Bは継続中で、取消さず終端まで確認する。
公開条件は未成立、新5完了logだけ一度取得し、旧詳細/旧現コードを照合する。

## N169 旧正式8cdfの通常iOS26 Aも失敗終端（2026-11-06）

同じ予定照会、source8cdf0663d192a566cada2288812358f5954bac58/run42144767317/attempt1、
job127670454100は02:22:54Z開始・02:35:07Z failure。要求SDK27.1/Runtime26.5、具体case/stage/
原因はlog未読で未確定。既知N167の3項目27失敗とは区別して対処前に記録する。残通常27 A/26 Bは
成功となり、全15表示jobは終端（実10件）。依存skipは成功に数えず公開なし。新3logのみ一度取得し、
artifactを一度確認、旧取得7log/限定2log/旧runは再取得しない。元N166のRuntime消失と同原因とはまだ扱わない。

N168完了logの事実：case477.609秒、Review.swift:16の最初のrequireReviewの20秒がtimeout。
最初の入力/ACK・実背景/復帰・入力再変更後のACK=trueは成立。manual-submit実Buttonを一回tapし、
t290.86でcoordinatorのlabelをNSPredicate形式の二つのCONTAINSで照会、Find後はt310.29まで返却がない。
t312.02/t344.88にsnapshotを要求、期限後AXはpreview=false;review=true;running=false;failure=noneを示した。
実touchは(175.67,747.67)でbegan/endedとUIKitResponder認識があり、ACK失敗ではない。
期限内のreview成立時刻はこの事後AXだけでは未確定。製品のreview生成失敗や20秒不足と断定しない。
旧8cdfの同単項目は589.224秒で成功、今回同sourceの三項目/原本変更/明示選択も成功した。
旧current helperは同じfirstMatch stateへ、format predicate内でlabelを二重参照し、判定後のlogでも再照会する。

N169完了logの事実：UI XCTest開始前のxcodebuild/test-without-buildingが17.1秒でINTERNAL ERROR。
Uncaught Exception Invalid parameter not satisfying: devicePair、CoreSimulatorのSimDeviceSet
addDevicePairAsync/handleXPCNotificationDevicePairAdded/subscribeToNotificationsWithError、
Foundation NSMutableDictionary initWithContentsOfFileがstackにある。製品caseは未実行。
bootstatusは91.2秒で成功、boot後のreadonlyhealthは10秒期限でunknown、失敗cleanup前はRuntime available/
owneddevice Booted。元N166のruntime bundle nullとは異なり、今回はRuntimeの不在を示さない。
旧8cdfは通常27 A/26 Bが元ケースと全追加phaseまで成功し、全15表示job終端・実10件のlog各一度/
artifact0一度確認済み。旧run/log/artifactを再照会しない。現在01feの通常27 A/26 Bは継続中、取消しなし。

N168照合/候補：Review.swift/requireReview/coordinator-state/二重labelでcatalog/索引を検索し、U67の
preview成立後の診断query停止、N94/N97/N140/N151/N165のidentity・重複照会の詳細と、1b368f5/
f709367/現Review・OneCorrection・生成fixtureを読んだ。U67はpredicate後の追加照会で、今回はpredicate内の
label取得自体から応答が止まった。旧/現requireReviewは同じfirstMatchと二重CONTAINSを持つ。
候補は元20秒内のblock predicateで同じIDの実StaticText配列を一度取得し、一意な一個のlabelを一回だけ読む。
同じ一文字列からreview=true AND preview=falseの両方を要求し、複数はsticky曖昧flagで失敗する。
待機後のlogは取得済み文字列を使い、新たなAX queryを加えない。元の20秒/completed/旧正常結果保持/
全review本文と比較/背景・復帰/再起動・正式採用/両OS/全15gateを維持する。製品やtap/待機を変更しない。
実predicateをSwiftで実行する局所対照（一意/不在/曖昧/未review/preview同時true/時点の異なる二つのlabel）を
追加し、二つの時点の値を混ぜて合格させないことを確認する。旧停止の下位原因・恒常解消は未確定。
根拠と候補を隔離refへpush後に局所検査し、既存単項目を含む新source全15を新規review後だけ開始する。

N169照合/扱い：devicePair/subscribeToNotifications/INTERNAL ERROR/bootstatusで索引を検索し、
N07/N73/N127と当時/現runnerを読んだ。同じdevicePair例外は既往記録なし。N73のhost通信断、N127のdestination
不在、N166のruntime bundle不在とは区別する。今回はCoreSimulatorが起動済みRuntime/deviceを報告したまま
xcodebuild内部でpair通知処理の例外を投げており、製品caseに未到達。26.5/SDK/device/boot順序を推測変更せず、
既に開始済み01feの新host・元通常26 A/Bの結果を確認する。同job内の再起動・再install・retryは加えない。
今回のN168候補の次の正式でも元26.5と全15をそのまま必須にし、このhost例外を成功扱いしない。


## N170 旧正式01feの通常iOS26 Bが失敗終端（2026-11-06）

予定04:05 UTC照会、source01fe8af2f3deacf760b8187469958a2661388f6a/run42149866023/attempt1、
job127685011044は03:05:53Z開始・03:49:45Z failure終端。要求SDK27.1/Runtime26.5、具体case/stage/
原因はlog未読で未確定として対処選択前に記録する。通常27 Aは成功、通常26 Aは03:48:51Zから継続中で
取消さず確認する。新しい旧正式2logと、新主実行957/run42156001519の成功6logだけ一度取得する。
主実行の訂正27元四件/Native/Distributionは成功、通常27 A/Bは継続中。全15/公開はまだ未成立。

N170完了logの具体的事実：基本6件/設定/文字サイズ/VoiceOver区間は全て元の完了照合を成功した。
26のVoiceOver一件は既定のOS条件で予定skip、実成功へ数えない。最後のphase前のcleanup（元の26通知区間で
freshdeviceへ切り替える処理）のstrict simctl shutdownがSimError405/current state Shutdown/exit149で停止した。
そのため残る通知phase/追加OS設定変更の全完了とは扱わない。直前check_uiはexit0/TEST EXECUTE SUCCEEDED、
失敗後healthは指定Runtime available/所有device Shutdown。XCTest assertionの失敗やN166のruntime bundle欠損、
N169のxcodebuild devicePair内部例外とは異なる。状態が既にShutdownになるまでのOS側原因は未確定。

N170照合：shutdown/current state/exit149/content_size/notification phaseを索引とcatalogで検索し、
U40/N07/N162の詳細、20a1c0f/9745d33/現test-app-ui.shを読んだ。元の26通知切替と最終正常終了は
strict shutdown→delete→必要時create/bootで、EXIT trapだけがbest-effortである。今回もUI caseの救済や
待機延長をしない。対処が必要なら、shutdown失敗時に所有UUID/指定Runtimeの一意なdeviceが既にShutdown
と読取確認できる場合だけ終了条件を満たす、idempotent cleanupとする。欠損/不明/Booted/別device/list失敗は
元終了値のfailureを保持し、delete後のfreshdeviceと全通知/OSサイズ検証を必須にする。
ただし今回の失敗を観測する前から主実行957/run42156001519は継続しているため、まずその元全15の結果を確認する。
同じhelperは現主実行にもあるが、旧実行だけから現在の失敗を予告・成功扱いせず、不要な再公開開始は行わない。
必要になった場合だけ事実・候補を先にpushしてから検査・新規reviewを行う。


## N171 主正式957の通常iOS26 Bが失敗終端（2026-11-06）

予定04:55 UTC照会、source9577502eaaf9690cb03d77bd6ecea3ae91d9c4aa/run42156001519/attempt1、
job127706197100は04:10:53Z開始・04:43:51Z failure。要求SDK27.1/Runtime26.5、具体case/stage/
原因はlog未読で未確定として対処選択前に記録する。元27 A/Bと訂正26の単項目/三項目/明示選択も成功。
26 Aと原本変更26は継続中で、取消さず終端を確認する。新6主実行logと旧01feの最後の成功26 Aを各一度取得する。
旧01feは全15表示job終端・実10件、今回最後のlogとartifact0を一度確認後は再照会しない。
N170の既停止cleanupと同一原因とはまだ断定せず、新しいlogを先に読む。

N171完了logの事実：基本6件中5成功、HomeTimetableAndWeekCalendarだけ44.956秒、Timetable.swift:200の
元5秒準備timeout。viewport/配列取得後、t40.02 exists、t40.35 frameを通過し、t40.72 enabledの再解決で
同じnative identityのFind retry1/2→t40.94 snapshotへ進んだ。N165の重複exists/frame停止を避けた現行でも、
次の属性参照まで同一native identityが残ることを保証できなかった。実calendar tap前である。
Runtimeはavailable/BootedでN170の既停止cleanupとは異なる。事後AXだけで期限内enabled成立は証明しない。
今回の製品週移動の不良/5秒不足/OS固有原因とはまだ断定しない。

N171照合/候補：N151/N165/N97/N94/N140の詳細と3398f52/6918212/9cd340e/現Navigation・WeekSection・
Calendar caseを読んだ。N165は重複exists/frameの削減後に両OSで成功したが、今回のnative identityはframe後の
enabled取得時に消えている。全属性の間で一時的なaccessibility実体が同じであるという前提は成り立たなかった。
製品の週Buttonに専用の固定accessibilityIdentifierを付け、同じ月/日からlabel条件も残した一意な短い論理ID
queryで現在のButtonを解決する。配列indexを通じた論理ID参照はN97の外側識別と同じ用途で、N151の
global label query.count→別index再検索やN94のAny祖先の入れ子indexへ戻さない。viewport先行、
一意/exists/一回frame/有限/全包含/enabled/hittable/元5秒/中心へ一回実tap/週picker5秒・取消・前後週は全て維持。
表示/週移動action/アニメーションを変えず、見失ったときは失敗のままにする。元caseと既存29幾何/生成・manifestが
実UI条件と部分表示拒否を検出するため、XCTestの寿命を模倣する新しいテストは作らない。下位原因・恒常解消は未確定。

N170の既知cleanupはこの新sourceに併せて対処する。strict shutdownがexit149のときだけ、追加のread-only
list devices（10秒/1MiB）で所有UUID/指定Runtimeの一意なdeviceがShutdownと確認できた場合に終了条件達成とする。
正常shutdownは元経路、他終了値/Booted/不在/複数/別Runtime/不正JSON/取得失敗・timeoutは元failureを保持する。
テストの再試行・boot救済・不明状態の成功扱いをせず、元のdelete/fresh create/boot/全通知とOS設定変更を維持する。
shellの実関数に対する正常/149確認済/149不明/他終了値の伝播と、実JSON確認の全負対照を追加する。
事実・比較・候補を隔離refへ先にpushしてから局所検査し、新規code-only review後のみ次の正式全15を開始する。
主957の残26 A/原本変更26は取消さず終端を確認し、旧01feは全15表示job終端・実10log各一度/artifact0確認済みで再照会しない。


## N172 旧正式957の最後の通常iOS26 Aが失敗終端（2026-11-06）

予定05:45 UTC照会、source9577502eaaf9690cb03d77bd6ecea3ae91d9c4aa/run42156001519/attempt1、
job127709445839は04:37:00Z開始・05:33:48Z failure。要求SDK27.1/Runtime26.5、具体case/stage/
原因は未読で未確定として対処選択前に記録する。残原本変更26は成功し、全18表示jobは終端。
新しい最後の2logとartifact0を一度確認した後は旧run/log/artifactを再照会しない。
主bb809/run42166029342は通常27 A/B・Native・Distribution・訂正27の三項目/明示選択/原本変更が成功、
単項目27は05:33:50開始で継続、26 A/Bは05:43台から継続中。新7成功logだけ一度取得し、旧残2と照合する。
旧実行の失敗を現在の成功・失敗やN170と同原因へ一般化せず、残りを取消さず確認する。

N172完了logの具体的事実：元通常Aの基本18件は失敗0で完了し、分離した通知case118.052秒だけが失敗。
ApplicationChecks.swift:124はlaunchReadyではなくscreen("通知")のnavigation bar10秒assertである。
設定tab/通知rowの全包含・有効・実label枠を通り、元の一回0.1秒native label接触後も期限内に通知画面へ移行しなかった。
事後AXは設定navigation barとselected設定tab、通知row(16,577.3,361,52.3)/label(32,593.3,32,20.3)を示す。
実Allow/更新後再起動/通知配信の期待には未到達で、通知の配信不良と断定しない。所有deviceはBooted/
Runtime available、service診断はtimeoutで不明。単独のdebugger version警告から原因を選ばない。

照合：case名/screen通知/native-label/10秒でN48/U75の詳細と98838f2/f709367/現Notifications・Navigationを読み、
当該helperは同一bytesと確認した。N48はapp-relative tapからnative-labelのbrief contactへ変更したが、
今回はその後の同じ元0.1秒方式で遷移未成立が再発した。位置/時間/OS/製品NavigationLinkを推測変更せず、
押し直しや許可注入・10秒延長で救済しない。N172観測前から主bb809の同じ元caseは継続しているため、
その26 Aを含む元全15の結果をまず確認する。27 Aの同caseは69.101秒で今回成功したが、26の成功へは流用しない。
旧957は全18表示job終端・実14件（12成功/N171とN172の2失敗）、全14log各一度/artifact0確認済みで再照会しない。


## N173 主正式bb809の単項目補正27が失敗終端（2026-11-06）

予定06:45 UTC照会、sourcebb8091e95fb739cd92b23ffaf58687af91d23d35/run42166029342/attempt1、
job127723415943は05:33:50Z開始・05:49:53Z failure。SDK27.1/Runtime27.0を要求する元単項目case、
具体stage/操作/原因は未読で未確定として対処選択前に記録する。他27全条件は成功した。

## N174 同じ主正式bb809の通常26 Bも失敗終端（2026-11-06）

同じsource/run/attempt、job127735502288は05:43:05Z開始・06:11:25Z failure。
要求SDK27.1/Runtime26.5、具体case/stage/原因はlog未読で未確定として対処選択前に記録する。
最後の26 Aはsuccess終端、全15表示jobが終端（実10件）。新3logとartifact0を各一度だけ確認し、
旧取得7log/終端runは再取得しない。依存skip5を成功へ数えず公開なし。N173/N174の具体logと
過去詳細/旧現sourceを比較してから対処を選び、記録と候補を先にpushしてから次の試行を行う。

N173完了logの事実：単項目case496.546秒、ManualAssistanceChecks+Navigation.swift:58の確認本文frame取得が
UI query timeout。review=trueとheaderの可視化は成功、対象の訂正値StaticTextのexists成立後t296.46の
frameがt327.83/t359.00再試行、t389.02以降のsnapshotも遅延した。ACK/レビュー20秒の失敗ではない。
対象は全appの訂正値label firstMatchで、実生成viewは既にmanual-reviewed-<fieldID>という専用IDを付けている。
crash原因はunassessedで、アプリcrashや確認本文欠落と断定しない。

N174完了logの事実：基本6件中5成功、calendar元5秒だけ69.039秒で失敗。t35.32詳細消失、viewportの
app/nav/tab/keyboard/footer各照会を経てt36.09に配列、t38.38で専用IDButton存在を再照会し、
t39.62/39.63内部retry、後続frame/enabled/hittableには未到達。事後AXには同ID/元labelの週Buttonがある。
専用IDでも一回取得したUI queryを次の属性のため再解決する部分が残っており、存在が期限内に成立した証明はない。
全job終端、実10logを各一度/artifact0一度確認済みで旧bb809を再照会しない。26 Aは今回成功した。

照合/次の候補：N173はN54/N78/N94/N97/N153の詳細と旧c7994b7/e33a3cd/現Navigation・Review・生成器を読む。
N54の全体label探索/再scroll、N78の同じCell反復探索、N153のroot全体停止と異なり、今回の先行review state/
headerは成立し、次の訂正値のglobal firstMatch.frameだけが停止している。元の16探索/受動Cell/包含/hittable/
可視確認後の全文・保存proofを維持し、既存manual-reviewed- ID prefixと元の期待labelの両方を満たす現在の
復旧Listの実要素配列へ対象を限定する。候補のframeはviewport観測後に各一回読み、その同じ値で位置/選択を判定。
代替配列で見つからないときにglobal firstMatch.frameへ戻る重複照会を除き、同じ16探索/受動dragを継続する。
他の既存代替menu候補も同じ一回frame/同じ全包含・hittableを保持する。labelや正常状態を注入しない。

N174はN151/N165/N171の詳細/各当時と現case/bodyViewportを再比較する。属性getterを順番に増減する方式では
一意な現在の表示を一つの時点で観測できない。候補は元5秒predicate内の一回のapp AX snapshotから、詳細bar不在、
app/nav/tab/keyboard/footerと専用ID/月・日からlabelの一意なButtonの存在/finite frame/enabledを同時取得する。
元と同じviewport算出/重複keyboard・footer拒否/完全包含を要求し、現在の同ID controlへのhittableを別に実確認して
同じ中心へ一回だけ接触する。snapshot内の存在と現在hittableが元exists条件を満たし、不明/欠損/複数/disabled/
clip/timeoutは全て失敗。UI treeは4096個を上限にし、超過は不明として合格させない。製品・元5秒・picker5秒/
取消/前後週/全15gateは変えない。新しいviewport projectionは元7幾何と新しい正負のnative対照で確認する。
候補/比較を隔離refへ先にpushした後に局所検査し、新規code-only review後だけ次の全15を開始する。

## N175 主正式031916の通常26 Aが失敗終端（2026-11-06）

予定09:00 UTC照会、source03191600c10a28231f37f55097be134c315d6abe/run42178798904/attempt1、
job127778153052は07:49:59Z開始・08:01:13Z failure。要求SDK27.1/Runtime26.5、具体case/stage/原因は
log未読で未確定として対処案を決める前に記録する。通常27 A/Bと26 Bは成功した。

## N176 同じ主正式031916の単項目復旧26が失敗終端（2026-11-06）

同source/run/attempt、job127778153082は07:49:58Z開始・08:03:17Z failure。
要求SDK27.1/Runtime26.5、具体stage/原因は未読で未確定。訂正27の同caseは成功しているが26へ一般化しない。

## N177 同じ主正式031916の三項目復旧26が失敗終端（2026-11-06）

同source/run/attempt、job127778153240は07:50:00Z開始・08:03:54Z failure。
要求SDK27.1/Runtime26.5、具体stage/原因は未読で未確定。全18表示job終端・実14件、失敗3/成功11、
依存・構成skip4を成功に数えず公開なし。前回取得8logは再取得せず、新6logとartifact一覧を一度確認する。
旧失敗と同原因と断定せず、新logと過去詳細/当時と現在のsourceを比較してから対処を決める。

N175完了logはUI XCTest開始前のtest-without-buildingが20.7秒でrunner channel disconnected。
直前healthはRuntime available/device Booted、直後はavailable/Shutdownだった。実caseは開始していない。
N176/N177は実case開始後にdevice Shutdown/runtime bundle null/supportedArches空となり、
Installing built productsがUnable to boot device because we cannot determine the runtime bundleで停止した。
SDKは三件とも実配布27.1で、訂正の当初記録の26.6はlog確認で訂正した。27の全ケースと26 B・26の
明示選択/原本変更は成功、全14log各一度/artifact0一度確認済み。完了run/log/artifactを再照会しない。

照合：runtime bundle/prepare-ios26/runtime-owned/Channel disconnectedで索引を検索し、U60/U61/N76/
N166/N169の詳細と3054127/現prepare26、現workflow/runnerを読んだ。N175はN169のdevicePair例外とは
別の通信切断であり、N176/N177はN166同様の実起動後のbundle利用不能。U61対処時から取得後の
available照合はあるが、download/export先のTemporaryDirectoryを準備step終了前に削除している。
今回成功/失敗ともexportedBundleを同所有領域へ出しており、登録直後のavailableだけで取得物の
削除後も全実行中のbacking lifetimeを保証できない。削除が今回の直接原因である証明はまだない。

次の候補は正式26と配布SDK26のrelaunch診断で--hold-exportを付け、欠損時に取得した所有exportを
ビルド/boot/実case/所有device回収まで保持する。同じhelperの--cleanup-exportを最後のalways stepで呼び、
固定のRUNNER_TEMP配下・所有marker一致・symlink拒否の場合だけ回収する。未取得時は無操作、
失敗でも回収し、未知領域や登録済Runtimeを削除しない。既存installed/unavailable拒否・正確なSDK27.1/
Runtime26.5・download/import期限と全UI/gateを維持し、retry/再起動/別OSへの逃避は加えない。
実helperをfake Apple CLIで動かしてexportの準備後保持/後片付け/エラー経路/別領域保全を確認し、
既存manifestへ保持→実テスト→always回収の順序を要求する。これはファイル寿命の候補検証で、
CoreSimulatorの恒常的な解消とは断定しない。記録/候補を先に隔離refへpushし、局所検証と新規専用review後に
同じ全15の正式一回を実行する。N175の切断の下位原因も引き続き未確定として扱う。

## N178 runtime寿命候補のローカルrunner検査が失敗表示（2026-11-06）

Debian/Linux・Swift6.1.2・sourcea28ae0a、test_application_ui_runner.pyの補足検証で、実行途中の
logに7件のFを観測した。session72201継続中、具体case/失敗assert/原因は詳細未読として対処前に記録する。
runtime準備4件とmanifest30件は成功済み、これらを当該runner検査の成功へ代用しない。
存在しないtest_application_relaunch_native_probe.py指定のdiscoverは0件で、検証成功には数えない。
runnerの実際の定義ファイルを検索して当該検査を開始した。新しい詳細と過去記録/旧現sourceを比較する。

N178の最終結果は16件/58.882秒、preflight一件のsubcase7失敗。最初の26 downloadは成功したが、
同一RUNNER_TEMPを共有する次のsubcaseから所有export directoryが残り、FileExistsErrorで停止、
後続のdownload一回という期待も0回となった。実Apple/製品/同じjob内retryの不良ではない。
N77/N75詳細と3054127/031916/currentのpreflight抽出・helperを照合した。旧testは一つのprepare stepのみを
実行して次の入力へ移り、旧TemporaryDirectoryはそのstepで回収していた。新候補はjob末尾のalways回収へ
寿命を移したので、testも実cleanupモードを各独立入力の後に実行する必要がある。元の全27入力/SDK・Runtime/
download一回/import件数/正負期待は変えず、cleanup成功・所有export不在も要求し、workflowの26限定always接続を
確認する。製品や準備の受理条件を緩めず、記録と候補を先にpushしてから再検査する。

## N179 主正式200e60aの通常26 Aが失敗終端（2026-11-06）

予定11:15 UTC照会、source200e60a832adbf555db5d5e8a575b9f63ceceb31/run42192999314/attempt1、
job127830490300は10:00:53Z開始・10:51:40Z failure。要求SDK27.1/Runtime26.5、具体case/stage/原因は
log未読で未確定として対処を選ぶ前に記録する。通常27 A/Bと訂正の両OS全8件は成功した。

## N180 同じ主正式200e60aの通常26 Bも失敗終端（2026-11-06）

同source/run/attempt、job127835521127は10:29:20Z開始・11:01:18Z failure。
要求SDK27.1/Runtime26.5、具体case/stage/原因はlog未読で未確定。全18表示job終端・実14件、成功12/失敗2、
依存・構成skip4を成功に数えず公開なし。新7logとartifact一覧を一度確認し、前回取得7logは再取得しない。
新logを読んでから過去詳細と当時/現sourceを照合し、同条件を根拠なく繰り返さない。

N179の先行Auxiliary caseは初回起動と実操作を通過後、73.72秒で停止確認→cold準備のHome命令に入り、
その命令の返却/ready記録がないまま約4分後にXCTestがunexpected exit/crash/test timeoutとしてrunnerを再起動した。
以後17件はforeground/fixture-ready待機で失敗した。製品アプリのcrashや全17機能の不良とは断定しない。
事前healthは10秒でunknown、最後はRuntime available/device Shutdown。N176/N177のbundle nullは出ていない。
N180は通常6件と先行追加phaseが成功し、独立通知caseの最初のONだけ126.863秒で失敗。外側rowと
実native track(300,177.333,63,28)の一意/0状態/全包含/enabled/hittableを確認、同じ0.25/0.5へ0.1秒一回接触後も
45秒内にUI/保存/Binding/認可要求が始まらず0のまま。端末やAPIの通知配送失敗へは到達していない。
Runtime available/device Booted、診断overlayは非hitを維持。全14log各一度/artifact0確認済みで再照会しない。

照合：N179はhome-once/launchReady/foregroundでU43/U49/U59/N95/N125の詳細とf709367/現helperを読み、
初回ready後のtarget launch timeoutとは異なり、今回は対象停止直後のHome命令自体から返っていないことを確認した。
候補は対象のnotRunning確認後、SpringBoardがすでに実foregroundならHome命令を重ねず、そうでない時だけ
従来のHome一回を送る。いずれも元45秒内にSpringBoard foreground/有限frameを観測し、対象の一回launch/
45秒foreground/45秒fixture-ready/元の全保存proofを必須とする。不明状態は成功にせず、retry/予備起動をしない。
Homeを呼んだかを固定値で記録し、起動下位原因の解消とは断定しない。元UI casesが実停止/新process/保存を検出する
ため、mock Apple APIを新しく作って恒常的な実OS成立を模倣するテストは追加しない。

N180はU19/U43/U55/U64/U71/N94/N167の詳細と当時/現native helper・既存FixtureInputDeliveryを比較した。
従来の同じ点/時間/実要素でも未反映があり、現在のlogには実UIKitのbegan/ended/cancelled/認識器/native Boolがない。
点/時間/製品/認可の受理を推測変更せず、この通知caseのみに既存--fixture-input-traceを追加する。
既存の128記録上限・固定名/数値のみ・元sendEvent一回・読取専用のbefore/after native観測・strict所有log回収を使う。
45秒・実Allow一回・UIと保存の両成立・全通知/全15gateは不変で、失敗なら追加の配送証拠を調べる。
候補と比較を先に隔離refへpushし、既存observer/manifest/Swift構文/catalogの局所確認と新規専用review後に
同じsource/run/attemptの正式全15を一回確認する。個別成功を借用した公開や未知の入力成功扱いはしない。

## N181 主正式bb201b8の明示選択復旧27が失敗終端（2026-11-06）

予定12:15 UTC照会、sourcebb201b8278167ebfbf37aa6b70742dc767506d40/run42209482541/attempt1、
job127865132718は11:28:23Z開始・11:45:28Z failure。要求SDK27.1/Runtime27.0、元の明示選択case、
具体stage/原因はlog未読で未確定として対処を選ぶ前に記録する。27通常A/B・他の訂正3件/Native/Distributionは成功。
26 A/Bは各12:02:35/11:58:33開始で継続中、取消さず終端を確認する。訂正26は依存skipで成功へ数えない。
新8logだけ一度取得し、過去の取得済みrun/logは再照会しない。新詳細と過去詳細/当時と現sourceを比較する。

N181完了logは608.669秒、manual Navigation.swift:62の実教師入力欄global Any firstMatch.existsが
UI query timeout。選択subjectの保持値確認は通過し、第三のroom選択後にsubject/teacherの保持値を
再確認するteacherの可視化中、t434.47のexistsから内部retry465.55/496.60へ進んだ。ACKや確認本文ではない。
この呼出しは既知manual-value- IDを持つのにvisibleへknownIDを渡しておらず、不在/virtualized時に
global firstMatch.existsを使っていた。subject/teacherの編集・実保持値や製品不具合とはまだ断定しない。

ManualAssistanceChecks+OneCorrection/Input/Navigationとinput/manual-value/existsでcatalogと索引を検索し、
N54/N78/N94/N97/N153/N173の詳細、c7994b7/bb8091e/現OneCorrection・Navigationを読んだ。
N173は確認後のlabel frame停止で、今回の候補で変更したreview経路は通過している。N97の既知IDの
論理検索は同helperにあり、単項目の保持値assertはすでにknownIDを渡しているが、明示選択caseの3箇所だけは
同じIDを引数に渡していない。候補はその3つのvisibleへ既存manual-value-+keyを渡し、現在の実配列の
一意性/位置をviewport観測後に確認する同じ経路を使うこと。対象不在時にglobal exists/frameへ戻らず、
元16探索/受動drag/有限枠/全包含/hittable・教師/subjectの保持値assert・独立ACK0・4件拒否・保存再起動を保つ。
新しいUI条件や型の仮定、成功値注入、期限延長は追加しない。元case/幾何/生成/manifestで十分なので、
同じID文字列を写すだけの追加caseは作らない。根拠/候補を先に隔離refへpushしてから局所確認する。
継続26 A/Bは取消さず、実開始から最大55分を踏まえ13:05 UTCに新しい終端だけまとめて確認する。

## N182 主正式b04d011の三項目復旧27が失敗終端（2026-11-06）

予定14:30 UTC照会、sourceb04d0119177a38dc74359364c0542569253054d0/run42227564373/attempt1、
job127925810909は13:48:33Z開始・14:02:38Z failure。要求SDK27.1/Runtime27.0、具体stage/原因は
log未読で未確定として対処前に記録する。限定を通過した明示選択27と通常27 A/Bは正式でも成功した。

## N183 同じ主正式b04d011の単項目復旧27も失敗終端（2026-11-06）

同source/run/attempt、job127925810970は13:58:45Z開始・14:13:21Z failure。
要求SDK27.1/Runtime27.0、具体stage/原因はlog未読で未確定。元通常26 A/Bは14:27:43/14:23:11開始で継続中、
取消さず終端まで確認する。新8logだけ一度取得し、過去の取得済みrun/logを再照会しない。
新しい具体logと過去詳細/当時と現sourceを比較し、全体を繰り返す前に対応する限定検証で候補を確認する。

14:31頃に作業環境の再起動が通知され、進行中のlog取得cell343が消失した。再開後、同じsourceと未commitの
N182/N183記録は保存されている。新8logのうちDistributionと通常27 Aの2ファイルだけが保存され、
残6件は一括取得のメモリ応答を失っている。完了済みの旧runや保存済み2logは再照会せず、
今回失われた新6logだけを回復取得する。環境の中断を製品やCIの追加失敗へ数えない。

回復後のN182完了logは205.412秒、ManualAssistanceChecks.swift:45の初回app.launchがXcode経由でtimeout。
Home一回とSpringBoard state4/有限frameは通過し、入力/ACKには未到達。独立統合logは15秒で取得不能、
crashCauseはunassessed、owned-input-log読取は成功したがinputDeliveryLines0である。初期化のどこまで進んだか
を現collectorが出さないため、製品crashやseed不良と断定しない。N183は416.122秒、Review.swift:26の元20秒。
入力全文とACKは成立、submit一回後にcoordinator-stateのglobal配列取得が19秒以上返らず、期限後AXは
preview=false/review=true/running=falseだった。期限内の状態成立や製品処理失敗は事後AXだけでは証明できない。

launch/home-once/Review.swift/coordinator-state/全画面検索でN95/N125/N168/N173/N179/N181と当時/現sourceを
照合した。N168で一回labelから同時判定する論理は直したが、N183はその前の全appのStaticText配列取得で停止する。
候補は既存QA overlayだけに明示的な観測container IDとchildren contain/非hitを付け、reviewとpreviewの両方を
そのcontainer内の同じstateへ限定する。製品やstateの値・一意性・一回label・元20秒・後続assertは変えない。
manualのcold準備は通常Suiteと異なりまだ無条件Homeだったため、両helperを同じforeground条件付きHomeへ揃える。
元45秒のSystem UI証明・対象一回launch・fixture-readyは保持し、N182の直接修復と断定しない。
既存FixtureLaunchDiagnosticsの初期化固定ラベルが同じ所有logに記録されているが、manual collectorはinput行しか
回収していなかった。既存launch9種だけを64KiB/128行/固定PID・時刻形式/全行一致で回収し、seed/readyへの
到達を次の限定で観測する。別本文・symlink・過大・不正encodingを拒否し、extra Apple呼出しを増やさない。
元の試行終了値と回収順序を保つ。新旧review predicate正負対照、生成container接続、owned lifecycle拒否を局所確認し、
候補と根拠を先にpushしてから既存manual限定all4case×両OSでまとめて確認する。正式の残26は取消さず終端確認する。

## N184 旧正式b04d011の通常26 Aも失敗終端（2026-11-06）

予定15:25 UTC照会、sourceb04d0119177a38dc74359364c0542569253054d0/run42227564373/attempt1、
job127947154731は14:27:43Z開始・14:41:13Z failure。要求SDK27.1/Runtime26.5、具体case/stage/原因は
log未読で未確定として対処前に記録する。最後の26 Bは成功、全15表示job終端・実10件、成功7/失敗3。
新しい最後の2logとartifact一覧だけ一度確認し、旧取得8logを再取得しない。公開なし、skip5は成功へ数えない。

## N185 関連4case限定2451a1bの三項目27が失敗終端（2026-11-06）

同じ予定照会、source2451a1b2da2fa1ef7659ff692463f95f3f30ad91/run42236030942/attempt1、
job127953754865は14:58:37Z開始・15:18:27Z failure。SDK27.1/Runtime27.0、元三項目case、
具体stage/原因はlog未読で未確定として対処前に記録する。

## N186 同じ関連限定の明示選択26も失敗終端（2026-11-06）

同source/run/attempt、job127953755070は14:40:37Z開始・15:09:21Z failure。
SDK26.5/Runtime26.5、元明示選択case、具体stage/原因は未読で未確定。限定26の他3件と原本変更27は成功。
明示選択27/単項目27は各15:01:50/15:07:25開始で継続し、取消さず残結果を確認する。
限定の新6logだけ一度取得し、失敗段階と既往/旧現sourceを比較してから次の対処を選ぶ。

N184完了logは最初のcase起動時にRuntime bundleを決定できず、N166/N176/N177と同じ固定エラー。
export保持後にも再発しており、その削除が直接原因だったとは扱わない。SDK/OS/deviceを推測で変更しない。
旧正式は全10log各一度（環境中断時の未保存6log回復を除く）/artifact0確認済みで、終端runを再照会しない。
N185は567.734秒、元3入力/各ACK/確認/preview/閉じる/未採用proofは通過し、Cases.swift:58の
app.terminateだけがretained pid10301に対してpid0への終了失敗となった。新4件拒否用cold launchには未到達。
固定lifecycleは既存processのfixture-readyまで10行、input42行、matching crash report0で原因はunassessed。
初回launch timeoutだったN182やglobal state待機のN183とは異なる。アプリcrashや終了成功とはまだ断定しない。
N186は1316.551秒、4件目拒否の状態文のbounded visible探索で失敗。3項目保持/ACK/確認/previewは通過した。
statusは一度(16,249,361,72.333)でviewport(0,193,393,647)へ収まると観測されたが、hittableを得られず、
識別子なし/owner不明のまま同じpassive行で進まなくなり、反転後に末尾へ向かってno-progressで失敗した。
本文/実状態/起動は破壊していない。statusが期限内に真に完全表示だったか、古いqueryの枠かは未確定。

terminate/pid0とvisible/status/no-progressで索引を検索し、U43/U55/N95/N125/N173/N179/N181と旧/現Cases・
OneCorrection・Navigation・実PDFRecoveryView/Coordinatorを照合した。N185には終了直前の新しいprocess状態がなく、
helper間でcold起動の前提は揃えたが、3つの終了呼出しは直接のterminateのままだった。候補は全3箇所で同じ
終了helperを使い、現在のforegroundを元nativeStateTimeout内に実確認してからterminateを一回だけ呼ぶこと。
notRunning/unknownを成功にせず、元の後続notRunning待機と新一回launch・保存/4件拒否のproofも維持する。
pid0の下位原因の解消とは断定しない。N186は製品のstatus Textに既存QA生成コピーだけの専用IDを付け、
同じ表示を現在のList/既知ID/実labelから確認する。元の完全包含/hittable/16探索/反転上限と同じ45秒本文存在を
保持し、見えるTextだからhittableを不要とする救済はしない。製品statusや3項目上限・期待本文を変更しない。
候補と根拠を先に隔離refへpushし、既存生成/幾何/manifestで局所検証してから関連限定を再評価する。
進行中の限定2件は取消さず、実開始+元35/45分から15:50 UTCに残りだけ確認する。

局所確認後の主担当照合で、終了前のforegroundを確認できなかった場合にcallerへ明示的にfalseを返し、
全3callerもguardで以後のlaunchへ進まない形へ揃える。終了失敗や不明状態の後に次の試行を開始しないための
制御で、元のケース失敗は保持する。この追加も実限定前にpushして既存生成/manifestを再確認する。

## N187 関連限定2451a1bの単項目27も失敗終端（2026-11-06）

実成功時間（選択最大約33分、単項目約23分）と局所検証終了を踏まえ、期限上限で予定した15:50を前倒しして
15:35 UTCに残2件を確認した。source2451a1b2da2fa1ef7659ff692463f95f3f30ad91/run42236030942/attempt1、
job127953755163は15:07:25Z開始・15:27:04Z failure。SDK27.1/Runtime27.0、具体stage/原因は
log未読で未確定として対処を決める前に記録する。明示選択27は成功し、全8job終端、成功5/失敗3。
最後の2logとartifact一覧だけ一度確認し、前回取得6logは再取得しない。新しい具体段階を読んでから候補との関係を判断する。

N187完了logは629.615秒、入力・ACK/確認・背景復帰は通過し、QA toolbarの架空検証Button一回tap後に
「表示サイズを変更」が元45秒で出なかった。実caseの製品入力や状態検索の停止とは異なる。N185/N186を含む
限定は全8log各一度/artifact0確認済みで、この終端run/logを再照会しない。
架空検証/表示サイズ/fixture menuで索引検索し、直接のmenu開封未反映の過去項目は見つからなかった。
U63/U75の同じ可視/有効Buttonの標準tap未反映、N85のmenu操作後の別検索停止、N151/N154のnative identity
詳細とf709367/現menu helper・通常Suiteの接触を比較した。今回のopening helperは古い直接Button.tapのままである。
候補は元toolbar/label/45秒存在を保ち、同じButtonを現在のnative identityで一意に取得してframe/toolbar包含/
enabled/hittableを確認し、その同じ中心へ一回0.1秒接触する。U63/U75の既存方式と同じで、画面座標を保存しない。
元3action全ての45秒存在・後続実action/入力保持は維持し、menuを押し直さず正常状態を注入しない。
効果や下位の入力取消原因は未確定。N185/N186候補と同じ限定全4×両OSで確認する前に記録と候補をpushする。
先に作成したN186用reviewは未消費のまま廃止し、N187差分も含む別の新規専用review後にだけ次の限定を開始する。

限定が旧26.6 SDKで通っても正式27.1のRuntime利用不能を先に検出できないため、既存manual probeへ
sdk26=27.1の明示選択を追加する。既定26.6/旧比較は維持し、今回は両OSとも配布SDK27.1を使い、
26.5を同じprepare/hold/always cleanupで確認する。元4case×両OS・35/45分・exact source・fail-fast false・
全assertは維持し、公開gateは変更しない。入力/Runner/Developer/SDK/26準備/always回収の接続を既存manifestで
検査する。新しいSDKを導入せず、正式で既に使っているtoolchainを限定でも明示するためである。
N187用reviewも未消費で廃止し、このworkflow差分を含めた別の新規専用review後にだけ限定を開始する。

## N188 配布SDK限定の最後の明示選択26がjob上限後も進行中（2026-11-06）

sourcedbbcc4b2c003f9811711d607a5b8cc6866911fff/run42246376301/attempt1、job127989558227。
16:04:41Z開始、SDK27.1/Runtime26.5準備は16:06:49Z成功、実test/script stepだけが16:52/16:55/16:59照会でも
in_progressだった。設定の元45分を超え、後続export回収はpending。終了結果・実test/診断/回収のどの段階かは未確定。
他7件は成功し各logを一度保存済み。直近の単体job URLは連携ツール非対応のためCLIで確認したが同じ進行中だった。
進行中logの取得は保存先拒否/連携エラーで得られず、取得失敗をtest成功や失敗に読み替えない。
このjobは取消さず残結果を追う。main用の準備reviewは未消費で、8件成功はまだ確認できていない。
対処案を決める前に本事実を記録し、過去の外側timeout/cleanupと当時/現runnerを照合する。

N162の詳細と2b5e5c9/現application-relaunch wrapper・manual runner・timed_commandを読んだ。
N162もjob上限30分を超え35分で終了し、27本文logを取得できず停止段階は未確定だった。既に24分の
実process監督/所有group終了120秒/固定stageで回収を試みる対処がある。一方manualは外側job予算だけで、
script全体とsimctl shutdown/deleteには有限監督がなく、testとcleanupを区別するstageもない。
今回の実停止段階はまだ不明だが、少なくとも同じ観測・終了制御の欠落はsourceで確認できた。

候補は元45分job内のmanual scriptを40分+所有group回収120秒で監督すること。35分の任意限定は30分+120秒とし、
元のjob予算を延ばさない。timeoutは124の失敗、元testの非zero/取消も保持し、PASS文字列だけで成功にしない。
cleanupの所有UUIDのshutdown/deleteは各10秒/猶予3秒で試み、元の失敗終了値を変えない。固定stageで
準備/build/boot/test/完了照合/診断/所有回収を区別する。UIの45秒/20秒/16探索/元入力/保存proofは一切変えない。
新しい限定にはOS選択を付け、既定both/旧SDK比較を保つ。今回は停止中の明示選択26だけをSDK27.1で検証し、
既に成功した27を同じ理由で重ねない。未知のOS/SDK入力は実行前に拒否する。
旧7件の実UI通過と今回の監督器検証を同一runの8成功へ合算せず、正式では新source/run/attemptの全15を別に要求する。
旧N188は取消さず追跡を継続し、新sourceの独立した検証を並行して進める。先行main用reviewは未消費で廃止し、
監督器の実process正負対照/cleanup終了値伝播/選択接続を確認後、別の新規専用reviewで限定を開始する。

N188候補9676cb8は試行前に非起動featureへpush済み。Linuxで監督器5件/失敗0（7.904秒）、
diagnostics12件/失敗0（0.302秒）、実shell+架空Apple commands5件/失敗0（8.568秒）、
project17件/失敗0（0.525秒）、manifest30件/失敗0（Swift6.1.2有効18.807秒）、
source-path3件/release-gate13件/失敗0、Bash構文/catalog450/check --base dbbcc4bが通過した。
最初のmanifestはSwift未設定で3件skipだったため、既設toolchainを有効にして同じ30件を再実行しskip0を確認した。
実processの2秒上限は124となり、TERM無視の所有childだけ回収・別groupは生存した。
cleanupは診断失敗6・shutdown/delete失敗9でも元0/7/143を保持し、正確な所有UUIDの順と10秒/3秒を確認した。
OS/SDKの24入力は正しい6組だけ受理し、不正18組はApple呼出し前に2で拒否した。
UI実操作・入力・全15gateは省略せず、次の限定は26/SDK27.1の明示選択一件だけである。

新規GPT-6.1 Sol/High ios_n188_supervisor_probe_pre_actions_reviewはcode-only5path/269行/16072bytes、
SHA256 7b538d608daf4ef45f0bbb97b552d7641e80c8616e9a53862978b2627d237e79の全差分と周辺を照合し指摘なし。
主担当が未変更hash・局所結果・未送信commit空白を確認後、26/SDK27.1の明示選択一件だけをdispatchする。
このreviewはその一回に消費し、後のmain開始には別の新規全差分reviewを要求する。

限定run42259774318/attempt1/source3ca41912976decdba248f16808a1c7e88b50bc3eは17:14:16Zに開始要求した。
OS26/SDK27.1の明示選択一件だけで、旧N188の停止中jobは取消していない。
待機中に別の新規GPT-6.1 Sol/High ios_n188_full_main_pre_actions_reviewが実main b04d011からの
全14codepath/565行/35956bytes、SHA256 f75c56643eaef35bd781a030e7af266b5582b0dd8115918a5b2b6e2dfc6364dfを確認し指摘なし。
これは限定成功・完了log確認・コード不変を条件とした次のmain一回専用で、現時点では未消費である。
文書は利用者の指定に合わせ、19行/13項目の短い「失敗→推奨」に圧縮した。詳細・不確定事項は索引に残す。

N188旧実行の終端を17:30Zにまとめて確認した。job127989558227は16:59:42Zにcancelled（開始から55分01秒）、
他7件successで全8終端。主担当から取消操作は行っていない。最後のjob本文取得は終端後も404/BlobNotFoundで、
停止段階・実UIの到達は依然不明。保存artifact0を一度確認し、旧7成功を8成功へ書き換えない。
新限定42259774318の一件job128036343146は17:14:20Z開始、OS/SDK選択・26.5準備は成功し、17:30時点でUIstep進行中。
旧runのarchiveを代替として一度取得したが14entryは他7jobの本文/システム記録だけで、明示選択26の本文は無かった。
他7件の本文は再読せず、archiveの件数/hashを非公開receiptへ残して所有ZIPを削除した。欠落logの回収はここで終了し、旧runは再照会しない。

## N189 有限監督追加後の明示選択26限定がfailure（2026-11-06）

source3ca41912976decdba248f16808a1c7e88b50bc3e/run42259774318/attempt1/job128036343146、
OS26/SDK27.1/予定Runtime26.5の明示選択一件。17:14:20Z開始、17:43:30Zにfailure。
exact source・入力検証・Runtime準備はsuccess、Exercise stepはfailure、最後の所有export回収はsuccess。
本文未読の時点では実UIの到達・失敗段階・outer timeoutの有無は未確定で、対処案を選ぶ前に事実を記録した。

完了logは一度保存済み、artifact0。実Runtime26.5、case1035.572秒/失敗1、Navigation.swift:190。
3項目入力/ACK/確認/preview/4件目menu操作の後、manual-statusの表示探索で失敗した。
同じIDのstatusと所有Cellは(16,249,361,72.333)、viewport(0,193,393,647)に3回収まったがhittableが成立せず、
元の一回反転後に末尾へ進みno-progressで失敗した。N186と同じ幾何だが今回は専用ID/所有Cellを特定できている。
build73.5秒/boot65.0秒/test1158.7秒、outer1534.1秒で上限は発火せず、診断→shutdown→delete→cleanup-completeを記録した。
監督器が元のUI失敗を成功にせず伝播したことは確認できた。既知IDだけでは元のhittability問題を解消していない。
対処の選択前にこの本文事実を追記し、N186/N160と当時/現Navigationを比較する。先行main用reviewは未消費で廃止する。

追加の観測事実：失敗後AXのmanual-observationは(0,129,391.7,155.3)で、直前に完全包含したstatusの
(16,249,361,72.333)と重なる。QA生成は現在topLeading overlayで、元の診断/保存proofを含むVStackを置く。
外側/各TextにallowsHitTesting(false)はあるが、AX上の重なりは残る。画像・接触時のAXhit配送は未採取で、
この重なりがhittable不成立の直接原因とはまだ断定しない。N160のButton native identity整理後も、statusはindexed Anyである。

overlay/observation/hittableでN49/U77/N160/N183/N186を検索し、N49とN160詳細・旧fd6e42c通知fixture・
旧b04と現manual generator/Navigationを照合した。N49は対話panelから通知設定への入力未反映で、
今回の既に非hitのQA観測Textとは違う。一方、QA表示が製品の前面に残る構造上の差は実sourceにあり、
今回はAX枠の重なりも直接観測した。N160は二段階のButton hit照会でnative側が例外となった別条件であり、
今回の非Button全体を根拠なくnativeへ一括変更しない。
次の候補はQAの同じ観測container全体だけをoverlayからbackgroundへ移し、製品Listの前面を覆わなくする。
状態/診断/保存proofの実値・ID・children contain・非hitは保ち、List寸法や操作・完全包含/hittable・16探索/一回反転・
45秒本文・3項目上限/4件拒否/実採用/再起動は変えない。観測表示のAX存在が失われた場合も元の状態待機で失敗する。
この一変更を先にpushして生成/状態/幾何/manifestを検証し、新規review後に同じOS26/SDK27.1の一件で比較する。

## N190 LinuxでApple専用project全生成を追加実行してplutil変換が失敗（2026-11-06）

source1b78ddc、Linux/Swift6.1.2、17:51Zの追加構文確認でmanual_ui_project.pyの全project生成を呼んだところ、
app_test_project.py:186のplutil -convert jsonが終了1となり、manual Viewの構文解析前に停止した。
製品/Swift構文/UIの失敗とは未確定。既存project17件・状態/幾何の実Swift対照は通過済みで、
全生成の成功とは扱わない。所有TemporaryDirectoryは例外後も回収済み。対処方法を決める前に本事実を記録した。

plutil/Unimplemented/Linux生成で索引を検索したが、過去の同じplutil失敗記録は無かった。
現app_test_project.pyと既存17件の生成検査を比較すると、全project生成はAppleのOpenStep変換を呼ぶが、
Linux側の既存検査は同じview変換関数を元Swiftへ適用している。コードは変えず、その実変換結果だけを
所有一時Swiftへ書きSwift frontendで構文解析する。macOSの全project生成/build/実AXは次の限定CIで確認し、
Linuxの部分検証を全生成成功へ読み替えない。この差を先にpushしてから構文確認をやり直す。

N189候補1b78ddcの関連局所結果：project17件/失敗0（0.659秒）、実review状態2件と実Swift18条件/失敗0（6.784秒）、
navigation2件/実Swift幾何29条件/失敗0（3.970秒）、manifest30件/失敗0/skip0（29.567秒）、catalog450/check --base8117882は通過した。
N190の範囲を直した再確認は、同じview変換関数を実PDFRecoveryView.swiftへ適用した出力のSwift構文解析が成功した。
Apple専用のproject全生成はこの成功に含めず、次のmacOS限定へ残す。コードをLinux向けに偽装する変更はしていない。

新規GPT-6.1 Sol/High ios_n189_background_probe_pre_actions_reviewはcode-only2path/26行/1788bytes、
SHA256 6b2a3fa3c1462041f66ddca08db01c40e9484a044cf7aa2092f520ebbdc06c31を実rangeと照合して指摘なし。
主担当がコード不変・局所結果・commit空白を確認し、同じ明示選択26/SDK27.1だけの次の一回へ消費する。
背景へ移したAX観測の存続と実hittableはまだ未確認で、失敗を成功へ置き換えない。mainには別の新規全差分reviewが必要。

## N191 QA観測を背面へ移した明示選択26限定がfailure（2026-11-06）

sourced572f69db8c2794f7e5803da9b4bdffa1a16b68e/run42265854163/attempt1/job128057439798、
OS26/SDK27.1/予定Runtime26.5、元明示選択一件。17:54:16Z開始・18:07:09Zにfailure。
exact source・入力検証・Runtime準備はsuccess、Exerciseはfailure、所有export回収はsuccess。
18:30Zの予定照会で終端を確認した。本文未読の時点で失敗段階・観測containerの存続・statusの到達は未確定。
次の対処を選ぶ前に記録し、新しい完了logと過去詳細/当時と現sourceを比較する。

完了logを一度保存しartifact0確認。実Runtime26.5、case166.331秒/失敗1、Input.swift:129の元完了Button待機が失敗した。
初回の科目消去・全文「架空選択科目」入力まではBinding/実TextField値で成立した。失敗後AXではKeyboardとmanual-edit-doneが
いずれも無く、復旧barは閉じる/架空検証だけだった。QA観測containerとmanual-input-stateは背面でも存在し、実入力/ack=falseを保持した。
U02は完了が存在してhittable=falseだったが今回は存在自体が無い。review/preview/4件目拒否の旧N189位置には未到達で、
背景移動によるstatus改善は未確認。outer613.4秒でtimeoutなし、所有回収完了。次の対処前にこの差を記録した。

完了/keyboard/focusでU02/U72/N163を検索し詳細・693cf079のInput・d4c1bceと現ApplicationFixture/製品FocusStateを比較した。
U02/U72の完了存在後のhit/AX停止と異なり、今回の完了は復旧bar内に無く、keyboardも消失している。
N163には固定のUIKit編集/keyboard通知observerがあるが、手動fixtureはflagを付けず、手動collectorもその8stageを拾っていなかった。
既存observerは現在も同じ7通知/32件上限で、差分は別のtouch配送診断だけだった。推測でfocusを設定し直したり、
keyboardが無ければ完了tapを省く救済はしない。
次の限定では既存の読取専用observerをmanual flagで有効にし、同じstageへUITextViewの3通知も対応付ける。
元の一回消去/全文入力/完了Button45秒・一回tap/keyboard消失/ACK/4件拒否/保存/再起動は維持する。
collectorは既存8stageだけ追加許可し、文字列/通知userInfo/focusの読み書きを加えず64KiB/128行/32通知の上限を保持する。
新しい通知観測で最初の消去から編集終了/keyboard hideの順を区別する一回であり、入力方法・期限・製品のFocusStateは変更しない。
候補と根拠を非起動featureへ先にpushしてから局所・新規review・同じ26/SDK27.1の限定へ進む。

候補bb5baacは先にpush済み。Linuxのdiagnostics12件/失敗0（0.467秒）、project17件/失敗0（0.927秒）、
manifest30件/失敗0/skip0（21.002秒）、Swift fixture/checks構文、catalog450/check --base d572f69が成功。
固定17stageの正対照と任意本文/未知stage/不正PID時刻/範囲超過/symlink/不正UTF8の拒否を維持した。

新規GPT-6.1 Sol/High ios_n191_native_edit_probe_pre_actions_reviewは全5codepath/71行/5019bytes、
SHA256 d88bacf34350df9be129876e04b09e49c53554ccdb113845b1c890ec4bb6c8ceを確認し指摘なし。
主担当が同じhash・局所結果・全commit空白を確認し、26/SDK27.1の同じ明示選択一件だけの次の一回へ消費する。
これは観測を増やした診断で、元の失敗や条件を緩和しない。公開前には別の新規全差分reviewと元の全15成功が必要。

新限定run42272298832/attempt1/sourcef2999889a381735e64e12de1b5cac95400afad8c/job128079672180は
18:36:56Z開始・19:12:55Zにsuccess。SDK27.1/Runtime26.5、元明示選択case1395.135秒/失敗0を厳密完了照合した。
全文入力/元完了Button/個別ACK/3項目保持/4件目拒否の実status完全包含+hittable/採用/保存/一回再起動後の保持まで通過した。
背面の実QA状態と保存proofも存在した。編集開始→keyboard表示→実文字変更→完了操作に伴う編集終了/keyboard非表示を
固定通知で記録した。32通知の上限は維持したため全後続入力の通知を網羅したとは扱わない。
outer2006.4秒で2400秒上限は発火せず、厳密完了→診断→所有shutdown/delete→cleanup-completeを通過し、export回収も成功した。
完了log一度保存済み/artifact0一度確認済み。この終端run/log/artifactは再照会しない。
旧N191の完了消失原因や下位OSの恒常的解消は未証明。旧N188/N189/N191失敗は保持し、別runの7成功と合算しない。
次は新規main専用全差分reviewの後、同じsource/run/attemptの元の全15を通常公開経路で確認する。

新規GPT-6.1 Sol/High ios_n191_verified_main_pre_actions_reviewは実main b04d011からの全15codepathを確認し指摘なし。
code-only596行/38525bytes、SHA256 01e750540364ba18fe257938c283814774379709ea922de34b5d2e29b73ab4a9と
実nondoc差分が一致した。主担当は同じhash・局所/限定結果・元の全15条件・未統合全commitの空白を照合した。
この新規reviewだけを次のmain通常fast-forward開始一回へ消費する。別sourceの限定成功を正式gateへ加算せず、
全15の同一source/run/attempt成功と正式publisherの完了後にだけ公開物を確認する。

## N192 正式b965の通常iOS27 Bがfailure（2026-11-06）

sourceb96509816e982a92932d43739b3b4a4f8fdf209b/run42278038401/attempt1/job128100274826、
SDK27.1/予定Runtime27.0、通常B。19:17:22Z開始・19:44:21Zにfailure、20:10Zの予定照会で確認した。
DistributionとNative、通常27 A、手動27の元4件はsuccess。通常26 B/手動26は依存skipで成功に数えない。
通常26 A/job128121440677は19:59:23Zから進行中で取消しない。正式全15/公開は未成立。
本文未読の時点で具体case/失敗段階/下位原因は未確定。対処案を決める前に記録し、完了logと過去詳細/当時と現sourceを比較する。

完了logを新7件だけ一度保存した。Bは基本6件がすべて成功し（900.6秒）、次の独立runnerの
testSettingsAccountDataAndFileDetailsだけ140.108秒/失敗1、Settings.swift:249。
Physical AI/OCR switch tap did not update both UI and stored permissionで、後続size/VoiceOver/通知phaseは未到達。
同sourceのNativeは701件/予定skip1/失敗0（Xcode26.6/SDK26.5のjob）、手動27は元4件がすべて成功し、
通常27 Aは元18件/実通知1件が成功した。他SDKのNative成功や全15成功とは読み替えない。

AIの最初の0→1で、実row(16,472.667,361,52.333)/native(300,485,63,28)・双方0・全表示/操作可を確認し、
native identityの同じ25%点(315.75,499)へ一回0.1秒接触を合成したが、45秒後もUI0/保存0だった。
回収logにはpid35055のAI setter before/afterとtouch配送記録が無い。このcaseは--ai-feature-probeだけで、
既存--fixture-input-traceはlink/通知/行除外にだけ付いていた。配送先・取消し・下位原因は未観測で断定しない。
U64/U55/N146/N180の詳細と917e807の旧native helper/現helper・setUp初期条件・setter診断を比較した。
U64と同じ最初の0→1、U55の4回目とは違う。現在はN146後のnative identity/同一predicate観測だが、
今回もN180と同じ「失敗caseへ既存配送診断が未接続」という不足がある。点/接触時間/45秒や製品を推測変更しない。
次の候補はこのcaseにも既存の読取専用touch診断flagだけ追加し、before/after native Boolと認識器の固定数値を観測する。
元128記録上限/所有log/本文拒否/一回sendEventを維持し、初回3操作・再起動後4回目・UI/保存の両成立と全15gateは変えない。
候補/根拠を先に非起動featureへpushし、局所・新規review後に既存relaunch診断の同じcaseを27/SDK27.1だけで一回観測する。
進行中の旧26 Aは取消さず、次の比較とまとめて終端を確認する。

同じtapNativeSwitchの全5callerも点検した。通知2箇所・行除外2箇所のcaseには既存flagがあり、今回のAIだけ未接続だった。
候補96fad4cを先にpush後、manifest30件/失敗0/skip0（19.901秒）、Swift構文/catalog450/check --base b965098が通過した。
新規GPT-6.1 Sol/High ios_n192_ai_delivery_probe_pre_actions_reviewはcode-only2path/26行/1824bytes、
SHA256 704fb4019f42ae432505364ed193a27b700c32ca5bb66371d70deb47d68b8e23を照合して指摘なし。
主担当がコード不変・局所/空白を確認し、既存の同じ設定case・27/SDK27.1の限定一回にだけこのreviewを消費する。
mainへの次の開始には別の新規reviewを要求し、元の四回の実Switch操作・保存/再起動や全15gateを維持する。

旧N192の架空画面before/unresolved画像を各53片から復元し、235464/235812bytesと元SHA256を照合して目視した。
両方とも設定画面でAI SwitchはOFF、実操作領域は表示され、ダイアログ/別画面による被覆は無かった。
画像だけでtouch配送・取消しや失敗原因は断定しない。hash receiptだけを残し、所有PNG/一時領域は確認後に回収した。

旧正式b965/run42278038401の最後の26 Aは20:48:50Zにsuccess。元18件と実通知1件（153.358秒）が完了し、
全15表示jobは実9件（成功8/失敗1N192）・skip6で終端した。全9実jobのlog各一度・artifact0一度確認済みで再照会しない。
N192の失敗/公開skipは保持し、26 Aの成功で救済しない。
新限定run42286781588/attempt1/source25c9eff8c8b65a1f953a4eb58931be7ff407c5ce/job128129543567は
20:15:27Z開始・20:29:08Zにsuccess。SDK27.1/Runtime27.0、元設定case全体445.039秒/失敗0・厳密完了照合が通過した。
同じnative枠/同じ点/0.1秒の初回0→1→0→1と再起動後1→0は、実UI/保存・setter before/afterで成立した。
outer799.0秒で元1440秒上限内、所有回収も成功。全log一度保存/artifact0一度確認済みで、この終端runは再照会しない。
旧接触配送が未観測だった事実と原因未確定を保持し、個別成功を恒常的な解消/全15成功へ一般化しない。
次のmainには別の新規専用reviewを要求し、新source/run/attemptで元の全15を確認する。

新規GPT-6.1 Sol/High ios_n192_verified_main_pre_actions_reviewは実main b965098からの全2codepathを確認し指摘なし。
code-only26行/1824bytes、SHA256 704fb4019f42ae432505364ed193a27b700c32ca5bb66371d70deb47d68b8e23と実差分が一致した。
主担当が同じコードhash・局所結果・限定の実4操作/保存・未統合全commit空白を確認して、次のmain一回へだけ消費する。
元の全15gate/両OS/実case/保存/再起動を保ち、限定/旧sourceの成功は正式実行の必須成功へ加算しない。

## N193 正式6aaの手動訂正3項目27がfailure（2026-11-06）

source6aa8e3eb7770d634d7f1e3c25885530d91e3564a/run42292699516/attempt1/job128151202436、
SDK27.1/予定Runtime27.0、testThreeFieldsRequireEachAcknowledgementAndFourRefuses。
21:00:20Z開始・21:13:14Zにfailure、22:05Zの予定照会で確認。本文未読で具体段階/下位原因は未確定。
通常27 A/B・残る手動27の3件・Native/Distributionはsuccess。別ケース成功をこの失敗へ代用せず、対処前に記録した。

## N194 同じ正式6aaの通常iOS26 Bもfailure（2026-11-06）

同source/run/attempt、job128169682038、SDK27.1/予定Runtime26.5、通常B。
21:38:58Z開始・21:50:48Zにfailure。本文未読で実Runtime/case/準備かUIのどちらか/原因は未確定。
通常26 A/job128179262950は22:00:07Zから進行中で取消さない。手動26は依存skip、正式全15/公開は未成立。
新7件の完了logだけを一度取得し、過去詳細/当時と現sourceを照合してから対処を決める。

N193実log：build85.3秒/boot122.7秒は成功、case206.212秒/失敗1、ManualAssistanceChecks.swift:57の最初の
app.launchがXcode経由timeout。入力/ACK/3項目確認には未到達。一方、所有appのpid13410はinit/seed/scene/
content-appeared/root-task/application-ready/fixture-readyまで記録した。UIの正常到達とXcode launch戻り値の成功は混同しない。
outer756.5秒/元2400秒内、診断/所有回収は完了。旧N182の同API timeoutとの初期化段階差を照合する。
N194実log：bootstatusはFinished/終了0と出た後、最初のsimctl ui content_sizeでSimError405
Unable to lookup in current state: Shutdown（終了149）。read-only healthもRuntime available/device Shutdownだった。
実UI/XCTestの開始前で、Runtime bundle NULLだったN184とは段階が違う。直前のbootのterminal statusは4294967295。
所有shutdown/delete/export回収は成功し、原因は未確定。対処を選ぶ前にこの具体的な段階を追記した。

N07/U41/N182と当時782ad0d/693cf079/現App・manual・Picker runnerを照合した。manual/Pickerはsimctl boot/bootstatus
だけで選択Xcodeの画面hostを明示起動せず、通常AppはSimulator/DeviceHub起動と所有UUIDの画面URLを開く。
N194ではその画面URLを開いた後に端末Shutdownを観測しており、bootstatus返却だけをUI準備完了とする不足がある。
N07の全device照会timeoutも踏まえ、新しい確認は既存2MiBのread-only runtime観測を再利用し、照会timeout/不正/不明は即失敗する。
下位原因をGUI不在やdebuggerと断定せず、Appの既存frontend手順を三runnerで共通化し、画面host接続後に
正確な所有UUID/Runtime available/実Bootedを45秒内に確認する候補とする。Shutdown/Booting等の既知遷移だけは有限観測し、
再boot/再launch/実入力の再送は追加しない。45秒を超えて返った応答は成功にせず、全体job/元UI期限も延ばさない。
製品・Xcode debugger・timed_command・全UI期待は変更せず、元の所有cleanupも保持する。
候補/根拠を先に非起動featureへpush後、実shell/状態遷移/不正・期限・所有拒否を局所検証する。
その後それぞれ新規reviewを受け、手動3項目27、通常Bの元先頭case26/SDK27.1、Picker27を既存限定workflowで確認してから全15へ進む。

## N195 共通起動helperの一覧生成がsource重複登録で停止（2026-11-06）

22:23Z、base6aa8e3e＋未commitの共通frontend/実Booted候補、Linuxのtest_catalog.py writeが
Duplicate source ownership: tools/notification_service_trace.pyで終了1。テスト本体/CIは未実行。
共有sourceを3分類のsourcesへ重複追加した一覧準備の失敗として、対処を決める前に記録した。

同じ重複source文言の過去記録は無く、loadの所有検査と6aaの元mappingを比較した。
sourceの所有分類は一つ、checksは複数分類から参照できる契約だった。共通helper/runtime moduleはApp分類だけで所有し、
App分類の対応検査へmanual/Picker runnerも加え、他分類は共通検査を参照する形へ直す。
修正/比較を含む候補を先に非起動featureへpushし、一覧再生成と局所検査を行う。未生成の一覧をCI成功と扱わない。
候補fbe89a5をpush後の一覧再生成は452登録で成功した。Runtime観測17件/失敗0、共通起動helperの実shell2件/失敗0、
manual実runner5件/失敗0は通過した。通常App runnerは継続検査中である。

## N196 Pickerのローカルrunner fakeに選択Developerディレクトリが無い（2026-11-06）

sourcefbe89a5、Linuxのtest_picker_ui_runnerは1宣言/8入力中6入力が失敗（2.850秒）。
success入力はNo supported simulator frontend in the selected Xcodeで終了し、test-without-buildingへ未到達。
他5失敗は同じ準備停止で本来の失敗入力へ進まずbuild回数が1だった。実iOS/Picker UIの失敗とは区別し、対処前に記録した。

6aaの旧Picker fakeにはfrontendが無く、共通化後のApp/helper fakeはDeveloperを明示作成、manual fakeは子Simulator.app作成時に作っていた。
Pickerだけは兄弟Applicationsを作り、Developer自体を作っていなかったため、実OSの `Developer/../Applications` 解決が失敗した。
実Xcodeを模したDeveloperの作成一行だけを追加し、helperの実在確認・元8入力・期待値を保持する。候補を先にpushして再検査する。
通常App runnerの先行検査は完了出力の回収が文脈上限で失われ、processも終了していたため、成功とは数えない。
結果を所有logへ保持して一回だけ回収検査する。これは実CIの再実行とは区別する。

## N197 ローカルmanifest検査のファイル名指定誤り（2026-11-06）

source73454fc/Linux/Swift6.1.2環境で `test_ui_manifest.py` を指定し、0 tests/NO TESTS RAN・終了5。
検査は実行されておらず成功に数えない。一覧と実ファイルを照合すると正しくは `test_ui_test_manifest.py` だった。
実装・期待値には変更せず、候補記録を先にpushして登録済みの正確な検査を実行する。

## N198 旧正式6aaの残る通常26 Aもfailure（2026-11-06）

23:00Z一括照会でrun42292699516/attempt1/job128179262950のfailureを確認。
source6aa8e3e/SDK27.1・予定Runtime26.5、22:00:07Z〜22:11:39Z。本文未読で失敗段階・原因は未確定。
全15表示jobが終端、実行10件中7成功/3失敗・公開skip。新候補の成否と区別し、対処前に記録する。

## N199 共通frontend候補の手動3項目27限定がfailure（2026-11-06）

source064a36db0b7f85c1f142d269593837583c6ec894/run42305296322/attempt1/job128193002862、
SDK27.1・予定Runtime27.0・testThreeFieldsRequireEachAcknowledgementAndFourRefuses、22:31:05Z〜22:37:39Z。
23:00Zにfailureを確認。本文未読で準備/入力の段階も原因も未確定。別のPicker成功を代用せず、対処前に記録する。

## N200 同じ候補の通常先頭ケース26限定もfailure（2026-11-06）

同source/run42305486640/attempt1/job128193634574、SDK27.1・予定Runtime26.5、
testChangedAccountDataNoticeOpensSharedAcquisition、22:32:33Z〜22:42:06Z。本文未読で段階・原因未確定。
Picker27/run42305570054は3実行jobとも成功（native/inventoryは選択対象外skip）。
旧残jobと新5完了logだけを取得し、当時/現コードを照合してから次の対処を決める。公開前全体CIは開始しない。

N198実logはbuild121.2秒/boot92.5秒の後、最初のcontent_sizeでSimError405/Shutdown、終了149。
N194と同じUI開始前の段階で、実caseは未開始。N199はbuild59.4秒、DeviceHub起動、bootstatus118.7秒の
Device already bootedまで成功。画面URL後の新readinessで `simctl list -j` が10秒でtimeout/exit-1、
所有Bootedは未確認として終了1。N200もbuild79.8秒/boot81.0秒、画面URL後の同じ照会がtimeout/exit-1。
後続healthとOSサービスのread-only照会もtimeoutだった。両方ともXCTest/実入力へ未到達で、N193のlaunch再発とは言わない。
Pickerは同じsource/SDKで実Runtime27.0 available/Bootedを確認し、元3ケース/失敗0・483.547秒と遷移確認を通過した。
Portable Swift603件/失敗0、Python契約も成功。全4run終端・artifact0・新6log一回取得済み。失敗したreadinessを緩めて公開しない。

N199/N200照合：`list/timeout/bootstatus/DeviceHub` でN07/N169/N176/N182と詳細を再読し、
40e1aab・782ad0d・成功3c3bcbaのcompare.py/tensor-main.swiftと現helper/観測moduleを比較した。
N07はfrontendを開いた後でも全device一覧が124秒で停止し、正確な所有UDID内へ一回spawnしたSwift実プロセスの
実環境UDID/ProcessInfo OS版/Simulator compile target/正のpidを照合する代替証明が両OSで成功していた。
今回は元10秒の任意diagnosticを必須gateへ再利用してしまい、その失敗済みAPIへの依存を再導入した点が不十分だった。
候補は共通frontendを保持し、boot前に選択SDKで専用の小さなSwift実行器を所有一時領域へcompile、bootstatus/画面URL後に
一回だけ対象UDIDへspawnして同じ独立identityを照合する。起動証明の全45秒を保持し、無応答/不一致/期限超過は失敗。
追加boot/launch/入力再送・host環境のUDID注入・debugger変更・UI期待/期限/全15gateの変更は行わない。
全device診断は失敗時の任意診断だけに戻し、一覧timeoutの握り潰しや一律成功へ置換しない。
旧成功と今回のUI準備を同一原因の確定とせず、helper/Python拒否条件/実Swift host対照を局所検証し、push済み候補に
新規reviewを毎回受けて元の限定3経路を確認する。前候補の失敗は残す。

候補a5fc1d0を先にpush後、Linux/Swift6.1.2の局所検査は観測18件/失敗0（5.109秒）、共通実shell2件/失敗0
（7.101秒）、manual5件/失敗0（10.552秒）、Picker1宣言/元8入力/失敗0（9.999秒）、App16件/失敗0
（53.694秒）、manifest30件/失敗0（20.532秒）。Bash構文・一覧453登録・check --base6aaも通過した。
実Swift host対照はIDらしい環境変数があってもsimulatorCompileTarget=falseを返し、起動証明を拒否する。
所有端末一回spawn・元45秒の境界・異なるID/OS/host/bad PID/不正/過大/失敗応答とcompile/sign/boot/window失敗も拒否した。
これらのfake/host成功を実Simulator UIの成功としない。完全code-only差分770行/48569bytesのSHA256は
53c94e6f7d0884ad53cb5df17f5909e6f4ecf332186608043b8d61a3096ee4a9。限定3実行に各新規reviewを消費する。

## N201 Native identity候補の通常26限定がfailure（2026-11-06）

sourcebfb7e734be04505865357545b97e0620c2e0edcc/run42309825003/attempt1/job128208213124、
SDK27.1・予定Runtime26.5・testChangedAccountDataNoticeOpensSharedAcquisition、23:08:29Z〜23:19:21Z。
23:30Z一括照会でfailureを確認。本文未読で準備/実UIの段階・原因は未確定。対処前に記録する。

## N202 同じ候補のPicker27限定もfailure（2026-11-06）

同source/run42309932187/attempt1/job128208575394、SDK27.1・予定Runtime27.0、23:09:25Z〜23:17:12Z。
本文未読で段階・原因は未確定。Portable Swift/Python jobはsuccess、非選択native/inventoryはskip。
別run42309711437/job128207837577の手動3項目27は23:26:06Zにsuccess。成功を他経路へ代用しない。
新5完了logを一回取得し、過去/現コードを照合してから次の対処を選ぶ。まだ全体公開CIは開始しない。

N201実log：build95.3秒、identity compile/sign成功3.7秒、bootstatus132.7秒/終了0の後、
画面URLを開き、readiness-enterから2.9秒でunconfirmed/終了1。45秒の時間切れではないが、
現在の起動証明は不受理理由を記録しておらず、spawn終了値/応答不一致のどちらかは未確定。実UIは未開始。
N202はbuild31.6秒/identity compile3.8秒/sign成功/boot129.0秒後、readiness-enterから54.2秒でunconfirmed。
45秒超過を拒否した事実だけが分かり、下位原因は未確定。元Picker3ケースは未開始。
同sourceの手動27ではidentity compile3.7秒・boot135.2秒後に所有native proofが8.2秒で成立し、
元3項目・全ACK・4番目拒否・採用/保存/再起動を含む591.888秒/失敗0、outer1093.9秒/元1800秒内で通過した。
全3run終端・artifact0・新5log一回取得済み。起動証明の一般的成功やN193の恒常的解消とは主張しない。

N201/N202追加照合：N07/起動停止/bootstatus/Shutdownと当時のcompare.py・現在のnative proofを再読した。
旧通常26 A成功128121440677、N198、新N201/N202、今回手動成功はいずれも同じhost macOS27.0.1/
xcode-27-arm64 image20261104.0337.1で、image更新の有無では分けられない。
N201はData Migration中のElapsed03:09からterminal/Elapsed00:00へ変わり、後続healthがRuntime available/
device Shutdownを実観測した。status4294967295自体は旧成功でも出ており、単独でエラーと解釈しない。
N202はbootstatusがDevice already bootedと返った後で別のnative probeが期限超過した。
次は振る舞いを推測変更せず、拒否したnative応答の終了値/期限/一致項目と、失敗時だけ正確な所有UUIDに
絞ったhost CoreSimulator/DeviceHubのread-only boot記録を有限・固定語彙で採取する診断候補とする。
45秒の起動証明・一回boot/spawn・UI期待・元job予算を保持し、待機延長や押し直しで救済しない。
新しい観測で失敗理由を区別するための限定26/Picker27とし、前の成功した手動ケースを再試行しない。

診断候補b84a038を先にpush後、観測19件/失敗0（1.282秒）、実helper2件/失敗0（4.347秒）、
通常App実runner16件/失敗0（44.591秒）、一覧453/write/check --base6aa・Bash構文が通過した。
実host対照、拒否条件/元45秒、失敗時だけの一回read-only host log、対象外端末・不正/過大応答・私的文字列の除外を保持する。
manual/Picker runner・native Swift本体・UI case・成功時の操作順はbfbで検査済みの同一bytesで、不要な全体再検査はしない。
完全code-only差分871行/55222bytesのSHA256は18970e51afd3042534a1bddd96531581b086cbabc6bec49f5793dfea8581372d。
短い実例一覧は13箇条のまま、重複する手順説明をN07の具体的な一覧停止の教訓に置き換えた。

## N203 診断追加e010のPicker27限定がfailure（2026-11-06）

sourcee010fa18d1efdb8b8c72bd096f0189cf5392c9f5/run42313146360/attempt1/job128219223789、
SDK27.1・予定Runtime27.0、23:37:33Z〜23:52:31Z。23:58Z一括照会でfailureを確認。
本文未読で準備/実UIのどちらか・下位原因は未確定。Swift/Python jobはsuccess、非選択2jobはskip。
同sourceの通常26先頭case/run42313011415/job128218771457は23:48:09Zにsuccess。
新4完了logを一度取得し、過去と現コードを照合してから対処を選ぶ。限定成功を全15へ代用しない。

N203実log：同じSDK/Runtime27.0のnative identityは全一致で成立。元3ケース中2成功/1失敗、
testReselectionThroughActualButtonsが395.228秒、MaterialPickerTapChecks.swift:147の
`buttons.allElementsBoundByIndex` でFailed to get matching snapshot/UI query timeout。
t328.60のCollectionView snapshot要求後に約66秒停止し、次の実button tapへ未到達。
他2ケース95.381秒/39.819秒は成功した。boot問題の再発や製品Picker表示失敗とは断定しない。
通常26は元先頭ケース27.959秒/失敗0、全native proof一致、outer563.9秒、所有回収/export完了。
全2run終端・artifact0・新4log一度取得済み。根拠を比較してから次の候補を選ぶ。

N203照合：MaterialPickerTapChecks/testReselectionThroughActualButtons/choose-2/Picker/再照会で
N74/N83/N94/N97/N140/N148と3762d38・711d48b・現Picker/Navigation/Inputを読んだ。
今回はHome→activate/foreground後の最後のchoose-2で、index列挙から対象buttonを解決しようとして
t225→258→289と約31秒ずつ再解決し、snapshotが止まった。前の10回の実選択/Cancelは成立していた。
N83は実hittable再照会、N140はCancel接触時の再解決で、今回は画面外候補を含むindex列挙の段階。
旧3762の一意button/枠/viewport再利用は保持されているが、revealの2箇所はなおindex-boundだった。
現在Cancel/手動最終接触では既にallElementsBoundByAccessibilityElementを使い、実nativeを一度取得している。
候補はPickerのこの2列挙だけを同方式へ揃え、当試行のnative identityを枠/hittable/直後の一回tapへ保持する。
対象ID/一意性/元8探索/逆方向の事前移動/30・30・10・最後5秒/全包含/hittable/元11回の選択とCancel/
案内8秒/Cancel30秒/全3ケースを保持する。製品・SDK・bootstrap・各期限を変えず、AXの一般的改善とは断定しない。
既存3実UIケースが今回の背景復帰を含み検出済みで、実装を写す新しい文字列テストは増やさない。
先に候補と根拠をpushし、Picker実runner/manifest/幾何/一覧を局所確認、新規review後にPickerだけ限定検証する。

N203候補fa9b00cの局所結果：Picker実runner1宣言/元8入力/失敗0（5.549秒）、manifest30件/失敗0
（19.239秒）、一覧453/check --base6aaが通過。幾何の計算/完全包含/上限は差分0と確認した。
この一回専用の新規GPT-6.1 Sol/High picker_native_elements_pre_actions_reviewは完全code-only差分893行/
56511bytes/SHA256 d255157e16c9c0d1e857b25548519cbac1a1cbae2463c8df340483c64980e07fを確認し、
意図外の実装・検査弱体化のblocking指摘なし。その一回の開始にだけ消費した。
run42315603061/attempt1は実3jobが全success、非選択2jobはskip、保存artifact0。新3完了logは一度取得済み。
SDK27.1/実Runtime27.0でnative proof全一致、元Picker3件/失敗0・430.855秒、連続ケース294.048秒で
元11回の実選択/Cancel・背景復帰を通過し、遷移確認もPASSだった。Portable Swift603件/失敗0、
Python306件/予定skip22/失敗0も通過。旧snapshot停止の恒常的解消とは主張せず、正式全15の成功へ加算しない。
次は同じcode-only差分へ別の新規mainレビューを受け、元の全15gateを同一source/run/attemptで確認する。

## N204 正式2b89の原本変更拒否27がfailure（2026-11-07）

source2b89c38d99c0011ce1680bce7db1a751fc165d89/run42318063090/attempt1/job128236331110、
SDK27.1・予定Runtime27.0・testChangedOriginalCannotSubmitOrReplaceLastGood、00:27:14Z〜00:34:58Z。
01:25Zの予定一括照会でfailureを確認。本文未読で準備/実UIの段階・原因は未確定。対処前に記録する。
通常27 A/B・Native/Distribution・他手動27の3件はsuccess。26 A128248923119（01:05:52Z開始）、
B128248049294（01:03:08Z開始）は進行中で取消さない。手動26は依存skipで成功に数えない。
新8完了logだけを一度取得して過去/現コードを照合する。元の全15・公開はまだ成立していない。

N204実log：build64.9秒・identity compile/sign2.5秒は成功。bootstatus105.8秒/終了0の後、所有画面URLも開いたが、
native proofはexit-1/deadlineExceeded=true/errorWords=timeoutで不成立。続く所有UUID限定host logも10秒でtimeout。
UI/XCTestへ未到達で、原本変更拒否のassertが失敗したわけではない。outer443.2秒/元2400秒内で終了1、所有回収は完了した。
同sourceの他3手動27は実484.913秒/713.750秒/977.185秒で成功。Native701/予定skip1/失敗0はSDK26.5のみ。
新8logを一度保存し、残26 A/Bの進行とartifact未確認を保持する。現在の失敗はN199の一覧APIではなく対象native spawnのtimeout。

N204照合：boot/timeout/競合/DeviceHubでN07/N53/N182/N199/N202を検索し、旧1186de3のPickerと
現共通helper/各runnerを比較した。N53ではSimulator起動とSwift buildの重なりを除く準備比較が成功しており、
現runnerは既にbuild-before-bootなのでそこを往復しない。一方、共通helperはVM bootを開始してから
重いDeviceHub初期起動を行い、二つの初期化を重ねている。N204ではHub初期起動44.9秒、bootstatus105.8秒の
already booted後にもnative45秒とhost log10秒が応答しなかった。CPU/OS停止の具体的な下位原因は未確定。
新候補はDeviceHubの初回openを所有VMの一回bootより先へ移し、初期化の重なりを除く比較に限定する。
既存Simulator.appはCurrentDeviceUDIDを渡す従来順を保持し、Hubも所有画面URLはbootstatus後の一回を保持する。
native proof45秒・元bootstatus・全UI期待/入力・全体予算・所有cleanupを保ち、再boot/再入力/期限延長で救済しない。
初期化競合が原因とは先取りせず、候補と根拠push後に実shell/全caller/manifest/一覧を局所確認し、
全callerのローカル検査後、新規reviewを受けて元の失敗27ケースを限定比較する。
過去の3経路限定確認は実施済みで、今回は同一host APIの二段階の順序だけが変更点。
実装を変えていない通常/Pickerの限定を毎回反復せず、両OSの全経路は次の正式全15で改めて要求する。
旧26 A/Bは取消さず、実開始から約50分の01:55Zに新限定とまとめて確認する。

## N205 正式2b89の通常26 Bがfailure（2026-11-07）

source2b89c38d99c0011ce1680bce7db1a751fc165d89/run42318063090/attempt1/job128248049294、
SDK27.1・予定Runtime26.5、01:03:08Z〜01:37:47Z。01:55Z一括照会でfailureを確認。
本文未読で具体ケース・段階・原因は未確定。26 A128248923119は01:47:07Zにsuccessで終端した。
これで全job終端、実行10件中8成功/2失敗、手動26/公開は依存skip。新2logだけを一度取得する。

## N206 DeviceHub先行候補の同じ原本変更拒否27限定がfailure（2026-11-07）

sourced10979187195f6e6ce9d763d3a0866d83bf9fa7a/run42324452193/attempt1/job128256391580、
SDK27.1・予定Runtime27.0、testChangedOriginalCannotSubmitOrReplaceLastGood、01:30:49Z〜01:39:32Z。
本文未読で準備/実UIの段階・原因は未確定。対処前に記録した。新logを一度取得し、過去/現コードを照合する。

N205実log：build110.1秒、boot470.4秒・全native identity一致後、元通常B先頭の
testChangedAccountDataNoticeOpensSharedAcquisitionがApplicationChecks.swift:120のUI snapshot timeoutで126.579秒/失敗。
後続の同phase5ケースは成功した。実UIの段階で、今回のboot proof timeoutとは区別する。26 Aは全元操作/通知に成功。
N206実log：Hubを先に開く操作は0.4秒で成功し、その後のboot呼出しが61.6秒、bootstatus137.8秒。
所有画面URL後のnative proofは45秒でtimeout/exit-1/deadlineExceeded、host log10秒もtimeoutで全UI未開始。
先行起動だけでは無応答を解消せず、初期化競合を原因と断定しない。元条件の盲目的再実行はしない。
全2run終端・新3logを一度取得・artifact0を確認済み。正式12の全10実行logは揃い、以後再照会しない。

N205/N206照合：Xcode/SDK/27.2/DEVELOPER_DIRで索引とci-toolchain-update-20261026を検索し、
N07/N53/N127/N182/N204と現prepare/runner/launchReady（120行）を比較した。
通常26の停止はSpringBoard foregroundと一回app.launchを通過した後のfixture-ready全画面snapshotで、他5ケースは成立。
起動順の先行化はnative応答を改善しなかったため、helperと対応order検査を正式2b89の順序へ戻す。
利用者提示の搭載一覧を一度取得するとimageの既定も27.1/27A9275で、SDK選択不一致の証拠はない。
同一覧の27.2 RC/27B48は旧source2562772/run40357278572でNative688/予定skip1/失敗0・元Picker3件/失敗0を
実比較済みだった（旧終端runは再照会しない）。今回の完全なアプリ/訂正の成功を保証するものではない。
利用者のSDK更新指示に沿い、Runtime26.5/27.0と全操作/期待/期限/boot proofを固定し、27.2 RCで二つの失敗経路を比較する。
手動限定workflowに既定27.1を保持した明示sdk27選択だけを追加し、不明SDKを拒否する。通常26は既存probeのsdk26=27.2を使う。
配布workflowはまだ27.1を保持し、比較成功後にだけ全15を27.2で検証する候補へ進む。製品・API・入力・再送・期限は変更しない。

## N207 SDK27.2の通常26先頭ケース限定がfailure（2026-11-07）

sourcee68fde9b7415ee63a32f0e1686f5bf96bcb7eb01/run42327110829/attempt1/job128264829052、
SDK27.2・予定Runtime26.5・testChangedAccountDataNoticeOpensSharedAcquisition、02:01:41Z〜02:13:00Z。
02:30Z一括照会でfailureを確認。本文未読で段階・原因は未確定。対処前に記録した。

## N208 同SDKのPicker27限定もfailure（2026-11-07）

同source/run42327206199/attempt1/job128265140716、SDK27.2・予定Runtime27.0、02:02:49Z〜02:12:10Z。
本文未読で準備/実UI・原因は未確定。同runのNative26.6/27.2・portable/Pythonはsuccess。
別run42327013991/job128264532386の原本変更拒否27は02:11:30Zにsuccess。新7完了logだけを一度取得し照合する。

N207はbuild79.3秒/boot80.1秒/画面URL後、native45秒でtimeout・全UI未開始。
N208はbuild35.9秒/boot200.2秒/画面URL後のnative応答exit0が期限後でdeadlineExceeded=trueとして拒否された。
元Picker3ケースは未開始であり、27.2のPicker操作のassert失敗ではない。host logも10秒でtimeout。
同SDKの原本変更拒否27は225.896秒/失敗0、全native identity一致・outer635.1秒で元全条件を通過した。
Nativeは実SDK26.5と27.2で各701件/予定skip1/失敗0（119.237/114.846秒）。Portable603/0、Python306/予定skip22/0。
全3run終端・新7log一度取得・artifact0確認済み。SDK更新だけで起動の無応答を解消したとは言わない。

N207/N208照合：N07/N53/N182/N193と正式b965の手動27全4成功、当時6aaのmanual/Picker runner、
現bootstrapを比較した。手動/Pickerは元々GUIホストを開かずにXCTestで実UIを操作していた。
GUIが起動原因との証明はなく、追加したDeviceHub起動/所有画面URLも現在のCLI停止を解消していない。
次の比較はCLIで所有VMを起動し、その実native証明後にXCTestへ画面操作を委ねるheadless modeとする。
従来GUI modeとその失敗検査は既定のまま保持し、限定3workflowだけにheadlessを明示する。
SDK27.2/Runtime26.5・27.0、native45秒、一回boot/probe、元UI全case/実操作/画像/保存/再起動/期限は変更しない。
GUI不在を無条件成功とせず、応答不成立や実UI不成立は失敗にする。未知modeも準備前に拒否する。
製品/配布workflowは変更せず、候補push→実shell/全caller/manifest/一覧→各新規review→限定3経路の順で確認する。

headless候補98f8401を先にpush後、実helper3件/失敗0（9.038秒）、App実runner17件/失敗0（53.825秒）、
manual5件/失敗0（10.001秒）、Picker1宣言/元8入力/失敗0（8.999秒）、manifest30件/失敗0（20.747秒）を確認。
未知modeでコマンド未実行、GUIなしの実shellでもcompile/sign/boot/bootstatus/identity不成立を拒否し、
Appの両OSで元Aの全caseとcontent_size実コマンド/所有回収が残ることを確認した。GUI枝の元検査も保持した。
一覧453/write/check --base2b89とBash構文も通過。実UIはまだ未確認で、限定3経路の実操作を要求する。
完全code-only差分228行/14466bytesのSHA256はd7c38c0081fd810dcd7061cb6844388f52e415bdd1f132a20cdd1eb29d3f30d2。

## N209 headless SDK27.2の原本変更拒否27限定がfailure（2026-11-07）

source6b0d3a04c607a8cf7641db796d243af51c45b3c4/run42330153297/attempt1/job128274584220、
SDK27.2・予定Runtime27.0・testChangedOriginalCannotSubmitOrReplaceLastGood、02:37:24Z〜02:48:38Z。
03:00Z一括照会でfailureを確認。本文未読で準備/実UIの段階・原因は未確定。対処前に記録した。

## N210 同headlessの通常26先頭ケースもfailure（2026-11-07）

同source/run42330227842/attempt1/job128274825457、SDK27.2・予定Runtime26.5・
testChangedAccountDataNoticeOpensSharedAcquisition、02:38:19Z〜02:47:40Z。本文未読で段階・原因未確定。
Picker27/run42330298101/job128275053125とportable/Pythonはsuccess。新5完了logを一度取得し過去/現コードを照合する。

N209はbuild108.1秒/boot225.9秒後の別nativeプロセスが45秒でtimeout、N210もbuild57.7秒/boot53.4秒後の
同プロセスでtimeoutした。両方ともXCTest/実UI未開始。GUI不在だけでは独立プロセスの停止は解消しない。
Pickerはheadlessで全native identity一致後、元3件74.274/193.535/25.814秒で全成功・遷移確認も成功。
実画素はlight255/255/255、dark28/28/30で、空の黒画像ではなく元の背景一致を確認した。
全3run終端・新5log一度取得・artifact0。元のUI failureと新しい事前チェックの停止を区別して保持する。

N209/N210照合：N07/N182/N193/N204〜N208と元6aa runner、現在のnative proofを比較した。
元の全15は実XCTest/実操作/厳密完了を要求しており、追加の別nativeプロセスは公開条件には元々無かった。
今回追加した45秒の独立spawnがUI開始を阻んでおり、元UIの失敗を観測する前に止める別の停止要因になっている。
次は証明を削除せず、実際に各UI caseを実行するSimulator内のUITest Runner自身から実UDID/OS/
Simulator compile条件/正のPIDを記録する。hostは選択済みUUID/Runtime・元case数と照合してから成功を受理する。
期待IDをguestへ注入せず、実行ごとの証明を要求するため、事前一回だけの証明より実テスト対象に結びつく。
独立した事前spawn/compileは不要にし、実UIの45秒等の元期限・case・実操作・全体予算は変更しない。
Runner内のidentity読み取り自体も単調clockで元45秒以内に限定し、時間切れならUI bodyへ進まずsetUp失敗とする。
GUI/headlessの表示準備と実bootstatusは保持し、UI不可/証明欠落・重複・異なる端末/OS/hostは失敗のまま。
候補/根拠を先にpushし、実Swift host拒否/strictログ検査/全runner/manifest/一覧を局所確認してから新規reviewで限定検証する。

候補aad1a49/b74da66/4306b40を各変更前提とともに先にpush後、実Swift host拒否とidentity厳格検査3件/失敗0
（最終2.086秒）、実boot/helper3件/失敗0（2.701秒）、App18件/失敗0（50.023秒）、manual6件/失敗0
（8.946秒）、Picker1宣言/元8+証明欠落の9入力/失敗0（8.135秒）、manifest30件/失敗0（21.179秒）、
manual project17件/失敗0（1.986秒）、観測16件/失敗0（0.442秒）、source paths3件/失敗0（0.004秒）が通過。
元のcompletion拒否入力はすべて保持し、正対照だけに新しい実Runner証明のschemaを追加した。
GUI/boot/window失敗の伝播と所有回収、Appの全phase/OS文字サイズ、manual/Pickerの全case照合を保持する。
一覧454/write/check --base2b89と4scriptのBash構文も成功。実Apple Runnerの証明は次の限定3経路で確認する。
完全code-only差分1060行/64012bytes/SHA256 a3a0ad21e1c1f7fce38477b7ca6625c83dc11ac5be83a6e428bcecb3588f7e9f。

## N211 実Runner証明候補の限定3経路がfailure（2026-11-07）

source d47a30071d7a132d623dfcf778f7b2381648a5a3・SDK27.2・headless・各attempt1。
03:50Zの一括照会で以下のfailureを確認。本文未読で失敗段階・原因は未確定。対処案の決定前に事実を記録する。
- manual27.0/run42333824290/job128286129823/testChangedOriginalCannotSubmitOrReplaceLastGood、03:23:59〜03:35:46Z。
- App26.5/run42333955054/job128286534880/testChangedAccountDataNoticeOpensSharedAcquisition、03:25:37〜03:34:56Z。
- Picker27.0/run42334076283/job128286927612/元3case、03:27:16〜03:37:26Z。
同Picker実行のportable128286927265とPython128286927436はsuccess。全3run終端。新5logを一度だけ確認する。

新5logとartifact0を各一度取得。manual元case234.630秒/失敗0、App元case20.481秒/失敗0、
Picker元3case355.746秒/失敗0。Picker実画素はlight255/255/255、dark28/28/30で元条件一致。
各Runnerの実UDID・OS・Simulator条件・正のPIDは所有対象と一致したが、
XCTestCase.nameは`-[ApplicationChecks test…]`等のmodule無し、xcodebuildのcompletionは
`-[PickerTapChecks.ApplicationChecks test…]`で、名前の前提の違いをstrict host照合が拒否した。
実UI失敗ではない。検索語`identity|XCTestCase.name|名前|native proof`でN199〜N210と
現在のSupport/host検証・d47版を照合。過去の独立probe停止とは異なり、今回は全実UIまで実行済み。
次はhost条件を緩めず、Runnerの実class型のreflectionからmoduleを取り、実XCTest名のclass一致を
確認して完全名へ正規化する。期待module/selectorをguestへ渡さず、実class/nameだけから生成する。
実Swiftでmodule無しnameからの正規化と異なるclass名の拒否を確認し、同じ限定3経路で再確認する。

dcb2013を先にpush後、実Swift正規化・別class名拒否・host拒否を含む3件/失敗0（2.540秒）、
一覧454/check --base d47a300が成功。3経路の実操作・実OS/UUIDは上記logで成立済みのため、
共通name変換の再確認はPicker27の元3caseへ絞り、全経路の再実行は正式全15で行う。
今回の実SDK27.2（27B52）とRuntime26.5/27.0の比較結果を踏まえ、配布/通常/手動/ビルドの
SDKを27.2、AppleのUI実行だけheadlessへ揃える候補へ進む。Native26.6/実SDK26.5とLinuxの環境を維持。
任意manual26 probeにも27.2比較を追加し、27.1/26.6の旧条件を保持する。未知SDK拒否は維持する。
host証明条件・元case/期限/期待・全15必須は変更せず、限定成功を正式ゲートへ合算しない。
この候補/根拠を先にpushし、SDK選択/全元ゲート/環境の分離をローカル検査した後、新規reviewで限定実行する。

d3e70d7を先にpush後、manifestの30件を失敗0で確認（通常27件5.163秒、Swift不在でskipした3件は
Swiftを有効にして2件9.404秒＋1件2.036秒で別途成功）。source paths3件/失敗0（0.003秒）、
一覧454/check --base2b89も成功。元8手動・4通常UIの全15ゲートと、Linuxへheadless環境を漏らさない条件を維持。
短い実例一覧は13項目/19行を維持し、今回のmodule名の教訓を既存identity項目に追記した。
完全code-only差分1302行/76496bytes/SHA256 594050beacea37d38a23b665939ae7bbe4ac61c586fa1fd12f0715f7498e9876。

## N212 正式13のiOS26で通常A/Bと手動3件がfailure（2026-11-07）

source a8b71315090b56da1d33eb5318fc264392cb7465/run42337449457/attempt1、SDK27.2・予定Runtime26.5・headless。
05:45Z一括照会で以下を確認。本文未読でケース内の失敗段階・原因は未確定。対処案を決める前の観測記録。
- 通常26B/job128306010183、04:51:08〜05:28:13Z、failure。
- 通常26A/job128308828884、05:04:14〜05:17:48Z、failure。
- 手動26One/job128308828903、05:04:14〜05:15:22Z、failure。
- 手動26Selected/job128308828922、05:15:25〜05:28:42Z、failure。
- 手動26Changed/job128308828938、05:04:15〜05:18:27Z、failure。
手動26Three/job128308828910はsuccess（05:04:14〜05:23:48Z）。27の通常A/Bと手動4件、配布検査、Nativeは全成功。
公開job128314268003は依存skipで未公開。全run終端。新26側6logだけを一度取得し、成功や旧logは再照会しない。

新6log/artifact0を一度取得。実Runnerのcase/UUID/26.5/Simulator条件/PIDは各caseで成立し、N211の形式差は解消。
26Aは補助資料case163.969秒で成功後の行除外case、手動One/Selected/Changedは起動後に
device Shutdown/runtime null/supportedArches空となり、`cannot determine the runtime bundle`で終了65。
Oneのxcresultはsignal term、cleanupもdevice not booted。3項目26は全実操作/保存/再起動を成功した。
exportは最後のcleanupまで保持済み。26Aは23F73、One/成功Threeは23F77で、build番号だけでは成功を区別できない。
26Bは先行のAI Switch4回を実UI/保存/setterで成功後、独立通知caseの最初のONが150.827秒で失敗。
実native枠(300,177.333,63,28)、state0、一回0.1秒接触は実UISwitch/_UILiquidLensViewへbeganで到達したが、
0.135秒後にcancelled、UILongPress state1、native値0のまま。Binding/認可要求は未開始、元45秒内のONは不成立。
今回初めて失敗接触の配送取消を観測できた。単なるtap返却を成功扱いしない。

検索語runtime bundle/not booted/export/phase=cancelled/UILongPressとN166/N176/N177/N184、U55/U64/N180/N192、
当時031916/2b89のrunnerと現在a8の準備/共通Switchを照合。旧bundle欠損はGUI共通化前にも発生し、
export保持だけではN184で再発済み。GUI有り正式12の26Aは全成功・26Bは別のfixture snapshot timeoutで、
今回headless正式13の4VMは実起動後にRuntimeを失った。GUI未接続が原因と断定せず、26だけ所有画面を開く比較を行う。
27のheadless/配布SDK27.2/実26.5/一回boot/厳密実Runner証明/元case/全15/元期限は維持し、別native事前probeは戻さない。
Switchは現在の同じnative identity/点/元状態照合を保持し、強制0.1秒pressだけを通常coordinate.tap一回へ変更する。
U64の旧tap失敗は同時のnative配送証拠が無く、現在はbinding済みnative要素へのpress取消を実観測した点が異なる。
全5callerへ共通適用し、元UI/保存/再起動の条件と45秒・許可一回を維持。入力再送や期待値/許可の注入はしない。
候補/根拠を先にpush後、局所契約/一覧と新規reviewを経て通知26と明示選択訂正26を各一回比較する。

01daa73を先にpush後、manifest30件/失敗0（20.300秒）、実GUI/headless bootstrap3件/失敗0（2.507秒）、
Swift構文と一覧454/check --base a8b7131が成功。元一回操作・全包含/状態照合・45秒と保存検査は維持。
共通Switchを使う両OSを確認するため、通知caseは同一dispatchで26/27各一回、訂正Selectedは26一回に絞る。
完全code-only差分113行/6314bytes/SHA256 da40dd5abac8e4534ed0ffac024e4b94c90bf165c9adce32ce358f3d1db38f40。

## N213 正式14の通常26A・明示選択訂正26がfailure（2026-11-07）

source ea8a4b2229d18f4daf54dd69f15f56792a08e9a5/run42351129878/attempt1、SDK27.2・予定Runtime26.5・GUI。
08:55Z一括照会で通常26A/job128346877924（08:00:54〜08:40:16Z）、手動Selected26/job128348435315
（08:08:00〜08:35:26Z）のfailureを確認。本文未読で失敗stage/原因は未確定。対処案の決定前の観測記録。
通常26Bと手動26One/Three/Changed、27通常A/B・手動4件、配布/Nativeはsuccess。公開job128358524690は依存skip。
全18表示job終端・実14件（成功12/失敗2）で未公開。新26側6logとartifact一覧だけを一度取得する。

新6log/artifact0を一度取得。通常26Bは元全case/通知/OS文字サイズ3段階を成功し、通知の通常tapもUI/保存1で成立。
通常26Aは先頭testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecoverのタブ移動中、
indexed calendar Imageのexists/frame再解決（t181.94）で約274秒途切れ、Runnerが再起動。残17件は成功したが先頭は成功しない。
手動Selected26は実3項目の入力/ACK後、visible()のCollectionView再照会（t404.30）で約320秒途切れ、
Runner再起動・xcresult signal term、所有deviceはnot booted。XCTest assertionによる拒否やN212の通知取消とは違う。
GUI付きでも再起動があり、Runtime lifetime解消は断定しない。CoreSimulatorの下位原因は未確定。

検索語calendar/index/frame/CollectionView/再照会でN78/N80/N165/N168/N203と当時/現Navigationを比較した。
PickerでN203を対処済みのnative accessibility identity方式が、共通tabのImageには未適用だった。
tabは同じbar/button/iconのframeを包含検査と診断printで何度も読み、manual visibleは同一試行のlist.frameを
viewport/受動行anchor/gestureで重ねていた。今回止まった実API呼出しと一致する。OS/SDKの推測変更は行わない。
候補は現在の一意なbar/button/iconとRecovery Listをaccessibility identityで取得し、各試行のframeを一度だけ保持する。
manualのList identity/frameはスクロール後の次試行で取り直す。元の存在/一意/完全包含/enabled/hittable、
native中心への一回操作、16探索/一度反転、45秒と全入力/ACK/保存/再起動、全15を保持する。
元のAuxiliaryReadとSelectedのUI caseが実移動/保持/再起動の失敗を検出できるため、模倣UIテストは足さない。
既存geometry/manifest/project検査を確認し、同じ失敗ケースを実26/27の限定で通す。候補/根拠を先にpushする。

## N214 N213候補のローカルproject契約が旧frame式を要求（2026-11-07）

source741228f/Linux、manual project17件中1失敗（0.911秒）、test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps:317。
旧`list.frame.minX`の式を要求しており、新しい同試行の`listFrame.minX`保持を未反映。Actionsは未開始。
manifest30件/失敗0（17.132秒）、Swift scroll2宣言/実29件/失敗0（2.652秒）、Swift構文と一覧454は成功。
対処前に記録。旧期待の目的は受動行の実midXからList原点を引くことで、固定gutterへの接触を拒否すること。
式の意味は変えず、実List.frameを一度だけ保持し、元のmidX/原点差と一意なnative Listを使う条件へ契約を更新する。
旧式と新しいcached式の両方でgutter固定を拒否する。geometryの元29動作検査と実UIで包含/反転/実接触を確認する。

9897c14を先にpush後、manual project17件/失敗0（0.713秒）、一覧454/check --base ea8a4b2が成功。
N213候補のmanifest30件・scroll実29件とSwift構文も上記通過済み。実AX応答は未確認で、
次の限定AuxiliaryRead両OSとSelected26では元case/実入力/全包含/保存/再起動/期限・厳密完了をそのまま要求する。

## N215 正式15の手動Selected27・One27がfailure（2026-11-07）

source eb6af3857ffa96b36f978fd7752d679638c22470/run42360753022/attempt1、SDK27.2・予定Runtime27.0・headless。
10:36Z一括照会でSelected27/job128368789370（09:42:40〜09:49:09Z）とOne27/job128368789414
（09:42:40〜09:49:50Z）のfailureを確認。本文未読で失敗段階/原因は未確定。対処案の決定前に記録。
27通常A/B・Three/Changed・Native・配布はsuccess。26通常A/Bは継続中で取り消さず残結果も確認する。
手動26は依存skipで成功扱いしない。新しい完了7logだけ取得し、既読配布logは再取得しない。

新7logを一度取得。Selected27は29.733秒、One27は36.348秒、両方とも最初の時間割ファイル画面への移動後に
viewport=(0,177,0,0)として即座にinvalid-viewportとなり、訂正本文へ未到達。成功Three/Changedは同じ起動経路を通過した。
失敗後の実treeには現在のCollectionView(0,0,393,852)と詳細Buttonがあり、消失/Runtime再起動ではない。
N213のframe保持を非Recoveryのindexed firstMatchへも適用したため、遷移中の一時的なzeroを固定してしまった。
Recoveryだけにnative bindingを入れた不足がある。検索語invalid-viewport/zero frame/CollectionViewと旧ea8/新eb6の
visible/tap/launchを照合。N213の数分停止とも通知取消とも段階が異なる。元tapには画面準備の待機がなく、同じframeを読み直していた。
候補は非Recoveryも現在の一意なnative Listへbindする。存在0や未確定geometryの観測は元16試行の中で次の観測へ進み、
その間にtap/dragは送らない。複数List/Recovery消失は拒否し、実際に有限なviewportとhittable対象が得られるまで操作しない。
各試行のframe一回、元16の総上限/一回反転/一回接触/45秒/保存・再起動・全15を維持。新しい待機時間や入力の再送は足さない。
OneとSelectedの元caseを両OSで限定確認する。旧26通常A/Bは取消さず、新限定とまとめて終端を確認する。

698c8b0を先にpush後、manual project17件/失敗0（0.706秒）、manifest30件/失敗0（16.445秒）、
Swift構文と一覧454/check --base eb6af38が成功。元caseとgeometry検査は実入力/曖昧性/有限枠の拒否を維持。
新しい待機秒数は追加せず、zero geometryの観測も元16試行を消費し、validになるまで一切入力しない。
完全code-only差分60行/4156bytes/SHA256 807d1ca61d74367c64734a05e216b8f071c6006517d57c1410ac5dda0d03117b。

## N216 N215限定のOne両OSとSelected26がfailure（2026-11-07）

source640b7bac6910c950fe3a59e51777926496405853・SDK27.2・各attempt1。
11:35Z一括照会でOne27/run42365107534/job128381409658（10:42:51〜10:51:40Z）、
One26/同run/job128381409868（10:42:50〜10:56:06Z）、Selected26/run42365175339/job128381615557
（10:43:51〜10:57:45Z）のfailureを確認。本文未読で段階/原因は未確定。対処案選択前に記録。
Selected27/job128381615819は10:51:44〜11:28:02Zでsuccess。新4logだけ一度取得する。

## N217 旧正式15の通常26Aが約60分でcancelled（2026-11-07）

sourceeb6af38/run42360753022/attempt1/job128376918468、SDK27.2/予定26.5/GUI、10:21:33〜11:22:24Z。
11:35Z照会でcancelled終端を確認。主担当はcancelを発行していない。job60分上限との関係と段階は本文未読で未確定。
旧26B/job128377992172は11:06:57Z success。旧正式15は全表示job終端・公開は依存skipで未公開。
旧既読8logは取り直さず、新26側2logとartifact一覧だけ一度取得する。

新6logと3runのartifact0を一度取得。N216 One27は35.100秒、通常時間割詳細画面に入った直後、
全画面CollectionViewが複数としてNavigation:38で拒否した。先行の時間割ファイル/詳細Buttonへの実tapは成功。
One26はRuntime bundle null/device not booted、Selected26はRunner通信前に120秒boot待ちがtimeout、
cleanupはSystem match policyでruntime profile not found。GUI有りでもRuntime lifetimeを保証できない。
Selected27は元全操作/保存/再起動を1425.925秒で成功。N215のzero geometryは再発しないが、全画面List数だけでは現在の操作先を決められない。
過去成功One27/Selected26の保存logでは通常画面4操作の実Buttonはすべてviewport内にあり、現在の目的Buttonを含むListへ絞れる。
Recoveryの専用IDと元の一意/有限枠/完全包含/hittableは維持し、全Listから任意のfirstMatchは選ばない。

N217の通常26Aは元18件を成功後、最後の独立通知Runnerでアプリlaunch/automation session中にjob上限で取消された。
本体44分＋準備/2台目boot等で60分へ達しており、通知の成功へ読み替えない。26Bは全元case/通知/3段階文字サイズまで成功。
実測のA重いSpecialRecoveryは371.113秒、BのChangedAccountDataNoticeは短い20秒級。
元case・件数・期限・全15を保ったまま、この2件の所属だけA/Bで交換し、Aの予算へ約6分の余裕を作る。
27側の直近A34分/B44分にも照らし、Bへの増分約3分は元60分内の比較とする。上限は延長しない。

runtime bundle/System matchでN166/N176/N177/N184/N212と現在のSDK準備を照合。
保存済みRunner搭載一覧のsystem defaultはXcode27.1だが、現在workflowはDEVELOPER_DIRで27.2を指定するだけだった。
CLIの環境指定はGUI/launchdのsystem選択一致を証明しない。差が今回の直接原因とは未確定だが、
標準的なCIセットアップとして、準備/Runtime登録より前に選択Xcodeをsystem側にも一回設定し、
DEVELOPER_DIRを外したxcode-selectの実パスを正規化して一致を要求する。実際の前後を固定形式で記録する。
対象はdisposable macOS Actionsだけに限定し、UI入力/許可/OS/Runtime/device/再boot/試行数は変えない。
候補/根拠を先にpushし、fake CLIで一回設定/不一致・失敗・非CI拒否と全caller接続を確認する。
新しい同一sourceでOne/Selected両OSを確認し、残っていた旧3runは全終端/全新log/artifact0取得済みとして再照会しない。

751164aを先にpush後、system Xcode selectorの実Python/fakeCLI4件/失敗0（1.226秒）、
manual project17件/失敗0（0.844秒）、manifest30件/失敗0（19.096秒）、App実shell18件/失敗0
（46.002秒）、source paths3件/失敗0（0.003秒）、Swift構文と一覧456/write/check --base eb6af38が成功。
selectorはCI以外/不正pathで設定前に拒否し、一回設定・環境overrideを外した実選択照合・alias正規化・失敗/不一致拒否を確認。
12個の配布/限定UI・ビルドcallerがRuntime準備前に接続し、Linux/旧Nativeのjobは維持することも確認した。
全元caseの一回所属/元phase完了/3段階文字サイズ/通知/厳密identityと全15gateは既存検査で維持した。
完全code-only差分411行/22009bytes/SHA256 9761aa3479c6e2cc5f01bd92965d7d7d76f7c259439095e2429bb338718f3d48。

## N218 N216限定のSelected26がfailure（2026-11-07）

source1f64b7bda7f74a3667ce26186ee03136b1e9ee63/run42370269712/attempt1/job128396762834、
SDK27.2・予定Runtime26.5・GUI、11:56:17〜12:09:47Z、12:35Z一括照会でfailureを確認。
本文未読で失敗段階/原因は未確定。対処案を選ぶ前に記録。Selected27/job128396762951は12:30:06Z success。
同sourceのOne26/27（run42370148012/jobs128396403035/128396403120）も12:15:00/12:17:41Z success。
全2run終端。新4logと各artifact一覧だけを一度取得し、過去の完了実行は再照会しない。

新4logを一度取得、各artifact0。全jobでsystem Xcode27.1→27.2の一致を確認したが、Selected26は
12:06:04Zにcase開始、12:06:06Zに実Runner26.5/Simulator/PIDを証明後、12:09:36Z頃に
Runtime bundle null/device Shutdownとなった。画面assertionではなく、直接の原因は未確定。
同sourceのOne26は23F77を取得して成功、Selected26は23F73を取得して失敗した。
検索語buildVersion/23F73/23F77/runtime bundleでN166/N176/N177/N184/N212/N216と旧prepare26を照合。
同じmarketing指定26.5がRCと正式版の両方を取得していた。過去23F77にも失敗があり、唯一の原因とは断定しない。
Apple公開Simulator catalogueを一度取得し、iOS26.5 arm64の正式23F77とRC23F73を確認した。
catalogue SHA256=10c77d82b1d1af2690027bfd0cccba5edf8a4dfd1c0ba786836586b8074f11e8。
GitHub lawkitt/mdoc issue654の実例も、marketing指定ではRC、build番号指定では正式版となる技術的根拠として照合した。
候補は元26.5/SDK27.2を維持し、downloadを正式build23F77/arm64へ固定、登録JSONでも一意なbuild一致を要求する。
不一致・欠落・重複は失敗にし、削除/再install/別minorへのfallbackはしない。export保持と所有回収、全入力/期限/全15は維持。
候補と根拠を先にpushし、fake CLIで正常登録/一回download・import/誤build/欠落/重複拒否と回収を検証する。
限定は元4手動caseを26で各freshVMで確認し、成功後に同一source/run/attemptの全15正式検証へ進む。

48f50b6を先にpush後、Runtime準備4宣言/失敗0（5.282秒、26の11経路を含む）、
元manifest30件/失敗0（Swift有効、16.734秒）、一覧456/check --base eb6af38が成功。
正式buildの一回取得/arm64・保持・後片付け、誤build/欠落/重複の拒否を実helper/fakeCLIで確認。
実Simulatorの安定性は未確認。code-only差分528行/29814bytes、SHA256
4c20a59ba47706ba0f5558d8c1ff7c591c0fae94e05058edcedd21737371cca5。

## N219 ローカルmanifest検査のファイル名誤指定（2026-11-07）

source48f50b6/Linux、test_ui_manifest.pyを指定して0件・exit5。Actions未開始、コード不具合ではない。
実在するtest_ui_test_manifest.pyを一覧から確認して実行し、上記30件の成功を得た。実装・期待値の変更なし。

## N220 正式build固定のSelected26がfailure（2026-11-07）

sourceb677db517f8f34518fb903e06b17771db898aec4/run42374327682/attempt1、SDK27.2・予定26.5正式23F77/GUI。
13:08:35Z一括照会でSelected/job128408714153は12:51:40〜13:02:43Z failure、
Changed/job128408714251は13:04:17Z success。One/Threeは継続中で取り消さず確認する。
本文未読で失敗段階/原因は未確定。対処案の選択前に記録し、新しい完了2logだけ一度取得する。

新2logを一度取得。Selectedも23F77/SDK27.2/system選択一致、build成功、bootstatus終了後に
Runner channel disconnectedとなり実case未開始。cleanupはRuntime unavailable/System match policy。
Changedは元case189.728秒/失敗0と厳密実Runner証明を成功。正式build固定だけでは解消しない。
検索語runtime profile/simdiskimaged/cryptexとN166/N176/N177/N184/N212/N216、旧/現prepare26を照合。
公開upstream actions/runner-images issue14946の10/29・11/2コメントを確認した。MobileAssetの重複登録後の
cleanupがiOS Runtimeをforce-unmountし、boot済みguestを落とす事例と、exportedBundleを一回importして
CoreSimulator/Cryptex/Imagesへ登録すると重複しなくなった実例がある。自環境の直接原因の証明とは区別する。
現helperはdownloadが自動登録したらimportを省略し、*.dmgのみをimport対象としていた。
今回の実取得物は*.exportedBundleであり、upstreamの安定登録経路を通っていない点が一致する。
候補は新しく自分がdownload/exportした26.5/23F77だけ、一意なexportedBundle（または旧dmg）から
一回importする。既存の不明/利用不能Runtimeを消去・置換しない。取得・importの再試行は足さず、
元SDK/OS/入力/boot/期限/全15とexport保持を維持。準備前後のread-only runtime image一覧も記録する。
実helper/fakeCLIで自動登録後も所有exportをimportする正例と複数/欠落/symlink/エラー拒否を確認し、
元Selected26と残ケースを再確認する。候補/根拠を先にpushしてから局所検査・新規reviewへ進む。

a4faa25を先にpush後、Runtime準備4宣言/失敗0（6.371秒、26の14経路）、manifest30件/失敗0
（Swift有効、16.968秒）、一覧456/write/check --base eb6af38が成功。実helperは自動登録後も一回importし、
exportedBundle/dmgの正例、複数/欠落/symlink・取得/import失敗・誤build/欠落/重複の拒否と所有回収を検証した。
元Runtime安定性は未確認。code-only差分562行/32350bytes、SHA256
3f72595050f9960e865902af12ae2e0c74880a749dd7d273978458399c9f1dbb。
限定は直前に失敗した元Selected26一件に絞り、One/Threeの旧実行も取消さず終端を確認する。

## N221 同じ旧build固定限定のOne26もfailure（2026-11-07）

sourceb677db5/run42374327682/attempt1/job128408714226、SDK27.2/26.5正式23F77/GUI。
13:30Z一括照会で12:51:40〜13:18:45Z failure。本文未読で段階/原因は未確定として対処前に記録。
Three/job128408714008は13:11:47Z success。全4job終端、新2logとartifact一覧だけ一度取得し、既読2logは取得しない。
exportedBundle import候補974ba9c/run42376089239/job128413854900は13:15:07Z開始、準備を通過し元UIを実行中。

新2log/artifact0を一度取得。Threeは354.411秒/失敗0、Changedとともに実26.5/UUID/Simulator/PID・元入力を成功。
Oneは実case/identityと訂正/ACK/表示サイズ変更まで進み、223秒のRecovery List.exists後に約6分応答が途切れ、
Runnerが再起動、case完了なし/exit65。cleanupはdevice not booted/Bad or unknown session、アプリcrash報告0。
Runtime bundle nullの明示はなく、AX応答停止とguest終了の因果は未確定。元ケース成功へ読み替えない。
新import候補にUI探索/入力の変更を追加せず、Selectedの実結果と登録情報を待つ。

## N222 owned exportedBundle import候補のSelected26がfailure（2026-11-07）

source974ba9c9b8dda9e9479f4c858439678e68c9c7a3/run42376089239/attempt1/job128413854900、
SDK27.2・予定26.5正式23F77/GUI、13:15:07〜13:30:16Z failureを予定13:52Z照会で確認。
本文未読で失敗段階/原因は未確定として、対処案を選ぶ前に記録。全job終端、新1log/artifact一覧のみ一度取得する。

新log/artifact0を一度取得。import自体は成功したが、直後の実image一覧には同じ23F77/26.5が2登録あった。
local Cryptex/Imagesの7CEB8950…はReady、今回downloadしたMobileAssetのCE547B96…はUnusable/Cryptex Mount Preferred。
前者を使う実Runner identity後、app launch/automation開始で応答が途切れ、Runner再起動/完了なし/exit65。
cleanupはdevice not booted/Bad or unknown session。upstream14946の重複cleanupと整合する登録は初めて実確認したが、
force-unmountのhost logは未取得であり、直接の因果は未確定。importだけで重複除去を保証していなかった。
同upstreamの登録方式と前後の実JSON、N176/N177/N220と旧/現helperを照合した。
次はdownload前のimage UUIDとasset directory、download直後の新しい26.5/23F77 MobileAsset UUIDを保持する。
import後のlocal Ready一件を確認し、同じpath/buildの今回作成されたUnusable/Cryptex Mount Preferred一件だけ、
boot前にsimctl runtime deleteの正規APIで回収する。既存UUID/asset・別OS・未知の重複・Readyは削除しない。
回収後に同じlocal Readyだけであることを再確認し、不一致/失敗/新たな重複は拒否、再試行しない。
元SDK/Runtime/全入力/一回boot/期限/全15を維持する。所有外を保全するfake CLIの正負ケースを追加し、候補/根拠を先にpushする。

be720feを先にpush後、実Runtime helper/fakeCLI4宣言/失敗0（11.854秒、26の25経路）、
元manifest30件/失敗0（Swift有効、18.803秒）、一覧456/write/check --base eb6af38が成功。
削除対象は新しい取得UUID一件だけ。既存image/UUID、別OS、未知重複、Ready、非deletable、誤local path、
local複数を拒否し、削除失敗・消えない重複は再試行せず失敗となる。所有exportの保持/回収も維持。
実Simulatorの結果は未確認。code-only差分650行/38903bytes、SHA256
9e39b22feeeea101c434815481cf06672b144af987c91ff56ee889494ef1628b。

## N223 所有重複回収候補のSelected26がfailure（2026-11-07）

source8cc49a850ad1a3c8f5940c9076bbc3f4d54a6389/run42379446719/attempt1/job128423782953、
SDK27.2・予定26.5正式23F77/GUI。13:59:28〜14:01:31Z failureを予定14:16Z照会で確認。
本文未読で失敗段階/原因は未確定、対処前に記録。全job終端、新1log/artifact一覧だけ一度取得する。

新log/artifact0を一度取得。download/importと所有判定は成功し、所有Unusable UUID543E8035…への
正規deleteだけがexit30で終了した。nativeは「Removed the runtime, but did not reclaim its MobileAsset」
と正確な今回asset pathを報告し、scan-and-mountで再登録して再度deleteするよう明示した。UI/bootは未実行。
検索語exit30/code30/scan-and-mountと既往N170の限定exit149、旧974ba9c/現helperを照合。
exit30の初出で、一般的な削除失敗と同じ成功へ読み替えない。元case/期限/全15は変更しない。
次は正確なnative domain/code30/今回asset path/復旧指示が揃う部分削除だけ、local Ready保全と旧UUID消失を
確認して一回scan-and-mountを行う。同じ自分のassetの新UUIDを再照合し一回回収する。
第二delete失敗、別asset/既存UUID/Ready/未知重複やscan失敗は拒否し、loopしない。
最終imageが同じlocal Readyのみ、かつowned AssetDataが残らないことを要求する。一般的なエラー30を無視しない。
これは起動前のApple APIが指定した限定復旧であり、UIの入力/起動/失敗caseを再試行するものではない。
候補と根拠を先にpush後、部分削除の正例と誤message/path・復旧失敗のfakeCLIを検証する。

e86c4b0を先にpush後、実helper/fakeCLI4宣言/失敗0（16.206秒、26の32経路）、
元manifest30件/失敗0（Swift有効、18.405秒）、一覧456/write/check --base eb6af38が成功。
特定exit30のみ一回scan/同じowned assetの新UUIDへ一回delete、誤message/path・local消失・scan失敗・
別asset・第二delete失敗は停止することを確認。通常errorは従来どおり失敗にする。
実Apple復旧は未確認。code-only差分706行/43502bytes、SHA256
36b4ac9dbfda99447d1946767e1c4a6efd606d7b4b0d062c8609804e95ca9848。

## N224 限定部分削除復旧のSelected26がfailure（2026-11-07）

source1b4645bc5e54067088b907888b14807003458012/run42381222834/attempt1/job128429056334、
SDK27.2・予定26.5正式23F77/GUI。14:21:36〜14:24:01Z failureを予定14:28Z照会で確認。
本文未読で段階/原因は未確定、対処前に記録。新1log/artifact一覧だけ一度取得する。

新log/artifact0を一度取得。正確なexit30を認識し、local Ready保全と旧UUID消失を確認、scanは成功した。
直後の実image一覧には同じlocal Readyのみで、再登録候補0のため準備を拒否した。UI/bootは未実行。
fakeはscan直後に新UUIDが必ず一件現れると想定していたが、実APIはその同期完了を保証していない。
その時点のAssetData実在は未記録で、既に回収されたのか、scanの非同期反映前かは未確定。
scan/非同期/完了で索引と旧/現helperを照合。最終契約（同じlocal Readyのみ・owned AssetData不在）は維持し、
候補0かつAssetData不在なら追加deleteせず完了、存在する間だけ最大30秒でread-only登録状態を観測する。
scanの再発行・別UUIDの推測・UIの再試行は行わず、未知重複/Ready消失/期限切れは拒否する。
fakeには既に回収済みと遅れて一件登録される両方を加え、OSの存在照会とCLIを独立して制御する。
候補/根拠を先にpush後に局所検査、新規reviewを経る。既読run/logは再照会しない。

5568d90を先にpush後、実helper/fakeCLI4宣言/失敗0（72.921秒、26の35経路、実30秒の期限切れも含む）、
元manifest30件/失敗0（Swift有効、18.697秒）、一覧456/write/check --base eb6af38が成功。
CLI登録とOSのAssetData存在を別々に制御し、既に回収済みでは第二deleteなし、遅延登録では正確な新UUIDへ一回、
登録されないままAssetDataが残る場合は30秒で失敗となることを確認。最終の同じReady/AssetData不在は維持。
実Appleの状態は未確認。code-only差分744行/46032bytes、SHA256
5391df8ad0cc871ba9dd03fee2d23cb67b8e65d96cce5d64f56c1f9d57fcc5a5。

## N225 非同期回収観測候補のSelected26がfailure（2026-11-07）

sourceff352dcc319513da8490f9774e4a1f9d26590c34/run42382152651/attempt1/job128431850046、
SDK27.2・予定26.5正式23F77/GUI。14:33:30〜14:36:30Z failureを予定14:40Z照会で確認。
本文未読で段階/原因は未確定、対処前に記録。新1log/artifact一覧のみ一度取得する。

新log/artifact0を一度取得。AssetDataは実在したまま、scan後約6秒で新MobileAsset UUID BA9411C1…がReady、
同じlocal UUID DA664E7B…がUnusable/Cryptex Mount Preferredへ切り替わり、local Ready不変の仮定で拒否した。
UI/bootは未実行。N224の非同期は実確認できたが、fakeの「local Readyが単調に維持される」という仮定も実APIと違った。
今回/前回JSONとnativeの指定手順を照合。Readyは登録・mountの状態であり、guestの使用中を意味しない。
次は正確なexit30後の一回scanに限り、同じlocal UUID/path/buildを保持した既知のCryptex優先切替を観測する。
回収対象は以前からの登録には広げず、今回の同じassetの新UUIDだけ。いずれのRuntimeにも起動中/不明状態のdeviceが
ないことをread-onlyで確認後、一回だけ指定deleteする。元のinitial削除ではReadyを引き続き拒否する。
最終の同じlocal Ready一件・owned AssetData不在、全元UI/SDK/OS/期限/全15は変えない。
fakeに実際のReady/Unusable切替とBooted/不明device拒否を追加し、候補/根拠を先にpushする。

f832cc9を先にpush後、実helper/fakeCLI4宣言/失敗0（67.606秒、26の40経路）、
元manifest30件/失敗0（Swift有効、19.642秒）、一覧456/write/check --base eb6af38が成功。
nativeで観測したReady/Unusable優先切替後に同じowned assetだけ一回回収し、local Ready復帰を確認する正例と、
initial/復旧のBooted・不明状態・別OSのBooted拒否を確認。全元UIと最終Ready一件/AssetData不在は維持。
実Appleの最終回収は未確認。code-only差分772行/48188bytes、SHA256
dda32a14b0307ce438118cbc48a9a38726d65173750c7152e3e5bf486118cd96。

## N226 実優先切替対応のSelected26がfailure（2026-11-07）

source6debe1a436af849ee13714cae49c187acb8c530a/run42383114750/attempt1/job128434744051、
SDK27.2・予定26.5正式23F77/GUI。14:45:55〜14:49:02Z failureを予定14:52Z照会で確認。
本文未読で段階/原因は未確定、対処前に記録。新1log/artifact一覧だけ一度取得する。

新log/artifact0を一度取得。起動deviceなしと同じowned assetの新Ready UUID ED29A55A…を実照合し、
第二deleteまで進んだが、同じnative部分削除exit30となった。再試行せず停止し、UI/bootは未実行。
N223〜N225とupstream14946の「別環境でexport後、MobileAssetのない環境へimport」の順序を再照合した。
現処理は取得とimportを同じ環境で先に行い、二重登録を作ってから回収していた。これがreclaim失敗の直接原因とは未確定。
次は一意なportable exportを保持したまま、今回新規取得した未使用のMobileAssetを先に正規APIで回収する。
全device Shutdown・同じasset/UUID/build/path・既存にないことを確認する。必要な特定exit30の一回scan/第二deleteは
同じ所有guardで維持するが、この段階ではimported localはまだ作らない。target登録0とowned AssetData不在を必須にする。
その後にowned exportを一回だけimportし、一意なlocal Ready/正式buildとAssetData不在を最終確認する。
SDK/OS/UI/boot/期限/全15は変えず、回収失敗を成功へ読み替えない。fakeも取得→所有回収→一回importの実順序を検証する。
native削除失敗時だけ、該当asset hash/purge/reclaimに絞ったhost logを最大15秒・表示32KiBで記録する。
このread-only診断の失敗はunknownとして示し、回収の成功条件には使わない。
候補/根拠を先にpushし、局所検査と新規reviewの後だけ次の限定を開始する。

e1acaf6を先にpush後、実helper/fakeCLI4宣言/失敗0（63.843秒、26の40経路）、manifest30件/失敗0
（Swift有効、18.083秒）、一覧456/write/check --base eb6af38が成功。portable exportの保持・元asset回収後の
一回import、すべてのdeleteがimportより前であることと、以前の所有/SDK/build/復旧期限/負対照を確認した。
診断追加19efa26も先にpush後にhelper全4宣言を再実行し、失敗0（62.105秒）。診断の失敗は回収結果を変更しない。
実Appleの回収は未確認。最終code-only差分795行/49164bytes、SHA256
f701489e8cbf02a0568bf4337001fc18667696934deba39769339fc97646f13d。

## N227 import前回収候補のSelected26がfailure（2026-11-07）

source2212c34fbca491be8f2daf30e4e59a7520d0d3fd/run42384545059/attempt1/job128439060270、
SDK27.2・予定26.5正式23F77/GUI。15:04:05〜15:06:09Z failureを予定15:10Z照会で確認。
本文未読で段階/原因は未確定、対処前に記録。新1log/artifact一覧だけ一度取得する。

新log/artifact0を一度取得。import前の最初のdeleteもnative部分削除exit30だった。host診断は取得成功し、
今回assetの新規download/moveを確認したが、直接のpurge失敗理由は記録されておらず、権限問題とは断定しない。
scan後約15秒で現れた新UUID1FCF9541…は同じ26.5/23F77/arm64、Ready、signature Verifiedだったが、
pathは同じowned AssetData/Restore/094-56039-099.dmg、parentMountPathは元AssetData、parentIdentifierは新UUID。
元AssetData直下のpath完全一致だけを許したため拒否し、第二delete/import/UI/bootには未到達。
N224〜N226/今回JSONとnativeの再登録指示を照合。復旧登録が同じ取得物内のVerified restore imageへ変わることを実確認した。
次はこの復旧分岐に限り、同じowned AssetDataのRestore直下・既知形式dmg名・正確な元pathのparentMountPath・
新しい有効parent UUID・Verified/arm64/exact buildが揃う子imageも認める。元の新規asset/UUID所有確認、
全device Shutdown、第二delete一回、target登録0/AssetData不在後の一回importと最終Ready/全15は維持する。
別asset/既存parent/未検証署名/別arch/相対pathは拒否するfakeを追加し、候補/根拠を先にpushする。

0b68a5cを先にpush後、実helper/fakeCLI4宣言/失敗0（68.233秒、26の46経路）、
元manifest30件/失敗0（Swift有効、17.578秒）、一覧456/write/check --base eb6af38が成功。
同じowned restore childの正例と別asset/既存parent/未検証署名/別arch/path traversal拒否を確認した。
native診断にはsimctl clientとinfo/debugも含め、回収エラーに近い末尾32KiBを保持する。15秒と受理条件は維持。
この診断出力だけの追記は回収制御・テスト期待を変えず、次の実Apple試行で観測する。

9a9bc33/run42385700552/attempt1/job128442498153は15:18:08〜15:45:28Zでsuccess。
元Selected26が813.534秒/失敗0、全元入力/ACK/4件拒否/採用/保存/再起動と厳密case完了・実Runner証明を成功。
準備ではowned MobileAsset回収後のtarget登録0、続く一回importのlocal Ready/23F77を実確認した。
system Xcode27.1→27.2も一致。新log一度/artifact0一度を取得し、終端runを再照会しない。
一件成功を恒常的解消へ一般化せず、同じ最終codeの正式全15へ進む。

## N228 ローカル再監査でGitHubの時刻prefix付きlogを生のidentity validatorへ渡した（2026-11-07）

source9a9bc33/run42385700552/attempt1/Linuxでの保持log再監査、validate_execution_identities:217がidentity件数で拒否。
実CIは生XCTest logに対する厳密照合を成功済みで、実case成功を失敗へ読み替えない。対処前に記録。
公開job logの各行にはGitHub時刻prefixがあり、validatorは行頭の固定identityを照合する。
私有監査入力だけでGitHubの固定時刻prefixを除いて同じvalidatorへ渡す。製品/CI validator・件数・期待は変更しない。

私有再監査で固定prefixを除き、hostのbootstatus UUIDと同じvalidatorで厳密identity照合を成功した。
保持log SHA256=68025d0ca01b3bd6e552c072c7bfa7a53b7af8287d14637cb00ef0be6ca4c9ca。
今回のtarget登録0→一回importのlocal Ready23F77と実全入力/保存/再起動を確認。main base eb6af38も変更なし。
正式main用の新規Sol/High n227_shipping_pre_actions_reviewは完全code-only821行/51291bytesを確認し指摘なし。
最終hash2202526550076f9013892d70bdbcd992ff47790386d6d5eb51a4e31f8dcffa56の同一性と
実Selected成功・未送信commitの空白を主担当が確認後、正常fast-forward main一回へ消費する。正式全15は別にすべて要求する。

## N229 正式16のDistributionがfailure（2026-11-07）

source19eaf591146f3e0a480519db7ee8faf19ebf8e00/run42388447778/attempt1/job128450727082、Linux。
15:52:08〜15:55:44Z failureを予定15:56Z照会で確認。本文未読で失敗case/stage/原因は未確定、対処前に記録。
依存の全Mac/公開はskipで成功扱いしない。全表示job終端、新1log/artifact一覧だけ一度取得する。

新log/artifact0を一度取得。314件/失敗11/予定skip22（206.882秒）、すべて
test_application_ui_runner.test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtimeの26 subcaseだった。
既存installed fakeにbuildversionがなく、runtime image照会へも従来のruntimes配列を返してAttributeError。
download期待もmarketing26.5・自動登録時のimport省略のままで、実helperの新契約に追従していなかった。
N178/N214のmock契約不一致と旧/現helper・workflow抽出を照合し、prepare-ios26/27/download/importをtests全体で検索した。
ここは実比較workflowのshellを実行する別のintegration fakeで、前回の関連検査確認から漏れていた。
実production/helper/元UI/gateを変更せず、このfakeを実JSON二種類・23F77/arm64・owned asset削除後の一回importへ合わせる。
元27件の正負対照と5秒上限・always回収を維持し、誤SDK/OS/取得/import/利用不能/誤buildの拒否も保つ。
候補を隔離featureへ先にpushし、関連shell検査と全Pythonを確認した後、新規main専用reviewを経て正式17へ進む。
実Runtime codeは変えないため、既に通ったSelected26を同じ条件で再dispatchせず、次の正式全15で再検証する。

b44773eを先にpush後、Swift6.1.2有効の全Python314件は失敗0・skip2（204.164秒）。
別callerの全28 preflight対照、実shell各shard/失敗/重複/identity拒否、Runtime準備46経路を同じ全体で確認した。
一覧456/write/check --base 19eaf59も成功。短い注意点は13項目・19行を維持し、全caller/mock検索と非同期実状態確認を既存項目へ追記した。
新規main専用Sol/High n229_shipping_pre_actions_reviewはコード差分108行/7515bytesを確認、指摘なし。
code-only hash96f97915608924266818677fe433399c068db460dee9029076283d01e6619cddと
実Runtime/production/UI code不変・main base19eaf59・全未送信commit空白を確認後、一回の正式17 mainへ消費する。

## N230 正式17の通常26 Bがfailure（2026-11-07）

source9ea1de5d49c8243e4ffa7857514c73c888263caf/run42389595709/attempt1/job128463209912、iOS26/SDK27.2。
16:42:23〜17:26:44Z failureを予定17:41Z照会で確認。ログ本文未読のためcase・失敗段階・原因は未確定。対処前に観測を記録する。
他13検査はsuccess、公開は依存skip。全表示job終端。新しい6実行logとartifact一覧・run情報だけ一度取得し、旧logを再取得しない。

新6log/artifact0/run情報を一度取得。通常26Bは先行全phase成功後、独立通知caseが131.909秒で失敗。
Notifications.swift:129の試験・返却ONを元10秒内に観測できなかった。初回の時間割変更ONは実Allow/authorization2/保存1まで成功。
次の試験・返却も同じnative controlの一回tap、began→ended（約0.060秒）、on-bindingとauth callbackまで実記録がある。
N212のcancelled/Binding未到達とは異なり、今回はcallbackのgranted/error、実specials/savedSpecials/permissionMessageは未採取。
通常26Aと手動26全4件も成功し、Runtime消失は観測していない。この失敗を接触取消やRuntime問題と断定しない。

検索語NotificationControls/試験・返却/auth-callback/10秒、N122/N159/N212/U37/U64の詳細と当時a8b7131/現9eaの通知・共通Switchを照合。
製品setEnabledはvalue=trueで実OS認可を要求してから保存する。元caseは初回だけ詳細state/画面を採り、二つ目の10秒失敗はその観測がない。
次は診断のみ：二つ目も同じ一回tap・同じ10秒で実native値を要求し、失敗時だけ実probe/画面を記録して明示失敗する。
使い捨てfixtureは実callbackのerror/granted/denied固定stageと実permissionMessageも観測する。OS応答・保存値は変更しない。
製品/接触点/許可操作/待機/元case/保存と再起動/全15は維持。この新観測条件を先に隔離featureへpushし、既存の可逆instrumentation/manifest/runner検査後、新規reviewで通知caseを26/27各一回比較する。

候補498e75fを先にpush後、既存manifest30件/失敗0（17.130秒）と実shell runner18件/失敗0（46.362秒）、Swift構文/catalog456は成功。
全collector検索でtest-app-ui.shの固定stage許可にも新しい三結果の登録が必要と確認し、その正例を既存の本文/大容量/symlink拒否ケースへ追加する。
callback windowの解析器は既存request/returned/callbackだけを時刻窓へ使うため、新結果を完了の代用へ加えない。採取内容だけを更新し、元の失敗判定を保持する。

c3ddd7eを先にpush後、最終manifest30件/失敗0（16.953秒）、実shell runner18件/失敗0（47.427秒）、Swift構文・shell構文・catalog456/check --base9eaは成功。
可逆instrumentation/元caseと全15/collectorの既知stage・本文/大容量/symlink拒否を既存ケースで確認し、期待を写す重複テストを増やしていない。
新規GPT-6.1 Sol/High n230_pre_actions_reviewは完全code-only85行/7384bytesを確認し、指摘なし。
SHA256=388deae90279494f9a5070f298bb75e822c195027204890585d23e8b00f2c0b7。主担当が最終差分同一性・局所成功・未送信commit空白を照合し、
このreviewを次の通知Controls/iOS26+27/SDK27.2限定dispatch一回だけへ使用する。正式mainには別の新規reviewと全15成功を要求する。

## N231 通知の新観測比較で27がfailure（2026-11-07）

source3f756ca33c79ae0a46dcb7dd0376c5fad1932e1f/run42397980393/attempt1/job128479375801、iOS27/SDK27.2。
17:46:51〜18:00:01Z failureを予定18:03Z照会で確認。本文未読で失敗case内の段階・原因は未確定、対処前に記録する。
同じ比較の26/job128479375638は17:46:51〜17:59:38Z success。全二job終端、新二log/artifact一覧だけを一度取得する。

新二log/artifact0を一度取得。26は196.987秒/失敗0、元の両ON/外観/保存/再起動と実Runner証明が成功。二つの認可callbackは実grantedだった。
27は138.536秒、112行の最初の変更通知ON・元45秒で失敗。実Switch操作後requesting=trueのまま、Allow操作なし、値0/保存false。
アプリ/システム画像は同じSHA256 da4feeca5cc6803ab2af019e63b093bb5a3ae6f81271c0413d87a886964de1bd、許可画面へ進んだ証拠はない。
実Runnerは27.0.0/Simulator/所有UUIDを記録。終了時Runtime available/device Bootedだが、guest launchctl/logとapp-container取得はすべてtimeoutし、
native journal・実OS callback結果を採取できなかった。N230の二つ目のcallback到達後とは異なる段階。OS内部の下位原因は未確定。

検索語requesting=true/初回未返答/callbackなし/host/headless27、U21/U22/U24/U36/U37と当時fd6e42c/現3fの通知実装・traceを照合。
旧GUIやSDK切替でも未返答があり、今回27は同じheadless/27.2の正式17では成功しているため、その切替を根拠なく繰り返さない。
現在の失敗診断はguest経由で、host側の所有UUIDに絞った既存collect_boot_failureをこのUI失敗時に呼んでいない。
次はその既存の10秒/2MiB/固定語彙/同じ所有UUIDだけのhostログを、failure cleanupのguest照会より先に一回採取する。
成功経路・製品・許可と一回tap/元45秒・全期待/15gateは変更しない。この新観測条件を先にpushし、実runner/既存host診断検査・新規review後、未解決の27だけ比較する。

## N232 N231候補のローカル実shell検査が非0（2026-11-07）

source25bd5c230d0d43b276160972fe7fe5e493e55420、Linux/Swift6.1.2、unittest test_application_ui_runner.py、session26867がexit1。
ケース/失敗段階は保持log本文を読む前で未確定。Actionsは開始していない。対処前の事実記録とし、保持logを調べる。

18件中の最終通知失敗case・26/27両subcaseで期待46に対して実1。9ea/現25bdのcheck_uiと既存fail_tests対照を読むと、
元runnerはxcodebuildの任意非0を明示exit1へ正規化しており、新assertだけが子コマンド46を外側の契約と誤認していた。
実1という失敗契約を厳密に確認し、元の非0要求を緩めない。製品/runnerの終了値は変更しない。
併せてcheck_uiはEXIT cleanupの前にも一回guest初期化logを取ることを確認。新しい順序assertが求めるhost先行にはcleanupだけの追加では不足する。
host採取を一回だけの共通helperにし、check_uiのguest直前とcleanup入口から呼ぶ。同じ失敗で重複採取せず、元のguest採取/回収を保持する。
未消費n231 reviewは最終差分が変わるため無効化し、候補/根拠を先にpush後、同じ実shell/host検査と新規reviewで評価する。

6c7e23aを先にpush後、実shell runner18件/失敗0（54.421秒）、既存host/通知trace16件/失敗0（0.231秒）、catalog456/check --base9ea・Bash構文は成功。
元子失敗→外側1、host一度/guestより前/元5実行/回収、hostの所有UUID・固定語彙・上限/失敗時unknownを確認した。
先行N230コードの全Python314件/失敗0・skip2（196.509秒、Swift6.1.2有効）も保持するが、新helperは今回の実runner/host検査で別に評価した。
新規GPT-6.1 Sol/High n232_pre_actions_reviewは最終code-only156行/11463bytes、SHA256 fefcc85dc0e1aaede21b0bd970c44f047d0c62995b40f8c1321f467ef213e2a9を確認し指摘なし。
主担当が同一性/局所結果/未送信空白を確認してから、このreviewを未解決Controls27/SDK27.2の限定dispatch一回だけへ使用する。26の成功を再実行せず、限定結果を正式全15へ流用しない。

最終ced2df0の全Python314件は失敗0・skip2（210.948秒、Swift6.1.2有効）。
Controls27/run42399887550/attempt1/job128485181090は18:09:58〜18:21:37Z success、元case259.103秒/失敗0。
実27.0.0/Simulator/所有UUIDに一致するRunner証明、元一回操作・実Allow/両認可granted・両ON・外観/保存/再起動と厳密完了が成立した。
新log/artifact0を一度取得し、終端を再照会しない。今回旧停止は再現せず、失敗専用host観測は作動していないため低位原因や恒常解消は断定しない。
先行26成功のUI/製品/成功経路と現在は同一codeで、追加したhost採取は失敗時だけ。限定成功を正式へ合算せず、最終mainの同じsource/run/attempt全15を別途要求する。
18:24Zにremote main9ea1de5不変を一度確認。main用の新規code-only reviewを経て通常fast-forwardの正式18へ進む。

新規main専用GPT-6.1 Sol/High n232_shipping_pre_actions_reviewは完全code-only156行/11463bytesを確認し指摘なし。
SHA256 fefcc85dc0e1aaede21b0bd970c44f047d0c62995b40f8c1321f467ef213e2a9の同一性、製品/正式workflow/manifest不変、
限定27成功・local全Python/関連検査・main9ea不変・全未送信commitの空白を主担当が確認した後、一回のmain pushへ消費する。

## N233 正式18の手動3項目27がfailure（2026-11-07）

source65f268dc933bce725fb747a27ee281eb9a43b0e3/run42401227517/attempt1/job128490320374、SDK27.2/予定Runtime27.0。
18:38:59〜18:54:31Z failureを予定19:25Z照会で確認。本文未読でcase内の失敗段階・原因は未確定。対処前の事実記録。
配布/Native/通常27A+B/他の手動27三件はsuccess。通常26A/Bは19:02:01/19:11:28Zから継続中、手動26は依存skip。
残りを中止せず、今回新しい7終端Mac logだけを一度取得する。artifact一覧は全job終端後まで取得しない。

新7logを一度取得。Native701/予定skip1/失敗0、通常27 A基本18件＋通知・B全phase/OS文字サイズと残手動3件は成功。
手動Three27は502.315秒でNavigation.swift:73のUI query timeout。3本文入力/各ACK/submit=trueとreview=true/lastgood保持まで成功後、
manual-review-headerはvirtualizedで未表示。受動Cellから元の一回下方drag後、t274.14の全アプリAny descendants一致ID配列で約222秒止まった。
実入力/採用結果の不一致、Runtime消失や許可停止とは異なり、採用/正式保存/再起動へは未到達。

検索語ManualAssistanceChecks/Navigation.swift:73/manual-review-header/descendants/UI query、N91/N94/N97/N203の詳細と
1b368f5/9cd340e/fa9b00c/現65fのNavigation・requireReview・fixture ID生成を照合。N91ではclearだけを同List/Buttonへ、
N97ではACKを同List/Switchとし、外側の論理IDをviewport観測後に解決して内側だけ接触identityへ固定していた。
今回の見出し・比較・状態Textには全app/Any検索が残っていた。PickerのN203とは場所が違い、外側を一律identityへ戻すとN97を再導入するため行わない。
全visible callerのknownID/fixture生成を検索し、既知のText7種はすべて復旧List内の実Textと確認した。
候補は復旧中の検索を同じListへ限定し、この既知Text群をstaticTextsへ絞る。clear/ACKは既存のButton/Switch、他は同List/Anyを維持し、editor型を推測固定しない。
外側のindex-bound論理ID・viewport先行/即frame観測と内側の実接触identity・一意性/完全包含・受動Cell・元16試行/一回reverse/gesture/全期限・全4caseと全15gateは保持する。
既存の元Three caseが今回を直接検出済みで、同じ元caseを両OSで先に比較する。条件を写す新テストを増やさず、既存幾何/生成契約/runner/manifestを実行する。
候補と根拠を隔離featureへ先にpushし、局所検査/新規review後に限定dispatchする。稼働中の正式18の通常26二件は中止しない。

31fb986を先にpush後、生成契約17件/失敗0（0.757秒）、スクロール2宣言/内部29幾何例/失敗0（3.472秒）、
実manual runner6件/失敗0（5.618秒）、manifest30件/失敗0（17.418秒）、Swift構文/catalog456/check --base65fは成功。
短い実例一覧は13項目/19行を維持し、既存の全画面検索の項目に実List/型の教訓を追記した。
新規GPT-6.1 Sol/High n233_pre_actions_reviewはcode-only26行/2027bytes、SHA256 e54c27655f58ac35edbc59bfd281bd596ccb76147691d2f8ac5bc98fa87576b7を確認し指摘なし。
主担当が同一性/局所結果/未送信空白を確認し、このreviewを元Three/両OS/SDK27.2限定dispatch一回へ消費する。

51ab481の全Python314件は失敗0・skip2（198.717秒、Swift6.1.2有効）。
元Three/両OS run42406420860/attempt1は両job success。27/job128505007705は19:29:06〜19:44:43Z・元case449.500秒/失敗0、
26/job128505007839は19:29:07〜19:56:37Z・元case525.237秒/失敗0。型を絞った実review header、元3入力/各ACK/4件拒否/採用/保存/再起動と厳密実Runner/完了が成立した。
新両log/artifact0を一度取得し、終端を再照会しない。AXの一般的な解消や別ソースの正式合格へは一般化しない。
旧正式18の通常26Aは19:40:53Z/Bは19:55:46Zにsuccess。全15表示job終端、9成功/手動Three27失敗1/依存・構成skip5（手動26はmatrix一行へ集約）で未公開。
新26通常二log/artifact0も一度取得、正式18の全10実行logが揃った。新修正は別sourceの全15を要求し、先行成功を合算しない。
20:06Zにremote main65f268d不変を一度確認。次は新しいmain専用code-only review後、元全15の正式19へ通常fast-forwardする。

新規main専用GPT-6.1 Sol/High n233_shipping_pre_actions_reviewは完全code-only26行/2027bytesを確認し指摘なし。
SHA256 e54c27655f58ac35edbc59bfd281bd596ccb76147691d2f8ac5bc98fa87576b7の同一性、両OSの元Three成功・全Pythonと局所検査、
製品/正式workflow/manifest不変・remote main65f不変・全未送信空白を主担当が確認後、一回の正式19 main pushへ消費する。

## N234 正式19の通常26Bがfailure（2026-11-07）

source5e94fee7ffa87945e3f0d7d7b86085b5fe1eb328/run42409545980/attempt1/job128526538635、予定iOS26.5/SDK27.2。
20:57:37〜21:01:15Z failureを予定21:10Z照会で確認。本文未読で準備/実UI/具体case・原因は未確定。対処前の事実記録。
配布/Native/通常27A+B/全手動27はsuccess。通常26Aと手動26全4件は継続中で中止しない。
今回新しい7Mac終端成功logと26Bの失敗logだけを一度取得し、artifact一覧は全終端後まで取得しない。

新8logを一度取得。通常26BはUI未到達、download26.5/23F77と所有新規asset確認後の回収で失敗。
最初のdeleteは既知の部分削除exit30、旧target登録0を実確認し、一回scanを開始した。約11秒は候補0/AssetData実在、
21:01:12Zに新child UUID3B41C75F…が同じowned AssetData/Restore/094-56039-099.dmgとして現れた。
exact26.5/23F77/deletable/新parentUUID/同じparentMountPath/Verified/arm64は成立したが、stateが初観測のReadingで、
Ready/既知Unusableだけの所有判定から即拒否した。元30秒の観測予算は残っていた。第二delete/import/実UIは未実行。

検索語Reading/after-owned-asset-rescan/restoreでN224/N225/N227の詳細と0b68a5c/現5e94のhelper/fakeを照合。
既往は候補0→Ready、今回は同じ所有物の登録自体がReadingとして先に見えている。これをReadyや削除可能と扱わない。
候補は再登録の不変な所有metadataと削除可能状態を分け、所有metadataが完全一致したReadingだけ元の同じ30秒期限内でread-only再観測する。
Ready/既知Unusableになった後だけ既存のShutdown確認と第二delete一回へ進み、別path/親/署名/arch/既存UUID/未知stateは即拒否、Readingのまま期限切れも失敗とする。
scan再送・削除再試行・期限延長・実状態の書換えはしない。元のtarget登録0/AssetData不在→一回import→正確なlocal Ready・全15は維持する。
fakeにはReading→Ready、Readingのまま期限切れ、Readingでも別asset、未知stateを加え、第二delete時に実観測stateがReadyであることも要求する。
候補/根拠を隔離featureへ先にpush後、実helper全mode/関連workflowcaller/manifest/catalogを確認し、新規reviewで未到達の通常26Bを限定評価する。
稼働中正式19の残り26五件は中止せず、後で新しい終端だけをまとめて確認する。

c52c5a0を先にpush後、実helper4宣言/26の50mode/失敗0（107.498秒）、実workflow caller18件/失敗0（52.542秒）、
manifest30件/失敗0（18.366秒、Swift6.1.2有効）、catalog456/check --base5e94が成功。
Readingを削除せず3観測目のReadyで一回deleteする正例、同じ30秒のReading期限切れ、Readingでも別assetの即拒否、未知state即拒否を確認。
限定対象は通常Bの元testSettingsAccountDataAndFileDetails一件/iOS26/SDK27.2とし、新Runtime準備から実UIまでを通す。
新規GPT-6.1 Sol/High n234_pre_actions_reviewはcode-only104行/8899bytes、SHA256 0aeb6122d6e7ab13d6e03b59523bbe5a1c5edee1875000372aa841063f6d0b65を確認し指摘なし。
主担当が同一性/局所結果/未送信空白を確認し、このreviewを上記限定dispatch一回だけへ使用する。

追加のReading期限切れをもう一度実30秒で待つと、旧正式18のPython257.579秒に対し5分jobの余白をほぼ使う。
二つの同じ30秒期限の負例を別々に実時間待機する必要はない。元の候補0の負例は実30秒を維持し、
新Reading負例だけはテスト用monotonic/sleepで同じ30秒・一秒以下の待機30回を制御する。実helperのclock/30秒設定は変更しない。
全30回がReadingで、仮想経過30秒ちょうどで失敗・第二delete/importなしを要求し、正例/他のCLIは実コマンドdoubleのまま動かす。
Native限定実行のソースef14399からRuntime helper/製品/UIは同一bytesで、変更はLinuxの検査時間だけ。候補を先にpushして全Pythonを確認する。

## N235 検査用clockを含む全Pythonが非0（2026-11-07）

sourcea2a216680b83ce7b35239198030a4c6476de816b、Linux/Swift6.1.2、全Python session41049がexit1。
保持log未読でcase/段階は未確定、対処前の事実記録。Native限定はRuntime helper同一のef14399で継続中、正式19の残りも中止しない。

保持logでは314件/失敗1/skip2（203.992秒）、Reading-stuckの仮想経過30.0に対して2662.276だった。
元の失敗判定は成立したが、testclockの30回/30秒という追加契約は未成立。Runtime/製品のnative失敗ではない。
N229/N232の別callerへ及ぶmock差を再照合し、a2/現wrapperとPython subprocess.Popen._waitの実本文を読むと、
stdlibもtime.sleepを用いるためglobalなpatchが子プロセスのOS待機まで仮想clockへ混入していた。
対処はglobal time moduleを変更せず、実helperを実行するnamespaceのimportだけでtime依存を置換する。
子プロセス/標準libraryは実clock・実timeoutのまま、実helperのReading観測だけ30回/元30秒を検査する。
製品/Runtime helper/Native限定sourceは同一bytesを保持し、候補を先にpushして関連検査と全Pythonを再確認する。

82535f1を先にpush後、最終全Python314件/失敗0・skip2（202.176秒、Swift6.1.2有効）、catalog456/check --base5e94が成功。
helper namespaceだけのclockでReading30回・仮想30秒、元の候補0では実30秒の期限切れを確認し、stdlib/子プロセスの時計を変更しない。
Runtime helper/製品/UIが最終codeと同一bytesのef14399/run42415082876/attempt1/job128531311105は21:16:44〜21:37:52Z success。
通常Bの元Settings case445.879秒/失敗0、実26.5/Simulator/所有UUID/厳密完了と設定・実Switch・保存・再起動が成立した。
同じowned restore childはReadyで現れ、target登録0/AssetData不在→一回importの正確なlocal Ready23F77を実確認。
今回Readingは再現せず、その分岐は上記50modeで検査した。一般的なRuntime安定や低位原因の解明とは主張しない。
旧正式19の残り通常26A/手動26全4件もsuccess。全18表示終端は13成功/準備26B失敗1/構成・公開skip4、全14実log/artifact0を一度取得した。
新しい限定log/artifact0も一度取得、旧/限定の成功を次の正式全15へ合算しない。21:42Zにremote main5e94不変を一度確認した。
新規main専用GPT-6.1 Sol/High n235_shipping_pre_actions_reviewは最終code-only130行/10534bytesを確認し指摘なし。
SHA256 948a0c15eb427a9afa33639ebb2a518eae75d5aaac78766c38be4c5ebe6632cfの同一性・local/native結果・main base・全未送信空白を主担当が確認後、一回の正式20 main pushへ消費する。

## N236 正式20の通常27Bがfailure（2026-11-07）

sourcefa926ec97902adfe3b3a6a77692f36007ff4c6c3/run42417258426/attempt1/job128538819613、予定iOS27.0/SDK27.2。
21:47:57〜22:05:32Z failureを予定22:35Z照会で確認。本文未読のためcase/段階/原因は未確定、対処前の事実記録。
配布/Native/通常27A/手動27全4件はsuccess、通常26A/job128547124238は22:22:35Zから継続中で中止しない。
26B/手動26は依存skip。新しい7Mac終端logだけを一度取得し、artifact一覧は全終端後まで取得しない。

新7logを一度取得。通常27Bは5件中1失敗、testLinkPreferencesSurviveRelaunchが123.842秒でSettings.swift:487。
実解除/一回再起動/実追加メニュー/保存/復帰行hittable/一回primary tapは成立した。
実ページ本文の元30秒待機はt81.38〜111.70で未成立。BROWSER_FIXTUREのHTTP200/205bytesは末尾t111秒近くに出力されたが、
要求到着/読了/送信の開始時刻はなく、サーバ・Safari service起動・描画のどこで遅れたかは未確定。
期限後AXには本物のClose/WebViewがあるがBrowserView IsPageLoaded=falseで、fixture本文は未表示。採用や通知の失敗とは違う。

検索語LinkPreferences/Settings.swift:487/BROWSER_FIXTURE/BrowserView/localhostでN161/N162/U42/U54/N44の詳細と
e4f2fbf/bf1749a/9745d33/現fa926のtest/server/生成器/SafariLinkViewを照合。N161は内部ID照会の停止、今回は実本文の期限切れ。
元fixtureは既に要求全体2秒/非blocking/停止時の回収を持ち、実サーバの遅延かOSの下位原因かをログから分離できない。
次は診断のみ：所有serverのaccept/要求読了/送信完了と実primary tap直前の時刻を固定語彙で記録し、
使い捨てSafari copyで実controller生成と実didCompleteInitialLoad callback（成功/失敗だけ）を所有journalへ記録する。
本文/URL/ブラウザ結果の注入、prewarm、押し直し、server2秒/ページ30秒/Close10秒の延長は行わず、全15/元case/保存/再起動/実Closeを維持。
生成器のLinux境界stubも新しい観測APIだけを記録できるよう追従させ、collectorの既知stage正例/本文拒否を既存検査へ加える。
候補/根拠を先にpushし、既存の実HTTP/生成境界/manifest/runner/catalog検査後、新規reviewで未解決の元LinkPreferences27だけを比較する。
正式20の残り26Aは中止せず、終端後の新log/artifact一覧だけを一度取得する。

d54e10dを先にpush後、manifest全30件/失敗0（16.592秒、Swift6.1.2有効）、実shell runner18件/失敗0（47.196秒）、
Swift構文/Bash構文/catalog456/check --basefa926は成功。元の実HTTP応答・部分送信2秒・stop回収、
実生成factoryのURL正負/新しい一回の観測・固定stageのcollectorと本文/大容量/symlink拒否も同じ既存検査で確認した。
新規GPT-6.1 Sol/High n236_pre_actions_reviewはcode-only125行/9040bytes、SHA256 3bea36c0e9cd405085961f0dcb811801d9e771bd9de90606fcc98c2cbbbeafcdを確認し指摘なし。
主担当が同一性/局所結果/未送信空白を確認してから、元LinkPreferences27/SDK27.2限定dispatch一回へ消費する。

731f50aの全Python314件は失敗0・skip2（195.888秒、Swift6.1.2有効）。
元LinkPreferences27/run42421750403/attempt1/job128551465392は22:41:04〜22:52:37Z success、case228.595秒/失敗0。
元解除/再起動/追加/一回primary tap/実ページ本文/実Close/一覧復帰と厳密実Runner/完了を通過した。
新しい実時刻ではprimary tapからHTTP200完了まで約17.404秒、要求読了から応答送信は約0.005秒。
app journalはcapture-unavailableで、追加したnative initial-load callbackの実結果は今回未採取。旧log表示時刻から旧要求・送信・描画の遅れを遡って断定しない。
今回旧失敗は再現せず、下位原因や一般的解消は未確定。診断用の元30秒/実本文条件は変えず、次の正式全15でも観測する。
旧正式20の残り26Aは22:58:49Zにsuccess、全15表示終端は8成功/27B失敗1/依存・構成skip6。
新限定/残26A logと各artifact0を一度取得し、旧正式20の実9logが揃った。限定や別sourceの成功は正式へ合算しない。
23:01Zにremote mainfa926不変を一度確認。新規main専用GPT-6.1 Sol/High n236_shipping_pre_actions_reviewはcode-only125行/9040bytesを確認し指摘なし。
SHA256 3bea36c0e9cd405085961f0dcb811801d9e771bd9de90606fcc98c2cbbbeafcdの同一性・local/native結果・全未送信空白とmain baseを主担当が確認後、一回の正式21 main pushへ消費する。

## N237 — 正式480の明示選択26で訂正menu後の教員actionが出ない（対処前の観測）

source b0f3f4499c05cd4834cb675032569a2a8eca1a7d／run42423473274・attempt1／job128568597025、
配布SDK27.2・実Runtime26.5、元testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunchが236.608秒で失敗。
ManualAssistanceChecks+OneCorrection.swift:71で、preview訂正menuへの一回の0.6秒press後、
「教員を訂正」実Buttonが元nativeStateTimeout内に存在しなかった。期限後AXは背景の資料詳細と復旧sheetを含み、
preview=true/review=false/running=false/draft=nil、対象StaticTextも存在した。教員action/手動入力への到達は未確認。
今回の下位原因は未確定。対処案を選ぶ前に記録した。先に見たAX先頭だけをsheet消失の証拠とは扱わない。
00:45Zのsnapshotでは通常26Bと他の手動26三件はsuccess、通常26AはComplete job中。
残りを取り消さず確認する。失敗logは一度保存し、同source/run/attempt全15未達のため未公開。

全18表示job終端は14事前条件中13成功/明示選択26失敗1・公開含む構成skip4、artifact0。
通常26Aも1588.527秒/18件・通知123.800秒で成功、全14実logを各一度保存した。
実touchは対象中心(80,347.67)へbegan/ended、約1.13秒、終了時_UITouchDurationがchangedだったがmenuは出ていない。
接触取消・sheet消失・製品の訂正action失敗とは断定しない。
検索語selectCorrectionFromPreview/教員を訂正/contextMenu/0.6/native identityでN25/N31/N55/N78/N94/N97と
1b368f5/9cd340e/82ca252の実コードを照合した。N25は別授業の未表示、N94は接触時のindex再解決停止、
N97は探索中のidentity寿命切れ。今回は同Listの外側論理IDから、接触するTextを実identityへ取り直す経路だけが未対応。
候補は授業menuの外側探索を既知ID/現在のList/StaticTextへ限定し、可視化後だけ一意な現在のnative Textと
有限枠/viewport完全包含/enabled/hittableを確認して、同じ一回0.6秒pressへ渡すこと。
探索中の論理IDは維持し、全3caller・実menu/第四項目拒否/3入力/ACK/保存/再起動と元45秒・16探索/全15を保持する。
製品contextMenu・接触時間/位置・待機上限・期待状態は変えず、今回の下位原因解消を事前には主張しない。
候補を先にpushして既存project/navigation/manifest/runner検査後、元明示選択26だけを新規reviewで比較する。

b8868e0を先にpush後、Swift6.1.2有効の全Python314件は失敗0/予定skip2（206.014秒）、
既存のproject17件・navigation2件/実Swift29条件・manual runner6件・manifest30件も同じ実行内で成功。
元明示選択caseは全3回の実menu/入力/ACK/第四拒否/保存/再起動を必須とするため、新しい期待状態を作る検査は追加しない。
Swift parse/catalog456・check --baseb0f3f44も成功。新規GPT-6.1 Sol/High n237_pre_actions_reviewは
code-only57行/3998bytes、SHA256 0230bba5391827d898323bfc814b0600f7b06799d47d2585a38f6c2130e4c5c7に指摘なし。
主担当が同一diff・元0.6秒/全期待/全15と局所結果を照合し、このreviewを元明示選択26/SDK27.2の限定dispatch一回へ消費する。

cbf843f/run42431756801/attempt1/job128581998023は00:52:41〜01:20:21Z success、元明示選択26.5/SDK27.2が932.495秒/失敗0。
3回のnative menu一意/枠/完全包含/enabled/hittableと元一回0.6秒、実action/3入力/全ACK/第四拒否/保存/再起動を通過した。
厳密な実Runner identityと元case完了確認も成功。log/artifact0を一度取得し、再照会しない。旧失敗の下位原因一般は未確定。
正式開始専用の新規GPT-6.1 Sol/High n237_shipping_pre_actions_reviewも同一code-only57行/3998bytesに指摘なし。
主担当がhash・元全期待/期限・全15gateの維持、限定とlocal結果・main baseと全未送信空白を確認後、一回の正式22 main pushへ消費する。

## N238 — 正式481の明示選択26でreview Buttonのidentity解決が失敗（対処前の観測）

source c059a9fd8a574102209e64a4115b9dd19c8dab6c／run42434367494・attempt1／job128598243785、
SDK27.2/Runtime26.5、元明示選択caseが274.146秒/失敗1。
Navigation.swift:140のmanual-review-submitの現在native Button枠取得でNo matches found for Identity Binding。
実logはcomputed Button from legacy attributes vs PopUpButton from modern attributeと報告した。
先行のN237対象の最初の教員menuはnative Text確認・実長押しを通過しており、同じmenu不在の再発とは扱わない。
今回の消失/型変化の下位原因と対処は未確定。対処案を選ぶ前に記録した。
通常26A/Bと単項目26は継続中で取消ししない。完了済みの新10logだけ各一度保存し、残job/artifactsはまだ未取得。

検索語PopUpButton/type mismatch/manual-review-submit/Identity Bindingで索引に同じ型不一致の既往はなく、
N59/N94/N97/N160/N203の詳細と200c4c9/9cd340e/current Navigation/OneCorrection/生成viewを照合した。
N59の専用IDは他の2callerだけへ渡され、明示選択の3callerではlabelから始めていた。
N160の最終native identityは維持するが、今回だけlegacy Buttonの型制約がmodern PopUpButtonの実分類と衝突した。
候補は同じreview操作の全5callerへ既存IDを渡し、このID/同List/完全一致labelだけ最終native queryをAnyへする。
実要素種別はButtonまたはOSが今回報告したPopUpButtonを要求して記録し、それ以外は拒否する。
一意性・有限枠/完全包含/enabled/hittable・一回tap・実preview/3入力/全ACK/第四拒否/保存/再起動は維持する。
一般Button/clear/menu/Text/ACKの経路、製品のButton/contextMenu、元16探索/45秒/全15gateは変更しない。
既存project検査の2callerという旧個数は実5callerへ更新し、未指定callerを残さない検査を維持する。
候補/比較を先にpush後に既存全Python/Swift構文/catalogを確認し、新規review後に元明示選択26/SDK27.2を比較する。

53b364fを先にpush後、Swift6.1.2有効の全Python314件/失敗0/予定skip2（243.828秒）、
Swift parse/catalog456/check --basec059a9fも成功。実5callerの既存project検査も通過した。
元四case×両OSが実操作/結果の検証を担い、Apple型分類の期待結果を注入するmockは追加しない。
新規GPT-6.1 Sol/High n238_pre_actions_reviewはcode-only80行/5657bytes、SHA256
6ed1a5f9b3907041c08ab9542657de384cba1758ff0a925b843362f2a5454db2に指摘なし。
主担当が実差分・一意ID/label/実種別guard・元の全操作/期待/期限/全15を照合し、限定26/SDK27.2 dispatch一回へ消費する。

995fb5a/run42439109096/attempt1/job128604307453は02:34:21〜03:07:36Z success、元明示選択26.5/SDK27.2が926.640秒/失敗0。
同ID/labelのnative操作・全3review・実3menu/3入力/ACK/第四拒否/保存/再起動と実Runner/完了確認を通過した。
今回実分類は3回ともButton(9)。旧失敗のmodern PopUpButton(14)は再現せず、この枝のnative確認や恒常解消は主張しない。
旧正式22の残26A/B/単項目26もsuccess、全18表示job終端は事前13成功/明示選択26失敗1/構成・公開skip4。
全14実logと限定log・両artifact0を一度だけ保存し、旧実行は再照会しない。限定成功を正式条件へ合算しない。
新規main専用GPT-6.1 Sol/High n238_shipping_pre_actions_reviewも同一code-only80行/5657bytesに指摘なし。
主担当がhash・局所/限定結果・元全期待/期限/全15維持・main baseと全未送信空白を確認後、一回の正式23 main pushへ消費する。

## N239 — 正式482の通常27BでAI/OCR Switchの実操作後のUI/保存が変わらない（対処前の観測）

source79e477656cbcc026b8f7e3f2edd50d07b5283698/run42441654334/attempt1/job128612698513、
SDK27.2/Runtime27.0、testSettingsAccountDataAndFileDetailsが168.884秒/失敗1。
Settings.swift:251でPhysical AI/OCR switch tap did not update both UI and stored permission。
どの回の操作か、実touch/Binding/保存の下位原因は詳細照合前で未確定。対処案を選ぶ前に記録した。
Native701/予定skip1・通常27A・手動27四件はsuccess、通常26Aだけ継続中。残りは取消しせず確認する。
新しい完了7logだけ各一度保存し、Distribution既取得と計8log。26A・artifactはまだ未取得。全15未達で未公開。

詳細：初回pid53655の3操作は実UI/保存/setter成功、native deliveryはbegan→endedが約73.6/81.3/85.1ms。
再起動後pid56687の4回目1→0だけ、同じ現在native枠(300,485,63,28)/状態1/75%点(347.25,499)を確認後、
約5.58msでbegan→endedした。cancelledではなくUILongPress state0のまま、UI1/保存1・新pidのsetterなし。
検索語AI/OCR/fourth/native tap/touch durationでU04/U19/U55/U64/N146/N180/N192/N212と
917e807/a8b7131/01daa73/current helper/全5callerを照合。U55の古いqueryは現行で再取得済み、
N192の初回/配送未採取とも、N212の約135ms forced0.1接触の実cancelledとも異なる。
今回は同点の極端に短い実deliveryと成功3接触の長さを初めて分離できた。短さが原因とはまだ断定しない。
候補は現在native identity/同点/全包含/前状態一致を維持し、一回の通常coordinate.tapを
要求50msの短いcoordinate.pressへ置換する。失敗済み要求100msへ戻さず、実配送時間/取消しは既存traceで再観測する。
全5callerへ共通適用し、再送/状態・許可注入/元45秒や行除外15秒の延長、UI/保存/再起動条件の緩和は行わない。
一回入力だけの既存契約検査は新しい短接触を明示的に要求し、二重tap/旧100ms/画面固定座標を拒否する。
候補/根拠を先にpush後に全Python/Swift構文/catalogを確認し、新規reviewで元Settings27/SDK27.2だけを比較する。

340631dを先にpush後、Swift6.1.2有効の全Python314件/失敗0/予定skip2（197.943秒）、
Swift構文/catalog456/check --base79e4776も成功。全5callerと一回入力・元guard/期限の既存契約を通過した。
新規GPT-6.1 Sol/High n239_pre_actions_reviewはcode-only40行/2536bytes、SHA256
9ec49086c32df8bfdeaec3ae47dbd5a2ec4cfcfcd1058db3a74b7bcc1fc29078に指摘なし。
主担当が同じ実identity/点・一回50ms・実UI/保存/再起動/元期限と全15の維持を照合し、元Settings27/SDK27.2の限定dispatch一回へ消費する。

e336ef1/run42446150709/attempt1/job128625390428は04:16:45〜04:30:33Z success、元Settings27/SDK27.2が445.658秒/失敗0。
全4接触は実配送66.235/85.370/91.115/69.967msのendedで、初回3回と再起動後4回目のUI/保存/setter成立、
その後の再起動後OFF保持と元のファイル詳細操作・厳密実Runner/完了も成功した。4回目の未反映は今回再現せず、恒常解消は未証明。
旧正式23の残26Aも04:33:52Zにsuccess、全15表示job終端は8成功/27B失敗1/構成・依存skip6。
全9実log/限定logと各artifact0は一度取得し、旧結果は再照会しない。限定や別sourceの成功を正式へ合算しない。
新規main専用GPT-6.1 Sol/High n239_shipping_pre_actions_reviewも同一code-only40行/2536bytesに指摘なし。
主担当がhash・元の全guard/期待/期限/全15維持・local/限定結果・main baseと全未送信空白を確認後、一回の正式24 main pushへ消費する。

## L20261113-runtime-mock：Linuxの準備スクリプト模擬検査

ba27dc0上の今回のPDF改修作業ツリー、Linux/Python3.12。
全Python検査中、test_prepare_ios27_runtime.PrepareRuntimeTests.
test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failuresの
partial-pendingで、期待する30秒の終了説明に代わり残予算約0.025秒の
mock xcrun runtime listがTimeoutExpiredとなった。実Xcode／Simulatorは使用していない。
当該スクリプトとテストのHEADとの差分は空。検索語partial-pending／prepare-ios26／
prepare_ios27に同条件の索引はなく、実Runtimeや実アプリの既存timeoutとは段階が異なる。
同時に走っていたSwift全体検証の終了後、負荷を分けて該当caseだけを確認する。
準備スクリプトの期限・期待値を変更しない。

L20261113-runtime-mock追記：Swift全体検証終了後の該当case単独実行は63.116秒・成功。
全入力を同じ期限・期待値で検査した。個別成功で、並行負荷時の再発が解消したとは断定しない。

## N240 — 試験scope追加後のApple Nativeコンパイルで保存検査式の型推論が停止

a3241b10ff8aba23a7beeec949a383cfbd88d581／run43357779926／attempt1、
Native PDF and recovery tests job131665299525。2026-11-13T03:39:52Z開始、03:42:50Z failure。
macos-26、設定DEVELOPER_DIRは/Applications/Xcode_26.6.app/Contents/Developer。
SpecialScheduleStore.swift:293の複合return式で「the compiler is unable to type-check this expression
in reasonable time」。テストケースの実行前にswift testのビルドが終了1となった。
ログにはこの設定パスがあり、実Swift／SDKのversion出力はないので推測で補わない。
同じsourceのLinux Swift6.1.2では613テスト成功。旧実行は中止せず残りの結果も確認する。
型検査条件の分割候補を選ぶ前に、型推論／type-check／SpecialScheduleStoreで過去索引を照合する。

N240照合：N31はSDK26側ViewBuilderの複合式、N03はtry/importなどの不足、
N67／N68はアプリとSPMの型契約／overloadの相違である。
N31の当時f1abea00の訂正メニューと現在の保存predicateを実コードで比較した。
今回はSwiftUIやGRDBのoverloadではなくFoundation型だけの長いBool式に診断が集中している。
同じ型推論条件を再実行せず、保存検査を小さなguardと型付きBool、授業ごとのloopへ分割する。
版数・返却の件数・scope・一意性・時刻・所属・投影・旧cacheの全条件と短絡順を維持する。
新しい模擬テストは追加せず、既存の可変scope再起動・返却subset保存拒否・不正時刻・
旧正常結果保持などを含む全Swift検証と、両Apple SDKの限定Native検証で確認する。
限定成功は公開ゲートへ合算せず、その後に新しい同一sourceの全15を実行する。

## N241 — iOS26 Runtime所有assetの再照合が残り1秒未満でTimeoutExpired

7c05ef749fab529d40272519c6bec8d8ea672040／run43362432494／attempt1、
Manual correction iOS26 ThreeFields job131709176812。2026-11-13T05:24:46Z開始、05:28:39Z failure。
設定SDK27.2／Xcode27.2、対象Runtime26.5の準備stepで終了1となった。
prepare-ios26-runtime.py:161のafter-owned-asset-rescanからruntime list -jを呼び、
残り0.678703708秒でsubprocess.TimeoutExpired。手動UIケースは未実行でskip。
同sourceのNative／iOS27通常・手動全件は成功済み。残りのiOS26実行を中止しない。
まずpartial-pending／reclaim_owned_asset／TimeoutExpiredの過去記録と当時のコードを照合する。
Runtime準備失敗の原因や恒常対処は未確定。アプリ／PDF解析の失敗とは判定していない。

N241照合：N224/5568d90の候補0→Readyの非同期登録、N234/c52c5a0の
所有metadata確定後のReading待機と現7c05efの実コードを比較した。
今回はscan後1.3秒から同じ取得asset/Restore下に新しい子imageがVerifying/Personalizedで現れ、
30秒終了直前まで続いた。runtimeIdentifier/build/versionはまだなく、削除可能な所有証明は未完成。
候補0のままAssetDataが実在し、30秒の残予算で最後のCLIもtimeoutした。
LinuxのL20261113-runtime-mockは期限末の説明の不安定さのみで、今回の署名検証継続は実Appleで初観測。
候補は正確な今回asset/Restoreパス・新規子/親UUID・deletable・Verifying/Personalizedが
一意に揃う場合だけ、scan開始から最大180秒の署名検証観測を追加する。
この状態をReady/検証済みとは扱わず、削除せずに読む。通常の候補なし/Readingは従来の30秒を維持する。
署名検証後も元のexact26.5/23F77/Verified/arm64と所有判定、Shutdown、正規delete一回、
AssetData不在→import→一意なlocal Readyを全て要求する。期限切れは常に失敗で、scan/UIを再試行しない。
180秒は既存scan-and-mountコマンドの上限と同じ準備予算であり、UI操作・ケース・jobの期限は変更しない。
候補/根拠を隔離branchへ先にpushし、架空CLIで検証遷移/期限切れ/誤所有と既存全modeを確認後、
元ThreeFields26/SDK27.2の限定CIで準備から実UIまで通す。恒常解消はまだ未証明。

N241局所検証：初候補9faacf2のRuntime helper4宣言/失敗0（82.787秒）、
manual runner6件/失敗0（3.903秒）、application runner18件/失敗0（35.159秒）。
新規Sol/Highの限定開始前code-only reviewで、180秒の起点がscan返却後になっている指摘を受けた。
scan開始前に起点を採り、通常30秒の登録観測は従来通り返却後、署名検証だけscan開始から180秒とする。
scan自体が150秒/180秒かかる対照も独立時計へ追加し、観測予算が更新されないことを確認する。

## N242 — 正式485のiOS26通常画面Bがfailure

7c05ef749fab529d40272519c6bec8d8ea672040／run43362432494／attempt1、
Application iOS26 UI B job131709176894。2026-11-13T05:24:45Z開始、05:57:25Z failure。
設定SDK27.2／対象Runtime26.5。完了照会でfailureを確認し、log本文はこれから読む。
失敗したケース／段階／原因は未確定。残Selected26と別branchの限定Three26は中止しない。
対処を決める前に新しい失敗logと既往の同case・同段階の実コードを照合する。

N242新log：Runtime準備とbuild-for-testingは成功。testLinkPreferencesSurviveRelaunchの
ApplicationChecks+Settings.swift:553で、一回のnative長押し後45秒以内にリンクmenuが現れず失敗。
ケースは173.064秒、通常Bの残ケースも実行され、同じjob内の結果はfailure。
前回484の同じUIコード／iOS26Bは成功。今回は新しいUI失敗の観測で、
N241の準備処理だけでは対処できない。LinkPreferences／Link menu／long pressの索引と当時のhelperを照合する。

N242照合：U42/U54/N44/N55/N86の詳細、dfb185cの標準Menu/primaryActionと現LinkRowを比較した。
同じnative長押し二秒と45秒待機を維持している。今回も架空loopbackページが実200応答で開き、
primary actionへ進んだことを確認。入力は同じHostingUIButtonの中心へbegan/ended、wall時刻差4.562秒。
終了時のUILongPress stateはfailedで、短い接触や取消しとは断定できない。
現observerはDateのwall時刻とstateのみで、UIKitのtouch/event時刻と認識器の実設定は未観測。
候補はLinkPreferencesケースだけにQAフラグを追加し、同じ一回のsendEventの前後を保ったまま、
touch/event timestampとpublic UILongPressGestureRecognizerの最小時間/移動上限/必要接触数を固定数値で記録する。
実操作・native hit point・二秒・45秒・保存/再起動/ブラウザ/全公開条件は変更しない。
本文やURLは記録せず、公開製品にも観測コードを追加しない。新しい観測条件で元case26/SDK27.2を限定評価する。

N241修正候補の確認：9ba4563のhelper4宣言/失敗0（84.572秒）、
Swift6.1.2を有効にしたPython全314件/失敗0/環境skip2（183.846秒）、catalog456が成功。
05d7208/run43373647001/attempt1/job131714991934は05:41:31〜06:03:06Z success。
新しいVerifying状態を観測後、scanから約27秒でVerified/Readyとなり、所有回収/importを通過した。
元ThreeFields26/SDK27.2は298.278秒で成功、正確なcase完了と所有cleanup・artifact0を確認。
今回の実Appleでは30秒超の遅延は再現せず、35秒相当の正例と180秒の失敗境界は独立時計の局所検査で確認した。
個別成功を恒常解消や正式公開へ換算しない。

N242観測候補8673b3cは、diagnostic parser12件/失敗0（0.269秒）、
Swift有効のmanifest30件/失敗0（15.414秒）、Swift構文とcatalog456/checkが成功。
新規Sol/High ios_link_press_focus_pre_actions_reviewは同じcode-only差分に指摘なし。
元のUI操作・期限・期待値と一回のsendEvent維持を主担当が照合してから、元LinkPreferences26/SDK27.2限定一回へ消費する。

## N243 — 正式485のSelected26が45分上限後にcancelled終端

7c05ef749fab529d40272519c6bec8d8ea672040／run43362432494／attempt1、
Manual correction iOS26 SelectedHighConfidence job131709176825。
05:24:46Z開始、06:19:46Z completed/cancelledをno-cache照会で確認。
設定SDK27.2／対象Runtime26.5。Runtime準備は05:28:00Z成功、以後の実手動case stepがin_progress表示のまま。
主担当はActionsのcancel APIやcancel操作を行っていない。45分job上限から10分後の終端と観測したが、
終了理由とケースの停止位置は新logで確認するまで未確定。成功とは扱わない。
対処を選ぶ前に新しいlogと当時の同ケース／同段階のコードを照合する。

N243確認：check-run annotationは「The job has exceeded the maximum execution time of 45m0s」。
GitHubがjob上限で停止したと確認できた。job log APIはBlobNotFound/404、完了run archive経由も0bytes。
artifact0。ログ欠落から実ケースの停止位置や製品原因は推定しない。
N162の上限後のlog欠落、N211/N218のSelected26、当時と現行の同case/runnerを照合する。
通常画面BのN242のmenu不在と同一原因とは扱わない。

N243照合：N162/2b5e5c9の外側監視と現manual-26/runnerを実コードで比較した。
現manualはRuntime準備後に40分timerを開始する。今回準備3分14秒の後では45分job上限まで
残り約41分46秒で、40分timeout後の120秒group回収と最大70秒診断を完了できる余白がない。
SDK選択・Runtime準備・元runnerを一つの既存2400秒監視の中へまとめ、全体をjob上限前に失敗させる。
focused manualにも同じ範囲を適用し、既存の2400/1800秒・45/35分上限・120秒回収を延長しない。
元Selectedの入力/各操作期限/全期待/実Runner証明は不変で、timeoutは引き続き124失敗。
これは停止箇所を失う監視範囲への対処候補であり、未観測のUI停止原因を直したとは扱わない。
実workflowのwrapped shellを架空CLIで動かし、準備の失敗/準備のtimeoutでUIへ進まず、正常時だけ
選択→準備→UIが一回ずつ進むことを確認する。その後、新sourceで元Selected26/SDK27.2一件を限定実行して観測する。

N243局所の初回：e71925a、Linux/Python3.12/Swift6.1.2、実workflow shellを含むmanual7件は成功8.493秒。
manifest30件は1件失敗（14.473秒）。focused workflowの旧「準備外の監視一行」を要求する
文字列契約だけが新しい意図したwrapperと不一致。UI／Swift動作失敗ではない。
準備を監視へ含めるN243候補と、以前の45/35分・2400/1800秒・120秒・元caseの全条件を比較して、
当該文字列を新しい正確なcommandへ更新し、選択/準備/UIの順と監視内であることも要求する。
reviewの同step化による環境伝播懸念は、実select/prepare各helper全体を読んで照合した。
いずれもGITHUB_ENV/GITHUB_OUTPUTへ書かず、workflow envとxcode-select/Runtime登録の実状態を使う。
held exportもRUNNER_TEMPの固定所有領域とmarkerで保持され、後続stepへの環境出力を必要としない。

N243局所の二回目：c8629c1、同Linux/Swift6.1.2のmanifest30件は1件失敗（14.306秒）。
test_manual_matrix_requires_every_unchanged_case_on_both_os_separately:874で、旧focusedの
独立prepare stepのif/run文字列契約が残っていた。前回は同じメソッド全体と全callerの確認が不足していた。
新しいActionsはまだ開始していない。利用者の指示で、両repositoryの今回の全差分・関連契約・
失敗索引本文と当時コードを確認し直し、個別の文字列修正と再実行を中断する。

## L20261113-audit-swift-preflight — 全体検証用コピーと起動方法の不整合

f9a2eefの全体確認開始前、所有一時SwiftPMコピー277ファイルのうちQA用2ファイルが古いことを検出。
一時run.shはmode600で、直接実行がPermission deniedとなりXCTestは未実行。
元ソースとscript/Packageの実状態を確認し、コピーを現在の公開ソースへ揃えて再照合し、
bashで所有scriptを解釈して起動する。検証条件やソースを緩めず、未実行を成功に数えない。

全差分再確認後の局所検証：現在の公開ソース277 Swiftファイルを所有コピーとbyte照合し、
Linux Swift6.1.2で613件・失敗0（78.489秒）。Swift終了後のPython全315件も失敗0、
予定された環境skip2（187.851秒）。catalog456とStrict枝一覧のcheckも成功した。
N243の実workflow shellはshipping26/27、focused26 SDK27.2、focused27、
focused26 native26.6での準備省略を全て検査し、準備失敗／timeout時のUI不実行を保持する。
新規のSelected限定レビューはv3差分にblocking指摘なし。元Selected26/SDK27.2の限定CIはこれから開始し、
その成功を正式実行の14公開前検証へ合算しない。未観測のUI停止原因の解消はまだ証明していない。

N242の観測限定48a16a2/run43376612715/attempt1/job131724468623は06:08:26〜06:21:53Z success。
同じ二秒のnative長押し、45秒menu待機、削除／再起動／追加／browser/Closeを全て通過した。
UIKit時刻でも二回の実接触を確認し、製品・入力・期待値の変更はない。cleanup成功・artifact0。
この一回の成功をN242の恒常解消とは扱わない。

N243限定確認：89066f3/run43387318089/attempt1/job131758747884は07:39:35〜08:15:21Z success。
元SelectedHighConfidence26/SDK27.2は1111.610秒で全期待を通過し、cleanup-completeと
所有Runtime exportの回収も成功、artifact0。準備を含む元2400秒内に完了した。
この限定ではUI停止は再現せず、N243の欠落logから旧停止原因を特定したことにはしない。
全14公開前検証と公開jobの同一ソース・同一run/attempt成功を次の正式486で別に要求する。
最終code-only v3差分は、未開始の正式486専用Sol/High reviewerも具体的指摘なし。

- 2026-11-16 #110 Linux Swift 6.1.2、8c8809e上の作業差分。初回のSwift全体検査は619件中、不均等な架空の返却行を扱う新規ケース1件がR090（授業欄の文字行）で停止。学年判定と授業欄の検証を切り分ける前の観測。
  PDFGrid.lessonFields の従来のR090は省略欄と基準セルの位置を照合する。新規ケースだけが授業1行を既存基準と異なる高さに追加していた。学年所属を検査する3つの架空枠へそれぞれ科目・教員・教室を明記し、Strict・認証用の両経路と誤所属の検出条件を維持した。
  同じLinux/Swift条件の限定検査では新規3枠へ3行を明記した後も、4件中その1件が同じR090。括弧・ソース行順・学年の問題と断定せず、架空セル位置と基準の可否を切り分ける。
- 2026-11-16 #112 Linux Python/Swift 6.1.2 の通知ライフサイクル検査で、既存の実メソッド抽出テストがコンパイル段階で停止。試験用Inputと比較関数に、個人修正を学校更新から区別する引数が未宣言だった。試験用の型に本番と同じ引数を追加し、通知失敗時の既存アサーションは維持する。
  架空データだけの座標診断で、別の既存1行枠に対する基準が新規の3行枠では教員の位置に重なり、既存基準では科目の位置に重なることを確認。新規3行枠を元fixtureと同じ基準間隔に整え、両解析器の校正条件は維持した。
- 2026-11-16 #112 Linux Swift 6.1.2 で原本更新後の永続化ケースの「旧補正が空」2箇所が失敗。途中版で原本に存在しない曜日列まで追加したため、元の入力に無い曜日補正が生成されていた。曜日列は原本にある場合だけ扱い、公式値への置換・旧補正の失効を再確認する。
- 2026-11-16 #112、328911c・限定CI 43731467471 attempt 1、iOS 27.0 / Xcode 27.2。rowsケースは従来の除外Switchのタップ後、ApplicationChecks+Changes.swift:31で15秒以内にvalue=1に到達せず停止。新しい個人編集画面に到達する前。file-detailsの変更・試験の警告サイズ拡大と既存ファイル詳細は成功。原因確定前の観測。
  実配送は3行目がbegan→ended約104ms、4行目が約4.8ms。両方とも同じ50msを要求し、正しいUISwitch上へ一度接触。4行目はUILongPress state=0のまま。N146・N212・N239の当時実装と現行の同一Swift helperを照合。対処候補は行除外・復元の実UIテストで、実際のSwitchの現在のつまみから反対側まで一回の水平ドラッグを使う。実スイッチの一意性・包含・状態一致、画面での状態遷移、元の期限、保存と再起動の検証は維持。通知・設定の操作は従来の短い接触を使う。
- 2026-11-16 #112、Swift 6.1.2 Linux、数式が変更され同じエラー値が残る入力の新規テストで2件の失敗。元行照合と再適用のアサーションを、根拠を保存する段階と照合する段階に分けて調べる。
  エラー値・根拠コードは一致し、異なる式2個とも式本文が長さ0だった。XML読取は従来 t/v だけを保存していた。個人編集でシートを開く場合だけ f 本文も長さ制限付きで保持し、数式の実行は行わない。Workbook内の式が変わった場合と同一のままの場合の両方を同じ新規ケースで検査する。
- 2026-11-16 #112、6e1307c・限定CI 43732991677 attempt 1、iOS 27.0 / Xcode 27.2。実スイッチの3行目・4行目・101行のグループ除外と、再起動後の保存確認は成功。その直後、画面下の解析結果から上方の「個人修正を編集」を探す操作が Navigation.swift:209 で停止。最終frameは無効、操作欄は上方にある。file-detailsは成功。前回のSwitch接触失敗とは異なる。
  失敗時のAXツリーは下部のクラス選択・授業結果を表示していた。N54/N78と実装を照合し、最初の個人修正ボタンの探索だけ、既存のsearchEarlierRowsで前方の行へ戻す。2回目は画面先頭から開く既存方向。スクロール回数・全包含・実際の操作・保存結果は変更しない。
- 2026-11-16 #110〜112、正式CI 43736804888 attempt 1、092cc9c。iOS 27・SelectedHighConfidenceFieldsで ManualAssistanceChecks+Review.swift:49 のAXスナップショットが「Lost connection to the application (pid 11833)」で停止。手動補助の既存検証経路。配布検査・native PDF解析は成功。今回の原因と他ジョブの結果は調査中。
  tap後の10秒待ちで、root全体のAnyによる画像探索が120秒以上かかり接続を喪失。U62・N153・N173の広域AX探索記録と照合。生成QAプロジェクトの実ScrollViewに識別子を付け、画像はその子孫・枠は画像の子孫に限定する。10秒・正の実寸・画像内の包含・slider拡大・等倍・後続の保存再起動は維持し、動作確認前の候補とする。
- 2026-11-16 #110〜112、正式CI 43736804888 attempt 1、正式テストiOS 26 UI B / 132894192222。架空リンクの実ページを表示し、Closeボタンが存在・操作可能で一度tapしたが、Settings.swift:519の10秒以内に本文が消えず停止。N161/N242の実ページ取得・メニュー未表示とは到達段階が異なる。Close接触はSafari側で、アプリ内のタッチ記録から実時間やdelegateの受領は確定できない。現行の正式再実行でも元の期限と実ページ検査を維持して比較する。
- 正式CI 43736804888 attempt 1 / 132890642929、同じソースのiOS 26 UI Aは既存の通知ケースで設定タブのアイコンへ1回接触後も45秒以内に選択されず、Navigation.swift:60で停止。失敗時もホームが選択中だった。U77は同じ選択判定で別の通知ケース。入力配送の原因は未特定。既に開始した正式CIの同じ操作・期限で結果を確認する。
- 正式CI 43742821232 attempt 1 / 132900704193、ソース409d0f9のiOS 27 B。testLinkPreferencesSurviveRelaunchはSafari表示まで進み、架空ページの本文がSettings.swift:512の30秒内に現れず停止。初回接触記録1794765641.944、controller生成42.472、接続56.881、別接続67.017、HTTP 200・205 bytes送信67.277、delegate成功5681.178（接触後約39秒）。失敗時の階層はIsPageLoaded=false、進捗10%、Closeあり。前回26のClose後に本文が残った事例とは異なる。
  N236・N161と現在の実サーバを照合。元実装の一つ目の未完ヘッダが後続GETの受付自体を止めることを、Swift実サーバの二接続・逆順完了で再現（元コードは先行接続が切断）。受理順に同じ2秒期限を設定し8本まで独立処理する。実HTTP/実本文30秒/Close10秒/通知の45秒は維持。今回のSafari実行の時間差全体をサーバ待ちだけで説明できる証拠はない。
- 正式CI 43748518096 attempt 1 / 132918327576、ソース91f6b41・iOS 27.0・SDK27.2。testMergedCardsFromAllSourcesがTimetable.swift:61の結合授業Buttonのhittability取得で "Activation point invalid and no suggested hit points based on element frame"。他の操作や入力の成否は別途照合。原因未確定。
  実行記録は同じカードに画面全体の上・下スワイプを交互に8回。N126/N160と既存の時間割カード検査を照合し、画面内の実枠を使い小さく移動する共通visibleへ変更。実ボタン全体が枠内・有効・hittable、元の高さ72超・各カードを一度タップ・4種の正しい詳細と行事表示を検証する。
- 正式CI 43754726270 attempt 1 / 132937141427、ソース070e4c1・SDK27.2・iOS 27.0。testChangedOriginalCannotSubmitOrReplaceLastGoodは ManualAssistanceChecks+Input.swift:53 のAX探索で "Failed to get matching snapshots: Timed out while evaluating UI query"。504.689秒で失敗。
  初回ACKは進行、再表示後の2回目も実Switchの一回接触と非同期述語から戻った直後、任意診断manual-input-stateのroot探索がt231/262/293秒と再試行し停止。U72/U73・生成QAのmanual-observation子要素を確認。実Switchの一意性・値1の待機結果をそのまま記録・検証し、異常時だけ該当グループ内の観測文字列・binding履歴を取得する。実submit・元資料変更・再起動・前回データ保護の判定は維持。
- 旧正式CI 43748518096 / 132933949457、iOS 26.5 Bはbootstatus成功後、Xcodeが指定した端末IDを対応先として列挙できずケース開始前に終了。終了後のsimctlでは同じ端末がBooted、runtime available。SDK・端末ID・公開条件を変更せず後続の正式CIで確認する。
- 正式CI 43758697036 attempt 1 / 132949347186、ソース3efbe8b・SDK27.2・iOS 27.0。testThreeFieldsRequireEachAcknowledgementAndFourRefusesはManualAssistanceChecks+Navigation.swift:97の実行中 "Failed to get matching snapshot: Timed out while evaluating UI query"。元資料変更ケースは同じ正式実行で成功。
  3項目の個別操作・確認画面を経て4項目拒否を調べるため再起動した後、設定→時間割ファイルの取得で停止。既に所有Listを特定した後もrootのbutton.firstMatchへ存在・frameを再照会（t362/392/423/455）。N203/N94とSettingsの実NavigationLinkを比較し、通常ページのラベル指定Buttonだけ所有List下の該当する型・ラベル・指定時のIDで一意な実体を取得し、同じ実体の枠・enabled・hittableと一回接触を使う。不存在は既存の16探索・受動スクロールで検証する。

- 2026-11-16 #110〜112、旧限定CI 43761286209 / 132956447655、iOS 27.0、手動3項目ケースは正常終了。旧正式491で止まった通常画面リストの探索を含む。この限定実行には他ケース・他OSは含まれない。
- 全差分の再点検で U72/U73、N94/N126/N160/N173/N189/N203/N233/N238、U77/N242 の探索・入力・再起動記録と最新の正式失敗3件の当時コードを比較。復旧中とシートを閉じた後の観測先を分け、現在のリストから操作対象を一意に取得する。全6箇所のプレビュー操作を同じ入口にし、任意診断は失敗時に限定。単項目・3項目とも採用された対象と値の対応を再起動前後で比較する。時間割カードは表示ラベルの日時限・科目で特定し、詳細の種類と科目・シートが閉じたことを検証する。
- Linuxの手動UI検査44件中2件は、全画面の再照会と特定のアサーション文字列を前提として失敗。操作上限を超えたら必ず失敗すること、現在の所有リスト・一意な項目ID・同一訂正内容の保持を検査するよう更新。
- Linuxの全体Swift検査で LocalDatabaseTests.testWeekdayConsentAndResultCommitTogetherAndRollbackTogether が invalidDatabase。別原本の取得で過去の解析試行を消した際、SQLiteが前回の試行を再読込した。新しい原本と古い正常結果を同時に保護したまま、対応する試行記録を同じトランザクションで消す。
- Linux/Python 3.12、模擬iOS26 runtimeの partial-verifying-wrong-identity がSwift全体検査と並行した際に15秒でTimeoutExpired。期待結果を読む前のテスト側サブプロセス待ち。過去のL20261113-runtime-mockは別のpartial-pendingで残り予算が尽きた記録。今回も実機やAppleの準備ジョブではない。Swift終了後、模擬検査を含む全Pythonテストを元の期限・条件で単独実行する。
- 旧正式490 / 43754726270 attempt 1、iOS 26 UI B / 132950001919 は cancelled で終端。22:02 UTCにtestNotificationControlsAndAppearanceを開始、22:04のログは「The operation was canceled.」。このケースのXCTest完了記録や取消の下位原因は確認できない。Build and publishはskipped。今回の限定検証とは別の実行。
- 旧正式491 / 43758697036 attempt 1 はiOS26 UI A・Bとも成功で終端。iOS27の手動3項目が既報の失敗のため、公開ジョブはskipped。個別成功は現在の候補版の公開判定に合算しない。
- 限定43767607953 attempt 1 / 132976131847、6ee6857、Xcode 27.2、iOS 26.5 手動3項目。XCTest開始前に prepare-ios26-runtime.py が「Owned asset re-registration did not complete within 30 seconds」で終了。準備step 203.4秒。シミュレーター上の入力やアプリの成否は未観測。
  N224/N225/N226/N234/N241の過去記録と、旧正式491および今回の同一prepare-ios26-runtime.pyを照合。今回の正規deleteはMobileAssetの回収のみ未完了。scan後30秒の19回の観測すべてで対象候補が空、AssetDataあり。N241で180秒観測する一意の子イメージの署名検証は現れなかった。同一source・SDKの別ホスト（132976131744）では同じ準備stepが成功してXCTestのstepへ進んだ。UI側の修正対象を示す証拠はない。準備・所有検証・各期限を維持し、クリーンなホストの限定実行で手動3項目を起動から確認する。
- Linux Swift 6.1.2の全636件が成功。先の模擬runtime timeoutを含むPython全体をSwift終了後に単独で実行し315件、失敗0、環境依存skip 2件。
- 限定43767607953 attempt 1 / 132976131744、6ee6857、Xcode 27.2／実guest 26.5.0、時間割変更rows。準備成功。22:11:44 UTCに外側runner開始、build 103.7秒、bootstatus 483.2秒、22:25:19にtest-without-building、22:31:07にケース開始。103行除外・再起動後に「個人修正を編集」を探索する途中の22:35:45、外側1440秒が満了（終了124）。その時点でXCTestのassertion失敗記録はなく、4行目の学年入力は未到達。
  N153（再起動後のAX応答停止）、N162（リンク診断の外側上限）、N199/N204（bootと実guest証明）、旧正式491の該当UI・shellと比較。今回はbootも実guest証明も通過、特定操作の失敗はない。同じ候補版のiOS 27.0 / 132976131829は、同じケースの全操作を469.872秒で完了（外側1042.7秒）。26.5では元の制限開始からケース開始まで1162.8秒を要し、残り約277秒だった。限定26.5のみ、実行対象を同じrows一件に固定し、実xcodebuild test-without-buildingを1200秒、全runnerを2400秒、jobを45分に個別制限する。範囲・各操作期限・同一ケースの一回実行・厳密な実guest証明・失敗時の回収を維持。公開workflowには適用しない。
- 限定43767607953 attempt 1 / 132976131799、6ee6857、SDK27.2／実guest 26.5.0。testMergedCardsFromAllSourcesはApplicationChecks.swift:114の一度目のapp.launch()で「Timed out while launching application via Xcode」。終了222.543秒、カードの照会前。アプリ側の同一pidのinit・seed-complete・application-ready・fixture-readyは記録済み。外側runner124のrowsとは異なる。
  U58/b9289ae・U59/373da5fの起動コード、N125/N159、旧正式491と今回のlaunchReady・生成schemeを照合。同じ一回launch・前面判定・fixture-readyが必須。今回はreadyまで約4.37秒をアプリ側で観測。事後のhost、AX、通知ログ収集はtimeout、下位エラーの記録なし。同期時のLLDB表示だけでは原因特定不可。同じ候補の26.5のrows・高確度手動ケースが別ホストで実起動。SDK、guest、起動方法、期限、カードの全判定を維持し、別ホストでカードの元の1件を限定確認する。
- 限定43769812600 attempt 1 / 132982976246、893913d、Xcode 27.2、iOS 26.5 の手動3項目。ランタイム・所有端末の作成、build 95.7秒、bootstatus 89.4秒が成功。test-without-buildingで「Unable to find a device matching the provided destination specifier」、指定UUIDの実機候補0、汎用Simulator placeholderのみ、140.6秒後に終了70。XCTestケースは開始前。前回のMobileAsset再登録停止とは段階が異なる。
  N127/source1c331818と旧正式43748518096の指定UUID解決失敗、旧正式491・今回の準備/手動runnerを照合。汎用先を採用せず、bootの成功をXCTest成功の証拠にしない。今回の同一候補・同一SDK・実26.5で高確度手動（132976131804）と原本変更（132976131849）が端末上の操作まで完了。iOS 27.0の元の手動3項目（132976131821）も成功。N127と同じく、指定UUIDと実行identity・一回起動・元のケース・期限・成功要件を全て維持し、この限定の失敗ジョブのみを新規ホストで確認する。
- 限定43767607953 attempt 1 / 132976132038、6ee6857、SDK27.2・実guest 27.0.0 standalone notifications。testChangedDataProducesOneLocalNotification（95.649秒）とtestNotificationControlsAndAppearance（99.710秒）が同じNotifications.swift:112で停止。2回とも実スイッチ接触・on-binding・auth-request・auth-returnedはあり、requesting=trueのまま45秒後にvalue=0/disabled。採用/キャンセル/許可済みcallbackの記録なし。両ケースの開始、独立プロセス、実guest identityを確認。
  U18/U37/U39、N50/N231と旧正式のtest-app-ui/manifest/ワークフロー、現行の許可呼出しを照合。今回のguestサービス4個は稼働、windowはreturned=true・callback=false。実Allow接触記録なし。同じ通常試験は正式でA/B別VMの通常画面後に最後の独立Runnerで1件ずつ実行する。今回は同一の新規guestで通知2件のみを最初のRunnerにまとめた。U39の元構成へ合わせ、27の限定をA（使い方画面→実配信）とB（時間割カードのVoiceOver→許可/外観）に分け、各VMの通常画面の成功後に同じUUIDの別Runnerで対象通知1件を行う。SDK27.2・guest27.0・headless、スイッチ一回・実Allow・callback・保存・配信・45秒・外側1440秒を維持。順序が原因とは未確定、公開条件は変更しない。
- 空欄学年を含むrowsの独立実行43770853584 / 132986209498はiOS 26.5.0で368.963秒・失敗0。iOS 27.0も同じテストで成功。除外103行、実入力した学年2の反映と再起動後の再編集、曜日設定の保持を両OSで確認した。
- 限定43767607953 attempt 1 / 132976131939、6ee6857、SDK27.2／実guest26.5.0、手動1項目。外側1800秒の開始からXCTest開始まで1200.9秒（build 138.9秒、bootstatus 415.8秒）。XCTest側の3回の未確認→確認と実操作を観測。経過599.20秒に復旧画面のリストを探索中、外側の準備込み1800秒が終了124。その時点でXCTestのassertion失敗なし。
  N243・旧正式491と現行のios-release.yml manual-26の実コマンドを照合。正式は手動1/3項目とも元から準備込み2400秒/回収120秒/job45分。今回限定だけ短い1800秒/35分で実ケースを中断した。限定は正式と同じ予算・同じSDK/guest/所有端末・一回の全ケースへ合わせる。今回の599秒の途中経過は結果に合算しない。iOS27の同じ1項目は既に成功、過去のN243のように準備を監督の外へ移さず回収を維持。
- 限定43769812600 attempt 2 / 132992176457、893913d、SDK27.2・設定guest26.5、手動3項目ジョブはcancelled。GitHub check-runの注記「The job has exceeded the maximum execution time of 35m0s」。終了後のjob log APIは404 BlobNotFound。準備開始stepが最後の状態で、guest上のXCTest開始やアプリのどの操作まで進んだかは確定できない。
  N243の35/45分上限・注記あり本文欠落の記録、N127、実際の配布manual-26の準備込み2400秒・job45分を照合。今回は既に準備を監視に含めていたが、短い限定35分では終了部分を回収できなかった。既設のmacos-26 / Xcode26.6・SDK26.5の限定経路で、同じ26.5の手動3項目を確認する。この経路はゲストを同じに保ち、別世代ランタイムの導入を必要とせず、同じ実UI・厳密なID・1800秒/35分・一回実行を維持。先例はevents-source-follow-up-20261105の限定SDK26.5→正式配布SDKの手順。公開は正式SDK27.2・同一run/attemptの全検証に従う。
- 限定43776992716 attempt 1 / 133005417847、0187cd3、SDK27.2・実guest26.5.0、手動1項目。ManualAssistanceChecks.swift:32、設定タブ一回tapのあと45秒以内に選択されず125.234秒で失敗。fixture-readyを観測、_UITabButton上(320,800)にbeganが1件。タッチの終了や設定への遷移は確認できず、手動訂正画面到達前。準備込みtimeoutの前回とは異なる。
  U30/U63の初回タブ接触、旧実装4fb54a8/9ffdf0e、N213の実要素再取得と通常UIの現行ヘルパを照合。手動だけタブボタンの標準tapを使用していた。通常UIで使う一意のbar/button/icon・実枠包含・enabled/hittable・中心0.1秒接触を手動入口でも共用する。接触後は手動の現在の一意な設定selected・元45秒を維持し、押し直さない。両suiteは同一のQA用ソースからcompileし、正式アプリ・個別の入力/採用・期限は変更しない。元ケースを両OSで限定確認する。
- Linux Python3.12の新タブ候補1e863a2、全316件中、実Swift identityコンパイルがFileNotFoundError swiftc、一時期にSwiftを必要とする7件skip。構文検査時に使えたローカルtoolchainを置いた作業ディレクトリ自体が失われていた。iOSネイティブの成否と区別し、Swift 6.1.2を戻して全件を再度確認する。
  Swift 6.1.2を再配置し、実Swift構文とPython全316件を再実行。失敗0、環境依存skip 2件。共有タブ操作・両suiteへの登録、各ケースのselector/guest一致、未完了の拒否を含む。
- 正式492（43781992020、attempt 1、133022350723、f6c2dbd、SDK27.2／iOS27.0）。手動選択した高信頼欄のケースが270.070秒で失敗。最初の科目入力は18 bytes・想定文字列が保存され、確認はfalse。Input.swift:58で確認スイッチの条件が期限に達した。診断のambiguous=false、binding履歴に確認trueはない。設定タブの実アイコン接触と入力画面への到達は成功。発生箇所を切り分け中。
  N93/N155のcancelled、N167のendedだがBindingなし、N212/N239およびe11398dの元コードを照合。今回はbegan→ended 156msで同じ中心(331.67,672.67)、UISwitchに届いたがlongPress/pan状態0のまま。#112の除外・解除は一意な実UISwitchのつまみを左右に一度だけドラッグし、同じSDK・両OSで実値・保存を確認済み。手動確認でも枠完全包含・enabled/hittable、外側/内側とも値0を要求し、つまみから反対側へ同じ一回の水平操作を使う。各callerの元45秒、実値1・入力失効・保存・再起動を維持。アプリの確認を自動化せず、タップ再送・期待値注入は行わない。選択訂正の実ケースを配布SDKで両OS比較する。
- 正式492、f6c2dbd／43781992020 attempt 1、133022350751、SDK27.2・実guest27.0.0。原本変更の手動ケースで、設定タブ選択直後に実List/設定NavigationBarを照会中、XCTestが「com.apple.springboard crashed」を記録。開始94秒でtear down、424.920秒・失敗1件、確認スイッチや原本切替には未到達。所有する診断はcrashCause unassessed、該当するアプリのクラッシュ報告0。原因の下位分類は未確定。
  U76とN125、既存のcold launch、492の全手動caseが使う同じ設定入口を照合。今回は起動直後のsessionではなく実アイコン選択後のSpringBoard停止。492の単項目・三項目27は同入口を通過し完走。システム停止をアプリのデータ不具合と推測せず、次の正式実行でも専用guestの元ケース・変更前後の拒否・旧結果の保持・厳密な完走を必須にする。先の確認スイッチ変更についてLinuxの全316件（環境skip 2、失敗0）と459ファイルの一覧を確認済み。
- 限定43784845018 attempt 1、2f8b77b／133030064028、SDK27.2、実guest26.5.0。元選択訂正の最初の科目は一回のつまみ操作後に実値1（outcome=1、ambiguous=false）、確認画面も通過。プレビューから「教員を訂正」を開く後続処理がNavigation.swift:294で失敗（214.566秒）。実menuの表示・照会を調査する。先の正式492の科目確認失敗とは別段階。
  N237は科目Textの再取得を追加し、同じSDK26側で成功した。今回はその再取得・一意性・枠包含・hittableは成立。同じText中心(80,339)への接触はbegan→ended（wall 1.82秒）、観測したUILongPressは0でactionは現れなかった。wall時刻はUIKitの認識時間とは断定できない。実装8c8809eと現行のlinkContextAction、およびN242の適用範囲を確認。既存の実メニュー検査で使っている2秒のnative長押しを、確認した科目Textに一度だけ使う。N242のリンクで2秒でもprimaryActionになった記録があり恒常解消とは扱わない。認識後の45秒内に一意な実action・枠・操作可能性を要求し、全3呼出の対象・旧値保持・4項目拒否・再起動を維持。アプリのメニューを差し替えず、配布SDK両OSの元ケースを確認する。
- 正式493（43790567453 attempt 1、97640a0、133062139889）、SDK27.2／実iOS26.5の通常UI B。testSettingsAccountDataAndFileDetailsが169.715秒で失敗。実AI/OCRスイッチは再起動前のON→OFF→ONでUI・保存値・setterが一致。再起動後のOFF一回は内側の同じUISwitchにbegan→ended 7.94ms、45秒後もUI/保存1、setter記録なし。開始時は外側/内側とも1、包含・hittableを確認済み。通常27Bは完走。対処前の観測。
  N239（通常tapが5.58ms）、N212（0.1秒pressのcancelled）、8c8809eとe11398d/現在の実controlを比較。今回は50msの予約でも再起動後は7.94msでended、先3回の同じ操作は62〜94msでsetter成立。同一の45秒を延長しても設定が変わった証拠にならない。#112の行除外と#492の手動確認で両OSに通った既存の一回のつまみドラッグを、今回の失敗が観測された再起動後のOFFだけに使用する。最初の3回は通常タップのON/OFFも引き続き検証する。実UIと保存値の両方、再起動前3回・再起動後1回、disabled時の復旧拒否を保持。通知の実許可は対象外。両OSで同じ設定ケースを限定し、正式ゲートは元のまま実行する。
- Linux全体316件の一回は、AI操作を絞る編集中の作業ツリーで旧Python本文を既にimportし、新Swiftを読んだため、旧文字列（dragThumb: trueの直指定）を数える契約1件が0 != 1で失敗。確定した57e53b0の変更後契約では通常タップ3回と再起動後の一回のdragを要求し、同一版のmanifest31件は成功。全体も固定treeから確認する。
  固定57e53b0からSwift6.1.2を有効にして全316件を検証、失敗0・環境skip2（305.751秒）。正式493はその他の13事前ジョブ成功、通常26Bのみ失敗、配布は依存skipで終端。
- 限定43799291494 attempt 1／2d35d22、133075252210、SDK27.2・guest27.0。再起動前3タップでUIと保存のON/OFF/ONが一致。再起動後も画面・保存1だが、今回は接触前にNavigation.swift:204の操作可能な単一Switchの取得で45秒が経過し失敗（240.809秒）。つまみドラッグの配送前。先の493の接触後不変と別段階。
  N94/N97/N165/N174の詳細、以前の通常SwitchとcalendarのSwift実装を比較。実ログでt120.13秒から内側Switchのexists/frame/enabled等の再解決が続き、t155でretry。外側の行は取得済み。N174で一度のAX snapshotから属性を読み、同じ現在要素のhittabilityを別に確認する方式を、該当する子Switchだけに適用。内外の一意性・有限枠と包含・enabled・双方0/1の一致・現在のhittability・元45秒を全callerで維持。存在しない子のsnapshotは取得できず、推定座標や入力リトライは使わない。通知や除外の接触方法はそのまま。
- 正式494（43803666255 attempt 1、fc906af、133090438105）、SDK27.2／iOS27.0指定の通常UI B。実端末UUID作成に成功した後、build-for-testingの実行先解決（64.9秒）がexit 70「Unable to find a device matching the provided destination specifier」で終了。後のsimctlで指定runtime available、同じUUIDはShutdown。XcodeのiOS実行先一覧は27.2端末のみ。アプリのcompile・起動・XCTestは未実行。
  N127（440）、N76と今回のThreeFields失敗、以前のtest-app-uiと現行runner・Xcode27 runtime準備・ios-releaseを照合。N127はboot後のテスト実行先、今回はboot前のビルド実行先。493と494の該当runner/準備/正式workflow差分は0で、493の27B、同候補の個別27設定は実SDK27.2・guest27.0で成功。Xcodeの列挙結果とCoreSimulatorの観測が一致しないホストを記録し、待機や端末を緩和しない。494初回の残項目が終わってから、同じソースの失敗・依存ジョブを新しいホストで一度検証する。新試行で正式の全15条件を照合する。
- 正式494、同じsource/attempt、133090438160、SDK27.2／iOS27.0。原本変更の手動テストはtest build成功（105.0秒）。続く最初のsimctl bootでNSPOSIXErrorDomain code 2「cannot determine the runtime bundle」、XCTest開始前。回収完了。先の通常27Bの実行先解決失敗と別ホスト・別段階。
  N166/N176/N212のruntime消失と当時のrunner、現行の27準備・bootを照合。今回のiOS27は準備時に27.0を確認し、同一SDK・同じ準備コードの正式493で原本変更caseは完走。494のSwift／手動runner／PDF訂正差分は同caseに影響しない。27Bと同様に、同一ソース・新ホストで失敗ジョブを一度検証し、実起動とケース完走を要求する。特定のbundle削除やアプリcrashが原因とは記録しない。
- 正式494 attempt 2／43803666255、fc906af、iOS26.5／SDK27.2。前回停止した通常27Bと原本変更27は完走。通常26B（133131048912）と手動26の三項目・単項目・明示選択（133131048772/823/891）はXCTest前に同じ理由で失敗。Xcodeから取得した23F77のディレクトリ型exportedBundleを-importPlatformへ渡すと「Code=23 Requires elevated privileges: Copying a directory source requires sudo」、終了70。後始末は実行。資料解析や画面操作の失敗ではない。
  検索語「importPlatform／exportedBundle／Code=23／reclaim／sudo」。N220/N222/N226と当時の配布版8c8809eのprepare-ios26-runtime.pyを照合。過去は二重登録・回収が失敗したが、今回は所有assetの回収が通り、その後のディレクトリcopyが権限を要求した。select-ci-xcode.pyは事前にシステムXcodeの選択を検証済み。候補はmacOS Actionsで自分が取得した一意な非symlinkのexportedBundleを取り込む一命令だけsudo -nでシステムの/usr/bin/xcodebuildへ渡す。dmgは一般権限、権限拒否は即停止。登録・実build・guest・実XCTest・期限・後始末の検証は維持。権限がなければディレクトリcopyを拒否するfakeと元のワークフロー入口を検査し、正式SDKの26.5ネイティブ限定確認を経て全ゲートを実行する。
- 正式494 attempt 2／43803666255、fc906af、原本変更26（133131048791）、SDK27.2／iOS26.5。最後のジョブで23F77 import・bootstatusが完了したが、ManualAssistanceChecks.swift:68の最初のアプリ起動でXcode側がタイムアウト、ケースは172.336秒・exit65。原本変更の操作前。公開は依存skip。ほかの4台のCode=23とは別の観測。
  N95の同じ原本変更ケースの初回Xcode起動timeout、U40/U49/U59/N61/N72の比較、限定43767607953の記録と、8c8809eおよび現行の訂正起動処理を再読。現行は既にSpringBoard前景・枠確認後に一回だけapp.launchし、fixture-readyを必須とする。両OSの同じ原本変更ケースの過去成功があり、今回の一台では操作開始前の起動待ちで止まった。ケースや期限を緩めず、新規ランナーを使う次の正式検証の元ケースで確認する。権限修正側のPython全316件は262.822秒、失敗0・環境依存skip2。sudo拒否・dmg非昇格・異なるホスト・不正なexportも検証。

### #113 Linux ローカル検証の入力固定
- f75b0632を基点にした作業中の差分、Linux Swift 6.1.2、ParsingTestsの最初のローカルビルドで、SwiftコンパイラがChangeAnalysis.swiftの変更を検出して停止した。XCTest・シミュレーターは起動していない。
- 当時のtools/test-parsing.shは入力を別ディレクトリにコピーしてから検証する。今回は作業ツリーを直接コンパイルしていた。以降は確定したスナップショットでコンパイルし、実行中の入力は編集しない。

### #113 限定のグループ行選択（2026-11-17）
- 8b2f030、43904353745 attempt 1、SDK 27.2／iOS 27.0.0、job 133429070162。testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch は最初の3行目で、内外のSwitchの値0と包含を確認。一度のつまみdragで正しいUISwitch上のbeganのみを採取し、15秒内に実値1を確認できずChanges.swift:27で失敗（109.059秒）。以降の除外・反映・再起動には未到達。配送が途切れた原因は未確定。同じ実行の26.5は完走した。
- 同じ候補45fa1b2のLinux Python全316件中、UI契約が旧画面のtoggle/groupという2変数名を数えて失敗（223.332秒、skip 2）。他の315件にこの失敗はない。実UIの選択・解除・保存を検証する契約へ対応づける。
- 検索語は change-select-row、つまみ、testChangeRowsRequireSelection、Switch。N146/N212/N239・#112とe11398dの実Switch処理を照合。今回は入力のbeganだけで、過去のended/cancelledとは異なる。グループの対象行は複数選択リストのチェックマーク付き標準Buttonとし、選択解除も同じ行で操作する。XCTestは各ボタンを一度操作して選択traitの遷移を確認。個々の設定用Switchの実操作、期限、103行除外、取消、入力・再起動・再編集の条件は維持する。
- 7463efa8、限定43966956235 attempt 1、SDK 27.2。26.5（133648793607、342.824秒）と27.0（133648794022、442.531秒）がともに3行目の再編集でNavigation.swift:173の完全包含に失敗。選択Button、103行除外、反映取消・確定・最初の再起動を通過。「曜日を日付から補完」Switchの最後の枠がともにy728.33〜780.67、テストの可視領域y129〜769。前回の選択値0からの遷移失敗とは別段階。原因を照合する。
  両OSのAXで、モーダルの原本入力欄と背後のタブを確認。26ログの6回とも中央(196.67,449)が実際のUITextFieldに接触し、同じ行の枠が動かない。N47/N60の行き過ぎと違い、同じ位置のまま。N78/N80と現在のRecoveryの受動行ドラッグを参照し、行編集で既知の行が切れた場合は同じForm内の「原本」ラベルの観測枠から同じ距離をドラッグする。元の完全包含、6回の上限、内外Switchの状態・実操作・永続化を保つ。対象・受動ラベルを確認できない場合は成功にしない。
- 正式496、4899da2、43976182508 attempt 1、SDK27.2／guest27.0、133683186249。testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch は教員18 bytes入力後、確認Switchに一度のつまみドラッグを送ったが、元45秒以内に実値1を取得できずManualAssistanceChecks+Input.swift:57で失敗（516.147秒）。科目の先行確認は成功。これは時間割変更の行選択ではなくPDFの手動確認で起きた。下位原因を確認中。
  検索語はManualAssistanceChecks+Input、teacher、ACK、ended、N167、正式492。N167・492の詳細・当時の実装と現行のhelper・Bindingを照合した。今回は教員Switchの正しい実枠で315.67→347.33の横移動とbegan→ended（約88ms）、実UIは0、対応する教員ackのsetter記録なし。N167の中心押下とも、今回の行選択Buttonとも異なる。該当PDF画面・入力helperは0.1.495から差分がなく、先行する同一ケースの科目2回と同runの三項目・単項目は完走した。前版の同じ27選択ケースも正式43822495555の初回で成功している。操作・待機時間・確認条件は維持し、残ジョブを確認後、新しいrunnerでこの失敗と依存する正式ジョブを一度再検証する。ここまででは配布不可。
- 正式496 attempt 1／4899da2／43976182508、通常26B（133701099383）、SDK27.2／guest26.5。testNotificationControlsAndAppearance の「試験・返却」Switchで、接触前に外側のhittability照会が「Activation point invalid and no suggested hit points based on element frame」で終了した（Navigation.swift:212、148.381秒）。内側への操作・通知設定の切替はこの段階では未検証。正式27Bは成功した。
  N126/N160・U10のactivation point invalidと旧版のNavigation／現行を照合。496では完全包含検査の後で外側Switchの照会が失敗し、設定を切り替える前。最初の「時間割変更」はbegan→endedしており、二つ目のSwitchの操作失敗とは区別する。現象の出た通知経路はscrollLabelsを渡さず、UI操作・実許可・保存条件、該当Switchの内外確認は前版から差分なし。前版の同guestの成功と今回の27Bの成功があり、残ジョブの終端後にfresh runnerで元の通常26Bを含めて再検証する。原因を特定のシステム障害とは断定しない。
- 正式496 attempt 2、4899da2／43976182508、選択訂正26.5（133744324623）。SDK27.2でテスト用ビルド後、test-without-buildingが作成したUDIDの実行先を見付けられず、Xcode終了70。対象XCTestの開始・アプリ操作は未実行。初回の教員確認Switchの失敗とは別段階。初回の選択訂正27と通知26Bの再検証は両方成功。
  N127と限定43769812600、正式494の前後段階、当時と現行のruntime準備・test-manual-ui.shを比較。今回も同一UDIDでTEST BUILD SUCCEEDEDとbootstatus-completeの後、Xcodeが実行先を解決できない。今回のコード差分はランタイム準備・選択処理に及ばず、同じ正式試行の別hostでは同じ26.5を起動して原本変更ケースが完走した。Runtime・UDID・実XCTestの一致と期限を保ったまま、残ジョブ終端後に新しいhostで失敗ジョブを再検証する。

- #114–116、c062e23を基にした作業差分、Linux Swift 6.1.2、最初の解析検査。既定の別名一覧のテストは追加された任意2列を想定せず、固定参照例は一つのセルの「ZZ,ZZ」を2件に展開する旧仕様を期待して失敗した。別の物理行の重複は引き続き保持する。UI実行前であり、端末上の操作結果とは別に記録する。
- 次のローカル検査はSwiftPMがテストソースのビルド中更新を検出して中断。テストの期待結果には到達しなかった。以降は編集が完了した入力を一時ディレクトリへ複製し、その固定入力を検査する。
- 限定44018063646 attempt 1、b4e4c74、Xcode 27.2、iOS 26.5/27.0 各2組。4ジョブともSDK・Runtime準備を通過し、対象セレクター照合を含むステップでexit 1。実行ラッパーの開始・build-for-testing・XCTestの記録は一件もない。アプリの操作成否は未評価。
  セレクター／selectorで索引を検索し、直前に成功したc3750ec9の固定文字列照合と比較した。今回は配列の各要素の先頭へのシェル置換を導入していた。両OSのログとも比較からラッパーへ到達しない。候補修正では各ケース名を明示的に1行ずつprintfし、完全一致しなければ両方のセレクターを記録して停止する。ケース、Runner、実機種別照合、上限は維持する。
- fd13389（配布候補1efe34aと同じtree）、Linux Python 3、全316検査の再実行。test_all_source_tests_are_assigned_once_and_both_os_checks_are_required の件数照合で実値32、期待31。失敗1件、環境依存skip 2。iOS XCTestでの操作とは異なる段階。先行のPython結果は現行32ケースの結果を示していなかった。
  直前の正式版c062e23のSHARDSと件数照合、既存のmanifest失敗記録を比較した。元の31ケースは維持され、ホーム・週・一覧から同じ教室変更を開くケースがAへ1件追加された。契約は32件の完全一致に更新し、新ケースのAへの所属も明示的に検査する。実ソースとの全件照合、重複検出、両OSの必須ジョブ判定は維持する。
- 限定44019728566 attempt 1、10b30bee、SDK27.2／iOS 27.0、job 133826071825。testChangedRoomInHomeWeekAndList（167.169秒）とtestHomeTimetableAndWeekCalendar（93.477秒）は完走。testMergedCardsFromAllSources はTimetable.swift:74で「Merged lesson card has no unique visible hit region」、86.223秒で失敗。同じケースはiOS 26.5で完走。27の行修正・再起動も555.046秒で完走。失敗したカードと当時の画面状態を照合する。
  返却カードの実枠はx179〜243/y611.7〜757.7、タブ上端769で完全包含、同じ完全ラベルはグリッドに1個。通常・試験の詳細は成功した。返却カードでは述語開始t68.53から、ナビ・タブ・キーボード・フッターの別々のAX再照会だけでt77.74になり、同じ10秒の枠でhittabilityまで到達できなかった。旧43748518096の上下スワイプ往復と異なる。N165/N171と直前に両OSで成功したカレンダーのコードを照合し、同じ実AXスナップショットからナビ・可視領域と週グリッド内の完全ラベルの一意性・enabled・枠を読む。実ボタンのhittability、一度のタップ、高さ72超、4種類の詳細・科目、10秒の期限は維持。
- 3a7335bのUI検査変更後、LinuxのPython全316件の終盤にtest_every_shipping_ui_and_probe_selects_before_preparing_apple_resourcesがjobs(file)["focus"]のKeyError（189.747秒、環境依存skip 2）。この検査中に、同一チェックアウトを限定用ワークフローのブランチへ切り替えていた。
  直前の保存済み製品コミットには求めるfocusジョブがあり、限定ワークフローのジョブ名はapplicationだった。以前の編集中・ビルド中のソース混在と同様に、検査対象だけが違う。配布用のワークフロー検査はそのまま維持し、3a7335bを固定した別worktreeで全件を再実行する。
- 52644f57、限定44025045066 attempt 1、SDK27.2／iOS 27.0、133843234158。testHomeTimetableAndWeekCalendarはTimetable.swift:201のAX探索で「Timed out while evaluating UI query」、262.573秒で失敗。教室変更の3経路と4種の結合カードは同じjobで成功。26.5は全3件、同じ製品のAppleネイティブ744件は失敗0。どの操作の前に停止したかを確認する。
  タブ実アイコン接触・時間割のnavigation表示は成功。旧c062e23と同じ全画面button.firstMatchがt26.24で存在待ちを開始、t67.66/t98.97の再照会を経てt254.75で終了し、カードへの接触・週移動には未到達。同じソースの後続結合カードのケースは117.260秒で成功。N94/N165/N171と前の結合カードのAX記録を照合し、時間割グリッド内の実カードに対象を絞る。前回検証した同一スナップショットの可視領域・完全ラベル一意性・高さ・有効状態と現在のhittability、10秒内の取得、一回の物理タップを共用する。実詳細と教員、カレンダー、2つのドラッグ後の表示週の照合を維持する。
- 正式497、f47d58ee、44031490084 attempt 1、SDK27.2／iOS 27.0、通常27A（133865801019）。testChangedRoomInHomeWeekAndListがNavigation.swift:111のAX探索で「Timed out while evaluating UI query」、293.089秒で失敗。通常Aのこの区画では19件中ほか18件が成功。27Bと27の手動4件、配布検査、ネイティブは成功。26Bは実行中、依存する未実行ジョブは成功に含めない。どの画面・操作を最後に観測したかを確認する。
  比較はN165/N174、正式496の実AX照会と当時のNavigation、今回のvisible/contentViewport、限定44028700493の両OSの実ログ。正式でもホームと週からは前後・理由・日時を確認して詳細を閉じた。3経路目の一覧からは同じカード・教室と理由まで確認し、更新日時の実行時要素を取得した後、表示領域を再確認中にt104.42からapp.frameのsnapshotが応答しなくなった。t135.72/t166.77の再試行の後もsnapshot要求は長時間応答せず、ケースは293.089秒で終了した状況で、表示値の不一致やアプリの終了は確認されない。同じ製品・同じXCTestの直近限定では両OSで最後まで成功し、同じ正式jobの他18件にも同じ可視領域関数で成功したケースがある。実入力、3経路すべての表示と完全包含、期限、正式15項目は保ち、残りが終端後に新規runnerで同じコミットの失敗ジョブと依存ジョブを再実行する。
  正式497の初回は26Bも成功し終端。試行2では同じf47d58eeの通常27Aが成功し、元ケースは147.424秒で3経路の理由と更新日時まで確認した。依存していた通常26A・手動26の4件・公開も成功。前回のAX応答停止はこの試行で再発しなかった。

- 2026-11-17 #117 限定44107679134/試行1、ソース3261b604、配布SDK27.2。iOS 27.0のweek-change-detailsとtimetable-clocksはアプリのbuild-for-testingで停止し、テストケースは開始していない。両ビルドのログはWeekPullObserver.Probeの `center` を型CGFloat・非公開で宣言した行に対し、UIView.centerはCGPointでありoverrideできない旨を報告。iOS 26.5の2ジョブはこの記録時点では実行中。
  同じ診断文を持つ旧NSObject.hash衝突と旧版WeekPullObserverを照合。UIViewの中心座標と、今回追加した案内の高さは別の値。Probe内部の高さだけを `badgeCenterY` とし、UIViewの座標・引き判定・SDKや検査条件を変更せずに再ビルドする。限定の終日行事ケースでは、同じ架空年度内の隣週との往復を実ドラッグし、両週の日付・行事表示・実枠の高さも照合する。
  旧限定のiOS 26.5の両ジョブも終端で同じUIView.centerのコンパイルエラーを確認し、4ジョブともケース未実行。SDKの違いやアニメーション動作による失敗とは扱わない。
- 2026-11-18 #117 限定44109447185/試行1、ソース2c4862d5、SDK27.2。27.0のweek-change-detailsは3ケース中2成功。testHomeTimetableAndWeekCalendarは最初の授業カードを取得する207行目で41.056秒後に失敗し、カレンダーとドラッグには未到達。両OSのtimetable-clocksは終日行事週との往復・実高さと日付の検査を完走。補助計測は26.5で離した後のスナップショットのxが各往復で1値（478.17または−85.17）のみ、27.0ではサンプルなし。途中の移動の確認には至っていない。26.5のweek-change-detailsはこの時点で実行中。
  26.5でも最初のカード取得で39.995秒後に同じ失敗。27.0の失敗時AXは中央の日付が幅64pt・高さ232pt、グリッド上端737.7、授業カード上端791.3、タブ上端769。前回497の全画面検索停止と異なり、グリッドと実カードは見つかるが、元の完全包含条件を満たせない。テストの探索・期限は保持し、左右・アイコン・日付の内側で1行の実寸を測るガラスのボタンに改める。旧実装のフレーム計測は、SwiftUIレイアウトと状態更新が重なると開始位置を画面上で確認できなかった。新しい候補では、離した時点で安定したUIKitホストへ実表示を固定し、新しい週が配置された後、両レイヤーに同じ開始時刻と明示した始点／終点を持つアニメーションを設定する。計測は描画できるウインドウへの取付後に行う。
- 2026-11-18 #117 文字サイズ限定44110568912/試行1・ソース2fd912ee・iOS27.0/SDK27.2。4回のボタン実枠検査は成功したが、試行ログから各PNGを長さ・SHA-256照合して復元すると、標準・最小・XXXLはカレンダーアイコンだけ、アクセシビリティ最大は「11/16…」だった。読み上げラベルと枠の合格だけでは日付の描画を証明できない。候補では暗黙のLabelスタイルを使わず、実際のアイコンと1行の日付をHStackに置き、ガラス背景と内側余白を含めた幅で選択する。次の限定でも4段階のPNGを確認する。
- #117 限定44111522958・試行1、e943ab28、SDK27.2。iOS 26.5 / job134138112716 (131.059秒)、27.0 / job134138113143 (126.830秒) とも終日行事と通常週を往復する実操作1件は成功。その後の2記録の数は一致したが、最初の記録に描画サンプルがなく検査に失敗。OSの設定値自体はこのログから判定できない。
  44109447185の位置が定数またはサンプルなしの記録と旧WeekSnapshotを照合。SwiftUIの旧ラッパー生成時に測定を始めると、実描画に付く前に計測時間を使い切れる。新しい候補ではウインドウ上で両レイヤーにアニメーションを登録した直後から実際の位置と透明度を測る。同じSDKと実ランタイムで、通常の横移動とOSの視差設定時のフェードを別々に照合する。
- #117 限定44121543599・試行1、c12bf7e2、SDK27.2/iOS27.0、job134173938061。終日行事と通常週との実往復1件は141.206秒／失敗0。OSとSwiftUI両方で視差軽減true。最初の描画記録は開始0.229秒後に新旧のxがともに180.5、opacityが既に0/1の1サンプルのみで、0.15秒の途中を捕捉できなかった。実画面の中間表示の有無は未確定。日付4条件のjob134173937788と、授業・カレンダー操作3件job134173937094は成功。4枚のPNGを長さ・SHA-256照合して目視し、標準/最小は11/16〜11/22、XXXL/アクセシビリティ最大は11/16〜22を最後まで表示した。
  同実行のiOS27.0通常表示job134173953458でも往復操作は161.096秒で成功。前週方向は6点、翌週方向は開始0.024秒と0.292秒の2点で、後者の中間フレーム数が不足した。26.5通常表示job134173937800は両方向で位置と間隔を複数点で確認済み。両OSで授業・週選択・ボタン・短い/確定ドラッグを含む3件が成功した。画面合成と別のmain-threadコールバックで測った点数を実表示枚数と同一視せず、独立録画のPTSと位置・色も照合する。
  iOS26.5の視差軽減job134173938082はOS/SwiftUIがともにtrue、往復185.966秒で成功。最初の側で新旧opacityの中間値を2点捕捉したが、3点の記録数に未達。日付job134173938376の4枚も長さとハッシュを照合し、全条件で両端を目視した。独立録画44126837688・試行1、2a0d790bのiOS27.0/job134192823155では往復とも静止した位置で色が段階的に変わる実フレームを確認した。
- 限定録画44126837688・試行1、2a0d790b。iOS27.0通常job134192823529は実往復161.612秒で成功後、ホスト開始時刻から推定した範囲が録画の尺外で後処理失敗。iOS26.5視差軽減job134192823505は95.518秒、最初の時間割タブの一回の接触後もHomeが表示され、録画判定に未到達。U30と以前の26.5の初回タブ入力不成立を照合した。前回の同じ製品部分で往復した結果をこの録画の成功には数えない。追加診断の録画は最初のタブ操作後に開始し、両操作の実フレームは動画固有のPTSで調べる。正式のタブ操作・期限・受理条件は維持する。
- #117 正式498（44131175299・試行1、0cfc07b6）、SDK27.2/iOS27.0。手動訂正の高信頼4欄job134210760004、testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch、356.881秒でReview.swift:85「The source must have one real image containing its unique highlight」、exit65。公開前のため498はこの時点では未配布。表示範囲・画像・ハイライトのどの条件が不成立かは調査中。
  最初の科目では原画像・強調枠・スライダー・等倍・閉じるまで成功。2回目の教員拡大ボタンは(196.7,494)で入力の開始・終了を観測した。t295.45に画像一覧を照会、t304.91にdebug description、t305.29にAX階層要求。2回目の強調枠照会はログになく、画像の不在は断定できない。497の時間割と同じ、別々のライブ問い合わせ中に予算を使い切る条件を参照。対象のスクロールビューから一度のAXスナップショットを取得し、その階層で唯一の画像、その画像内で唯一の強調枠、両方の実枠・包含を確認する。拡大後も同じ方法と幅の増加を確認する。10秒の期限と物理タップは保持する。
  同じ正式498試行1の別ケース、iOS27.0/job134210760283、testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackgroundも417.224秒で同じReview.swift:85。科目拡大の実タップt402.31、t405.52で画像の子孫検索、t414.79にdebug description、強調枠問い合わせには未到達。二つの呼出元は同じinspectSourceを共有する。候補は科目・教員・教室に一つの観測方法を適用し、別々のケースとして正式検査へ残す。
- #117 限定44136034934・試行1、fc67a899、iOS27.0(24A434)/SDK27.2、job134225701853。端末内復旧の開始・一覧のスクロール後、t69.63の復旧ナビゲーション照会まで到達。実行中にCoreSimulatorが「runtime path not found」(401)を返し、終了時はdevice not booted (405)。ケース完走0、今回の原画像検査には未到達。正式494のN166/N176/N212と同様に準備・起動後のランタイム消失。検査の期待値・期限・SDK・アプリコードを保ち、新しいホストで実Runtimeを準備し直す。正式498で同じ箇所に止まった単項目と高信頼の両ケースを別ジョブで実行する。
- #117 正式499試行1（44144901590・d8cf7f10、SDK27.2/iOS26.5）、高信頼欄の手動訂正job134300135594。原画像の元の失敗箇所より後の、Navigation.swift:294「The opened popup must have one visible and operable action: 教員を訂正」で329.130秒後に失敗。ラベルを検索したが、ポップアップ表示・項目の存在・実枠・操作可能性のうち何が不成立かはこの観測だけでは未確定。
  一意な実科目Textの枠中心(79.83,355.83)に一回の2秒長押し。ネイティブ記録は(80,356)でbegan→ended、wall 3.431秒、採取したUILongPressの状態は両方0、_UITouchDurationは0→2。物理接触は届いたが、コンテキストメニューの認識成立や表示は確認できない。43784845018の0.6秒長押し、2秒を採用した限定と497の正式成功、現行の同一PDFRecoveryView/実Textの認識経路を照合した。今回は長押し時間を延ばさず、同じ製品・同じSDK/OS・同じケースを新しいSimulatorで観察する。期限後に画面階層を採り、失敗時のみAX上の開いているメニューとボタンを識別できるようにする。正式の認識条件と確認期限は維持する。
- #117 限定44162262957・試行1、7d63773b、job134318915197。SDK27.2でiOS26.5（23F77）を準備中、Appleのランタイムカタログ取得がMobileAssetError.Download code 53/DVTDownloadableErrorDomain 41となり、xcodebuildは70で終了。XCTest開始前であり、長押しの変化・成否は観測していない。
  N166/N176/N212の既知のruntime消失・選択失敗と現行prepare-ios26-runtime.pyを照合した。今回はSimulator起動より前の配信カタログに限定され、27.2で23F77の準備に成功した正式499の他の同OS検査もある。新しいホストで同じ正式カタログ・指定build・実テストを確認する。ソース、期待値、期限は同じ。
- #117 正式498/44131175299と499/44144901590、SDK27.2/iOS26.5の通常UI。498はA/Bとも60分のジョブ期限に到達。Aは最初の19件が1942.416秒で成功し、後続の独立通知が開始から約69秒で外枠により中断。Bは追加の文字サイズ3件目が28.832秒で成功した約0.86秒後に打ち切られ、runner末尾の照合へ進めなかった。499 B/job134280180069は準備後に通常4件のまとまりが597.199秒で完走し、後続の通知UI開始19:56:22Z、20:01:10Zに操作取消、ジョブ自体は20:02:39Z終了。個別の成功件数を全体成功に数えない。
  N217ではAのみ時間超過のため二つのケースを入れ替えた。今回の498は両方が上限で停止し、片方への移動で解決しない。成功した正式497.2はA55分46秒/B56分48秒で、ランタイム準備は3分03秒/4分31秒、498では8分55秒/7分40秒。499 Bは通知ケースの終了・別プロセスの文字サイズ3種・事後照合が残っていた。同じ対象OSの通常A/Bに限って、準備・複数プロセス・清掃を含むジョブの合計予算を80分にする。27側は60分。各操作の期限、ケース数、通知や文字サイズの独立起動、識別子照合と全件成功条件は変更しない。旧来のworkflow試験は4ブロック全体に60分が一箇所あることだけを見ていたため、OS/組別にそれぞれの合計予算を検証する。
  同じ499 A/job134289230845も20:06:57Zにcancelled終端。通常19件が2297.534秒で成功し、20:04:13Z開始の独立した通知1件も88.155秒で成功した。20:06:43Zに外枠の取消となり、末尾の回収・正式照合まで完了していない。両組のジョブ全体の完了には個別試験を終えた後の時間も必要なことを追加確認した。

- 2026-11-18 #118 ローカル候補（基準6dd809f3、Linux/Python、Actions未開始）。Python全317件は成功314・失敗1・skip2。`test_all_source_tests_are_assigned_once_and_both_os_checks_are_required` が追加2件後の宣言数34を旧固定値32と比較して失敗した。実iOSケースはまだ開始していない。既存ケースの欠落や重複の合否は、この固定数比較の失敗とは区別する。
  `assigned_once / 宣言数 / ケース追加` でN30・N106と直前の32対31の記録を検索し、登録一覧と旧固定数を照合した。今回は元32件を残し、実色と実移動の新規2件をBに各1回登録したため、固定総数を34へ増やし、その2件の所属も要求する。欠落・重複拒否と正式15ゲートは維持する。
- 2026-11-18 #118 引き継ぎ時に候補4af66eb3の未記録のLinux Swift6.1.2結果を確認。全648件・79.345秒、`testWeekBadgeHasClearanceOnBothEdgesAndInShortOrScrolledBodies` の36行目の包含判定が6回失敗し、他ケースは成功。ActionsとApple UIは未開始。短い表／縦スクロール途中の2領域、左右2方向、上下中央3点のどの入力で失敗したかは元ログに出ておらず、製品の配置とLinuxの矩形演算を分けて調べる。
  同じSwift6.1.2で12入力を個別出力し、原点y=250の6入力だけ包含APIがfalseと確認した。各矩形の4辺は必要な10ptの内側に収まっていた。`contains / CGRect / 矩形` で過去索引を検索したが同一のLinux矩形条件はなく、4af66eb3の配置式と今回の数値を照合した。製品の配置式と12入力は保持し、四辺それぞれを10ptの境界と直接比較する。9.9ptの包含による許容を広げず、各辺の失敗値も分かる検査とする。Apple実画面のガラス境界検査は別途維持する。
- #118 限定 [44219539602・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44219539602/attempts/1)、021acf4f、Ubuntu 24.04、source contracts job 134517683244。新規ブランチ初回pushの `before` が40桁のゼロで、テスト一覧が存在しないコミットを `git rev-parse --verify` して終了した。ローカルで同じ環境変数を設定して再現。正式のmain更新では公開済みの6dd809f3が比較対象で、今回の限定ではその値をイベントから受け取れなかった。依存のApple Nativeと両iOSのUIは未実行。
  限定ワークフローでは候補とmainの共通祖先を比較元とし、初回と後続のpush・手動起動で候補全体を検査する。チェックアウトは引き続き全履歴を取得し、祖先を求められない場合は検査を失敗させる。正式ゲートの比較元と成功条件は維持する。
- #118、24a7a01a、Linux Swift 6.1.2の `-typecheck`。架空UI記録器の `CGPoint(x: .nan, y: .nan)` をFoundationで型検査すると、CGFloatとDoubleの `nan` が曖昧になる。これはiOSの描画やジェスチャーの失敗を示さない。`nan / ambiguous use / 型推論` で索引を検索し、N67と既存の矩形テストの `CGFloat.nan` を確認した。今回は点が未取得の状態をOptionalで記録し、取得できた座標だけをJSONに含める。テストは引き続き座標の取得を必須とし、ダミー値を使用しない。
  同じLinuxで有効なCGPointを `[String: Any]` のCGFloat値として直接渡すと、FoundationのJSON化がエラー3840になることも確認した。既存のサンプル・矩形のDouble値に合わせ、releaseの二座標もDoubleを明示する。欠落時は値を記録せず、テストで検出する。
- #118 限定 [44233274298・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44233274298/attempts/1)、24a7a01a。比較元修正後のsource contractsは成功。iOS 27.0、SDK 27.2、job 134564514194はbuild-for-testingで生成した `ApplicationFixture+WeekMotion.swift:44:51` の `ambiguous use of 'nan'` を報告しexit 65。iOS UIケースは未開始。先にLinuxで型曖昧を分離して確認した箇所と一致し、947a3bbで実測点をOptionalとDoubleで記録する修正を送った。この時点のiOS 26とApple Nativeは継続中。
  終端後、iOS 26.5、SDK 27.2、job 134564514238も同じ箇所と診断でexit 65。両OSとも実操作前。Apple Native job 134564514192は749件、環境skip 1、失敗0で終端した。
- #118 限定 [44233800747・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44233800747/attempts/1)、947a3bb0。source contractsは成功。iOS 27.0、SDK 27.2、job 134566133971はbuild-for-testingのXCTestコンパイルで `ApplicationChecks+WeekAppearance.swift:119:32: 'gridMetrics' is inaccessible due to 'private' protection level` と報告してexit 65。直前のnan診断は出ていない。UIケースは未開始。iOS 26とApple Nativeの終端はこの時点で未確認。
  `gridMetrics / private protection level / アクセス範囲` を索引で検索し、同じアクセス違反は見つからなかった。N67のようにSwift構文検査は成功したが新しいXCTestターゲットの実際の型検査で拒否された。旧6dd809f3は同じ `ApplicationChecks+Timetable.swift` 内だけから取得する。別ファイルに置く新ケースにも既存計測を使うため、同じテストターゲット内に限って共有する。測定値、入力、必須のアサーションは維持する。
  終端後、iOS 26.5、SDK 27.2、job 134566133845も同じXCTest型検査でexit 65。Apple Native job 134566133809は749件、環境skip 1、失敗0で終端した。観測関数を同一テストターゲットに公開した b633489c は別の限定実行で両OSを確認する。
- #118 限定 [44234763926・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44234763926/attempts/1)、b633489c、SDK 27.2。iOS 26.5/job 134569488852と27.0/job 134569488864の両方がビルド・実操作に到達。色変更は26.5で195.807秒、27.0で314.395秒で成功。旧授業詳細の最初の選択は`Timetable.swift:196`、新規週送りは`WeekAppearance.swift:72`、旧文字サイズ・行事は`Timetable.swift:308`で失敗した。週送りはドラッグ前に止まり、release後のフレームは未採取。source contractsとApple Nativeは成功し、全ジョブ終端済み。
  両OSの階層に同じ `timetable-week-grid` が3個。`fixture-grid-metrics` も複数で、各要素の本来の値に代わり `2026-11-16` が付いていた。`accessibilityHidden / Multiple matching / children: .contain / grid-metrics` を検索し、過去の観測コンテナ追加、旧6dd809f3の単一ScrollView、b633489cでカスタムLayout全体に付けた値を照合した。各週に実コンテナを作ってその週の公開範囲を制御し、Layout全体から子の固有値へ伝播する週値を外す。日時の操作は従来どおり週選択ボタンから読み上げる。テストの一意条件、実タップ、実時間と余白の検査は維持する。
- #118 限定 [44238306393・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44238306393/attempts/1)、678686aa、SDK 27.2。iOS 27.0/job 134581146818は4件中、配色が171.830秒で成功。`Timetable.swift:196`の授業詳細（47.447秒）と`:308`の行事・文字サイズ（151.961秒）は引き続き複数の実AX要素で失敗。階層には空の隣週ScrollViewが2個と現週の授業ありScrollViewが1個。現週の授業枠はy603.7〜749.7、タブ上端769。計測のJSON値は復元したが、プローブは3個。`WeekAppearance.swift:96`の週送りは初めて実ドラッグと実測に到達し、指を離してから1ptを超える最初の動きが0.100955875秒で、既存0.10秒の上限を超えた（36.970秒、1回目の操作）。この時点でiOS 26.5は継続中。source contractsとApple Nativeは終端成功。
  旧6dd809f3の単一Grid、b633489cと今回の階層、既存の `testHomeTimetableAndWeekCalendar` の可視領域を照合した。週コンテナで隣週の授業は読まれなくなったが、ScrollView本体とfixture overlayは親の指定だけで除外できなかった。表示中の週からだけ実格子のラベル・IDを公開し、ScrollView自身に非表示を適用する。実測fixtureは同じ表示条件で1つだけ公開し、実値・一意判定・完全包含は維持する。
  `0.10 / release / display link / #117` で索引を検索し、旧#117の描画前に測り終えたケースと比較した。今回はpan終了からの計測で実際に0.10秒を超え、候補は準備位置に戻す初期化後の2回目まで待つ実装だった。次の描画コールバックでアニメーションを登録し、同じ期限・1pt・実サンプルを確認する。XCTest側でも座標の実測JSONを残し、失敗点と描画開始を照合できるようにする。
  iOS 26.5/job 134581146642も終端。配色は258.693秒で成功。授業詳細と計測は同じ重複で失敗。週送りは最初の実ドラッグまで進み、指を離して1ptの動きまで0.118459833秒で既存上限を超えた。両OSとも同じ修正と100ms条件で再検証する。
- #118 限定 [44241344073・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44241344073/attempts/1)、5868aae7、SDK 27.2、iOS 27.0/job 134591002719。元の授業詳細・カレンダー・短い/確定ドラッグ（105.054秒）、色変更（197.415秒）、source contractsとApple Nativeは成功。新規週送りは `WeekAppearance.swift:99` で上限100msに対し108.26275ms。releaseの元ページx=-46、初回3点はx=-63.3333で留まり、実際の横移動が観測された次の点は158.17425ms・x=-94、横移動の到着は393.8117ms。移動中の記録Yは元656、先642.667。休業週の既存検査は重複やJSON値のエラーを通過した後、`Timetable.swift:514` で第一曜日列x=31と時限列幅+間隔95が不一致。直前の通常週の文字サイズ切替と休業週の行事サイズ確認は進んだ。iOS 26.5は記録時点で継続中。
  旧#117の描画待ち、678686aaの初動、5868aae7で得た表示層と `UIScrollView.contentOffset` の違いを照合した。releaseの画面上の座標を保持するため表示層の `bounds.origin.x` から引き伸ばし量を求め、スクロール停止は移動元だけに適用する。遷移開始時の読み上げ階層の作り直しを避け、現在週の読み上げを週の確定まで保つ。画像は引いているときの実画素を撮り、PNG化と保存はフレーム採取の後に行う。元の100ms、実サンプル、逆行と余白の条件を維持する。
  `periodWidth / headerFrames / Dynamic Type` で索引を検索し、旧6dd809f3の単一ScrollViewと現在の等価な週ページを比較した。現在の生成fixtureはサイズ変更時に幅の状態と描画済みの実枠を別々に更新し、後者だけが変わっても週ページは同じ版として取り扱う。実枠を個別に観測するモデルから表示中の計測に通知し、描画した枠を確実に読み直す。xの不一致時にはその時の実測概要を記録する。列の比較式、許容差、実操作は保持する。
  同じ実測JSONの案内枠はy661.167〜706.833、可視領域はy656〜728で、上端の余白は5.167pt。100msの失敗で8ptの余白判定には未到達だった。左右の変換は一致し、表示領域で中央になる位置との差は8pt。旧新のList行とoverlayを照合し、ScrollView内からウインドウへ変換した可視枠と、ウインドウ上のoverlay原点で配置する。実画像と余白は同じ両方向で再確認する。
  iOS 26.5/job 134591002853も終端。最初の授業詳細・教員・詳細閉鎖までは成功し、`Timetable.swift:231`の週選択ボタンのhittability取得で `Activation point invalid and no suggested hit points`（83.099秒、接触前）。同じソースの27.0は全操作成功。N151/N126の別段階の症状と照合し、26.5のUI内部原因は未確定。単一の実枠、5秒、実際のhittability・一回の接触を維持する。色変更は178.901秒で成功。休業週は同じx31対95で失敗。週送りはreleaseから95.374msで最初の位置変化を捉え、移動先の非表示時x16から貼り付け時x297.667への逆向き位置変化を検出した。実画面の移動先はそこで初めて表示された。隣週を待機中から対応する画面外の位置に置き、実表示位置の逆行条件を2ページとも保持する。案内の上端余白は同じ5.167ptだった。全ジョブは終端済み。
- #118 限定 [44245631871・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44245631871/attempts/1)、06027138、SDK 27.2。iOS 27.0/job 134605090841は既存の授業詳細・カレンダー・短い/確定ドラッグ（81.015秒）、メインカラー（237.367秒）が成功。休業週の文字サイズ・列揃えは進み、`Timetable.swift:545`の実ドラッグ直後の照会で週ラベルがまだ出発週だった（139.863秒）。最後の入力の完了約0.2秒後に照会し、到着後までは観測していない。既存 `testHomeTimetableAndWeekCalendar` と同じ上限8秒で操作後の実ラベル更新を待ち、元のドラッグ・行事・サイズと復路の条件を保つ。
  週送りの新規ケースはreleaseと最初のサンプルがx=-63.333で一致、1ptの動きは68.016ms、逆行・Yとフレーム間隔の条件を通過。`WeekAppearance.swift:129`の余白で停止（33.630秒）。実PNGは長さ577008、SHA-256 f329d792df751e5dfeab0a31aa844e3aafe010b5921e5623034f65fb24ef16c2で復元し、右の案内の四辺を目視。案内枠y661.167、可視領域始点y656で上端5.167ptは再現した。前回のウインドウ座標への変換に加え、overlayのローカル座標をカスタムLayoutが受け取る非ゼロ原点へ変換し、測った中心に置く。実PNGと8ptの四辺の条件を維持する。iOS 26.5はこの記録時点で継続中。
  iOS 26.5/job 134605090764も終端。授業詳細・カレンダー・実ドラッグ（71.156秒）、配色（144.371秒）に成功。途中の列揃えは通った。27と同じ2件が失敗し、最初の動きは67.414ms、上端余白は5.167pt、休業週ラベルの判定も到着前だった。全ジョブ終端。通常とコンパクトの両方が余白内に収まらない場合はガラスを配置せず、縦だけでなく横も収まりの判定に使う。
- #118 Linux 17a7e76a、Swift 6.1.2／Python 3.12。カタログ462登録・素材とWeb PDF・Swift全648件が成功。Python全317件は環境skip 2・`TimeoutExpired` 2件。`test_passing_ui_completions_without_native_case_identities_fail_closed`の26模擬識別と `test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failures` のpartial-verifying-expired-ready。AppleのSDKや画面を動かす前段階で既存のサブプロセス時間枠に到達した。N156および先行の模擬runtime単独成功と照合し、Swiftビルドと並行した影響を切り分けるため、同じ期限・期待値でLinuxのPythonだけを再実行する。
- #118 限定 [44249872385・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44249872385/attempts/1)、f3d5136f、SDK 27.2。iOS 26.5/job 134617636283、27.0/job 134617636197は4件ずつ成功。ただし正式開始前の実測JSONの追加照合で、両OS・両方向の高さ調整に段差があった。横移動中と最終の移動先の授業開始Yは、休業週→通常週で約642.7、通常週→休業週で656pt。到着直後にそれぞれ832、466.3ptへ一度跳ね、約0.2秒かけて元のYへ戻った。見切れ対策・初動・横移動中のYの成功とは区別する。旧テストは水平区間の時刻だけを判定し、到着後の問題を検出できなかった。正式公開は開始していない。
  `高さ / 到着 / settle / horizontal` で索引を検索し、公開6dd809f3のList配置とf3d5136fの固定frame・高さへの暗黙アニメーションの組合せ、4本の描画データを比較した。現在の遷移内のLayoutが予約高を所有し、到着後は同じ0.2秒を描画更新ごとの実寸で進める。ページ自体の自然高と上端配置は保持し、List全体への暗黙の配置アニメーションを避ける。明示的な深い位置のはみ出し補正はSwiftUI/UIKitに委ねる。到着後から最終まで、同じ架空の通常・休業週で移動先の表示X/Yを照合し、横移動中は両ページの異なる実位置を要求する。既存の100ms・8pt・実操作と正式全15項目は維持する。
- #118 Linux 0bbb0249、Python 3.12単独の全317件、355.989秒。環境skip 2・エラー1。`test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failures` の `partial-verifying-stuck` だけがサブプロセス15秒で `TimeoutExpired`。既存の模擬ランタイムの検査で、Swift／実iOSは動かしていない。直近のe0a126f0単独全体は同じテストが成功し、今回はテスト・ランタイム準備のコードを変更していない。以前の `partial-verifying-expired-ready` とは別条件。模擬の期待値と期限を維持し、該当テストだけを同じ固定コピーで単独照合する。Mac限定は別に実行中。
  同じ0bbb0249の該当1件は、全模擬条件を含め155.065秒で成功。最初の全体実行のタイムアウトを記録し、限定やLinuxの部分再実行を正式公開の成功には数えない。
#118の正式ソース4e2852f1を固定したLinux／Swift 6.1.2／Python 3.12の全317件（457.619秒）で、既存の模擬ランナー2条件が15秒で `TimeoutExpired`、環境skip 2。`test_optional_hang_observer_preserves_phase_results_and_owned_cleanup` の `failed=True` では `test-app-ui.sh` の復帰前、`test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failures` の `partial-verifying-stuck` では `--hold-export` の復帰前に停止した。Xcodeや実Simulatorは使っていない。原因は未確定で、正式501のジョブ結果とは別の観測。

同じソースで両テストを単独で照合した。前者は4.290秒で両条件が成功。後者は157.030秒で `partial-verifying-stuck` の15秒停止が再発し、ほかの条件は成功した。0bbb0249以降、この模擬テストと準備スクリプトに差分はない。`rows-context` から通るランナー処理も同じ。期限・期待値は維持し、この結果は成功扱いしない。

### #118 正式501のiOS 27 Bが失敗（2026-11-18）

4e2852f1、run 44259503653、初回、SDK 27.2／iOS 27.0、job 134650684374。`Exercise app screens with synthetic data` が17:06:46 JSTにfailure終端。ケース・停止箇所・下位原因はログ照合前で未確定。Distribution、Apple Native、iOS 27 A、iOS 27の手動訂正4件は成功。iOS 26 Aは17:19:41 JSTから進行中。27 Bに依存するiOS 26 B、手動訂正26の依存skipを成功に数えず、残ジョブを取消せず終端を確認する。この時点で公開不可。

[27 Bの完了ログ](https://github.com/n624-dev/takupoke-ios/actions/runs/44259503653/job/134650684374)で、`testSettingsAccountDataAndFileDetails`（307.553秒）の `試験返却時間割` の状態見出しが `ApplicationChecks+Navigation.swift:196` の完全包含で失敗した。AXには一意の `material-state-section` があり、全6回と最後で枠y=165.0、viewportの上端y=165.00000000000006を反復観測した。変更詳細の下端切れとは別の段階。先行のメインカラー切替（168.598秒）と週送り（37.776秒）を含む基本7件は成功。通知と追加文字サイズへは未到達。描画欠損や操作未反映を示す結果ではない。

ケース名・`material-state-section`・完全包含・浮動小数点・物理画素で索引とカタログを照合。CI339の状態見出し（113.0と113.00000000000001）と `be3adf5` の物理画素境界補正を読み、U55・N239の設定Switch入力失敗、N47の目視できる部分切れと区別した。`4e2852f1` の製品設定画面と当該テストは公開500.1と同じ。Linux Swift 6.1.2で元の幾何8件に今回の165ptの観測を加えると、その判定1件だけ再現して失敗した（0.313秒）。物理画素の整数位置を求めると、元の座標の差は2 ULP、倍率を掛けた値の差は3 ULP。候補は物理画素の境界を取得した後、元の座標単位で2 ULPを比較する。既存の四辺の0.001画素・1画素の実際のはみ出し拒否と、UIの完全包含・操作・期限は維持する。

正式501の残ジョブ26 Aも18:17:55 JSTに `Exercise app screens with synthetic data` でfailure終端した。4e2852f1、run 44259503653、初回、SDK 27.2／iOS 26.5、job 134670604718。ケース・操作段階はログ照合前で未確定。公開ジョブは依存skip、全ジョブ終端、501の公開なし。正式502は別ソース67a758abで、19:10 JSTの確認時点ではDistribution・Native・27の通常A/B・手動4件が成功し、26側は実行中。

[26 Aの完了ログ](https://github.com/n624-dev/takupoke-ios/actions/runs/44259503653/job/134670604718)では `testChangedDataProducesOneLocalNotification`（95.119秒）が `ApplicationChecks.swift:130` の通知画面10秒待機で停止。新プロセスの `fixture-ready` と設定画面は成立。一度の通知ラベル押下は元の実セルで `began` と約161ms後の `cancelled` を記録し、AXは設定画面のまま。許可要求・更新通知配信に未到達。ケース名、`screen("通知")`、実ラベル押下、10秒からU75/N48/N172の詳細を照合。枠と停止段階は同じで、今回の下位原因は未確定。Geometryの境界補正はこの操作経路や期限を変更せず、先に開始済みの502で同じ元ケースの結果を確認する。

### #118 正式502のiOS 26側3ジョブが失敗（2026-11-18）

67a758ab、run 44273508763、初回、SDK 27.2／iOS 26.5。通常26 B（job 134723308781）は19:35:01 JSTに `Exercise app screens with synthetic data` でfailure。手動の明示選択（134723771891）と原本変更（134723772385）はそれぞれ19:44:26／19:21:52 JSTに `Exercise one manual case and require its exact completion` でfailure。詳細は完了ログ照合前で未確定。26 A・手動の三項目／単項目、27側6ジョブ、Native、Distributionは成功。全ジョブ終端・公開依存skip、502の公開なし。

通常26 Bは `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（32.902秒）。`ApplicationChecks+WeekAppearance.swift:102` で指を離してからの最初の実移動0.103381208秒が元の0.100秒上限を超えた。手動の原本変更は `ManualAssistanceChecks+Navigation.swift:243`、149.151秒。`manual-materials-list` の「通常時間割の詳細を見る」が16回の観測で操作可能な可視枠を得られなかった。明示選択はラッパーexit 124、到達段階の詳しい照合前。原因と3件の関係は未確定。

週送りの左方向は初期座標95.333ptが48.277、66.161、84.660msで変わらず、103.381msの点で126pt。到着332.992ms。反対側は初動84.437ms。`release`・100ms・描画コールバックを検索して678686aa、5868aae7と4e2852f1のログ・現実装を照合。いずれも実表示を観測し、今回は逆走の再現がなく、準備済みの位置から暗黙のアニメーションの描画待ちが残る。候補は横位置を最初の描画コールバックから直接更新し、表示層から得たrelease位置、移動元と移動先の共通進捗、到着後の高さ調整、Reduce Motionの短いフェード、元の100msを保つ。

原本変更では設定内の「時間割ファイル」の実タップ後、資料一覧を待つ16回すべてが `pending-list`。詳細行への接触・原本再照合の検査には未到達。`pending-list`・「時間割ファイル」・「通常時間割の詳細を見る」を検索し、N152の同じ入口の取消と照合した。今回は入口の実タップと一覧の不在を観測し、タップ取消やAX解決の下位原因は未確定。明示選択はprepared boot 411.3秒、テスト起動コマンドからケース開始まで603.0秒、ケース中は4件目の拒否文言と調整処理の完了まで到達。全体2400秒が再起動前に尽きた。枠・操作や2400秒を延長せず、今回長かったboot／Runner準備を限定実行で比較する。

原本変更の入力記録では同じセルの同じ中心（196.67,231.67）で `began` と0.2135秒後の `cancelled` を観測した。N152で追加した実identity・一意・完全包含・有効・操作可能は既に成立する経路であり、そのまま実Buttonの中心へ一度だけ50ms接触を要求する。既存の0.1秒要求に対する取消や短接触のN239比較を参照した。変更はこの手動4ケース共通の入口のみ。資料画面を開く判定、16回上限、原本・入力・拒否・保存・再起動の観測を維持する。

Linuxの手動project契約17件では、候補の最初の表記に `ownerID:` 後の空白があり、既存の文字列照合1件が失敗した（0.642秒）。識別子を保持し、呼出しを既存ファイルの引数表記にそろえる。実UI・アプリのコンパイルはこの検査の対象外。

### #118 直接描画候補の限定iOS 26が失敗（2026-11-18）

666a8a7、run 44292203433、初回、SDK 27.2／iOS 26.5、job 134759975291。20:27:51 JSTに `Observe release and landing frames, glass bounds and timetable layout` でfailure終端。停止したケースと下位原因はログ照合前で未確定。27側とApple Nativeは成功。手動の別限定44292318981は20:42 JSTで3件成功、残5件進行中、取消せず確認する。

26の週送りは `ApplicationChecks+Navigation.swift:24`（152.483秒）、一意・操作可能な「時間割」の実タブアイコン（222.833,780.333,29,25）へ一回接触した後も元45秒内に選択されなかった。事後AXは「たくポケ」／ホーム選択。週送りのドラッグ・計測には未到達。同じjobの休業週ケースは同じタブで正常遷移して成功（128.553秒）。U30/U77/N213と#117の限定44126837688、現行ヘルパを比較し、今回は実タブ入力の配送記録がない。製品・接触の位置や時間・元45秒・成功条件を保ち、週送りケースにも既存の実入力ログを付けて同じOSとSDKで比較する。SDK 27.2／iOS 27.0では週送り（72.948秒）と休業週（195.254秒）が成功。保存された両方向の初動は32.430ms／32.955ms、到着251.0ms／249.3ms、到着Xはどちらも16pt。

手動限定44292318981／試行1、666a8a7、SDK 27.2／iOS 26.5、明示選択の最後のjob 134760371446が21:21:47 JSTにfailure終端。残る7件は成功、全ジョブ終端。具体的な段階と原因はログ照合前で未確定。

完了ログで明示選択ケース自体が1144.584秒で成功し、21:20:57 JSTに実行完了・厳密なケース照合が通ったことを確認した。準備込みでここまで2327.5秒。成功後にもxcresult失敗・ゲストログ等を収集して29.8秒を消費し、回収shutdown中に全体2400秒でexit 124。再起動前に全体期限を超えた正式502とは到達段階が異なる。全体失敗を維持し、候補では成功時の失敗専用診断だけを省く。実入力の記録、実行・照合・後処理の失敗時診断、所有Simulatorの回収と全体時間は維持する。

### #118 正式503のiOS 27 Aが失敗（2026-11-18）

f5ddf28c、run 44311087289、初回、SDK 27.2／iOS 27.0、job 134827367982。23:04:11 JSTに `Exercise app screens with synthetic data` がfailure。具体ケースと段階は完了ログ照合前で未確定。同runの通常27 B・手動27の4件・Native・Distributionは成功、26 Bは継続中。26 Aと手動26は依存skip、公開不可。残jobを取消せず確認する。

完了ログで `testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates` は `ApplicationChecks+Navigation.swift:120` のAX snapshot照会timeout（339.979秒）、`testTimetableCommonClocksAndEventOnlyWeekScale` は `ApplicationChecks+Timetable.swift:536` の `Week grid is outside the viewport`（144.337秒）。個々の直前操作と表示は追加照合する。先行の配色・週送りは別の通常Bで成功（188.039秒／42.167秒）。Distributionは318件、Apple Nativeは749件（予定skip 1・失敗0）。

行事ケースは初回のホーム・境界週を通過し、再起動後に `fixture-ready`、ホームの選択とナビゲーションまで成立。`今日の予定` はexists後のfirstMatch.frameで再解決が31秒以上ずつ停止し、計約339.979秒で失敗した。対象句／snapshot／frameでU05、同ケースU09、再起動後のN153、N213の実identity・枠の再取得と比較。U09の境界注意文の不在照会と違い、今回は再起動後の実見出しの枠取得。候補はホームの実List内で見出しのAX identityと枠を一回観測し、範囲外・仮想化の場合だけ既存の有界スクロールを使う。行事・授業・表示と不在の全条件を維持する。

休業週ケースは通常・休業の文字設定3段階、日付・行事カードの寸法まで通過。初回ドラッグ前、標準文字へ戻した直後のgridと可視範囲の交差が230×30pt条件を満たさなかった。接触や週移動は行われておらず、当時の個別枠はログに出ていない。N47の部分行と過去の休業週の表示／移動の検査を比較し、短い週の実ScrollViewを既存の有界操作で表示範囲へ収めてから、同じ交差・実ドラッグ・8秒の到着・往復後の高さを検査する。失敗時は実枠を記録する。

503の最後の26 B（f5ddf28c、run 44311087289、初回、SDK 27.2／iOS 26.5、job 134856989448）は11月19日00:07:00 JSTに `Exercise app screens with synthetic data` でfailure。該当ケースと段階はログ照合前で未確定。全ジョブ終端、公開skip、配布なし。別の正式504は00:45 JSTでNative、Distribution、27の手動4件成功、通常27 A/Bは継続中。

503の26 Bは独立通知ケース `testNotificationControlsAndAppearance`（251.798秒）。新しい通知専用Simulatorで一度目の `app.launch()` がXcodeのtimeout。所有ログのアプリpid19152では `fixture-ready` まで到達したが、テスト側の起動復帰・通知操作には未到達。`Xcode起動・fixture-ready・通知` でU58と6ee6857の限定43767607953を比較し、後者と同じ「アプリ内到達とXcode返却の不一致」を確認した。アプリの起動条件、期限、押し直しの有無を変更せず、先に開始済みの504を観測する。

### #118 正式504のiOS 26手動2ジョブが失敗（2026-11-19）

151e00e4、run 44327865622、初回、SDK 27.2／iOS 26.5。明示選択（134925706804）は01:28:22 JST、原本変更（134925723424）は01:46:41 JSTに `Exercise one manual case and require its exact completion` がfailure。具体段階はログ照合前で未確定。26 B・単項目／三項目、27側全6件・Native・Distributionは成功、26 A継続。残ジョブを取消さず確認する。ここでは公開不可。

原本変更はbootだけで1041.4秒、Xcodeの実Runnerが接続を確立する前に `Test crashed with signal kill before establishing connection`、exit 65。実ケースの開始・アプリ操作・原本照合に未到達。`Runner bootstrap／signal kill／boot` でN55の接続前停止と比較した。明示選択はboot452.8秒、開始前に全体約1458秒を消費し、XCTestは約942秒の時点で成功プレビューと4項目拒否を確認後、採用操作前に全体2400秒へ到達しexit 124。ケース成功後の回収で停止した44292318981とは異なり、成功時の診断短縮が有効になる段階に未到達。旧502と同様、準備を含む外側期限で止まったことをログで確認し、操作や期限を変更しない。

両ケースは同じ製品コード・手動UI・SDKで、直前の26.5限定（原本変更44292318981、明示選択44304589147）は完了と回収まで成功した。現在の失敗が接続前の終了と長い準備を伴い、内容のassertの失敗に達していないこと、およびN127でGitHub attempt API自身が同一source/run/新attemptの全必須結果を返したことを根拠に、504の全残結果の確認後、新しい所有ランナーで失敗ジョブを一度再実行する候補とする。同一の正式ゲート15件を維持し、前の試行を手作業で合算しない。

初回の26 Aは01:51:53 JSTに成功し、行事155.833秒、休業週153.568秒、通知145.113秒を含む全ケースを完走。全ジョブ終端、公開skip、保存artifact 0。02:10 JSTに同一ソースの失敗ジョブを再実行し、GitHub APIで同じrun IDの `run_attempt=2` と `head_sha=151e00e4…` を照合した。

正式504の試行2も全18ジョブ終端・公開skip。全結果がattempt 2・同じ151e00e4であることをattempt APIで確認。SDK 27.2／iOS 26.5の明示選択（134983047826）は02:32:56 JST、原本変更（134983047865）は02:36:34 JSTにfailure、詳細はログ照合前で未確定。初回の失敗を解消済みとは扱わない。

試行2では明示選択が実行390.347秒で「教員を訂正」、原本変更が254.760秒で「架空原本のハッシュを変更」の実ポップアップ項目を操作前に特定できず、両方 `ManualAssistanceChecks+Navigation.swift:294`。初回のRunner接続・外側時間切れとは異なり両ケースは実操作へ進んだ。実項目の不在／無効／枠ずれ／重複の内訳をログから照合する。

明示選択は現在の一意な実StaticTextに2秒を要求し、中心(80,364)で実接触began→ended（wall 4.480秒）。UILongPressは両端で0、_UITouchDurationは0→2、指を離した後に完全ラベル照会を反復したが項目を観測できなかった。長押し認識の成否やポップアップの表示を示す証跡はない。N237の0.6秒、#117の499の2秒、497.2と直前限定の成功を現在の実Text再取得と照合。候補は同じ実Textの中心に同じ2秒の座標長押しを一度だけ行い、XCTestの暗黙の接触点解決を明示する。既存の入力計測でtouch/event時間とUILongPress設定も記録し、認識不成立とAX取得不成立を区別する。製品のcontextMenu、長押し時間、回数や操作後の検査は維持する。

原本変更は「架空検証」への一回の接触後、元の3項目が各exists照会で実在を返した。その後の対象再列挙と個別の枠・ルート・Button照会が、約t156からt201まで続き、操作は行われなかった。U14は枠250×42取得後の即時操作不可、今回は同様の候補があっても詳細観測が期限内に完了していない。U14の4292872、N165/N171と43767607953以降の単一スナップショット経路を比較した。候補はtoolbar操作後に3つの実タイトル、対象の一意性、枠・有効性を同じAX取得で確認する。現在の実Buttonのhittableが成立した場合のみ一回タップし、観測の最終段階を失敗時に出力する。プレビュー訂正にも同じ判定を使う。既存45秒と元ケースの採用・拒否・保存・再起動条件を維持する。

Linuxの生成project検査では、生成先で元のXCTestファイル名を探したコマンドが空入力をSwiftへ渡し、case構文は検査されなかった。project生成自体と、ソース側の当該ファイルの構文は成功。索引の「生成／Swift構文」から先行候補のsourceとprojectを区別し、今回の生成器はXCTestをcheckoutの絶対パスで参照することを確認した。生成したアプリ3ファイルと参照される本体4ファイルを明示して構文を確認する。

限定44365635983・試行1、4f8d9163、SDK 27.2／iOS 26.5。明示選択job 135018486942は11月19日03:26:52 JSTに手動実行stepがfailure、03:27:13 JSTにjob終端。03:35 JSTに原本変更は両OS、単項目は27.0で成功、残4件継続と確認した。明示選択の今回の停止段階と下位原因はログ照合前で未確定。残ジョブを取消さず確認する。

限定26の明示選択は154.791秒で `ManualAssistanceChecks+Review.swift:90`。最初の科目の原画像を開く実Buttonに一度接触し、(196.67,494)でbegan→ended（touch時刻差66.7ms、wall 91.0ms、取消なし）。既存の10秒内で `manual-source-scroll` のネイティブ解決を一度開始し、約9.2秒後に内部再照会・期限到達。ScrollView解決後の画像・強調枠・拡大や訂正メニューには未到達。シートが表示されなかったか、表示後のAX解決が遅れたかはこのログだけで未確定。27の単項目は同じ入力・画像・再起動を773.820秒で完走、原本変更は26.5／27.0で285.516／347.396秒。

ケース名／原画像／強調枠／ `manual-source-scroll` で#117の498、d8cf7f1、前段の409d0f9を照合。旧498は実ScrollView内で画像の再探索中、今回の26は同じ範囲を限定する入口の実ScrollView解決中に停止した。アプリスナップショット一回から一意な同じ実ScrollViewを取得し、その子の実画像とその中の強調枠を同じ観測で判定する候補。原画面の実Buttonと一回の接触、10秒、画像と枠の一意・包含・拡大、等倍、終了、各caseの採用・拒否・保存を維持する。

### #118 正式開始前レビューで週選択とスクロールの差を確認（2026-11-19）

候補56a141e、公開500.1の6dd809f3と実コードを静的に比較した。Actionsは今回はまだ起動していない。旧 `moveWeek` は境界を再検査し、長押し解除時に選択を書き込む。現在は横移動と高さ調整の後で確定し、途中の `onDisappear`・版変更・視差設定変化では選択を書き込まず破棄され得る。旧 `.id(weekStart)` で再作成された横ScrollViewも、候補では隣週を維持するため元の末尾位置を再表示し得る。元テストは現在の大型横スクロールを往復で観測していなかった。画面での頻度は未確認。

`週／中断／先頭／スクロール` で失敗索引を検索し、#117の終日行事週の拡大・短い週の限定、502/503の初動・縦位置・実枠を再読した。今回は表示途中の破棄と移動後のスクロールのため、初動や短い表だけの再現とは異なる。候補は、中断時には同じ移動元と現在も到達可能な行き先を照合して、受け付け済みの週選択だけを確定する。明示的な現在週や日付選択は優先し、前週・翌週やPickerは受け付け済みの変更があれば先に確定して参照する。送出後のみ非表示ページを先頭へ戻す。従来の行事フッターの単独List表示と文字サイズはそのままにし、移動ページの縦安定に必要な埋込時だけ余白と区切りを持たせる。元の時間・見た目・行事の照合を維持する。

候補のLinux生成で `instrument_week_motion` が旧内部代入 `selection = value.destination` を探して停止した。iOSのコンパイル・実操作には未到達。旧コードとfixture位置を照合し、同じ停止・確定箇所の実コールへ挿入点を移す。release／到着／終了・実位置の記録と未一致拒否を維持する。

週限定44381575880・試行1、d1b81494、SDK 27.2。26.5のjob 135074915911と27.0の135074916503がそれぞれ04:53:39／04:42:00 JSTに表示・操作stepでfailure。Apple Nativeは成功、全ジョブ終端。停止した実ケースと段階はログ照合前で未確定。

26.5の週送りは46.916秒、WeekAppearance.swift:177。左方向の幅361ptで、releaseの移動元x=-63.333と同じ14.811msでは隣の実ビューが可視境界x=377の外にあり、理論の開始座標297.667との差79.333を画面内のフレーム差として計上。25.481msでは移動元-91・移動先270で、両方が同じ27.667pt分移動。32.172msでは-142.333／218.667、到着後は16pt。100ms、実際に表示された二枚の同方向移動、終点・縦位置・高さは検査を通過した段階まで確認。27.0の同caseは36.215秒で成功。両OSの追加した大文字往復はTimetable.swift:533、文字設定・枠を読んだ直後、仮想化されたカレンダーのlabelを直接取得して停止。横ドラッグ前で位置リセットは未確認。

`週／仮想化／フレーム差` で既存の503・504と44297474407時点の記録・生成fixtureを比較。新しいケースでは既存の有界可視化でカレンダーを表示して現在と方向を読み、横ドラッグ後の同じ週を実見出し日付で照合する。描画では画面外にある初期の隣週は移動元が元の位置に留まるときだけ許し、表示領域に入った全フレームで両ページの相対距離が実viewport幅と一致することを要求する。release由来の位置からの1/5以下、100ms、実表示中4点、逆走・到着・高さの従来条件は維持する。製品の移動はこの試行から変更しない。

週限定44387511020・試行1、03683ca7、SDK 27.2。27.0のjob 135095979533は05:17:29 JSTに表示・操作stepでfailure。26.5（135095979305）は05:29:50 JST成功、Apple Native（135095979012）も成功、全ジョブ終端。27の停止ケースと段階は完了ログ照合前で未確定。

44387511020の27.0は元の連続描画が44.952秒で成功。広幅往復は67.128秒、Timetable.swift:539。実カレンダーの可視化で先頭へ戻し、metricsの存在を待つ一回の縦swipe後、AXから読んだgridとbodyの交差幅は0pt。元の230×30ptを満たさず、横接触は行われていない。26.5は同じSHAで描画41.707秒、時計・休業週・大文字往復205.484秒が全完走。保存artifact 0。

503の短い週の初回ドラッグ前に、既存の有界可視化を用いて実枠を得ると両OSで成功したコードを照合。今回は最大文字の縦に大きい表であり、ScrollView全体の完全包含は要求できない。最初の現在曜日の実見出しを同じ有界可視化で表示し、その後に同じ表の交差、見出しの日付および物理ドラッグ・往復を確認する。失敗時の実枠を記録する。見出しや高さの期待値、ドラッグの距離、公開ゲートは維持する。

### #118 正式開始前レビューで実ポップアップ操作のidentity差を確認（2026-11-19）

候補44d9fed、現main151e00e4からのコード比較。まだ正式Actionsを起動していない。候補は同一snapshot内の項目・枠・有効性を確認後、labelの再評価が可能な実要素にhittableとtapを委ねた。元の `allElementsBoundByAccessibilityElement` に比べ、再生成時に別の同ラベル要素を操作し得る。以前の504試行2の複数AX照会とU14を照合。先行の一回のAX観測・元3項目の同時確認は残し、最後に同ラベルの実identityを一意に束縛して型・枠・有効性を一回の実snapshotで照合し、現在もhittableであれば同じ実identityだけを一回操作する。元の45秒と全原本・採用・保存条件を維持する。再生成の頻度と今回の下位原因は未確認。

### #118 正式505のiOS 27 Bが失敗（2026-11-19）

d9918b45、run 44407326157、試行1、SDK 27.2／iOS 27.0、job 135168256057。07:32:57 JSTに実画面stepがfailure、07:33:07にjob終端。07:38 JSTにDistribution、Native、27手動の原本変更・単項目・三項目は成功、27 Aと明示選択は継続。元の失敗ケースと具体段階は完了ログ照合前で未確定。この試行では公開不可。残りを取消さず確認する。

正式505の27 Bは `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（35.356秒）。WeekAppearance.swift:186の高さ途中の観測間隔で0.1000518秒が既存0.09秒を超過。右方向は到着0.250539秒、横の全点・同時表示・往復yとx=16ptは通過。高さはt0.31534で606.333、t0.34904で535.333、t0.38187で398.667、t0.48192で316.333、完了後251.667pt。左方向は同段階を通過。実時間はreleaseから計測しており、記録間隔が計測器のcallback不在・不足・表示停滞のどれに由来するかは未確定。配色162.304秒、時間割／週カレンダー88.141秒、リンク231.596秒と他の既存Bの7ケースも成功。後段の通知・文字設定は組の失敗により未到達。

`高さ／フレーム間隔／DRAW` で#117の44111522958・44121543599の記録間隔と、502以降の実表示測定、504、限定44387511020と現在の `WeekPagesLayout` を比較した。現在は外枠の予約高さを既に持っていても旧週の自然高を毎回照会し、配置では全週の自然高を毎回再照会してから改めて配置を依頼する。候補は既知の幅と予約高さから外枠を決め、全週を既知幅・自然高のまま配置する。整列、待機、近隣の公開元データと実測レイアウト／準備、一回だけの高さ調整、90msの観測条件は保持する。再現していない下位原因は確定としない。

正式505の27 A（135168256201）も07:53:09 JSTに実画面stepがfailure、d9918b45・試行1。全job終端、公開skip、artifact 0。元 `testChangedRoomInHomeWeekAndList` が341.684秒、Navigation.swift:111でAX snapshot timeout。ホーム・時間割側と詳細の閉じる操作を経て、3番目の一覧のボタンを探す現行ヘルパが実NavigationBar、TabBar、keyboard、footerを別々に照会。ナビゲーションの初回再解決はt104.48、予備診断のroot照会がt105.64から約31秒ずつ停止した。一覧側のタップ・詳細の照合には未到達。残る基本18件（広幅時計・休業週226.769秒を含む）と27手動4件が成功。明示選択1106.109秒。後続通知・VoiceOverは基本失敗で未実行。

`教室変更／Navigation.swift:111／AX snapshot` で#117の44019728566およびN165/N171、503の再起動後見出しと共有visibleを比較した。今回は時間割の教室変更詳細を閉じた直後、同じ時間割内の変更一覧でのAX探索。製品の表示不良や入力の配送失敗は記録から未確定。既に開始した木5359b47の正式506で同じ既存ケースを確認し、同じ段階の結果に基づいて対処する。

### #119 保存・取消しのLinux追加試験がコンパイルで停止（2026-11-19）

5359b477を基点にした未コミット候補、Linux x86_64／Swift 6.1.2、ローカル試行2。`testLegacyAmbiguousWeekdayExclusionsCanBeConfirmedAndSavedAfterReopen` の228行で `XCTAssertEqual` が `ChangeAnalysis: Equatable` を要求し、テスト実行に未到達。既存の `ChangeAnalysis` は `Codable`。旧版の取消しに関する既存テストと同じ永続化経路を使い、保存前後の比較にキー順を固定した保存形式を使う。以前の解析結果を全項目照合する検査は維持する。

### #119 最初の限定CIでテスト用アプリが初回起動時に終了（2026-11-19）

d6bc639、run 44439254857・試行1、iOS 27.0.0／SDK 27.2、job 135275715625。生成・コンパイル・Simulator起動は成功。`testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups` は最初のアプリ起動後、Running Foreground待機中に `jp.n624.takupoke.app-checks crashed`（113.891秒）。設定・原本差し替え・実UIの検査には未到達。終了の下位原因と26.5の結果は調査中。

### #121 Linuxの鮮度境界比較で秒未満の期待値が不一致（2026-11-19）

d6bc639基点の統合候補、Linux x86_64／Swift 6.1.2、最初の統合試行。`testMetadataTTLIsTwelveHoursOrSixtySecondsWhileCheckingAndRejectsClockRollback` の74行。元成功時刻は秒未満.842、fixtureの次回試行可能時刻は.000で、後者を先に採るコードだった。日時の秒未満はXCTest出力に表示されず、実際のwireと旧キャッシュの比較を行った。次回可能時刻が先になる場合と、それより24時間の観測期限が先になる場合を別々の入力で照合する。

#119の同じ試行のiOS 26.5.0（135275715201）もコンパイル成功後、初回起動の `seed-enter` で終了（37.776秒）。N112の初回初期化を照合し、当該fixtureの `MaterialWorker.open()` と2回目の `openLibrary` が同じ排他ロックに到達することを確認。現行の `flock(LOCK_EX | LOCK_NB)` は二重所有を拒否する。取得ワーカーが先に開いた同じライブラリで保存し、実ファイル差し替え・実画面の行数・採用・取り消し・再起動は維持する。修正限定のレビューは差分 `b9eb4ed0396cad2278aca20823b187ca1befd191e18c445720831dce55271820`、GPT-6.2 Sol/High、指摘なし。

### #120・#121 Linux行事モデルの形式型検査で停止（2026-11-19）

d6bc639基点、追加のLinuxモデル試行、Swift 6.1.2／FoundationNetworking・OpenCombine・Swift Cryptoの一時コピー。`SchoolEventsModel` が状態要求用の `SchoolEventsFormat` へwire検証前も扱うoptional形式を渡し、2箇所のコンパイルエラーと後続の型推論エラーで処理開始前に停止。既存のv1/v2本文のdecode境界、以前の記録でraw形式を照合するコードを比較した。保存済み本文に対応する状態要求形式は `SchoolEventsSourceTarget` の既存のv1旧形式互換境界から取得する。元のリクエスト形式の一致判定・応答検証は維持する。

限定開始前のコードレビューで、冷間起動の半期切替ではカウントダウン表示がまだ空のため、私有通知を外した全体照合が公開行事・個人予定の通知まで削除し得ることを確認。通知の処理自体は起動していない。既存の通知所有者・半期移行の順序を比較し、処理世代を先に無効にして待ち、学内由来の識別子に限って取り消す。また独立した状態取得が本文の再試行待機を飛び越える経路を確認。前景の不一致回復は本文の通常1時間を越えてよいが、本文失敗後の既存待機を継続し、必要な回復は期限後に引き継ぐ。

### #120 Linuxの配布検査が編集中のUI一覧を読み込んで停止（2026-11-19）

3c24aa2基点の作業枝、Linux Python 3.12、配布検査の最初の試行。`test_all_source_tests_are_assigned_once_and_both_os_checks_are_required` が追加した実通知ケースを未登録と判定し、`test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs` が旧取得の選択と途中で変更されたmanifestとの不一致を検出。318件中1失敗・1エラー・予定skip 23、219.927秒。現在の入力を照合すると通知ケースの実ソース・正式B・限定入力がすべて登録済みで、検査の開始後に編集中の作業木を別プロセスが読んだ。期限・全件照合は維持し、次の配布検査は固定した候補の別作業ディレクトリで走らせる。

実通知の限定開始前に既存のテスト配置とOS許可の寿命を照合した。新ケースを通常Bへ置くと、iOS27で既存の通知ケースより先にOS許可を付与できる。起動前の検査であり、実行はまだしていない。既存の通知ケースを同じRunnerで先に実行し、新ケースはその後に置く。単独の限定では実際の許可ダイアログを確認する。画面遷移だけで許可待ちを終えず、実予約の報告まで待ち、固定した登録の2つの識別子とOSの許可を個別に照合する。

### #120 Linuxのカウントダウン接続の型検査で停止（2026-11-19）

f5ca2a7のカウントダウンと学校行事モデルを対象にした追加のLinux型検査。Swift 6.1.2、通知フレームワークの型だけを一時置換。`CountdownModel.swift:175` で任意の `pdfAnalyses` の添字にoptional chainがなく、製品以外のApple接続の型確認より前に停止。`HomeTodayView` の同じ時間割投影入口を照合し、通常時間割が未取得でも試験資料を判定できるよう同じoptional chainを使う。f5ca2a7の限定は開始済みであり、取消しはしない。

[限定44443673963・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44443673963/attempts/1) のiOS27.0.0（135290462665）と26.5.0（135290463296）、f5ca2a7、SDK 27.2は、どちらも同じ `CountdownModel.swift:175:76` のoptional添字でコンパイル停止。02:22:48／02:30:04 UTCにエラーを観測し、画面操作には未到達。全ジョブ終端。同じoptional chainを適用したLinux追加型検査と行事・カウントダウン46件は成功した。通知フレームワークの置換は補助検査に限り、限定でネイティブ実機能を再検査する。

### #120 固定候補のLinux配布検査で通知Runnerの失敗注入が未発動（2026-11-19）

095999f、Linux Python 3.12、固定worktreeの試行。`test_failed_final_notification_batch_is_not_rescued_by_passed_scenarios` の26/27で期待exit 1・実値0。318件中2失敗、予定skip 23、215.570秒。U40/N07/N162と旧Runner、現在の新通知ケースが既存ケースの後に同フェーズで選ばれることを比較した。検査用の偽Xcodeは旧ケース一件だけの完全一致で失敗を注入していた。旧ケースが含まれる同フェーズへ失敗を注入し、元の開始順序、二件の正確な選択と順序、全体停止とシステム文字検査未到達の条件を維持する。製品と実通知Runnerは変更しない。

### #120 未取得を想定したUIで既存の年度データが自動移行（2026-11-19）

095999f、run 44444947806・試行1、iOS 27.0.0／SDK 27.2、job 135294712860。build・起動・設定の学校行事への遷移が成立。`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent` は60.687秒、Navigation.swift:39の「学校行事を取得」が存在しない段階で停止。実AXは現在年度の取得済み、本文更新確認、本文最終更新、元PDF確認中、元資料確認日時、「学校行事を更新」を表示していた。カウントダウン操作と通知フェーズは未実行。N96/U73の可視行やN163の入力待機と比較した。今回は取得ボタンが隠れた状態ではなく、共通fixtureが最初から現在年度のv1を保存し、そのv2自動移行も成立した状態。初回取得を検査する `--countdown-calendar` の初回fixtureだけ共通の学校行事保存を省く。他ケースと再起動時の保存、実取得・確認日時・差異・UI操作は維持する。

開始前レビューでfixtureの共通初期化と保存寿命を再照合した。`SchoolDataRetention.replace` は公開行事と個人予定を保持するので、正式Bで直前の別ケースが保存した架空行事も残り得る。初回の `--reset-fixture` とカウントダウンの初回取得flagが両方ある場合に限り、所有するテスト用行事・登録ファイルを消す。再起動では両方を保存したままにする。通知取消しの新検査は、既存の別通知に加えて別の登録の二つの実予約を対照にし、当該登録に限る取消しを照合する。

同じ固定実行のiOS26.5.0（135294712500）もbuild、実起動、学校行事への遷移と本文の確認日時まで到達し、81.046秒で同じ存在判定に失敗。実ツリーは更新ボタンを表示した。カウントダウンの編集と通知はいずれのOSも未実行。既存の合否条件を維持し、次回はそれぞれを独立して両OSで確認する。

### #120 独立限定iOS27でメニューと通知照合の検査が停止（2026-11-19）

ae5f4a3、[初回取得限定44447514495](https://github.com/n624-dev/takupoke-ios/actions/runs/44447514495/attempts/1)・試行1、iOS27.0.0／SDK27.2、job135303154919。build、起動、実手動取得ボタンの接触、設定のカウントダウン管理、追加Menuの一回接触は通過。実AXは「自分で入力」Buttonを一度解決した後、通常List向けの共通tapヘルパが画面の縦swipeを行うと項目が消失。Navigation.swift:39、80.170秒。入力・保存には未到達。N96/U73の通常List可視化と、#118の実ポップアップを別に照合。追加Menuの項目は本文Listの範囲から探索せず、現在表示された実Buttonを一意に束縛し、アプリ内の正の実枠・有効・hittableと同じ要素の一回tapを確認する。通常のtapヘルパや期限は変更しない。

[通知限定44447518238](https://github.com/n624-dev/takupoke-ios/actions/runs/44447518238/attempts/1)・試行1、同source／SDK／iOS27、job135303165835。管理から元の詳細を開き、通知設定オフを表示。最初のOS照合Buttonの一回tapは実際に `照合中` まで到達したが、15秒内に結果が表示されずNotifications.swift:256、62.002秒。スイッチ・許可要求・予約は未実行。SpringBoard等4サービスの稼働は確認できたが、保留リクエスト取得と設定取得のどちらが返らなかったかは未採取。N50/U18の許可要求後の未返答とは異なる段階。OS読み取りを分け、最初の無許可・未予約の確認は既存設定と実pendingを使い、再予約の判定は実OS許可と件数の両方を維持する。

同じ通知限定のiOS26.5.0（135303165662）は最初の実pending 0件、対照0件、許可falseを観測した。次の「編集」Buttonへの接触後、10秒以内に編集画面に遷移せず、ApplicationChecks.swift:135、147.954秒。実ツリーは元の予定詳細と左下の観測パネルを表示した。N96の行可視化と観測パネルの旧hit-testing記録を照合し、テスト用ラベルと背景を受動にする。検査の操作は既存の有界可視化で詳細にある実編集ボタンを見せて同じ接触と期限を使う。通知26で照合は成立したため、27で返らなかったSDK段階の原因は確定していない。

iOS26.5.0の取得限定（135303154628）も同ケースの「自分で入力」Buttonを開いた後の通常List用探索で停止、112.384秒。初回取得は両OSで到達した。両独立実行は全終端。通知の候補では元の許可用コールバックブリッジを更新通知処理と共有し、予約希望がない段階の許可API照会を省く。予約の検証はネイティブpendingと許可の回答を別々に観測し、初回0件・許可後の各2件と一つの対照・取消し後の0/2/1を保持する。Linuxで既存通知ライフサイクルの実コード抽出試験4件、生成projectとSwift構文、カタログ466は成功した。
[初回取得限定44450320512](https://github.com/n624-dev/takupoke-ios/actions/runs/44450320512/attempts/1)・試行1、53e4c5f、SDK 27.2。iOS 27.0.0（135312370319、209.669秒）と26.5.0（135312370600、198.703秒）は、初回取得、手入力と行事選択の追加Menu、各保存、別名の行事を一覧から開くところまで通過。詳細で `架空の分割試験A` の完全一致StaticTextを探す可視化が、Navigation.swift:196で両方停止。診断の末尾は詳細リスト下部で、別名と日時、確認中、通知設定を表示していた。再起動と差異確認には未到達。

[通知限定44450370059](https://github.com/n624-dev/takupoke-ios/actions/runs/44450370059/attempts/1)・試行1、53e4c5f、SDK 27.2、iOS 27.0.0（135312526369、81.947秒）。詳細が開き、`予約を照合` の実操作で `保留予約を取得中` へ変わった。15秒で実件数が返らずNotifications.swift:258で停止。今回分離した表示から、最初の未許可のOS pending読み取り段階と特定できた。許可要求、予約・取消しは未到達。

初回取得の両OSについて、U69の当時の設定検査と現在の予定詳細の `LabeledContent` を照合した。今回の末尾の実AXにも「自分用の名称、Fictional exam alias」の結合ラベルがある。予定詳細で複数区間の2行目と公表名のラベル・値を同じ実行で照合する。表示・値・可視枠は維持し、名前と日付の保存、再起動、別名維持、差異の確認も省略しない。

同じ通知限定のiOS 26.5.0（135312525944）は171.158秒で成功。初回の実0/0/0、カウントダウン設定の実Allow、実2/2/1、再起動後の2/2/1、対象解除後の0/2/1が成立。両限定とも全ジョブ終端、保存artifact 0。N50、U18、43767607953の通知単独と通常Bの段階を比較。iOS 27の次の限定は、正式Bと同じく既存VoiceOverの後で、既存の実通知許可・保存・外観caseとカウントダウンcaseを同じ通知Runnerで実行する。iOS 26の単独成功と別記し、既存許可やカウントダウンへの実操作を注入せず、全ケースの実結果・期限と後始末を維持する。順序と27のOS未返答の因果は未確定。
[初回取得限定44453272343](https://github.com/n624-dev/takupoke-ios/actions/runs/44453272343/attempts/1)・試行1、032631e、SDK 27.2。iOS 27.0.0（135322134204）は247.823秒で完走。iOS 26.5.0（135322133666）は149.943秒で、初回取得、手入力・保存、再度の追加メニューまでは成立。第二項目「学校行事を選ぶ」を一意の実Buttonとして束縛して一回標準tapした後、行事選択画面へ遷移せず、Navigation.swift:196で行事の行を可視化できなかった。最終の実AXは管理画面で、保存した個人予定が表示されていた。第二の保存・詳細確認・再起動には未到達。

[通知文脈の限定44453291004](https://github.com/n624-dev/takupoke-ios/actions/runs/44453291004/attempts/1)・試行1、同sourceとSDK、iOS 27.0.0（135322196250）。`testVoiceOverReadsTimetableCard` は実時間割と見出しまで到達し、最初のAX moveForwardがCode 3（103.893秒）。通知Runnerを開始しなかったため、新規通知caseの結果はない。SpringBoard・VoiceOver・通知サービスの稼働確認は得たが、時刻範囲の診断は未返答。

追加メニューの配送はN237の実メニューとN系の位置束縛、現在のタブと通常NavigationLinkの相対接触実装を照合した。26で止まった標準tapを、同じ一意の実項目の採取済み枠中央への0.1秒接触1回で比較し、両項目の遷移先画面を実行直後に要求する。操作後の行取得・保存・再起動・注意の各条件は維持。iOS 27では標準tapでも同じアプリコードと元ケースが成功した。

VoiceOverはU66/U74の既存ケースの `moveForward` の失敗と一致し、iOS 27での直前の通常Bの構成と現在の実見出し操作も照合した。次の通知限定は、既存設定画面caseで通常操作を経て、同一guestの通知Runnerで既存の実通知許可・外観とカウントダウン予約を検査する。今回の限定からVoiceOverを外すのは初回予約まで観測するためで、正式BのVoiceOverと全条件は維持する。
[通知文脈の限定44456348152](https://github.com/n624-dev/takupoke-ios/actions/runs/44456348152/attempts/1)・試行1、e0d355d、SDK 27.2、iOS 27.0.0（135332186453）。既存設定caseは429.318秒で成功。同じguestの通知Runnerは既存 `testNotificationControlsAndAppearance` に進み、実Allow、OS callback、通知設定と色の保存を観測。既存caseで青の保存直後の再起動に入った時点で、準備込み限定全体1440秒が満了した。XCTestの検査失敗は未観測で、カウントダウン通知caseは開始前。巻き取った所有Simulatorの回収が成功し、保存artifact 0。

N243と43767607953の準備込み外側上限、現限定側の `timed_command` と正式 `simulator-27-b` を比較した。今回の既存設定と実Allow後のcallbackに停止はなかった。正式Bは従来の60分枠で全通常phase・実VoiceOver・旧通知・新カウントダウン通知を実行する。限定の上限を理由にケースや個別の期限を変えず、本番製品差分が同じまま、正式実行でiOS 27の新予約・再起動・取消しを判定する。
[正式44459819127](https://github.com/n624-dev/takupoke-ios/actions/runs/44459819127/attempts/1)、7dc8438、job135343585410、04:44:07 UTC終端と、[README更新後の正式44462333213](https://github.com/n624-dev/takupoke-ios/actions/runs/44462333213/attempts/1)、e4ed117、job135351855384、05:06:16 UTC終端。ともに試行1、LinuxのDistributionが318件中2エラー・22環境skip。`test_manual_input_lifecycle.py` は実ソース抜粋をコンパイルするSwift fixtureで、79行目の起動試験では `updateCountdown` の定義、131行目の背景試験では `homeClock` の定義が見つからなかった。どちらもSwift実行前のコンパイルで停止し、macOS各jobと公開は依存skip。別実行のLinux試験で両caseが走らなかった理由と、今の製品・fixture・過去記録を照合してから修正する。

N21の98a1dfbのテストと現在の `ApplicationData.activate`・`updateCountdown`・`setFileMonitoring`、直前のLinux Distributionログを比較した。以前のローカル一式では、SwiftがPATHになく該当2件をskipしていた。Swift 6.1.2をPATHへ追加すると、修正前のf10ce53でも同じ2件を再現した。入った時刻・前景と背景の分岐・元の原入力/画像/レビュー保持と消去を検証し、製品コード、テストの選択、期限は維持する。起動fixtureには `updateCountdown` の実メソッドを含め、依存fixtureで実時刻の受け渡しを観測。背景fixtureでは時計の状態を観測する。変更後の対象4件がLinuxで成功した。
[正式44465270899](https://github.com/n624-dev/takupoke-ios/actions/runs/44465270899/attempts/1)・試行1、1e173b3、macOS／Xcode 26.6、Native PDF and recovery tests（135362675445）は05:35:33 UTCにfailure。実 `testActualEventsModelCachesProjectionAcrossReads304FailureAndStoreReload`（SchoolEventsAPITests.swift:59–67）で、200で更新する段階の結果が旧題名のまま、投影回数1・世代不変。再起動後の期待値も不成立。1ケース7 assertion失敗。配布テストと先に終わったiOS 27の手動4件は成功、通常UIは実行中。対処前に実fixtureとv2移行後の要求形式、既存の失敗記録を照合する。

54fee3dの `refreshInBackground` は毎回本文を取得して個別の失敗を画面用フラグへ通知していた。現在の自動更新は最終正常本文確認から3600秒、失敗時は保存済みデータを保持して再試行を待つ。旧fixtureは実時間を進めず、`/source-status` の照合も拒否していた。本文304→3600秒後の新本文200→3600秒後の503を注入時計で再現し、採用版hashを含む元PDF APIの応答を別に供給する。元の投影回数・世代・題名・永続化・背景失敗の返り値を維持し、本文の最終確認時刻と一時失敗時の無警告も確認する。Linux Swift 6.1.2の一時互換環境で旧fixtureに同じ7失敗を再現し、修正後のAPI・状態モデル33件は成功した。正式Nativeの765件中、失敗はこの1ケースに限られた（予定skip 1）。
[正式44471299753](https://github.com/n624-dev/takupoke-ios/actions/runs/44471299753/attempts/1)・試行1、d295d29、iOS 27.0.0／SDK 27.2 UI B（135382670878）は06:48:30 UTCにfailure。`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent`（138.128秒）、`ApplicationChecks+Events.swift:242` で「学校行事を選ぶ」Buttonの実 `isHittable` 取得時に `Activation point invalid and no suggested hit points based on element frame`。以前の同一UIコードの正式iOS27 Bと限定は通過した。最新のDistribution・Native765（予定skip1、失敗0）・手動iOS27 4件は成功。UI Aは実行中。

[正式44465270899](https://github.com/n624-dev/takupoke-ios/actions/runs/44465270899/attempts/1)・試行1、1e173b3、iOS 26.5.0／SDK 27.2 UI B（135382985848）は07:10:52 UTCにfailure。`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（50.054秒）、`ApplicationChecks+WeekAppearance.swift:99` で案内PNGの `Int` unwrapが不成立。移動計測値と描画の段階は原ログ・過去の#118記録および現在のframe記録を比較する。旧実行の残jobは取消さない。

iOS 27のメニューはN126/N160/U10の例と同じエラー文字列だが、今回は通常Listの操作ではなく、一意な浮動メニューの有効Buttonを解決したあと別の操作点を問い合わせる段階。以前の限定位と物理座標の接触結果を照合し、同一の実スナップショットで型、完全一致、enabled、有限の正枠とアプリ内の完全包含を確認する。その枠の中心への1回の実接触と実遷移を必須にし、固定座標、再接触、疑似操作は行わない。入力の受動記録を同ケースへ追加する。

iOS 26.5の `Int` は案内画像の `pngBytes`。ログの1方向目には実722524バイトとhashあり。2方向目の `badge` は空で、横移動のframeは取得されていた。#118の案内枠・実PNGと既存の観測挿入を確認した。旧観測は遅延処理が描画を試す前に採取済みとし、指離し、windowなし、drawHierarchyの失敗を区別できなかった。候補は実ready枠からdisplay linkで描画機会を一度待ち、実接触中だけウインドウを採取する。描画APIが成功するまで採取済みにせず、失敗時は次のframeで一度だけ再観測する。指離しと取消しで停止し、release測定からは分離する。2方向の実PNG・外枠・余白と全モーション条件を維持し、PNG未取得は失敗のまま。原因の下位分類は未確定。
[先行正式44465270899](https://github.com/n624-dev/takupoke-ios/actions/runs/44465270899/attempts/1)・試行1、1e173b3、iOS 26.5.0／SDK 27.2 UI A（135383212635）は07:30:04 UTCにfailure。元の `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`（120.364秒）で「学年が空欄の変更」の実入力後、「選んだ行に入力」の一回操作は記録されたが10秒内に「内容を確認・修正」への遷移を観測できず、ApplicationChecks.swift:135で停止。末尾AXのNavigationBarは「時間割変更」。具体的な配送・画面階層と旧記録を照合する。先行実行は全job終端、11成功・3失敗・4skipで公開skip。

末尾の別Windowには「学年が空欄の変更」が残り、6行目はSelected、テキストは実値1、ボタン枠y338–390。受動入力記録では中央(196.67,364.00)のbegan→endedが7.15msで、SwiftUI ListのCellHostingViewまで到達した。N160の操作点照会失敗とは異なり、一回の物理接触は成立した。過去の同ケースと通常行の0.1秒接触を比較し、実入力値、有界可視化、該当Buttonのenabled/hittableを確認して実枠中心へ0.1秒接触する。接触は各行1回、元の10秒以内の遷移と後続の確認・保存・再起動の条件は維持する。
[正式44486188488](https://github.com/n624-dev/takupoke-ios/actions/runs/44486188488/attempts/1)・試行1、e60ea07、iOS27.0.0／SDK27.2の手動原本変更（135431850945）は08:53:39 UTCにfailure。`testChangedOriginalCannotSubmitOrReplaceLastGood`（418.025秒）は初回の原本変更後の送信拒否、正常結果保持、再起動後の編集・確認、二度目の原本変更完了まで到達。二度目のプレビュー操作前、実List内の `manual-review-submit` を型なし・indexの列挙で問い合わせる `ManualAssistanceChecks+Navigation.swift:83` が約121秒でAX query timeout。二度目のプレビュー拒否と結果保持は未到達。配布・Native・手動27の他3件・27 Aは成功、残ジョブは取消さない。

`manual-review-submit`、`PopUpButton`、`allElementsBoundByIndex`、`UI query timeout` でN59・N94・N97・N203・N238とc059a9f／53b364fのNavigationおよび現行Review・Casesを照合。N203はPickerのindex列挙が止まり、実AX identityの単回取得へ切り替えた。N238で同じ訂正ボタンがPopUpButtonと報告されたため、型を固定せず、所属Listと専用IDで限定する。各探索で実AX identityを一度取得して、同じ要素の枠・ID・完全一致ラベル・Button/PopUpButton・enabled・hittableを照合し、既存の一回タップへ渡す。元16探索、表示枠、原本変更後の送信及びプレビュー拒否、正常結果保持、再起動を維持する。製品コード・README・正式ゲートは変更しない。これでAX停止全般が解消するかは未確認。

[正式44499001313](https://github.com/n624-dev/takupoke-ios/actions/runs/44499001313/attempts/1)・試行1、3fc31e1、iOS 27.0／SDK27.2の手動単項目（135475351166）が10:09:25 UTCにfailure。`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`（794.826秒）は前景・背景復帰、再編集、レビュー、実資料全体の採用、採用済みの保存証明、元プロセスの停止まで到達。SpringBoard前景と正枠の確認後、再起動の `ManualAssistanceChecks.swift:71` で `Timed out while launching application via Xcode`。最後の起動後の再読込判定は未到達。元の原本変更、手動3項目、Linux配布、Nativeは同じ正式実行で成功。詳細の起動記録・過去の同条件と照合する。残ジョブは取り消さない。

[先行正式44486188488](https://github.com/n624-dev/takupoke-ios/actions/runs/44486188488/attempts/1)・試行1、e60ea07、iOS26.5／SDK27.2のApplication B（135459480892）は10:23:14 UTCにfailure。`testTimetableUsesSystemTextSize`（75.161秒）が `ApplicationChecks+Navigation.swift:24` の `Native tab tap did not select its current control` で停止。配布・Native・27両画面・26 Aは成功。同実行は全job終端、公開skip。画面の実表示、接触と選択の段階、対象の端末作成経路を根拠と照合する。

単項目の再起動は10:04:50 UTCにXcode経由で開始。実fixtureの永続ログには新pid32376の10:06:59.133のinitとseed、10:07:05.385のreadyがあり、10:07:55のXCTest起動タイムアウトより前に別プロセスで準備完了している。クラッシュ一致0、OSログは上限で早期の記録まで。N95・N125・U65と43767607953の `testMergedCardsFromAllSources`、当時のlaunch helperと現行を照合。今回は採用後の二度目の起動で、同じreadyまで達した過去の例と同じく製品内停止の根拠がない。以前の全体e60ea07では同caseが成功。既存の一度のXcode起動・SpringBoard確認・保存と再読込を使い、別の所有27Simulatorの単項目限定で再確認する。期限、起動方法、結果の期待は変えない。

文字サイズの通常Runner分は19.449秒で成功し、新規通知用Simulatorでの最初の追加OSサイズ（extra-small）のみ失敗。実ボタン枠は189.83,773,95.75,54、その中の実calendar画像は222.83,780.33,29,25。実画像の1回0.1秒操作後もホームがSelected。operationのt24.95〜25.34に実Imageを再照会しており、配送時の点は未採録。U63の4fb54a8／9ffdf0e、U77のfd6e42cと現行のNativeTabActivation・文字サイズRunnerを比較した。以前に実績のある同じアイコン中心・0.1秒・一回を保持し、その場で観測した枠からアプリ座標を出して接触時の画像再照会を避ける。タブ画像の実型・一意性・実枠・包含、enabled/hittable、元45秒の実tab選択と画面の検査を保つ。文字サイズケースに受動配送記録を付け、同一Runtime／SDKで元の通常と追加3設定を確認する。製品コードは変更しない。

[正式44513210500](https://github.com/n624-dev/takupoke-ios/actions/runs/44513210500/attempts/1)・試行1、6bc3c18、iOS27.0／SDK27.2の手動明示選択（135524385063）は11:38:22 UTCにfailure。元 `testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`（232.060秒）は実アプリ起動とfixture-ready、TabBarの存在と結び付け、設定Button存在まで観測。t92.67から設定Buttonを同じTabBar下で配列として取得し直す `NativeTabActivation.swift:17` がタイムアウト。受動実接触0件のため接触点、訂正、保存には未到達。Linux配布、Native、原本変更、手動三項目は成功。先行正式の残ジョブと今回のジョブは取消さない。

`NativeTabActivation`、`UI query timeout` と `snapshot` でU63・U77・N174・N203・N213を読み、9ffdf0eの週タブ操作、6bc3c18の共有helper、現状の実snapshot幾何と照合。今回止まった再照会は旧アイコン再照会・押した後の未選択とは異なり、接触前で、新規のapp.frame読取りには達していない。候補は既存4096ノード上限の処理を使い、同一の実app snapshotからTabBar→指定の実Button→属する実Imageを一意に確認。現在の実Buttonを取得したもう一つのsnapshotで枠・enabled・全Imageの数、対象ImageのID・ラベル・枠を再確認し、実ButtonとImageのhittable、既存の中心と一回0.1秒を維持する。元のTabBarとButtonの各45秒、選択／実画面・保存と再起動の判定を保つ。繰り返しの存在・配列探索をこの入口から省き、実アプリの状態と訂正・保存の期待は変更しない。

[先行正式44499001313](https://github.com/n624-dev/takupoke-ios/actions/runs/44499001313/attempts/1)・試行1、3fc31e1、iOS26.5／SDK27.2のApplication B（135521078033）は11:52:55 UTCにfailure。同じ実行の26 Aと27 A/Bは成功、公開skip。`testLinkPreferencesSurviveRelaunch`（121.944秒）はお気に入り解除、再起動後の追加、実行のprimary tap（1795088327.230218）まで到達。loopback接続は+6.247秒と+18.620秒、後者のGET読了は+18.655秒、HTTP200／205bytes送信ログは+18.659秒。`ApplicationChecks+Settings.swift:527`の実本文30秒で停止し、最後のAXは実SafariのClose・127.0.0.1・進捗10%・IsPageLoaded=false。Closeと画面復帰は未試行。HTTP送信成功の詳細、WebKit側、類例を照合する。

`testLinkPreferencesSurviveRelaunch`、`BROWSER_FIXTURE`、`IsPageLoaded` でN161・N236・N242・43742821232を照合し、409d0f9と3fc31e1の通信処理・App Fixture・生成Safari境界を確認。旧単一接続の問題は現行の独立受付で修正済み。今回はGET読了から送信完了まで0.004秒で、実Safariの読込開始前後の遅れの内訳は未確定。次はこのケースの各実起動時にだけ、AppleのSafariServicesの公開prewarm APIを用いて同じ検証済みloopback接続を前もって準備する。トークンをfixtureのプロセス内で保持し、接続準備の開始のみ観測する。ブラウザ実画面・HTML・設定経路・解除と追加・一回tap・元30秒・実Closeと一覧復帰を維持し、本番コード、学校URL、公開ゲートを変更しない。[Appleの宣言](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/prewarmconnections(to:))

[先行正式44513210500](https://github.com/n624-dev/takupoke-ios/actions/runs/44513210500/attempts/1)・試行1、6bc3c18、iOS26.5／SDK27.2のApplication B（135564917850）は13:35:27 UTCにfailure。既に同じ実行の明示選択caseが失敗しており、公開skipで全job終端。新しい失敗は`testNotificationControlsAndAppearance`の112.329秒。設定tabとNavigationBar、実「通知」Button存在を確認し、行内の実「通知」StaticTextへ0.1秒接触を合成したが、`ApplicationChecks.swift:137`で実通知NavigationBarが10秒内に現れなかった。末尾AXは「設定」、通知Button枠16,577.3,361,52.3、ラベル枠32,593.3,32,20.3。通知許可・設定保持は未到達。先行3fcのSafari読込と達した段階が異なる。N48・U75・当時のSwiftと、今回の配送ログを確認する。
`NOTIFICATION_ROW`、`screen("通知")`、`phase=cancelled` でN48・U75・N172と44259503653の詳細、98838f2／f709367／6bc3c18の実helperを照合した。今回の実UIKit配送は(48.00,603.33)の元のセルのbeganから約283ms後のcancelledで、endedなし。44259503653も同セルでcancelled（約161ms）。N48の旧app-relative操作とは同一原因と断定できない。現410a588では先のタブ照会・Safariの修正を確認中で、この通知行入口は6bc3c18と同一。実通知ジョブの新しい結果を観測し、必要なら実配送を根拠に次の候補を選ぶ。通知機能、タブ、許可要求や元のテスト条件はここでは変更しない。

[正式44527990308](https://github.com/n624-dev/takupoke-ios/actions/runs/44527990308/attempts/1)・試行1、410a588、iOS26.5／SDK27.2のApplication B（135604907297）は14:27:36 UTCにfailure。元の`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（35.174秒）、`ApplicationChecks+WeekAppearance.swift:198`で109.6667ptの実隣接枠の移動が上限72.2pt（幅361の1/5）を超えた。2方向のPNGは各1回、幾何欠落0。戻る方向のt0.06445→0.081235秒でsource x123→232.667、target x−238→−128.333。最初の方向はこの検査を通過。手動3件、27 A/Bと手動4件、配布・Nativeは同じ正式実行で既に成功。26 Bの同一実行では連携カレンダー239.764秒、実Safari91.536秒、その他基本ケースも進行し、通知Runnerはこの失敗後のため未実行。残ジョブを取消さない。製品は#118公開後の週Gridと同じで、#122の作業は別。旧フレーム、初動、実コードを比較して原因候補を選ぶ。
`advanceSlide`、`A displayed frame must not skip a fifth`、`初動` で#118の678686aa・5868aae7・408c1673・5359b47と44249872385／44297474407および公開時の両方向の測定を照合した。現410a588は公開5359b47のGridと同一。今回の最初の実変位は戻る方向で0.06445秒時点の27.667pt、次の実枠で109.667ptを追加した。移動元と先の相対幅は361ptで、Y、到着位置、高さ、方向は通過。瞬間的な実表示更新の差を、旧的確なrelease位置・手動display callback処理と分ける。絶対のtargetTimestampへの一度の追いつきが起き得る現在の時間増分を、フレームごとに単調な実target時刻差を消費し、一度に最大30Hz一フレーム相当とする方式へ変える。通常の60/120Hzは経過時間と同じ尺、遅れた場合はそのフレームでの移動を抑える。製品で推奨する表示機会は現在の画面の最大周波数に合わせる。実初動、露出、横位置、逆行、1/5、Y、高さ、PNGの検査値を維持する。表示側が複数callbackをまとめた場合まで一実行で保証するものではなく、限定実画面で比較する。

同じ[正式44527990308](https://github.com/n624-dev/takupoke-ios/actions/runs/44527990308/attempts/1)・試行1、410a588、iOS26.5／SDK27.2のApplication A（135615767194）は14:57:08 UTCにfailure。元の`testMergedCardsFromAllSources`（47.654秒）は最初の通常授業カードの実タップ、詳細「授業詳細」・「通常の授業」・「科目、架空科目A」の表示まで成功。14:47:06に元の詳細NavigationBar中央から画面95%へ一回0.1秒下方ドラッグを合成した。元の10秒の消失待機で`ApplicationChecks+Timetable.swift:100`が失敗し、末尾AXでも実詳細NavigationBar（0,75,393,54）と同科目・背景の時間割を同時確認した。残り3種類の表示と閉鎖は未到達。実UIKit配送は当時のcase条件に記録がなく未確定。両UI A/Bの他ジョブを取消さず、同一実行の全8訂正・27A/B・配布・Nativeは成功。公開skipで全て終端。
`dismissLesson`、`waitForNonExistence`、`testMergedCardsFromAllSources`でN117、全体398・43748518096／44019728566とc815640／7f340c8／91f6b41／410a588の実helperとcaseを比較した。同じ実シートを一度下へ払う契約を維持する。今回は旧起動やカードの範囲確定を通り、元のドラッグ操作がNativeBarを何度も再照会した後でも実詳細が残った。配送不達か実panの競合かは不明。実app snapshotの一意の対象NavigationBarから、元と同じ実中央と同じ終点を一度読み取り、そこからアプリ座標で同じ一回のドラッグを送る。既存10秒の実消失、背景画面、4種類の見出しと科目は維持。旧失敗caseに既存UIKit入力観測を追加し、既にある`week-change-details`群を限定workflowの選択肢へ登録して26.5/27.0で確認する。製品と正式テスト登録・ゲートを変更しない。

[限定44549765427](https://github.com/n624-dev/takupoke-ios/actions/runs/44549765427/attempts/1)・試行1、a6d26f8、iOS26.5／SDK27.2（135650038289）は15:27:49 UTCにfailure。元`testNotificationControlsAndAppearance`は実通知画面、実Allowと許可callback、通知の設定／再起動と色保持を通過し、348.705秒で成功した。Xcodeも`TEST EXECUTE SUCCEEDED`、Runnerも実identityと1 XCTest完了を15:27:17に検証。15:27:29に外側の限定runner制限1440秒で終了124、所有端末のcleanupは完了。N243等の制限、正式26 Bとの差を照合する。
`TIMING timeout`、`1440`、`Verified native identity`でN243・43767607953・44456348152と当時の限定／現行の実workflowを比較した。今回は当該実通知caseの合否とnative identityまで確定した後の外側timer。正式26 Bは旧80分のjob枠で個別操作期限を維持し、この1440秒のラッパーを使用しない。限定jobの失敗と実操作の成功を両方残し、正式ゲートの成功には使用しない。対象操作が実際に完了しているため、同じ限定を繰り返さず正式の同一commit全15で改めて判定する。

#122の別作業ツリー、Linux Swift 6.1.2のUI生成／登録検査。生成projectは成功、Pythonの32件中 `test_all_source_tests_are_assigned_once_and_both_os_checks_are_required` の1件が38件と旧固定値37件の差で失敗した。今回追加した連続週送りの1件の登録以外に件数差がないことを元manifestと比較し、全件の一意性と両OSゲートを保持して固定値と新規ケースの所属確認を更新する。シミュレーターは未実行。

#122の次のLinux一式（318件、279.872秒）は `test_week_motion_observation_keeps_real_release_layout_and_animation_unchanged` だけ失敗。試験開始時にPythonが取り込んだ旧marker `motion.setTransitionTouch(week: week)` に対し、実行中の編集で書き換わったGridの現行ファイルを後から読んだ。generatorと実体が異なる時点の組合せだった。対象差分を固定し、旧観測を削らず対応済みの同一ソースで再検査する。

[週送り・黄色限定44501853677](https://github.com/n624-dev/takupoke-ios/actions/runs/44501853677/attempts/1)・試行1、0a6c313、iOS27.0／SDK27.2（135483385866）は10:22:46 UTCにfailure。配色は234.106秒で成功。連続週送りの新規ケースは4回のXCTest操作のイベント送出後、`ApplicationChecks+WeekAppearance.swift:115` の8秒以内に四到着と最終調整の組合せを観測できず、59.213秒で停止。各送出ログ時刻は42.68／44.23／46.19／47.96秒で、短間隔の実接触を確認できない。旧週送りケースは42.866秒で、高さ調整の連続枠間隔が0.114799秒で0.09秒上限を超えた（同ファイル277行）。Apple Nativeは成功、26.5は実行中で取消さない。両失敗の下位段階は観測ログと過去の同条件を読む。

連続ケースの実UIKit入力ログは初回から次まで1.800、1.751、1.781秒。4回ともグリッドの実HostingScrollViewにbeganが届いた。個別のXCUICoordinate操作の都度待ちが入り、短間隔を検証していない。テスト側で現在の実枠から4接触を1つのXCTestイベント列へ組み、個々の移動と指離し、到着、演出中の受付を観測する。テスト成否を反映するための製品変更や人工的なアニメーション延長は行わない。列の未達時は実受信値をログに残す。

旧週送りの実データは横到着0.248960秒、次の実枠0.363759秒、幾何欠落0。間隔0.114799秒は到着直後の一か所。#118正式505の同位置、408c1673の既知幅・予約高を確認した。今回の候補は到着で選択を書き込みつつ、調整の最中に不要になったページの破棄と枠窓更新を避け、横・高さを同じ表示コールバックで続ける。高さ調整中の次操作受付と、その時点の実予約高から始める条件を保つ。以前のフレーム0.09秒、Y、位置、案内PNGの要求を保持する。

同じ初回限定のiOS26.5（135483386600）は10:39:36 UTCにfailure。連続ケースは135.705秒、同じ8秒の観測で止まり、実グリッドのbegan間隔は1.866、1.720、1.706秒で短間隔に未到達。黄色のUI（182.485秒）、単独週送り（30.413秒）は成功。Apple Native769件は予定skip 1、失敗0、黄色のコントラスト・ダーク色の検査も成功した。両OSの実指間隔を同じXCTestイベント列で確かめる候補へ進む。

[次の限定44510193805](https://github.com/n624-dev/takupoke-ios/actions/runs/44510193805/attempts/1)・試行1、766a13f、SDK27.2。iOS27.0（135512115628）は11:16:20、iOS26.5（135512115472）は11:22:41 UTCにfailure。両OSでシーケンスのビルドは通り、`WeekContactSequence` の `synthesizeEvent:completion:` 型照合（`WeekAppearance.swift:36`）で送出前に拒否。実タッチ4つは未到達。黄色は26.5で191.065秒、27.0で351.129秒で再度成功。単独週送りは26.5で高さの最初の枠間隔0.116465秒、27.0で解放から最初の描画0.132609秒で既存上限に達せず、実案内画像と幾何は採取。Nativeは成功。旧コードと個々の実frameを比較し、原因と対処を判断する。

イベント列の型は実行時の差の詳細が出なかったため、既存条件のまま再実行しない。公開されているXCTestの両宣言を照合し、引数修飾子・block型付加情報を区別して比較したうえで実型を記録する。非互換を送信前に確認した場合にだけ、同じイベントレコードの別のネイティブ送出入口 `synthesizeWithError:` を確認して一度送り、送信後は別の入口で送り直さない。前回どおり実接触と両演出段階・指離し・表示週・重複を観測する。[XCTestの公開参照宣言](https://github.com/appium/WebDriverAgent/tree/3d6a4e03cdd673e540289c610f7e189f8ffea434/PrivateHeaders/XCTest)

描画は26.5で実到着0.214575→次の描画0.331040秒、27.0はスライド中も観察間隔がおよそ0.0667秒で、初期の無変位の次が0.132609秒。幾何の欠落は双方0、画像採取は各1回。408c1673の既知幅・予約高と766a13fのページ準備・進捗観測を比較し、候補は準備ページ窓の更新を表示コールバックの位置更新から分ける。ページ内容の組立ては準備窓の変更で行い、通常の表示コールバックは既存配置の位置・高さを更新する。製品と実frame観測の両方が現在の画面の最大周波数を優先し、実時計・実枠・期限・案内PNGの評価を維持する。Simulator側の表示間隔を強制できるとは断定しない。

[現限定44516935250](https://github.com/n624-dev/takupoke-ios/actions/runs/44516935250/attempts/1)・試行1、981161b、iOS27.0／SDK27.2（135535263666）は12:07:28 UTCにfailure。proxyの実戻り型は@、引数は[@, :, @, @?]。送信前に既存の代替入口を選び、実接触・放し・到着は各4回、最終の逆方向も成立。最初の指離し後の新しい接触は実0.016738秒、0.048253秒、0.047995秒。三回ともslideに到着し、releaseもslide中に到達した。`ApplicationChecks+WeekAppearance.swift:276`で実height中開始がなかったため停止（38.093秒）。単独週送りと黄色は同じjobで成功。26.5は実行中で取消さない。イベント列の時刻記述と受信結果を照合する。

`WeekContactSequence`、`phase == "height"`、`pauseAfterLift` で初回44501853677・次の44510193805、766a13fと981161bのXCTestイベント作成と実UIKit観測位置を照合。別の指離しから3回の次接触がいずれも最初の横到着前だった。早過ぎた最初の接触だけ、今回計測した横到着0.301469秒と最初の高さ調整の実持続、要求から受信までのずれを使って後ろへ約0.3秒離す。後半の2つの短い間隔を維持して、別の実タッチでslide開始・slide中releaseを確認する。最初の対象がheightまで入り、実4接触・4遷移と画面の最終日付・重複なしが実測できるまで成功にしない。演出時間や製品コードは変更しない。

同じ限定44516935250・試行1、981161b、iOS26.5／SDK27.2（135535265079）は12:27:52 UTCにfailure。連続ケース（42.868秒）は4接触・4 release・前進3回と逆方向1回、実slide中の入力およびreleaseに到達。実指間隔0.033287／0.041907／0.012268秒、最後の接触は実ページ準備待ちも通過。三回ともslide中に始まり、同じ276行の実height開始の条件が未達。黄色は214.491秒で成功。単独ケース（30.639秒）は434行で実到着0.209942秒から次の観測0.326311秒まで0.1163686秒となり、既存0.09上限を超えた。幾何欠落0、案内PNG採取1回。Nativeは成功、同run全job終端。横移動の完了・表示週の昇格・高さ調整付近の実枠と実ソースを照合する。

26.5と27.0の実入力を比較し、最初の横到着は実release後0.322262／0.301469秒。次の開始はそこより早く、両方の観測誤差の余裕を取った0.70秒候補（要求を+0.34秒）の比較を両OSへ適用する。26.5単独は実x=26の到着判定から、位置16・旧高251.667の次サンプルまで0.116369秒。その後は0.05075秒で実高さ511.667、さらに約0.022秒で617.667を観測。27.0単独は欠落0、最大0.09秒以内。408c1673・766a13f・981161b、`settle`／`promote`／`reachableWeekBounds` の旧実装を照合した。今回の表示週更新では、遷移コールバックの範囲確認に加え、画面の複数の節が学期の次の週を再評価するたびに、各日・学年・時限の資料を都度線形検索している。候補は時間割の描画で同じ資料版に使用中の `SourceIndex` を範囲判定でも再利用し、元の行事有無と授業・特別・変更の判定、範囲の再確認を維持する。フレーム不足の全原因は未確定。尺、位置、検査上限、実画像を変更せずNativeで実枠を再測定する。

[限定44526384025](https://github.com/n624-dev/takupoke-ios/actions/runs/44526384025/attempts/1)・試行1、1824b8b、SDK27.2。27.0（135567960849）は12:57:56、26.5（135567960373）は13:01:46 UTCにfailure。Nativeは成功。最初の要求間隔を0.36→0.70秒へ伸ばしても実指間隔は26.5で0.020457／0.045725／0.007857秒、27.0で0.024980／0.036023／0.008526秒。各OSで実4接触・解放・到着、前進3週と逆方向1週・slide中の開始と解放を確認したが、278行のheight中開始だけ未達（44.656／44.421秒）。黄色は179.480／208.514秒で成功。単独描画は26.5で到着0.264200→次枠0.363960秒（0.099760秒、上限0.09）、27.0で0.251174→0.400923秒（約0.150秒）に間があり、27.0で異なる中間高さが1個だけだった（427行）。両OSとも幾何欠落なし、最初の方向の案内PNGは1回で採取。タイムラインの指定値が保たれない理由およびフレーム間隔と週更新の作業を旧ソースと比較する。

`pauseAfterLift`、`pressDownAtOffset`、`synthesizeWithError` で981161bと1824b8b、両OSの実時計、AppleのXCTestヘッダーの公開参照を比較した。別のtouch path間の待ちが同じrecordの実送出で明確には維持されず、0.34秒の延長でも実間隔はほぼ増えない。次は最初の実dragを一つのnative recordで一度送り、送出入口が戻った後にtestの時計で0.28秒を空け、残り3つの短間隔のdragを2番目のnative recordで各一度だけ送る。通常のXCUICoordinateの静止待ちには接続しない。双方の実送出時刻と実アプリが観測した各開始・終了・演出・到着を記録し、実height中開始を受け入れ条件に保つ。この0.28秒がアプリで期待する間隔になるかは未確認。

`detailRevision`、`weekSection`、`changesSection`、`settle`、`adjustHeight` で408c1673から1824b8bの実装を照合した。旧フレームの次に水平到着位置を描くまで止まり、26.5でその直後の高さは251.667のまま、27.0は続く枠で591.333へ大きく進んだ。時間割全体を再評価する@Stateの選択週を観測可能な独立の状態に移し、週と変更範囲を読む行だけが週変更に依存するようにする。詳細は同じ週変更と資料変更で閉じる。到着で選択と入力週を切り替える条件は維持。高さは実コールバックが来るまで時計を進めず、到着後の最初のcallbackを同じ0.2秒の尺の起点にする。Y・画面位置・PNG・実枠の0.09秒と2つの中間高さの条件を変更しない。元の隣週・日付範囲・既存表示条件、支障の原因全体は実UIで確認する。

#122の局所Linux対照（13:14 UTC頃、Swift 6.1.2、1824b8bからの未コミット候補）。実`TimetableWeekSelection`と`SchoolDate`の型検査はリンクまで進み、`libswiftObservation.so: undefined reference to swift::threading::fatal(char const*, ...)` でリンクが1件失敗した。実日付変更の通知assertは未到達。Appleの実ビューは未実行。Linux用ライブラリの依存とシンボルを調べる。
`readelf`と`nm`で同じSwift 6.1.2を比較した。配布の動的Observationが要求するシンボルは動的Coreからは公開されず、同梱の静的CoreのThreadingError.cpp.oには定義がある。実クラス・日付・assert・Swift版を保持し、`-static-stdlib`でLinuxのリンク方式だけを切り替える。
静的リンクは成功したが静的Foundation側で`TimeZone(identifier: "Asia/Tokyo")`がnilとなり、`SchoolDate.swift:71`の初期化前提で停止した（終了132）。動的Foundationで通常の学期検証663件は成功済み。静的Core同梱の不足しているThreadingErrorオブジェクトをLinuxの一時対照だけへ渡し、Foundationを動的のまま維持する。
ThreadingErrorオブジェクト単体を追加する動的試行も、さらに非公開の`swift::fatalErrorv`とhidden symbolのためリンク不可だった。局所のリンク方式を製品へ導入せず、実クラスとSchoolDateのコンパイラ型検査までをLinuxの結果とする。実Observation通知とビューの振る舞いはMacへ渡す。

[限定44531912673](https://github.com/n624-dev/takupoke-ios/actions/runs/44531912673/attempts/1)・試行1、4d6fa6c、iOS27.0／SDK27.2（135587159090）は13:41:24 UTCにbuild-for-testingでfailure。生成AppChecksの`TimetableView.swift:213` とObservationTracked macro展開で、選択週のデフォルト値へ挿入された`SimulatorSelectionFixture.day`をnonisolated初期化から参照できず停止。実アプリ起動・タッチ・フレーム計測は未到達。26.5とNativeは取消さず、既存のfixture日付の差し替えと当時のActor制約を比較する。
`N143`／`actor-isolated static property`でN143の当時のCards内local functionと今回の1824b8b（Viewの初期化に日付）・4d6fa6c（モデルのdefault値へ移動）を比較した。どちらも参照元から外した境界でMainActorが失われる。今回は製品がコンパイルできるかだけでなく、生成器が既存のfixture日付への参照を新しいモデルへ展開する点を見落とした。実生成変換、実Observationモデル・SchoolDate、ViewのMainActor相当と実fixture宣言の型境界を用いるLinux 6.1.2対照で、修正前の同じ非隔離初期値エラーを再現した（1件失敗、2.425秒）。候補は従来のView初期化へ日付を戻し、モデルは確定した値だけ受け取る。すべての架空日付選択条件、画面・実連続入力・フレーム検査を維持する。

同じ旧限定44531912673のiOS26.5（135587158689）も13:45:05 UTCに同一の生成`TimetableView.swift:213`／ObservationTracked／MainActorでbuild-for-testingが停止。UIKitの検証未到達。Nativeは13:47:36にsuccess、旧runは全job終端。15b6d70以降の入力を持つ限定結果とは区別する。

[限定44536795734](https://github.com/n624-dev/takupoke-ios/actions/runs/44536795734/attempts/1)・試行1、15b6d70、SDK27.2。27.0（135604251444）は14:04:27 UTCにfailure。生成アプリはコンパイル成功し、Nativeも成功。連続実操作は40.507秒。最初のrelease実879.051245、横到着879.302273、ネイティブ1番目の返却879.259869、後続送出879.542347、最初の高さ完了879.543823、次の実開始879.658936（すでにsettled）。4実接触／解放／到着、3前進と1逆、後半のslide中始動と解放は成立したが、283行のheight開始未達。黄色は197.514秒で成功。単独枠（96.762秒）は横到着0.251359、次の実整列枠0.432693の差0.181334秒で旧0.09上限を超過。その後の中間高は実10点、幾何欠落0。横到着付近だけの無表示と実リサイズ中の改善を区別する。26.5は取消さず、実結果と当時のコードを照合する。
`TAKUPOKE_WEEK_RECORDS`、`promote`、`CADisplayLink` で旧1824b8b／4d6fa6c／15b6d70の実験を照合。分割したrecordでは0.28秒の外側待ちは実測でも維持されたが、最初のreleaseから1番目の返却まで約0.209秒、次の送出から実始動まで約0.117秒が別にかかり、予定より後になった。連続検査は両OSの各実時刻から次の値を決める。単独は高さ中の実描画が増えた一方、横到着付近には実0.181秒の欠落が残った。下位原因はまだ未確定。次は使い捨てfixtureの受動観測で、到着・日付反映・スクロール復帰・再構成前後の壁時計と同じmain threadのCPU時間、実display-link時刻、元の実枠を一緒に採る。フレーム、接触、PNGの条件や製品動作に手を入れず、CPU作業とSimulator側のコールバック待ちを判別する。
同じ15b6d70限定の26.5（135604250932）はActions上13:46:33開始、ランタイム準備成功、実画面stepが13:50:40–14:18:43にcancelled、14:21:33終端。こちらからの取消操作なし。job log APIはBlobNotFound、CLIのjob logは0バイトで実タッチ・計測の結果は取得できない。下位の取消理由も未確定。保存artifact0。27側で実測できた送出差0.208624＋0.116589秒を使い、外側の間隔を0.05秒にすると同条件でrelease後約0.375秒に始動する見込み。27で観測した到着0.251・高さ完了0.493秒の中を検査し、両OSとも実phaseと元の四接触と各結果を必須とする。26の見込みは未検証。

[限定44544262245](https://github.com/n624-dev/takupoke-ios/actions/runs/44544262245/attempts/1)・試行1、656cdaa、SDK27.2。iOS26.5（135630503722）は14:40:58 UTCにfailure。生成アプリのbuild-for-testingは完了し、bootstatusが14:40:31にFinished。最初の`simctl ui content_size`でSimError405・現在状態Shutdown・exit149。runtime available、guest Shutdown、実XCTest未開始。所有Simulatorのcleanup完了。27.0（135630504281）とNativeは成功。27.0連続39.650秒で次接触height・後半slide／slide中release・四到着／カレンダー成立、黄色200.207秒、単独36.541秒。単独の昇格コールバック約0.3–0.6ms、次の整列実枠まで約0.050／0.027秒。その間のアプリmain thread CPUは約0.049／0.027秒。停滞が出たiOS26の測定は未取得。
`SimError405`、`current state Shutdown`、`simulator-content-size-enter` でN194/N198と当時の782ad0d／40e1aab、現行boot helper/runnerを比較。今回もRuntimeの配布・名前選択・buildには成功し、実UI開始前のCoreSimulator状態喪失。別ホストでは同じruntime/SDKの実26.5 UIが複数回起動済み（44526384025等）。実タッチや今回の候補を修正する根拠はないため、同じ完全SHAの当該jobだけを新規所有runner／Simulatorで1試行する。失敗を成功扱いせず、27やNativeを再投入せず、正式15件にも合算しない。

[限定44544262245](https://github.com/n624-dev/takupoke-ios/actions/runs/44544262245/attempts/2)・試行2、656cdaa、iOS26.5／SDK27.2（135647938751）は15:15:03 UTCにfailure。差し直した所有Simulatorで実XCTestを実行。連続実操作41.834秒は4接触・4解放・4到着、height中開始、slide中開始・解放、未準備ページの保留と実最終表示がすべて成立した。黄色188.224秒も成功。単独（34.748秒）は復路のt0.029771→0.048093秒でsource x123→198、target x−238→−163の75.0ptが上限72.2ptを超えた（453行）。両方向の幾何欠落0。横到着から次の整列枠は約0.059／0.067秒で旧0.09秒内、その間のmain CPU差は約0.046／0.053秒。昇格処理の同期部分は約0.3–0.5ms。01回目と違い実画面までは到達した。

`A displayed frame must not skip a fifth` と `advanceSlide` で正式410a588の26 Bと同じ復路の実隣接枠の超過を比較し、5359b47／410a588／a6d26f8の進捗・直近両OS限定44549625762を確認した。#122にもa6d26f8のフレーム時刻差の累積を使用する。各入力の接触・保留・到着順と既存の実フレーム条件は維持する。共通修正が既存週送りで両OSに成功したことと、#122の連続入力を含んだ新しい候補の検証は区別する。

[正式44558479226](https://github.com/n624-dev/takupoke-ios/actions/runs/44558479226/attempts/1)・試行1、bf35cfc、iOS27.0／SDK27.2。Application B（135683513690）は16:23:14 UTCにfailure。元`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（41.870秒）の復路は境界0.281221秒、実x=16へ0.297785秒で到着。高さ調整中の実枠0.414381→0.549528秒の差0.135147秒が元0.09を超えた（WeekAppearance.swift:188）。この2枠の高さ356→316pt、両方向の実PNG各1回、幾何欠落0。26 Bの前回の横方向109.667ptとは別の段階。配布、Native、27 A、他3手動は成功。27 Bに依存する公開は不可。進行中26 Aは取消さない。

同じ正式のiOS27手動明示選択（135683514053）は16:29:02 UTCにfailure。元case1017.746秒。教室入力の全文と完了、checkboxの外枠(16,280.67,361,52.33)、内枠(300,293,63,28)、一意・enabled/hittable、外内0とkeyboardなしを確認。Input.swift:41の元の一回0.05秒接触と水平ドラッグを合成し、実教室だけ値0／`ack=false`で、科目・教員はtrue。45秒でInput.swift:57停止。最後の現象のUIKit配送は、128行出力の先頭を保持する診断に残っていない。結合資料の採用／再起動の契約に未到達。過去の対象実コードと現在の一回入力・観測を比較する。

`Height adjustment must keep drawing frames`、`settle`、`WeekPagesCanvas`で408c1673、bf35cfc、#122の981161b／15b6d70／656cdaaと実枠を比較。既存単独の高さ中に断続的に表示機会を失う。#122では到着と高さ開始の時計を分け、事前準備ページと表示中の再計算を分離している。既存限定の最新656では実連続と黄色を両OSで確認済み、26単独の高さ間隔は0.09以内、横方向のみ75ptを超えた。前の正式に対して横時刻増分を実測で修正したbf35の処理も統合済み。#119〜122を同じ検証へまとめ、既存の横・高さ・実入力・実PNG条件をすべて検査する。高さの過負荷全般の解明とは扱わない。

`acknowledge`、`manual-ack-cell-1-0:0:room`、`TAKUPOKE-MANUAL-ACK`でN94/N167・正式492、f6e13a6／ed76a288と現行Input・収集器を照合した。過去N94同様に実Switchを確認した後に操作時の枠を再照会しているが、今回はイベント合成後に実値が変わらなかった。最新記録に実配送がないため下位原因は未確定。同じ実Switchの確定枠から、同じ両端位置をアプリ座標で一度だけ水平ドラッグする。外と内の一意な実値0、実枠包含、enabled/hittable、0.05秒・元速度、一回、45秒内の実値1・確認・保存・再起動の条件を維持する。所有ファイルの型検証・サイズ上限を維持し、同じ128行枠で最後の実配送を残す。

Linux x86_64、Swift 6.1.2を有効にしたf097156のローカル検査で、`test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps` が旧 `actual.coordinate` の文字列を要求し、生成前のソース検査で1件失敗。実Switchの実画面は未実行。当時のbf35cfcとf097156の入力を照合し、検査は変更後も同じ実枠の25%・75%と高さ中央を要求する。アプリ枠の包含、座標変換、単一ドラッグおよび前後の実値の要件を検査に残し、同じ形の旧文字列が残っていないか確認する。

4d30920の正式開始前のコードレビューで、横に広い週の連続操作による位置消失を特定した。A→B中にB→Cを保留し、用意済みのCが短い横ドラッグを受け取ると、Cの実横位置を更新してその接触は消費済みとなる。Bへの到着で`configure`が先行した場合、`resetNeighborScrolls`は保留先のCを対象外にしていないため、表示前に先頭へ戻し得る。手元の実画面ケースは行事週中心で、この幅での実機再現は未確認。bf35cfcでは非選択の全ページを先頭に戻しており、同版には次週以降を保留する処理がない。656cdaaの保留順と4d30920の実位置更新、既存の幅・保留試験を照合した。選択週・描画中・接触中の従来保護に加え、待ち行列に到着先として残る週の横位置を保持する。

[限定44570597421](https://github.com/n624-dev/takupoke-ios/actions/runs/44570597421/attempts/1)・試行1、4d30920、iOS26.5／SDK27.2（135724248522）が17:18:35 UTCにfailure。実連続51.862秒・黄色278.369秒は成功。単独（36.215秒）は復路の横到着0.232787秒から初めのx=16／旧高630.667ptの整列枠0.332029秒まで99.242msで、元の90msを超過した（WeekAppearance.swift:443）。往路は83.013ms、横の最大隣接差は両方向51.333pt、実PNG各1枚、幾何欠落0。復路の昇格とスクロール復帰は0.889ms、実整列までのmain thread CPU差は89.450ms。設定呼出しの開始までに約71msを消費した。27.0の同候補は3件成功し、高さの最大間隔64.958／48.253ms。正式bf35cfcでは高さ調整中に135.147ms、今回は高さ開始前に99.242msとなった。

`横到着`、`configuration-begin`、`weekSection`で981161b・1824b8b・656cdaa・4d30920を照合した。昇格処理の同期部分は実枠間隔の1ms未満だった。現行の整列時点でSwiftUIの個々の仕事は判別できず、残りのCPU時間の内訳は未確定。横位置の修正で開始済みの後続限定44575116201では、元の90ms、実枠、PNG、全入力の検査を使用する。

[正式44580736320](https://github.com/n624-dev/takupoke-ios/actions/runs/44580736320/attempts/1)・試行1、d66d60f、SDK27.2／iOS27.0の手動明示選択（135762830052）は18:14:25 UTCにfailure。元ケース280.492秒。科目の全文入力とkeyboard終了後、実Switch内枠(300,658.667,63,28)・一意・有効・hittable・外内0を確認済み。一度の水平ドラッグは実UISwitchの`_UILiquidLensView`に(315.67,672.67)で入り、同じ実Switch上の(347.33,672.67)で200ms後に終了した。末尾traceの終了時点に`UIPan:1`があり、観測した瞬間のnative値は0。45秒以内の実確認値は0、入力状態`ack=false`、対応する確認setterの記録はない（Input.swift:61）。後続の採用や再起動は未到達。配布・Native・27 A・他3手動は成功。残るジョブは取り消さない。

`ManualAssistanceChecks+Input`、`UIPan`、`N167`、正式492／496で当時のf6c2dbd、ed76a288、4899da2、現在の入力・製品Bindingを比較した。正式492とN167は実中心への接触、正式496は同じ両端で88msの実ドラッグだが教員だけ失敗。先行4d30920の限定44570734947では同じ両端、後半に今回と同じ高さで教員の実確認にも成功した。N167では成功時でもsendEvent直後のnative観測が0の例があり、即時値を合否に使わない。今回は実配送後の確認が失敗し、下位原因は未確定。既存`slow`の実ログ250pt/sから125pt/sへ移動速度だけを下げ、同じ幅の操作を約0.25秒かけて送る候補とする。実枠、始点終点、一回、元の45秒、全項目・取消・採用・保存の要件を維持する。

同候補の最初のLinuxローカル検査は30件中1件失敗。Swiftの実生成・構文検査後、`test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps`がコメント中の`for`を反復操作と誤認した。旧d66d60fと比較し、行コメントを除いたコードでループを禁止する条件に修正する。一回の`press`と実値の検査は維持する。

同じ正式44580736320／d66d60fのiOS27.0 UI B（135762829890）は17:50:23 UTCに開始し、18:51:27にcancelled終端。チェック注記は`The job has exceeded the maximum execution time of 1h0m0s`。先行の単独週送り39.351秒、黄色246.260秒、曜日修正207.564秒、実VoiceOver64.799秒、既存通知185.347秒は成功。独立`testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch`が18:50:07に開始し、18:50:38にジョブ全体の取消となり、当該ケースの完了・OS文字サイズ3回・元の最終照合には未到達。iOS27 UI Aは50分46秒で成功。こちらからの取消操作はない。

`ジョブ全体`、`60分`、`N217`で正式498/499、旧6dd809f、d66d60fの正式workflowと実runnerを照合。26は以前、追加ランナー起動・OS文字サイズ・照合・清掃を含めて80分へ変更した。今の27 Bも最後の通知の通常完了約2〜6分と文字サイズ3回、終了処理が60分時点で残っていた。27 Bの合計枠だけを75分にし、テスト自身の操作期限、実runner・対象OS照合、失敗時終了、残る全ケースと既存公開ゲートを使用する。

[正式44597797740](https://github.com/n624-dev/takupoke-ios/actions/runs/44597797740/attempts/1)・試行1、c4546bf、SDK27.2／iOS27.0、手動単項目（135822896783）は19:42:59 UTCにfailure。元ケース406.269秒。実値125の科目確認2回は成功し、最初の編集画面でHome→background=3→activate=4、同一processを確認した。レビュー画面では元の文字・比較なし表示を確認後、19:39:33にHomeを一度送った。19:39:35以降に対象アプリの状態述語が外れるたび、XCTestはpid12378の表示階層を取得した。19:40:29にforeground=4で停止（Lifecycle.swift:17）。元45秒を越えるまで複数の画面取得が続き、後続の復帰・採用・再起動は未到達。Home配送後に本当にバックグラウンド状態へ入ったか、画面取得が観測へ影響したかは未確定。他ジョブは取り消さない。

`before-home`、`background-observed`、`Capturing element debug description`で5d378cd／d66d60fの元helper、既存冷起動でのSpringBoard待ち、同じケースで成功した直前の編集画面を比較した。今回は同一processのレビュー画面における待機で、冷起動への未到達とは異なる。待機の対象を`nil`にし、画面階層を診断対象に渡さずに実アプリのランタイム状態だけを読む。Homeは一回、45秒、二つの実バックグラウンド状態、元の同一process・復帰・保存条件を維持する。状態が変化したときだけ記録する。

[限定44602988498](https://github.com/n624-dev/takupoke-ios/actions/runs/44602988498/attempts/1)・試行1、8eea8b9、SDK27.2の単項目。iOS26.5（135839093228）は20:20:35 UTCにsuccess、548.147秒、編集・レビュー双方で実background=3から同一processに復帰し採用・再起動を確認。iOS27.0（135839093747）は20:17:37にfailure、532.644秒。実科目確認と最初の表示サイズ変更は成功。二回目の架空メニューを開く操作は20:10:19に開始し、実ボタン確認後の`press`が対象再照会を挟んで約96秒間進まなかった。実`HostingUIButton`上の同一点(329,97)で接触開始と終了を記録したが、wallは1.834秒。メニューの3ラベルは一つも現れず（Navigation.swift:312）、背景ケースには未到達。

同じ正式c4546bfのiOS27.0明示選択（135822896747）は20:05:05 UTCにfailure、841.483秒。五回目の教員欄まで進み、実Switch枠(300,658.667,63,28)、有効、内外0を照合。`press`がwindowの準備と再照会に約36秒かかり、実Switchの(315.67,672.67)→(347.33,672.67)でbegan/endedを記録、イベント時刻差333msに対してwall109ms、終了時`UIPan:1`、45秒後も教員の実値0とack=false（Input.swift:62）。先の限定cef515aは両OSで同じ手順を全て成功済み。`N167`、正式496、d66d60fと今回のソース・配信時刻を比較した。前段の実要素検査は維持し、再照会を伴わない同じSimulatorの時間指定イベントを使い、短いスイッチの移動を複数点で確実に送る候補とする。架空メニューの開く一回にも同じ経路を使用し、実三項目、対象の一意性、操作と結果は従来どおり必須にする。

同じ正式c4546bfのiOS27.0 UI B（135822896572）は19:59:41 UTCにfailure。元単独（30.718秒）は往路の横到着0.249401秒→整列x16・旧高251.667ptの実枠0.348828秒、99.427msが90ms条件を超過（WeekAppearance.swift:443）。実PNG561720 bytes、幾何欠落0、昇格・スクロール復帰0.899ms、次枠までmain thread CPU約91.209ms。前回4d30920のiOS26.5と同じ到着直後。旧981161b／656cdaa／現1af3e5cと`weekSection`／`configuration-begin`を照合し、日付ボタン・行事の未取得表示・グリッドの週依存を各行へ移す。実際のSwiftUI内部CPUの内訳は未確定。合格枠・実入力・表示内容・タイミングの測定は同じにする。今回75分の総枠には達していない。

共有の実接触helperを両テストターゲットに登録した候補の最初のLinux一覧生成は、`NativeTestContacts.swift`を二つの分類で所有したため生成前に拒否された。既存の共有`NativeTabActivation.swift`と同様にソースの所有分類を一つにし、両ターゲットの登録と両方の実操作検査への対応を残す。

[限定44609218761](https://github.com/n624-dev/takupoke-ios/actions/runs/44609218761/attempts/1)・試行1、169eb22、iOS27.0／SDK27.2明示選択（135861035899）が20:56:52 UTCにfailure、952.540秒。時間指定イベントで最初の科目2回と教員の確認は成功。三項目の確認で科目の実Switch枠(300,219.667,63,28)、外内0、有効・hittable・keyboardなしを確認し、一度の送出は約0.75秒で返却した。45秒で科目の実値は0・ack=false（Input.swift:62）。失敗時の所有コンテナ取得が10秒でtimeoutしたため、当該接触のUIKit配送は未確認。対して同候補の単項目は両OSで元ケースを完走した。

Switch確認の正式492／496／d66／c454、N167と#113の行選択、当時のe11398d／7463efa8および現行の`PDFRecoveryView`と`ChangePreviewView`を照合した。旧接触法でも今回の時間指定でも同じ確認が外れたままの事例が続く。操作対象を各項目の「原本と一致することを確認」のチェックマーク付きButtonへ変更する。既存の行選択と同様に選択traitを使用し、未選択／選択の反転、値変更による解除、古いdraft・レビュー中の拒否と提出・採用・保存の実検証を維持する。各操作は実ボタンの確認済み枠に一回だけ接触する。

Linux Swift 6.1.2の確認Button候補のローカル38件では、既存の実コールバック抽出検査だけが失敗。SwiftUIを使わず実アクション本体を検査する周辺コードに`Button`名まで入れ、`cannot find 'Button' in scope`で停止した。旧Bindingと同様に製品の実クロージャそのものを抽出し、実値の選択・解除と古いdraftの拒否を検査する。

[限定44609466898](https://github.com/n624-dev/takupoke-ios/actions/runs/44609466898/attempts/1)・試行1、169eb22、iOS26.5／SDK27.2（135861894684）は21:18:44 UTCにfailure。連続操作（121.342秒）で、時間指定の2記録に合成した4接触のうち受信記録は最初の週で2接触・2解放。実接触間隔は開始から解放まで26.545msと1.368msで、週到着は0。最初の新しい接触も送出記録の返却側時刻より約1.04秒後。ABI照合により既存同期経路を両OSが使った。26.5の単独33.495秒と黄色195.124秒は成功し、単独は実PNG各1枚、幾何欠落0、高さ最大50.363／45.341ms。同じ試行のiOS27.0は4接触、前進と後退、実height／slide、黄色、単独すべて成功。描画間隔の失敗とは段階が異なる。

`WeekContactSequence`、`NativeTestContacts`、`TAKUPOKE_WEEK_RECORDS`で旧1af3e5cの両OS成功、15b6d70／656cdaa、169eb22の実コードを照合。連続週送りの接触点、実移動の記録、三つの後続経路の時刻は同じ。今回は到着を待つ条件に加え、受信した接触数と持続自体が不足した。下位原因は未確定。環境を替えた同じ完全SHAのiOS26.5ジョブだけを一度再実行し、四接触・実到着・描画条件を課す。両OSの正式ゲートには合算しない。

確認Buttonの正式前レビューで、`.borderless`にしたラベルの内容が文字とアイコンの高さしか持たない場合、行が44ptでも接触領域が狭くなる可能性を指摘。既存の44ptの消去ボタンと実画面内の包含条件を確認し、ラベルの接触形状に先立って44ptの最小高さを付ける。前の候補で実際に狭い接触領域を観測したものではない。

[限定44616414594](https://github.com/n624-dev/takupoke-ios/actions/runs/44616414594/attempts/1)・試行1、ebe3694、iOS26.5／SDK27.2単項目（135886201716）は21:44:04 UTCにfailure。端末起動510.9秒。実XCTestが21:37:18に開始し、最初の科目入力・確認前の一覧照会中に、準備込み1800秒で21:42:43に終了124。実確認ボタンの操作や背景・採用の判定には未到達で、所有端末とexport回収は完了した。同じ限定のiOS27.0は506.663秒で成功。別のebe3694のiOS27.0明示選択も1266.792秒で実6確認・採用・再起動を完走した。

`1800`、`Focused manual preparation`でN243・旧43767607953、現行と旧491の`manual-26`の実コマンドを照合。以前のiOS26で同じ外側上限への到達が記録されており、正式はすでに準備込み2400秒・job45分。別のSDKでiOS26ランタイムを準備する限定も正式と同じ合計枠にそろえる。元の操作期限、実OS・ケースの一致、完了照合と所有回収を維持する。

同じ[週限定44609466898](https://github.com/n624-dev/takupoke-ios/actions/runs/44609466898/attempts/2)・試行2、169eb22のiOS26.5／SDK27.2（135897771042）は21:53:03 UTCにfailure。前回の連続ケースは今回は49.039秒で実4接触・到着、height中とslide中の実開始、後退、最終週まで成功。単独も36.017秒で成功。黄色（190.453秒）は先行の時間割・設定のタブ移動後、21:50:09に設定アイコン枠(306.25,779,28,28)、中心(320.25,793)を確認。一度の`.press`を合成し、その後の45秒内で設定が選択されなかった。待機中、XCTestは元アプリの表示階層を繰り返し照会した。黄色の全状態には未到達で、失敗した接触のUIKit配送は確定していない。

`Native tab tap did not select`、`NativeTabActivation`でU63、正式44486188488、44513210500、直近の0a7cab6／b1cfd1aと実コードを照合した。既存の一意な実アイコン、実枠、有効・hittableの照合は成功。送出のための対象アプリ再照会を避けるため、架空メニューで両OSの実確認に成功した時間指定の接触で、同じ画面上のアイコン中心への一回を送る。前景を要求し、実タブが選択されるまでの元の45秒と移動先の画面確認を使う。明示的に取得した実AX以外に、XCTestの副次的な診断スナップショットを待機対象に渡さない。

### 44ptの原本照合確認後に架空操作のAX取得が停止

[単項目iOS26限定44622550899](https://github.com/n624-dev/takupoke-ios/actions/runs/44622550899/job/135907766432)・試行1、aabf90e、SDK27.2／Runtime26.5は22:17:26 UTCにfailure。2400秒の準備込み枠内に495.130秒の実テストを完了した。元の科目では実確認行の高さ74pt・未選択・操作可能から、22:14:03までに一回の実接触で選択済みを確認した。UIKit配送は(196.67,661.67)でbegin/end、25.1ms。未選択時の確定不可と選択時の確定可能も成功した。22:14:46に架空toolbarの一度の接触を送出した後、最初のアプリ階層照会が返らず22:16:26に`表示サイズを変更;snapshot unavailable`で停止。遅い起動はあったが合計枠には到達していない。診断21件にこのtoolbar点の実配送はなく、AXが止まった理由・メニューの表示有無は未確定。後続の背景・採用は未到達。

`架空検証`、`表示サイズを変更`、`snapshot unavailable`でN187と44602988498を検索し、f709367・4f8d916・169eb22のtoolbar／架空ボタンと実コード、今の3アクションを照合した。同じ時間指定接触は169eb22の両OSで通り、以前の接触では実Toolbarへ届いてもMenuが表示されない例があった。生成した検査専用の入口で、既存の3アクションを標準Buttonから明示的に開く標準確認ダイアログにする。元の一回の実接触・全3項目・45秒・後続の確認を維持する。表示サイズは実環境値、同じ原本の照合は実処理後の記録をそれぞれ確かめる。配布アプリの原本・訂正の操作や、実コンテキストメニューを検証するケースは変更しない。

### 三項目の最後の確認ボタンを再照会中に停止

[正式44633231836](https://github.com/n624-dev/takupoke-ios/actions/runs/44633231836/job/135947056871)・試行1、bf2c9c0、SDK27.2／iOS27.0の`testThreeFieldsRequireEachAcknowledgementAndFourRefuses`は23:16:46 UTCにfailure、実ケース447.165秒。教室と科目で74ptの実ボタンが選択済みになり、各操作後の確定不可を検証した。三項目目の教員は全文入力・キーボード閉鎖・未選択状態を確認した。その直後に同じ確認ボタンを再取得し、実枠(16,624.667,361,74)とviewportへの包含までは成立。23:11:09以後のラベル・有効・hittableを順に読む`Navigation.swift:117`で内部照会が反復し、23:14:55にAX timeoutとなった。第三の実接触は送られておらず、確定・四項目拒否には未到達。残りのジョブは継続。

`ThreeFields`、`manual-ack`、`Navigation.swift:117`、`snapshot`でN52・N165・N174と43799291494を照合した。N52は同じ第三項目でも、消去直後の古いSwitchで停止し、全文入力前だった。今回と近いN165では実枠取得後の重複読取りで止まり、N174／43799291494以降は実snapshotと現在のhittableを分けて照会した。c454の正式三項目は旧Switch（44597797740）で成功、c818の実ボタンは単項目の両OSで成功。133bfd6・169eb22の旧照会とbf2cの実コードを比較し、ebe3694から三項目で同じ実Buttonの可視化・属性を連続で読み直していることを確認した。現在の一意なButtonから一度のsnapshotで実枠・識別子・ラベル・有効・未選択を取り、現在のhittableと同じviewportを確認して一回の実接触を送る。後続の実選択と確定可否・四項目拒否を保つ。元のSDKで同じ三項目を限定確認し、三回の実確認と次の拒否まで通るかを判定する。

### 先行正式のiOS26 Bで起動後の実行先をXcodeが列挙できない

[先行正式44633231836](https://github.com/n624-dev/takupoke-ios/actions/runs/44633231836/job/135972348271)・試行1、bf2c9c0のiOS26.5 B／SDK27.2は00:08:41 UTCにfailure。指定端末のビルド116.5秒とbootstatus181.3秒を完了。`test-without-building` の117.9秒でXcodeが同一UUIDを見つけられず、実Simulator候補には汎用placeholderのみが出た。回収時のCoreSimulatorではRuntime `available`、所有端末 `Booted`、SpringBoardも動作。XCTestケースは未開始で、開始時に候補から外れた下位理由は未確定。26 Aは00:29:15に成功し、全ジョブ終端で公開は依存skip。

`Unable to find a device matching`、`bootstatus`、`test-without-building`でN127・43769812600・正式494を読んだ。N127は同じboot後の指定UUID解決で、正式494はbuild時だった。1c331818の旧runとbf2cの実行先を指定する箇所を比較し、8b15dd8とのRuntime準備・通常UI runnerと公開ゲートの差分がないことを確認した。N127の再実行では新しいホストで同じ条件が通り、GitHubが成功済みの結果を新しい試行に引き継いだ。先行bf2cは三項目訂正の失敗もあり、現在はその修正を含む正式8b15dd8が実行中。同じ環境段階で最新も止まった場合は、結果がすべて終端してから修正の要否・同一コミットの失敗ジョブ再実行を、この証拠と新しい実ログから判断する。

### 正式iOS27 Bのホストとの通信断

[正式44641545708](https://github.com/n624-dev/takupoke-ios/actions/runs/44641545708/job/135975149293)・試行1、8b15dd8、指定SDK27.2／iOS27.0 Bは00:04:51〜00:59:08 UTCでfailure。ジョブの失敗注記は `The hosted runner lost communication with the server`。シミュレータ実行stepで停止したが、connectorでログを取得するとBlobNotFound、`gh run view --job` は実行全体の終了前と返した。どのケースまで進んだか、通信断の原因がホスト終了・資源・ネットワークのどれかは未確定。75分のジョブ上限には達していない。iOS27 Aと手動4件は成功、残りの26 Aは継続。

`lost communication`、`hosted runner`、`BlobNotFound`でN73／39771133485を検索し、旧d713ed6と現行の指定端末・各ケースの実行方法を照合した。過去はiOS26 Aで同じ失敗注記とログ欠落、今回はiOS27 B。先行bf2cのiOS27 Bは同じ製品・通常UIテスト・生成器・Runtime準備・runner・正式workflowで23:52:06 UTCに成功し、三項目の修正は手動テストだけにある。26 Aが終端し、追加の実ケース失敗が見つからなければ、ソースを変えず同じiOS27 Bと依存ジョブを新しいホストで一度再実行する。元の操作・期限・公開条件を保ち、引き継がれる結果は新しい試行のAPIで照合する。初回の通信断は記録に残す。

[同じ正式44641545708のiOS26.5 A](https://github.com/n624-dev/takupoke-ios/actions/runs/44641545708/job/136001068252)・試行1／SDK27.2は01:33:29 UTCにfailure。`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch` 150.426秒だけ失敗し、通常20件中19件成功。2行の学年入力と「選んだ行に入力」が成立し、「内容を確認・修正」へ戻った。`反映する` の有効と存在を一度確認後、`ApplicationChecks+Navigation.swift:51` の `contained` による同じボタンの存在・枠の再照会で30秒以上止まった。01:14:00の失敗後AXには該当navigation (0,75,393,106) 内の一意な実Button (285.3,79,87.7,36) があったが、期限内の操作可能性は確定していない。このボタンへのタッチ、確認と保存は未到達。全ジョブ終端、公開は依存skip。別に発生した27 Bのホスト通信断と区別する。

`tapToolbar`、`反映する`、`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`、`snapshot`で1e173b3の先行26 A、N160・N165・N174、bf2cの成功条件を照合した。44465270899では先の学年入力の画面復帰で停止し、今回の反映ボタンの照会とは段階が違う。旧1e173b3と8b15dd8の`tapToolbar`は同じ複数getterで、bf2cの26 Aは同じコードで成功している。N165のように成功していた状態を重複して読む箇所を減らし、元のナビゲーション・Button各10秒、ツールバー所属、一意性、実枠包含・enabled・現hittable、一回の実タップを維持する。同じ準備の全対象ケースを限定で確認し、反映の確認・取消・再起動後の保存までを検証する。製品コードや公開条件は変えない。

### 正式iOS26の単項目と明示選択で停止段階が異なる

- [正式44660400847の単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136062998708)・試行1、0d1208c、SDK27.2／iOS26.5は03:52:19 UTCにfailure。実ビルド158.2秒、bootstatus375.3秒を完了した後、`test-without-building` の開始107.1秒で所有UUIDの実行先をXcodeが見つけられずexit70。XCTestケースや原本照合には未到達。N127、43769812600と当時・現行の実端末指定を照合した。同じ実行の原本変更・三項目の同OSは実ケースが成功した。
- [同じ正式の明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136062998723)は03:45:46 UTCにfailure、実ケース210.107秒。最初の科目入力、74ptの確認ボタンの一回の実選択、確定可否、レビュー成立と入力表示まで成功。`manual-comparison-unavailable` のスクロールは最初の2回で `自動読取` の起点が同じまま、その後の反転で先頭方へ移動し、6回目のno-progressで停止。UIKitに始点の接触はあるが、最初の2回でスクロールが進まなかった理由は未確定。教員・教室の追加選択、四項目拒否、採用・保存は未到達。
- `manual-comparison-unavailable`、`no-progress-after-reverse`、`受動Cell`でN54・N78・N173、5fd0805の当時のReviewと現在の比較欄・実スクロールを照合した。N54は同じ比較欄でAXが返らず、今回は候補が画面外のままスクロールが進まない。利用者の指示に従い、コードと検査条件を0d1208cのまま、通常26 A・Bが終端した後に失敗ジョブと依存ジョブを一度再実行する。新しい試行では元の比較表示・採用・保存と全公開条件を確認し、初回の停止は記録に残す。

- [同じ正式の通常26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136054211789)では行訂正が669.032秒で成功。連続週送り67.735秒は実4接触・実4解放と前進3回・後退1回の実到着、slide中の開始が成立し、height中の開始だけが不成立。実観測は最初の解放3129.4536、次接触3129.6255、最初の到着3129.7682で、次接触は到着前だった。週限定df2a880／44626211937と同じ週製品・接触コードで、その限定は両OSのheight中開始を観測して完走した。44526384025の接触順記録も比較した。再実行でも同じ高さ・順序条件を維持する。
- [同じ正式の通常26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136062998644)では `testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups` の最初の2回の時間割ファイル遷移、実反映・取消と確定が成立。反映後に再起動し設定タブの実選択を確認し、3回目の「時間割ファイル」へタップした後、10秒内に移動先を観測できず141.956秒で失敗した。事後AXには設定NavigationBarが残った。N153の保存後の再起動と閲覧失敗、およびbf2c・現行の`openDetail`を比較した。今回はボタンへのタップ送出後に停止し、修正したツールバーボタン自体は3回の操作に通過している。iOS27 Bの同じケースは先に成功。初回は4件の失敗で終端したので、利用者が指定した同一ソースでの一度の再検証には、この2件を加えた失敗4件と依存ジョブを用いる。成功済みは新しい試行のAPI情報で照合する。

### 同一コミットの再実行で明示選択が成功し、単項目は次の段階へ進んで停止

- [正式44660400847・試行2](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/attempts/2)は同じ0d1208cで失敗4件を再実行した。明示選択iOS26.5（136089875832）は780.061秒で成功し、比較欄、6回の実確認、四項目拒否、採用・再起動後の保存まで通過した。旧失敗は試行1の記録に残る。
- 単項目iOS26.5（136089875821）は05:11:46 UTCにfailure。ビルドと起動を経て実ケースを開始し、217.914秒で初回消去の45秒待機が失敗。現実ボタンの枠 (317,565.667,44,44) を確認して一回タップ。UIKitは中心(339,587.667)でbeganを取り、123.6ms後にcancelled。入力には旧値が残り、消去Bindingや次の照合には未到達。試行1の実行先解決とは別。`clear`、`cancelled`、`Native clear` でN71・N90・N92の実観測と1b368f5／現行の有界取得及び実接触を照合した。現版の44pt実領域と実要素の照合は成立していた。今回の下位原因は未確定で、残りの26 A・Bは継続する。
- [同じ試行の26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136089876043)は05:23:33 UTCにfailure。最初のカウントダウンケースの本体を操作する前に、一度の `app.launch()` がXcode起動timeoutとなり211.638秒で終了。同じPID30346では05:05:15 UTCにfixture-readyまで成立し、Xcodeはその約75秒後の05:06:30にtimeoutを返した。同じ実行の後続7ケースは成功。試行1の行変更・再起動後の遷移とは別。`Timed out while launching application via Xcode` と `fixture-ready` で、同じランタイムとSDKの43767607953／旧6ee6857の先例およびN95の起動失敗と現行の一回起動を比較した。N95にはアプリの準備完了の記録がないが、43767607953では今回と同様に準備完了は採れた。現在の26 Aは継続する。
- [同じ試行の26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/44660400847/job/136089875640)は05:38:54 UTCにsuccess。行訂正424.599秒、週の連続操作25.544秒。2回目の実接触1913.0354は1回目の横移動到着1912.8843の約151ms後で高さ調整中（調整完了1913.1911）。残りでは横移動中の実接触と解放、全4回の実到着と最後の逆方向、終了照合まで成立した。試行1の同じ接触は横移動到着の約143ms前。両試行で製品・操作ソースは同一で、検査の途中で意図したphaseが実際に成立したかを今後も記録する。試行2は単項目とBの失敗で公開がskipped、全ジョブ終端。両試行の成功範囲を次の正式に合算しない。

ebe3694の[明示選択限定44616309920](https://github.com/n624-dev/takupoke-ios/actions/runs/44616309920/attempts/1)・試行1、iOS26.5／SDK27.2（135885851122）は21:53:43 UTCにfailure。21:31:58に実ケース開始、Set Up以降に初期画面・入力の記録はなく、準備込み2400秒で21:52:15にexit124。所有端末の回収は完了した。実確認操作・新しいButtonの成否は未観測。同じ症状の前に候補を変更する根拠にはしない。

### 共通操作ログの初回Appleビルドが補間式の型検査で停止

- source4c7d931、SDK27.2、試行1の[週送り44683196548](https://github.com/n624-dev/takupoke-ios/actions/runs/44683196548/attempts/1)（iOS26.5 136111236071、27.0 136111236081）、[手動単項目44683292593](https://github.com/n624-dev/takupoke-ios/actions/runs/44683292593/attempts/1)（iOS26.5 136111548113、27.0 136111548445）、[ファイル選択44683454924](https://github.com/n624-dev/takupoke-ios/actions/runs/44683454924/attempts/1)（iOS27.0 136112082201）、sourcec7d4c2fの[カウントダウン初回起動44684004659](https://github.com/n624-dev/takupoke-ios/actions/runs/44684004659/attempts/1)（iOS26.5 136113890229）はすべて `ApplicationFixture+CITrace.swift:19:60` の `reference to property 'sequence' in closure requires explicit use of 'self' to make capture semantics explicit`。停止箇所はテストアプリのビルドで、Simulator実行・操作ログ配信・元ケースは未開始。週のNativeロジックは成功。開発ToolsのLinux副ジョブでは別途、既知のcleanup単体テストの読み込み漏れで失敗した。読み込み修正済みc7d4c2fのLinux全322件は失敗0・専用環境skip2。
- `capture semantics`・`autoclosure`・`ActorIsolatedCall`・型検査で索引を検索し、N143の同期関数とMainActor、N240の式型推論、当時の候補diffと共通ログ追加前後を比較した。今回の診断はApple `Logger` の遅延評価される補間が、クラスのプロパティを暗黙に捕捉することを拒否した。共通ファイルのLinux構文検査だけでは検出できなかった。ロック内の順序番号を先にローカルの値に写して渡す。Apple補間と同じescaping autoclosureを要求するLinuxの型検査に実クラスの出力処理を渡し、修正前で拒否、修正後で型検査成功を確認してから、最短のファイル選択でApple上のビルドと実ログを確認する。

### ファイル選択の起動し直し後にタッチ観測が登録されない

- [ed76633のファイル選択限定44685775729](https://github.com/n624-dev/takupoke-ios/actions/runs/44685775729/job/136119637082)・試行1、iOS27.0／SDK27.2は06:21:36 UTCにsuccess。ビルド16.0秒、boot85.4秒、既存XCTestの3件（176.653・180.922・32.173秒）、実行identity、幾何／再選択／取消／実結果のPASSはすべて成立。実配信342件・通し番号の欠番0だが、監視登録は初回PID4595のみ。他の4プロセス4960／5001／8024／9184はseq1が`picker-scene-connected`で、起動後の実タップがXCTestにあっても監視登録やUIKit配送が記録されていない。テスト結果の失敗ではなく、観測範囲の不足。
- `picker-scene`、`relaunch`、`event-observer-installed` で索引を参照し、N73の通信断・前項のビルド失敗・この実行の連番1を区別した。Pickerの`configurationForConnecting`は初回だけ呼ばれ、既存scene構成が復元された各起動では監視が未登録だった。毎プロセスの`didFinishLaunchingWithOptions`で観測を登録する。通常・手動は最初から毎起動の`ApplicationFixture.init`で登録する。Pickerの全PIDで登録とscene接続を確認し、物理操作のある各プロセスでは実タッチ開始／終了・配送完了を照合する。元のファイル選択検査は維持する。

### 全操作配信付きの週送りと単項目の実観測

- d5079ecの[週送り44688069401](https://github.com/n624-dev/takupoke-ios/actions/runs/44688069401/attempts/1)・試行1、SDK27.2。iOS26.5（136127063123）と27.0（136127063211）の連続操作は実4接触、4解放、4到着とslide中の開始／解放が成立。最初の横移動到着1384.6567／1322.4057に対し2回目の開始1384.5944／1322.3161は約62／90ms早く、height中開始の条件で失敗（57.320／113.906秒）。本番の画面タッチの配送は両OSで記録され、欠番0。配色は両OSで成功（174.944／298.414秒）。固定待ちで遅すぎた44536795734、早すぎた正式44660400847試行1、同一ソースで到着151ms後だった試行2と旧 `WEEK_MOTION_INSERTIONS`／現 `testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating` を比較した。
- 同じ限定の単独の枠検査では、26.5の整列前後の観測差が約0.099s（上限0.09）、main CPU増分約44ms。27.0の復路は実releaseの約1ms後に表示リンクが登録され、UIKitの同一処理から戻るまで約0.540秒、最初の枠の観測が0.647秒、実移動0.664秒（上限0.1）。releaseから初回観測までmain CPU増分約55ms。描画時刻の停止は観測したが、Logger・処理待ち・Runnerのスケジュールの内訳は未確定。正式505、44501853677、44527990308、44558479226および既存の `CADisplayLink`/昇格コードと段階別に比較した。観測の追加負荷を減らしてから同じ枠・同じ上限で再測定する。
- 同じd5079ec、[手動単項目44687892174](https://github.com/n624-dev/takupoke-ios/actions/runs/44687892174/attempts/1)・試行1、SDK27.2。26.5（136126488491）成功（514.935秒、2PIDでログ2161件、欠番0）。27.0（136126488112）は296.558秒、アプリ実タップ開始・終了、消去2回、入力、確認2回、背景復帰、レビュー実ボタンの開始と終了が成立した。UIKitの接触配信は完了、直後に20秒のレビュー状態を待って取得できず、事後AXは元の通常時間割の分析画面。復旧シートはAXに観測されなかった。`manual-submit`、`review-background` でN168の事後AXにreview=trueが存在した例と旧8cdf/現Input・Review・復旧シートのコードを比較した。今回のButtonから処理開始・復旧シート非表示の順は記録が足りず特定できない。レビューの実操作、20秒の要求、背景・再起動・保存の条件を残したままアクションと結果、シートの有無を観測する。
- [同じ候補のカウントダウン初回起動44687967639](https://github.com/n624-dev/takupoke-ios/actions/runs/44687967639/job/136126735263)・試行1、iOS26.5／SDK27.2は207.934秒で成功。両起動のfixture-ready、実UI、連動・警告・保存、完了照合が成立（2PID・209件・欠番0）。旧正式の起動返却停止はこのランでは再発していない。

### 週の観測通知がiOSのSwiftモジュールから直接見えず停止

- 02fc8d1の[週送り44692317652](https://github.com/n624-dev/takupoke-ios/actions/runs/44692317652/attempts/1)・試行1、SDK27.2、iOS27.0（136140801303）／26.5（136140801409）と、[単項目27限定44692551505](https://github.com/n624-dev/takupoke-ios/actions/runs/44692551505/job/136141559677)はいずれもビルド中に `ApplicationFixture+WeekMotion.swift:223` の `notify_post` と224行の `NOTIFY_STATUS_OK` をSwiftの `import Darwin` で解決できず停止した。実UIと今回の手動レビュー観測は未開始。週のMac Nativeロジックは成功。
- `cannot find in scope`、`notify_post`、SwiftモジュールでN123のファイル登録漏れ・上の補間問題を照合。今回の型の問題はC APIが公開ヘッダーでiOS対応でも、SwiftのDarwinモジュールに同じ宣言が含まれない点だった。AppleのSwift宣言にiOS対応が明記されたCore FoundationのDarwin通知へ切り替え、送出と購読に同じ小さなSwift実装を使用する。Linuxで実実装をCoreFoundationに対して型検査し、Apple側の名前型初期化の差はApple公開Swift宣言で確認する。Swiftを通した型検査と実際の通知を週送りで観測してから手動へ広げる。

### 正式公開5cc39a5の27 Bは起動後のAX表示待ち、明示選択は外側の時間上限

- [正式44700448423のiOS27.0 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136168955479)、試行1、SDK27.2は08:47:09 UTCにfailure。`testHomeTimetableAndWeekCalendar`（133.493秒）は一度のXcode起動と前面待機を通り、実PID16318が08:27:25 UTCまでに初期化・画面表示・実データの`fixture-ready`を記録した。XCTestの `fixture-ready` 要素の45秒待機は空のAX query chainで失敗し、ホーム操作に未到達。他の基本7件はカウントダウンと両方向の週送り実描画も含め成功。実配信2024件、欠番0。カウントダウンでXcodeの一回の起動そのものが返らなかった旧正式44660400847試行2、N159の同じケースで`root-task-enter`以前に止まった例と、c0605c4／現行の同じ実AX 45秒待機を照合し、旧事象と分けて扱う。AXセッション内部の原因は未確定。
- [同じ正式のiOS27.0明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136168955684)は08:56:02 UTCにfailure。実SIM boot 522.9秒、ビルド150.3秒、外枠開始08:14:43 UTC、ケース開始08:32:48 UTC。各回の実入力・6回の確認、3回の実submit受理とレビュー準備、元のレビュー本文の検査を進め、t1314.60の画面照会中に準備込み2400秒でexit124。実3072件・欠番0、XCTestのassertion失敗はなく、後続の4項目拒否と採用・再起動の完了は未確認。N243／N162のログ欠落と7c05ef7／現行の外枠、旧限定の同じ明示選択完走を照合。先に残る通常27 Aとその依存の終端を確認する。今回観測した後続ケースのAX応答や明示選択の進行を根拠に、新しいホストで元のケース・閾値を使う失敗ジョブ限定の再検証を候補とする。完走した検査だけを正式の成功に数える。
- [正式の27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136168955632)は09:01:35 UTCにsuccess。行訂正491.546秒、連続週送り29.237秒で実height操作を含み全条件成立。実配信5396件、欠番0。26 Aはその直後から実行を継続。正式とコード差分0の[ホーム・時間割の限定44709467432](https://github.com/n624-dev/takupoke-ios/actions/runs/44709467432/job/136197191461)は別のiOS27.0／SDK27.2ホストで09:33:28 UTCにsuccess。同じ問題のホームケース80.966秒、他の実教室変更170.570秒・結合カード124.875秒、3件の実行元・完了照合に成功。実2255件・3プロセス・欠番0。限定ではケースの順序も異なり、正式B全体の完了として使わない。この実AXと後続操作の成功を根拠に、正式終端後は同じソース・元ケースに対して失敗ジョブ限定の1回を行う。別の箇所で失敗が判明した場合はログを先に比較する。
- [正式の26 A](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136189678821)は10:03:27 UTCにsuccess。行訂正497.414秒、実heightを含む連続週送り30.582秒、同シミュレータの元全検査を完走。実配信5588件／35プロセス、欠番・戻りの欠落0。試行1が既知の2件だけ失敗で終端したため、コード差分0と新規レビューを照合して失敗ジョブ限定で再実行した。[試行2](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/attempts/2)を同じ5cc39a5・10:11:10 UTC開始と確認した。この正式内で再実行された元ケースと依存の結果を照合する。

### 正式5cc39a5試行2は明示選択が完走し、27 Bの別ケースでXcodeが起動を返さない

- [明示選択27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136223030253)は試行2、SDK27.2で10:33:46 UTCにsuccess。元ケース987.096秒、3回のsubmit・レビュー、四項目拒否、採用と実再起動、実行元と完了確認を通過。実配信4919件・2プロセス・欠番0。試行1で終了した40分の外枠を維持。
- [同じ試行の27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136223029673)は10:43:29 UTCにfailure。前回失敗の`testHomeTimetableAndWeekCalendar`が120.048秒で実UIまで成功。他の6件も成功。今回は初回に成功した`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent`が212.531秒で停止し、`ApplicationChecks.swift:128`の一度の`app.launch()`が10:26:11 UTCにtimeout。SpringBoard前面確認、一度の送出、対象PID12227で`fixture-ready`とscene activeの成立（10:24:30 UTC）まで記録した。XCTestへの起動返却とカウントダウン操作には未到達。実配信2130件、11プロセス、欠番0。旧正式44660400847試行2の26.5で同じケース・対応SDK27.2・アプリ準備／起動返却の不一致を観測。今回の試行1の空AX待機、N95のアプリ準備未観測、43767607953と現行の一回起動を区別して照合した。初回の27同一ケース（232.083秒）と26.5限定44687967639の元ケース（207.934秒）は実完走。この根拠で、試行2終端後は同じソースの27 B一件とその依存のみを新規ランナーで検証する。起動やAX期限、正式公開条件を維持する。Xcodeが返らなかった下位の原因は未確定。

### 正式5cc39a5試行3はSimulatorの通信断でXCTest開始前に停止

- [iOS27.0 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136239827973)・試行3、SDK27.2、10:58:17 UTCにfailure。ビルド139.0秒、bootstatus189.2秒の後、最初の`test-without-building`で `Failed to install or launch the test runner`、`Mach error -308 - (ipc/mig) server died`。実XCTest／アプリ運転は開始せず、実配信0。清掃前の正確な所有UUIDはruntime available、device Shutdown。状態保存と元の回収は完了。公開は依存skip。同じ試行の他の失敗なし。
- `ipc/mig`、`server died`、`test runner`、`Shutdown`で索引を検索。N169の別のCoreSimulator例外では所有端末はBooted、N127ではXcodeが所有UUIDを解決する前の停止。今回の試行2では対象アプリはすでに前面・準備済みで、同じ停止段階ではない。現行 `boot-simulator-ui.sh` とXcode起動前後、旧N169のRuntime診断の経路を照合した。アプリケースを一度も実行できておらず、他ホストの同じ正式では元のケースに到達しているため、同じSDK・ケース・期限のB一件を新しいランナーで一度確認する。失敗済み試行は保持する。

### 正式5cc39a5試行4で授業カードのタップ位置取得と週送りの初動が停止

- [iOS27.0 B](https://github.com/n624-dev/takupoke-ios/actions/runs/44700448423/job/136259727545)・試行4、SDK27.2、12:02:16 UTCにfailure。旧カウントダウンは278.506秒で成功。ホーム・時間割では起動／ホーム／カレンダータブの実接触・遷移が成立後、結合授業の一意な実枠・enabledが得られた直後の別のXCTest照会 `card.isHittable` が `Activation point invalid and no suggested hit points` で終了（Timetable.swift:66、147.217秒）。授業カードへの実接触は未開始。`Activation point invalid` と`readyWeekCard`でN126/N160、91f6b41の以前の結合授業と現在のsnapshot＋ラベル再照会を比較した。今回は単一実画面上で完全包含まで成功した後の再照会。実際のタップを一意・enabled・画面とGridの可視範囲に完全包含する同snapshotの実枠から1回だけ送り、現実の詳細を元の期限内に観測する候補とする。
- 同じ試行の単独週送りは初動0.2439405秒が既存0.10上限を超えた（WeekAppearance.swift:240、28.645秒）。実release直後の表示リンク登録は約0.8ms、そのUIKitイベントの処理が戻ったのは約0.202秒後、最初の実サンプル0.227秒・その時点のmain CPU増分約34ms。最初のサンプルでは移動なし。記録を非同期に変えた後も発生し、mainスレッドが進まなかった時間は観測できたが待ち先は未確定。直前の`testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis`は成功。d5079ecの同類、d5bec5fの両限定の初動・正式試行2の同じ描画成功、現行の`WeekSlideClock`／`before-settings`を比較した。Bの描画計測だけを初回の専用フェーズにし、重い復旧・OCRを前に走らせない。ビルド使い回しと同じ端末、全ケース、描画・タップ・実画面の元の上限を維持する。実配信1874件、12プロセス、欠番0。他の元ケースは6件成功し、公開は依存skip。

### 限定4aa3a29での起動進捗と対象外ケースの時間切れ

- [iOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44734888974/job/136283690540)・試行1、12:46:56 UTCにfailure。先頭の週送り実描画（52.654秒）とホーム・時間割（99.623秒）は成功した。続く `testMergedCardsFromAllSources`（343.683秒）、二件目の同じXCTest Runnerで12:40:36 UTCに一回の起動を要求。実アプリPID30117は12:45:22 UTCに初期化を始め、12:45:26にscene activeとfixture-readyを記録した。12:46:16、`ApplicationChecks.swift:128`で `Timed out while requesting launch progress`。カードの照会・接触前。実配信423件、欠番0。`testMergedCardsFromAllSources`、`launch progress`、`fixture-ready`で限定43767607953・6ee6857の同じケースおよび正式44700448423試行2を照合し、当時と現在のlaunchReadyは同じ一回の起動と準備確認。今回の起動要求からプロセス開始までの約286秒と、アプリ初期化の約4秒を区別する。待ち先は未確定。専用の最初のXCTest Runnerで同じ1ケースだけを実行し、他ケース後の起動を避ける。正式Aの登録、起動手順、操作期限と受入条件を維持する。
- [iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44734888974/job/136283690100)・試行1、12:45:56 UTCにfailure。対象3ケースは週送り55.632秒、ホーム89.590秒、四種類の実授業カード98.974秒で成功。設定ケースは12:36:34 UTCに開始し、架空ファイルの詳細で「件数」の表示を照会中の12:44:30 UTCに外側1440秒の上限へ達した。終了124、直前までシミュレーターで実操作が記録され、XCTestのアサーション失敗は見つからなかった。実配信1653件、欠番0。過去の43767607953の長いrowsケースと同じく、準備・先行操作も外側期限の内数。設定はBと同じフェーズを作るため限定に含めたが、残る確認はiOS26の四種類だけなので専用選択肢に絞る。正式Bの設定ケースと期限は維持する。

### 正式e59d1ff試行1で設定タブの画像照会が接触前に停止

- [iOS27.0／SDK27.2の手動単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44741890239/job/136309373717)・試行1、13:33:08 UTCにfailure。`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`（161.303秒）。実PID13321は13:28:46にactive、13:28:46.975にfixture-ready。XCTestは元のfixture-readyを確認し、TabBar、設定Button、`gearshape`まで取得した。13:29:47に同じButton下のImageを列挙し、13:30:33に`NativeTabActivation.swift:60`（`liveButton.images.allElementsBoundByAccessibilityElement`）が `Failed to resolve query: Timed out while evaluating UI query`。最初の設定タブ実接触・訂正・背景・採用・再起動は未到達。実配信は起動18件、1プロセス、欠番0、タッチ0件。
- `NativeTabActivation`、`Timed out while evaluating UI query`、`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`でU63、N174、正式44513210500の6bc3c18、正式44499001313の3fc31e1を照合。先行6bc3c18の明示選択はTabBarの下のButton列挙、3fc31e1の単項目は採用と元プロセス停止後の再起動で止まった。今回は有効なButtonの照合後のImage列挙。タブの実接触が完了した過去のケースとも区別する。実際の`NativeTabActivation.swift`と`ManualAssistanceChecks.swift`をd5bec5fと比較し同一。d5bec5fの限定44697199129と正式5cc39a5試行1でiOS27の同じ元単項目に成功している。XCTest照会の下位の待ち先は未確定。同じ段階を同じ候補で初めて観測したため、残ジョブの終端後に、失敗したジョブと依存だけを同じソース・SDK・期限の新しいRunnerで一度確認する。残りを取り消さない。

### 正式e59d1ff試行1で時間割変更の再起動後の表示照会が停止

- [iOS27.0／SDK27.2の通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/44741890239/job/136309373596)・試行1、14:04:06 UTCにfailure。元の`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`（453.224秒）1件だけ失敗、残る通常ケース19件は成功。2行の実学年入力、反映の取消と実反映、前プロセス停止と一回の再起動、103行・解析済み・除外範囲の保存を通過。新PID28806で設定・資料・変更詳細のタッチ配送を観測した。13:34:44から残す「変更後、架空科目C」の表示を調べ、NavigationBar・TabBar・rootの診断照会も長く待機。13:38:32に `ApplicationChecks+Navigation.swift:136` の `app.frame` が `Failed to get matching snapshot: Timed out while evaluating UI query`。次ケースは同PIDをterminateと記録し、実描画を見られたのはここまで。途中の監視は所有実行パスの一致が取れず `owned-app-unavailable`、スタック未採取。クラッシュ・画面不在・メインスレッドの待ち先は確定していない。Aの配信4718件、欠番・配送戻り欠落0。四種類のカードは88.018秒で成功。依存26 Aはskip。
- `変更後、架空科目C`、`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`、`UI query timeout`でN153、d8d32e4／2acdaf1／67273c0と今回の`contentViewport`と行ケースを照合。N153の正式は同じ再起動後のCの表示探索で旧Keyboard列挙まで遅れ、今回はrootのframeで例外になった。N153の限定では同じ元ケース204.433秒、新しい正式67273c0では277.549秒でC保持・B除外を含め成功し、全15成立で449.1を公開した。直前の正式5cc39a5でも同じSDK・Runtimeで行ケースが通り、今回の製品と該当helperは5cc39a5と同一。今回タッチと再起動後の保存到達が記録できたため、同じ条件の全Aを新しいRunnerで一度確認する。手動単項目と同様に、残るジョブ終端を確認して過去の成功を繰り返さず、元の試行の失敗を保持する。

### 正式e59d1ff試行2で通常27 Aがジョブ全体60分に到達

- [通常27 A／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44741890239/job/136373731984)・試行2、15:13:51 UTC開始。15:14:07にRuntime準備完了、ビルド123.7秒、Simulator boot421.2秒、15:25:56にAのXCTest開始。試行1で失敗した `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch` は945.231秒で、C保持・B除外を含めて成功。カード四種類も94.508秒で成功。18件が成功・XCTestの失敗記録0。19件目の `testTimetableCommonClocksAndEventOnlyWeekScale` は16:12:40から進み、16:14:04に打ち切られた。GitHub注記は `The job has exceeded the maximum execution time of 1h0m0s`。残りの基本ケースと独立通知の正式照合は未完了。実配信5031件、31プロセス、欠番と未返却0。主担当の取消はない。
- `60分`、`1h0m0s`、`ジョブ全体`でN217、正式498/499およびd66d60fの通常27 Bと当時・今回のworkflowを比較。先行27 Bでは通常全ケース後の通知が外枠で止まり、75分に変更した。今回27 Aは同じソースの試行1が全20件を50分06秒で走らせており、今回は実起動約7分と行ケース約16分が合計に入った。前のAX失敗は再現しておらず、元のA一件が全結果を返すかを別Runnerで一度確認する。公開には今回の未到達分を含む全ケースの成功を必須とする。既存の成功済み8ジョブは保持し、27 Aと未実行の依存だけを対象とする。

### 正式e59d1ff試行3で時間割変更の再起動後、設定タブへの接触前に停止

- [通常27 A／SDK27.2、iOS27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/44741890239/job/136410611583)・試行3、16:57:28 UTCにfailure。`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`（559.169秒）で反映と最初の表示が成立し、終了後に新PID32589がactiveとfixture-readyを記録。16:34:38から設定タブを照会し、実TabBar、Button、Imageの一意性を各二度観測。後半の画像再照会のあと、16:36:02に`NativeTabActivation.swift:74`が期限内の接触点を得られずfailure。このPIDで設定タブへの実接触は未開始。時間割変更詳細の再表示は未到達。ほか19件は成功、配信5262件・33プロセス・欠番と未返却0。公開と26 A／26手動は依存skip。
- `NativeTabActivation`、`current native images`、`変更後、架空科目C` で正式44513210500の6bc3c18、正式522試行1・2、N153の設定／時間割表示を照合。今回は前回のiOS27単項目と同じ共有ヘルパーの再照会で接触前に止まり、試行1の通常Aで止まった保持科目の照会には届いていない。試行2では両操作が成立した。6bc3c18では元のsnapshot以前のButton列挙が停止した。現在の実画面の一意で有効なタブと画像・包含を同じ実snapshotで確かめ、その座標への一回の実接触と両callerの実タブ選択を維持する。遅い再照会自体を減らす。同じ通常Aの関連する保持科目は元の厳格な完全可視判定と実スクロールを使い、表示領域とラベルを同じ実snapshotで観測する。原因をOSや実アプリの不具合とは断定できない。

### 限定0741379で、反映直後の表示領域が新しい取得方法から得られなかった

- [限定rows iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44780949309/job/136443165860)・試行1、17:26:01 UTCにfailure。実設定タブには座標(320.25,793)で一回の開始・終了が配信されて画面選択を通過。除外、二行の学年入力、取消・再度の実反映、103行と解析済み・除外範囲を確認した。反映直後の保持科目を探す新ヘルパーでは17:24:06以降に対象app snapshotへ繰り返し照会し、観測した表示領域からのログが0行、スクロール未送出。17:24:34に `ApplicationChecks+Changes.swift:221`、元のケースは211.788秒でfailure。どの観測条件が欠けたかは確認できない。再起動後は未到達。137件／1プロセス、欠番と未返却0。
- `retainedChangeIsVisible`、`変更後、架空科目C`、N153、正式522試行2、194672cの両OS限定と現在のヘルパーを比較。先行の実表示検査では個別の対象・表示領域の観測でスクロールでき、同じ操作と再起動を通過した。全体snapshot必須にした候補差分を取り消し、旧 `visible` による同じ実画面での完全可視・実スクロールへ戻す。元の反映後／再起動後の保持科目と除外、各期限は維持し、その実確認を通過した段階を記録する。実配送を確認した共有タブ修正と、各OS独立の配布CIを候補に保持する。

### 限定の時間割変更で、保存した3行目の除外解除が変化しなかった

- [76042ccの限定rows iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44785460957/job/136459034395)・試行1、18:01:13 UTCにfailure。元ケース427.067秒。設定タブへの実接触を新旧2プロセスで確認し、反映後と再起動後の保持科目Cの完全可視と除外科目B不在、保存103行と範囲を通過。再起動後の実3行目で有効なSwitch内側と外側が値1、内側枠(300,705.667,63,28)。一回の水平ドラッグでtouch15が(347.333,719.667)から(315.667,719.667)へ到達、開始から終了までイベント時刻200ms、配信時刻約94ms。実終了とUIKit処理戻りも記録。17:56:59、`ApplicationChecks+Changes.swift:217` で元の15秒以内に値0が成立せず、最終AXは値1。残りは未到達。実配信446件、2PID、欠番・未返却0。入力は到達し、受け手が値を変えなかった理由は未確定。
- `この行を除外`、`thumb-drag`、`N239`、8b2f030、旧e11398dと現在の`tapNativeSwitch`を照合。以前の選択操作には開始だけや極短接触の例があり、今回は現在の水平操作が終了まで届いた。独立した実タブ・訂正入力に使う `NativeTestContacts` の時刻指定を、元の個別保存行の三操作に使う。内外の実値・有効・hittable・完全包含、同じつまみの開始と反対側、0.33秒の実接触一回、元の15秒と値0／1・取消／保存を維持する。通知・設定・カウントダウンの操作は元の方式を使う。
- [0741379の先行iOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44780949309/job/136443165356)・試行1は17:50:52 UTCにfailure。ビルドと起動準備の後、XCTest Runnerが `Timed out waiting for AX loaded notification` で開始不可、元ケースの実行・アプリ観測0件。先行e59d1ffでの起動進捗返却や旧Mach IPCと区別する。対象行に着く前の環境側停止で、今回の27で実接触したスイッチの結果とは別に記録した。

### 独立した行編集の照会が、後続の実操作より前に停止

- [b880e5fのiOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44789807104/job/136474167690)・試行1は18:30:44 UTCにfailure。元ケース413.801秒、実設定への接触と学年入力後の「選んだ行に入力」の開始・終了を確認し、レビューのNavBarまで戻った。18:28:04に実「反映する」ボタン列挙、ボタン一件を得た後、次の照会で期限を使い、18:28:27にNavigation.swift:77。照合最終値は `matching native buttons=1` まで。ボタンの実接触・確定・個別の時刻付きSwitchは未到達。121件／1PID、欠番と未返却0。
- [76042ccのiOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44785460957/job/136459034714)・試行1は18:21:14 UTCにfailure。元ケース507.414秒。設定・資料・編集グループに到達し、実 `change-select-row-3` の存在と枠の照会が返った。その後18:12:18から同じ候補数を再照会し、18:18:05にChanges.swift:123でAX snapshot timeout。行ボタンの実接触前。35件／1PID、欠番と未返却0。
- `反映する`、`matching native buttons`、`change-select-row-3`、`snapshot` から旧44641545708（反映Buttonの枠の照会停止）、先行194672c（同じ表示・反映・再起動の両OS成功）、8b2f030（実接触の開始後）、現在の`tapToolbar`／`selectRows`を照合。レビューの元10秒待機を保って、反映Buttonは指定NavBarのsnapshot一回で一意・有効・完全包含を判定して実中心へ一回接触。対象行ボタンは元の実表示とスクロール、同じ一意な識別子・有効・未選択を確かめ、中心への一回の実接触と元15秒の実選択を維持する。元の確認・取消・保存・再起動・個別Switchは省かない。配布アプリと他のテストの操作は維持する。
- [b880e5fの先行iOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44789807104/job/136474167091)・試行1は18:52:49 UTCにcancelled。限定runner開始18:11:02、ビルド219.4秒、実端末boot422.2秒、実ケース開始18:39:45。反映後の103行・範囲の確認から保持科目の照会を行っている途中、18:51:02にrunner2400秒の上限。GitHubでもjob全体45分上限の注記、終了124。145件／1PID、欠番・未返却0。設定への一回の実接触・反映の実送出は観測した。元ケースの完了、再起動後の検査、個別Switchには未到達。43767607953の準備時間に起因する旧限定停止および522試行2のジョブ全体枠と比較し、元のアサーション失敗と分けた。主担当の取消はない。

### 正式82860ce試行1でiOS27の手動単項目がSimulator起動中に中断

- [iOS27.0／SDK27.2の手動単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44800663590/job/136513472111)・試行1、19:30:16 UTCにcancelled。開始19:20:29、Runtime選択・端末作成・ビルド175.2秒が成立。19:26:06から所有端末のbootstatus、19:29:04にGitHub注記 `The operation was canceled.`。2400秒の監督期限や45分のジョブ上限より前で、元の `testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground` の開始・実配信ともに0。XCTestのアサーション、Mach IPCエラー、ホストとの通信断の明示はない。主担当による取消はなく、GitHub側の中断理由の詳細は未確定。
- `boot`、`cancelled`、`The operation was canceled`、`Mach error -308` を照合。旧44641545708はホスト通信断注記あり、522試行2は1時間の上限、5cc39a5のB試行3はbootstatus完了後のRunner起動時Mach停止。今回の停止はケースより前で、0741379の先行限定iOS27は同一の共有タブ・手動処理で全ケースが通過した。同じ公開実行の他ジョブを終了まで確認し、失敗・中断した必須ジョブと依存だけを実際の終端理由に基づいて再実行する。

### 正式82860ce試行1でiOS26 Bの横到着から次の実描画まで182ms

- [iOS26.5／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44800663590/job/136513472164)・試行1、20:20:33 UTCにfailure。最初の独立フェーズ `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（57.159秒）。往路初動28.863ms、横到着0.216372秒と次の実フレーム0.398705秒の差182.333msが`ApplicationChecks+WeekAppearance.swift:312`の90msを超過。昇格〜スクロール復帰0.43ms、幾何欠落0、目的週x16で旧高238.333pt。横到着から最初の次枠まで同じmain thread CPU約175.8ms、`configuration-begin`は0.355738、実設定時間0.082ms。同期昇格の外で主スレッドが多く処理していた事実は確認できるが、SwiftUIのどの処理で時間を使ったかは未確定。57件／1PID、欠番・処理戻り欠落0。残るBケースは未到達。同じ正式の27 A全21実検査と27 Bは成功し、26 Aと手動26二件は継続。
- `horizontal-arrival`、`configuration-begin`、`0.09` と4d30920／c4546bf／bf35cfc、d5bec5f、e59d1ffを比較。旧c4546bfと4d30920にも到着直後のCPU差約89〜91msがあり、bf35cfcは高さ調整途中で約135msを記録。直前e59d1ff正式522試行1の26 Bでは同じ週送りコードと先頭フェーズで全ケースを成功、4aa3a29の26限定も初動46.22／47.98ms・高さ最大83.41ms。同じ製品 `WeekPagesLayout`／`settle`／`promote` および実描画ケースを比較し差分なし。今回も復旧・OCRより前。基準と全ケースを保ち、同じ公開実行が終端した後にこれまでの成功を引き継いで対象Bを新Runnerで一回確認する。再現した場合はメインスレッドの処理内訳と調整経路を調べる。

### 正式82860ce試行2の手動単項目で消去後のキーボードが入力前に閉じた

- [iOS27.0／SDK27.2の手動単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44800663590/job/136563363412)・試行2、21:08:41 UTCにfailure。元の `testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`（144.503秒）は設定タブと復旧画面へ到達した。科目の実消去ボタン(317,565.667,44,44)に一回接触し、対象PID19107で消去のsetter、編集開始、keyboard did-showを記録。did-showから約679ms後、追加のタッチ配送と入力送出の記録がない状態でkeyboard will-hideが発生し、編集終了とdid-hideを記録した。空欄・確認解除の照会は通過したが、21:07:28に `ManualAssistanceChecks+Input.swift:99` の元のキーボード確認で停止。全文入力・確定・再起動には未到達。実配信205件／1PID、欠番・未返却0。フォーカスが外れた経路は未確定。
- `keyboard-will-hide`、`text-edit-ended`、`Input.swift:99`、`消去` とN52／U17／N191を照合した。N52は空欄後の確認コントロール照会、U17はキーボードを確認後の追加照会、N191はiOS26.5で全文入力後の完了ボタンとキーボードが不在。今回は入力前に表示と閉鎖の両通知があり、最終画面には復旧シートと空欄・未確認の科目、通常の閉じる操作が残った。旧正式e59d1ffから `PDFRecoveryView.swift` と手動入力・期待値のコードは同一。[その27単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44741890239/job/136373732851)が537.927秒、[現在と同じタブhelperを使う0741379の27限定](https://github.com/n624-dev/takupoke-ios/actions/runs/44781058037/job/136443541524)が631.621秒で全文・背景・保存・再起動まで通過。この正式の26単項目と27の残り3種も成功した。今回の実閉鎖は先行のSimulator起動中断とは異なる。残る正式ジョブの終端後、同じ製品・SDK・ケース・期限で27単項目のみを一度、新しいRunnerで確認する。同じ閉鎖が再現した場合は再実行を重ねず、フォーカスの変化と画面構成を確認する。

### #120の通知日回帰を追加した時点のLinux件数検査

- 5906340を基に公開前の通知日ケース一件を追加したローカル差分。Linux x86_64／Swift 6.1.2でUI manifest検査38件中1件失敗、19.996秒。`test_all_source_tests_are_assigned_once_and_both_os_checks_are_required` の件数が旧38に固定され、新しい宣言と登録の39件を拒否した。実機とApple CIは未実行。旧5906340と登録一覧を比較して元の38件がすべて残ることを確認し、39件の厳密照合と限定の2件選択を検査する。

- Linux x86_64／Swift 6.1.2の最初のローカル対象実行は、直接の `swift test` からGRDBの `sqlite3.h` を解決できず、対象ケース開始前に終了。以前の0.1.523のLinuxパッケージ検証と同じ `tools/test-parsing.sh` に戻し、`TKPK_ZLIB_PREFIX` から対応するヘッダーと共有ライブラリを渡す。Apple側のテスト条件は維持する。

### #120の限定2655abcでiOS26の最大日数入力が切り詰められた

- [iOS26.5／SDK27.2の限定44890464202・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44890464202/job/136804939924)は09:52:40 UTCにfailure。通知日の元ケース52.907秒。最初の「7」は実ラベル枠(32,651,79.667,20.333)と数値枠(256.667,650,70.333,22)で同じ行。実数値欄への接触、実キーボード、deleteと6桁の入力に続く編集変更7件、実「保存」のタッチ、再入場が成立した。09:49:29 UTC、保存後の値は `365,000` の期待に対し `3,650`（ApplicationChecks+Notifications.swift:234）。入力直後の表示値は前候補のテストでは採っておらず、整数変換と保存のどこで変わったかは未確定。最大文字サイズと個人予定には未到達。実配信178件／2PID、欠番・処理戻り欠落0。黄色の実表示ケースは同じジョブで成功。
- [同じiOS27.0／SDK27.2のジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/44890464202/job/136804940135)は09:52:07 UTCにsuccess。通知日の全経路は191.855秒で、最大365,000と0の再表示を確認。標準・最大・アクセシビリティ文字サイズの実PNG、実配信445件／2PID、欠番・処理戻り欠落0。黄色も成功した。
- `3,650`、`numberPad`、`formatStyle`、`field-edit-changed` で検索。N163の年度欄はキーボード表示前、直前の523.3手動訂正はキーボード表示直後に消失し文字入力前で、今回の入力通知7件とは別段階。公開82860ceと失敗2655abcを比較し、数値formatで直結した整数Bindingと通知日の保存処理は同じで、今回が最大桁の初めての両OS実比較。AppleのTextField仕様では変換できない値はBindingへ進まない。入力中は生の文字列を確保し、変換できる値を同期で整数へ反映する。グルーピングは編集終了後だけ表示し、既存の有効範囲・保存先・予約時刻は維持する。保存直前にも入力欄の実文字列全桁を確認し、再入場時の保存値と区別する。

### #120の削除回帰で編集中の値が後続の行番号に表示された

- [54f6d4fの限定44894076296・試行1、iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44894076296/job/136815869070)は10:38:38 UTCにfailure。通知日ケース185.266秒。試験編集の365,000と個人予定の0について、実入力・確定・保存後の再表示と、標準・最大サイズを通過した。個人予定の先頭を0から2へ実入力後、10:34:49に条件削除を一回送出。キーボードの非表示と実編集終了が記録されたが、10:34:53に新しい先頭の表示値が元の次条件1に対し2だった（ApplicationChecks+Notifications.swift:234）。この試行は表示で停止したため保存値の変化は未確認。黄色のケースは143.175秒で成功。実配信547件・2PID、欠番・戻り欠落0。
- `focus|row identity|index|再利用` で索引を検索し、N52（SwiftUI行再生成後の確認要素）とb95d7c2、54f6d4f、現コードを比較した。今回はキーボードと編集終了を観測した後も、画面の同じ識別子・行番号に旧入力が残った。条件を増減するたびに入力欄の世代を更新して編集状態を破棄する。旧世代の入力Bindingは書き込みを拒否するため、条件数が元に戻った場合も別の行を変更できない。残った行の値を削除直後と保存・再入場後の両方で検査する。
- [同じ試行のiOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44894076296/job/136815869287)も10:43:12 UTCにfailure。通知日ケース230.601秒。10:39:07に同じ削除を実送出し、keyboard did-hideと編集終了後、10:39:13に同じ2対1で停止した。配信676件・2PID、欠番・戻り欠落0。黄色は172.564秒で成功。両OSの同じ停止段階を確認した上で、フォーカスだけを閉じる同条件の反復はせず、旧入力欄を世代交代させる候補で検証する。

### 通知日VoiceOver限定で隣のラベルを直接触れても発声を照合できなかった

- [4b1054fの限定44898808370・試行1、iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44898808370/job/136830094231)は11:53:17 UTCにfailure。元通知日ケース87.246秒。試験の自動表示・標準の実数値7・実ラベルと数値欄の枠まで確認。VoiceOverを有効にし、11:51:01にラベル中心(72,661.333)への接触を実配信し、終了と処理戻りを確認した。45秒内にラベルの発声を照合できず、11:51:47にApplicationChecks+Notifications.swift:357で停止。発声が取得できなかったか、取得内容が異なったかは前回ログから区別できない。実数値欄への接触と両エディタの発声照合には未到達、実配信37件・1PID。正式#524のiOS27 Bは別に成功。
- `VoiceOver|currentSpeech|moveForward|noSpeech` でU66/U74、N170、旧限定44453291004と正式08d2b4aのXCTestを比較。直接接触が確認できてもVoiceOverの選択移動までは証明できなかった。正式の既存ケースが使う `moveForward()` で次の実要素の読み上げを観測し、両エディタの「予定の何日前」と単独値7、続く保存・再表示を同じ条件で確認する。正式の配布条件と製品コードは変えない。

### 通知日VoiceOver限定で最初の次項目命令がCode3を返した

- [f27a377の限定44902816687・試行1、iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/44902816687/job/136842113655)は12:29:11 UTCにfailure。元ケース52.507秒。試験の自動表示、入力7と実表示枠、VoiceOver有効化まで成立。最初の `moveForward()` は `AXVoiceOverAutomationErrorDomain Code=3`（Failed to send moveForward command）で12:27:43 UTCに停止。発声が返った移動は0、実配信28件・1PID。個人予定には未到達。U66/U74および限定44453291004の最初の移動停止と同じコードで、製品コードは正式と同一。
- U66の成功では元の見出しへ0.1秒の実接触を一回送った後、実18移動を確認。U74では同接触後も初回発声が取れず、続いて最初の移動がCode3を返した。通知欄では数値7の実入力欄を一回触れ、まずシステムから初回の発声が返ることを明示的に要求する。初回の発声で対象値が確認できればその結果を使い、発声が返り対象でないときは次項目へ移動して確認する。返答がなければ同じ条件で移動を重ねない。

### #124の外観限定で、スイッチ画像の画素数計算が型検査で停止

- [外観限定44915823020・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44915823020/attempts/1)、source`ddec081cb86438d4d46333185d74286688f0776e`。SDK27.2のiOS27.0 job136881090987（23時51分18秒終端）とiOS26.5 job136881090716（23時57分29秒終端、日本時間）は、`testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch`用のビルドで`ApplicationChecks+WeekAppearance.swift:186`の`pixels.count`を整数として解決できず、`generic parameter 'E' could not be inferred`、終了65。両方とも実テスト開始・表示・実接触には未到達。
- macOS26／Xcode26.6のNative job136881090967は同日23時49分02秒に終了1。GitHub上の固定`ZIPFoundation`取得にHTTP 403が返り、パッケージビルドと色のテストは未到達。同じ試行のApp UIジョブは依存解決後にアプリ・テストのコンパイルまで進んでおり、403とSwift型エラーは別の停止段階。403の下位原因は未確定。
- `generic parameter|型検査|ZIPFoundation|failed to clone`を索引で検索し、N67・N143と`08d2b4a`の色サンプラーを照合した。旧版は配列の`.count`を使い、`stride`自体はループにだけ使用していた。今回の`StrideTo<Int>`の`.count`は件数プロパティではなく`Sequence.count(where:)`。LinuxのSwift 6.1.2でもアサーションの式を`-typecheck`すると同じ2診断が再現した。画素の総数をRGBAバイト数÷4で計算し、有意に変化した画素は`count(where:)`で数える。色・実画像・変化10％の基準は同じ。依存403は以前の成功と今回のUIで同じ固定依存を取得できた事実を確認し、次の候補の新しいRunnerで一度確認する。依存の版・公開条件は維持する。

### #124の標準ライトで黄色と濃い文字は描画され、輪郭幅の測定が0

- [外観限定44917689867・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44917689867/attempts/1)、source`86689da2c2db7f9ec86b0249e1b7d5e667644deb`、SDK27.2。iOS26.5 job136886725452（実123.144秒）とiOS27.0 job136886725507（126.721秒）で選択済み週の保持と、設定の黄色＋濃色の描画を通過。設定の黄色／濃色画素数は26が10,107／1,118、27が10,109／1,116。日付ボタンは26が28,953／2,264、27が28,318／2,260。黄色面とその内側の文字は両OSで確認したが、日付ボタン外側の濃い輪郭の中央値は両方0ピクセルとなり`ApplicationChecks+WeekAppearance.swift:123`で停止。元のオレンジ・緑は通過。既定・青、高コントラスト・スイッチ・ダークには未到達。両OSとも配信74件／1PID、欠番と戻り欠落0。macOS26／Xcode26.6 job136886725208は依存を取得でき、770件中失敗0・予定skip1で成功。
- 停止点のアプリの画素は記録したが、輪郭判定前にボタン画像を出力していなかったため、前候補で輪郭が描かれなかったか、ガラスによる合成や画像範囲で候補色の画素が取れなかったかは区別できない。
- `glass|輪郭|capsule|strokeBorder`を索引で検索し、標準週ボタンの過去のガラス枠記録と`08d2b4a`・`86689da`の合成順を比較した。旧版はガラスだけを使用し、候補で黄色塗り＋内側strokeを同じガラス合成に重ねていた。暗い不透明なカプセルを下に置き、同形の不透明な黄色の面を標準1pt／高コントラスト2pt内側に配置する。他の色、両隣の週ボタン、タブ・スイッチは既存の標準部品を使用する。日付の見えている画像を判定前に出力し、同じ暗色画素・中央値・幅の条件で照合する。欠けや合成が原因だったとは断定しない。

### #124の背景を塗る案を利用者の指示で取りやめ

#124の着手時の候補は設定アイコンの背景を黄色で塗り、日付ボタンを塗りと輪郭で強調した。利用者はiOS26.5の架空データ画像を確認し、既存のアイコンの線の色だけ変え、塗りや囲みを加えないよう明示した。公開候補は0.1.524のコードから作り直し、未公開だった塗り・輪郭、ホームと時間割の変更は取り込まない。旧候補の実行はiOS26／27の表示検査で、公開ジョブを含まない。標準部品と文字は標準tintで表示し、黄色は既存設定アイコンだけに使う。この案は#124に反映した。

### #124の正式525・試行1で週送りの描画間隔と復路の記録照会が停止

- [iOS26.5／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136900050091)、source`de64d20b31af3d606d51316e7df05f6f2efeab89`、試行1。独立先頭の`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（41.120秒）は11月22日01時35分07秒JSTに`ApplicationChecks+WeekAppearance.swift:381`で停止。往路横到着0.293176秒から次の観測0.476071秒まで182.895msで、90msの基準を超えた。到着直後の実枠x16・元高238.333pt。昇格からスクロール復帰まで約0.77ms、同じmain threadのCPU差約170.0ms、`configuration-begin`は0.439659秒・設定0.256ms。記録25枠、幾何欠落0、実PNG1枚、配信57件／1PIDで欠番・処理戻り欠落0。高さ終了は0.692938秒。後続ケースには未到達。SwiftUIの処理内訳は未確定。
- [iOS27.0／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136900050118)、同sourceと試行1。元ケース169.898秒。往路の実PNG、33枠・幾何欠落0、横到着0.250676秒と高さ終了0.484145秒、描画条件を通過した。復路の接触(46,640)開始と(241,640)解放は実アプリに届き、解放から約251msで横到着・昇格、約449msで高さ終了、続いて設定復帰まで記録した。01時30分28秒JSTに`ApplicationChecks+WeekAppearance.swift:283`で2件目の`fixture-week-motion`の値を8秒内に照合できず停止。復路の全実枠と最終ラベルは検証に到達していない。2件目の報告生成・AX配送のどこで止まったかは未確定。配信189件／1PIDで欠番・処理戻り欠落0、後続B未実行。
- `182.333|configuration-begin|0.09|fixture-week-motion|8 seconds|復路`で過去を検索した。26は正式44800663590試行1（82860ce）の横到着直後182.333ms、main CPU約175.8ms、同じ90ms停止と一致する段階。27は旧44688069401の復路にも停止があったが、その回は実描画が遅れた故障で、今回の復路の到着・高さ終了記録後に2件目の照合が取れない停止とは区別する。`08d2b4a`の公開524と`de64d20`で元ケース本体・週描画・記録器・正式ジョブ定義が同じことを確認した。配色の候補自体は同じSHAの限定44919879164の両OSで通過している。残りの今回のジョブを全て終端まで確認し、正式の同一SHA・同じ基準で失敗ジョブとその依存だけを新Runnerで一度再実行する。公開対象のmainは同一SHAを要求するため、この記録は対象の作業ブランチへ先にpushする。
- [同じ試行のiOS26.5／SDK27.2通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136900050163)は02時05分10秒JSTにfailure。他の通常ケース19件は成功。`testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating`（26.498秒）は01時47分42秒JSTに4回目の完了を要求する`ApplicationChecks+WeekAppearance.swift:213`で停止。4接触開始、3解放・3到着。2回目は横到着約92.4ms後かつ高さ調整中に開始し、3・4回目は横移動中。復路の4接触目はx46で実開始ののち、UIKitでx286への`phase=4`（cancelled）を観測し、通常の解放はなかった。同じ時刻の記録では直前の解放のイベント時刻と次の開始時刻が同値。取消の発生理由は未確定。A全体の配信6017件／33PID、欠番・処理戻り欠落0。
- `phase=4|cancel|TAKUPOKE_WEEK_RECORDS|連続操作`で先行169eb22の同一OS試行を比較した。旧試行1は合成4回に対し実2接触、試行2は同SHAで実4接触・4解放・往復と高さまで完走。今回の実4回目の取消は、2接触が未配送だった旧事象と区別する。公開524の同じ連続入力、製品の週送り・測定コードは同一で、両OSが成功済み。今回の試行1は必須11件成功、全ジョブ終端、公開は依存skip。正確な同一SHAのまま週送りの停止を含むA／Bの失敗3ジョブと公開依存のみを再実行する。

### #124 正式525・試行2のiOS27 Bが最初の横到着後98.2msで停止

- [iOS27.0／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136921924605)、同source`de64d20b31af3d606d51316e7df05f6f2efeab89`、試行2。独立先頭の元ケース52.871秒。11月22日02時25分39秒JSTに`ApplicationChecks+WeekAppearance.swift:381`の90ms条件に対し、最初の横到着0.216849秒から次の実枠0.315057秒まで98.2075ms。実枠x16、旧高238.333pt、スクロール復帰まで0.409ms、main CPU増分約97.8ms、最初の設定0.087ms。27枠・幾何欠落0、実PNG556,658バイト、配信77件／1PID、欠番と処理戻り欠落0。往路高さの終了は0.515059秒。色の検証を含む後続Bケースは未到達。
- `98.207|0.09|horizontal-arrival|configuration-begin`で検索。この27の停止は試行1の同OSの復路報告取得失敗から変わり、同試行1の26と旧正式44800663590試行1、旧c4546bf／4d30920の横到着後の停止と同段階。元ケース、週描画、試験fixture、SDK、本番ゲートは同じ。直近の公開524試行1では同じコードの両OSの実描画を含め成功。描画のCPU増分は証拠だが内部経路は未確定。残る同試行の26 A／Bを終端まで確認してから次の対象を決める。
- [同じ試行のiOS26.5／SDK27.2通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136921924419)は03時05分01秒JSTにfailure。前回止まった連続週送りは33.282秒で成功した。失敗は既存`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`（278.566秒）で、反映後と再起動後のC保持・B除外は両方確認済み。02時42分26秒台に`change-editor-row-4`への一回のタップを送出。PID38116で同じ点(196.667,632.667)の開始と約181ms後に`phase=4`取消を記録、通常の解放はなく、10秒内に`4行目`画面が出なかった。停止箇所は`ApplicationChecks.swift:144`。事後階層は時間割変更の詳細に留まっていた。他の通常ケース19件は成功、配信5428件／32PID、欠番・処理戻り欠落0。取消の内部理由は未確定。
- `change-editor-row-4|4行目|phase=4|cancelled`でN90/N92と旧単項目136089875821の接触取消を比較した。過去は消去ボタン、今回は除外一覧が存在して必要な行が可視の後のNavigationLink。`08d2b4a`から既存の行4、変更詳細、UI操作に差分はなく、525試行1では同じ26A・同じsourceで行4を含む元ケースが359.392秒で成功した。取消が同じプラットフォーム域で起きた事実と、今回のナビゲーション状態の変化を分けて扱う。
- [同じ試行のiOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44921744173/job/136921924621)は03時25分43秒JSTに成功。これで同一sourceの通常Bで描画・色・後続の全検査が通った。試行2の必須12件成功、失敗は26 Aと27 Bの2件、公開は依存skipで全ジョブ終端。26 Aの行4は試行1、連続週送りは試行2でそれぞれ実成功し、27の停止点は復路報告不一致から往路の描画遅延に移った。同じSHA・OS・実操作の条件で、失敗した2件と依存の公開だけを再実行する。

### #125 生成アプリの独立色調査でiOS 26のXCTest起動帰還が停止

[調査44989185115・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44989185115/job/137106283638)、source `038e41d06b109e3ae26e056db3e5d4c539d7b4f9`、SDK27.2／iOS26.5。XCTestの元ケース開始後、05:33:43 UTCに一回の起動を要求。アプリPID17824は05:35:32 UTC台にfixture-readyを記録したが、05:36:46に`ApplicationChecks.swift:131`の起動呼出しがtimeout。画面操作・追加の配色比較に未到達。別のiOS27は同じ元ケースと追加の描画比較を406.627秒で成功。`fixture-ready|app.launch|Xcode起動|U58`で索引を調査し、前のiOS26.5限定44987629022（同じランタイム・起動経路で元ケースと画像採取に成功）および正式44700448423の起動返却停止を照合した。画面の仕様とXCTestへの起動返却は別。元の待機期限、一回の起動、実画面撮影を維持する。

### #125 配布候補のタブ名tintが時間割の日付へ伝播

[外観限定44994268172・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/44994268172/attempts/1)、source `1bbf056401fd8b26591d63c421a278ebb9650b1a`、SDK27.2／Runtime26.5（job137121812389）と27.0（137121812321）。両方の標準ライト設定タブは明るい黄色をアイコン枠で検出し、26は2,731画素・文字9.07:1、27は2,737画素・文字9.03:1。先行の橙・緑、設定行の黄色、タブ遷移と週の保持を通った後、時間割の日付ボタンの色を読む `ApplicationChecks+WeekAppearance.swift:29` で有彩色画素0となり停止。ケースは26が130.331秒、27が115.084秒。黄色の時間割タブの詳細検査、既定／青、高コントラスト比較は未到達。MacのNativeは成功。

`tint|黄色|タブ|calendar`で公開525と調査44991031553の実装・画像を照合。前者の日付は元の青。後者は各画面に同じtintを渡した状態で下部タブの文字とアイコンを採取したが、時間割の日付ボタンに色が伝わらないことは個別に検証していなかった。候補の `TabView.tint` が画面の `WeekControlAccent` の既定アクセント解決に影響したことを両OSで観測した。元の `TabView` とページのtintを復元し、明るいアイコンは同じ公開APIを使い、標準の `UITabBar` 自身のtintだけで文字色を設定する。変更後も既存の日付ボタンの検査を維持する。毎回実行している設定アイコンとタブ名の実画素検査も維持。

### #125の正式526・試行1でiOS26 Bの最初の時間割タブ接触をUIKitが取消

[iOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137133998118)、source `d37a2ae47a812aa5364345821be7182c4a8c4c97`、試行1。`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（134.400秒）では実起動と `fixture-ready` を通った。07:59:30 UTCに時間割タブの一意な実アイコン枠(222.833,780.333,29,25)と中心(237.333,792.833)を取得し、対応する互換経路で一回だけ接触を送出。PID43860で UIKit の開始と`phase=4`の取り消し（イベント時刻差約273ms）を記録し、通常の終了はなかった。08:00:20に `ApplicationChecks+Navigation.swift:24` で元の45秒以内に実選択を確認できず停止。週送りの接触、描画、黄色の元ケースと後続Bには未到達。取消の内部理由は未確定。

`Native tab tap did not select|NativeTabActivation|phase=4|タブ停止`で索引を検索し、U63、44486188488試行1、525の連続4接触の取消と照合した。時間割タブが選択されない点は先例にあるが、今回は開始とUIKitの取消の両方を観測できた。`NativeTabActivation`の一度の時間指定接触、テストの早期フレーム計測、配布ワークフローに公開525から差分なし。黄色のタブタイトル変更はこの既定色の実行では適用されない。別の同一source／OSで、一回の実タブ選択から黄色・標準色・高コントラストまで既に通った [限定44996077866](https://github.com/n624-dev/takupoke-ios/actions/runs/44996077866/job/137127298837) と、通常Aの成功を対照とした。全ジョブ終端後、元の一回の実入力と45秒の判定を維持して同じsourceの失敗ジョブだけを再実行する。公開対象のmainは試行前のSHAのまま保持するため、この失敗記録を先に作業ブランチへpushする。

### #125の正式526・試行1でiOS26単項目の消去後に入力欄の照会が停止

[iOS26.5／SDK27.2手動単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137133998211)、source `d37a2ae47a812aa5364345821be7182c4a8c4c97`、試行1。`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`（193.881秒）で08:19:23 UTC台にPID42249の消去ボタン(339,587.667)の実接触と通常終了、続くBinding消去・編集開始・keyboard did-showを記録。空欄確認の `manual-value-cell-1-0:0:subject` の列挙中に08:20:31 UTC `ManualAssistanceChecks+Input.swift:78` の `Failed to resolve query: Timed out while evaluating UI query`。空欄の確認、実入力、後続の背景復帰・採用は未到達。照会が止まった内部理由は確定していない。

`manual-value-cell|Input.swift:78|manual-binding-clear|Timed out while evaluating UI query` でN52と正式43754726270・44741890239を確認した。過去の同単項目の接触取消やタブ画像の照会とは異なり、今回はエディタの実消去後に止まった。公開525から同じ入力ヘルパー・消去・編集・元期限で、525の同じiOS26単項目と526の他の手動7件は成功。元の実入力・期限・配布の必須条件を保持して、全ジョブ終端後に失敗したジョブだけを再実行する。

### #125 正式526・試行2のiOS26 Bで最初の横到着後166.470ms

[iOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137155729918)、source `d37a2ae47a812aa5364345821be7182c4a8c4c97`。2026年11月22日18時12分50秒JSTに `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（35.388秒）が `ApplicationChecks+WeekAppearance.swift:442` で停止。試行1と異なり最初の時間割タブが開き、週送りの実接触・解放・横到着まで成立。解放を基準に横到着0.215203秒、次の実枠0.381673秒で間隔166.470ms、条件は90ms以下。着地位置x16、直後は元の高さ238.333pt、続く実枠に246.333、315、390ptを記録。スクロール復帰まで約1.0ms、伴うmain CPU差は次の枠まで約162.9ms、最初の設定0.093ms。高さ終了0.598610秒、25実枠、幾何欠落0、実PNG716,075バイトを一回で採取。往路の基準で停止したため復路および後続Bの検査は未到達。同じ試行で[iOS26手動訂正](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137155730058)が成功し、必須13件成功、公開は依存で未実行、全ジョブ終端。

`Height adjustment must keep drawing frames|描画間隔|configuration-begin|0.09` で索引を引き、正式525試行1のiOS26 Bの182.895ms、旧正式44800663590試行1の182.333ms、正式525試行2のiOS26 Bの完走を照合した。到着直後の再描画で止まる段階とmain CPUの増加が一致し、SwiftUI内部の処理・ランナー寄与の内訳は確定していない。公開525から週描画・本ケース本体・正式ゲートの差分はなく、既定色fixtureで黄色用の色指定は無効。今回の試行1は同じケースでも実タブ接触の取消で止まっており、同一の失敗の反復ではない。元の90msと描画・画像・操作検査を維持し、同一sourceでiOS26 Bと依存の公開だけを新しいRunnerで再実行する。

### #125 正式526・試行3のiOS26 Bで試験・返却スイッチの接触が取消

[iOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137162434939)、同source `d37a2ae47a812aa5364345821be7182c4a8c4c97`。試行1・2で止まった週送りは47.310秒で成功。往復の高さ中最大間隔83.225／66.222ms、幾何欠落0で、元の90msを満たした。黄色の設定・時間割・再起動・高コントラストは196.846秒で成功。後続で `testNotificationControlsAndAppearance`（106.706秒）が11月22日19時29分57秒JSTに `ApplicationChecks+Notifications.swift:134` で停止。最初の「時間割変更」は実Allow、許可callback、authorization=2、表示と保存ONまで成功。直後の「試験・返却」で一回の50ms接触を要求し、実UIKitで座標(315.667,243.667)の開始と約185.9ms後のphase=4取消を観測。解放・この操作のBinding・認可要求は発生せず、保存と表示は両方OFF、エラー表示なし。失敗時の画面とシステム画像・AXも採取した。続く実通知予約と再起動のケースは119.588秒で成功した。公開は依存で未実行。全ジョブ終端。

`testNotificationControlsAndAppearance|試験・返却|phase=cancelled|Special notification switch` でN212、N230、N239と公開525通常26 B成功（136921924621）を照合した。N212は最初のスイッチで取消、N230は二つ目でも解放と認可callback到達済み、今回は二つ目で実取消。試行1・2の週送り停止とは別で、元の通知ケース・短接触・通知処理・配布ゲートに公開525から差分なし。基礎原因はこの記録だけでは確定しない。既定色で黄色の分岐も不使用。正式候補をそのまま使い、今回不成功だったiOS26 Bとその公開依存を再実行する。

### #125 正式526・試行4は最初の横到着後216.183ms

[iOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/44997934998/job/137181895048)、source `d37a2ae47a812aa5364345821be7182c4a8c4c97`。11月22日20時00分56秒JSTに `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（42.339秒）が `ApplicationChecks+WeekAppearance.swift:442` で停止。実タブ・接触・解放が成立。横到着0.281766秒から次の枠0.497948秒で216.183ms、既存90msを超過。到着と次枠のmain CPU差約211.3ms。スクロール復帰まで約0.70ms、最初の設定0.174ms、着地x16・旧高238.333pt、高さ終了0.685487秒、29実枠、幾何欠落0、実PNG724,014バイトを一回採取。復路・後続ケースは未到達。必須13件成功、公開は依存で未実行、全ジョブ終端。

`0.09|horizontal-arrival|configuration-begin|fixture-week-motion` で試行2の166.470ms、試行3で往復を成功した83.225／66.222ms、旧正式525試行1と44800663590試行1を比較。同じ停止が繰り返され、通常の昇格処理だけでは差を説明できない。試行2・4とも実解放後から横到着付近に座標操作のXCTest側「Wait for … to idle」が並行し、明示的な `fixture-week-motion` の読み取りは高さ完了後だった。座標操作の同期が原因とは未確定。前後の実経路が同じで時計・準備・観測負荷のどこに差が出るかを切り分ける。

### #125 正式527・試行1でiOS26手動原本変更の設定List照会が停止

[iOS26.5／SDK27.2手動原本変更](https://github.com/n624-dev/takupoke-ios/actions/runs/45017628980/job/137194296982)、source `8b335c9524b45f758b13319f7fbd22e13caecf4a`。11月22日20時59分44秒（日本時間）。`testChangedOriginalCannotSubmitOrReplaceLastGood`（159.445秒）でアプリ起動・fixture-ready、設定タブの中心(320.333,793)の実開始と解放、設定のgearshapeの照会まで成功。11:57:53 UTCに `manual-settings-list` の現Listの実identity列挙に進み、約111秒後に `ManualAssistanceChecks+Navigation.swift:42` がXCTestのUI query timeoutで終了した。以後の設定行・初回訂正・原本変更・送信拒否・前回結果保存は未到達。同じrunのiOS27同ケースは成功。

`manual-settings-list|Timed out while evaluating UI query|CollectionView|N213`でN213のList照会中のSimulator消失、正式43754726270および44486188488の手動原本変更の後半入力／送信照会停止、正式526試行1の同じiOS26原本変更の成功（137133998183）と照合した。今回は最初の設定画面で、実入力が始まる前。Simulator消失や配信取消の証拠はなく、AX応答が返らなかった下位理由は未確定。元のケースと画面、固有Listの照会・期限を維持する。残る正式ジョブを終端まで確認した後、失敗したジョブだけを対象にする。

### #126〜128 修正前のLinux回帰対照（2026-11-23）

基点 `203e407`、Linux x86_64／Swift 6.1.2。架空データで以下の再現を確認した。

- #126の `testAcceptedLinkResponseWithUnescapedSlashesSurvivesReload` と `testAcceptedEventResponseWithUnescapedSlashesSurvivesReload` はAPI応答の検証後、保存で `invalidResponse` になった。全666件のうちこの2件。APIのサイズ上限を維持し、保存・再読込用のJSONでスラッシュのエスケープを省く。
- #127の `testChangeCommonClockChecksApplicableDocumentsWithEmptyPeriod` は時限欄だけが08:50〜09:35を返した。時刻が競合または欠落する8条件すべてで再現し、カードと詳細は期待どおり時刻を返さなかった。索引の `commonPeriodTime|cardTime` でN104を照合した。#90の未取得条件と異なり、今回は両資料が適用される。時限欄にもカードの資料照合を使う。
- #128の `testNotModifiedRequiresMatchingValidatorForAllPrivateResources` は、不一致または欠落したETagで3経路とも304を変更なしと判定した。実確認メソッドと架空のURLProtocol応答による6件のassertion失敗。通知・UI・学校への通信は実行していない。

### #150 リンク索引回帰のLinuxコンパイル（2026-11-23）

02:28 JST前後、`a7fb5f4`からの候補、Linux Swift 6.1.2の一時ホスト実行。`LinksTests.swift:145` の期待順を `flatMap/filter/enumerated/compactMap/sorted/map` の一式で計算し、コンパイラの型検査が制限に達した。テストは未到達。以前のN100では検索スコアの後方別名を検査している。今回もその検査を保持し、新規テストの期待順は完全一致・長い別名・前方・部分一致とAPI順を事前に固定する。

### #145 試験の日付セル全体を読む架空ケースの文字順（2026-11-23）

02:46 JST、a16adfdからの候補、Linux Swift 6.1.2。既存の `flexibleExamPage` に位置の離れた曜日を足した回帰が `PDF239Grid.contentRows` の `R357 / textOrder` で停止した。元の文字にはsourceLine／sourceOrderがあり、追加文字だけ未設定だった。全79件中、当該1件だけが想定外に失敗。R357の契約を確認し、追加文字を独立した原文行として位置・順序付きで作る。製品の文字順拒否と、離れた取消注記を拒否する期待値は維持する。

### #134 iOS 27の破損カウントダウン検査が通知取消の処理中で停止（2026-11-23）

候補 `ce31556`、[45050646373試行1／137294784924](https://github.com/n624-dev/takupoke-ios/actions/runs/45050646373/job/137294784924)、Xcode 27.2／iOS 27.0、`testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration` 48.116秒。build・起動・設定画面・破損の警告・新規登録無効と再読込みが成立。35.90秒で確認ダイアログ内の「通知を取り消す」を実タップした。36.74秒から完了文を10秒待ったが、AXには操作行が無効のまま残った。元ファイルの初期化、登録、再起動は未到達。通知サービスの呼出しとcallbackの到達を直接示すログはまだない。`await worker?.value` と保留通知の読込みのどちらかで処理が続いていた可能性を切り分ける。iOS 26の実行は進行中。

同じ試行の[iOS 26.5／137294784604](https://github.com/n624-dev/takupoke-ios/actions/runs/45050646373/job/137294784604)は90.804秒、Notifications.swift:34。通知取消の完了文と再読込み後の破損警告は現れた。75.04秒で「元のファイルを保全して初期化」に実タップし、77.65秒から確認ダイアログのキャンセルを10秒待った。最終AXには元の設定リストと有効な初期化の行があり、確認シートは見えなかった。両OSの失敗段階は異なり、26では通知の応答待ちを通過した。

`getPendingNotificationRequests|通知.*応答|確認ダイアログ|Relaunch` で既存の通知境界と#121・#124の記録を確認した。既存ケースは許可読込や許可ダイアログの待機で、今回の取消後のOS保留一覧読込とは異なる。保留一覧の実callbackを保持し6秒で終了できるようにして、開始・正常応答・期限切れの段階を記録する。無応答時は取消成功を表示せず、初期化自体は完了できる。初期化は固定文言の標準アラート、通知取消は独立の確認ダイアログとし、利用者が両方を区別できるようにする。確認とキャンセルの実操作を維持し、追加・保存は既存のツールバー専用検査で識別子から取得する。下位のOS原因は未確定。

同候補のLinux Swift 6.1.2で通知の実メソッド抽出テストが3ケース型検査で停止した。`notificationSettings`の終端を次の通常メソッドで切っていたため、追加した静的な保留照会も旧stubへ入った。既存の実メソッド抽出ヘルパーで各メソッドの本体だけを取得し、元の許可・保存・取消結果を示す期待値は維持する。

### #145 解析器の版更新と旧回帰の固定値（2026-11-23）

- `369012d` 基点のLinux Swift 6.1.2全体検査は688件中5失敗（110.060秒、実機・Xcodeなし）。`RecoveryTests` の `SpecialScopeVersion`、`RowOrderAndWholeClockVersion`、`UnusedFontReaderVersion`、`ParallelAlignmentVersion`、`OCRCoverageVersion` の各ケースで、試験・返却解析器の版37を旧固定値36と比較する箇所だけが失敗した。同一原本の再解析・成功後の停止条件自体に失敗は出ていない。
- 79件の限定検査には `RecoveryTests` を含めなかった。日付の版更新が過去の再解析テストでも参照されるため、版を上げる候補は過去の固定値参照を先に横断検索し、Apple実行前にLinux全体を通す。

### #147 旧採用証明を作る対照のOCR行番号（2026-11-23）

- `369012d` の直前のBuilderとラスター判定を使う架空対照をLinux Swift 6.1.2で実行した。1件が `invalidInventory` で停止した。閉図形を誤って空欄とするBuilderまでは進み、旧確認結果を生成する手前のOCR取得記録で止まった。
- 取得記録の行番号は0から連続する必要がある。架空の画像に合わせて3行分の認識結果を除いた後、番号を詰めていないことを確認した。既存の取得証明の検査は維持し、架空入力だけを実取得と同じ連続番号に直す。

### #147 行高に近い閉図形の追加対照（2026-11-23）

- `e3a3cdf` 基点、Linux Swift 6.1.2。空欄・区切り・閉図形・開いた図形を比較する1ケースは新しい検査5箇所で失敗。閉図形と開いた図形に加え、ほぼ1行高の矩形も曖昧として拒否されたが、空欄の墨検査の拒否には工程番号が付いていなかった。追加の高さ対照では抽出された縦線の端点も架空値と一致しなかった。今回の実行だけでは、行高近くの図形が全解析で成功するとは言えない。
- 見直し時に、現行マスクでは前後2画素の差を含む候補が自分の縦辺を時限境界にでき、本文境界を横切る候補も無条件に通る箇所を確認した。空欄拒否に `rasterInput` を付け、全解析の試験とマスクの直接対照を分けて、拒否された場所と除外された線を識別する。

#147 のマスク単体対照はLinuxの型検査で一度停止した。`PDFRule` に `Equatable` がないため、合否を比較する前に `[PDFRule]` の比較でコンパイル拒否された。比較すべき座標4値を明示的に取り出す。ラスターから得る縦線は、元の濃い画素が194〜294でも抽出時に192〜296へ延びていた。端点の座標条件だけでは実際に交差したか判定できない。

座標比較へ直したマスク単体対照は、本文の上下端に近い閉図形4辺と、本文外からまたぐ線2本をすべて残した。表の境界・正当な区切りの6本だけを残す期待に1件失敗した。抽出座標と実画素を区別し、独立に確認した行の両端へ、罫線の太さも考慮して接続する縦線を証明する。

冊子の罫線に相当する実画素を使った候補はLinux Swift 6.1.2の212件中1失敗。閉図形と本文横切りの6候補のうち5本は除外できたが、`x70` の縦辺が隣の実罫線 `x72` の黒い列を借り、一方だけ残った。補正した中心の整数列に限定して接触を確認する。元の空欄・校時・返却・復旧の対照はこの候補でも成功した。

次の限定対照も修正前に再現した。1画素だけ表の外へ伸びた正当な区切りと、表の端で止まるクラス欄の区切りが除外された一方、隣の行にしかない時限境界を端点にした本文内の線が残った。同じ高さに達している時限境界だけを使い、表に入らない線と端の丸め誤差を区別する。

### #152 通知先シートが開かなかった対照（2026-11-23）

- `3d13e72`（製品 `d7f11ef`）、[45052922079・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45052922079/job/137301792542)、iOS 27.0・SDK 27.2、`testCountdownNotificationRouteOpensCurrentDetailAndMissingTargetList` の実ケース1件・失敗1（135.716秒）。設定で架空の個人予定を確認してホームへ戻り、有効な通知先を渡すテストボタンの実tapを39.39秒に送出した。10秒の待機で「予定の詳細」は見つからず17行で停止。後続の対象なし、閉じる操作は未到達。失敗時のAXはアプリの照会先名までで要素がなく、通常のクラッシュ記録は取得できなかった。OSからの配信や通知バナーのタップは未実行。
- `sheet|EnvironmentObject|カウントダウン|予定の詳細` で通常の詳細遷移、N117の閉鎖、#120の予定詳細と通知許可の記録を照合した。今回は既存の一覧のNavigationLinkを通らず、外側のシートが同じモデルを必要とする経路。通知シートに実モデルを明示して渡し、操作を受け取った場所と、詳細が見えない場合のアプリ状態を記録する。実予定・期限・対象なしの期待値は維持する。停止の下位原因は未確定。

## #156 変更ファイルの再試行を中止すると保留が外れる（2026-11-23）

Linux Swift 6.1.2、`0fe7d66` の `MaterialLibrary` と追加した対照 `testClassExamHoldsAfterFailedFirstChangeAcquisitionAcrossReopen`。SQLiteに初回取得失敗を記録して開き直し、次の取得の中止を記録して再度開いた。既存候補は取得失敗を中止で上書きし、変更資料なしのまま試験通知の保留を解除した。1件中2 assertion失敗、0.141秒。実端末や配信の失敗を示すものではない。

初回に一度も取り込めていない場合だけ、再試行の中止で未解決の取得エラーを消さない。初めて試した操作の中止・未試行・成功後の解析待ちは、それぞれ保存を開き直して比較する。移行用の旧メッセージと新しい中止情報の優先順位もテストする。

追加した取得成功の正対照を含む初回候補のLinux限定47件は失敗1。失敗は `invalidState` で、成功後の再openの前に同じLibraryを保持していた。`LocalMaterialDatabase.openLibrary` の排他的 `LibraryLock` と既存の `testFreshSQLiteCutoverIgnoresLegacyAndReopensWithoutReset` を照合し、前の所有者をスコープで解放してから再openする。製品の排他、保留条件、成功後の期待値は変更しない。

## #157 半期切替時の通知サービス読み取りに応答が無い（2026-11-23）

作業ブランチ `953f454`、Linux Swift 6.1.2で製品の `CountdownModel.expirePrivateNotices` と `ScheduleNotifications.notificationSettings` を抽出して実行した。通知サービスを模した応答だけを順に保留した。許可状態で待つ照合ワーカー、予約一覧、配信済み一覧の各段階で、期限処理の後続が停止した。呼出し元をキャンセルしても、遅らせた応答を実際に返すまで次へ進まなかった。最後に正常応答した場合は選択クラスの架空の通知だけが取り消され、個人予定と他機能の通知は残った。

`getPendingNotificationRequests|通知.*応答|callback` で#134の破損設定対応、#155の設定と許可要求の比較、旧#121・#124の実通知記録を照合した。今回は期限切れデータの処理前に受動読取を待ち続ける経路。破損復旧の有限待機と同じ考え方を期限処理と通常照合にも適用し、実一覧を受信できなければ未確認のまま再試行できる状態へ戻す。学校データの期限管理と対象通知の識別を維持し、実応答を期限やキャンセルで代用しない。

初回のLinux lifecycle候補で既存4件は成功、新規の半期処理対照だけはSwiftの型検査で失敗した。共通スタブに同期・非同期の同名 `resetForRetention()` を両方入れ、実コードの同期呼出しもasyncに解決された。実装では `ScheduleNotifications` のみ非同期で、リンク・名称・授業時刻は同期。スタブを実際の型境界へ分けて再実行し、同じ処理・期待値を検査する。

## #158 許可状態の抽出テストで新しい補助関数が重複（2026-11-23）

Linux Swift 6.1.2の初回7件では既存5件が成功し、通知ゲート・比較保存の2件は型検査で `readCurrentNotificationSettings()` の重複宣言になった。#134の静的補助追加時と同様、チェック関数の終端を次のコメントで切っており、新しい補助関数が別抽出にも含まれた。両方を既存の `block` で関数単位に抽出し、期待値や準備期限はそのままにする。元の順序不具合は製品関数の独立比較で再現済み。

## #162 期限処理で通知追加の完了を待ち続ける（2026-11-23）

`cbf4db3` のLinux Swift 6.1.2対照で、通知追加の完了を保留した後に製品の `expirePrivateNotices` と `suspendForUnavailableData` を実行した。キャンセル後7秒でも戻らず、予約一覧の読取は0回。追加完了を返した後は両方の処理が終了した。制御した通知サービスでの再現で、iOS 27の実予約が2003として返った事例とは区別する。

終了通知を追跡し、停止が確認できるまで次のワーカーを開始しない。待機を打ち切っても保存期間を進めず、両方の通知処理が停止した後に所有範囲の取消を再試行する。初回のLinux検査は9件中8件成功、追加した書込対照も成功した。既存の受動読取対照は、`Task` から変更したテスト側のescapingクロージャに `self` がなく、コンパイル停止。製品のワーカーには元から明示的な参照がある。既存のfixture側も所有者を明示し、読取りの確認条件を維持する。
## #157 iOS 27の管理マーカー明示復旧で通知照会を確認できない（2026-11-23）

`4bcf6d8` の[45059993597／試行1 iOS 27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/45059993597/job/137323553192)、SDK27.2、既存 `testRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData`、72.567秒。起動・取消し・二度目の復旧確認操作へ到達し、復旧のダイアログが閉じた。削除完了アラートを要求する `ApplicationChecks+Settings.swift:192` で失敗。末尾実画面は「期限切れの通知を確認できませんでした。…再試行してください。」と復旧ボタンを表示し、マーカーと旧データをそのまま保持した。`marker=0;old=1;prefs=1;public=1;original=1`、閉鎖カウント2。OSの予約一覧か配信済み一覧のどちらが返らなかったかはこの実行で分離できていない。App起動やN81/N82の取消し未到達とは別の段階。iOS 26.5の別jobは進行中。

### #157 iOS 27の通知サービスは6秒を越え、約1分後に実応答（2026-11-23）

`17f597d` の[45061660859／試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45061660859/job/137328714807)、SDK27.2／iOS27.0。元の復旧caseは97.448秒、削除完了の30秒で失敗し、元マーカーと旧資料は保持された。識別子付きログでは初回pendingが70.86秒、明示確認後のpendingが57.15秒、deliveredが51.14秒で実callbackを返した。アプリは応答自体が無いと判定せず、6秒で再試行を案内し、期限後の応答を成功に取り込まなかった。通知サービスがまとめて応答した下位理由は未確認。

#134の6秒は製品の一時停止中の退出条件。N81/N82は実取消しの条件で、本件の遅い実照会とは異なる。通常に応答する場合のiOS 27の削除完了も検査するため、キャンセルと元バイトの保持を確認した後、同じ所有アプリから実pendingとdeliveredの両方が一度返ることを確認してから、元の二度目の確定操作へ進む。固定sleepや許可設定の注入を使わず、応答しない場合は準備失敗。製品・既存の確定後30秒・実削除／元ファイル維持・再起動を維持し、上記の未確認とデータ保持のiOS 27観測を別に記録する。
## #155 許可要求の比較がiOS 27の起動前に停止（2026-11-23）

候補 `8b5ee44`、[45057062757試行1／137314524539](https://github.com/n624-dev/takupoke-ios/actions/runs/45057062757/job/137314524539)、Xcode 27.2／iOS 27.0。ビルド成功後、18:58:39 UTCに最初の `app.launch()` を一度要求。18:59:07 UTCに `FBSOpenApplicationServiceErrorDomain Code 5 / InvalidResponse`、SpringBoardの応答のXPC error、`Failed to get launch progress` を返した。ケース159.523秒。アプリのfixture-ready・通知設定の操作・許可要求・回答・予約一覧に未到達。起動APIはSpringBoardがクラッシュした可能性を返したが、下位原因や製品プロセスのクラッシュは未確認。前回 `f903a02` の通知設定コールバック待ちとは到達段階が異なる。

`SpringBoard|Failed to get launch progress|InvalidResponse` でU76、U49、N125と当時および現行の `launchReady`／ランナーを照合した。U76も実操作前に止まり、条件を保持した新しいRunnerでは同ケースが成功した。U49は操作後の再起動、N125は準備後の別の起動期限だった。現行の事前確認、一回の起動、実Allow、予約4件の日時と識別子、既存期限を保持し、iOS 27だけ新Runnerの同条件で比較する。今回iOS 26.5は実Allowと予約4件の比較に成功したため、再実行対象に含めない。

## #129・#155 許可後に学校全体の実予約4件を照合できない（2026-11-23）

候補 `7e97912`、[45058953653試行1／137320333439](https://github.com/n624-dev/takupoke-ios/actions/runs/45058953653/job/137320333439)、Xcode 27.2／iOS 27.0、`testSchoolCountdownReservesBothLaterPeriodsWhileCurrentPeriodIsDisplayed` 105.943秒。アプリの実起動と設定保存に到達。19:17:36Zに通知許可を呼び、19:18:17Zに実 `Tap "Allow"`・許可callback・`notification-auth-granted` を確認した。続いて実設定と予約・配信済み照会の応答、`center.add` の4回の呼出し開始と返却、実予約の読み直しの返却まで記録された。現在の一枚Aの表示に成功した。その後の検査専用ボタンの照会結果は該当する接頭辞で0件、元の15秒で架空の後続2期間／通知4件と時刻の照合に失敗した。直前の許可操作とアプリ起動の失敗とは別の段階。旧計測は `try?` の後に返却を記録するため、4回ともOSが受理したか、拒否したかはまだ区別できない。テスト側の接頭辞以外に予約が存在したかも出力していない。アプリが表示した「これからの通知日時はありません。」は現在のカードAの表示で、別対象B/Cの予約を証明しない。

`UNNotificationRequest|nextTriggerDate|実予約0件` で旧#121の許可前0件と、同fixture・同SDKのiOS 26.5の実Allow後4件、現在の `CountdownModel.reconcile` と `SimulatorCountdownEventsFixture` を比較した。今回は許可が確定し、現在カードの警告は対象外。保持した元ケースで、生成アプリだけの観測を追加する。予約を呼ぶ前の `nextTriggerDate()` の有無と日時の一致、実 `add` の受理／エラー種別と番号、削除対象の件数、モデルとテスト画面の実pendingの全体数／期待一致件数を記録する。Appleも `add` の完了値で受理と問題を区別し、保留一覧は別APIで返す。接触方法・許可・現在カード・4件のIDと日時・15秒・製品ロジックを維持する。[Appleの予約API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add(_:withcompletionhandler:)) · [Appleの次回通知日時](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger/nexttriggerdate())

## #129 iOS 27で正しいトリガーの予約がOSの2003エラーになる（2026-11-23）

`8ccb231` の[45060928537試行1／137326458047](https://github.com/n624-dev/takupoke-ios/actions/runs/45060928537/job/137326458047)、Xcode 27.2／iOS 27.0、元ケース208.857秒。実起動・設定・Allow・許可callbackが成立。19:36:45Z台、最初の実予約までに設定／予定一覧／配信済み一覧から応答を得た。4件とも `nextTriggerDate()` が指定の日本時間と一致し、実 `add` が `UNErrorDomain` 2003を返した。削除要求は対象0件、直後の保留一覧が全体0／期待対象0、利用者の操作で再照合した時も全体0。XCTestは元の予約4件の条件を満たさず失敗。数値2003の下位原因はAppleの公開 `UNError.Code` 文書から断定できない。学校全体の対象選択や曜日の入力失敗ではない。

`countdown-notice-reserve|UNErrorDomain|2003|通知の許可` で前回45058953653と両iOSの許可経路、iOS26の同内容4件、旧#121の受動照会待ちを比較した。今回は許可応答後にOSの実登録がエラーを返している。実際に許可済みで、正常な未来のトリガーを送った後の追加失敗だけを、同じ予約計画が有効な間に有限回再照合する。現在の実予約を読み直し、成功した枠は再追加しない。OSが拒否した結果を成功扱いせず、実ケース・元15秒・時刻・ID・実Allowの条件を維持する。[Appleの予約応答](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add(_:withcompletionhandler:)) · [Appleの公開エラー一覧](https://developer.apple.com/documentation/usernotifications/unerror/code)
## #129・#161 iOS 27でスイッチの実接触後にONへ変わらない（2026-11-23）

`06b4551` の[45063287797試行1／137333770101](https://github.com/n624-dev/takupoke-ios/actions/runs/45063287797/job/137333770101)、Xcode 27.2／iOS 27.0、元の学校全体の実予約ケース61.410秒。アプリ起動、設定、試験の自動表示編集、スイッチOFFを確認。20:02:24Zに観測済みのネイティブつまみで一回の水平操作を開始した。実UIKitで315.67→347.33ptの開始・移動・終了が届いたが、スイッチは元の15秒以内にONにならず、既存の行19で失敗した。許可要求、保存、予約追加と再試行は未到達。初期の実保留照会も失敗時までにコールバックが記録されなかった。接触の送達と通知サービスの応答を区別し、今回のログから両者の因果は決めない。2003エラーを比較した過去の失敗と段階が異なる。

`thumb-drag|tapNativeSwitch|この行を除外` でN239と、同じく水平操作が終了まで届いても切り替わらなかった76042ccの実スイッチ、旧と現行の操作を照合した。0.33秒を指定する既存の実接触ヘルパーを学校のケースだけに使用する。表示中のネイティブ部品の実枠・一意性・有効状態を維持し、一回の接触を送る。状態0→1、元の15秒、OSの許可と後続2期間の実予約4件の条件は維持する。接触後にカウントダウンの編集値が変わった段階を固定ログに加える。

統合後のLinux manifestは `test_all_source_tests_are_assigned_once_and_both_os_checks_are_required` で不一致。旧試験通知worktreeには後から作った#152の通知先ケースがなく、統合後は旧41件に学校全体の1件が加わって42件になる。どちらのケースも残し、完全一覧の期待件数と一次元の宣言確認をそろえる。

### #157・#162 統合前レビューで個人予定の予約を消す経路を検出

`4b4c6ae` の差分レビューで、学校データの期限処理が照合ワーカーをキャンセルすると、処理中の個人・公開行事の実追加が後から完了した時、通常のキャンセル処理がその識別子まで取り消すことを確認した。初回のLinux期限テストが追加完了を止めた対象は学校由来のみで、この組合せは未検査だった。旧 `70fb091` は予約の世代を更新し、処理中の追加の完了をキャンセルせず待っていた。私的な期限処理ではこの区別を保って有限に完了を待つ。既存の通常キャンセルと、旧計画の次の通知を追加しない条件は維持する。

## #159・#160 再起動後のお気に入り操作からSafari本文が現れない（2026-11-23）

`70fb091` の[45063781514試行1／137335320142](https://github.com/n624-dev/takupoke-ios/actions/runs/45063781514/job/137335320142)、iOS26.5／SDK27.2の `testLinkPreferencesSurviveRelaunch`（134.246秒）。実解除・再起動・追加と、追加後のお気に入り行を確認した。元のprimary tap受信後に `browser-controller-created` が到達。接触記録の後、loopback GETを読み終え、0.0007秒でHTTP200／205bytesを送信した。元の30秒で実本文が見つからず、`ApplicationChecks+Settings.swift:527` で失敗。末尾AXは「一覧」とお気に入り済み行。SafariのCloseと本文、実初回読込callbackは未観測で、閉じる操作と復帰の検査は未到達。同runのiOS27.0は183.495秒で実本文・実Close・一覧復帰まで成功。接続、Safariの表示・読込、リストの保存を区別する。

`testLinkPreferencesSurviveRelaunch|browser-controller-created|IsPageLoaded` でN161/N236/N242と44499001313の旧iOS26.5を照合。旧の主な比較は実Closeが表示されながらWebViewが未読込だった。今回は同じloopback fixtureで入力とHTTP送信が成立し、失敗末尾にSafari画面自体が見えなかった。実初回読込探索、入力、旧30秒を保ったまま、次の比較には生成アプリで表示側の観測だけを追加する。

Safariの準備APIと実画面をそのまま使い、使い捨ての生成アプリにだけフルスクリーン表示の出現・消失と、既存コントローラの `viewIfLoaded.window` への接続を記録する。画面を新規に読み込ませず、弱参照で取得できる既存値だけを見る。URL・画面内容は記録しない。iOS26.5／SDK27.2の同じリンクケースを比較し、元の一回の接触・30秒の本文・10秒のClose・一覧復帰、お気に入りの再起動後の期待値は維持する。生成Swiftの構文とLinuxのmanifest40件が成功。

## #157・#162 通知ワーカー取消しのactor境界でAppleビルドが停止（2026-11-23）

`86d95eb`、Xcode27.2、[学校全体通知の45065428110／137340384748](https://github.com/n624-dev/takupoke-ios/actions/runs/45065428110/job/137340384748)、[期限処理iOS27.0の45065611705／137340962361](https://github.com/n624-dev/takupoke-ios/actions/runs/45065611705/job/137340962361)、[同iOS26.5／137340962573](https://github.com/n624-dev/takupoke-ios/actions/runs/45065611705/job/137340962573) の試行1が同じ箇所で失敗した。いずれも生成した `ScheduleNotifications.swift:289:81` のキャンセルハンドラからMainActorに隔離した `NotificationWork.cancel()` を同期呼出しして `ActorIsolatedCall`。アプリの起動、操作、通知サービスは未到達。旧iOS27のスイッチ未切替や2003拒否とは異なる。

同じ製品の `drainPending` とワーカーの型を抽出してLinux Swift 6.1.2のSwift 5・6両モードで同じエラーを再現した。元のLinux検査は `CountdownModel` のキャンセルと期限処理を別に実行し、更新通知側のハンドラまで一緒に型検査していなかった。取消しはSendableな `Task` の取消しだけを行うため、その入口だけMainActorから分離する。通知状態、書き込み、完了の待機と後処理は引き続きMainActorに置き、両側で同じ元の処理を使う対照を追加する。通知許可・実予約・期限切替の期待値、端末・SDKは維持する。

### #164 背景の通知処理がキャンセル後も復帰を止める

Linux Swift 6.1.2で、actor境界だけを直した直後の製品の `activate`、`refreshInBackground`、カウントダウンと時間割通知の待機を同時に実行した。制御したOS追加完了を保留すると、親と両ワーカーにキャンセルを伝えても復帰側の `prepare` はまだ未到達。片方を返しても止まり、両方を返して初めて進んだ。#162が対処する期限切替の手前の待機で、物理iPhoneでの追加無応答は未観測。通知を追加中のワーカーは保持しながら、キャンセル済みの呼出し側だけ完了の待機を解く。通常の背景更新は完了まで待つ。

#164の最初のLinux統合対照では、テスト側がSwiftの暗黙Returnを使う取消し待機クロージャへ計測行を挿入したため、戻り値がVoidと解釈されて型検査が止まった。計測は呼出しの直前に置き、製品のクロージャ本文、Boolの意味と元のテスト条件を保つ。

## #165 通知設定をオフにした時の取消しが追加応答を待ち続ける（2026-11-23）

`d63ecf4` の実 `setEnabled` とワーカー型をLinux Swift 6.1.2で実行。通知追加の応答だけを保留し、時間割変更をオフにした。保存への反映とキャンセルは成立したが、予約と配信済みの旧識別子はどちらも残り続けた。追加完了を返した時だけ、対象の予約と履歴を取り消した。OSを制御した対照で、#157の一覧読取や#164のアプリ復帰とは別。既存の所有識別子をすぐ取り消し、追加完了後は現在もオフの場合に同じ種類だけを再確認する。

## #129・#155 iOS 27でスイッチON後のOS許可が未応答（2026-11-23）

`d63ecf4` の[45066765115試行1／137344570970](https://github.com/n624-dev/takupoke-ios/actions/runs/45066765115/job/137344570970)、Xcode27.2／iOS27.0。20:33:01Zにビルド成功。一回0.33秒の実接触を行い20:39:00Zに `countdown-notice-draft-on`、20:39:04Zに実許可を要求して同期戻りも記録した。実Allowと許可結果のコールバックは45秒以内に観測されず、`ApplicationChecks+Notifications.swift:74`、ケース88.053秒で失敗。新規予約と再試行は未到達。初期の実pendingは待機期限内に返らず、実行終盤のサービス観測ではSpringBoard・runningboardd・lsd・usernotificationsdは動作中。旧06b4551のスイッチ未切替、86d95ebのビルド失敗、以前実許可後に2003で拒否された段階とは別。

`notification-auth-returned|callbackなし|headless27` でU39/N231と、実Allowが到達した旧45058953653を照合した。下位原因は未確定。同じ学校ケースを同条件で繰り返さず、実保留一覧を先に照会する既存の個人予定のケースを、同じRuntime／SDKの実通知センター対照として選ぶ。許可や一覧の結果を注入せず、一回の操作、元の期限、実日時・予約と既存対照を維持する。

### #157・#162 統合後のiOS27は通知センターの準備段階で停止

`d63ecf4` の[45067307478試行1／137346226400](https://github.com/n624-dev/takupoke-ios/actions/runs/45067307478/job/137346226400)、iOS27.0／Xcode27.2。ビルド・起動と復旧の取消しまで成功。取消し後に元マーカーと旧資料、個人設定・公開データ・元ファイルの保持を確認した。同一プロセスの保留・配信済み一覧の準備条件が元の90秒で成立せず、`ApplicationChecks+Settings.swift:191`、120.792秒で失敗した。二度目の復旧確定を行わず、末尾も古いデータとマーカーを保持。86d95ebの型エラー、4bcf6d8の確定後の停止、ead8fd2で実応答した同じ成功対照とは観測段階が異なる。iOS26の別ジョブは進行中。通知サービス内部で両処理のどちらが停止したかは準備段階について未確定。

### #167 iOS26で削除完了のあとにテスト用の準備表示だけが更新されない

同じ `d63ecf4` の[45067307478試行1／137346226105](https://github.com/n624-dev/takupoke-ios/actions/runs/45067307478/job/137346226105)、iOS26.5／Xcode27.2。実保留・配信済み一覧の応答と取消し時の元バイトを確認した。20:49:37Zに生成アプリの `fixture-ready-timeout` が出てから、20:49:58Zに二度目の確認、20:50:01Z台に両実一覧の応答と削除完了アラート、20:50:05Z台に「あとで」が成立。末尾の画面はホームタブを選択済みだったが、採取済みの保存情報の表示が取消し前の値のまま、準備表示を待つ `ApplicationChecks+Settings.swift:203`、163.084秒で失敗した。確定後の再起動・バイト比較は未到達。末尾の古い表示からディスク内容は判定できない。

`fixture-ready-timeout|testRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData|保存データを削除しました` で `4bcf6d8`・`ead8fd2` と今回のコードを比較し、三候補とも起動画面から300回×100msの監視を一度だけ実行することを確認した。復旧用の起動だけ、製品の保存期間準備の通知を受けてから既存の読み込み監視を始める。通知サービスの実応答・取消し・復旧後のファイル照合・元のテスト期限を維持する。[#167](https://github.com/n624-dev/takupoke-ios/issues/167)

### iOS27で個人予定の初回の実予約一覧が返らない

`44d8932` の[45068137098試行1／137348820903](https://github.com/n624-dev/takupoke-ios/actions/runs/45068137098/job/137348820903)、iOS27.0／Xcode27.2。個人予定の既存 `testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch` を単独実行。起動と編集一覧が成立し、20:52:49Z台に「予約を照合」を一回操作。実 `getPendingNotificationRequests` を待つ「保留予約を取得中」のまま、最初の保留0件の条件が元の15秒で成立しなかった（`ApplicationChecks+Notifications.swift:512`、53.160秒）。個人予定の許可・保存・追加は未到達。学校全体の追加や対象選択を行う前にも実通知センターの別APIで停滞した。iOS27で前の実Allowが出たケース、実予約4件を拒否したケース、準備段階で止まった復旧の両一覧と到達段階が異なる。通知サービスの下位原因は未確定で、同条件の再実行は保留する。

### #168・#169 更新通知が別の種類の追加まで止める

`b927d41` の通知モデル全体と実際の比較状態保存をLinux Swift 6.1.2で動かした。架空の試験・返却PDFの両更新を確認したとき、先の試験の追加だけをOS境界で拒否すると呼出しは試験1件で、試験・返却が送信待ちに残った。別条件では試験の追加応答を保留して時間割変更だけをオフにし、試験の書込を返してからも返却のOS追加に進まなかった。OS応答だけを制御し、実資料・Appleの通知設定は使っていない。#161はカウントダウン予約の追加と再試行で、今回は更新通知の種類間の処理で発生した。

`testChangedDataProducesOneLocalNotification|実配信|requestAuthorization` で限定43767607953の許可応答停止、正式44259503653の26 Aの実セル取消し、先の#155で実許可応答を確認した経路を照合した。今回の回帰は許可済みで比較状態を保存してからの処理。オンの種類を処理し続け、拒否された種類だけを既存の送信待ちへ残す。既存のiOS試験では実許可操作、実ファイル更新、通知センターの新しい実通知と同一更新の重複防止を維持する。

### #170 Linuxの開発ツールジョブが全Python検査の途中で中断

`edeb3ae` の[45069283561試行1／137352393571](https://github.com/n624-dev/takupoke-ios/actions/runs/45069283561/job/137352393571)、Ubuntu 24.04。Python全検査開始は20:57:04Z。架空のiOS26ランタイム検査 `test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failures` は直前ケース終了から126秒後の21:02:05Zに成功。21:02:10Zに実行が取り消され、Python集計・後続の文法と空白検査は未到達。ジョブに5分の上限が設定されていた。Ubuntu Swiftは694件、macOSの両Xcodeは各808件・既定skip1・失敗0で成功した。

`test_ios26_export_lives_until|5分|TimeoutExpired` でL20261113-runtime-mockおよび0bbb0249のLinux全検査を比較した。今回の停止は個別の模擬条件が期限に達した過去例と異なり、対象テストが成功した後のジョブ全体の上限。0bbb0249の全検査は355.989秒だった。開発・配布のUbuntuジョブが同じ全検査を実行するため外側の予算を両方10分にする。模擬の個別期限、検査項目と期待値、Appleの実UI・公開の合格条件は維持する。[#170](https://github.com/n624-dev/takupoke-ios/issues/170)

### #173 特別時間割の時刻が秒・小数の途中で採用された

`1cb5612` の特別PDF両完全パーサーをLinux Swift 6.1.2で架空6ページに対して実行。単独2限の `9:50~10:35:30` と `９：５０〜１０：３５．５` を両方とも `09:50〜10:35` として採用し、明示連続の `8:50~10:20:30` でも採用が成立した。元になったPDFの画素や実機は検証対象外。前に直した3桁の分や前置数字は期待どおり拒否された。

`periodHeading|b424|b425|数値境界`でN128・N129と `c23433c`／`cc8fca5` のコードを照合した。既存の隣接グループとUnicode十進数字の扱いを維持し、時計の末尾に続く数値の前にコロンや小数点がある場合も、時刻全体の境界エラーとする。保存済み資料は解析版の既存の再確認で判定し、拒否時に以前の正常データを置き換えない。[#173](https://github.com/n624-dev/takupoke-ios/issues/173)

通常・復旧用の完全パーサーに対策を入れた後で、復旧資料を直接組み立てる別入口を実行した。旧Builderは秒部分を表の外の注記として保持し、同じ架空資料の `09:50〜10:35` が実EngineとValidatorを通った。復旧資料を組み立てる時点で、復旧用パーサーと同じ時刻境界を確認する。

### 正式528・試行1でiOS26通常Bの週送りが到着後199.689ms停止

[iOS26.5／SDK27.2通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/45112946241/job/137490689520)、source `d1c3bf71ab88c9e9180cdba2a7949474ad0ed53b`。2026年11月23日04:57:09 UTC、`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable`（36.799秒）で失敗した。実接触・解放・横到着は成立し、最初の高さ調整中の枠間隔199.689msが90msの基準を超えた。枠間のmain CPUは約182.9ms、到着からスクロール復帰までは約0.70ms、次の設定開始は到着から約161.6ms後。21枠、幾何欠落0。正式527で採用した接触を使用し、計測中の `Wait for … to idle` は今回のログに現れていない。復路と後続ケースは未到達。main threadのCPU時間は観測できたが、その時間を使った呼出しは未確定。

`horizontal-arrival|configuration-begin|0.09|NativeTestContacts` で正式526試行2・4と正式527前の限定を比較した。[限定45016115439のiOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45016115439/job/137188674490)の実ログでは各34枠、最大49.734／49.130ms、到着から設定開始まで約23.5／29.3msで往復成功。正式527から正式528へ週送り本体・計測・テスト操作に差分はなく、今回の週送りケースは従来の通常時間割・行事週の入力を使用する。正式527で除いたXCTestのアイドル照会がなくても再発することを確認した。ホストの混雑やSwiftUI内部の処理の内訳は確定していない。

### 正式528・試行1のiOS26手動原本変更はXCTest前にXcodeが実行先を見失った

[iOS26.5／SDK27.2手動原本変更](https://github.com/n624-dev/takupoke-ios/actions/runs/45112946241/job/137490689549)、source `d1c3bf71ab88c9e9180cdba2a7949474ad0ed53b`。ビルド・所有Simulatorの起動確認・GUI準備を完了した。05:15:55 UTCに同じUDIDで `test-without-building` を起動し、05:16:59 UTCにXcodeが対照デバイスなしでexit 70。ケース本体は開始せず、タッチの観測は0件。後処理と所有Simulatorの削除処理は終わった。Simulatorがテスト実行先から外れた理由は未確定。

`Unable to find a device matching|destination specifier|bootstatus|exit 70` でN127・限定43769812600試行1・正式44660400847試行1を照合した。いずれも起動を確認してから所有UUIDの実行先解決に失敗した。正式527の同じ原本変更はListの照会まで到達しており、今回はそこより前で停止した。正式527と528の `test-manual-ui.sh`・iOS26のRuntime準備・実行先指定は同一。`Any iOS Simulator Device` を代わりに選ばず、新しい所有Simulatorで同じケース・期限・実行先の照合を行う。

### 正式528・試行2でもiOS26通常Bの高さ調整中に266.508ms

同じsource `d1c3bf71ab88c9e9180cdba2a7949474ad0ed53b`、iOS26.5／SDK27.2。[通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/45112946241/job/137518367474) の `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は06:28:23 UTCに失敗した。実解放と横到着は成立。到着と最初の整列枠の間が266.508ms、main CPU約256.6ms、21枠から22枠になり幾何欠落0。昇格・スクロール復帰は約0.53ms、最初の設定開始は到着から約216.1ms後。計測中のXCTestアイドル照会はログに現れず、前回より少ない公開前ジョブの状態でも同じ段階の停止が再発した。往路で失敗し後続は未到達。一緒に再実行した[手動原本変更](https://github.com/n624-dev/takupoke-ios/actions/runs/45112946241/job/137518367632)は同じSDKと元の条件で425.135秒、成功。全ジョブ終端、公開は依存ジョブが失敗したため未実行。

再発時は `FixtureActiveGridMetrics|fixtureGridMetrics|isDisplayedTimetableWeek|configuration-begin` も調べた。生成アプリだけのグリッド診断は、選択中の週や測定値の変化でViewを再評価し、メインスレッドで全カードの集計、ファイル読取、JSON変換を行う。既存の週送り検査は枠を採取し終えてから、この診断で到着週が行事だけかを照合する。枠の採取中は診断の組み立てを待ち、診断が実行された回数も記録する。実接触、実座標、描画間隔上限90ms、ガラス画像、終了後の診断と元の週への復帰の検査を維持する。診断処理が過去の遅延をどれだけ占めたかは未確定。iOS26.5／27.0・SDK27.2の週送り限定で検証する。

### 週送り限定45127238474・iOS27は週送り後の別ケースで見出しを画面内へ移せなかった

[iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/45127238474/job/137534297120)、source `99bd3b9`、試行1。週送りの描画検査は53.024秒で成功。往路50.184ms・復路39.624ms、幾何欠落0、実枠採取中の診断JSON読取0件。続く `testTimetableCommonClocksAndEventOnlyWeekScale` は07:09:32 UTCに163.379秒で失敗した。最大文字サイズの通常週で先頭日付の下端が854pt、可視範囲の下端が769ptだった。接触ログでは実縦ドラッグを配送したが、6回とも対象の枠は変わらなかった。横スクロール位置の確認は未到達。縦ドラッグが画面位置を変えなかった理由は未確定。

`UI_VISIBLE|testTimetableCommonClocksAndEventOnlyWeekScale|Week grid is outside the viewport` で正式503と正式528の通常A、現行 `visible` を照合した。正式503は行事週のドラッグ前の表示範囲、今回は通常週の先頭日付を探す途中。今回の可視範囲の中心 `(196.5, 441)` は、失敗後の実アクセシビリティ木で「変更込み」ボタンの枠 `(196,416.3,165,32)` 内だった。切り替えに触れないよう、同じ実Listで可視範囲に完全に収まる見出し・案内の実ラベルを既存のドラッグ始点候補にする。縦移動量、対象の完全包含、既存の最大文字・横位置・週移動の判定を維持し、始点と終点を数値ログで確認する。[正式528の同ケースが成功したiOS27 A](https://github.com/n624-dev/takupoke-ios/actions/runs/45112946241/job/137490689486)

### 週送り限定45127238474・iOS26では診断JSONを除いても同じ段階で停止

[iOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/45127238474/job/137534296998)、source `99bd3b9`、試行1。`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は07:11:26 UTCに38.470秒で失敗した。描画の停止339.005ms、収集23枠、実枠採取中の診断JSON読取0件。横到着0.2814秒、昇格とスクロール復帰0.2822秒、最初の設定開始0.5379秒。到着から設定開始まで約256.5ms、その間のmain CPU約253.7ms。正式528の2回と工程が一致し、診断JSONだけでは説明できない。Native検査は成功し両OSのジョブは終端。

`isDisplayedTimetableWeek|weekSection|configuration-begin|WeekGridAccessibility` で #125 の正式526・527、4d30920の限定と今の描画コードを比較。到着直後の選択変化で、準備済みの2つの週の中身にSwiftUIの環境値も伝播していた。候補では、既存の選択状態をアクセシビリティの表示判定だけで読み、UIKitの非表示状態も旧週・新週の実ScrollViewと新規登録時に更新する。準備済みの週の中身に選択状態の環境変更が及ばないようにし、実際の週の選択順・日時表示・接触範囲・VoiceOverの表示対象を維持する。これがCPU時間をどこまで減らすかは未検証。両OSの週送り限定で、90msの元の上限・往復・描画画像・実グリッドと、別ケースの最大文字時の実ドラッグを確認する。

Linuxの生成後Swift構文検査で、変更途中の `WeekGridAccessibility` を2行に分割すると、行を基準にした既存の生成器が引数の途中に観測用Viewを挿入することを確認した。引数のラベルをローカル変数に取り出し、生成器が利用する呼出しを一行で閉じる。生成後のソースを再検査してからAppleの限定に進む。

### 週送り限定45131022827・iOS27で準備済みページの環境更新を外しても148.194ms

[iOS27.0／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/45131022827/job/137546295053)、source `a60c912`、試行1。`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は07:35:19 UTCに37.559秒で停止。実枠の間隔148.194ms、採取中の診断JSON読取0件。到着から最初の設定開始まで約132.1ms、同区間のmain CPU約130.7ms。準備済みページへの選択環境値だけでは説明できない。後続の `testTimetableCommonClocksAndEventOnlyWeekScale` は252.366秒で成功。Native検査も成功。

同じ限定の[iOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45131022827/job/137546294817)も、07:46:33 UTCに到着後149.169msで週送りが停止。後続の最大文字のケースは、リストのラベル `(196.5,635.7)` から縦ドラッグして実画面を移動し、193.980秒で成功した。通常の限定の全ジョブは終端。

### 週送りスタック採取45133851878・所有アプリは照合でき、sampleは期限で終了

[iOS26.5／SDK27.2](https://github.com/n624-dev/takupoke-ios/actions/runs/45133851878/job/137555309949)、診断source `5a81c57`、試行1。週送りの最初の高さ調整で333.099msを観測（08:02:06 UTC）。採取対象の実所有アプリを照合したが、`sample` は期限で終了してスタックを取得できなかった。開始から採取結果の記録まで12.23秒。最大文字は同じ実始点の照合を通って216.509秒で成功。採取を有効にした実行なので、描画の成績は正式配布の判断に使わない。全ジョブ終端。

### 週送り限定45136782217・配置を分けてもiOS27は133.518ms、iOS26はRuntime準備で停止

source `e2b1804`、試行1、SDK27.2。[iOS27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/45136782217/job/137564853957)は08:22:06 UTCに `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` が39.044秒・高さ中133.518msで停止。診断JSON読取0件、27枠、到着後の最初の設定開始まで約100.5ms。最大文字は153.878秒で成功。[iOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45136782217/job/137564854270)は08:15:53 UTCに取得済みRuntimeの再登録が30秒内に完了せず、生成アプリのビルドとXCTestの前に停止した。Nativeは成功し、全ジョブは終端。

`Owned asset re-registration did not complete|SWIFT_OPTIMIZATION_LEVEL|Onone|configuration-begin` を確認した。iOS26の準備は限定43767607953の停止と同段階で、条件に合うRuntimeや実行先の判定は維持する。iOS27のアプリのコンパイラ行では `-Onone` を確認した。公開IPAの対象は `Release` の `-O` と `wholemodule`。週配置の試験的な変更は旧製品のコードへ戻す。通常UIの生成アプリ本体には公開版と同じSwift最適化設定を適用し、テストの入力、取得点、合格基準、DEBUGでの架空データ、XCTestと手動訂正用の既存設定を維持する。公開ビルドに近い実行条件で、同じ90msの基準を両OSで検証する。

### 週送り限定45140095070・公開版と同じ最適化でも週送りの高さ調整が停止

source `bd586dc`、試行1、SDK27.2。両OSの実コンパイラ行は `Takupoke -O -whole-module-optimization`。[iOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45140095070/job/137575662106)は08:49:24 UTC、`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` が40.348秒、到着後134.629msで失敗。採取中の診断JSONは0件、29枠。最大文字は159.088秒で成功。[iOS27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/45140095070/job/137575662229)は08:52:42 UTC、同ケースが48.799秒、217.638msで失敗。診断JSONは0件、21枠。続く最大文字では、見出しの下端955ptが可視下端769ptの外にあり、縦ドラッグの候補ラベルを丸ごと表示できる始点が得られず132.607秒で失敗した。Nativeは成功し、両OSは終端。

最大文字の縦移動は `No visible list label|UI_VISIBLE|ObservedScreenGeometry` で限定45127238474と45131022827を照合した。全体が画面に入っている必要があるのは検査対象の見出し。縦スクロールの始点を選ぶ際は、その操作を受けることが確認できた非操作ラベルの可視部分から、始点と終点の両方が画面内に入る点を求める。変更行の入力回避に使う従来の始点選択や、最大文字の見出しの完全包含は維持する。

追加の[スタック採取45143832553](https://github.com/n624-dev/takupoke-ios/actions/runs/45143832553/job/137588120836) は `0b73d32` のiOS26.5／SDK27.2で往復50.270／54.550ms。最初の接触では所有アプリの照合が時間内に完了せず、2回目は接触から6.11秒後に採取コマンドが始まった。コマンド自体は成功したが認識できるメインスレッドの枠はなく、動作中の原因に対応付けられない。最大文字は成功。[最大文字限定45144000876](https://github.com/n624-dev/takupoke-ios/actions/runs/45144000876/job/137588670963) は `1c3ca75` のiOS27.0／SDK27.2で319.609秒、成功。

`WeekColumnsLayout|rowHeights|sizeThatFits|placeSubviews` で現行の週グリッドを確認した。同じ列幅と子Viewの数で、サイズ要求と直後の配置がそれぞれ全見出し・列の自然高を求めていた。サイズ要求で得た測定値は、同じ列幅・子View数の最初の配置に限って再利用する。新しいサイズ要求、単独配置、別の列幅では測り直す。週の選択時刻や90msの基準は維持する。この重複作業が停止時間のどれだけを占めるかは未確定で、限定で比較する。

Linuxの局所レイアウト検査で、製品の `private` 型を抽出後に公開範囲の変数へ入れてSwift型検査で停止した。型の公開範囲を保ち、検査変数にも `private` を付けて同じ式・期待値を実行する。

`84a4e91` のLinux全体検査はSwift 700件・失敗0。Pythonは `test_actual_xctest_comparison_and_pixel_geometry` が幾何ケース数の固定値8に対して9件を見つけ、実Swiftの再実行前に停止した。部分表示ラベルの新ケースをSwift全体は実行済み。`geometry_names|ObservedScreenGeometryTests|test_actual_xctest_comparison_and_pixel_geometry` で、名前を抽出してすべて走らせる既存のLinux補助と台帳を照合した。旧8件と追加1件の期待を同期し、補助からも9件すべてを実行する。

`84a4e91` の[週送り限定45149532016](https://github.com/n624-dev/takupoke-ios/actions/runs/45149532016)は両OSで成功。高さ調整中の最大間隔はiOS26.5で49.854／49.997ms、iOS27.0で33.125／31.640ms。各方向の幾何欠落と採取中の診断JSON呼び出しは0。最大文字は両OSで成功し、iOS26.5は実ラベルからの縦ドラッグを数値ログで確認した。Linux補助の同期後はPython全344件・既定skip2・失敗0。正式公開の全組と同じコミットの結果は別に記録する。

### 正式529・試行1のiOS27 Aで時間割変更の再起動後にAX照会が停止

[iOS27.0／SDK27.2の通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/45154215506/job/137625383531)、source `86866fd8df355c8483704d3df78903b896023b2f`。 `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch` は10:45:02 UTC、738.024秒で失敗。`RETAINED_CHANGE` は最初の反映直後と再起動後にいずれも `visible=true excluded=true`。実「修正済み」から3・4行目を再編集し、反映後に表示を確認した。10:40:23 UTCに二度目の再起動。その後の「内容を確認・修正」のタッチ開始と解放が配送され、同タイトルのNavigationBarを確認した。`change-edited-rows` を探す表示領域の処理で、`bodyViewport` 内の `次へ` のボタン列挙までログに記録され、約132秒後に `Navigation.swift:157` で `Timed out while evaluating UI query`。二度目の再起動後の3・4行目の内訳の再確認が未到達。同じXCTestプロセスの23件中、最大文字を含む残り22件は成功。所有アプリのスタック採取は `owned-app-unavailable`。下位原因は未確定。

`変更後、架空科目C`、`change-edited-rows`、`testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`、`UI query timeout` でN153と正式44741890239の試行1・2を照合した。先行試行1は最初の再起動後の表示探索で `app.frame` が停止し、試行2は保持科目Cと除外科目Bの確認を通過した。今回はその確認と初回の「修正済み」への遷移も実行済み。二度目の再起動のあと `SetupView.swift` の初期設定専用フッターを探す追加照会が停止した。正式528の同ケースはiOS26・27で成功している。停止中の待ち先と最後に編集した行の内部状態はこの試行からは確定できない。

### 正式529・試行1の通常BでカウントダウンのAX照会と通知画面への接触が停止

[iOS27.0／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/45154215506/job/137625383591)、source `86866fd8df355c8483704d3df78903b896023b2f`。10:55:19 UTCに終了。`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent` は10:36:34 UTC、448.542秒で失敗。個人予定と学校行事の登録を進め、再起動、新しい元PDFの警告、設定からカウントダウンへの再遷移を観測した。保持した固定カウントダウンを探す `Button (First Match)` の存在照会が2回内部再試行の後、`ApplicationChecks+Navigation.swift:144` で `Timed out while evaluating UI query`。該当カードの保持・詳細は未確認。同じフェーズの残り7件は成功し、後続フェーズは未開始。

同じ試行の[iOS26.5／SDK27.2の通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/45154215506/job/137625383466)は11:19:13 UTCに終了。`testNotificationControlsAndAppearance` は11:15:33 UTC、120.338秒で失敗。実設定タブを開き、通知行と子ラベルの実枠を確認。ラベル中央(48,603.33)への一回の0.1秒指定の接触は始点がUIKitへ届いたが、実配送間隔約277msで `phase=cancelled`、解放なし。`ApplicationChecks.swift:148` の通知NavigationBarの10秒判定で停止。通知の許可・スイッチ・外観設定は未到達。同じフェーズのカウントダウン通知予約は152.205秒で成功。両OSの週送りは最初のフェーズで成功し、到着後の枠間隔はiOS26.5が67.099／66.483ms、iOS27.0が44.224／51.061ms。欠落枠と採取中の診断JSON読取は全方向0。

`Transport closed|外部ログ保存先|N06|N14` で過去の転送経路を照合した。B両ジョブの本文取得でコネクターが切断し、公式RESTのジョブ単位の取得は署名先への接続でHTTP403。公式RESTの試行全体のZIP（`actions/runs/<run>/attempts/<attempt>/logs`）は残ジョブの進行中にも取得できた。約29.8MBのZIPから完了済みの対象2ジョブの原ログを分けて確認した。ジョブ単独の転送エラーをテストの失敗理由と混同しない。

`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent|Button (First Match)|UI query timeout` で正式44700448423を照合。前はアプリ起動返却前、今回は再起動後の対象ボタン照会が停止した。正式528のiOS27 Bは同じカウントダウン検査を完走。`NOTIFICATION_ROW|phase=cancelled|screen("通知")` でN48・U75・正式44513210500の6bc3c18と現行 `openNotificationSettings` を照合。6bc3c18と同じ場所と段階の入力取消が見えた。正式527のiOS26 Bでは同じ入口を通り、今回のiOS26 Aでも同じ入口を使う `testChangedDataProducesOneLocalNotification` を含む全ジョブが成功した。iOS27 Aの修正済み行の再起動確認も、正式528の両OSと今回のiOS26 Aで通った。`d1c3bf7` 以後、失敗した事例のリスト照会、対象カード、通知行の操作に使われる分岐と設定の製品コードに変更はない。実AX照会と入力取消の下位原因は未確定。

このsourceで失敗した3ジョブについて、同じsource・SDK・全ケース・判定を保持して、新しいRunnerかつ初回の手動訂正ジョブが並行しない条件で一度だけ比較する。公開は失敗ジョブの再実行分を含む同じ公式試行の全必須検査を照合する。再試行で同じ接触取消や同じAX照会の停止が続いた場合は、各停止点に対応する照会や送出だけを見直す。

### 正式529・試行2の通常Bで再び2ジョブが停止

同じsource `86866fd8df355c8483704d3df78903b896023b2f`、Xcode SDK27.2。[通常iOS26.5 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45154215506/job/137685187485) は12:15:05〜12:32:42 UTC、[通常iOS27.0 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45154215506/job/137685187118) は12:15:03〜12:52:06 UTCで失敗。12:53の確認でiOS27 Aは進行中。既存の11成功は試行2へ継承された。ケース・段階・原因は原ログ取得前の時点で未確定。試行1との一致は原ログで確認する。

iOS26.5では `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` が12:31:21 UTC、87.076秒で停止。横到着直後の高さ調整で実描画間隔232.996ms、採取間のmainスレッドCPUは約221ms。横到着から昇格コールバックとスクロール復帰は約0.64ms、最初の `configuration-begin` は約176ms後。27枠、欠落0、診断JSON読取0。通知画面のフェーズまで進まなかった。正式528の同じ週送りで199.689／266.508msだった以前の停止段階と一致する。今回の初回は週送りを成功しており、負荷を占めた個別の呼出しは未確定。

iOS27.0の週送りは67.800／48.009msで成功。`before-settings` の `testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors` は12:35:13 UTC、258.396秒で `Navigation.swift:132` の `Present keyboard must have finite positive geometry`。先にKeyboardの存在を取得し、同じIdentityのframe再取得で内部再試行を観測した。個別の画面遷移とキーボード状態は前後ログと対照して記録する。同じフェーズの残り7件は成功し、試行1のカレンダーケースは今回は通過。後続フェーズは未実行。

`gridMetricReadsDuringMotion|fixtureGridMeasurements|onGeometryChange|configuration-begin` で正式528・限定45149532016と比較した。旧候補は計測中の診断JSON生成を除いたが、生成器が追加した各時限カード・日見出しの座標、行事見出しの寸法は表示のたびに取得し、変更を `@Published` の辞書へ書く。週送りの対象ケースは実画面のフレームを別の録画器で取得し、最後の診断JSONは `eventsOnly` だけを読む。座標・寸法の変換と更新をこの計測中に使わない構成で比較する。画面・実測・方向・90ms・PNG・行事週の条件は維持し、計測中の追加収集の書込件数も記録する。通常のカード寸法・最大文字のケースでは従来の座標収集を使う。232.996msの内訳はいまだ未確定で、これが原因とみなすのは実比較の後とする。

`countdown-delete-reminder-0|Present keyboard|Identity Binding|N153` で `contentViewport` と既存の一貫した幾何確認を比較した。今回は個人予定の標準文字で2を実入力し、キーボードの存在が成立したあと、削除行を表示する途中の再照会で幾何が無効だった。N153はキーボード列挙そのもののタイムアウト。現在のframeがとれなければ既存の `ObservedScreenGeometry.bodyViewport` で範囲を未確定にし、既存の探索中は押したりスクロールしたりせず再観測する。削除前の存在・削除後の消失・残った1日前の保存と再表示の元検査は維持する。

### 詳細な座標計測を除いた週送り限定・iOS27ジョブの停止

候補 `c0f6136a024e6fe53e600b4d254fc616f9c89aee`、SDK27.2、試行1。[iOS27.0の週送り限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45180196646/job/137711719890)は13:03:55〜13:13:39 UTCで失敗。Nativeは成功、iOS26.5は13:25確認時点で進行中。同じsourceの[通知日数を含むiOS27限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45180380204/job/137712356522)は成功。失敗した週送り限定のケース・段階・原因は原ログ取得前の時点で未確定。

iOS27.0の `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は13:08:40 UTC、30.900秒で失敗。横到着直後の高さ調整で114.370ms、近傍のmain CPU増加は約105ms。31枠・欠落0・診断JSON取得0・個別座標の書込0。最初の配置設定まで到着後約79ms、設定自身は0.070ms。元の最大文字は243.390秒で成功。書き込みを除いても同じ停止が残る。通知日数の削除・元の1日前の保存／再表示は171.726秒で成功し、同じ限定のカレンダー282.946秒、通知予約138.862秒も成功した。

`configuration-begin|WeekPagesCanvas|WeekColumnsLayout|sample-timeout` で正式528・529の同段階と、45133851878／45143832553のスタック採取を照合した。外からの採取は未取得か対象区間より後に始まった。診断用の生成アプリに限り、横到着から高さ調整完了までの週操作・画面構築・週幅測定／配置の呼び出しごとの開始・終了・main CPU差を固定名で測る。観測対象は試行2でCPUが増えた到着後〜最初の枠取得。架空データ、元フレーム条件と期限を使い、計時のための分岐を製品に入れない。計測付きを製品配布の成立とは扱わない。

同じ限定の[iOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45180196646/job/137711719818)は13:34:02 UTC、GitHub注記 `The job has exceeded the maximum execution time of 30m0s` で終了。シミュレーターbootは約9分、テスト実行開始からケース開始までは約6分30秒。週送りの実ケース59.498秒で往復49.967／51.534ms、29／31枠、診断2種の回数0。最大文字は217.236秒で成功。13:33:46に検査フェーズと所有Simulatorの削除の完了を記録し、その後の外枠が未完了。主担当の取消はなく、ケースの到達点は保持し、ジョブ全体は成功に数えない。上記のiOS27の描画停止とは異なる段階。

### 週送り昇格のCPU診断・iOS26で停止

診断 `60a55abb876619f19b3128557ca613d9a2220574`、Xcode SDK27.2、試行1。[iOS26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45184977667/job/137728124723)は13:32:53〜13:56:20 UTCで失敗。[iOS27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/45184977667/job/137728124807)とNativeは成功、全ジョブ終端。対象のケース・停止段階・計時の内訳は原ログから確認する。

iOS26.5の `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は13:49:45 UTCに166.500ms・38.693秒で停止。最大文字は307.017秒で成功。到着が0.282690秒、次の枠0.449190秒、昇格処理の復帰が0.283111秒、最初の `configuration-begin` は0.388497秒。失敗区間内の `page-content` は4回、main CPUは11.751／5.297／4.685／0.773ms。週操作は2.646ms。記録上限120に到達し、ネストした計時値を足して残りの停止時間と比較できない。iOS27.0は往復49.974／45.555ms、同じ最大文字175.396秒、成功。診断付きの結果は公開の判定には使わない。

`WeekPage|page-content|WeekColumnsLayout|isDisplayedTimetableWeek` で正式528・限定45136782217・45180196646を照合した。到着直後に新しい週を作ることは想定していないが、今の `WeekPage.body` は同じ版でも呼ばれるたびに `content()` で週内容を構築する。週と既存の表示リビジョンで作成済みの表示値を保ち、組み替えた準備範囲から外れた週とリビジョン変更時は破棄する。表示値は最初に必要な時に作り、横移動中に新たな一括構築は行わない。現在の週に切り替わる時点、選択時のVoiceOver対象、実接触・90ms・実枠は維持する。旧44238306393で親だけの `accessibilityHidden` は同じScrollView IDが重複したため、子側の処理は保持する。再構築以外のCPU消費と性能の改善幅は未確定。

準備週の局所Linux検査は、製品の `WeekPage.body: some View` を含めた代替型で `AnyView` に `View` 適合がなく型検査エラーになった。Appleでの既存 `AnyView: View` と同じ適合を代替型に付ける。製品の型、実キャッシュと古い表示値の破棄を照合する検査は保持する。

### キーボードの実枠を要求した通知日数限定の停止

`06de837ecf720178daaf48f07484801e49fa731d`、Xcode SDK27.2／iOS27.0、試行1。[通知日数限定45196180262](https://github.com/n624-dev/takupoke-ios/actions/runs/45196180262/job/137767118854)は14:37:30〜14:59:51 UTC、実行stepが終了1。全ジョブ終端。ケース、入力の到達点、下位原因は原ログから確認する。

`testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors` は156.269秒で成功。変更したキーボード実範囲での削除、消失、1日前の保存と再表示まで完走した。カレンダーも190.175秒で成功。`testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch` は315.289秒で失敗。実通知センターの対象2件・別登録2件・対照1件、許可ありを確認して再起動し、設定からカウントダウン画面へのタッチを確認した。復帰後の予定カードの `Button (First Match)` が二度の内部再試行の後、`Navigation.swift:149` の存在照会で時間切れ。再起動後の予約照合と取消は未到達。下位のAX待ち先は未確定。

`testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch|Button (First Match)|UI query timeout` で過去を照合した。45068137098では最初の通知センター応答が止まり、今回は予約と許可が成立した後の画面照会。正式529試行1のiOS27 Bで別ケースのカレンダーも再起動後の同種の照会が止まり、試行2は通過した。`c0f6136` の同じ通知予約ケースはiOS27.0で138.862秒の成功、529試行1のiOS26.5も152.205秒で成功。今回の限定の条件で個人予定の予約処理や保持条件には変更がなく、キーボード実枠を必須にした箇所は日数の削除だけ。正式全体の通常Bは通知フェーズで、今回先に走ったカレンダーと日数のケースとは異なるフェーズ構成で、既存の全検査を同じsourceで確認する。限定は2件成功・1件失敗として記録し、公開の合格に数えない。

### 正式530・試行1のiOS26通常Bが停止

source `50f4047d28ca862c7622488b843f2f0737d38761`、Xcode SDK27.2、試行1。[通常iOS26.5 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45201354410/job/137788644887)は15:11:03〜15:27:21 UTCにfailure。15:49の確認時点で配布、Native、iOS26手動3件、iOS27手動1件は成功し、ほかのジョブは進行中・待ち。ケースと段階はログで照合する。

`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は50.174秒で失敗。横到着後の高さ調整中、往路66.731msは基準内、復路98.333msで90msの基準を超えた。往路30／復路27枠、全方向の欠落・詳細座標／JSON計測・到着後の週ビュー構築は0。復路の到着前最後のサンプルから到着後最初のサンプルまでのmain CPU増加は92.912ms、到着から最初の `configuration-begin` は81.160ms。のちの通知検査には未到達。先の正式529試行2の往路232.996msより短く、その診断で見えた表示内容の再作成は観測されていない。残るSwiftUI内部処理の内訳は未確定。

`weekContentBuildsAfterArrival|configuration-begin|WeekPages` で診断45184977667と、同じ製品・週送りのケースを実行した `a327f2b` のiOS26.5限定を照合。限定では往復50.046／65.900ms、再作成0、全ジョブ成功。正式との違いは同時進行のジョブ、実Runner、後続ケース構成。全ジョブの終端とほかの失敗箇所を確認した後に次の範囲を決める。準備範囲を保ったまま `weekStart` の読み取りを実表示と操作の近くへ移し、上位に伝わる必要がない更新を外す案をローカルで確認する。以前の `e2b1804` と異なり週表示値の再利用が既にあり、実ScrollViewの既存AX修飾は維持する。

16:38:56 UTCに全ジョブ終端。公開必須14件のうち13件が成功。通常iOS26.5 Bだけが失敗し、公開ジョブは依存関係により未実行。iOS27.0 Bは同一sourceで16:11:58 UTCに成功し、週移動、日数欄、再起動後の予定・通知取消を含む全検査を通過した。両OSのA、手動訂正各4件、配布、Nativeも成功。

同一sourceで実Runnerが変わる失敗ジョブの再実行を一度行う。前回の正式529の232.996msの停止と異なり、今回の週内容の再構築は0で、同じ製品と操作の限定ではiOS26.5の往復も基準内だった。正式530で基準を超えたのは復路だけで8.333ms。再実行では初回の手動訂正ジョブとの並行もなくなる。Runnerの差が原因かは未確定。90msの基準、往復実操作、実枠の計測と後続の通知検査を維持し、公開は公式試行の全必須ジョブ成功後に行う。

再実行前の差分レビューは `86866fd..50f4047` の製品・テスト・実行コード（27,762 bytes、SHA-256 `0637bcbab3edf63c1a8a39b5fde6cd6b071ece7bf5b043a57986bde948b93d49`）。独立レビューに停止事項はなかった。準備週のキーについて、主担当が週の日付、受理済み資料の識別・解析版・解析日時、時刻・名称の版、表示クラスと設定、テーマ、文字サイズ、幅を現行のレイアウト・時刻・行事の入力と照合した。READMEのGitオブジェクトは `5fb62b8bb905d4ae6698de9b2e418ffa825c7383`。

### 正式530・試行2のiOS26通常Bは文字サイズ設定前にSimulatorが停止

同一source `50f4047d28ca862c7622488b843f2f0737d38761`、iOS26.5／Xcode SDK27.2。[通常iOS26.5 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45201354410/job/137849319575)は16:42:01〜16:53:59 UTCにfailure、16:54 UTCに全ジョブ終端。13成功を試行2のAPIで照合。Runtime準備・Simulator作成・build-for-testingは成功。16:53:27.688に `simctl bootstatus` が `Finished`、16:53:28.916に `bootstatus-complete`、直後のSimの文字サイズ設定で `com.apple.CoreSimulator.SimError` 405／`Unable to lookup in current state: Shutdown`、exit149。XCTestは開始0件。Host診断では停止とサービス接続エラーを観測。後片付けでトレースの子プロセスへのシグナルにpermission errorが出たが、文字サイズ設定での停止より後。Simulatorが落ちた直接の下位原因と週移動の再現性は未確認。公開ジョブは未実行。

`SimError405|current state: Shutdown|simulator-content-size-enter|exit149` でN194・N198と[限定44544262245の試行1・2](https://github.com/n624-dev/takupoke-ios/actions/runs/44544262245/attempts/2)の詳細を確認し、`656cdaa` の `boot-simulator-ui.sh` と `test-app-ui.sh` を `50f4047` と照合した。旧試行1は同じ `bootstatus Finished` 後の最初の文字サイズコマンドで停止。旧試行2は新規所有SimulatorでXCTestを開始し、連続週移動と黄色に成功し、別の実横移動検査まで到達して失敗した。旧試行1のRunnerでは現行のトレース開始自体がなかった。今回の試行1のiOS26 A・Bは同じ完全SHAで検査を開始済み。iOS27通常Bの成功原ログでは週移動・カレンダー179.744秒・日数入力とキーボード中の削除349.868秒・再起動後の個人予定の予約照合と取消112.261秒、および全21 XCTest完了を確認した。

直近は製品の比較に入る前に試行が終了したため、同じSHAから失敗したiOS26 Bだけを新規Runnerで一度起動し、既存13成功を継承する。過去に同じ停止から新規Runnerで実検査へ到達したことを根拠とする。試行1の性能停止が解消したとは扱わず、UI検査、90ms、実枠、範囲は変更しない。同じ起動条件が再び失敗した場合は所有Simulatorの状態遷移と起動時の復旧を見直す。実検査で同じ性能停止が再度出た場合は、到着時の日付の購読範囲を比較する。

### 正式530・試行3のiOS26通常Bは個人カウントダウンの通知スイッチで停止

同一source `50f4047d28ca862c7622488b843f2f0737d38761`、iOS26.5／SDK27.2。[通常iOS26.5 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45201354410/job/137864866063) は17:05:46〜18:24:39 UTCにfailure、18:24:40に全終端。公開必須13件成功で公開なし。週移動の高さ調整は往復83.039／49.588ms、28／29枠。欠落・到着後の週再構築・幾何計測は0。通常Bの16件が成功。うち設定の通知と外観は197.350秒で成功した。後続のOS文字サイズ3種は未到達。

`testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch` は158.782秒。最初の実予約0件を確認し、個人予定の初回編集に入った。18:23:08 UTCに行と一意の内側Switchの実枠・包含・操作可・値0を確認し、内側の25%→75%の要素相対水平操作をXCTestが記録。15秒以内に外側の値1が成立せず `ApplicationChecks+Notifications.swift:575` で停止。保存、OS許可、予約追加、再起動と取消は未到達。終了後もRuntimeはavailable、所有SimulatorはBooted。旧 `TAKUPOKE_INPUT` には当該PIDの記録がないが、同PID 52245の時系列 `CI_SIMULATOR_EVENT` では実UIKitへの接触開始、315.67→347.33ptの移動、解放の配送を確認。接触の時計は約200ms、UIKit観測の開始から解放までは6.527秒で、dispatch62の入口から配送返却まで5.636秒。時間差が値未変更を起こしたか、内側Switchがどう処理したかは未確定。

`thumb-drag|tapNativeSwitch|testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch` と、学校側の `06b4551` と `4b4c6ae`、N239、行の `76042cc`／`b880e5f`、現行ヘルパーを照合した。学校通知の旧法でも実水平操作が終了したままONにならず、0.33秒の `NativeTestContacts` を採用した候補は同一sourceの通常A両OSで実4件の検証に成功済み。今回の個人予定は正式529試行1のiOS26.5、正式530試行1のiOS27.0で完走したが、現在のiOS26.5試行3では最初の0→1で停止した。個人のケースだけを同じ既存の時刻付き手順へ寄せる。実ネイティブ枠の25%・75%と中央、全包含・一意性・状態・有効性、操作一回、15秒以内の0→1／1→0、保存、OS許可と実予約数、再起動、別予定と対照予約の保持は維持する。生成アプリの既存固定ログに個人予定の実編集値の変更も含める。到達は `CI_SIMULATOR_EVENT`、反応は `countdown-notice-draft-on/off`、実予約は元の端末照合で確かめる。まず対象の1ケースを正式と同じSDK・各OSの起動モード（26 GUI／27 headless）で確認する。準備済み週の表示や製品コード、公開ゲートに変更はない。

### 個人通知限定45239584216・試行1のiOS27は最初の保留予約照会で停止

source `05aa9e995af58ab0d7712770bf4d25cef47014c4`、iOS27.0／SDK27.2。[iOS27限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45239584216/job/137920293006)は18:33:07〜18:44:05 UTCにfailure。生成アプリのビルド114.9秒とSimulator起動169.4秒の後、18:41:30 UTCに実ケース開始。最初の「予約を照合」へのタッチと解放は実配送済み。静的テキストの照会は返ったが、「保留予約を取得中」のまま、最初の実予約／別登録／対照0件が15秒以内に成立せず行588・54.594秒で終了。iOSの通知サービスは失敗後の確認でrunning、サービスログ照会はtimeout。今回変えたSwitchのON/OFF、保存、許可、予約・再起動は未到達。iOS26は18:54の時点で継続中。

`fixture-countdown-pending|保留予約を取得中|45068137098` で `44d8932` の実記録と当時の `countReservations`、現行の `getPendingNotificationRequests` と比較した。旧53.160秒の停止も同じ初回・同じ待機条件。形式の違う元PDFや時間割、今回のSwitch送出は未関係。正式530試行1のiOS27 Bは通常の設定・通知操作を先に行う順で、同じ個人予定を112.261秒で完走。下位のUserNotifications応答停止を未確定として残し、同じiOS27／SDK27.2とheadlessで既存 `countdown-notification-context` を使う。正式に含まれる設定詳細と通知操作のあとに元ケースを一回実行する。初回0件、待機15秒、許可・保存・実予約と再起動後の取消を変えない。実OSの通知設定を先に通る差を比較し、ケースの成功を仮定しない。限定は30分、今回11分の単独実行に設定・通知の過去数分ずつを加えても範囲内の見込み。進行中のiOS26ジョブは取消ししない。

### 通知の先行ケースを含むiOS27限定もOS応答を観測できず停止

source `b23e0105467040f61b2dd70c5b0ee5f52bae0294`、iOS27.0／SDK27.2、試行1。[iOS27比較](https://github.com/n624-dev/takupoke-ios/actions/runs/45243562141/job/137934317377)は18:56:37〜19:19:13 UTCにfailureで全終端。設定詳細は467.530秒で成功。続く `testNotificationControlsAndAppearance` は通知行の実接触、通知Switchの開始・解放、`notification-on-binding`、`notification-auth-request`、`notification-auth-returned` まで確認し、許可callback未観測のまま337行・98.997秒で失敗。個人予定は `予約を照合` の開始・終了が配送されたが、同じ `保留予約を取得中` のまま588行・58.176秒で失敗。変更対象Switchは未到達。UserNotificationsから二つの経路で応答を観測できなかったが、サービス内部の原因は未確定。

`notification-auth-returned|permission and enablement|fixture-countdown-pending` でU15、`d63ecf4` の45066765115、`44d8932` の45068137098と現在の `testNotificationControlsAndAppearance`／`countReservations` を比較した。先行通知設定の操作は今回は実BindingとOS要求まで成立したが、正常な許可・保存は成立しなかった。先行実行が正常に終わった条件の再現には至らなかった。iOS27の実0.33秒操作は同じ通知Switchの学校ケースで実値ONを、正式530の同じ製品の通常Bはこの二つのテストの実許可と個人再起動後の取消まで確認済み。iOS26は今回の個人2方向を新しい操作で実検証した。iOS27個人の新しい0.33秒による値変更は未確認。今後、同じ限定条件でまた最初の要求を繰り返さず、通常の先行画面、全経路と同じSDK・実機種を使う正式CIで再評価する。OSの結果は注入せず、全14件と公開ジョブが成功するまで配布しない。

### 正式531・試行1のiOS26手動単項目はAppleのランタイムカタログ取得で停止

source `18a7f5cf6537bb79b3cc47e1d0fd6bf5fcc115b0`、iOS26.5（23F77）／Xcode SDK27.2、試行1。[手動単項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953427100)は19:55:17〜19:55:44 UTCにfailure。18秒弱で `xcodebuild -downloadPlatform iOS -buildVersion 23F77 -architectureVariant arm64` が `DVTDownloadableErrorDomain` 41、`DVTDownloadsUtilitiesErrorDomain` −1、`com.apple.MobileAssetError.Download` 47（AppleのiOS Simulator Runtimeカタログ取得中のネットワークエラー、`tryAgainLater=true`）、exit70。Simulatorの作成と元の `testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground` は未到達。20:16時点でほかの13必須jobは成功4・進行中5・待ち4。取消さず終端まで確認する。

`Failed fetching catalog|MobileAssetError.Download` で限定44162262957（`7d63773b`）の同じ `-downloadPlatform` と正式499の成功経路を照合した。以前は同一Appleカタログのcode53、今回はネットワークcode47。同一試行の[iOS26高信頼欄](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953426811)が20:32:25 UTCに成功し、指定ランタイムでの検査は別Runnerで成立した。以前の正式530の同じ単項目も15:37:45 UTCに成功。今回未到達の訂正ケースや製品、ランタイム指定の変更は不要。20:40時点で必須成功7、失敗1、実行5、待ち1。iOS27通常A/Bは両方成功し、先行限定で未達だった実通知の許可と、変更後の個人通知の予約・復帰・取消を含む。全ジョブ終端後、同じSHAで失敗した範囲と比較条件を確定する。

### 正式531・試行1のiOS26通常Aは通知Switchの操作前hittabilityで停止

同一source `18a7f5cf6537bb79b3cc47e1d0fd6bf5fcc115b0`、iOS26.5／SDK27.2、試行1。[iOS26通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953426724)は19:46:16〜20:46:19 UTCにfailure。23件の基本検査は全件完了し、再起動後の変更編集395.789秒、連続週移動21.782秒、最大文字156.078秒も成功。独立通知の `testChangedDataProducesOneLocalNotification` は121.877秒で失敗。通知画面の行とOFFの外側状態、`authorization=notRequested;scene=active;application=0` を確認。内側の `0` Switchを照会し、`ApplicationChecks+Navigation.swift:265` の `isHittable` でXCTestが `Activation point invalid and no suggested hit points based on element frame` を報告。専用 `NATIVE_SWITCH` の操作前ログ、対象Switchへの接触、許可要求、実通知の発生は未到達。後続の学校全体カウントダウン通知は63.867秒で成功し、外枠の時間切れではない。Activation pointが無効だった理由は未確定。

同じ試行の[iOS26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953426590)は20:41:39 UTCに成功。実週移動、個人予定の両方向・実予約・再起動・取消、OS文字サイズ3種を含む。iOS27通常A/B、Native、iOS26原本変更とiOS27手動4件は成功。21:02 UTC時点で13件終端（成功11、失敗2）、iOS26手動3項目だけ進行中。公開ジョブは実行前。

`testChangedDataProducesOneLocalNotification|Activation point invalid|Failed to determine hittability` で正式496／`4899da2` とN126・N160の詳細、元のNavigationと現在の内側Switchを照合した。496の別Switchは外側の判定で同じエラー、同一sourceの再実行ではiOS26 Bが成功。今回の内側判定に先立つ実画面・OFF状態は確認し、正式44259503653の同ケースの通知行への接触取消とは段階が異なる。`50f4047` から時間割変更通知の操作、内外Switchの包含・hittability、製品通知に差分はない。正式530の[同じiOS26通常A](https://github.com/n624-dev/takupoke-ios/actions/runs/45201354410/job/137788644974)は全ケース成功。今回のiOS27通常AとiOS26 Bの別の実通知設定も成功した。全ジョブ終端後に同一SHAの失敗分を新規Runnerで一度比較する根拠とし、`isHittable`、接触数、実通知・重複防止と全件条件を保つ。同じ照会停止が再現した場合は実枠取得とhittability成立の条件を区別し、原因未確定のまま条件を緩めない。

### 正式531・試行1のiOS26手動3項目は再起動後の設定タブ接触が取消

[iOS26.5手動3項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953427050)、同一source／SDK27.2、試行1。実ケース `testThreeFieldsRequireEachAcknowledgementAndFourRefuses` は586.971秒。3項目の入力・個別照合、確認プレビュー、閉じる操作、前回結果の確認を経て再起動。新PID43631の設定アイコン座標(320.33,793.00)へ一回接触し、21:10:42 UTCの実ログで開始と約197ms後の取消、解放なし。設定の実選択が成立せず `ManualAssistanceChecks.swift:30` で終了。再起動後の4項目拒否・前回結果の再確認は未到達。サービス・UIKitが取消した下位理由は未確定。

`testThreeFieldsRequireEachAcknowledgementAndFourRefuses|Settings tab must be selected|NativeTabActivation|phase=cancelled` で旧正式43736804888／`092cc9c` の設定タブ選択失敗、正式44741890239の接触前のタブ画像照会停止、今回と同じケースのApple試行を照合。今回は一意な現在のタブアイコンを使いUIKitまで届いた後の取消。正式530試行1の[同じiOS26の3項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45201354410/job/137788645094)と、今回の[iOS27の同ケース](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/137953426780)は成功。`50f4047` から当該手動テストと `NativeTabActivation` の変更なし。新しいRunnerで一度の接触、元の選択期限と4項目拒否を再検証する。

正式531試行1は21:12:46 UTCまでに全終端。必須14件中11成功、失敗はiOS26の通常Aと手動3項目・単項目の3件、公開は未実行。同じsourceの失敗3件だけを対象とし、成功した通常B両OS、iOS27通常A、その他の成功を引き継ぐ。再実行前の新規GPT-6.2 Sol／Highに `50f4047..18a7f5c` のコード・検査3,941バイト、SHA-256 `42b4e69724a153037124c94d46ef47004caabb6c31c998ce2d47fffc177d9edc` を確認させた。指摘のヘルパー署名と分岐は主担当が確認し、試行1の通常B両OSの実成功でも変更済みの接触と判定が成立した。公開は再試行の14件と公開ジョブが成功した時点で行う。

### 正式531・試行2の公開ジョブはホスト資料テストのコンパイルで停止

source `18a7f5cf6537bb79b3cc47e1d0fd6bf5fcc115b0`、[公開ジョブ](https://github.com/n624-dev/takupoke-ios/actions/runs/45248143697/job/138055598636)は22:17:36〜22:33:12 UTCでfailure。Xcode SDK27.2の準備、同じ試行の事前検査14件と公開ジョブの実Picker UIまでは成功。`Material compilation`（46.9秒）が `RecoveryValidator.swift:23` の `cannot find 'PDF239SpecialScheduleParser' in scope` と24行の型推論エラーで停止。`tools/build-ios-app.sh` の先頭の資料テスト内。実iPhoneビルドとアップロードには未到達。調査で実行していたLinuxの解析テストと形式が異なる公開ジョブの同じホスト資料コンパイルは事前に実行していなかった。

`git log -S` と `c6f3cd2`、直前に更新した `b2721dc` の資料スクリプト、現行Swift Packageを比較した。曜日証明を導入した `c6f3cd2` で既存 `RecoveryValidator` が試験のStrictパーサーを参照し、資料専用の手動ソース一覧だけに反映されなかった。`ea22ab6` と `220a6c4` にも資料スクリプトの依存追従の修正がある。前回のソース一覧をさらに増やすとStrictから時刻・返却位置・時間割へ依存が広がるため、同じ製品モジュールを使う既存Swift Packageで資料の元シナリオも実行する。元の33入力がLinux／macOSそれぞれのPackageの登録に全て含まれ、Xcodeアプリの183 Swiftファイルは全件・一意に登録されていることを別に点検した。

Linuxの新しい配布登録チェック1回目は30件中1件失敗。対象Swift Packageの `sources` の最後を後続の `resources` の部分一致から取っており、実マニフェスト展開では登録済みの `WebPDFDownloader.swift` を検査側だけが見失った。境界のある `sources` の宣言を抽出し、同じ登録・共有実行経路の条件を再検査する。

### 正式532・試行1のiOS26通常Bで到着直後の描画間隔が基準を超過

source `9bc80c20c3995c38a5170c3a5c3db43b37bdab82`、iOS26.5／SDK27.2。[通常iOS26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45282315702/job/138072627994)は22:48:44〜23:08:46 UTCにfailure。`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` は往路で、到着0.265498秒→最初の整列枠0.381667秒が116.169ms、90msを超過。33枠、欠落・到着後の再構築・詳細幾何の書込と読込はいずれも0。到着から返却は約0.49ms、`configuration-begin` は到着の約47.7ms後、直近の到着前後でmain CPUが約109.4ms増えた。方向を反転する後半と通知には未到達。`18a7f5c` から製品差分なし。残るSwiftUIの内訳は未確定。Distribution成功。[Native](https://github.com/n624-dev/takupoke-ios/actions/runs/45282315702/job/138072627946)は818件・既定skip1・失敗0、今回組み込んだ資料とWeb PDFが0.260秒で実行完了した。

`weekContentBuildsAfterArrival|horizontal-arrival|configuration-begin` で正式530試行1の98.333msと試行3の83.039／49.588ms、正式531の両OS、限定45190291935、当時 `a327f2b`／現行を照合した。再作成0でも最新の最初の整列枠で同じ間隔超過。既存の週表示再利用を保ち、先にローカルで用意した `ba91ff8` の製品・計測用差分を `9bc80c2` に適用して別枝で比較する。移動中は準備対象週の親ビューが日付の変更を購読せず、表示中のページ、入力・バッジ・実AXの更新は必要箇所で従来の時点に行う。日付とVoiceOverの反映を遅延させない。表示の計算以外の残りCPUの内訳や効果は未確定。実回帰は元の90ms・往復・実枠・PNG・最大文字のまま両OS限定で測る。正式532の進行中ジョブは取消さず、限定は正式成功に加算しない。

同じ正式532の[iOS27通常B](https://github.com/n624-dev/takupoke-ios/actions/runs/45282315702/job/138072628082)は22:53:11〜23:26:13 UTCにfailure。23:38 UTCの確認で必須成功6、失敗2、進行4、待ち2。注記はexit1だけで、対象ケース・到達段階・原因は原ログ未確定。コネクター単独ログはTransport closed、実行途中の試行別ZIPはHTTP404。正式529・530の先例どおり全ジョブが終端した後の試行別ZIPを使用する。転送失敗を実ケースの失敗理由と区別する。

ジョブの実ステップを照合するとiOS27.0の準備までは成功し、`Exercise app screens with synthetic data` が22:53:29〜23:26:01 UTCにfailure。試行全体が終わるまでは、個別の落ちたケースと実行段階を原ログから確認できていない。

[限定45286730101のiOS27](https://github.com/n624-dev/takupoke-ios/actions/runs/45286730101/job/138084891233)、source `3c36708291e2cf9d9826910292efdee817374e43` は、到着から整列まで往路49.617ms、復路48.521ms、31／30枠で欠落・到着後再構築とも0。往復の実枠とバッジPNGの検査は44.080秒、共通授業時刻・行事だけの週・最大文字の確認は167.079秒で合格。Nativeも成功した。これは候補の限定結果で、正式532のiOS27通常Bの失敗箇所を示すものではない。

[同じ限定のiOS26](https://github.com/n624-dev/takupoke-ios/actions/runs/45286730101/job/138084891647)も、到着から整列まで往路67.573ms、復路29.108ms、各31枠で欠落・到着後再構築とも0。往復ケース50.512秒、共通授業時刻・行事週・最大文字227.718秒。限定3ジョブは全て成功した。正式532は00:13 UTCまでにDistribution、Native、iOS26通常A、両OSの手動訂正8件が成功し、iOS27通常Aのみ進行中。両OS通常Bの失敗はそのまま残る。

正式532試行1は00:18:30 UTCに全終端。必須12件成功、通常Bの両OSが失敗、公開は依存skip。終端後の試行別原ログで、iOS27.0／SDK27.2の通常Bは週移動1件を先に完了し、次の`before-settings`区間の`testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent`だけが385.119秒で失敗した。23:07:46 UTCに `tests/ui/ApplicationChecks.swift:135`、`Application 'jp.n624.takupoke.app-checks' does not have a process ID`。続く同区間の7件は成功。

初回の起動、個人予定・行事登録、登録後のホームに到達。前のPID12509の終了とSpringBoard前面を観測し、`app.launch()`を23:04:15 UTCに一回呼んだ。新PID17022は23:04:50にscene activeとfixture-readyを記録。約212秒経過して起動呼出し自体が失敗し、後続の前面照会と再起動後の警告・保存内容検査は未到達。次のケースは23:07:49に同じPID17022を終了させており、この時点まで起動済みプロセスが存在した。製品のクラッシュやXCTestの内部でPIDを取得できなかった原因は原ログから確定できない。

`does not have a process ID|testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent|app.launch` でU16（正式352、`b765302`）、正式44700448423試行2（`5cc39a5`）と現行を比較した。U16と同じAPI・エラー、44700448423と同じケース・実アプリ準備済み後の起動返却停止で、今回は二回目の起動。前回正式531の `18a7f5c` では同じiOS27 Bの21件が試行1で成功し、`9bc80c2` までの起動ヘルパー・カウントダウンのケースと製品は同一。週の比較候補もこの経路にコード変更なし。iOS26の再現した描画の改善を採り、次の正式実行でiOS27 Bの元ケース・一回起動・期限・保存検査を同じ条件で再検証する。正式532の2失敗、両OS限定の成功と次回の公開条件はそれぞれ記録する。

[正式533試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45297601510/attempts/1)、source `1a87351744bee2829dd277114b87342d6510989f` でiOS26／27の通常Bは元の21件を完了。週移動の到着から整列は26で49.862／66.277ms、27で85.413／33.185ms。4方向とも90ms以内、実計測枠28／29／30／34、欠落・到着後再構築は0。行事カウントダウンの登録・再起動・元PDF警告と保持は26が231.489秒、27が169.292秒で成功。両OSの個人通知の実予約・再起動・個別取消も成功。正式531の実ビルドで未到達だった資料とWeb PDFは公開ジョブでも実行され、0.338秒で成功した。正式533では全14事前検査と公開ジョブが成功した。起動返却停止が今後発生しないことはこの結果だけでは分からない。

## N244 設定・ステータス改修のローカルSwift依存ビルド（2026-11-24）

- source: `9bffdbff66c7617c2c86f0f7b2618ef0e10acebe` を基点とする `codex/ios-settings-status-ui` 作業差分。Linux x86_64／Swift 6.1.2、`bash tools/test-parsing.sh` の初回。62.6秒で依存GRDBSQLiteの `sqlite3.h file not found` によりビルド失敗。XCTest実行・Apple型検査・画面操作には未到達。
- 対処案を決める前に観測事実を記録。製品・テスト期待値の失敗とは断定せず、既存Linux環境の依存配置の記録と今回のヘッダー／ライブラリ状態を照合する。
- 照合: N42・N43の同じヘッダー欠落と `docs/development.md` の専用prefix手順を確認。現環境には以前の設置先がなく、zlib開発ファイルはあるがSQLite開発ヘッダーがない。公式Debian索引で現存する3.46.1-7+deb13u2のheaderと共有libraryを同じ所有prefixへ展開し、ビルド時・実行時ともその組を指定する。製品ソース・期待値・テスト期限はこの環境対処のためには変更しない。

## N245 設定・ステータス改修の独立Swiftハーネス型検査（2026-11-24）

- source: `9bffdbff66c7617c2c86f0f7b2618ef0e10acebe` 基点の作業差分、Linux／Swift 6.1.2、Python全検査の初回。`test_change_preview_actions.py` が実 `MaterialsModel.perform` を抽出したSwiftハーネスのコンパイルでERROR。観測された診断は `FileOperationOutcome` がscopeにないこと、架空 `MaterialsModel` に `cancellationRequested` 等の状態がないこと。実処理・UIの成功を検証できたとは扱わない。
- 対処案を決める前に記録。製品とハーネスの宣言、以前の共有helperとcallerの同期記録を照合し、新しい取消状態を実行入力・実結果で検査できる構成にする。既存のプレビュー保持・completionの成功条件は維持する。
- 照合: N178・N229の実helperと独立ハーネスの同期漏れ、基点と現行の `perform` と抽出テストを比較した。取消状態・キュー・監視破棄の宣言をハーネスにも追加し、分類関数とキューは実ソースから抽出する。既存の失敗時プレビュー保持と成功時だけの閉鎖を残した上で、4種類の取消エラーを実performへ投げ、completion=false・failed=false・前回結果／プレビュー保持・待機要求破棄を追加検査する。
- N244の依存対処後、Swift packageの715件が失敗0（91.083秒、取得・ビルド込み271.0秒）。N245の初回Python全体は351件・ERROR1・予定skip2で終端し、ハーネス同期後の関連8件は11.247秒・失敗0。取消4分類と背景一時停止の実入口を確認した。Apple型検査・画面操作は別に確認する。

N245追記：ハーネス同期後のPython全体352件は266.187秒・失敗0・予定skip2で完了。予定skip2は固定公開フォントを持つ専用環境のOCR資料生成検査で、Swift抽出ハーネスは実行した。

## N246 設定・ステータス限定CIのランナー期限（2026-11-24）

- source `002aae045d44c7f636e65053c6e3a62d9e45d335`、[45374452872・試行1／iOS 27](https://github.com/n624-dev/takupoke-ios/actions/runs/45374452872/job/138376808545)、SDK 27.2／iOS 27.0。生成アプリのビルド110.8秒と起動130.5秒は成功。
- `testEmptyDataCanBeConfigured`（73.618秒）、`testSettingsAccountDataAndFileDetails`（605.354秒）、`testSettingsGroupsAndCompactDataOverviews`（101.000秒）が成功。`testSetupCanBeSkippedAndOffersAllFiles` は起動後のアイドル待ちまで進み、10:48:43 UTCに外側の1440秒期限が発火した。セットアップの確認完了前で、`testStatusScreenUsesPublicResourcesAndDataRoutes` は未開始。終了コード124。画面の期待値失敗は観測していない。
- 同一source／実行の [iOS 26](https://github.com/n624-dev/takupoke-ios/actions/runs/45374452872/job/138376809363)、SDK 27.2／iOS 26.5。ビルド173.9秒・起動150.4秒は成功。同じ3ケースが60.047秒、407.742秒、84.810秒で成功。初期設定で「データを取得」の「次へ」を押した後、10:52:21 UTCに同じ1440秒期限が発火した。初期設定の完了前で、ステータス詳細のケースは未開始。終了124で両ジョブ終端。
- `Focused relaunch runner|1440秒|file-details|testSettingsAccountDataAndFileDetails` でN162、44456348152、44734888974と当時の限定条件を比較した。複数ケースの前に準備・ビルドとRunner起動があり、先行ケースが後続の実行時間を消費する点が共通。U10／U23／U73のセットアップ内の個別検査失敗は今回は観測していない。今回は両OSが同じ先行3ケースを完了した。シミュレーターの各操作にかかる時間は変動する。
- 次の限定では `status-settings` の各OSで設定詳細1件を独立ジョブにし、残る4件を別ジョブに割り当てる。全5件の重複なしの実行と、各ジョブの実行結果照合を求める。ジョブ・ランナーの期限、SDK・OS、実操作と公開条件は従来どおり。製品コードの差分は加えない。

## N247 iOS 27でAI・OCRスイッチの短い操作後も設定値が変わらない（2026-11-24）

- source `6f2770bb7a4c190b455ccc43b1e7e11b10a27be6`、[45379230056・試行1／iOS 27設定詳細](https://github.com/n624-dev/takupoke-ios/actions/runs/45379230056/job/138393594255)、SDK 27.2／iOS 27.0。生成アプリのビルドと起動は成功。`testSettingsAccountDataAndFileDetails` は139.733秒、11:07:07 UTCに `ApplicationChecks+Settings.swift:269` で失敗した。
- 再起動後にAI・OCRの表示と保存値が0であることを観測した。実スイッチの左側のつまみへ50ms指定の接触を一回送出し、UIKitに開始と約3.66ms後の終了が届いた。表示も保存値も0のままで、元の期限内に1へ移らなかった。その後の資料詳細は未到達。実配送と値の変化を記録したが、OS側が切り替えを受け付けなかった理由は未確定。
- `AI/OCR switch gesture|short-contact-50ms|thumb-drag` でU74とN239、当時の操作と現行 `tapNativeSwitch` を照合した。N239は同様の短い実配送（5.58ms）で再起動後の解除に失敗した。今回は最初の有効化で停止し、N212の長い接触の取消とは違い解放が届いた。N246の同じiOS 27・実スイッチ・座標では約28／84／84msの3回でそれぞれUIと保存値が変わり、再起動後のドラッグでも解除に成功した。
- 候補ではAI・OCRの先頭3回だけ、既存の `NativeTestContacts` で同じつまみへの開始と解放を80ms間隔で指定する。一回ずつの実タップ、実要素の一意性・表示枠・有効性・状態一致、45秒のUIと保存値の確認、再起動後の実ドラッグと再度の保持確認を維持する。製品のsetterと他のスイッチの操作は同一。実配送時間を再確認し、短さだけを原因と断定しない。

## N248 設定一覧側の4件完了後にランナー期限（2026-11-24）

- source `6f2770bb7a4c190b455ccc43b1e7e11b10a27be6`、[45379230056・試行1／iOS 27設定一覧側](https://github.com/n624-dev/takupoke-ios/actions/runs/45379230056/job/138393594453)、SDK 27.2／iOS 27.0。ビルド140.3秒、起動133.6秒。空データ158.937秒、設定構成337.909秒、初期設定118.526秒、ステータス詳細106.512秒の4ケースすべて成功。11:18:38 UTCにSimulatorの実行identityと4件の完了を確認した。
- 11:19:04 UTCに回収へ入り、11:19:15 UTCの1440秒期限で終了124。XCTestと選択照合は済みだがジョブは失敗。回収の正常完了と外側の最終照合は未確認。N246の「初期設定の途中で未実行ケースが残る」とは到達段階が異なる。
- [同じ試行のiOS 26設定一覧側](https://github.com/n624-dev/takupoke-ios/actions/runs/45379230056/job/138393594171)はSDK 27.2／iOS 26.5。ビルド167.0秒、起動373.9秒。空データ69.080秒、設定構成164.084秒、初期設定128.453秒は成功。ステータス詳細は両サービスの状態と監視結果、稼働率、履歴を確認して「この端末」へ戻った直後、11:21:55 UTCの1440秒期限で終了124。コピー操作の表示と設定へ戻る最後の検査は未完了。
- [同iOS 26設定詳細](https://github.com/n624-dev/takupoke-ios/actions/runs/45379230056/job/138393593969)はビルド193.0秒、起動449.0秒。AI・OCRの4操作と状態保持を確認し、資料一覧へ移動して最初の詳細を照会中の11:22:19 UTCに同期限で終了124。N247のスイッチ値が反映されない失敗はこのジョブでは観測していない。分割実行は全ジョブが終端した。
- `1440秒|Verified 4 XCTest completions|cleanup-enter` でN246の設定一覧側と限定44549765427を照合した。後者と今回のiOS 27はいずれもXCTest完了後の期限。iOS 26はステータス詳細の終盤に到達していたが、起動に373.9秒を要した。同じSDKとGUIでこの1ケースを先に実行して全操作と回収までを判定する。今後の `status-settings` でもステータス詳細を独立ジョブにし、残る4ケースを元の設定詳細1件と設定一覧側3件で実行する。実製品、各ケースの操作・確認条件、期限と照合条件は維持する。

## N249 時刻指定したAI・OCRタップでもiOS 27の値が変わらない（2026-11-24）

- source `38719b7956ce569a42a3e8270d050cf8530d2cbe`、[45382618904・試行1／iOS 27](https://github.com/n624-dev/takupoke-ios/actions/runs/45382618904/job/138405259984)、SDK 27.2／iOS 27.0。ビルド131.7秒・起動144.4秒は成功。`testSettingsAccountDataAndFileDetails` は135.724秒、11:37:06 UTCに `ApplicationChecks+Settings.swift:269` で失敗した。
- 最初の有効化でつまみへの80msの静止接触を一回送出。テストの既存互換経路でUIKitに開始と解放が届いたが、その間隔は約8.51msだった。UIと保存は0のまま。次のスイッチ操作・資料詳細には未到達。ジョブ回収は完了した。指定時間どおりに配送されたとは扱わない。
- N247とN239の短い静止接触を比較し、同じ静止接触を繰り返さない。N246の再起動後に成功した実つまみのドラッグと、行除外・学校通知で用いている0.33秒の時刻付き移動を照合した。先頭3回は既存の時刻付き移動で同じ実つまみを一回スライドする。再起動後の元のドラッグと、45秒・UI・保存・再起動の各検査を維持する。静止タップ用の候補経路を取り除き、製品および他のテストのスイッチ操作は同一。
- [同試行のiOS 26](https://github.com/n624-dev/takupoke-ios/actions/runs/45382618904/job/138405259099)はSDK 27.2／iOS 26.5。ビルド173.2秒と起動476.9秒の後、AI・OCRのUIと保存値が4回とも変わった。通常時間割詳細から戻り、時間割変更詳細を照会中の11:45:40 UTCに1440秒期限。続いてGitHubのジョブ上限で `cancelled` 終端。XCTestの結果は未完了。操作した側からの取消はない。

## N250 実つまみ移動の設定詳細でiOS 26がランナー期限（2026-11-24）

- source `b5377c08c6ad28b046674bd5d281f11a37f7c574`、[45386853188・試行1／iOS 26](https://github.com/n624-dev/takupoke-ios/actions/runs/45386853188/job/138419901052)、SDK 27.2／iOS 26.5。ビルド179.0秒、起動507.8秒、XCTest開始は12:07:44 UTC。時刻付きの3操作と再起動後の元の1操作で、表示と保存値がすべて変化した。12:11:34 UTC、学校行事から設定へ戻る途中に外側1440秒の期限が発火し、資料詳細までのケース完了は未確認。回収は完了、終了124。
- 同じ試行の [iOS 27](https://github.com/n624-dev/takupoke-ios/actions/runs/45386853188/job/138419901566)は同じ4操作、再起動後の保持、4種類の資料詳細を617.959秒で完了。実行identity、完了照合と回収も成功。N246でiOS 26の設定詳細全体に成功したときの起動150.4秒と、今回の507.8秒を照合した。iOS 26の追加実行は4操作の結果を確認できたが、ケース全体とジョブの成功判定には使用しない。

### N183-L1 — 2026-11-24 FileRefreshホスト検査の環境準備

- source: `4fdaaa5` からの未コミットMaterialFileReader差分。Debian13上のDocker `swift:6.1.2`（Ubuntu）。
- `bash tools/test-parsing.sh --filter FileRefreshTests` はビルド前に `python3: command not found`、exit127。テスト未実行。iOS／UI失敗ではない。
- 文書にある `/workspace/toolchains` はこの新規環境には存在しない。Swift公式イメージにはPythonが含まれない。Swift・検査条件を変更せず、検証用コンテナへPythonと既存パッケージに必要な開発依存を追加して再試行する。
- 同じ差分の次試行はPython準備後に依存cloneでTLS証明書検証エラー。テスト・コンパイル未到達。ホストに設定済みのCA bundleを検証コンテナへ渡して信頼連鎖を維持する。TLS検証は無効化しない。

### N183-L2 — #183 隔離パイプライン接続後のホストハーネス依存

2026-11-24、`dcae9bf` 上の未コミット隔離パイプライン差分、Swift6.1.2／Linux。`test_change_preview_actions.py` は8件中4件がSwiftハーネスのコンパイルで失敗。実行前の依存不足であり、期待する中止／保存結果の失敗ではない。抽出済みAcquisitionControl・FileOperationOutcome・モデルの既存callerへ追加したFilePipeline型とpipeline入口がハーネスに未登録（cannot find FilePipeline／no member pipeline）。N183-L1の環境準備失敗とは異なり、コンパイラは使用可能。期待値・既存シナリオを維持し、新しい境界をハーネスへ接続して再実行する。Foundation本体の最初のFileRefreshTests実行は成功しているが、その後追加したケースは次試行で確認する。

### N183-L3 — #183 ローカル増分ビルド中の入力変更

2026-11-24、`dcae9bf` 上の未コミット差分、Swift6.1.2／Linux。作業ツリーを直接参照した増分ホスト検査は、コンパイル中に主担当がSelectedFileSource.swiftを編集したため `input file ... was modified during the build` で停止。テストには未到達。N183-L2のハーネス依存は補完後に8件成功。次の増分検査は所有する固定コピーへソースを同期してから開始し、ビルド中はそのコピーを更新しない。既存の隔離実行スクリプトと同じ入力固定条件を維持する。
- N183-L2追補: 再試行・実行枠接続後の次試行では8件中2件がハーネス型検査で停止。追加した実行枠判定と解析成功通知の依存が不足している。既存の動作期待は維持し、不足したstubの型・関数だけを補う。

### N183-L4 — #183 全ホスト検査の保存日時比較

2026-11-24、`dcae9bf` 上の未コミット候補、Swift6.1.2／Linux。固定入力の全731件で2件が予期しないエラーにより失敗。限定FileRefreshTests29件は成功していたが、これを保存全体の成功に代用しない。全体ログの失敗ケース・保存段階を確認してから修正し、再実行する。並行してレビューで指摘された実行要求世代・バッチ取消・終了投影を補強中のため、この実行は後続補強の最終検証ではない。
- N183-L4の失敗は `LocalDatabaseTests.testSameDigestAutomaticRefreshReusesOriginalAndPersistsUpdatedModificationDate` と `ParsingTests.testOldRowSkipDecisionSurvivesSQLiteUpgradeAndCurrentRevalidation`。保存後のcurrentSnapshot照合で追加したlastAcquiredAtを可変メタデータとして正規化していなかった。Current側だけでなくSnapshot側の不変原本比較へ同じ正規化を追加し、原本識別・内容・解析版の検査は維持する。

### N183-L5 — 更新待ちの確定文言と既存期待

2026-11-24、固定入力の全734件で失敗2件。N183-L4のSQLite保存2件は修正後成功。残る失敗はSchoolEventsSourceStatusTestsの2ケースが旧文言「確認待ち」を期待しているためで、利用者確認済みの「更新待ち・配信元の対応・再取得では解消しない」へ変更した表示との差。差異判定・警告・旧正常結果保持の期待は緩和せず、新しい責任分担を表す文言へ更新する。APIの最初の型検査は追加functional-status.tsのnullable observation絞り込み4箇所で停止し、ランタイム未到達。既存validObservationの型述語を明示して補う。
- N183-L2追補: 行確認・プレビューも隔離処理へ接続した次試行は、9件中2件のハーネスでWorker.pipelineとTicketの依存が不足し型検査停止。バッチ取消と子期限の分離ケースは成功。該当する限定stubを補い、既存の却下・保存失敗・プレビュー保持の期待は維持する。

### N183-L6 — Linuxの作業領域不足

`codex/issue-183-pipeline` の保存境界・公開状態の作業差分をLinux x86_64／Swift 6.1.2で検証中、コンパイル・テスト用出力の生成で `other(28)` が発生した。Windowsの対象テストでもテスト用ファイルの配置前に `No space left on device`。共有ディスクの空きは0で、どちらも対象テストは未実行。作業中に作成した依存の重複キャッシュを解放し、テスト条件は変えずに再実行する。変更前の固定入力ではSwift 736件が成功した。

### N183-L7 — PDF照合の互換性とLinuxの抽出テスト

`codex/issue-183-pipeline` のLinux／Swift 6.1.2固定入力で、既存APIの応答を維持する変更後にも `sourceUrl` の検証参照が残り、コンパイルで停止した。APIの全検証で既存契約に追加キーがないことも検査しており、既存応答の変更を取り消す。Python抽出テストは製品側の保存済み原本の存在確認を模擬するURLに `path` がなく、1件がコンパイルで停止した。製品側で原本の存在確認をストアに集約し、抽出テストは既存原本ありを表す境界だけ補う。実際の欠落ファイルの検証はSwiftのファイル・ストア試験で行う。

### N183-CI1 — iOS 26のファイル詳細が限定ランナーの上限に到達

- 対象: `0d688d8`、[45429156784・試行1のiOS 26ファイル詳細](https://github.com/n624-dev/takupoke-ios/actions/runs/45429156784/job/138569323385)。Xcode／SDK 27.2、iOS 26.5、`testSettingsAccountDataAndFileDetails`。
- アプリとテストのビルドに成功。iOS 26シミュレーターの起動区間は367.3秒。画面テストは16:06:38 UTCに開始し、16:13:09 UTCに試験返却時間割のナビゲーションバーまで到達。テストの完了前に16:13:34 UTCに外側の1440秒期限が発火した。片付けまで完了し、個別のアサーション失敗は観測されていない。
- `1440秒|file-details|status-settings-screen|cleanup-enter` でN246・N250付近の既存記録を照合。今回のiOS 27の同ケースは成功、iOS 26の設定一覧も成功。期限・操作・完了照合を変更していない。ファイル詳細の限定失敗は成功に扱わず、[最終コードの別枠の全体CI](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714) のiOS 26操作結果を確認する。

### N183-CI2 — iOS 26手動訂正のアクセシビリティ照会

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408225)、Xcode／SDK 27.2・iOS 26.5、`testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`。
- ビルド191.4秒、Simulator起動444.1秒。テスト開始は16:37:27 UTC。235.205秒で `ManualAssistanceChecks+Navigation.swift:52` のUI照会が `Timed out while evaluating UI query` となった。終了コード65。全体の2400秒期限とは別の失敗で、当該ケースの訂正保持と再起動までは完了していない。
- 設定タブの一度の接触と解放がアプリまで届き、`manual-settings-list` の照会後、16:38:22に設定のナビゲーションバーの取得を開始した時点で停止した。訂正入力には未到達。
- `manual-settings-list|Timed out while evaluating UI query|ManualAssistanceChecks+Navigation.swift:52` で #125正式527試行1とN213を照合。先行例ではList列挙、今回は直後のBar列挙で停止した。対象のナビゲーション補助と設定画面は先行ブランチから変更なし。同じ試行でiOS 26の原本変更とiOS 27の2つの手動ケースは成功。原因の断定やテスト変更は行わず、全ジョブ終端を確認して同じコミットの失敗ジョブを再確認する。

### N183-CI3 — iOS 27通常UI Aの3件

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587407971)、Xcode／SDK 27.2・iOS 27.0、UI A。ビルド124秒、Simulator起動175秒。XCTest実行中の次の3件が失敗し、後続ケースは継続した。
- `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch` は16:35:38 UTC、465.900秒。 `ApplicationChecks+Navigation.swift:237` で対象要素が表示領域外のまま。
- `testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration` は16:37:12 UTC、65.110秒。`ApplicationChecks+Notifications.swift:195` の存在確認で失敗。
- `testFirstFailedSpecialDocumentsWarnOnHomeAndWeekAndOpenTheirDetails` は16:49:33 UTC、28.030秒。`ApplicationChecks+Timetable.swift:39` の期待が成立しなかった。該当画面の分岐とログを照合する。
- 変更のケースは再起動と「103行」の確認へ進む過程の詳細で、表示範囲はページ先頭（状態とファイル情報の行が可視）。未生成の「内容を確認・修正」に方向指定で先頭へ戻る操作が続いた。各呼び出しが詳細の新規表示直後なのを確認し、ファイル情報より後ろを探す。包含と実タップ、選択・確認・再起動の検査は維持。
- 試験のケースはホーム・週の初回失敗警告と、試験詳細へ実タップ・遷移まで成功。「保存済みのPDFを見る」は状態・ファイル情報より後ろの行なので、画面内へ出して利用可能かを確認する。解析ボタンも対象のナビゲーションバー内で確認する。
- カウントダウンはアプリが通知の取消を確認できなかった旨を表示。#134の同観測と照合し、今回の変更に通知取消処理の差がないことを確認した。通知取消の成功条件は維持する。
- 操作行の2件は限定 `material-detail-navigation` の個別ジョブで実際の操作を再確認する。変更行は既存の `rows` と同じ時間枠・診断条件で実行する。

### N183-CI4 — iOS 27通常UI Bの2件

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408466)、Xcode／SDK 27.2・iOS 27.0、UI B。アプリのビルド・起動と前段の週移動1件は成功。
- before-settingsで `testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent` が16:50:40 UTC、209.985秒、Navigation.swift:237で表示領域外。 `testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch` が17:00:00 UTC、75.430秒、WeekAppearance.swift:111で選択タブ文字の画素数0（期待は50超）。8件中6件成功。後段は未実行。
- カレンダーのケースは設定へ本物のタップで遷移し、取得・保存後の「元PDFの確認、更新待ち」と新しい説明をAXログで確認した。N183-L5と同じ旧文言がUIテストに残っていたため、設定・ホーム・時間割に共通の新しい説明を照合し、設定の状態名は「更新待ち」を別途照合する。限定 `material-detail-navigation` の `countdown-calendar` で既存の保持と訂正後の予定の参照も確認する。
- `dark readable lettering|WeekAppearance.swift:111|YELLOW_TAB|tint|黄色|タブ` で索引を検索し、#125の44994268172と44996077866で同じSDK・標準ライトの設定タブ文字が暗色だったことを照合した。今回の合成fixture実画面 `yellow-tab-settings-standard` では設定タブのアイコンが黄色、文字が青。黄色設定行のグリフは1104画素、タブの黄色グリフ検査も通過した。この描画の原因は未確定。配色実装・画像による閾値は先行ブランチから変更していないため、成功条件を保って同条件の結果を再確認する。

### N183-CI5 — iPhoneビルドのPicker事前検査で取得依存が不足

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408191)、Xcode／SDK 27.2・iOS 27.0。17:22:25 UTC、独立したPickerテストアプリのビルドで `ScopedMaterialSelection.swift` に追加された `SelectedFileProviding`、`SchoolDataPeriod`、`FilePipeline` が解決できず、終了65。Picker操作と実iPhoneビルドには未到達。
- `Picker UI|ScopedMaterialSelection|cannot find.*in scope` でN68・45248143697と照合。既往の主アプリ／資料テストの未登録とは別で、今回は選択権限だけを使う独立Pickerターゲットへ取得制御が入った。取得制御を同じアプリのProvider実装へそのまま移し、もとの選択権限の取得・保持とPickerの実ソース構成を維持する。取得制御を抽出するテストの参照先を合わせ、Pickerが必要な依存だけで選択権限のソースを型検査できる回帰を追加する。

### N183-CI6 — iOS 26通常UI Aでジョブが取消

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408040)、Xcode／SDK 27.2・iOS 26.5。生成アプリのビルド後、17:04:28 UTCに最初の補助資料のケースを開始。17:20:07 UTCに実行結果を出さずGitHub側で取消。担当からの取消操作はなく、他のジョブは継続。
- `cancelled|1440秒|iOS 26` でN183-CI1、N249と比較。今回は通常Aの完了が確認できず、限定のファイル詳細や個々のアサーション結果とは区別する。通常Aの時間枠と検査条件を維持する。

### N183-CI7 — Picker修正のCIがテスト一覧で停止

- `e6ec654` の [全体CI 45448486960](https://github.com/n624-dev/takupoke-ios/actions/runs/45448486960/job/138638727077) は17:26:01 UTC、LinuxのDistribution testsで `Stale test catalogue; run write: docs/test-catalog/app-ui.md`。生成済み一覧が作業ツリーにあり、実行コミットへの追加が抜けていた。N183-CI5のPickerコンパイルより前に停止し、Appleジョブは未実行。
- `Stale test catalogue|app-ui.md` を索引と開発手順で確認し、生成結果を `2de565b` で追加。コミット後のclean tree上で `test_catalog.py check` 成功。Pickerの新テストは修正前のソースに対して同じ依存不足を再現し、修正後は関連2件と取得制御9件が成功。検査設定と製品コードを維持して再度実行する。

### N183-CI8 — iOS 26通常UI Bにも旧文言と配色の失敗

- 対象: `033c479`、[全体CI 45433219714・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408329)、Xcode／SDK 27.2・iOS 26.5。先行する週移動は50.812秒で成功。続くbefore-settingsは8件中6件成功。
- `testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent` は17:31:21 UTC、160.559秒、Navigation.swift:237。 `testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch` は17:38:57 UTC、78.378秒、WeekAppearance.swift:111、選択タブ文字の画素数0。検索語と比較はN183-CI4に記録済みで、iOS 27と停止段階が共通。旧文言は修正済み。配色の判定は維持し、[両OSの配色限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45447828888) と修正後の全体CIで確認する。
- 最初の全体CIは17:47:32 UTCに全ジョブ終端。非配布の検証は9件成功、5件失敗、1件取消。公開ジョブはスキップ。[資料詳細の修正後のiOS 27限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45446409831/job/138631295490) は同じ実操作が95.068秒で成功 (Xcode／SDK27.2・iOS27.0)。限定の成功は既存の全体結果を上書きしない。

### N183-CI9 — 黄色の選択時にタブ文字だけが青になる

- 対象: `00cefd1`、[配色限定45447828888](https://github.com/n624-dev/takupoke-ios/actions/runs/45447828888)、SDK 27.2。iOS 26.5で96.258秒、iOS 27.0で94.563秒。両OSとも設定の黄色グリフは1105／1104画素、選択タブの文字は暗色0画素で停止した。前段の週移動やカレンダー検査から独立させてもN183-CI4／CI8と同じ条件で失敗した。Nativeロジックは成功。
- `タブ名tint|tintColorDidChange|yellow-tab-settings-standard` で #125の先例と現在の公開APIを比較。元の実装は選択・ウィンドウが変わって見つけ直したときだけ標準バーに色を設定しており、現在のバーの色が戻った後のレイアウトでは再適用しない。原因はまだ確定していない。既存のタブバーに限定して、継承tint変更とレイアウト時に異なる色を再確認する候補を検証する。ページ色、標準背景とアイコン、標準・高コントラストの確認値、操作・待機・実画素条件を維持する。

### N183-CI10 — 時間割変更の再起動後に操作行を逆方向へ探す

- 対象: `a1ca3f4`、[限定45446409831・変更行](https://github.com/n624-dev/takupoke-ios/actions/runs/45446409831/job/138631296060)、SDK 27.2・iOS 27.0。18:02:19 UTC、281.329秒、Navigation.swift:237。「内容を確認・修正」を最初は実タップし、選択・確認、103行の除外、再起動前後のC保持とB除外を確認した。
- `RETAINED_CHANGE|change-skipped-count|内容を確認・修正` でN183-CI3、旧#124と比較。その後は保持を確認した行のあるページ下方から操作へ戻る必要があったが、新規表示用と同じ下向き検索を繰り返した。操作位置が最初と同じという前提が誤っていた。保存済みの行を読んだ直後だけ先頭側を探し、新規で開いた2回は後方を探す。実タップ前に行の有効性・操作可能を明示確認し、再起動・確認ダイアログ・保存の期待値は維持する。

### N183-CI11 — 配色候補の観測とiOS 26の週移動描画

- [配色候補 `8e7b3c2` の限定45455234867・iOS 27](https://github.com/n624-dev/takupoke-ios/actions/runs/45455234867/job/138662772564)、SDK 27.2／iOS 27.0。18:14:46 UTC、92.504秒でN183-CI9と同じ文字画素0。レイアウトと継承tint変更から再適用する候補だけでは解消しなかった。元の描画コードへ戻し、合成fixtureで対象バーの探索、色の設定、設定直後と次の描画後の色を固定イベントとして測る。暗色・コントラスト・日付の検査は維持する。
- 同じ候補の [iOS 26](https://github.com/n624-dev/takupoke-ios/actions/runs/45455234867/job/138662772814) も18:22:42 UTC、129.149秒で同じ文字画素0。Nativeは成功。元の描画コードと合成fixtureだけの測定を使う [iOS 27の切り分け](https://github.com/n624-dev/takupoke-ios/actions/runs/45458686064) は `f3cc00c` で開始した。
- [Picker修正後の全体CIのiOS 26 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45448844241/job/138643805088)、`cd7bb15`、SDK 27.2／iOS 26.5。18:16:04 UTC、週移動の先頭ケース49.288秒。最初の到着後の描画間隔133.182msが既存90msを越えた。 `Height adjustment must keep drawing frames|0.09` で #125と比較し、[直前試行](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408329) の同じiOS 26と週描画コードで当該ケースが成功していることを確認した。後段の通常UIは未実行。描画条件と操作は変更しない。

### N183-CI12 — 再実行のiOS 27の週移動と手動訂正

- `cd7bb15`、[iOS 27 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45448844241/job/138643805148)、Xcode／SDK 27.2、iOS 27.0。18:39:59 UTC、週移動の先頭ケース49.745秒で描画間隔99.555ms、既存条件90msを超えた。N183-CI11の26と同じ検査。[直前の27実行](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408466) では先頭ケースが成功。後段は未実行。
- [iOS 27手動訂正](https://github.com/n624-dev/takupoke-ios/actions/runs/45448844241/job/138643805225) は18:36:33 UTC、625.635秒、`ManualAssistanceChecks+Navigation.swift:107` で `manual-ack-cell-1-0:0:room` の実ボタンを確認できなかった。N183-CI2の26は設定の階層照会で停止し、今回は訂正画面の別段階。 `Could not observe the current native Button|manual-ack-cell` で関連記録を照合。 [直前の同じ27ケース](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408558) は成功しており、当該アプリの機能・テストは同じ。照会が止まった原因は確定していない。週移動、訂正とも合格条件を維持する。

### N183-CI13 — タブバーの色と文字の描画を切り分け

- [iOS 27の計測45458686064](https://github.com/n624-dev/takupoke-ios/actions/runs/45458686064/job/138674995814)、`f3cc00c`、SDK27.2／iOS27.0。19:17:42 UTC、一つの実タブバーを発見し、期待する `tintColor` を設定。設定直後と約0.28秒後の両方で一致。その後最初の標準ライトの設定タブ文字検査が文字画素0で失敗（98.910秒）。後続の上書き有無は未確認。
- `tab-tint-kept|tintColor|選択タブ` でN183-CI9／11、#125の日付tintの回帰を照合。標準バーの色設定だけで現在の文字を検証できないため、候補は現行バーの選択項目の文字にUIKitの公開APIで直接指定する。文字色を設定した項目から移る場合、変更した色だけを復元する。ツールによる計測を整理し、製品のページtint・アイコン・背景、撮影と既存の暗色・コントラスト条件を維持する。
- [`c0cec6c` のiOS 27変更行](https://github.com/n624-dev/takupoke-ios/actions/runs/45456001287/job/138665483283) は415.945秒で全工程成功。初回の除外と反映、再起動後の保持、保存済み行の編集・再保存、最後の再起動後の保持を確認。

### N183-CI14 — 配色の設定とiOS 26の限定ランナー期限

- `4c0b54e`、[配色候補45469907539のiOS 27](https://github.com/n624-dev/takupoke-ios/actions/runs/45469907539/job/138714747891) は225.092秒で成功。SDK 27.2／iOS 27.0。設定／時間割の文字コントラストは標準8.98／9.06、高コントラスト16.61／16.91。黄色アイコン、日付ボタン、週の選択、他色と再起動後の保持も確認した。
- [同iOS 26](https://github.com/n624-dev/takupoke-ios/actions/runs/45469907539/job/138714747373) はSDK 27.2／iOS 26.5。起動・XCTest準備後の実ケース開始は19:46:30 UTC。N183-CI9で失敗した標準ライトの設定・時間割は9.04／9.04で成功。19:52:33に外側の1440秒期限、終了124。アサーション失敗は観測せず、高コントラストとケース全体は未完了。
- `yellow-contrast|1440秒|Focused relaunch runner` でN183-CI1／N248と照合。SDK・Runtime・検証条件・ケースは維持し、iOS 26のこの限定だけ、外側を既存の長い変更行検査と同じジョブ45分・ランナー2400秒にする。実操作や個々の待機・実画素基準と全体CIの設定は維持する。
- 先行UI `4fdaaa5` の [iOS 27の比較](https://github.com/n624-dev/takupoke-ios/actions/runs/45470806794/job/138717950851) は19:41:28 UTC、98.411秒で、標準表示の同じ選択タブ文字が0画素。今の取得・解析パイプラインの追加前でも同じ現象が起きることを確認した。

### N183-CI15 — 統合版のiOS 26週移動と訂正ランナー

- `369c6c8`、[iOS 26 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562074)、SDK 27.2／iOS 26.5。20:25:59 UTC、週移動の先頭ケース51.964秒。描画間隔115.954ms、条件90ms。 `Height adjustment must keep drawing frames|0.09` でN183-CI11／12と #125の同じ検査を比較。後段は未実行。週移動の実装、操作・描画条件は変えていない。
- [iOS 26の手動単項目訂正](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562187) はビルド162.2秒、シミュレーター起動321.1秒の後、20:21:20 UTCにXCTestがテスト開始準備中のRunner終了を報告、exit65。訂正操作・採用は未実行。 `Test crashed with signal kill|before.*test` で過去の準備停止を照合し、N183-CI2／12の画面内AX照会失敗と区別する。同じ単項目ケースの[前の成功](https://github.com/n624-dev/takupoke-ios/actions/runs/45433219714/job/138587408479)は記録済み。今回の終了原因は確定していない。

### N183-CI16 — 統合版のiOS 26通知専用テストで設定行の照会

- `369c6c8`、[iOS 26 UI A](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562114)、SDK 27.2／iOS 26.5。通常24件は2658.795秒、失敗0。変更行の保存・再起動と、試験・返却資料の詳細も成功。
- 続く通知専用の `testChangedDataProducesOneLocalNotification` は21:15:19 UTC、56.729秒、`ApplicationChecks+Notifications.swift:249` の存在待ちで失敗。AXは設定冒頭、AI・OCRの末尾までしか表示していなかった。 `testChangedDataProducesOneLocalNotification|Notifications.swift:249|NOTIFICATION_ROW` でN48/U75と旧44259503653を照合。以前の実接触取消と違い、今回は行の表示前に存在を待ち、行への接触・許可・通知配信には未到達。
- 既存の可視化を最初に行い、その後の存在確認・有効性・枠内のラベルへの一度の接触を維持する。実通知許可・ファイル更新・配信1件の検証に変更はない。製品コードの差分はない。

### N183-CI17 — 通知の限定再検証と手動訂正の期限

- [iOS 26の通知限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45491201397/job/138789692431) は `8a0a0fc`、SDK27.2／iOS26.5、98.483秒で成功。実設定を開く・許可・更新通知1件の一連のケース。N183-CI16で止まった行の操作も到達した。
- [iOS 27の同限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45491201397/job/138789692815) は同source、SDK27.2／iOS27.0、134.558秒。通知行の表示と実操作は成功。OS許可要求の開始／戻りは21:38:56 UTC、許可の完了を観測できず21:39:54にNotifications.swift:336で停止。 `notification-auth-request|notification-auth-returned|Native notification switch activation did not complete` で43767607953と比較し、同じ待機中状態で止まることを確認した。ケースの許可・配信条件を維持した。ホストの通知関連12件は成功。
- [統合版のiOS 26選択訂正](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562469)、`369c6c8`。21:35:24 UTCに最後の再起動で画面準備が成立したが、21:35:31 UTCに外側2400秒期限。個別アサーション失敗は観測していない。起動に445.5秒を要した。N183-CI2のAX timeout、N183-CI15の準備中終了とは別段階で、前回の同ケース成功は [再実行](https://github.com/n624-dev/takupoke-ios/actions/runs/45448844241/job/138643805657) に記録した。

### N183-CI18 — 統合版のiOS 27通常UIと曜日除外

- `369c6c8`、[iOS 27 UI A](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562025)。通常UIの実行中にGitHubのホストランナーとの通信が切れ、当該ステップは取消、ジョブは失敗。ログ保存先に対象blobがなく、最後の個別ケースの到達点は確認不能。実行側からの取消はない。
- [iOS 27 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382/job/138737562377) は週移動、学校行事、標準・高コントラスト配色、設定と4資料詳細、Dynamic Typeなどが成功。21:48:32 UTC、`testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups` が83.660秒、Navigation.swift:237で停止。初期と再起動後の「同じファイルを再取得」はどちらも詳細を開いた直後に使うが、行がまだAXにないときにページ先頭側を探し続けた。
- `testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups|同じファイルを再取得|material-actions-section` でN183-CI3／10と変更詳細の行順を照合した。AXはページ上部に留まり、操作見出しはy711、再取得はさらに後ろ。新規表示から下へ探す。実タップ・再取得完了、45行／90行、確認／取消・再起動を含む元の条件は維持。製品の差分はない。
- [統合版の全体CI](https://github.com/n624-dev/takupoke-ios/actions/runs/45475328382) は11月25日07:01 JSTに終端。検証15ジョブは成功9・失敗6。公開はスキップ。

### N183-CI19 — 両OSの通知フェーズで再起動後の配色行を確認できない

- `40a4c5a`、[全体CI 45503335049 試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/attempts/1)、SDK27.2。[iOS 27.0 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/job/138835177075) は2026-11-24 23:45:03 UTC、85.363秒、[iOS 26.5 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/job/138835177257) は同日23:56:35 UTC、130.973秒。`testNotificationControlsAndAppearance` の `ApplicationChecks+Notifications.swift:385` で再起動後の「メインカラー、緑」の実ボタン照会が失敗した。両方で変更通知と試験・返却通知の許可応答、緑・外部ブラウザの選択、終了、再起動、fixture-ready、設定タブの実選択、設定バーの表示までは観測済み。その直後にボタンの存在を一度照会して停止した。再起動後の永続値・外部ブラウザの行、既定色と青の再起動確認には未到達。
- 両UI Bで週移動、設定と資料詳細、曜日除外の引き継ぎ、文字サイズ、個人予定の実通知予約は成功。両UI Aでファイル更新の実通知1件、両OSの手動訂正計8件、Apple Native 858件（既定skip1）と非配布のiPhoneビルドも成功。検証15ジョブは13成功・2失敗、公開はスキップ。
- `ApplicationChecks+Notifications.swift:385|testNotificationControlsAndAppearance|メインカラー.*再起動` でN122、N183-CI16〜18、現行設定の「アプリ設定」内の行順を照合。N122は青の保存未観測、CI17は許可callback未観測で、今回は緑の選択・許可応答の後に設定先頭から即時照会した。通知行より後ろの配色とリンクを、再起動後すぐに複合ラベルで探していた。候補は設定画面を開いた直後の配色行とリンク行を、既存の可視化操作でそれぞれ表示してから、その実ラベルの選択値を調べる。リンクの後で配色へ戻る場合は前の行を探す。緑・既定・青の実選択、実保存観測、3回の再起動、外部ブラウザ・通知許可の旧条件を維持する。製品に差分なし。

### N183-CI20 — 設定の限定検証でiOS 27の通知許可応答を確認できない

- `697777a`、[限定45523762015 試行1、iOS 27.0](https://github.com/n624-dev/takupoke-ios/actions/runs/45523762015/job/138901879736)、SDK27.2。生成・ビルド・起動と通知行の実操作は成功。2026-11-25 01:20:54 UTCに実スイッチから `notification-auth-request` と `notification-auth-returned` を観測した。許可UIへの実Allowとcallbackは観測できず、01:21:43に `testNotificationControlsAndAppearance` の元の許可判定（Notifications.swift:336）で停止。113.143秒。修正した配色・ブラウザの再起動経路はこのジョブで未到達。通知サービス内部の原因は未確定。
- `notification-auth-returned|permission and enablement|Notifications.swift:336` でN183-CI17、43767607953、45243562141と比較した。単独または短い先行ケースでも実許可の返却を確認できない場合がある。[修正前の全体27 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/job/138835177075) は同一SDK・同一OS、同じ通知実装で2種類の許可返却を確認し、再起動後の設定行まで進んだ。27の正式構成では通常画面、文字サイズ、VoiceOverの後、同じ所有Simulatorで通知専用フェーズへ入る。同じ単独条件を繰り返さず、通常シナリオを先に通る全体CIで修正後の到達を確認する。OS許可の要求・待機・実操作・条件は維持する。
- [同iOS 26.5限定](https://github.com/n624-dev/takupoke-ios/actions/runs/45523762015/job/138901879186) は223.792秒で成功。起動ごとに最初の配色行が未生成で、既存スクロール後に見つかった。2種類の実許可、緑・外部ブラウザ、既定・青の再起動後の表示と実保存まで到達。これを根拠に設定の可視化のみを変更し、全体の合格条件に変更を加えない。

### N183-CI21 — iOS 26の明示選択訂正で消去後のUI照会が時間切れ

- `71ec2dd`、[全体45527221520 試行1のiOS 26.5明示選択訂正](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138915387966)、SDK27.2。実起動、1欄目の消去・入力後、2026-11-25 02:05:11 UTCに2欄目の教員の消去が配送され、`manual-binding-clear` と編集開始、キーボード表示を観測。直後の `manual-value-cell-1-0:0:teacher` のAX列挙が約60秒返らず、02:06:25に `ManualAssistanceChecks+Input.swift:78` でXCTestが失敗を報告（ケース423.926秒、exit65）。個別の空欄確認、2欄目の入力以後は未到達。外側の2400秒期限には達していない。
- `Input.swift:78|manual-binding-clear|Timed out while evaluating UI query` でN52、正式526試行1/2（44997934998）と照合。526のiOS 26単項目では同じ照会が科目消去後に停止し、後の同条件の実行では完走した。今回と[前回成功の同一iOS 26明示選択ケース](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/job/138835177411) の製品、入力テスト、SDK、Runtimeに差はない。今回も消去と実キーボード表示までは成立しているが、AX応答遅延の下位原因は未確定。全ジョブ終端後、同一ソースの失敗分を新しいRunnerで一度比較する根拠とする。空欄の見え方、実入力・承認、保存・再起動と期限を維持する。

### N183-CI22 — iOS 26の週送りで高さ調整初期の描画間隔が再発

- `71ec2dd`、[全体45527221520 試行1のiOS 26.5 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138915388058)、SDK27.2。先頭 `testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` で、2026-11-25 02:23:52 UTCに横到着後の次枠まで116.517ms、条件90msを超過（WeekAppearance.swift:466、ケース31.668秒）。到着0.281091秒、次の実枠0.397608秒、直前サンプルからのmain CPU増加108.285ms。昇格からスクロール復帰まで約0.99ms、最初の配置設定は到着後30.63ms・設定0.11ms。28枠、幾何欠落0。先頭で止まり、配色修正と他の通常B検査はこのジョブで未到達。製品、週操作、測定条件に差分なし。
- `Height adjustment must keep drawing frames|0.09` でN183-CI11／12、CI15、N183-CI19の同OS成功と比較。[40a4c5aのiOS 26 B](https://github.com/n624-dev/takupoke-ios/actions/runs/45503335049/job/138835177257) は同じ製品・実操作・判定で週移動を通過。変更は後段の通知テストの再起動後の行表示だけ。到着後のCPU処理の内訳は今回も未確定であり、外部要因と断定できない。通常26 Bは後段が一切実行されていないため、最新ソースの後段を確認する目的で、他ジョブ終端後に既存90msを保った新しいRunnerで一度比較する。

### N183-CI23 — iOS 26 UI B再実行でXcodeが起動済み端末を列挙できない

- `71ec2dd`、[全体45527221520 試行2のiOS 26.5 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138956018583)、SDK27.2。ビルド109.2秒、端末起動104.8秒、`simulator-ready` 後の `test-without-building` で、2026-11-25 03:39:44 UTCに `Unable to find a device matching the provided destination specifier`。対象端末IDをXcodeが候補に出さず、XCTestは開始せず、アプリのイベント0。失敗後の同端末のsimctl照会は `runtime=available, device=Booted`、所有端末の清掃成功。週送りの動作計測自体は未到達であり、N183-CI22と停止段階が異なる。Xcodeとsimctlの列挙の差が生じた下位原因は未確定。
- `Unable to find a device matching|destination specifier|bootstatus|exit 70` でN127（40051510584）・43769812600・正式528（45112946241）を比較。N127は同じ通常26 Bでbootstatus後に実行先の列挙が失敗し、新しいRunnerで元の全操作が完走した。正式528の同段階は別の手動ケース。今回もビルドと起動後の実行先解決で、N183-CI22の描画間隔は測定されていない。作業ブランチ前回の通常26 Bは同じ作成・起動・実ID指定で実テストに到達済み。ハードウェア、合格基準、SDK、実行先の指定や準備順は維持し、試行2の全終端後、同じ実行の残存失敗を新しいRunnerで一度確認する根拠とする。

### N183-CI24 — iOS 26通常Bの変更通知Switchに実接触は届くが値が変わらない

- `71ec2dd`、[全体45527221520 試行3のiOS 26.5 UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138969495025)、SDK27.2。週送り（48.333秒）、設定と資料詳細、曜日除外、既存の文字・配色まで成功。通知フェーズの `testNotificationControlsAndAppearance` は設定行とOFFを確認し、2026-11-25 05:14:38 UTCに実Switchの25%位置で短い静止接触の開始・解放がUIKitへ到達。値は0、`requesting=false`・保存falseのままで、アプリのBinding変更・OS許可要求は観測なし。`ApplicationChecks+Notifications.swift:336` に05:15:29、ケース122.946秒で停止。後続の個人予定実通知は許可と予約を確認して成功（143.165秒）。前の試行のXcode実行先の問題と、N183-CI20の許可を要求済みだが未応答の状態とも異なる。試行3は14成功・1失敗、公開スキップ。
- `short-contact-50ms|testNotificationControlsAndAppearance|Special notification switch|thumb-drag` でN239、N249、正式526試行3、正式530試行3と照合した。正式526は2個目の通知Switchの静止接触が取消、今回は最初の接触を通常終了しても値が変わらない。同じ試行で個人通知に使った既存の0.33秒の実つまみドラッグは実許可と保存・予約に到達。候補ではiOS 26の当該Bケースの2つのSwitchに、その既存実つまみドラッグを一回ずつ使う。iOS 27とUI Aの実短接触、実枠の一意性・包含・hittability、45秒/10秒、OSの実許可、保存と再起動、週送り判定は維持する。接触非反映の下位原因は未確定。iOS 26限定の同じケースで、実接触・値・許可・再起動を確認する。

### N183-CI25 — iOS 26の通知限定がXCTest開始前に取消

- `ea7531c`、[限定45553651442 試行1、iOS 26.5](https://github.com/n624-dev/takupoke-ios/actions/runs/45553651442/job/139000448658)、SDK27.2。初回依存解決のエラーからビルドを完了し、2026-11-25 05:38:18 UTCに所有端末の `simulator-ready` を記録。05:38:34にGitHubは `The operation was canceled` を報告。XCTestの開始、通知の接触、実値、許可、保存は全て未到達。05:41:32に取消で終端。作業側からの取消操作はなく、取消の発生理由は未確定。外側1440秒を迎える前。
- `The operation was canceled|simulator-ready|bootstatus` で正式490と正式44800663590の手動単項目を比較した。正式490はケース実行中、44800663590は起動準備中で同じGitHubメッセージにより終了し、当時も個別ケースの合格判定は行わなかった。今回は準備成功後かつXCTest開始前。対象ケースの実操作データが無いため、変更済みの同一コミット・SDK・実端末で新しいRunnerを一度比較する。期限、所有先、ケース、実許可と設定値の条件は維持する。

### N183-CI26 — iOS 27通常Aでカウントダウン確認のボタン照会が時間切れ

- `4a08a7a`、[全体45557966509 試行1のiOS 27.0 UI A](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139016457269)、SDK27.2。`testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration` は破損警告、通知取消、初期化アラートのキャンセルを通過。2026-11-25 06:42:58 UTCに2回目の「元のファイルを保全して初期化」の実接触を観測し、アラート存在は成立。子Button照会の応答に時間を要し、元の10秒条件で `ApplicationChecks+Notifications.swift:173` の「初期化」操作可判定が失敗（06:43:49、ケース217.903秒）。失敗時のAXツリーには同アラートと「初期化」「キャンセル」が存在する。確定操作は未送出。iOS 26 UI Aは同じケースを含み成功。AX照会遅延の下位原因は未確定。
- `Dialog button never became tappable|初期化|testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration` でN183-CI3と45050646373の両OS、[71ec2ddの成功したiOS 27 UI A](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138915387927) を比較。先行の失敗は通知取消後の完了文、または最初の確認ダイアログ不在。今回は2回目のアラートは出ており、子ボタン照会で停止。前の統合成功から製品・当該テスト・SDKに変更はなく、今回のiOS 26 UI Aも完走。全体の結果確定後、この実行の失敗分を一度別Runnerで比較する根拠とする。確定・取消・保全・新規登録の実操作、10秒の条件を維持する。

### N183-CI27 — iOS 26の3項目手動訂正がGitHubジョブの上限で取消

- `4a08a7a`、[全体45557966509 試行1のiOS 26.5手動3項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139016457314)、SDK27.2。GitHubのチェック注記は `The job has exceeded the maximum execution time of 45m0s`。ソース確認は成功、ケース実行ステップは失敗、所有Runtimeの回収ステップは結果未確定。2026-11-25 07:44:42 UTCに取消で終端した。単独ジョブログは取得時に `BlobNotFound`。具体的なケース到達点や内側2400秒の経過は、完了後の試行アーカイブを確認する。N183-CI25のジョブ上限に達する前の原因不明の取消とは区別する。
- 試行1の全終端後に取得した試行ZIPにも当該手動ジョブログはなかった。 `maximum execution time of 45m|BlobNotFound|manual-26` でN243、N183-CI17と[同じiOS 26手動3項目の成功](https://github.com/n624-dev/takupoke-ios/actions/runs/45527221520/job/138915387917)を照合した。N243の対処後と同じ準備込み2400秒・ジョブ45分で、今回は具体的な停止段階を判定できない。前回成功から手動用コード・条件は同じなので、新しいRunnerで一度比較し、元の成功条件と回収を維持する。

### N183-CI28 — iOS 26手動3項目の再実行でXcode起動要求が時間切れ

- `4a08a7a`、[全体45557966509 試行2のiOS 26.5手動3項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139062265471)、SDK27.2。ビルド124.2秒、所有Simulatorの起動493.0秒。2026-11-25 08:22:58 UTCに実プロセスのfixture-readyは観測したが、最初の `app.launch()` からXCTestに正常に返らず08:23:43に `ManualAssistanceChecks.swift:71` の `Timed out while launching application via Xcode`、ケース228.645秒、exit65。アプリの準備・起動APIの復帰を区別し、訂正操作は未実行。試行1のGitHubジョブ全体の期限とは別段階。
- `Timed out while launching application via Xcode|fixture-ready|ManualAssistanceChecks.swift:71` で正式503、44499001313、44660400847と比較。503／44660400847は初回のXcode起動返却、44499001313は採用後の再起動で停止。今回の最初の起動についても、生成アプリ準備成立とテスト起動API未返却をログで区別した。試行1の詳細が欠落しており、同じ停止だったとは判定できない。前の全体CIで同一製品・SDK・ケースが通った実績と、今回の訂正操作未到達を根拠に、全体の終端後に新しいRunnerで同一ケースを確認する。起動を成功とみなす条件、起動回数、実操作、回収は維持する。
- [試行3の同じケース](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139093060268) は同一ソースで実起動、3項目の確認、4項目目の拒否・採用・再起動と回収まで成功（375.270秒）。同じ試行の必須15件は全成功、公開はスキップ。試行1／2の停止と下位原因の不確定は記録として残す。

### N185-L1 — Linuxの通知・保存検証が進捗設定の型を認識できない

- `3adf386`、Linux・Swift 6.1.2。配布ゲートと同じPythonテスト一式のうち、実Swiftメソッドを境界のスタブと組み合わせる通知検証でコンパイルが停止した。起点日編集の型、私有スナップショットのAPI、復旧時のコールバックの型が旧スタブに不足した。既存の通知取消や半期処理の実行結果はこの試行では未確認。
- 本体のメソッド抽出と通知の照合条件を維持し、追加の型と保存・再計算境界をスタブに反映した。起点日の保存前に対象を再確認できない場合と別の試験に変わった場合の拒否、半期削除時の公開設定の保持も照合する。

### N185-CI1 — iOS 26の手動明示選択で入力後の完了ボタンを確認できない

- `0294c79`、[全体45714093730・試行1のiOS 26.5手動明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139557970143)、SDK 27.2、`testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`。2欄目で実消去、フォーカス、入力まで進み、2026-11-25 23:00:02 UTCに `ManualAssistanceChecks+Input.swift:126` で期限内の完了ボタンを確認できず、203.834秒で失敗。終了時のAXには背後の通常時間割のナビゲーションバーがあった。入力確定、採用、再起動は未確認。完了ボタンを確認できなかった原因は未確定。
- `manual-edit-done|keyboard-will-hide|text-edit-ended|N191|N183-CI21` を照合した。今回は待機開始時にキーボードが閉じて `text-edit-ended` が出ており、終了時AXには復旧バーも残った。N191と似た症状だがSDKが異なり、N183-CI21では消去後に止まっており入力に未到達。直前の全体CI 45557966509では同じiOS 26.5・SDK 27.2の[元ケースが成功](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139016457641)。入力テストと復旧画面に変更はなく、キーボードが閉じた理由は未確定。全ジョブの終端後、この実行の失敗分を新しいRunnerで比較する。操作と合格条件を維持する。

### N185-CI2 — iOS 27の手動明示選択で確認画面を期限内に照合できない

- `0294c79`、[全体45714093730・試行1のiOS 27.0手動明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139557970184)、SDK 27.2、`testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`。少なくとも科目・教員の入力と編集終了まで確認。2026-11-25 23:28:37 UTCに `ManualAssistanceChecks+Review.swift:45` で元の待機が時間切れとなり、535.490秒で失敗。原因は未確定。後続の採用と再起動は未確認。
- `Review.swift:45|manual-coordinator-state|review=true|高信頼` を照合した。最初の科目だけの確認状態は成立。後の失敗時AXにも科目＋教員の `review=true;preview=false` が出ていたが、20秒の元の待機では照会できなかった。[前回の全体CI](https://github.com/n624-dev/takupoke-ios/actions/runs/45557966509/job/139016457266) では同じSDK・OS、同じ復旧画面と手動テストで完走。N185-CI1とは失敗段階が異なる。全ジョブを待ち、同一ソース・同一条件で失敗分を比較する。

### N185-CI3 — iOS 27の手動1項目で確認画面を期限内に照合できない

- `0294c79`、[全体45714093730・試行1のiOS 27.0手動1項目](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139557970157)、SDK 27.2、`testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`。2026-11-25 23:48:15 UTCに `ManualAssistanceChecks+Review.swift:45` の待機が時間切れとなり、516.582秒で失敗。採用・再起動までは未確認。
- 同じケース内では確認画面の成立2回と背景復帰後の同一プロセス・確認状態の保持を観測。失敗直後のAXにも `review=true;preview=false` が出た。N185-CI2とは同じ待機だが、今回の停止は背景復帰後の再確認。両ケースを同一コード・同一期限で再検証する。

### N185-CI4 — iOS 27通常UI Bがジョブ時間の上限に到達

- `0294c79`、[全体45714093730・試行1のiOS 27.0通常UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139557970051)、SDK 27.2。2026-11-25 23:53:21 UTCにGitHub上で取消。チェック注記の理由は75分のジョブ上限。個別ログは取得時に拒否され、最後に到達したケースは未確認。手動取消は行っていない。

### N187-CI1 — 失敗時画面の実機構成テストが撮影前の起動で停止

- `bf7f27d`、[実シミュレーター撮影の専用検証45721609887](https://github.com/n624-dev/takupoke-ios/actions/runs/45721609887/job/139581068431)、SDK 27.2・iOS 27.0。専用ワークフローでsimctlの直接起動を行い、2026-11-25 23:54:27 UTCにbootstatusの期限到達。プロセスの回収中にOperation not permitted。画面の取得処理には未到達。
- `bootstatus|Operation not permitted|frontend` で通常iOS27の起動失敗と前回の限定成功を比較した。前回の[限定成功](https://github.com/n624-dev/takupoke-ios/actions/runs/45710773715/job/139544317881) は既存の起動ヘルパーを使用した。専用検証の直接起動を既存ヘルパーに揃え、実画面1枚・成功時0枚・PNGバイトの照合を維持する。全体CIの成否には合算しない。

### N187-CI2 — 失敗時画面の実シミュレーター検証で画像が取得できない

- `1ca28c0`、[撮影専用45726149220・試行1](https://github.com/n624-dev/takupoke-ios/actions/runs/45726149220/job/139596423999)、iOS 27.0・SDK 27.2。既存のGUI起動手順は完了。2026-11-26 00:08:19 UTCに `simctl io` による取得が失敗し、PNGを検証できなかった。N187-CI1と異なり、撮影まで到達した。個別コマンドの終了値・期限を次の試行で記録する。

### N187-CI3 — OCR研究ジョブが従来の製品スナップショット照合で停止

- `d42fbc8`、[OCR標準45726229873](https://github.com/n624-dev/takupoke-ios/actions/runs/45726229873) と [OCR ASCII 45726250089](https://github.com/n624-dev/takupoke-ios/actions/runs/45726250089)、両OSとも固定コミットとのアプリ差分照合で終了。ランタイム起動・撮影は未実行。固定コミットの製品部分を専用検証ブランチに復元し、既存の照合を保ったまま、同じ撮影コードを検証する。PR #186・#187の製品コードと検査条件は変えない。

### N187-CI4 — XCTestの失敗後に撮った画像をPNGログへ渡せない

- `20cb32e`、[撮影専用45727821587](https://github.com/n624-dev/takupoke-ios/actions/runs/45727821587/job/139602033193)、iOS 27.0・SDK 27.2。架空のホーム画面と起点日前の検査を通過し、指定の意図的なXCTest失敗を2026-11-26 00:29:18 UTCに確認。撮影コマンドは正常終了したが、00:29:23に画像が形式・容量の検査に通らず、PNGを復元できなかった。元データの形式と容量を切り分け、必要時だけApple標準の画像処理で1024px以下のPNGへ変換してから従来の検査を行う。

### N187-CI5 — ASCII OCRのiOS 27がiPhone 16向けの端末を作成できない

- `2d77717`、[固定スナップショットのASCII OCR 45727564438](https://github.com/n624-dev/takupoke-ios/actions/runs/45727564438/job/139601152463)。iOS 27の列挙でiPhone19,4専用のランタイムが選ばれ、iPhone 16の端末作成がexit147。起動や撮影には未到達。iOS 26は成功。[標準OCRの両OS](https://github.com/n624-dev/takupoke-ios/actions/runs/45727553482)も成功。ランタイム選択が汎用iOS 27の中で行われるよう両研究ランナーに共通の判定を使う。既存のSDK、固定製品、実プロセスの照合と推論の合格条件は維持する。

### N185-CI5 — iOS 26通常UI Bのメインカラーの選択肢を確認できない

- `0294c79`、[全体45714093730・試行1のiOS 26.5通常UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139557970148)、SDK 27.2。週送りと通常画面の区間は成功。2026-11-26 00:58:33 UTCに `testNotificationControlsAndAppearance` の `ApplicationChecks+Notifications.swift:379` でメインカラーの選択肢の実存在を確認できず失敗。通知と新しい進捗テストは通過。試行1のiOS 27では同じメインカラー操作が成功した。合格条件を保って全体試行2で照合する。
- N185-CI4の試行ZIPを確認。iOS 27通常UI Bでは通知2件と実文字サイズの先行2ケースが成功し、3ケース目の起動中にGitHubの上限へ到達した。元のケース・端末条件を維持して再検証する。

### N185-CI6 — iOS 26通常UI Bの再実行でAppleカタログ取得が失敗

- `0294c79`、[全体45714093730・試行2のiOS 26通常UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139622073331)。2026-11-26 01:09:50 UTCにApple MobileAssetのカタログ取得がネットワークエラーで失敗し、iOS 26.5（23F77）の取得コマンドが70を返した。SDK選択まで成功、実Runtimeの準備とXCTestは未実行。
- `MobileAssetError.Download|tryAgainLater|23F77` とN185-CI5を比較。試行1は同じRuntimeの準備と画面操作まで成立し停止箇所も異なる。試行2のほかのジョブが終了した後、同じSDKとRuntimeの要求を維持して再検証する。

### N185-CI7 — iOS 26手動明示選択の再実行で3項目目の保存状態を照会できない

- `0294c79`、[全体45714093730・試行2のiOS 26手動明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139622074047)、SDK 27.2・iOS 26.5。試行1の完了ボタン待機を通過し、2026-11-26 01:39:29 UTCに `ManualAssistanceChecks+Review.swift:148` で3件の一意な項目IDが確認できず失敗（544.086秒）。取得値は `nil, ambiguous=false`。採用と再起動まで未確認。
- `manual-field-ids|distinct field IDs|Review.swift:148` を照合した。試行1のiOS 26は入力、試行1のiOS 27は確認画面の照合で止まっており、今回は異なる段階。前回全体の同一OS・SDKでは実操作・採用・再起動を完了している。成功したiOS 27の試行2と同じ合格条件で、残件を再検証する。

### N185-CI8 — iOS 26手動明示選択の試行3でAppleカタログ取得が失敗

- `0294c79`、[全体45714093730・試行3のiOS 26手動明示選択](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139644912562)。2026-11-26 02:56:46 UTCにApple MobileAsset `tryAgainLater`、iOS 26.5（23F77）の取得が終了70。試行2のN185-CI6と同じ準備エラー。今回、手動訂正ケースは開始していない。ほかのジョブ終端後、同一SDK・Runtimeの要求を維持して照合する。

### N185-CI9 — iOS 26通常UI Bの試行3で週送りの描画が100ms空いた

- `0294c79`、[全体45714093730・試行3のiOS 26通常UI B](https://github.com/n624-dev/takupoke-ios/actions/runs/45714093730/job/139644913399)、SDK 27.2・iOS 26.5。2026-11-26 03:14:55 UTCに `ApplicationChecks+WeekAppearance.swift:466`、`testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable` が100.309msの描画間隔を観測し、元90ms条件で失敗。42.960秒。試行1はこのケースを通過し、試行2はRuntime取得前の失敗だった。N183-CI22の近接した描画間隔と照合し、元の合格条件を維持する。

### N187-CI6 — 全体のiOS 26通常UI Aで連続週送りの4接触が揃わない

- `99fa7e2`、[全体45736484307・試行1のiOS 26通常UI A](https://github.com/n624-dev/takupoke-ios/actions/runs/45736484307/job/139632621700)、SDK 27.2・iOS 26.5。2026-11-26 02:54:34 UTCに `ApplicationChecks+WeekAppearance.swift:274`、`testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating` が「4回のネイティブドラッグと最後の高さ調整」を確認できず28.005秒で失敗。同ジョブの残りのテストは進行し、全体では14件成功、公開はスキップ。XCTestで失敗時の画像が1枚記録され、129290バイトのPNGの出力を確認した。

## #212 架空の試験保存先の失敗を検査するSwiftプローブの型不一致（2026-11-27）

- 基点 `48a0a73` の作業差分、Swift 6.1.2 / Linux、ローカルの `test_last_special_store_failure_triggers_a_new_countdown_evaluation`。架空UIKit境界の `UIApplication` をcaseのないenumにしていたため、生成ソース30行で初期化できず、購読の再評価には未到達。
- 架空のアプリ状態を生成できるstructへ修正する。試験資料の失敗だけを最後に通知し、製品の購読・MainActor再評価が失敗を読み取る条件を維持する。

## #192 原本なしの通常資料の取得失敗がLinux回帰でinvalidState（2026-11-27）

- 基点 `48a0a73` の作業差分、Swift 6.1.2／SQLite 3.53.4／Linux、Actions・Simulator未使用。11:03:28 UTCに `testFirstRegularAcquisitionFailurePersistsWithoutAnOriginal` が `invalidState` で停止。テストからは初回DB作成・失敗記録・再読込のいずれが停止したか未確定。特別資料の初回失敗の記録・再読込のケースは成功。Swift 135件中失敗1件。
- `LocalMaterialDatabase.openLibrary` は先行所有者が保持する `LibraryLock` を `LOCK_EX` で取得できなければ `invalidState` を返す。初回テストは書き込み側を生存させたまま再読込していた。書き込み側を閉じてから再読込し、正常な排他制御と再起動時の永続化を両立する条件で再検証する。
- 修正後の同じ135件は失敗0。初回取得失敗、選択中止、排他を解放した後の再読込、4種類の失敗理由と未取得表示まで検証した。
