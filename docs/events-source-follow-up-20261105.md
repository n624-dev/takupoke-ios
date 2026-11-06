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


主実行957/run42156001519/attempt1は04:05予定照会でDistributionとNative（Xcode26.6/SDK26.5）700/予定skip1/失敗0、
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


主bb809/run42166029342は05:45予定照会で通常27 A/Bが成功、Native（Xcode26.6/SDK26.5）700/予定skip1/失敗0、Distribution、
訂正27の三項目/原本変更/明示選択も成功。新7完了logを各一度取得した。残単項目27は05:33:50開始、
通常26 Bは05:43:05、Aは05:43:28開始で継続、取消しなし。全15/公開はまだ未成立。
旧957の最後の2logを各一度取得しartifact0を一度確認した。旧26 AはN172の通知設定navigation10秒失敗で、
配信確認前の別段階として記録。N48/U75と旧現helperを比較し、既に開始済みの主bb809の26 A結果を確認してから判断する。
新primaryの元通常26の最大約55分と残訂正を踏まえ、次は06:45 UTCに新しい完了jobと公開段階をまとめて確認する。
これまでの終端run/log/artifactは再照会しない。Windows10459の公開検証は完了済みである。

主bb809の06:45予定照会で残3件が終端となり、通常26 Aは成功、単項目27はN173の訂正値のglobal
firstMatch.frame照会timeout、通常26 BはN174のcalendar専用IDのexists再照会停止だった。全15表示job終端、
実10log各一度/artifact0一度を確認し、依存skip5は成功に数えず公開なし。終端実行を再照会しない。
事実を索引へ先に記録し、N54/N78/N94/N97/N153/N151/N165/N171の詳細と当時/現在のsourceを比較した。
復旧確認値を既存manual-reviewed- IDと実labelで現在の復旧Listへ限定し、候補frameを一回だけ観測する。
calendarは一回のAX snapshotで存在・一意性・画面枠・enabledを揃え、現在の実controlのhittableも別に要求する。
元5秒/完全包含/一回中心tap/全後続assert、復旧の16探索/受動drag/実訂正値/保存proof/全15gateは維持する。
比較・候補a0fc902を隔離refへ先にpushしてから局所検証した。

Linux/Swift6.1.2でreview controls Python2件/失敗0（7.300秒、元comparison10と幾何8 XCTestも全成功）、
scroll navigation Python2件/失敗0（2.962秒）、元navigation関連Swift29件/失敗0（0.124秒）、
project生成17件/失敗0（0.557秒）、manifest30件/失敗0（19.409秒）、Swift frontend parseと
catalog450/check --base bb8091eが成功した。新幾何caseは同じviewport規則と欠損・重複・不正枠の拒否を確認する。
既存UI caseが実label/全包含/操作・後続状態を検出するため、そのassertや期限は編集しない。
これらはApple SDKの型解決・実AX応答時間や恒常的な解消の証明ではなく、次の正式両OSで確認する。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n173_main_pre_actions_review`がcode patch172行/11768bytes、SHA256
`90b1e5dde80e70d7ae78016d9f5b35837a4b9ca5d3ea8528caa1427828f3bc60`を全量・commit差分一致まで確認し指摘なし。
主担当も同時点の実snapshot/現在hittable/元5秒/一意性/完全包含/一回tap、復旧の実label/16探索/保存proofと
新幾何の負対照を照合した。この新しいreviewだけを次のmain自動Actions一回へ消費し、過去reviewを再利用しない。

主031916/run42178798904/attempt1は08:00照会で27の全ケース/Distribution/Nativeが成功、09:00照会で
全18表示jobが終端だった。実14件中11成功、N175通常26 AのXCTest開始前runner通信切断、N176単項目26と
N177三項目26の実case開始後Runtime bundle利用不能の3失敗で公開なし。依存・構成skip4は成功に数えない。
全14完了logを各一度/artifact0を一度確認し、終端run/logを再照会しない。新しいcalendarは26 Bでも元5秒と
全後続操作に成功、復旧27の確認本文も成功したが、個別成功を恒常解消へ一般化しない。
Native701件/予定skip1/失敗0はXcode26.6/SDK26.5である。先行比較の両SDK699件と区別し、旧本文2箇所の
正式700件を両SDKとした記述を訂正した。DistributionはPython297件/失敗0（90.762秒）。

N175〜N177の観測事実を先に記録し、U60/U61/N76/N166/N169の詳細と3054127/現準備sourceを比較した。
準備stepで削除していた取得exportを、正式26/配布SDK26のrelaunch診断で実testとdevice回収まで保持し、
最後のalways stepで所有領域だけを回収する候補a28ae0aを局所試行前に隔離refへpushした。
Linux/Python3.12で実準備helperのlifetime/cleanup/SDK各4件/失敗0（6.380秒）、manifest30件/失敗0
（21.661秒）、catalog450/check --base031916が成功。実AppleのRuntime安定性の証明とは別である。
補足runnerの初回16件はN178の独立入力間で新always回収を実行しておらず7subcaseが失敗した。
事実・旧現比較を先に記録し、元全27入力/正負期待を保って実cleanupを各入力の後へ接続する55af502を
先にpushした後、実shell16件/失敗0（66.045秒）で再確認した。0件の誤ったfile patternは成功件数に含めない。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n176_main_pre_actions_review`がcode patch271行/15653bytes、SHA256
`a7fd34c4cd35193cf6586123eba9d8c5c0aa983cf7e2642ab6a6873b2f948a96`を全量・commit差分一致まで確認し指摘なし。
主担当もSDK/Runtime固定・登録済unavailable拒否・download/import期限・所有marker/symlink拒否・
元全UI/全15gateとalways回収の順序を照合した。この新reviewだけを次のmain開始一回へ消費する。
Runtime消失とexport削除の直接因果、通信切断の下位原因、恒常解消は未証明として、次の正式両OSで確認する。

主200e60a/run42192999314/attempt1は10:05照会でDistribution299件/失敗0（153.349秒）、Native701件/
予定skip1/失敗0（Xcode26.6/SDK26.5、125.000秒）、通常27 Aと訂正27全4件が成功。新7完了logを各一度取得した。
11:15照会で全18表示job終端、通常27 Bと訂正26全4件も成功したが、通常26 A/BはN179/N180で失敗、公開なし。
全14log各一度/artifact0一度確認済み、過去の終端run/logを再照会しない。取得exportは実testとdevice回収後まで
保持され、今回bundle nullは出なかったが、候補が下位OSの問題全般を解消したとは断定しない。

N179はcold再起動前のHome命令から返却せずXCTestがunexpected再起動、その後17件がforeground等で失敗。
N180は独立通知caseの初回native Switch一回接触後、UI/保存/認可要求が始まらず45秒で失敗した。
事実を先に記録しU19/U43/U49/U55/U59/U64/U71/N94/N95/N125/N167の詳細と旧現helper/既存observerを照合。
SpringBoardが実foregroundなら余分なHome命令を送らず元45秒の実準備証明は維持し、通知caseだけ既存の
read-only入力診断を有効にする5b8fe8aを隔離refへ先にpushした。製品/点/接触時間/期限/全後続assert/gate不変。
Linux Swift6.1.2でmanifest30件/失敗0（18.003秒）、所有observer・終了確認15件/失敗0（0.152秒）、
Swift frontend parse、catalog450/check --base200e60aが成功。元UI caseで実起動・入力・保存を確認するため、
Apple APIのmockで実OS成功を模倣する追加caseは作らない。実OSの準備・配送は次の正式両OSで評価する。

次のmain push/正式全15/条件成立時の公開一回専用に、新規GPT-6.1 Sol/High
`ios_n179_main_pre_actions_review`がcode patch41行/2946bytes、SHA256
`89b0aefeea633b97708db0a7369a1b6d269972f0fe85573fc42b08638783cb79`を全量・commit差分一致まで確認し指摘なし。
主担当も停止後一回launch/元45秒と実foreground・frame、既存observerの元event一回/非介入/固定記録、
全後続assert・全15gate維持を照合した。この新reviewだけを次のmain開始一回に消費し、過去reviewを再利用しない。

主bb201b8/run42209482541は12:15予定照会で通常27 A/B・訂正27の単項目/三項目/原本変更・Native/Distributionが成功、
明示選択27だけN181の教師入力欄global Any firstMatch.existsでtimeout。新8logを各一度取得した。
通常26 A/Bは取消さず継続し、実開始11:58:33/12:02:35と過去最大55分から13:05に残りだけ確認する。
N181の事実・N54/N78/N94/N97/N153/N173の詳細/旧現source比較を先に記録し、既知IDの引数漏れ3箇所を
まとめて修正する49c4c60を先に隔離refへpushした。全manual visible呼出しも検索し、同じglobal Any入力欄の
引数漏れが他にないことを確認した。専用Button・動的label・代替候補は用途を読み、機械的一括置換はしない。
Linux Swift6.1.2で元navigation Python2件とSwift29件/失敗0、生成17件/失敗0（0.435秒）、manifest30件/失敗0
（17.201秒）、Swift parse/catalog450/check --basebb201b8が成功した。実OSの応答は未確認である。

利用者の追加指示により、全体CIの反復前に対応する限定CIで候補を確認する進め方へ改めた。
短い[UIテスト実例一覧](ui-test-best-practices.md)を18行/12項目で作り、AGENTS/保守方針/READMEから参照する。
元ケース/公開ゲート/期限は変えない。先に作成したmain専用ios_n181_main_pre_actions_reviewは指摘なしだったが
未消費のまま廃止し、次の限定dispatchへ流用しない。限定後のmainにも別の新規reviewを要求する。

次の既存manual-input-native-probe/元明示選択case/元両OS一回だけに、新規GPT-6.1 Sol/High
`ios_n181_probe_pre_actions_review`がcode patch24行/1863bytes、SHA256
`c6d945c3d9b74dba171928ce3a3730eb311b2420b500e776387324325cfb4027`を全量・commit差分一致まで確認し指摘なし。
主担当も引数IDと実生成ID・元の厳密な可視化/実値assert・全後続操作/保存を確認した。この新reviewを限定開始一回へ消費する。
限定27は失敗時と同じSDK27.1/Runtime27.0、限定26は既存workflowのSDK26.5/Runtime26.5である。
限定26の結果を正式配布SDK27.1の26や全15成功へ流用せず、正式は最後に同じsource/run/attemptで別に確認する。

13:05予定照会で旧bb201b8の26 A/Bも成功、全15表示job終端・実10件（9成功/N181失敗1）・依存構成skip5で公開なし。
最後の2log各一度/artifact0一度を確認し、旧run/logを再照会しない。通常両OSのcold起動/通知も元ケースを通過した。
13:40予定照会で限定5772cd7/run42222239849/attempt1は両job成功、元明示選択caseは26で1247.423秒、
27で1066.195秒、各失敗0。2完了log各一度/artifact0一度確認済みで、この終端実行も再照会しない。
三つの保持値・独立ACK/4件拒否・採用/保存・再起動を含む元の完了照合が成功した。限定成功を正式へ合算せず、
既知ID候補を含む新sourceの元全15を同じsource/run/attemptで確認してから既存経路で公開する。

限定完了後の次のmain push/正式全15/条件成立時の公開一回に、新規GPT-6.1 Sol/High
`ios_n181_final_main_pre_actions_review`がcode patch24行/1863bytes、SHA256
`c6d945c3d9b74dba171928ce3a3730eb311b2420b500e776387324325cfb4027`を全量・commit差分一致まで確認し指摘なし。
主担当もID対応/実値assert/元の探索・包含・hittable・ACK/保存/再起動・全15を照合した。
この新reviewだけを次のmain開始一回へ消費し、廃止した旧main用や限定用reviewを流用しない。

主b04d011/run42227564373の14:30予定照会で、明示選択27は正式でも1198.759秒/失敗0、通常27 A/B/
原本変更/Distribution299件/Native701件（予定skip1、Xcode26.6/SDK26.5）も成功した。ただしN182の三項目27は
初回app.launchのXcode timeout、N183の単項目27はreview20秒のglobal state検索で失敗した。通常26 A/Bは
14:23:11/14:27:43開始で継続、取消さず最大55分を踏まえ15:25に残りを確認する。
作業環境の再起動でlog取得cellが失われたため、保存済み2logは再取得せず、未保存6logだけ回復取得した。
これで新8logを保存済み。旧終端run/logへ戻らず、通信中断をCIの新失敗へ数えない。

N182/N183の事実とN95/N125/N168/N173/N179/N181の詳細/当時と現sourceを先に照合した。
manualにも通常Suiteと同じ条件付きHomeを適用し、QA overlayの専用container内へreview/previewの
両state queryを限定する候補793f8b0を先に隔離refへpushした。既存の初期化固定stageを同じ所有logから
回収する診断も付け、起動の到達段階を観測する。製品・元操作・45秒/20秒・全assert/gateは不変である。
Linux Swift6.1.2でreview controls Python2件/失敗0（11.371秒、比較10/幾何8 XCTestも成功）、
生成17件/失敗0（0.688秒）、manual診断12件/失敗0（0.329秒）、manifest30件/失敗0（40.175秒）、
Swift parse/catalog450/check --baseb04d011が成功。元の一回label同時判定/未知・複数拒否・20秒、
生成containerの一意ID/children contain/非hit接続、固定lifecycle9種/128行/64KiB/本文・symlink拒否を確認した。
これらは実OS起動やAX応答の証明ではなく、次は既存限定all4case×両OSで関連ケースをまとめて確認する。

次の既存manual-input-native-probe/case=all/元4case×元両OS一回専用に、新規GPT-6.1 Sol/High
`ios_n183_probe_pre_actions_review`がcode patch157行/9306bytes、SHA256
`ee4c835cf42301e1037bfd98f03c6ffb3817b736b3b9270adc38ec4e1b37783b`を全量・commit差分一致まで確認し指摘なし。
主担当も条件付きHome/元一回launch・45秒、QAの非hit container/元実state・20秒、固定診断/元終了値/所有回収を照合した。
この新reviewだけを次の限定dispatch一回へ消費する。限定26は元SDK26.5であり、正式の配布SDK27.1検証とは区別する。
限定全体を通過した後に、別の新規reviewで正式全15を開始する。継続中の旧通常26の終端も取消さず確認する。

15:25予定照会で旧b04の通常26 Bは成功、26 AはN184のRuntime bundle利用不能で失敗だった。export保持後も
再発しており、保持が直接原因を修復したとは扱わない。旧正式は全15表示job終端・実10件（7成功/3失敗）/
全10log保存済み/artifact0一度確認済みで再照会しない。公開なし、依存skipは成功へ数えない。
関連限定2451a1b/run42236030942は15:25で6件終端、実成功時間と局所確認終了から15:35へ前倒して残2件も確認した。
全8件中5成功、N185の三項目27はreview/preview/閉じる/未採用proof後のterminate、N186の明示選択26は4件目拒否の
状態文のbounded可視化、N187の単項目27はQA menu開封後の45秒action存在で失敗。全8log各一度/artifact0一度確認済み。
新QA state containerでreview/previewは通過したが、他段階の失敗を恒常解消と混同しない。

N184〜N187を先に記録し、U43/U55/U63/U75/N85/N94/N95/N125/N151/N154/N173/N179/N181と旧現sourceを照合。
全3終了callerで現在のforegroundを確認してから一回terminateし、確認できないcallerはBool guardで止める。
statusにはQA生成コピーだけの専用IDを付け、同じList/既知ID/実labelから元の完全包含/hittable/16探索を確認する。
QA menuはtoolbar観測後に現在のnative Buttonを一意に取得し、同じ中心へ既存方式の0.1秒接触を一回だけ行う。
元3actionの45秒存在、実操作/保存、全体gateは変えない。1b92c54/f64671a/f6730afの各候補を局所試行前にpushした。
生成17件/失敗0（初回0.595秒、caller guard後0.652秒、menu後1.145秒）、幾何Swift29件/失敗0、
manifest30件/失敗0（25.897秒/20.012秒/71.395秒）、Swift parse/catalog450が成功した。

次の限定は26にも配布SDK27.1を明示できるよう40e056cで入力を追加し、先にpushした。既定26.6の比較は維持する。
変更後のmanifest30件/失敗0（51.834秒）、実SDK/Runtime helper4件/失敗0（22.703秒）、catalog450が成功。
同じ4case×両OS/35・45分/全完了照合、Runtime26.5と所有exportのhold/always回収を保持し、正式gateを変更しない。
N186/N187用の先行reviewはいずれも未消費で廃止し、追加workflow差分を含む次の一回へ流用しない。

次の既存manual-input-native-probe/case=all/sdk26=27.1/4case×両OS一回に、新規GPT-6.1 Sol/High
`ios_n187_shipping_probe_pre_actions_review`がcode patch217行/15324bytes、SHA256
`fc22d957fd8e3ba263d143be7d07e324dd6dcef166917a4be38bded26386f906`を全量・commit差分一致まで確認し指摘なし。
主担当も元assert/期限/一回操作/Bool失敗の中断・SDK選択/既定旧SDK保持/always所有回収を照合した。
この新reviewだけを次の明示配布SDKの限定dispatch一回へ消費する。限定8件が通過してから、別の新規reviewで正式全15を行う。
