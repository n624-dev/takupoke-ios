# 436公開後の追加Issue対応

初回公開436.1（c815640、run39999724291/1）の全15必須検査・匿名配布検証完了後に着手。追加39件（65〜103）とWindows25件（20〜44）の本文を一括取得し、以後は保存済みsnapshotから調査する。APIサーバー改修は完了済み、再開しない。個別の未確認を完了扱いにしない。

## 年度行事の保存境界（68）

e623598に再現テストのみ先行。Linux Swift6.1.2でpayload999,990bytesを実decode/saveしてから新しいstoreで読み戻すと、failedYears2032/savednil。N99に修正前事実を記録。4d683d0はpayload1MBを維持し、metadata envelope全体へ2048bytesの別枠を設けsave/load共通の上限とする。payload超過時の既存ファイルbytes維持も確認。

## 空DBの初回作成中断（78）

e623598の再現は空SQLite+原本0でinvalidState。過去N57・Issue41原本保護の旧/現行を比較した。4d683d0では原本なし・schema完全空・user_version/application_id0だけを再開し二表をtransaction作成。他schema/非zero version/原本ありでは引き続き拒否し削除しない。旧schema移行も維持。

修正前546件/3失敗、修正後547件/失敗0（72.910秒、準備込み246.3秒）。追加境界・初期化再開・負の対照すべて成功。Apple Native/iOS実機はまだ未検証。このLinux実行に未実行のSwiftUIを含めない。

Windows対照:PublicEventsStoreのファイル上限は2MBとpayload1MBで既に別。上限近傍を保存/再読込する回帰は追加確認予定。学校DBは暗号化された独立storeで特別資料も同じschema transactionを使用し、iOSの空sidecar専用guardとは異なる。Windows独自のリンク互換失敗37、行事列挙失敗38による正常資料の巻き添えを別途修正する。

## 文字列・検索（69/99、Windows25/27/28/42）

8985d7cは修正前再現テストのみ。t=strは両OSで既存のOOXML一回復号を通らない。後方検索語の減点も両OSに存在。iOSのuu長音は既にuなのでWindows28は非該当。Win25のBOM、26のtyped-dateもSwift readerで比較する。結果・修正後検証は後続追記。
