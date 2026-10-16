# 日本語V6のiOS CPU Runtime照合

Windows由来の固定ONNXを、iOS26／27 Simulatorの実プロセスへ渡す研究。
Mac PythonのCPU参照と同じモデル・同じ原画素・同じFP32入力を使い、全確率とCTCを比較する。
Mac上で動くことをiOSでの実行成功に読み替えない。

同じ使用済みの完全架空6ページ・144項目・2切り抜き条件を使う。未使用資料の精度合格には加点しない。
既知の物理領域から取得した原画素をBGR／48px／元の丸め・正規化・ゼロ余白へ変換する。
元画像・FP32入力・native全確率のSHA256を保持し、各条件288回を両Runtimeへ各1回だけ渡す。
実行器・比較器は`oracle.json`や期待文字列を読み込まない。

ONNX Runtime1.23.2の公式NuGetパッケージから、サイズ／SHA256を固定したiOS XCFrameworkだけを取得する。
不要なパッケージ内容は実行しない。iPhone向けarm64とSimulator向けの両方を実SDKでコンパイルし、
所有するiPhone16 SimulatorへC API実行ファイルを起動する。追加providerを登録せずCPUで実行し、telemetryを無効にする。
upstream RuntimeはMicrosoft ONNX Runtime（MIT）、モデルはPaddlePaddle（Apache-2.0）。
アプリへの組込みやモデルの再配布はこの研究に含めない。

全確率の最大差5e-5以内、greedy文字列と全CTC区間の一致、選択された各文字の0.85条件の一致を
すべて必要とする。別Runtimeのスコアを移植したり、選択結果だけで誤差を見逃さない。
未取得・不正形状・非有限値・途中終了・取消・時間切れ・所定OS不在は失敗。
画像の正解やモデル同士の一致を、本文の正しさ・正式採用の証明に使わない。

Simulatorでの推論・メモリは物理iPhoneの実測ではない。iPhone SDKでのリンク成功も実機実行と分ける。
アプリ本体・Strict・その入口／経路／切替、Parser33／32、Validator・0.85・本文最大3項目は変更しない。
配信Manifestと公開版も維持する。モデルの全文書取得・所属・確認・採用をつなぐには別の検証が必要。

所有Simulatorは終了時にshutdown／deleteし、PDF・画像・モデル・Framework・入力／確率ファイル・
依存・module cacheも所有一時領域から削除する。cache／artifact／追加Releaseは作らない。
全確率のファイルは逐次比較後に削除し、集計・元のCTC・ハッシュだけを完全架空ログへ残す。
新しいActions開始前には毎回新規GPT-6.1 Sol／Highで対象コード差分だけをレビューする。

N07後の限定比較では、既存UI検証と同じ選択Xcode内の実在フロントエンドを起動する。
26はSimulatorへ所有UDIDを渡し、27はDevice Hubと所有deviceのURLを開く。
bootstatus・実UDIDのBooted照合・全確率検査と元の期限は維持する。
各コマンドの開始／完了／失敗と所要時間、所有deviceのshutdown／delete結果を記録する。
画面起動を原因・解消と断定せず、モデル呼出し前の失敗も成功へ救済しない。

次のv2比較はiOS SwiftのRGB8→BGR／48px／bilinear丸め／正規化／ゼロ余白も対象にする。
Pythonの参照テンソルをnative推論へ直接渡さず、iOSで元RGB8から独立に全テンソルを作る。
元の288原画像と、色順序・非対称行・奇数寸法・最大幅を含む4つの架空画素対照の計292件について、
幅・有効幅・SHAだけでなく全FP32bytesの完全一致を必要とする。
一致したiOS製テンソルだけをnativeの288回の推論に使用し、Mac参照は別に保存した参照テンソルを使う。
これは明示RGB8の数値変換の照合であり、CGImageの色空間・alpha・上下方向の取得証明ではない。
追加のSwift実行器も実iPhone SDK／Simulator SDKでコンパイルし、Simulatorだけで実行する。
Swift変換・モデル・Parserをアプリへ接続する変更は含めない。

v2ではN07で停止した全device一覧を使わず、所有UDIDへSwift実行器を一回spawnし、
そのプロセスのSIMULATOR_UDID・実OS版・Simulatorビルド条件・正のPIDを照合する。
呼出側が端末IDやOS版を実行器へ渡して返答させる方式ではない。
bootstatus360秒とspawn120秒を維持し、実応答・ID・OSが一致しない場合は失敗する。
元の一覧timeoutを捕捉して救済するfallbackや、起動し直す処理は加えない。
