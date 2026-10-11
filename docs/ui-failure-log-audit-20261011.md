# 失敗原ログの照合一覧（2026-10-11）

GitHubに残るfailureの147実行と、失敗索引のcancelled・成功対照を含む154実行を照合した。
その最新試行にある失敗／timed_outの253ジョブの原ログを全件取得した。取得失敗0。
以下は停止の観測分類であり、下位原因の確定・修正完了を意味しない。
ビルド・研究・公開ゲート・実動作の失敗も含み、UIケース数や通知の失敗率へ転用しない。
XCTest失敗名0件は未実行成功を意味せず、準備停止・完了未記録・別の検証方式もある。
削除済み実行、過去の全再試行、索引外cancelledの網羅は示さない。

方針の再評価と比較済み条件は[通知UIの再評価](ui-notification-reassessment-20261011.md)、
個別ケースの詳細は[失敗索引](ui-test-failures.md)を参照する。
公開記録には本文・画像・Prompt・RecoveryResult・認証情報・原ログ全文をコピーしない。

| 実行／ジョブ原ログ | 対象 | 停止の観測 | XCTest失敗名数 |
|---|---|---|---:|
| [38120972871／114415615207](https://github.com/n624-dev/takupoke-ios/actions/runs/38120972871/job/114415615207) | Application iOS 27 UI B | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38116598744／114402796799](https://github.com/n624-dev/takupoke-ios/actions/runs/38116598744/job/114402796799) | Application iOS 26 UI B | Runner再起動（crash／timeout未確定） | 0 |
| [38116201187／114401469377](https://github.com/n624-dev/takupoke-ios/actions/runs/38116201187/job/114401469377) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38114822271／114397520767](https://github.com/n624-dev/takupoke-ios/actions/runs/38114822271/job/114397520767) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38113398465／114393417764](https://github.com/n624-dev/takupoke-ios/actions/runs/38113398465/job/114393417764) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38112276765／114390139488](https://github.com/n624-dev/takupoke-ios/actions/runs/38112276765/job/114390139488) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38111810296／114388890984](https://github.com/n624-dev/takupoke-ios/actions/runs/38111810296/job/114388890984) | Application iOS 27 UI B | ビルド／コンパイル失敗 | 0 |
| [38111810296／114388890989](https://github.com/n624-dev/takupoke-ios/actions/runs/38111810296/job/114388890989) | Application iOS 27 UI A | ビルド／コンパイル失敗 | 0 |
| [38110490234／114384843641](https://github.com/n624-dev/takupoke-ios/actions/runs/38110490234/job/114384843641) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38109734983／114382626520](https://github.com/n624-dev/takupoke-ios/actions/runs/38109734983/job/114382626520) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38109734983／114382626599](https://github.com/n624-dev/takupoke-ios/actions/runs/38109734983/job/114382626599) | Relaunch diagnosis iOS 26 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38109731687／114382614575](https://github.com/n624-dev/takupoke-ios/actions/runs/38109731687/job/114382614575) | Catalogue and test-runner contracts | 差分の末尾空行 | 0 |
| [38107075743／114374844570](https://github.com/n624-dev/takupoke-ios/actions/runs/38107075743/job/114374844570) | Application iOS 27 UI B | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38106669988／114373554664](https://github.com/n624-dev/takupoke-ios/actions/runs/38106669988/job/114373554664) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38081878973／114300313530](https://github.com/n624-dev/takupoke-ios/actions/runs/38081878973/job/114300313530) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38077539018／114287713301](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018/job/114287713301) | Application iOS 27 UI B | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38077539018／114287713351](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018/job/114287713351) | Application iOS 26 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38077539018／114287713398](https://github.com/n624-dev/takupoke-ios/actions/runs/38077539018/job/114287713398) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38075094896／114280469182](https://github.com/n624-dev/takupoke-ios/actions/runs/38075094896/job/114280469182) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [38075094896／114280469251](https://github.com/n624-dev/takupoke-ios/actions/runs/38075094896/job/114280469251) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38073321707／114275050342](https://github.com/n624-dev/takupoke-ios/actions/runs/38073321707/job/114275050342) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38068857906／114262118118](https://github.com/n624-dev/takupoke-ios/actions/runs/38068857906/job/114262118118) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38064917285／114250712952](https://github.com/n624-dev/takupoke-ios/actions/runs/38064917285/job/114250712952) | Application iOS 26 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38063910154／114247570955](https://github.com/n624-dev/takupoke-ios/actions/runs/38063910154/job/114247570955) | Development native PDF SDK 26 | ビルド／コンパイル失敗 | 0 |
| [38063910154／114247570976](https://github.com/n624-dev/takupoke-ios/actions/runs/38063910154/job/114247570976) | Development native PDF SDK 27 | ビルド／コンパイル失敗 | 0 |
| [38063910154／114247571027](https://github.com/n624-dev/takupoke-ios/actions/runs/38063910154/job/114247571027) | Development portable Swift checks | ビルド／コンパイル失敗 | 0 |
| [38063908274／114247562537](https://github.com/n624-dev/takupoke-ios/actions/runs/38063908274/job/114247562537) | Development portable Swift checks | ビルド／コンパイル失敗 | 0 |
| [38062088141／114242233236](https://github.com/n624-dev/takupoke-ios/actions/runs/38062088141/job/114242233236) | Development native PDF SDK 27 | XCTestケース失敗 | 1 |
| [38062088141／114242233259](https://github.com/n624-dev/takupoke-ios/actions/runs/38062088141/job/114242233259) | Development native PDF SDK 26 | XCTestケース失敗 | 1 |
| [38061329610／114240029455](https://github.com/n624-dev/takupoke-ios/actions/runs/38061329610/job/114240029455) | Development native PDF SDK 27 | XCTestケース失敗 | 4 |
| [38061329610／114240029487](https://github.com/n624-dev/takupoke-ios/actions/runs/38061329610/job/114240029487) | Development native PDF SDK 26 | XCTestケース失敗 | 4 |
| [38061090687／114239338866](https://github.com/n624-dev/takupoke-ios/actions/runs/38061090687/job/114239338866) | Development native PDF SDK 26 | ビルド／コンパイル失敗 | 0 |
| [38061090687／114239339016](https://github.com/n624-dev/takupoke-ios/actions/runs/38061090687/job/114239339016) | Development native PDF SDK 27 | ビルド／コンパイル失敗 | 0 |
| [38061090687／114239339115](https://github.com/n624-dev/takupoke-ios/actions/runs/38061090687/job/114239339115) | Development portable Swift checks | ビルド／コンパイル失敗 | 0 |
| [38061089643／114239333630](https://github.com/n624-dev/takupoke-ios/actions/runs/38061089643/job/114239333630) | Development portable Swift checks | ビルド／コンパイル失敗 | 0 |
| [38040538159／114179897970](https://github.com/n624-dev/takupoke-ios/actions/runs/38040538159/job/114179897970) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38036952573／114169411384](https://github.com/n624-dev/takupoke-ios/actions/runs/38036952573/job/114169411384) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [38033516782／114159252608](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252608) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [38033516782／114159252633](https://github.com/n624-dev/takupoke-ios/actions/runs/38033516782/job/114159252633) | Application iOS 27 UI B | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38030340274／114149898669](https://github.com/n624-dev/takupoke-ios/actions/runs/38030340274/job/114149898669) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [38030340274／114149898742](https://github.com/n624-dev/takupoke-ios/actions/runs/38030340274/job/114149898742) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [38025452042／114135377793](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042/job/114135377793) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [38025452042／114135377831](https://github.com/n624-dev/takupoke-ios/actions/runs/38025452042/job/114135377831) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [38023085810／114128234002](https://github.com/n624-dev/takupoke-ios/actions/runs/38023085810/job/114128234002) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [38021457932／114123316256](https://github.com/n624-dev/takupoke-ios/actions/runs/38021457932/job/114123316256) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [38020167906／114119203264](https://github.com/n624-dev/takupoke-ios/actions/runs/38020167906/job/114119203264) | Development native PDF SDK 26 | XCTestケース失敗 | 5 |
| [38020167906／114119203462](https://github.com/n624-dev/takupoke-ios/actions/runs/38020167906/job/114119203462) | Development native PDF SDK 27 | XCTestケース失敗 | 5 |
| [37978618022／113983147786](https://github.com/n624-dev/takupoke-ios/actions/runs/37978618022/job/113983147786) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 4 |
| [37978618022／113983147898](https://github.com/n624-dev/takupoke-ios/actions/runs/37978618022/job/113983147898) | Relaunch diagnosis iOS 26 | 通知を含むXCTest失敗（段階は索引参照） | 4 |
| [37976233485／113975130356](https://github.com/n624-dev/takupoke-ios/actions/runs/37976233485/job/113975130356) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37974710845／113969954387](https://github.com/n624-dev/takupoke-ios/actions/runs/37974710845/job/113969954387) | Relaunch diagnosis iOS 27 | Runner準備中の異常終了 | 0 |
| [37971894052／113960344778](https://github.com/n624-dev/takupoke-ios/actions/runs/37971894052/job/113960344778) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37966566030／113942302826](https://github.com/n624-dev/takupoke-ios/actions/runs/37966566030/job/113942302826) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [37957784144／113912938634](https://github.com/n624-dev/takupoke-ios/actions/runs/37957784144/job/113912938634) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37957784144／113912938676](https://github.com/n624-dev/takupoke-ios/actions/runs/37957784144/job/113912938676) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37957784144／113912938860](https://github.com/n624-dev/takupoke-ios/actions/runs/37957784144/job/113912938860) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37951761364／113892061970](https://github.com/n624-dev/takupoke-ios/actions/runs/37951761364/job/113892061970) | Relaunch diagnosis iOS 26 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37949136078／113883060978](https://github.com/n624-dev/takupoke-ios/actions/runs/37949136078/job/113883060978) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37945117177／113869284812](https://github.com/n624-dev/takupoke-ios/actions/runs/37945117177/job/113869284812) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37944069066／113865636007](https://github.com/n624-dev/takupoke-ios/actions/runs/37944069066/job/113865636007) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37934716695／113834112409](https://github.com/n624-dev/takupoke-ios/actions/runs/37934716695/job/113834112409) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37920921771／113788379955](https://github.com/n624-dev/takupoke-ios/actions/runs/37920921771/job/113788379955) | Relaunch diagnosis iOS 26 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37917748832／113777975641](https://github.com/n624-dev/takupoke-ios/actions/runs/37917748832/job/113777975641) | Relaunch diagnosis iOS 26 | XCTestケース失敗 | 1 |
| [37912704373／113761727937](https://github.com/n624-dev/takupoke-ios/actions/runs/37912704373/job/113761727937) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37912704373／113761729034](https://github.com/n624-dev/takupoke-ios/actions/runs/37912704373/job/113761729034) | Build and publish AltStore release | 上流不合格を公開ゲートで拒否 | 0 |
| [37905575598／113738365855](https://github.com/n624-dev/takupoke-ios/actions/runs/37905575598/job/113738365855) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37905575598／113738366255](https://github.com/n624-dev/takupoke-ios/actions/runs/37905575598/job/113738366255) | Build and publish AltStore release | 上流不合格を公開ゲートで拒否 | 0 |
| [37901644546／113725343429](https://github.com/n624-dev/takupoke-ios/actions/runs/37901644546/job/113725343429) | Relaunch diagnosis iOS 26 | XCTestケース失敗 | 1 |
| [37899596901／113718788966](https://github.com/n624-dev/takupoke-ios/actions/runs/37899596901/job/113718788966) | Relaunch diagnosis iOS 26 | XCTestケース失敗 | 1 |
| [37897595908／113712408950](https://github.com/n624-dev/takupoke-ios/actions/runs/37897595908/job/113712408950) | Relaunch diagnosis iOS 27 | XCTestケース失敗 | 1 |
| [37897595908／113712409379](https://github.com/n624-dev/takupoke-ios/actions/runs/37897595908/job/113712409379) | Relaunch diagnosis iOS 26 | XCTestケース失敗 | 1 |
| [37895252244／113705025557](https://github.com/n624-dev/takupoke-ios/actions/runs/37895252244/job/113705025557) | Catalogue and test-runner contracts | 差分の末尾空行 | 0 |
| [37893441851／113699297490](https://github.com/n624-dev/takupoke-ios/actions/runs/37893441851/job/113699297490) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37889545151／113687286706](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151/job/113687286706) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37889545151／113687286750](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151/job/113687286750) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37889545151／113687286798](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151/job/113687286798) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37889545151／113687286853](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151/job/113687286853) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37889545151／113687287367](https://github.com/n624-dev/takupoke-ios/actions/runs/37889545151/job/113687287367) | Build and publish AltStore release | 上流不合格を公開ゲートで拒否 | 0 |
| [37886485996／113677815027](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996/job/113677815027) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37886485996／113677815028](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996/job/113677815028) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 2 |
| [37886485996／113677815030](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996/job/113677815030) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37886485996／113677815210](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996/job/113677815210) | Build and publish AltStore release | 上流不合格を公開ゲートで拒否 | 0 |
| [37886485996／113677815472](https://github.com/n624-dev/takupoke-ios/actions/runs/37886485996/job/113677815472) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37884065885／113670195219](https://github.com/n624-dev/takupoke-ios/actions/runs/37884065885/job/113670195219) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37884065885／113670195285](https://github.com/n624-dev/takupoke-ios/actions/runs/37884065885/job/113670195285) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37789317942／113352487436](https://github.com/n624-dev/takupoke-ios/actions/runs/37789317942/job/113352487436) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37789317942／113352487803](https://github.com/n624-dev/takupoke-ios/actions/runs/37789317942/job/113352487803) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37781627582／113326217076](https://github.com/n624-dev/takupoke-ios/actions/runs/37781627582/job/113326217076) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37781627582／113326217091](https://github.com/n624-dev/takupoke-ios/actions/runs/37781627582/job/113326217091) | Application iOS 26 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37781627582／113326217362](https://github.com/n624-dev/takupoke-ios/actions/runs/37781627582/job/113326217362) | 手動訂正 27 | Runner準備中の異常終了 | 0 |
| [37781627582／113326217552](https://github.com/n624-dev/takupoke-ios/actions/runs/37781627582/job/113326217552) | Application iOS 27 UI A | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37749888072／113220507361](https://github.com/n624-dev/takupoke-ios/actions/runs/37749888072/job/113220507361) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37749888072／113220507571](https://github.com/n624-dev/takupoke-ios/actions/runs/37749888072/job/113220507571) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37736674883／113177675424](https://github.com/n624-dev/takupoke-ios/actions/runs/37736674883/job/113177675424) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37734895217／113172092198](https://github.com/n624-dev/takupoke-ios/actions/runs/37734895217/job/113172092198) | Relaunch diagnosis iOS 26 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37734895217／113172092577](https://github.com/n624-dev/takupoke-ios/actions/runs/37734895217/job/113172092577) | Relaunch diagnosis iOS 27 | 通知を含むXCTest失敗（段階は索引参照） | 1 |
| [37720750964／113127567647](https://github.com/n624-dev/takupoke-ios/actions/runs/37720750964/job/113127567647) | observe | 検証・公開スクリプトの例外 | 0 |
| [37720082636／113125492897](https://github.com/n624-dev/takupoke-ios/actions/runs/37720082636/job/113125492897) | observe | ビルド／コンパイル失敗 | 0 |
| [37715457158／113110775108](https://github.com/n624-dev/takupoke-ios/actions/runs/37715457158/job/113110775108) | observe | XCTestケース失敗 | 1 |
| [37714976724／113109284216](https://github.com/n624-dev/takupoke-ios/actions/runs/37714976724/job/113109284216) | Native input iOS 26 | XCTestケース失敗 | 1 |
| [37713451766／113104442232](https://github.com/n624-dev/takupoke-ios/actions/runs/37713451766/job/113104442232) | Native input iOS 27 | XCTestケース失敗 | 1 |
| [37713451766／113104442475](https://github.com/n624-dev/takupoke-ios/actions/runs/37713451766/job/113104442475) | Native input iOS 26 | XCTestケース失敗 | 1 |
| [37708947860／113090006780](https://github.com/n624-dev/takupoke-ios/actions/runs/37708947860/job/113090006780) | Native input iOS 26 | XCTestケース失敗 | 1 |
| [37706668488／113082554517](https://github.com/n624-dev/takupoke-ios/actions/runs/37706668488/job/113082554517) | Native input iOS 26 | XCTestケース失敗 | 1 |
| [37687961129／113020550919](https://github.com/n624-dev/takupoke-ios/actions/runs/37687961129/job/113020550919) | observe | ビルド／コンパイル失敗 | 0 |
| [37670677438／112990028140](https://github.com/n624-dev/takupoke-ios/actions/runs/37670677438/job/112990028140) | 手動訂正 26 | XCTestケース失敗 | 1 |
| [37669563234／112957497079](https://github.com/n624-dev/takupoke-ios/actions/runs/37669563234/job/112957497079) | Native PDFKit and ordered-row regression | 検証準備／生成契約の拒否 | 0 |
| [37624630580／112803161706](https://github.com/n624-dev/takupoke-ios/actions/runs/37624630580/job/112803161706) | Publish previously verified development build | 検証・公開スクリプトの例外 | 0 |
| [37389689760／112031934208](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934208) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37389689760／112031934214](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934214) | Application iOS 26 UI B | ビルド／コンパイル失敗 | 0 |
| [37389689760／112031934215](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934215) | 手動訂正 26 | ビルド／コンパイル失敗 | 0 |
| [37389689760／112031934219](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934219) | 手動訂正 26 | ビルド／コンパイル失敗 | 0 |
| [37389689760／112031934256](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934256) | 手動訂正 26 | ビルド／コンパイル失敗 | 0 |
| [37389689760／112031934327](https://github.com/n624-dev/takupoke-ios/actions/runs/37389689760/job/112031934327) | Application iOS 26 UI A | ビルド／コンパイル失敗 | 0 |
| [37388066573／112026289802](https://github.com/n624-dev/takupoke-ios/actions/runs/37388066573/job/112026289802) | Native hierarchy iPhone SDK 26 | 研究の実行・観測契約失敗 | 0 |
| [37384030256／112013495261](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495261) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [37384030256／112013495484](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495484) | 手動訂正 26 | XCTestケース失敗 | 1 |
| [37384030256／112013495494](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495494) | 手動訂正 26 | XCTestケース失敗 | 1 |
| [37384030256／112013495510](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495510) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37384030256／112013495553](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495553) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37384030256／112013495563](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495563) | 手動訂正 27 | XCTestケース失敗 | 1 |
| [37384030256／112013495663](https://github.com/n624-dev/takupoke-ios/actions/runs/37384030256/job/112013495663) | 手動訂正 26 | XCTestケース失敗 | 1 |
| [37383392714／112010676353](https://github.com/n624-dev/takupoke-ios/actions/runs/37383392714/job/112010676353) | Native hierarchy iPhone SDK 26 | 研究の実行・観測契約失敗 | 0 |
| [37382196083／112006691867](https://github.com/n624-dev/takupoke-ios/actions/runs/37382196083/job/112006691867) | Native hierarchy iPhone SDK 26 | 研究の実行・観測契約失敗 | 0 |
| [37377788271／111991423120](https://github.com/n624-dev/takupoke-ios/actions/runs/37377788271/job/111991423120) | Native hierarchy iPhone SDK 26 | 研究の実行・観測契約失敗 | 0 |
| [37342290982／111872088510](https://github.com/n624-dev/takupoke-ios/actions/runs/37342290982/job/111872088510) | Native hierarchy iPhone SDK 26 | 研究の実行・観測契約失敗 | 0 |
| [37304523082／111744883333](https://github.com/n624-dev/takupoke-ios/actions/runs/37304523082/job/111744883333) | Fictional manual QA iOS 26 | XCTestケース失敗 | 2 |
| [37300248837／111730987596](https://github.com/n624-dev/takupoke-ios/actions/runs/37300248837/job/111730987596) | Fictional manual QA iOS 26 | XCTestケース失敗 | 1 |
| [37294836772／111713496805](https://github.com/n624-dev/takupoke-ios/actions/runs/37294836772/job/111713496805) | Fictional manual QA iOS 26 | XCTestケース失敗 | 3 |
| [37275854271／111652590637](https://github.com/n624-dev/takupoke-ios/actions/runs/37275854271/job/111652590637) | Fictional manual QA iOS 26 | XCTestケース失敗 | 2 |
| [37273218933／111644489801](https://github.com/n624-dev/takupoke-ios/actions/runs/37273218933/job/111644489801) | Fictional manual QA iOS 26 | XCTestケース失敗 | 3 |
| [37271141856／111638186205](https://github.com/n624-dev/takupoke-ios/actions/runs/37271141856/job/111638186205) | Fictional manual QA iOS 26 | XCTestケース失敗 | 3 |
| [37270491934／111636248313](https://github.com/n624-dev/takupoke-ios/actions/runs/37270491934/job/111636248313) | Fictional manual QA iOS 26 | ビルド／コンパイル失敗 | 0 |
| [37268753019／111631053781](https://github.com/n624-dev/takupoke-ios/actions/runs/37268753019/job/111631053781) | Fictional manual QA iOS 26 | XCTestケース失敗 | 3 |
| [37262352451／111612088567](https://github.com/n624-dev/takupoke-ios/actions/runs/37262352451/job/111612088567) | Native PDF and recovery tests | ビルド／コンパイル失敗 | 0 |
| [37262352451／111612088592](https://github.com/n624-dev/takupoke-ios/actions/runs/37262352451/job/111612088592) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [37262352451／111612088645](https://github.com/n624-dev/takupoke-ios/actions/runs/37262352451/job/111612088645) | Application iOS 27 UI A | XCTestケース失敗 | 3 |
| [37262352451／111612088690](https://github.com/n624-dev/takupoke-ios/actions/runs/37262352451/job/111612088690) | Application iOS 26 UI A | ビルド／コンパイル失敗 | 0 |
| [37252243938／111582086334](https://github.com/n624-dev/takupoke-ios/actions/runs/37252243938/job/111582086334) | native-acquisition | 検証準備／生成契約の拒否 | 0 |
| [37222078243／111494323324](https://github.com/n624-dev/takupoke-ios/actions/runs/37222078243/job/111494323324) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [37221400765／111492318014](https://github.com/n624-dev/takupoke-ios/actions/runs/37221400765/job/111492318014) | native-acquisition | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404039553](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404039553) | candidate (qwen3-06) | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404039622](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404039622) | candidate (phi35-mini) | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404039665](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404039665) | candidate (qwen25-15) | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404039704](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404039704) | candidate (smollm3-3) | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404039986](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404039986) | candidate (granite4-1) | ビルド／コンパイル失敗 | 0 |
| [37191355813／111404040006](https://github.com/n624-dev/takupoke-ios/actions/runs/37191355813/job/111404040006) | candidate (ministral3-3) | ビルド／コンパイル失敗 | 0 |
| [37189271515／111397862051](https://github.com/n624-dev/takupoke-ios/actions/runs/37189271515/job/111397862051) | native-simulator | ビルド／コンパイル失敗 | 0 |
| [37187163969／111391448725](https://github.com/n624-dev/takupoke-ios/actions/runs/37187163969/job/111391448725) | research-build | 研究用Releaseの取得404 | 0 |
| [37176295919／111359512600](https://github.com/n624-dev/takupoke-ios/actions/runs/37176295919/job/111359512600) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37150245688／111282472250](https://github.com/n624-dev/takupoke-ios/actions/runs/37150245688/job/111282472250) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [37150245688／111282472424](https://github.com/n624-dev/takupoke-ios/actions/runs/37150245688/job/111282472424) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37145351175／111268066711](https://github.com/n624-dev/takupoke-ios/actions/runs/37145351175/job/111268066711) | Application iOS 27 UI A | XCTestケース失敗 | 1 |
| [37145351175／111268066758](https://github.com/n624-dev/takupoke-ios/actions/runs/37145351175/job/111268066758) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37142926132／111260935902](https://github.com/n624-dev/takupoke-ios/actions/runs/37142926132/job/111260935902) | Application iOS 27 UI A | XCTestケース失敗 | 1 |
| [37142926132／111260935909](https://github.com/n624-dev/takupoke-ios/actions/runs/37142926132/job/111260935909) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37142926132／111260935915](https://github.com/n624-dev/takupoke-ios/actions/runs/37142926132/job/111260935915) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37140790840／111254668349](https://github.com/n624-dev/takupoke-ios/actions/runs/37140790840/job/111254668349) | Native PDF and recovery tests | XCTestケース失敗 | 1 |
| [37140790840／111254668397](https://github.com/n624-dev/takupoke-ios/actions/runs/37140790840/job/111254668397) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [37137936151／111246236342](https://github.com/n624-dev/takupoke-ios/actions/runs/37137936151/job/111246236342) | Native PDF and recovery tests | XCTestケース失敗 | 1 |
| [37137936151／111246236366](https://github.com/n624-dev/takupoke-ios/actions/runs/37137936151/job/111246236366) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [37136463675／111241935275](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935275) | Application iOS 26 UI A | 検証準備／生成契約の拒否 | 0 |
| [37136463675／111241935290](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935290) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [37136463675／111241935309](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935309) | Application iOS 27 UI B | 検証準備／生成契約の拒否 | 0 |
| [37136463675／111241935319](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935319) | Application iOS 27 UI A | 検証準備／生成契約の拒否 | 0 |
| [37136463675／111241935335](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935335) | Native PDF and recovery tests | XCTestケース失敗 | 1 |
| [37136463675／111241935347](https://github.com/n624-dev/takupoke-ios/actions/runs/37136463675/job/111241935347) | Application iOS 26 UI B | 検証準備／生成契約の拒否 | 0 |
| [37135408181／111238863102](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863102) | Application iOS 27 UI A | 検証準備／生成契約の拒否 | 0 |
| [37135408181／111238863117](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863117) | Native PDF and recovery tests | XCTestケース失敗 | 6 |
| [37135408181／111238863119](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863119) | Check iPhone build without publishing | XCTestケース失敗 | 6 |
| [37135408181／111238863191](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863191) | Application iOS 27 UI B | 検証準備／生成契約の拒否 | 0 |
| [37135408181／111238863209](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863209) | Application iOS 26 UI A | 検証準備／生成契約の拒否 | 0 |
| [37135408181／111238863229](https://github.com/n624-dev/takupoke-ios/actions/runs/37135408181/job/111238863229) | Application iOS 26 UI B | 検証準備／生成契約の拒否 | 0 |
| [37134240617／111235418870](https://github.com/n624-dev/takupoke-ios/actions/runs/37134240617/job/111235418870) | Check iPhone build without publishing | XCTestケース失敗 | 5 |
| [37134240617／111235418871](https://github.com/n624-dev/takupoke-ios/actions/runs/37134240617/job/111235418871) | Native PDF and recovery tests | XCTestケース失敗 | 5 |
| [37134240617／111235418898](https://github.com/n624-dev/takupoke-ios/actions/runs/37134240617/job/111235418898) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37133926963／111234480307](https://github.com/n624-dev/takupoke-ios/actions/runs/37133926963/job/111234480307) | Native PDF and recovery tests | ビルド／コンパイル失敗 | 0 |
| [37133926963／111234480334](https://github.com/n624-dev/takupoke-ios/actions/runs/37133926963/job/111234480334) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [37132326788／111229762333](https://github.com/n624-dev/takupoke-ios/actions/runs/37132326788/job/111229762333) | Native PDF and recovery tests | XCTestケース失敗 | 5 |
| [37132326788／111229762349](https://github.com/n624-dev/takupoke-ios/actions/runs/37132326788/job/111229762349) | Check iPhone build without publishing | XCTestケース失敗 | 5 |
| [37132326788／111229762413](https://github.com/n624-dev/takupoke-ios/actions/runs/37132326788/job/111229762413) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37123390574／111203796389](https://github.com/n624-dev/takupoke-ios/actions/runs/37123390574/job/111203796389) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37121488766／111198339817](https://github.com/n624-dev/takupoke-ios/actions/runs/37121488766/job/111198339817) | Application iOS 27 UI A | ビルド／コンパイル失敗 | 0 |
| [37121488766／111198339837](https://github.com/n624-dev/takupoke-ios/actions/runs/37121488766/job/111198339837) | Application iOS 27 UI B | ビルド／コンパイル失敗 | 0 |
| [37121488766／111198339911](https://github.com/n624-dev/takupoke-ios/actions/runs/37121488766/job/111198339911) | Application iOS 26 UI B | ビルド／コンパイル失敗 | 0 |
| [37121488766／111198339945](https://github.com/n624-dev/takupoke-ios/actions/runs/37121488766/job/111198339945) | Application iOS 26 UI A | ビルド／コンパイル失敗 | 0 |
| [37119704782／111193306783](https://github.com/n624-dev/takupoke-ios/actions/runs/37119704782/job/111193306783) | Application iOS 27 UI A | XCTestケース失敗 | 1 |
| [37119704782／111193306804](https://github.com/n624-dev/takupoke-ios/actions/runs/37119704782/job/111193306804) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37119704782／111193306811](https://github.com/n624-dev/takupoke-ios/actions/runs/37119704782/job/111193306811) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37119704782／111193306816](https://github.com/n624-dev/takupoke-ios/actions/runs/37119704782/job/111193306816) | Application iOS 26 UI B | XCTestケース失敗 | 2 |
| [37119068100／111191515852](https://github.com/n624-dev/takupoke-ios/actions/runs/37119068100/job/111191515852) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [37119068100／111191515859](https://github.com/n624-dev/takupoke-ios/actions/runs/37119068100/job/111191515859) | Application iOS 26 UI A | XCTestケース失敗 | 1 |
| [37119068100／111191515871](https://github.com/n624-dev/takupoke-ios/actions/runs/37119068100/job/111191515871) | Application iOS 26 UI B | XCTestケース失敗 | 1 |
| [37119068100／111191515878](https://github.com/n624-dev/takupoke-ios/actions/runs/37119068100/job/111191515878) | Application iOS 27 UI A | XCTestケース失敗 | 1 |
| [37119068100／111191515902](https://github.com/n624-dev/takupoke-ios/actions/runs/37119068100/job/111191515902) | Application iOS 27 UI B | XCTestケース失敗 | 1 |
| [37116939582／111185490373](https://github.com/n624-dev/takupoke-ios/actions/runs/37116939582/job/111185490373) | Application iOS 26 UI A | XCTestケース失敗 | 2 |
| [37116939582／111185490380](https://github.com/n624-dev/takupoke-ios/actions/runs/37116939582/job/111185490380) | Application iOS 27 UI A | XCTestケース失敗 | 2 |
| [37116939582／111185490384](https://github.com/n624-dev/takupoke-ios/actions/runs/37116939582/job/111185490384) | Application iOS 27 UI B | XCTestケース失敗 | 2 |
| [37116939582／111185490391](https://github.com/n624-dev/takupoke-ios/actions/runs/37116939582/job/111185490391) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [37116939582／111185490417](https://github.com/n624-dev/takupoke-ios/actions/runs/37116939582/job/111185490417) | Application iOS 26 UI B | XCTestケース失敗 | 2 |
| [36951180437／110664356792](https://github.com/n624-dev/takupoke-ios/actions/runs/36951180437/job/110664356792) | Build and publish AltStore release | XCTestケース失敗 | 1 |
| [36850211378／110329849314](https://github.com/n624-dev/takupoke-ios/actions/runs/36850211378/job/110329849314) | 通常UI 27 | XCTestケース失敗 | 2 |
| [36850211378／110329849356](https://github.com/n624-dev/takupoke-ios/actions/runs/36850211378/job/110329849356) | 通常UI 26 | XCTestケース失敗 | 2 |
| [36847785068／110322021487](https://github.com/n624-dev/takupoke-ios/actions/runs/36847785068/job/110322021487) | 通常UI 27 | XCTestケース失敗 | 1 |
| [36847785068／110322021549](https://github.com/n624-dev/takupoke-ios/actions/runs/36847785068/job/110322021549) | 通常UI 26 | XCTestケース失敗 | 1 |
| [36846275422／110317119763](https://github.com/n624-dev/takupoke-ios/actions/runs/36846275422/job/110317119763) | 通常UI 26 | XCTestケース失敗 | 1 |
| [36846275422／110317119850](https://github.com/n624-dev/takupoke-ios/actions/runs/36846275422/job/110317119850) | 通常UI 27 | XCTestケース失敗 | 1 |
| [36843033665／110306427421](https://github.com/n624-dev/takupoke-ios/actions/runs/36843033665/job/110306427421) | 通常UI 27 | XCTestケース失敗 | 3 |
| [36843033665／110306427422](https://github.com/n624-dev/takupoke-ios/actions/runs/36843033665/job/110306427422) | 通常UI 26 | XCTestケース失敗 | 3 |
| [36744835061／109988326131](https://github.com/n624-dev/takupoke-ios/actions/runs/36744835061/job/109988326131) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [36744835061／109988326136](https://github.com/n624-dev/takupoke-ios/actions/runs/36744835061/job/109988326136) | 通常UI 27 | XCTestケース失敗 | 1 |
| [36744835061／109988326355](https://github.com/n624-dev/takupoke-ios/actions/runs/36744835061/job/109988326355) | 通常UI 26 | XCTestケース失敗 | 1 |
| [36740533416／109973504982](https://github.com/n624-dev/takupoke-ios/actions/runs/36740533416/job/109973504982) | 通常UI 26 | XCTestケース失敗 | 5 |
| [36740533416／109973505022](https://github.com/n624-dev/takupoke-ios/actions/runs/36740533416/job/109973505022) | 通常UI 27 | XCTestケース失敗 | 5 |
| [36736422789／109959558169](https://github.com/n624-dev/takupoke-ios/actions/runs/36736422789/job/109959558169) | 通常UI 26 | XCTestケース失敗 | 3 |
| [36736422789／109959558204](https://github.com/n624-dev/takupoke-ios/actions/runs/36736422789/job/109959558204) | 通常UI 27 | XCTestケース失敗 | 4 |
| [36723626107／109914842480](https://github.com/n624-dev/takupoke-ios/actions/runs/36723626107/job/109914842480) | 通常UI 27 | 通知を含むXCTest失敗（段階は索引参照） | 3 |
| [36723626107／109914842634](https://github.com/n624-dev/takupoke-ios/actions/runs/36723626107/job/109914842634) | 通常UI 26 | 通知を含むXCTest失敗（段階は索引参照） | 3 |
| [36722259115／109910142216](https://github.com/n624-dev/takupoke-ios/actions/runs/36722259115/job/109910142216) | 通常UI 27 | ビルド／コンパイル失敗 | 0 |
| [36722259115／109910142263](https://github.com/n624-dev/takupoke-ios/actions/runs/36722259115/job/109910142263) | 通常UI 26 | ビルド／コンパイル失敗 | 0 |
| [36716586853／109890955337](https://github.com/n624-dev/takupoke-ios/actions/runs/36716586853/job/109890955337) | 通常UI 26 | 通知を含むXCTest失敗（段階は索引参照） | 6 |
| [36716586853／109890955499](https://github.com/n624-dev/takupoke-ios/actions/runs/36716586853/job/109890955499) | 通常UI 27 | 通知を含むXCTest失敗（段階は索引参照） | 7 |
| [36714287291／109883815444](https://github.com/n624-dev/takupoke-ios/actions/runs/36714287291/job/109883815444) | 通常UI 旧構成 | 通知を含むXCTest失敗（段階は索引参照） | 9 |
| [36713968474／109882033447](https://github.com/n624-dev/takupoke-ios/actions/runs/36713968474/job/109882033447) | 通常UI 旧構成 | 通知を含むXCTest失敗（段階は索引参照） | 9 |
| [36711919793／109875566589](https://github.com/n624-dev/takupoke-ios/actions/runs/36711919793/job/109875566589) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [36711779654／109875165516](https://github.com/n624-dev/takupoke-ios/actions/runs/36711779654/job/109875165516) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [36645632642／109667853564](https://github.com/n624-dev/takupoke-ios/actions/runs/36645632642/job/109667853564) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [36644409233／109663966191](https://github.com/n624-dev/takupoke-ios/actions/runs/36644409233/job/109663966191) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [36643136576／109659887828](https://github.com/n624-dev/takupoke-ios/actions/runs/36643136576/job/109659887828) | Check iPhone build without publishing | XCTestケース失敗 | 2 |
| [36641998281／109656218876](https://github.com/n624-dev/takupoke-ios/actions/runs/36641998281/job/109656218876) | Check iPhone build without publishing | XCTestケース失敗 | 2 |
| [36641648287／109655272782](https://github.com/n624-dev/takupoke-ios/actions/runs/36641648287/job/109655272782) | Check iPhone build without publishing | XCTestケース失敗 | 2 |
| [36641070568／109653253715](https://github.com/n624-dev/takupoke-ios/actions/runs/36641070568/job/109653253715) | Check iPhone build without publishing | XCTestケース失敗 | 1 |
| [36578787074／109441241952](https://github.com/n624-dev/takupoke-ios/actions/runs/36578787074/job/109441241952) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36577462853／109436775036](https://github.com/n624-dev/takupoke-ios/actions/runs/36577462853/job/109436775036) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36575943581／109431521978](https://github.com/n624-dev/takupoke-ios/actions/runs/36575943581/job/109431521978) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36568022368／109404747190](https://github.com/n624-dev/takupoke-ios/actions/runs/36568022368/job/109404747190) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36566968582／109401205128](https://github.com/n624-dev/takupoke-ios/actions/runs/36566968582/job/109401205128) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36566215649／109398711204](https://github.com/n624-dev/takupoke-ios/actions/runs/36566215649/job/109398711204) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36565131134／109395541755](https://github.com/n624-dev/takupoke-ios/actions/runs/36565131134/job/109395541755) | Check iPhone build without publishing | Picker実動作／待機失敗 | 0 |
| [36315252358／108608650161](https://github.com/n624-dev/takupoke-ios/actions/runs/36315252358/job/108608650161) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [36228669231／108367485999](https://github.com/n624-dev/takupoke-ios/actions/runs/36228669231/job/108367485999) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [36223451509／108352930552](https://github.com/n624-dev/takupoke-ios/actions/runs/36223451509/job/108352930552) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [36093386181／107940397082](https://github.com/n624-dev/takupoke-ios/actions/runs/36093386181/job/107940397082) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [35966215296／107525282201](https://github.com/n624-dev/takupoke-ios/actions/runs/35966215296/job/107525282201) | Check iPhone build without publishing | XCTestケース失敗 | 2 |
| [35965999795／107524627011](https://github.com/n624-dev/takupoke-ios/actions/runs/35965999795/job/107524627011) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [35965210589／107522193185](https://github.com/n624-dev/takupoke-ios/actions/runs/35965210589/job/107522193185) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [35964957764／107521419074](https://github.com/n624-dev/takupoke-ios/actions/runs/35964957764/job/107521419074) | Check iPhone build without publishing | ビルド／コンパイル失敗 | 0 |
| [35860881240／107180635499](https://github.com/n624-dev/takupoke-ios/actions/runs/35860881240/job/107180635499) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
| [35822048029／107055820354](https://github.com/n624-dev/takupoke-ios/actions/runs/35822048029/job/107055820354) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
| [35505056621／106063360541](https://github.com/n624-dev/takupoke-ios/actions/runs/35505056621/job/106063360541) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
| [35484499497／106008280950](https://github.com/n624-dev/takupoke-ios/actions/runs/35484499497/job/106008280950) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
| [35438525503／105885231267](https://github.com/n624-dev/takupoke-ios/actions/runs/35438525503/job/105885231267) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
| [35430150981／105863171009](https://github.com/n624-dev/takupoke-ios/actions/runs/35430150981/job/105863171009) | Build and publish AltStore release | ビルド／コンパイル失敗 | 0 |
