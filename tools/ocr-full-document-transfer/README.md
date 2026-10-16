# PDF全体からの原画素・物理セル取得の初期比較

学校原本を読まず、新しいseedと独立した配置で6件の画像PDFを生成する。
通常は1クラス×5曜日×8時限、試験／返却は各17クラス×1日×1時限、
各3本文値、両字体で444値を対象にする。複数通常クラス・結合・並記・空欄・回転の資格はまだ含まない。
両字体は前の比較で使用済みで、未見字体や学習データと独立との主張はしない。
v4でも同じ6PDFを現行の最大2048pxと、最大4096px・上限2px/PDFpointで実取得する。
各条件444値、計888値。通常は3440px幅、試験／返却は両条件とも上限未満である。
生成済みPDFの元画像は2px/PDFpointなので、2倍を超える描画で新しい詳細を作ったとは呼ばない。
現在の4096pxまでの既存Raster上限を維持し、アプリの2048px条件は変更しない。
N11で確認した元Vision captureの2048px上限も維持する。
Visionを実行するのは現行条件の6回だけで、4096条件はV6用の原画素・実罫線取得である。
Vision未実行を空出力や成功へ変換せず、元2048 capture・元物理セルで本文への所属を検査する。
その後、同じPDFの同じ本文targetでV6と比較する。4096条件は同じ画素の認識器比較ではない。
V6の2048／4096の変化は、各444項目から修復／退行を別に計算する。

v4では既存の固定EnglishV1を、非ASCII prefixの後にある2〜32文字のASCII末尾へだけ試す。
raw CTCが示す境界窓に、元RGBの全行が白い縦帯を確認できる場合だけ切り出す。
白帯は文字種や正しい境界の証明ではないため、元V6・原pixel hash・CTC仮説・原ASCII出力を別々に残す。
既知の教室名や期待文字による補正、原クラス一覧による候補選びはしない。
Standaloneのクラス断片・1桁の時限は対象外で、underscoreの行分断を解決したとは呼ばない。
ASCIIの選択は元末尾と同じ文字数、元のpadding支持、各piece0.85以上、reject0.05以下、
英数字／underscore／hyphenの文字と数字を含むことを要求する。挿入・欠落を推測で埋めない。
V6全体の元文字・元CTCは書き換えず、選択した複合文字列と固有score条件は別の指標とする。
既に正しい数字の科目末尾も同じ条件で処理し、修復だけでなく退行を数える。
両字体・元資料は使用済みの探索であり、未使用評価・iOSでのASCII入出力実行・本体採用は未確認。

認識処理はPDF・ID・資料種別・ファイルSHAだけを受ける。
generatorの座標・対象クラス・期待文字を入力manifestへ入れない。
正解の文字と領域は`oracle.json`へ分け、認識プロセスが終了した後の比較器だけが読む。
同じsource PDFのSHAも突き合わせ、別の資料を同じIDで結び付けない。

既存iOSの`RecoveryRasterGrid`／`PDFGrid`をそのまま所有Swift Packageコピーでコンパイルし、
実PDFKitの原画素・罫線・四辺が支持される領域を取得する。
元のprivate maskへの読み取り専用getterだけを、同じ所有コピーのファイル末尾へ追加する。
原本ソースの全bytesがprefixとして不変であることを検査し、既存メソッド・しきい値を置換しない。
追加テストの登録も所有Packageコピーだけで、アプリ・元Package・Strictの経路は変更しない。
N10でSwiftのprintとXCTest終了出力が接合したため、原captureはテスト中に保存し、
終了後の単独Pythonプロセスが元順位・文字・観測枠・score・全候補をそのまま出力する。
各資料の原native行数と元captureのSHAを別のreceiptへ出し、ログから全ID／順位を照合する。

物理領域内と領域外のすべての非白／非罫線画素を、元の白い隙間で行候補へ分ける。
固定2px余白は隣の行・別の所有者の墨を含めず、削除・重複・所有競合は失敗にする。
罫線マスクで白い隙間を消さず、NN入力の画素も書き換えない。
PNGと既存本体のRGBA由来grayscaleが全画素で一致するかも、枠選択前に検査する。
原画素の網羅性は読字や役割の正しさの証明ではない。

固定PaddleV6と同じページの既定Visionを、literal・実取得セルの一意な所属・
修復／退行・自身のscore条件を通る誤読に分けて比較する。
V6の確率は元のCTCを保持し、Visionのconfidenceへ転用しない。
文字の欠落・分割・広すぎる観測枠・物理所属の不一致は未割当として残すため、
集計は純粋な文字認識率ではなく、初期の取得／所属を含む本文指標である。
本文に重なる未割当領域は別に数える。本文全一致の表示は全項目一致に加え、
その未割当領域が0であることも要求し、余分な認識が残る場合に一致件数だけで合格と呼ばない。
認識の幅上限は明記した未対応結果とし、空欄・成功の本文へ変換しない。

SDK26で最初の探索を行う。Mac SDK27の既定VisionはN06の既知失敗があり、
条件を変えずに再実行しない。先の両iOS SimulatorでのV6 Runtime一致を、
この全文書のiOS取得品質へ読み替えない。
Actionsの成功は比較の完了だけで、精度合格・Builder／Validator・正式採用・実機成功ではない。
アプリ組込み・配信Manifest・追加IPAはこの研究へ含めない。
共有する推論・取得・pin・依存定義の変更もこの比較を起動する。
アプリ全体はhandoff版との無変更を冒頭で検査する、固定条件の探索である。
将来アプリを変更した後の汎用回帰試験として使うには、保護対象と研究条件を明示して別途レビューする。

所有するPDF・フォント・画像・原capture・モデル・依存・ビルド領域は成功／失敗時に削除する。
cache／artifact／追加Releaseは作成しない。原出力と比較値は完全架空のログだけに記録する。
新しいActions開始前は毎回、新規GPT-6.1 Sol／Highによる対象コード差分のみのレビューを行う。

```sh
bash tools/ocr-full-document-transfer/run.sh
```

## v5: actual class-column ink framing

The v4 fixed EnglishV1 suffix trial added no exact body fields at its fixed
conditions. v5 does not download or run it; body metrics remain the original V6
baseline. The helper and negative tests are retained as historical research.

An actual high-own-score `クラス` observation must uniquely belong to the top-left
measured cell. Only the contiguous, unambiguous physical column below that cell
is eligible for a second V6 input. The recognizer receives all original non-rule
ink of each selected cell plus the same bounded two-pixel margin, including
underscores detached by row projection. Original RGB is never erased or rewritten.
A declared overall-height <=1.5 times largest occupied-row-band bound refuses
separated multi-height text. This geometric bound does not prove that arbitrary
ink is one semantic class name. Empty cells, competing columns, additional header
ink, absent labels or unsupported widths remain explicit unsupported outcomes.

Alternative class-cell CTC/probabilities and original projection records are kept
separately. This rereads the same original ink; it does not add original coverage.
Only after all inference is finished does the comparator read the 70 class-name
assertions and measure literal plus actual cell ownership, gain/loss, wrong eligible
outputs and unexpected candidate-cell ink. No candidate is chosen by a class list,
expected literal or oracle coordinates. Body444, header70, mandatory low scores,
full Builder/Validator and physical phone qualification remain distinct.

## v6: independent ASCII reading of the whole class-cell frame

v5 left four high-own-score `AI` to `Al` confusions in the exploratory class cohort.
v6 compares fixed EnglishV1 on the same actual class-cell RGB, separately from V6.
Only a V6 printable-ASCII literal of length2..32 containing a digit is eligible.
The expert recomputes its received source RGB SHA before transformation; selection
rechecks original V6/expert/candidate frame hashes, original results and fixed
same-length alnum/_/- / piece>=.85 / reject<=.05 / padding conditions. Expected
class lists never choose frames or replace literals. Original V6 metrics remain;
selected ASCII class metrics are separate. This is not the failed body-tail trial,
new training, native iOS two-input/output qualification or application adoption.
