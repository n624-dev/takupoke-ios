# UIテスト実装の注意点

UI編集前に読む。詳細・未確定事項は[失敗索引](ui-test-failures.md)と当時のコードで確認する。

- 画面外の`firstMatch`を直接読む → IDから現在の実候補を探し、元の上限内でスクロールする。（N97/N181）
- 文字列やAnyで全画面を検索する → 実List・型・専用ID・実labelで絞る。QA状態は専用containerへ絞り、本文の前面に重ねない。（N173/N183/N189/N233/N238）
- スクロール前のnative identityを使い続ける → 接触直前に取得し、一意性・完全包含・enabled/hittableを確認する。長押しするTextも同じ。（N94/N97/N237）
- 同じframe/labelを何度も読む → 一試行の値を再利用し、現在のhittabilityは別に確認する。（N165/N168/N174）
- 検査済みCellの子を再列挙する → 同じ試行の実子・枠を保持し、dragは操作部品を避ける。（N78/N80）
- tapの返却を成功とする → 実値・Binding・保存と全callerの配送を確認する。接触取消は実記録から対処し、押し直し・注入・期限延長で救済しない。（U64/N180/N192/N212）
- 無条件でHomeを送る → SpringBoardが既に前面なら重ねない。元の準備条件・一回launchを守る。（N179/N182）
- Runtime登録直後に取得物を消す → test/device回収後まで保持し、最後のalwaysで所有領域だけ消す。（N176/N177）
- shutdown失敗を一律無視する → exit149だけ、正確な所有UUID/Runtimeが一意なShutdownと実確認した場合に受理する。（N170）
- APIの返却・途中状態だけで成否を決める → 元の期限内で実状態・所有回収を確認し、timeoutは失敗にする。（N162/N188/N224/N234）
- helperと別callerのmockを別々に直す → 全caller/mockを検索し、実JSONへ揃える。一時領域は入力ごとに分離・回収する。（N178/N229）
- 全device一覧やログ名の想定で証明する → 実RunnerのID・OS・Simulator条件を照合し、テスト名は実classで正規化する。（N07/N199/N200/N211）
- 部分成功で公開する → 同じsource/run/attemptの全15必須成功を要求する。毎回の新規review・残job確認・未実機確認の明記も守る。

個別成功を恒常的な解消へ一般化しない。詳しい手順は[テスト保守方針](test-maintenance-policy.md)へ。
