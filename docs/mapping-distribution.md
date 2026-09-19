# 名称対応表の配信・接続方針

利用者が別途構築する配信サービスにiOS版を接続する方針です。現時点で配信URLは未決定で、iOSのログイン・ZIP取得・対応表の取り込みは未実装です。仮の本番URLや認証情報をアプリへ埋め込みません。PDF解析は対応表なしで、記載名を保持して利用できます。

## 役割

- 既存の `takuma-gakunin-hono` をOIDC Providerとして利用する。iOSはpublic clientとしてAuthorization Code FlowとPKCE S256を使い、ログインには `ASWebAuthenticationSession` を使う方針。
- 別の配信用Cloudflare Workerが、配信用API向けAccess Tokenの署名・発行者・対象API・有効期限・`mapping.read`権限を検証して対応表を返す。ID TokenをZIP取得用トークンとして兼用しない。
- Provider側で必要な署名付きAccess Tokenの発行は配信側との連携作業で対応する。現行実装がすでに配信用APIへ対応しているとは扱わず、既存クライアントへの影響も確認する。
- 実際の対応表ZIPは非公開R2に置く。公開用の `r2.dev` やバケットの公開ドメインを有効にせず、WorkerのR2 Bindingから読み取る。アプリへR2の直接URLを渡さない。
- 配布対象は名称の対応・変換規則に限定する。正解時間割CSV、学校行事CSV、PDF、XLSXを含めない。

## iOSでの取り込みと更新

- 初回取得・更新確認は利用者の明示操作で行う。変更がない場合はETag等でZIPの取得を省く。
- ZIPはアプリ専用の一時領域で扱い、検証・取り込み後に削除する。展開・変換した対応表もアプリ専用領域に置き、「ファイル」アプリへ公開しない。
- ファイル数・サイズ・展開量・CSV形式・schema・変換規則を検証し、正常な新しい対応表だけを原子的に反映する。失敗時は前回正常版を保持する。
- PDFの記載名を残し、取り込んだ対応表による正式名称を別の値として扱う。対応表の更新時に元PDFの再ダウンロードを必要としない。
- 正規表現を含む対応表は、対応する記法・適用範囲・優先順位・複数一致・実行量上限を配信側と合意してから実装する。任意の解析コードをダウンロードして実行する仕組みにはしない。
- 認証情報は適切な端末内保管を使い、ログ・バックアップ・公開リポジトリへ出さない。端末所有者によるデータ取り出しを完全に防ぐ仕組みではない。

## 配信側の更新

新しいZIPのアップロードと検証を終えてから最新版への参照を切り替え、最新版と切り戻し用の前版のみを維持する方針です。これは対応表配信の保存方針であり、iOSアプリの正式なGitHub Releasesの自動削除は行いません。

## 接続前に確定するもの

- OIDC issuer、iOS用client ID、登録済みのredirect URI、配信用Access Tokenのaudience・scope・有効期限。
- 配信用APIのHTTPS URL、更新確認・ZIP取得のパス、認可切れや権限不足時の応答。
- ZIP内のファイル名、CSV列、metadata/schema、バージョン、整合性確認方法。
- 規則の一致方法・優先順位・クラス別適用・要確認行・不一致の扱い。

会話中のファイル名やURL例は確定値として使用しません。

参照: [R2の非公開設定](https://developers.cloudflare.com/r2/buckets/public-buckets/)、[WorkersからのR2取得](https://developers.cloudflare.com/r2/api/workers/workers-api-usage/)、[OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)。
