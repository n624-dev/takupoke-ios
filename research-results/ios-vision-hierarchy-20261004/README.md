# iOS Vision：全文・表・候補の詳細確認（2026-10-04）

原文の「3」は全10ページで正しい時限位置に残っていました。5〜8時限は、記録した全文・表のセル・行・上位候補の該当位置には見つかりませんでした。表を辿っても、従来の global top1 から増えた正しい時限はありません。この2資料について、表からの取り出し不足だけで欠落を解決できるという仮説は支持されませんでした。

[実行37209476528](https://github.com/n624-dev/takupoke-ios/actions/runs/37209476528) は source `6fe7d66f64b5cd26484d629a3304e95bb4510631`、job `111457538837` で成功しました。Apple SDKのコンパイルは修正なしで成功。取得戻り・記録完了・対象文字階層の捕捉完了は10/10、打切りと実行エラーは0です。正式な復旧、原文インクの全量対応、空欄証明、class/day/period/科目/担当/教室の完全な紐付けは未評価です。品質合格とはしていません。

| 診断対象 | 結果 |
|---|---:|
| 原文の時限位置 | 80 |
| global top1で位置まで一致 | 33 |
| 表・セルを含むtop1で位置まで一致 | 33 |
| top5も含めて位置まで一致 | 33 |
| 追加候補や表による増加 | 0 |
| 正しい時限のうち元の0.85以上・文字矩形条件を通過 | 2 |
| 同じ実行の従来global top1と独立queryの一致 | 79/79 |

時限ごとの存在数は1が7/10、2が10/10、3が10/10、4が6/10、5〜8は各0/10でした。正しい33件の残り31件は信頼度0.85未満です。通過した2件は丙の2・4ページの「2」（confidence `0.8729578853`）。これは取得後の条件診断であり、実際の`.layouts`や正式復旧を実行した結果ではありません。

全ページで表1個・9列が返りました。時限に対応するセルは記録しましたが、欠けた時限のセル内容は空でした。空の認識セルは原画像が空である証拠になりません。native row/columnRangeはそのまま保存し、時限番号として読み替えたり、1〜8を補ったりしていません。科目などの文字が読めても、担当がlabel-onlyであることからEMPTYを確定しません。

同じ原2PDFと10PNGを使い、productionからbyte-exactに抽出した`.read`本文、default `RecognizeDocumentsRequest()`、描画規則、SDK、信頼度条件は変更していません。1ページにつき1回のnative request、合計10回です。前回の[簡易観測](../ios-vision-acquisition-20261004/README.md)と全10ページの従来global top1記録は同一でした。今回の追加は観測用accessorだけです。top1を独立取得してからtop5を記録し、全対象でtop1とtop5.firstの文字・信頼度は一致しました。候補は自動採用していません。

位置判定は原PNGの物理時限セル（x=`96+116*(period−1)`から116px、y=60〜90px）へnative文字矩形の中心を戻した診断です。年度・class・教室に含まれる数字や、位置不明の全文substringを時限の存在数に含めません。実描画は乙984×197、丙984×201、原PNGは1025×206/210でした。描画後pixel自体は保存していないため、レンダラと認識器の原因を分離できません。

取得済み文字階層の範囲はtext/title/paragraph/table.rows.cell.content/list.items.content、各transcript/line/top1/top5/文字boxです。barcode payload、DataDetectorMatch metadata、独立column traversal、top5を超える潜在候補は対象外です。全10ページでこの対象範囲の打切りはありませんが、すべての内部認識や全原文インクを捕捉したという意味ではありません。「未認識のモデル能力が原因」とは断定できません。現在確かめられたのは、対象accessorへの出力欠落と、正しい文字にも低いconfidenceが付く現象です。

実機ではなくiPhone14のiOS27シミュレータで測定しました。ホストはApple M1 (Virtual)、3 logical CPU、RAM 7GiB、Xcode27.0、SDK27.0。native実行時間は105.593秒（観測処理を含む）。実機の必要メモリや速度、OCR engine単独の比較には使えません。入力は完全に架空の既消費development controlsで、未使用holdoutではありません。新モデル・LLM・プロンプト・学習・学校データは使用していません。

`raw-evidence.json` はnative JSONL（1,683,713bytes/SHA `0c21d705c253bcc98ef25ca717c6005bc6bd0c3cb753bada12c93104909b840d`）とfull job log（1,742,953bytes/SHA `d5044e3fc31702e2bfa8928cf8fbd7e640bb17d30358f45aa376ce98e56d87a4`）の全byteをzlib+base64で保存しています。これは保存容量を減らすだけで、認識入力・出力を加工していません。`results.json`は実行・集計、`header-evidence.json`は80位置すべて、`ten-page-causes.json`は各ページの段階原因、`independent-review.json`は原PNG罫線から別に位置を再計算した確認です。

次のコマンドでこのフォルダだけからrawのSHAを検証して位置一覧を再生成できます。native OCRは呼びません。

```sh
python3 analyze.py
```

元の全文を取り出す場合は以下を使います。全byteのSHAとサイズを検証してから書き出します。

```python
import base64, hashlib, json, pathlib, zlib
for item in json.loads(pathlib.Path('raw-evidence.json').read_text(encoding='utf-8'))['files']:
    raw = zlib.decompress(base64.b64decode(item['data'], validate=True))
    assert len(raw) == item['uncompressedBytes']
    assert hashlib.sha256(raw).hexdigest() == item['sha256']
    pathlib.Path(item['name']).write_bytes(raw)
```
