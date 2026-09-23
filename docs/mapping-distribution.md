# 名称対応表の配信・接続方針

既存の認証サービスと `takupoke-api` にiOS版を接続する方針です。配信APIは本番へ反映済みですが、iOSのログイン・ZIP取得・対応表の取り込みは未実装です。bucketは空で、対応表をまだ配信していません。PDF解析は対応表なしで、記載名を保持して利用できます。

## 役割

- 既存の `takuma-gakunin-hono` をOIDC Providerとして利用する。iOSはpublic client `takupoke-ios` としてAuthorization Code FlowとPKCE S256を使い、ログインには `ASWebAuthenticationSession` を使う。redirect URIは `jp.n624.takupoke:/oauth/callback` とする方針。
- 既存の `takupoke-api` Workerが、配信用Access TokenのES256署名を固定JWKSで検証し、`typ=at+jwt`、issuer、`aud=takupoke-mapping-api`、有効期限、`mapping.read`権限を確認して対応表を返す。ID TokenをZIP取得用トークンとして兼用しない。
- Providerの署名付きAccess Token発行は実装・本番反映済み。本番D1に `takupoke-ios` のpublic client、redirect URI、`openid`・`mapping.read` scopeが登録されていることを読み取りで確認済み。実アカウントでのログイン確認は未実施。
- 実際の対応表ZIPは非公開R2に置く。公開用の `r2.dev` やバケットの公開ドメインを有効にせず、WorkerのR2 Bindingから読み取る。アプリへR2の直接URLを渡さない。
- 配布対象は名称の対応・変換規則に限定する。正解時間割CSV、学校行事CSV、PDF、XLSXを含めない。

## 配信APIと形式

- 本番URLは `https://takupoke-api.n624.jp`。`GET /mappings/current` は最新版ZIPを直接返し、`GET /mappings/versions/:version` は指定版のZIPを返す。どちらもBearer Access Tokenを必要とする。
- 認証済みの `If-None-Match` 一致時だけ304を返す。tokenがない・無効な場合は401、未配置・未発見は404。ZIPが未配置の間は認証済みでも404になる。
- R2 bucket `takupoke-api` の `mappings/versions/<version>.zip` に版を置き、`mappings/current.json` の参照先を最後に切り替える。
- ZIP内部の対応表はJSONで配布する。ファイル名・列に相当するフィールド・規則の詳細・上限は元データを確認して確定する。

## iOSでの取り込みと更新

- 初回取得・更新確認は利用者の明示操作で行う。変更がない場合はETag等でZIPの取得を省く。
- ZIPはアプリ専用の一時領域で扱い、検証・取り込み後に削除する。展開・変換した対応表もアプリ専用領域に置き、「ファイル」アプリへ公開しない。
- ファイル数・サイズ・展開量・JSON schema・変換規則を検証し、正常な新しい対応表だけを原子的に反映する。失敗時は前回正常版を保持する。
- PDFの記載名を残し、取り込んだ対応表による正式名称を別の値として扱う。対応表の更新時に元PDFの再ダウンロードを必要としない。
- 正規表現を含む対応表は、対応する記法・適用範囲・優先順位・複数一致・実行量上限を配信側と合意してから実装する。任意の解析コードをダウンロードして実行する仕組みにはしない。
- 認証情報は適切な端末内保管を使い、ログ・バックアップ・公開リポジトリへ出さない。端末所有者によるデータ取り出しを完全に防ぐ仕組みではない。

## 配信側の更新

新しいZIPのアップロードと検証を終えてから最新版への参照を切り替え、最新版と切り戻し用の前版のみを維持する方針です。これは対応表配信の保存方針であり、iOSアプリの正式なGitHub Releasesの自動削除は行いません。

## 接続前に確定するもの

- ZIP内のファイル名、JSONフィールド、metadata/schema、バージョン、整合性確認方法。
- 規則の一致方法・優先順位・クラス別適用・要確認行・不一致の扱い。

会話中のファイル名やURL例は確定値として使用しません。

参照: [R2の非公開設定](https://developers.cloudflare.com/r2/buckets/public-buckets/)、[WorkersからのR2取得](https://developers.cloudflare.com/r2/api/workers/workers-api-usage/)、[OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)。
