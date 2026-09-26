# たくポケ iOS — AltStore PAL 経由の新規インストール

このページでは、**AltStore PAL → AltStore Classic → たくポケ** の順で iPhone に新規インストールする方法を説明します。

この手順では、AltStore Classic 2.3 以降の **Remote AltServer** と、iOS 27 以降の **On-Device Pairing** を使用します。初期設定が完了したあとは、7 日ごとの署名更新のために PC を起動しておく必要はありません。

> [!NOTE]
> このページは **新規インストール向け**です。以前の AltStore Classic から署名証明書やアプリを引き継ぐ手順は扱いません。

## 必要なもの

- iOS 27 以降の iPhone
- 日本の App Store アカウント
- 日本国内での利用
- Wi-Fi 接続
- Apple Account
- AltStore PAL
- AltStore Classic 2.3 以降
- LocalDevVPN

たくポケ本体は iOS 16.0 以降に対応していますが、このページでは PC を常時使用しない Remote AltServer の設定まで行うため、iOS 27 以降を前提とします。

---

## 1. AltStore PAL をインストールする

iPhone で [AltStore 公式ダウンロードページ](https://altstore.io/download) を開き、**Download** を押します。

初回は「AltStore LLC からの Marketplace を許可」のような確認が表示されます。画面の案内に従って設定アプリで許可したあと、もう一度 [AltStore 公式ダウンロードページ](https://altstore.io/download) に戻って **Download** を押し、AltStore PAL をインストールしてください。

AltStore PAL は日本で正式に利用できます。

---

## 2. AltStore PAL から AltStore Classic をインストールする

iPhone で [AltStore Classic の公式 PAL Source](https://api.altstore.io/source/marketplace.altstore.io?app=com.rileytestut.AltStore) を開き、AltStore PAL に Source を追加します。

Source に表示された **AltStore Classic** をインストールしてください。

PAL 経由でインストールした AltStore Classic 自体には、従来の AltServer 経由版のような 7 日ごとの Refresh は必要ありません。

ただし、AltStore Classic からインストールする「たくポケ」などの IPA は、無料 Apple Account を使う場合は 7 日ごとの署名更新が必要です。

---

## 3. AltStore Classic の初期設定を行う

AltStore Classic を起動し、画面の案内に従って Apple Account でサインインします。

既存の Signing Certificate を Import するか確認された場合、**完全な新規インストールで引き継ぐ証明書がなければ `Skip` を選択**して進めます。

AltStore Classic が新しい署名証明書を作成します。

---

## 4. UDID を入力する

AltStore Classic で次の画面が表示された場合は、使用している iPhone の **UDID** を入力します。

```text
Please enter your device's UDID.
```

UDID は、IMEI・EID・シリアル番号とは別の端末識別子です。

### Windows の iTunes で UDID を確認する

1. iPhone を USB で Windows PC に接続します。
2. iPhone に「このコンピュータを信頼しますか？」と表示された場合は、**信頼**を選択します。
3. Windows で iTunes を開きます。
4. iPhone のデバイス画面を開きます。
5. **概要**を開きます。
6. **シリアル番号の表示部分をクリック**します。
7. 表示が **UDID** に切り替わったら、表示された文字列を確認します。
8. AltStore Classic に戻り、表示されている UDID を**正確に手入力**します。

> [!IMPORTANT]
> iTunes 上の UDID は、環境によってはそのままコピーできません。コピーできることを前提にせず、表示内容を確認して入力してください。IMEI・EID・シリアル番号は入力しないでください。

UDID の入力画面が表示されなかった場合、この手順は不要です。

UDID そのものについては、Apple の [Locating device identifiers](https://developer.apple.com/documentation/xcode/locating-device-identifiers) も参照できます。

---

## 5. Remote AltServer のセットアップを開始する

AltStore Classic で次を開きます。

```text
Settings
→ Set-Up Remote AltServer
```

Remote AltServer は、PC 上の AltServer を常時起動していなくても、AltStore Classic からアプリのインストールや Refresh を行うための仕組みです。

AltStore Classic 2.3 の Remote AltServer については、[開発者による説明](https://www.patreon.com/rileyshane/posts/altstore-classic-158697195) も参照してください。

---

## 6. LocalDevVPN をインストールする

セットアップ中に LocalDevVPN のインストールを求められたら、[LocalDevVPN を App Store で開く](https://apps.apple.com/jp/app/localdevvpn/id6755608044) からインストールします。

LocalDevVPN を起動し、初回に VPN 構成の追加を求められた場合は許可してください。

その後、LocalDevVPN を次の状態にします。

```text
Current status
Connected
```

LocalDevVPN は、インターネット通信を外部の VPN サーバーへ送る一般的な VPN サービスとは用途が異なります。iPhone 内にローカルネットワークトンネルを作成するために使用されます。

---

## 7. On-Device Pairing を行う

Remote AltServer のセットアップ画面で **Start Pairing** を押します。

続いて iPhone の設定アプリを開きます。

```text
設定
→ プライバシーとセキュリティ
→ デベロッパモード
→ Pair with AltStore
```

`Pair with AltStore` が表示されたら選択し、必要に応じて iPhone のパスコードを入力します。

iOS 27 以降では On-Device Pairing に対応しているため、Remote AltServer 用の Pairing File を PC で作成して転送する必要はありません。

詳しくは [AltStore Classic 2.3 RC の On-Device Pairing の説明](https://www.patreon.com/rileyshane/posts/altstore-classic-169262530) を参照してください。

---

## 8. Wi-Fi と LocalDevVPN を接続する

Remote AltServer を使うときは、iPhone を **Wi-Fi に接続**し、LocalDevVPN を **Connected** にします。

```text
Wi-Fi: 接続済み
LocalDevVPN: Connected
```

4G / 5G のみの状態では、LocalDevVPN が `Connected` でも AltStore Classic 側が次のように表示されることがあります。

```text
Status: Not Connected
Turn on Wi-Fi and LocalDevVPN to connect.
```

この場合は Wi-Fi に接続してください。

---

## 9. Remote AltServer のサーバーを選ぶ

AltStore Classic の **Settings** にある **Server** を開きます。

複数の Anisette Server が表示されますが、通常は**自動選択されたサーバーのままで構いません**。

自動選択されたサーバーで接続できない場合は、別の Popular サーバーへ変更してください。

例:

```text
SideStore
ani.sidestore.io
```

あわせて、次を ON にします。

```text
Prefer Remote AltServer
```

サーバーの自動選択については、[AltStore Classic 2.3 beta 2 の開発者説明](https://www.patreon.com/rileyshane/posts/altstore-classic-163069024) を参照してください。

---

## 10. Remote AltServer の接続を確認する

AltStore Classic の Settings で、Remote AltServer が次の状態になっていることを確認します。

```text
Status: Connected
```

あわせて次も確認します。

```text
Wi-Fi: 接続済み
LocalDevVPN: Connected
Prefer Remote AltServer: ON
```

ここまで完了すれば、PC 上の AltServer を常時起動せずに IPA をインストール・Refresh できる状態です。

---

## 11. たくポケの Source を追加する

AltStore Classic の **Sources** 画面で Source を追加し、次の URL を入力します。

**[たくポケ AltStore Source](https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json)**

```text
https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
```

公開中のバージョンや配布ファイルは [GitHub Releases](https://github.com/n624-dev/takupoke-ios/releases) で確認できます。

---

## 12. たくポケをインストールする

追加した Source を開き、**たくポケ** の **Install** を押します。

AltStore Classic が IPA を取得し、Apple Account で署名して iPhone にインストールします。

インストールが完了したら、ホーム画面から **たくポケ** を起動してください。

たくポケのソースコードと最新の説明は [n624-dev/takupoke-ios](https://github.com/n624-dev/takupoke-ios) で確認できます。

---

## 13. インストール後に確認する

たくポケを起動し、初回セットアップに沿って学校アカウント認証、ファイル選択、クラス選択を行います。「あとで設定」で終了した場合は、設定の「セットアップ」から再開できます。

「設定」→「このアプリについて」で次の情報を確認します。

- バージョン
- ビルド

必要に応じて [GitHub Releases](https://github.com/n624-dev/takupoke-ios/releases) の公開内容と照合してください。

アプリの現在の実装状況や使い方は [README](https://github.com/n624-dev/takupoke-ios/blob/main/README.md) を参照してください。

---

## 14. 7 日ごとに Refresh する

無料 Apple Account で AltStore Classic からインストールした「たくポケ」には、7 日間の署名期限があります。

期限切れになる前に、次の状態にします。

```text
Wi-Fi: 接続済み
LocalDevVPN: Connected
```

そのうえで AltStore Classic を開きます。

```text
My Apps
→ Refresh All
```

「たくポケ」の残り日数が再び **7 DAYS** になれば完了です。

Remote AltServer の設定後は、この Refresh のために PC 上の AltServer を起動しておく必要はありません。

---

## 15. たくポケをアップデートする

新しいバージョンが公開されると、AltStore Classic の Source から更新できます。

- [たくポケ AltStore Source](https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json)
- [GitHub Releases](https://github.com/n624-dev/takupoke-ios/releases)

AltStore Classic で Source を更新し、新しいバージョンが表示されたら **Update** してください。

通常のアップデートでは、先に「たくポケ」を削除しないでください。既存アプリへ上書きインストールすることで、端末内のアプリデータを維持できます。

---

# トラブルシューティング

## LocalDevVPN を入れたのにセットアップが進まない

[LocalDevVPN](https://apps.apple.com/jp/app/localdevvpn/id6755608044) を開き、`Connected` になっていることを確認します。

改善しない場合は、次の順番でやり直します。

1. LocalDevVPN を `Connected` にする
2. AltStore Classic を App スイッチャーから完全に終了する
3. AltStore Classic を開き直す
4. `Set-Up Remote AltServer` をもう一度開く

---

## Remote AltServer が `Not Connected` になる

次の両方を確認してください。

```text
Wi-Fi: 接続済み
LocalDevVPN: Connected
```

4G / 5G のみになっている場合は、Wi-Fi に接続してから確認します。

---

## Remote AltServer のサーバーに接続できない

AltStore Classic の次の画面から、別の Popular サーバーを選択します。

```text
Settings
→ Server
```

正常に接続できているサーバーを、理由なく変更する必要はありません。

---

## `Pair with AltStore` が表示されない

まず AltStore Classic 側で **Start Pairing** を押してから、設定アプリを確認します。

```text
設定
→ プライバシーとセキュリティ
→ デベロッパモード
```

AltStore Classic と iOS が最新であることも確認してください。

---

## UDID が分からない

Windows 版 iTunes では、次の手順で表示できます。

```text
iPhone を USB 接続
→ iTunes
→ iPhone
→ 概要
→ シリアル番号の表示部分をクリック
→ UDID を表示
```

表示された UDID を確認し、AltStore Classic の入力欄へ正確に入力してください。

**IMEI・EID・シリアル番号は UDID ではありません。**

---

# 関連リンク

- [たくポケ GitHub リポジトリ](https://github.com/n624-dev/takupoke-ios)
- [たくポケ GitHub Releases](https://github.com/n624-dev/takupoke-ios/releases)
- [たくポケ AltStore Source](https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json)
- [AltStore PAL 公式ダウンロード](https://altstore.io/download)
- [AltStore Classic 公式 PAL Source](https://api.altstore.io/source/marketplace.altstore.io?app=com.rileytestut.AltStore)
- [LocalDevVPN — App Store](https://apps.apple.com/jp/app/localdevvpn/id6755608044)
