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
