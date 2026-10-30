# Windowsからインストールする（AltServer）

**iOS 26・27のiPhone**で使える、Windows PCを利用した導入方法です。AltStore ClassicをWindowsのAltServer経由でインストールします。

iOS 27でPCを使わず導入したい場合は、[AltStore PALを使う方法](altstore-pal-install.md)を参照してください。

## 準備

- Windows PC、iPhone、接続用ケーブルまたは同じWi-Fiネットワーク
- 自分のApple Account
- iPhoneのデベロッパモード（アプリを起動するために必要）
- AltServerとAltStore Classic

1. [AltStore公式のWindows向けインストール手順](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)に従い、WindowsにAltServerを導入します。必要なApple関連ソフトウェアや接続設定も公式手順に合わせます。
2. AltServerからiPhoneに**AltStore Classic**をインストールします。Apple Accountの認証やiPhoneの「信頼」確認を求められた場合は、公式画面の案内に従います。
3. iPhoneの**設定 → プライバシーとセキュリティ → デベロッパモード**を有効にし、必要な再起動後の確認を完了します。

Apple Accountのパスワードや署名証明書を、GitHubのIssue・公開チャットなどに投稿しないでください。

## たくポケを入れる

1. iPhoneのAltStore Classicを開き、**Sources**から次のURLを追加します。

   ```text
   https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
   ```

2. 表示された**たくポケ → Install**を選びます。必要に応じて、WindowsでAltServerを起動し、iPhoneを接続した状態にします。
3. 初回起動で開発元の信頼を求められた場合は、iPhoneの**設定 → 一般 → VPNとデバイス管理**から案内に従います。

その後は[初期設定](materials.md)へ進んでください。

## 署名更新とアプリの更新

無料のApple Accountで署名したアプリには、通常7日間の期限があります。期限前にAltStore Classicの**My Apps → Refresh All**で署名更新してください。通常のAltServer方式では、PC上のAltServerとiPhoneの接続が必要です。

たくポケの新しい版は、AltStore ClassicでSource・更新一覧を確認して**Update**します。署名のRefreshとバージョンのUpdateは別です。**データを残すため、更新前にアプリを削除しないでください。**

[AltStore公式トラブルシューティング](https://faq.altstore.io/altstore-classic/troubleshooting-guide) · [たくポケの最新版](https://github.com/n624-dev/takupoke-ios/releases/latest)
