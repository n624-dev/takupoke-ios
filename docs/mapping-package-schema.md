# 名称対応表ZIP schema案

この文書は、`takupoke-api` の認証付きAPIで配信するZIPの内部形式を定めるための下書きです。実資料・教員名・科目名・教室名・元ZIPはリポジトリに含めません。例は独立した架空値だけを使います。

## 対象と構成

初版は通常時間割PDFから分割済みの授業について、`subject`、`teacher`、`room` の記載名から詳細表示用の正式名称を引く。PDFの記載名は上書きせず、未一致のときは正式名称を設定しない。試験・返却PDF、学校行事、時間割変更XLSXには初版で適用しない。

ZIP直下のファイルは次の2件に固定する。サブディレクトリ、追加ファイル、同名重複、暗号化エントリ、シンボリックリンクは受け付けない。

```text
manifest.json
mappings.json
```

両方ともUTF-8のJSONとする。ZIPのバージョンはAPIの `X-Mapping-Version` と `manifest.json` の `version` で一致させる。ZIPの内容は一時領域で検証し、正常な版だけを採用する。

## manifest.json

```json
{
  "schemaVersion": 1,
  "version": "1",
  "publishedAt": "2032-01-02T03:04:05Z",
  "mappings": {
    "sha256": "<mappings.jsonのSHA-256を小文字16進数64文字で記載>",
    "bytes": 1234
  }
}
```

`publishedAt` はUTCのRFC 3339形式。`bytes` は `mappings.json` のUTF-8バイト数。取り込み時にバイト数とSHA-256を照合する。ZIP自体のSHA-256とAPIのETagは端末内の取得記録として別に保存する。

## mappings.json

```json
{
  "subjects": [
    { "alias": "架空科目A", "fullName": "架空の正式科目A" },
    { "alias": "架空科目B", "fullName": "架空の正式科目B", "classes": ["架空組1"] }
  ],
  "teachers": [
    { "alias": "架空教員A", "fullName": "架空の正式教員A" }
  ],
  "rooms": [
    { "alias": "架空教室A", "fullName": "架空の正式教室A" }
  ]
}
```

`alias` はPDF解析後の授業ごとの記載名と完全一致させる。`fullName` は `subjectFullName`、`teacherFullName`、`roomFullName` に使用する。`classes` は科目規則のみで任意とし、省略時は全クラスに適用する。指定した場合は空でない配列とし、PDF解析済みの `className` と完全一致させる。クラス付き規則が一致すれば全クラス用規則より優先し、同条件で異なる正式名称になる重複はパッケージ全体を拒否する。配列順に意味は持たせない。

空文字・空白だけの値、未知のフィールド、型違い、同条件での重複、異常に長い文字列は拒否する。検証時に勝手なUnicode正規化や空白除去を行わず、値は元データに確認済みの形で登録する。未一致・複数候補で一意にならない場合は推測せず、正式名称を設定しない。

## 採用・検証

元ZIPの `subject_alias.csv`、`teacher_alias.csv`、`room_alias.csv` から配布用JSONを生成する。時間割本体、学校行事、試験・返却、出典URL、備考、所属などの列は含めない。採用する `status` の範囲は利用者確認待ち。元データに正規表現の規則はないため、初版で正規表現を実装するかどうかも採用範囲と合わせて確定する。

iOSはZIP・JSONのファイル数とサイズ、schemaVersion、version、ハッシュ、規則の件数・型・重複を検証する。失敗した版は採用せず、前回正常版を保持する。正常な版を端末内へ原子的に切り替え、取得用ZIPと展開用一時ファイルを削除する。
