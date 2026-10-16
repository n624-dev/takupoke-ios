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
