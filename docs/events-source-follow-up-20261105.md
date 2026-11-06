# 学校行事の元PDF確認結果の追従

利用者の報告は、確認中の案内が出たあと、学校行事の手動更新で登録元一致へ戻ること。
公開457.1/source f709367a84747a2216a419eb2f4723c7ca429a29とAPIの状態取得契約を照合した。
APIは24時間以上あいた最初の要求で非同期確認を予約して確認中を返す。iOSはその応答を
保存し、60秒後に文言を期限切れへ変えるが、確認完了の状態を取り直さなかった。
手動更新は行事の200/304確認後に状態APIも再取得するため、完了していれば一致へ戻る。
当該端末の通信ログは未取得であり、個別発生時のサーバー状態を確定したものではない。

利用者が承認した方針は、状態APIだけを60秒間隔・初回後に追加最大3回取得すること。
APIサーバー、学校PDFの取得間隔、行事本文取得・保存の契約は変更しない。
前面で確認中の一致した対象だけを追従し、完了/通信失敗/背景移行/保存対象の変更で止める。
年度・元PDFのhash・配信版が変わった待機とin-flight応答は採用しない。
同じ年度の同時要求は合流し、通常のcache確認や背景復帰で残り回数を増やさない。
明示的な手動取得は古い待機を置き換え、新しい確認として扱う。
保存済み行事・前回成功・時刻・別年度と時間割投影を、状態の取得だけで更新しない。

編集前にdevelopment-policy/roadmap/test-maintenance-policy/test-catalogを読み、
catalog search SchoolEventsModel/ApplicationDataで対応を確認した。
確認中/source-status/期限/再取得で失敗索引を検索し、N156のLinux型/時間切れ、
N157の通常行除外、N163の行事年度入力と旧/現実装を照合した。
今回UI操作/helper/期待/期限は変えず、状態Modelの所有待機と前景の接続を変更する。
既存の表示期限だけのテストを保持し、実Modelと全通信を捕捉する架空URLProtocolへ、
完了追従/合計4回上限/失敗時保持/背景中断/in-flight取消/対象変更/版ずれ/手動置換/
復帰時の残り予算を検証するApple Nativeケースを追加する。
実ApplicationDataの前景・背景メソッドを実行するLinux harnessも行事境界の通知を検証する。
学校URLへテスト通信せず、Apple CIと実機の確認範囲を区別する。検証結果は後記する。

初回ローカルはSwift6.1.2の構文解析、Python292件/失敗0（118.257秒、専用font環境2件の予定skip）、
catalog450/check --base f709367が成功。Apple専用のModel通信/待機はまだ実行していない。
専用code-only reviewで、activateのawait中の背景移行後にrefreshAtStartupが状態確認を再開しうる
競合の指摘があった。主担当が実activateの先頭/await/末尾guardを照合し、await後の背景判定を
追加し、そのguard後だけで行事の確認を有効化する。既存の前景/背景メソッドの実行検査に、
背景処理待機中/prepare中/初めから背景/前景成功を追加し、元の復旧draft保持の検査も維持する。
修正差分の再レビューと局所検査後にだけ専用Native比較を開始する。

競合修正後、実ApplicationData.activate/setFileMonitoringと元入力callbackを含むLinux実行4件は
失敗0（6.739秒）。背景への移行が二つのawaitのそれぞれで起きても確認を再開しないことと、
前景では確認を開始することを実メソッドで検証した。Swift構文とcatalog450も再確認する。
これはApple専用SchoolEventsModel/SwiftUIの実ビルド・新しい待機ケースの成功ではない。

修正後のmanifest30件/失敗0（18.245秒）も成功した。上限到達直後は確認完了未取得と未確認を
明示し、前回成功と日時を保持する表示対照も追加した。全Swift構文とcatalog450を確認。
次の既存Development workflow一回（native_pdf=true/sdk27=27.1/picker=false/inventory=false）
専用に新規GPT-6.1 Sol/High events_follow_up_native_pre_actions_reviewを作成した。
初回P2の修正と上限表示を含む最終code-only540行/30204bytes/SHA256
9eb11d1eb0195a152baf43c0c60981511bf892682dc89a74e4d39853d1103a93を全行確認し、最終指摘なし。
主担当が同一差分、元の全case/期限/公開条件、局所検査とApple未実行の範囲を照合してから使う。
このレビューは次の比較一回だけに消費し、正式main/公開前は別の新規レビューを行う。

Native比較61080e3/run42134413676を開始し、その間に別の新規main専用reviewを実施した。
main reviewでは、背景で60秒以上経過した後の通常確認が、cache鮮度内だけで参照していた
残り予算を見ず初期値3へ戻すP2を指摘した。主担当が初回/復帰/再取得の呼出しを照合し、
鮮度切れの確認中応答についても同じ対象の残り予算を保持し、復帰時GETも一回に数える。
同時要求は先に合流し、消費済みの予算では鮮度切れ後も自動取得を増やさない。
明示的手動更新は別の確認として既存仕様どおり許可する。実Modelの復帰対照を0秒/120秒で
比較し、いずれも合計4GETで止まることを要求する。先行比較の結果をこの追加修正や正式全15へ
合算しない。開始済み実行を取消さず終端まで確認し、追加差分も再レビュー後にだけmainを開始する。

同じ未消費main reviewの再確認で、予算計算とcache再利用の二つのnow取得が60秒境界をまたぐと
一回多く取得しうる点も指摘された。主担当が両経路へ一つの観測時刻を渡すようにし、二回読むと
59.9秒から60.1秒へ進む時計対照で、一回の鮮度判断と合計4GETを要求するNative検査を追加する。

先行比較source61080e3/run42134413676/attempt1は全6表示job終端・選択4job成功・構成skip2。
予定00:20 UTCの一括照会で確認し、4完了logを一度ずつ保存した。Native26.6/27.1は各699件/
予定skip1/失敗0（129.686/116.242秒）、Modelの11件も各失敗0で、基本の自動一致/上限/
通信失敗/背景中断/変更/手動置換を通過した。portable602件/失敗0、Python293件/予定skip22/
失敗0（107.294秒）も成功。この終端run/logは再照会しない。5942f20の長時間復帰修正と
境界時計の追加一件はこの先行sourceに含まれず、次の正式全体で700件を新たに検証する。

別の新規GPT-6.1 Sol/High events_follow_up_main_pre_actions_reviewは最初の全7artifact
2127行/105107bytesを読み、二つの予算P2とその修正を主担当が照合した後、最終code patch
587行/32983bytes SHA256 7b32a7c9c8250c257761c53956716756afabb017514c8f5783efa4aaaa7346d2、
Model402行/20367bytes f15f505a…を全行/bytes/hashで再確認し、最終指摘なし。
主担当も現差分の同一性と構文/catalog、先行結果の範囲、全未送信commitの空白を確認して、
この未消費reviewを次のmain push/正式全15/条件成立時の公開一回にのみ使用する。
先行や旧sourceの合格を新sourceへ借用せず、元のUIケース・両OS・期限・全15を維持する。


正式source77d57a5/run42136180150はDistribution/Native700/通常27 A/訂正27四件の7成功、
通常27 Bと26 Aの2失敗、依存6skipで未公開。実行9件のlogを各一度・artifact0を一度確認し再照会しない。
N165/N166の事実・旧現比較・候補は失敗索引に記録し863cbd5で隔離refへ先にpushした。
候補後のLinux検証はnotification/runtime観測14件（0.208秒）、実shell orchestration15件（38.651秒）、
manifest30件（17.588秒）が失敗0。Swift6.1.2 parse・Bash構文・catalog450/check --base77d57a5も成功。
Runtime観測はread-onlyであり、Linuxのコマンド境界検査は実AppleのRuntime消失原因の確認ではない。
週calendarの元5秒/全guard/一回接触/取消/前後週/両OS/正式全15は維持する。

次のmain push/正式全15/条件成立時の公開一回専用として、新規GPT-6.1 Sol/High
`ios_n165_main_pre_actions_review`がcode patch129行/7229bytes、SHA256
`d88c7a7e96b11a1f1d967cd43ede065d3268495f37c2420adb4bca33da6ca604`を全量確認し、指摘なし。
主担当も元5秒/一意性/存在/有限枠/完全包含/enabled/hittable/一回中心tapと全後続assert、
追加診断の10秒/2MiB/対象照合/固定語/一時回収/非介入を照合した。既存正式workflow/製品Modelの
コードは77d57a5から不変で、今回のreviewはこの一回へ消費し再利用しない。


N167の診断候補1a8d4edをpush後、Linux/Swift6.1.2で既存manual diagnostics11件/失敗0（0.267秒）、
manifest30件/失敗0（19.440秒）、fixture Swift parse、catalog450/check --base8cdf066が成功した。
元の三項目ケース/45秒/実接触/保存proofは無変更で、SwiftのUIKit型解決は次のApple診断で確認する。
次の既存manual-input-native-probe/case=三項目/元両OS一回専用として、新規GPT-6.1 Sol/High
`ios_n167_probe_pre_actions_review`がcode patch110行/6874bytes、SHA256
`78ee5d0ab48854995f01f235c9b753a06d9fc454f6b42202f0775d43e264367d`の全量とbase/source一致を確認し指摘なし。
主担当もguard/通常両経路の元sendEvent一回、非介入、128記録/64KiB/固定Bool/本文拒否を再確認した。
このreviewを次の診断dispatch一回に消費し、main公開には別の新規reviewを要求する。
正式8cdfの継続jobは取消さず、新しい完了結果だけ予定時刻に確認する。


N167追加観測の限定ed76a28/run42147251375は元三項目をSDK26.6/27.1の両OSで成功した。
成功時もimmediate native Boolは0のため、後続Binding成功との時点差を記録し、根本原因解明としない。
元test/input/ACK/保存/45秒を変えずに、正式にもこのread-only診断を残し、新sourceの既存全15を確認する。
旧8cdf正式は通常27 Bも成功（calendar元caseを含む）、単項目/明示選択も成功、新3log各一度取得。
旧通常27 A/26 B/後続26 Aは取消さず残りの結果を確認する。終端済みprobe2log/artifact0は再照会しない。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n167_main_pre_actions_review`がpatch110行/6874bytes、SHA256
`78ee5d0ab48854995f01f235c9b753a06d9fc454f6b42202f0775d43e264367d`を全量・commit範囲一致まで確認し指摘なし。
主担当も元sendEvent一回/非介入/128記録/64KiB/strict owned parser/元assert不変を確認し、この新しい
reviewだけを次のmain自動Actions一回に消費する。限定用review/旧main用reviewを再利用しない。
N165候補を含む旧正式のcalendarは52.279秒・元5秒と全後続操作が成功したが、恒常解消とは記載しない。


旧正式8cdf/run42144767317は全15表示job終端、実10件のlogを各一度、artifact0を一度確認し再照会しない。
元通常27 A/26 Bは成功、N167三項目27とN169のXCTest前CoreSimulator devicePair内部例外で公開不可。
現正式01fe/run42149866023はN168単項目27のreview状態照会で20秒timeout、ACK成功後の別段階。
新5logを各一度取得、取得済みは合計7、残通常27 A/26 B/後続26 Aは取消さず確認する。
N168/N169は事実を索引へ先に書き、U67/N94/N97/N140/N151/N165/N07/N73/N127と旧現コードを読んだ。
N168のpredicateを同じ20秒/一意性/一回label読出し/両状態の同時成立へ整理し、事後の追加state照会を除く候補
5f88400を隔離refへ先にpushした。製品・元操作・全後続assert・全15gateは変更しない。
その後Linux Swift6.1.2でreview controls Python2件/失敗0（5.515秒、うち元comparison10 XCTestも成功）、
実predicateの一意/不存在/複数/preview同時true/二時点の値混合拒否、元20秒引数を確認した。
project生成17件/失敗0（0.457秒）、Swift parse・catalog450/check --base01fe8afも成功。
これらは実Appleの20秒内応答やN168の根本原因の証明ではなく、実UIは次の正式両OSで確認する。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n168_main_pre_actions_review`がcode patch93行/5392bytes、SHA256
`8da0d7b81e4c705a9a6da3cd6607557db0025f8cff865ee5f41175bd0145e6d3`を全量とcommit差分一致まで確認し指摘なし。
主担当も一個/単一labelからの両状態/曖昧拒否/元20秒と全後続UI・保存proof不変を確認し、
このreviewだけを次のmain自動Actions一回へ消費する。旧実行は取消さず、同じ終端logは再取得しない。


主実行957/run42156001519/attempt1は04:05予定照会でDistributionとNative両SDK700/予定skip1/失敗0、
訂正27の元四件すべて成功。新6完了logを各一度保存した。単項目は514.027秒でreview/実背景復帰/
再入力と各ACK/正式採用・保存・再起動まで成功し、元20秒と全後続assertを保持した候補の今回の成立を確認した。
三項目673.665秒、明示選択1062.158秒、原本変更420.631秒が成功。一般的なAX原因や恒常解消とは断定しない。
通常27 Aは03:36:25Z、Bは03:39:58Z開始で継続中。次は親の約46分/26側最大55分を踏まえ04:55 UTCに
新しい完了結果と26開始時刻をまとめて確認する。旧01feの26 A（03:48:51開始）も取消さず同時に確認する。
旧01feの27 Aは成功、26 BはN170の既停止deviceへのstrict shutdownだけでfail。新旧別sourceの結果を混ぜず、
主実行の全15/公開gateは維持する。対応が必要ならN170の一意な所有deviceの既停止確認という候補で進め、
推測でSDK/OS/bootや元のテストを変更しない。


主957の04:55予定照会で通常27 A/Bと訂正26の単項目/三項目/明示選択が成功、新6logを各一度取得した。
ただし通常26 BはN171のcalendar native identityがframe後のenabled取得で消え、元5秒が不成立。
N170とは別の段階である。主957の残26 A/原本変更26は取消さず終端まで確認する。
旧01feは最後の26 Aが04:36:58Zに成功し、全15表示job終端・実10log各一度/artifact0一度確認済みで再照会しない。
N171の事実・旧現比較を先に記録し、週Buttonの固定semantic IDへ結び付ける候補とN170既停止cleanupの限定対応を
05ab23fとして隔離refへpushした。wrong supported Runtimeの負対照一つも964a9b9で先にpushしてから確認した。
局所はobserver/終了確認15件/失敗0（初回0.243秒、追加負対照後0.205秒）、実shell16件/失敗0（43.104秒）、
manifest30件/失敗0（19.224秒、元29幾何を含む）、Swift6.1.2 parse/Bash構文/catalog450/check --base9577502が成功。
UIDを付けるだけの製品変更では原caseと元幾何を使用し、XCTestの再生成を模倣した新caseは増やさない。
これらはAppleの5秒応答やcleanup状態を保証せず、実両OSは次の正式全15で確認する。
review artifactはすべての局所commandが終了した後に一意なfinal pathへ再生成し、同一SHAを確認してから渡した。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n171_main_pre_actions_review`がcode patch180行/10214bytes、SHA256
`bd64b89e57fa11a8f911f630ff027031d6a50d5c6626433f0e60ae870dc5506e`を全量・commit範囲一致まで確認し指摘なし。
主担当も週Buttonの元label/固定ID/一意性/全guard/5秒/一回中心接触と、149限定の一意な所有device既停止確認/
他終了値・不明状態のfailure伝播/全freshdevice・通知・OSサイズ検証の維持を照合した。
この新しいreviewだけを次のmain自動Actions一回に消費し、過去reviewは再利用しない。
