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

iPhone の Safari で [AltStore 公式ダウンロードページ](https://altstore.io/download) を開き、**Download** を押します。

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

詳しくは [Remote AltServer の公式セットアップ手順](https://faq.altstore.io/altstore-classic/remote-altservers)を参照してください。

---

## 6. LocalDevVPN をインストールする

セットアップ中に LocalDevVPN のインストールを求められたら、[LocalDevVPN を App Store で開く](https://apps.apple.com/jp/app/localdevvpn/id6755608044) からインストールします。

LocalDevVPN を起動し、初回に VPN 構成の追加を求められた場合は許可してください。

その後、LocalDevVPN を次の状態にします。

```text
Current status
Connected
```

LocalDevVPNは、iPhone内にローカルネットワークトンネルを作成するために使用します。

---

## 7. デベロッパモードを有効にしてペアリングする

AltStore Classic からインストールする「たくポケ」を起動するには、**デベロッパモードを有効にする必要があります**。

### デベロッパモードを有効にする

1. AltStore Classic の Remote AltServer セットアップ画面で **Start Pairing** を押します。
2. iPhone の「設定」→「プライバシーとセキュリティ」→「デベロッパモード」を開きます。
3. **デベロッパモードをオン**にし、確認画面で再起動を選びます。
4. 再起動後に iPhone のロックを解除し、デベロッパモードを有効にする確認画面で有効化を選び、パスコードを入力します。
5. 「設定」へ戻り、デベロッパモードがオンになっていることを確認します。

すでにオンの場合は、次のペアリングへ進みます。操作の詳細は [Apple のデベロッパモード有効化手順](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)を参照してください。

### On-Device Pairing を完了する

1. 再起動した場合は Wi-Fi の接続を確認し、LocalDevVPN を開いて **Connected** にします。
2. AltStore Classic の Remote AltServer セットアップへ戻り、**Start Pairing** を押します。
3. iPhone の設定アプリで次を開きます。

   ```text
   設定
   → プライバシーとセキュリティ
   → デベロッパモード
   → Pair with AltStore
   ```

4. **Pair with AltStore** を選択し、求められたら iPhone のパスコードを入力します。
5. AltStore Classic へ戻り、画面の案内に沿ってセットアップを続けます。

iOS 27 以降では、この操作で端末内にペアリング情報を作成できます。詳しくは [AltStore 開発者による On-Device Pairing の説明](https://www.patreon.com/rileyshane/posts/altstore-classic-169262530)を参照してください。

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

インストールが完了したら、ホーム画面から **たくポケ** を起動します。

### 開発元の信頼を求められた場合

初回起動時に開発元が信頼されていないという案内が表示されたら、次の手順を行います。

1. iPhone の「設定」→「一般」→「VPNとデバイス管理」を開きます。
2. 「デベロッパAPP」で、**AltStore Classic の署名に使った自分の Apple Account** を選択します。
3. 信頼する操作を選び、確認画面の案内に従います。
4. ホーム画面へ戻り、たくポケを開き直します。

署名したアカウントの信頼については、[AltStore の公式インストール手順](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)にも記載されています。

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

## 「デベロッパモード」や `Pair with AltStore` が表示されない

1. iOS 27 以降・AltStore Classic 2.3 以降であることを確認します。
2. Wi-Fi と LocalDevVPN を接続します。
3. AltStore Classic の Remote AltServer セットアップで **Start Pairing** を押します。
4. 「設定」→「プライバシーとセキュリティ」を開き直します。
5. 「デベロッパモード」がオフなら、手順7の有効化・再起動・再起動後の確認を完了してから、もう一度ペアリングを開始します。

Apple は、ペアリングを開始すると設定にデベロッパモードが表示されると案内しています。表示されない場合は、[AltStore の公式セットアップ手順](https://faq.altstore.io/altstore-classic/remote-altservers)を確認してください。

---

## 「デベロッパモードが必要」と表示され、たくポケを起動できない

手順7に戻り、デベロッパモードをオンにします。**再起動後の有効化確認とパスコード入力まで**完了してから、たくポケを開き直してください。

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
- [Apple：デベロッパモードの有効化](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [AltStore：Remote AltServer のセットアップ](https://faq.altstore.io/altstore-classic/remote-altservers)
