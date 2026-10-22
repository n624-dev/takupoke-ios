# Issue59の検証（2026-10-22）

基点fcc6ee2。完全架空の返却PDFを使い、Strict239が既存どおり受理する[4/2,4/1,4/3,4/4,4/5]と通常列順を検査する。受理条件・枝番号は変更しない。日付のsort前に専用時刻の適用日を保存し、parserVersion33へ更新する。認定parserにも同じ情報を保存するが、既存の日付順条件は維持する。

保存済み授業の時刻は全日で保持する。旧形式で先頭列を復元できない場合は時限時計を推測せず、保存済みの原文時刻と正常PDF・DBを維持し再解析を待つ。旧形式でtimeRangeがnilだった正常レコードも、従来の読込検証だけを互換維持し、表示の時計推測へ流用しない。復旧採用済みの各日各時限時計は従来どおり優先する。

事前にtest catalog・失敗索引を検索した（/tmp/issue59-ios-catalog-search.log、/tmp/issue59-ios-failure-search.log）。実parserから各5日×8時限の独立期待、JSON往復、空枠の変更時計、5〜6限結合カード・授業中・6限fragment、実SQLite保存と再起動、旧32形式の原文保持と不明時計を検査する。初回533件中1失敗はN69へ記録し、旧期待と今回の確定仕様との差を明記した。Apple環境・実機での確認は別途記録する。

修正記録push後、Linux正規SPM533件が失敗0（実行76.913秒、準備込み256.2秒）。Swiftを有効にしたPython264件も予定skip2・失敗0。初回の生成枝一覧のリンク不一致はN70へ記録し、23箇所の行リンクだけを更新した。枝番号・分類・受理条件は変更していない。test catalogのmain基点check、枝一覧check、共有指示bytesとiOS adapter検査、差分空白検査も成功。Actions開始前に新規GPT-6.1 Sol/Highへ両環境のコード差分だけを渡し、N69後の1 assertion修正も同じレビューで確認しblockingなし。最新Apple全体結果はこれから確認する。

Apple PR全体427/run39750668724のsourceee6720dではNative616件（予定skip1・失敗0）、iPhone build、両OS通常UI4組、訂正7ケースが初回成功した。選択26だけは初回起動のbackground assertion timeoutで止まり、N72の比較・記録push・新規レビュー後に同sourceのその1ジョブを独立検証し成功した。初回失敗や旧426のclear未成立は失敗索引へ保持する。利用者の公開指示に従い、公開用mainの全検証・ビルド・配布照合へ進む。物理iPhoneでの更新は未確認。

## 2026-10-22 公開と匿名照合

[0.1.428/428.3](https://github.com/n624-dev/takupoke-ios/releases/tag/v0.1.428-build.428.3)を通常Release/Latestとして公開した。配布元d713ed6698a6fd6c2be04f273b13956dc2d51bfe、全体428/run39771133485。初回はN73のhost通信断、試行2はN74のPicker AX照会停止で公開しなかった。失敗ジョブだけの独立検証後、試行3で公開ゲートの全必須成功確認と配布が完了した。両OS通常UI4組・訂正8件、Native616件（予定skip1・失敗0）、元Picker3件・実遷移とiPhone buildを確認した。

全4添付を匿名取得し、GitHubのsize/digest・release.jsonの全ハッシュ・IPA内部の版/ソース/権限/公開版診断除外と版固有Sourceを照合した。固定AltStore Sourceの実bytesも一致し、同じ版を案内する。検証用一時領域は自動回収した。

IPAは17,128,712 bytes、SHA-256は`d774aedce62b610b9d3ff1346545dfdd5d010289cf74674d8ea93d3042ce92ff`。
AltStore Source経由の端末更新、実機での修正再確認、学校資料・OneDriveの実動作は今回未確認。CI/独立架空入力と実機確認を区別する。
