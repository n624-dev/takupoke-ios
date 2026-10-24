# 学校行事の元PDF状態APIへの移行

API #47 / iOS #65 に従い、端末から学校PDFへのHEADを専用の状態APIへ置き換える。
保存済み行事・APIの200/304・初回手動取得は維持する。端末キャッシュは12時間、
サーバー確認中は60秒。年度・採用済みhash・APIレスポンスETagに対応する配信版を照合する。
状態と確認日時は標準Text/Labelで表示し、日本時間を明記する。配信版不一致は一致扱いにしない。

編集前にtest_catalog search SchoolEventsで既存14ケースを確認した。
既存は行事本体の契約と保存を検査するため、新しい状態検証・キャッシュ境界・
異なる年度/hash/配信版・失敗/未確認/期限・架空URLProtocol通信を6ケース追加した。
Package.swiftとXcodeの入力・対応表へ登録し、一覧write/check --base 1c33181は成功。
Linux Pythonのtest_test_catalog.py 14件成功。

UI索引はSchoolEvents/学校行事/source.status/HEADで検索した。N105/N106の保存済み行事読込・
参考表示の優先順位は維持する。状態APIの表示や学校HEAD廃止そのものの既存失敗は見つからない。
学校本番URLへの通信・資料取得をテストへ追加しない。LinuxではSwiftUIの実画面・VoiceOver・
物理端末のオフライン/復帰・AltStore導入を確認できない。Apple CIと実機確認は別に記録する。

変更は開発PRで検証し、公開済みバイナリへ反映したとは扱わない。
API側の旧PDF監視撤去はAPI本番とiOS移行確認を条件とする。
