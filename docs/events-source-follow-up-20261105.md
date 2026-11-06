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
