# 名称対応表の配信・接続

通常時間割PDFの記載名から正式名称への対応表を、認証付きの `takupoke-api` から取得します。iOSはPDF解析結果を書き換えず、授業詳細の表示時に保存済み対応表を適用します。時間割変更XLSXでは表示時だけ末尾括弧の教員・教室と正式名を照合します。試験・返却PDF、学校行事の解析結果は書き換えません。

## 更新確認と認証

- 起動時は公開 `GET https://takupoke-api.n624.jp/mapping-revision` だけを確認します。レスポンスは本文なし、ランダムな43文字の revision を引用符で囲んだ `ETag` のみです。内部バージョン、日時、件数、ZIPは公開しません。ただし継続監視から更新時期の範囲は推測可能です。
- 保存済み revision を `If-None-Match` で送ります。304なら変更なし、200なら更新ありとして設定の「データ取得」→「名称対応表」に表示します。取得失敗時は保存済み対応表を保持し、確認失敗を示します。
- 利用者が取得を押したとき、まず revision を再確認します。変更があれば `ASWebAuthenticationSession` で `takuma-gakunin-hono` のAuthorization Code + PKCE S256を開始し、`openid mapping.read links.read` を要求し、一覧と名称対応表の必要な更新を一回の認証で取得します。Microsoft側の既存SSOを許可し、`prompt=login`は付けません。
- `client_id=takupoke-ios`、callbackは `jp.n624.takupoke:/oauth/callback`。ID Tokenは署名・issuer・audience・nonce・有効期限を確認し、対応表APIにはAccess Tokenだけを送ります。Refresh Tokenは使用せず、Tokenは端末内へ永続保存しません。
- 認証後の `GET /mappings/current` は Bearer Token必須です。ZIPレスポンスの `X-Mapping-Revision` と直前に確認した公開 revision が一致する場合だけ取り込みます。公開確認と取得の間に版が切り替わった場合は旧版を残して再試行を案内します。

## ZIPの検証と保存

ZIP直下の `manifest.json` と `mappings.json` だけを許可し、ZIPのCRC、ファイル数・サイズ、schemaVersion、内部バージョン、`mappings.json` のサイズとSHA-256、規則の型と重複を検証します。v1は科目・教員・教室の完全一致規則だけです。v2は同姓教員について、学校年度・クラス・正式科目名・教員略名を合わせて確認する条件付き規則を追加します。科目のクラス指定規則は全クラス規則より優先します。正規表現は含めません。既存のv1保存結果も引き続き読み取ります。配布形式の原本は [`takupoke-api` の仕様](https://github.com/n624-dev/takupoke-api/blob/main/docs/mapping-package.md)です。

検証済みの規則と対応する公開revisionを専用SQLiteへ一回の取引で保存します。保存が成功するまで表示は前回正常版を使います。ZIPはURLSessionの一時ファイルで受け、取り込み後・失敗時に削除します。保存領域はバックアップ対象から外し、iOSのファイル保護を使用します。元PDFの再取得・再解析は行いません。

公開リポジトリ・テストには学校の実際の対応表、PDF、XLSX、認証情報を含めません。自動テストは架空データと架空URLを使います。

## 保存期限と出典

サーバーに自動失効期限は設けません。認証・権限確認を維持し、iOS側では半期ごとと半期管理方式への初回移行に保存済み対応表を削除します。[非公開データの管理](private-data-lifecycle.md)を参照してください。

配信元CSVの出典管理の作り直しは別途行います。生成済みZIPから出典やレビュー状態を推測して埋めません。API側生成器は今後の入力で未レビュー行を拒否します。
