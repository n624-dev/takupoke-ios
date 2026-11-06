# UIテスト実装の注意点

UIの編集・実行前に読む。[失敗索引](ui-test-failures.md)の詳細と当時のコードも照合する。

- **画面外の`firstMatch.exists/frame`を直接読む → 専用IDをhelperへ渡し、現在の実候補配列から探す。** 不在時は元の上限内でスクロールする。同種の呼出しも全件点検する。（N97/N173/N181、N181の限定ケースは両OSで通過）
- **文字列だけで画面全体を探す → 現在のList・専用ID・実labelで対象を絞る。** 同じ文字の編集欄やプレビューと混同しない。QA状態も専用containerへ絞る。（N173/N183）
- **スクロール前からnative identityを保持する → 移動中は論理ID、接触直前だけ現在のnative identityを使う。** 一意性・完全包含・enabled/hittableを省かない。（N94/N97）
- **同じframe/labelを何度も読む → 一試行の観測値を再利用する。** AND条件は同じlabel一回から判定する。snapshotを使っても現在のhittabilityは別に確認する。（N165/N168/N174）
- **検査済みCellの子を直後に再列挙する → 同じ試行では実子・枠を保持する。** dragは操作部品を避けた実受動Cellで行う。（N78/N80）
- **tapの返却を成功とする → 実native値・Binding・保存を期限内に確認する。** 未反映は読取専用の入力診断で調べ、押し直し・値/許可注入・期限延長で救済しない。（U64/U71/N167/N180）
- **cold起動前に無条件でHomeを送る → 実SpringBoardがforegroundなら重ねない候補を使う。** 元の準備期限・有限frame・対象一回launch・foreground/fixture-ready確認は維持する。（N179は両OS通過、manualへの適用N182は確認中）
- **Runtime登録直後に取得物を消す → test/device回収後まで所有exportを保持し、最後のalwaysで所有領域だけ回収する。** 別Runtime・未知領域・symlinkを削除しない。（N176/N177、消失の直接原因は未確定）
- **shutdown失敗を無視する → exit149だけ、正確な所有UUID/Runtimeが一意なShutdownと実確認できた場合に限り受理する。** 他の終了値・不明状態は失敗する。（N170）
- **fakeの独立job間で一時領域を共有し回収を省く → 各入力でも実job末尾のcleanupを実行する。** 元の正負期待と回数は変えない。（N178）
- **失敗箇所だけ直して全体CIを繰り返す → 事実を先に記録し、過去詳細・当時/現コード・関連呼出しをまとめて点検する。** 候補を先にpushし、関連ローカル検査→失敗元のSDK/OSを明示した限定CI→最後に全体CIの順で確認する。
- **部分成功を公開可とする → 同じsource/run/attemptの元の全15必須成功を要求する。** 限定CIのSDK/OS差と未実機確認を明記する。各Actions前の新規review・失敗後の残job確認も省かない。

個別成功を恒常的な解消へ一般化しない。詳しい手順は[テスト保守方針](test-maintenance-policy.md)へ。
