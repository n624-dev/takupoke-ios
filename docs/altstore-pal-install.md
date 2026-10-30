# iPhoneだけでインストールする（AltStore PAL）

**iOS 27・日本国内向け**の方法です。AltStore PALからAltStore Classicを導入し、その中で「たくポケ」をインストールします。初回の設定から署名更新まで、PCを使わずに行えます。

iOS 26の場合は[WindowsのAltServerを使う方法](distribution.md)を参照してください。

## 用意するもの

- iOS 27のiPhoneと、日本で利用できるApp Storeアカウント
- Apple Account（AltStore Classicでの署名用）
- Wi-Fi接続
- AltStore PAL、AltStore Classic **2.3以降**、LocalDevVPN

**たくポケはAltStore PALに直接登録されたアプリではありません。** AltStore PALに追加するのはAltStore Classicで、そのClassicからたくポケを入れます。

## 1. AltStore PALとClassicを入れる

1. iPhoneのSafariで[AltStore公式ダウンロードページ](https://altstore.io/download)を開き、AltStore PALをインストールします。初回はiPhoneの設定でマーケットプレイスの許可が必要になることがあります。
2. [AltStore Classicの公式PAL Source](https://api.altstore.io/source/marketplace.altstore.io?app=com.rileytestut.AltStore)をAltStore PALに追加し、**AltStore Classic**をインストールします。
3. AltStore Classicを開き、案内に沿って自分のApple Accountでサインインします。

※ 既存の署名証明書の取り込みを求められ、引き継ぐものがない場合は、画面の案内に従い新規設定を選びます。

## 2. Remote AltServerを設定する

1. AltStore Classicの**Settings → Set-Up Remote AltServer**を開きます。
2. 画面の案内に従って[LocalDevVPN](https://apps.apple.com/jp/app/localdevvpn/id6755608044)をインストールし、VPN構成を許可して**Connected**にします。
3. iPhoneの**設定 → プライバシーとセキュリティ → デベロッパモード**を有効にします。要求された場合は再起動し、再起動後の確認も完了します。
4. セットアップ画面の**Start Pairing**から、iPhoneの設定に表示される**Pair with AltStore**の案内に沿って端末内ペアリングを済ませます。
5. AltStore Classicに戻り、Remote AltServerの状態が**Connected**になるまで画面の案内を進めます。

Remote AltServerの使用中は**Wi-FiとLocalDevVPNの接続が必要**です。携帯電話回線だけでは接続できません。通常はサーバーの自動選択のままで構いません。

操作画面が異なる場合は[AltStore公式のRemote AltServer手順](https://faq.altstore.io/altstore-classic/remote-altservers)に従ってください。端末識別子（UDID）の入力を求められたときは、IMEIやシリアル番号と取り違えないよう、[Appleの識別子確認方法](https://developer.apple.com/documentation/xcode/locating-device-identifiers)を参照してください。

## 3. たくポケをインストールする

1. AltStore Classicの**Sources**で次のURLを追加します。

   ```text
   https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
   ```

2. 表示された**たくポケ → Install**を選びます。
3. インストール後、ホーム画面からたくポケを開きます。

開発元の信頼を求められたときは、iPhoneの**設定 → 一般 → VPNとデバイス管理**を開き、AltStore Classicで署名した自分のApple Accountに対する信頼の案内に従ってください。デベロッパモードも有効になっている必要があります。

## インストール後

[初期設定・OneDriveの準備](materials.md)に従って学校ファイルとクラスを設定してください。

無料のApple Accountでインストールした場合、アプリは通常**7日ごとに署名更新**が必要です。期限前にWi-FiとLocalDevVPNを接続して、AltStore Classicの**My Apps → Refresh All**を実行します。Remote AltServerの設定が済んでいれば、この操作にPCは不要です。

新しいたくポケが公開されたら、AltStore ClassicでSourceまたは更新一覧を再読み込みし、**Update**を選びます。**更新のために既存のアプリを削除しないでください。** 削除するとアプリ内データも失われます。

## 接続に失敗するとき

- **Not Connected**：Wi-FiとLocalDevVPNの両方が接続されているか確認します。
- **Pair with AltStoreがない**：iOS 27・Classic 2.3以降であること、デベロッパモード、ペアリング開始操作を確認します。
- **Remote AltServerに接続できない**：AltStore ClassicのSettingsから別のサーバーを選ぶか、[公式案内](https://faq.altstore.io/altstore-classic/remote-altservers)を確認します。
- **インストールできたが起動しない**：デベロッパモードと「VPNとデバイス管理」の信頼状態を確認します。

[その他のトラブル](troubleshooting.md) · [GitHubの最新版](https://github.com/n624-dev/takupoke-ios/releases/latest)
