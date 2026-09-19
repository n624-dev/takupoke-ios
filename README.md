# takupoke-ios

学校の通常時間割・学校行事・時間割変更を端末内で統合する、Swift / SwiftUI 製の iOS ネイティブアプリ。

現在は開発方針とリポジトリ構成を整えた段階です。アプリ、ビルド用 GitHub Actions、IPA、AltStore Source はまだ実装・公開していません。

## ドキュメント

- [確定した開発方針](docs/development-policy.md)
- [開発順序と完了条件](docs/roadmap.md)
- [公開リポジトリでの情報管理](docs/public-repository.md)

## 基本方針

- SwiftUI を基本とし、必要な箇所のみ UIKit を使用する。
- Web 版とは別実装にし、必要なデータ仕様・解析ルールを合わせる。
- iOS 標準の「ファイル」と OneDrive File Provider を通じて学校資料を取得する。Microsoft Graph は使用しない。
- PDF は PDFKit、XLSX は Swift で解析する。曖昧な内容は推測で反映しない。
- 取得・解析に失敗した場合も、端末内の前回正常データを維持する。
- ローカルに一時ファイルを溜めず、開発・アプリ処理で不要になった作業用ファイルを片付ける。
- 最初の開発ステップで AltStore Classic による初回導入と更新を実機確認する。

通常の開発フローは以下に固定します。

```text
このデバイスまたは Windows で編集
  → GitHub へ push
  → GitHub Actions の macOS runner で IPA を生成・公開
  → バージョン / build 番号と AltStore Source JSON を自動更新
  → iPhone の AltStore Source から導入・更新
```

開発にはこのデバイスと Windows の両方を使用します。Mac の所有は前提にしません。Windows 版アプリは今回の開発対象外です。

## リポジトリの扱い

公開対象はソースコード、設定のひな形、ドキュメント、完全に架空のテストデータです。学校の実資料、実資料から抽出したデータ、個人情報、認証情報は含めません。

ローカルの実資料はリポジトリ外に保存することを基本とし、作業上必要な場合は Git 除外済みの `private/` を使用します。追加・コミット・公開の前に [情報管理ルール](docs/public-repository.md) を確認してください。
