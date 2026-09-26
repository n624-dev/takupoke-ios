# アプリアイコンと画面方向

画面はiPhoneの縦向き専用です。`Info.plist` の `UISupportedInterfaceOrientations` は `UIInterfaceOrientationPortrait` だけを指定します。

## 元素材と加工

利用者が選んだWeb版「クラシック」を使用します。出典は `n624-dev/takupoke-astro` のコミット `e08b9d65c83613b12a90259d426bfcdd51e5c22f`、`public/takupoke-1024.png`（角丸マスクを付ける前の1024px素材）です。

- 「たくポケ」の文字、赤い線、鉛筆の配置と配色を基にしています。
- 利用者指定により白い背景・焼き込まれた影を分離し、文字・線・鉛筆の面を均一な色にしています。画像生成で試した素材は採用せず、元画像の色領域を抽出したPNGを使用します。
- 前景は `Takupoke/AppIcon.icon/Assets/` 内の `ClassicArtwork.png`（赤い線と鉛筆）、`ClassicTaku.png`、`ClassicPoke.png` の3レイヤーです。文字は2行全体を垂直方向の中央に配置しています。横位置は輪の中央を基準とし、「ポケ」は文字形状による左寄りを補うため、外接矩形の中央配置から右へ15px（1024px素材上）調整しています。赤い輪と鉛筆はつながりを維持してまとめて配置し直し、文字とともに約90%へ縮めています。文字を輪の中央へ収め、鉛筆の右端にも余白を確保しています。
- 通常は白背景・茶色の「たく」、ダークは黒に近い背景・温かみのあるグレー（#B6AC96）の「たく」です。「ポケ」・赤い線・鉛筆の配色は維持します。`icon.json` のappearance指定を使用し、ホーム画面で選んだアイコン外観に従ってOSが切り替えます。文字2レイヤーはLiquid Glassを無効にし、赤い輪・鉛筆には効果を残します。角丸マスクと有効な効果の描画はOSへ任せます。

クリア／色付き表示の基となるMono（ファイル内の `appearance: tinted`）では、「たく」「ポケ」を不透明な白の濃淡素材として明示します。濃い茶色の自動変換に任せず文字形状を維持するための指定で、通常・ダークの文字色には影響しません。クリアの明暗や壁紙に応じた最終描画はOSが行うため、端末での表示確認を必要とします。

## ビルドと配布

`AppIcon.icon` はXcodeのResourcesへ登録し、`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` を使用します。Xcode 26.3でLiquid Glass用にコンパイルします。iOS 26より前のOS向け画像はXcodeが生成します。最低対応OSはiOS 16のままです。

`Assets.xcassets/AppIcon.appiconset/AppIcon.png` は同じ前景を白背景に合成した不透明PNGです。AltStore Source / Releaseの `icon.png` にも使用します。ネイティブの動的な光沢をPNGへ焼き込んではいません。

将来変更するときは `.icon` の前景・設定と配布用PNGを合わせて更新してください。旧カレンダーアイコンの生成スクリプトは削除しました。macOSではIcon Composerで各外観をプレビューできます。Linuxでの素材確認・CIでのコンパイルと、実機での明暗・色合い・クリア外観の確認は区別します。

参照: [Apple: Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)。ファイル構造はAppleの[Landmarksサンプル](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)も参照しています。
