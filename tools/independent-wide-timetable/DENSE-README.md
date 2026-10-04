# 独立した密度・文字色の比較資料

既存の wide v1 本体・期待値・座標を変更せず、別の `generate_dense.py` で 1450×990（比率約1.46）の新しい配置を組み立てる。曜日5群×8時限、17クラス、結合・並記・空欄を含む同じ完全架空授業680枠を、32ptの時限幅と47ptの行高に置く。内容は seed `20320819` で独立生成済みの「架空科目…／架空教員…／架空室…」だけ。学校原本・私的画像・原本フォントは読まない。

ラベルなし本体とラベル付きcontrolを分け、各々に黒文字と濃い別色のvariantを作る。別色は独立seed `704893` が選んだ12文字だけのRGB `(0.02, 0.04, 0.12)`。色選択に期待roleやOCR結果を使わない。黒・色の両方を同じ文字単位の描画命令で作り、文字の分割と色の差を混同しない。新しい値を期待値から復元する処理はない。

```bash
python3 -B tools/independent-wide-timetable/test_dense_generator.py
python3 -B tools/independent-wide-timetable/generate_dense.py \
  --source-root . --output /tmp/unique-owned-dense-timetable \
  --font-file /tmp/pinned-public-font.ttf
```

公開フォントとライセンスの固定SHAは元generatorと同じ。PDF・フォント・画像のバイナリはGitに入れず、所有印付き一時出力だけを使用後に削除する。出力manifestと `dense-artifact-pins.json` がPDFの固定SHAを示す。期待JSONは既存の完全架空680枠とbyte同一の `efdcb749…ce191` で、Reader／Builderへの入力には渡さない。

2件の設計チェックと2回の生成での4PDF byte再現、および公開PyMuPDFでの黒・色の文字／座標一致はgeneratorの検査に限る。各OSの実Reader・Strict／Recovery・正式授業全体の成功は別の実測結果である。濃い色の可視性guardを緩和せず、Readerが拒否する場合は未対応として記録する。control成功はラベルなし本体成功を意味せず、このvector比較は画像OCRや追加AIモデルの品質合格も証明しない。
