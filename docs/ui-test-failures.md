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
