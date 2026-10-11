# 失敗したActionsの期間別一覧（2026-10-11）

2026-10-08 00:00 UTC以降、今回の照合時点で、
結論がfailureの全61実行と、その最新試行の失敗95ジョブをGitHub APIで確認した。
全実行を列挙したが、原ログの全件再取得を意味しない。原因の比較と再照合の範囲は
[横断確認](ui-failure-patterns-20261011.md)を参照する。
ジョブ数はケース数・原因数ではない。上流の失敗を検出した公開ゲートの失敗も含む。
成功・cancelled・skip・実行中はこの表に含めず、失敗率は算出しない。
既存のcancelled中の失敗は[失敗索引](ui-test-failures.md)と検証記録へ保持する。

| 作成日 UTC | 実行 | ソース | 失敗ジョブ数 |
|---|---|---|---:|
| 2026-10-11 | [通常UI診断 40](https://github.com/n624-dev/takupoke-ios/actions/runs/38114822271) | 4bba1b6 | 1 |
| 2026-10-11 | [通常UI診断 39](https://github.com/n624-dev/takupoke-ios/actions/runs/38113398465) | b34bd1f | 1 |
| 2026-10-11 | [通常UI診断 38](https://github.com/n624-dev/takupoke-ios/actions/runs/38112276765) | 249037b | 1 |
| 2026-10-11 | [通常UI診断 37](https://github.com/n624-dev/takupoke-ios/actions/runs/38110490234) | f4c656a | 1 |
| 2026-10-11 | [通常UI診断 36](https://github.com/n624-dev/takupoke-ios/actions/runs/38109734983) | 185a65f | 2 |
| 2026-10-11 | [開発検査 64](https://github.com/n624-dev/takupoke-ios/actions/runs/38109731687) | 185a65f | 1 |
| 2026-10-11 | [配布前全体 360](https://github.com/n624-dev/takupoke-ios/actions/runs/38107075743) | 9b3ac23 | 1 |
| 2026-10-11 | [通常UI診断 35](https://github.com/n624-dev/takupoke-ios/actions/runs/38106669988) | 9b3ac23 | 1 |
| 2026-10-10 | [通常UI診断 34](https://github.com/n624-dev/takupoke-ios/actions/runs/38081878973) | 9d1eb79 | 1 |
| 2026-10-10 | [配布前全体 359](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018) | e191bf3 | 3 |
| 2026-10-10 | [配布前全体 358](https://github.com/n624-dev/takupoke-ios/actions/runs/38075094896) | 5cfc575 | 2 |
| 2026-10-10 | [通常UI診断 32](https://github.com/n624-dev/takupoke-ios/actions/runs/38073321707) | 9e28e63 | 1 |
| 2026-10-10 | [配布前全体 357](https://github.com/n624-dev/takupoke-ios/actions/runs/38068857906) | c490e2d | 1 |
| 2026-10-10 | [配布前全体 356](https://github.com/n624-dev/takupoke-ios/actions/runs/38064917285) | 3e58684 | 1 |
| 2026-10-10 | [開発検査 54](https://github.com/n624-dev/takupoke-ios/actions/runs/38063910154) | 226cb5e | 3 |
| 2026-10-10 | [開発検査 53](https://github.com/n624-dev/takupoke-ios/actions/runs/38063908274) | 226cb5e | 1 |
| 2026-10-10 | [開発検査 50](https://github.com/n624-dev/takupoke-ios/actions/runs/38062088141) | a864f11 | 2 |
| 2026-10-10 | [開発検査 48](https://github.com/n624-dev/takupoke-ios/actions/runs/38061329610) | 3f7d7df | 2 |
| 2026-10-10 | [開発検査 46](https://github.com/n624-dev/takupoke-ios/actions/runs/38061090687) | 62decb4 | 3 |
| 2026-10-10 | [開発検査 45](https://github.com/n624-dev/takupoke-ios/actions/runs/38061089643) | 62decb4 | 1 |
| 2026-10-10 | [配布前全体 354](https://github.com/n624-dev/takupoke-ios/actions/runs/38040538159) | 5d378cd | 1 |
| 2026-10-10 | [配布前全体 353](https://github.com/n624-dev/takupoke-ios/actions/runs/38036952573) | 4292872 | 1 |
| 2026-10-10 | [配布前全体 352](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782) | b765302 | 2 |
| 2026-10-10 | [配布前全体 351](https://github.com/n624-dev/takupoke-ios/actions/runs/38030340274) | 2f3c94e | 2 |
| 2026-10-10 | [配布前全体 350](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042) | 693cf07 | 2 |
| 2026-10-10 | [配布前全体 349](https://github.com/n624-dev/takupoke-ios/actions/runs/38023085810) | e285172 | 1 |
| 2026-10-10 | [配布前全体 348](https://github.com/n624-dev/takupoke-ios/actions/runs/38021457932) | a6a0bdc | 1 |
| 2026-10-10 | [開発検査 33](https://github.com/n624-dev/takupoke-ios/actions/runs/38020167906) | cd5052f | 2 |
| 2026-10-09 | [通常UI診断 28](https://github.com/n624-dev/takupoke-ios/actions/runs/37978618022) | 6d5ee1d | 2 |
| 2026-10-09 | [通常UI診断 27](https://github.com/n624-dev/takupoke-ios/actions/runs/37976233485) | 5fb25e6 | 1 |
| 2026-10-09 | [通常UI診断 26](https://github.com/n624-dev/takupoke-ios/actions/runs/37974710845) | 5fb25e6 | 1 |
| 2026-10-09 | [通常UI診断 25](https://github.com/n624-dev/takupoke-ios/actions/runs/37971894052) | fb43b6f | 1 |
| 2026-10-09 | [通常UI診断 24](https://github.com/n624-dev/takupoke-ios/actions/runs/37966566030) | 22e7a33 | 1 |
| 2026-10-09 | [配布前全体 346](https://github.com/n624-dev/takupoke-ios/actions/runs/37957784144) | c4df343 | 3 |
| 2026-10-09 | [通常UI診断 20](https://github.com/n624-dev/takupoke-ios/actions/runs/37951761364) | 93b5dd0 | 1 |
| 2026-10-09 | [通常UI診断 19](https://github.com/n624-dev/takupoke-ios/actions/runs/37949136078) | ff144ee | 1 |
| 2026-10-09 | [通常UI診断 17](https://github.com/n624-dev/takupoke-ios/actions/runs/37945117177) | c407ad2 | 1 |
| 2026-10-09 | [通常UI診断 16](https://github.com/n624-dev/takupoke-ios/actions/runs/37944069066) | c407ad2 | 1 |
| 2026-10-09 | [配布前全体 345](https://github.com/n624-dev/takupoke-ios/actions/runs/37934716695) | 4ac4d77 | 1 |
| 2026-10-09 | [通常UI診断 14](https://github.com/n624-dev/takupoke-ios/actions/runs/37920921771) | 599e176 | 1 |
| 2026-10-09 | [通常UI診断 13](https://github.com/n624-dev/takupoke-ios/actions/runs/37917748832) | d8fb46e | 1 |
| 2026-10-09 | [配布前全体 343](https://github.com/n624-dev/takupoke-ios/actions/runs/37912704373) | aee12b6 | 2 |
| 2026-10-09 | [配布前全体 342](https://github.com/n624-dev/takupoke-ios/actions/runs/37905575598) | b676328 | 2 |
| 2026-10-09 | [通常UI診断 10](https://github.com/n624-dev/takupoke-ios/actions/runs/37901644546) | 405d6f1 | 1 |
| 2026-10-09 | [通常UI診断 9](https://github.com/n624-dev/takupoke-ios/actions/runs/37899596901) | 97ebe9a | 1 |
| 2026-10-09 | [通常UI診断 8](https://github.com/n624-dev/takupoke-ios/actions/runs/37897595908) | fe1e064 | 2 |
| 2026-10-09 | [テストツール 1](https://github.com/n624-dev/takupoke-ios/actions/runs/37895252244) | 698dac4 | 1 |
| 2026-10-09 | [通常UI診断 7](https://github.com/n624-dev/takupoke-ios/actions/runs/37893441851) | be3adf5 | 1 |
| 2026-10-09 | [配布前全体 340](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151) | e198f74 | 5 |
| 2026-10-09 | [配布前全体 339](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996) | dcaebf2 | 5 |
| 2026-10-08 | [配布前全体 327](https://github.com/n624-dev/takupoke-ios/actions/runs/37781627582) | e3d20ab | 4 |
| 2026-10-08 | [配布前全体 314](https://github.com/n624-dev/takupoke-ios/actions/runs/37749888072) | 5bf763b | 2 |
| 2026-10-08 | [通常UI診断 3](https://github.com/n624-dev/takupoke-ios/actions/runs/37736674883) | 20cc616 | 1 |
| 2026-10-08 | [通常UI診断 2](https://github.com/n624-dev/takupoke-ios/actions/runs/37734895217) | feac6b8 | 2 |
| 2026-10-08 | [架空OCR研究 25](https://github.com/n624-dev/takupoke-ios/actions/runs/37720750964) | a4138f7 | 1 |
| 2026-10-08 | [架空OCR研究 24](https://github.com/n624-dev/takupoke-ios/actions/runs/37720082636) | 5f3225f | 1 |
| 2026-10-08 | [架空OCR研究 18](https://github.com/n624-dev/takupoke-ios/actions/runs/37715457158) | 89ba11f | 1 |
| 2026-10-08 | [手動訂正診断 4](https://github.com/n624-dev/takupoke-ios/actions/runs/37714976724) | 5b815ae | 1 |
| 2026-10-08 | [手動訂正診断 3](https://github.com/n624-dev/takupoke-ios/actions/runs/37713451766) | 5e437e0 | 2 |
| 2026-10-08 | [手動訂正診断 2](https://github.com/n624-dev/takupoke-ios/actions/runs/37708947860) | 957706f | 1 |
| 2026-10-08 | [手動訂正診断 1](https://github.com/n624-dev/takupoke-ios/actions/runs/37706668488) | e65c37f | 1 |

## 文書リンクの不足を原ログで補足

実行ID／失敗ジョブIDへのリンクが既存文書にない9実行について、16ジョブの原ログを追加確認した。
過去に未調査だったという意味ではなく、照合時点でリンクから追跡できなかった範囲である。

| 対象 | 原ログで確認した停止 |
|---|---|
| 開発64・テストツール1 | Python検査は成功。その後のdiff-treeでファイル末尾の余分な空行を拒否。通知APIの失敗ではない |
| 開発48・50 | 実PDFの白・極薄CMYKの判定失敗。両SDKの失敗メタデータを確認し、27側の原ログを再取得。最終3e58684での修正とは分ける |
| 通常UI診断8・10 | AI/OCRの実Switch操作後、UIと保存値が期待どおり変化しない。通知許可要求前後の問題とは別 |
| 配布前339 | 両OSの行除外／設定の表示領域外、27の通知許可、26のリンクメニューが開かない失敗。全通常UI失敗を単一原因としない |
| 配布前340 | 26の授業詳細／設定、27の通知許可と手動訂正の待機切れ。配布ゲートは上流不合格を検出して停止 |
| 架空OCR研究24 | RecoveryVisionCaptureを参照できず、型検査でもコンパイル失敗。その後のID検査も失敗。OCR品質の失敗例に数えない |

通常UIの操作配送・表示領域・通知要求の分類は既存索引と一致した。
余分な空行と研究コンパイル不備は、事前のローカル確認で防げる実装・検証手順の不備である。
Apple環境でしか出ない実描画の違いと、Simulator許可の未返答を同じ対策で扱わない。
