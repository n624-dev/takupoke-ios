# 新規無ラベル40コマ画像：固定Default Document認識1回

実SDKコンパイル・CI6テスト・ネイティブ実行・3ストリームのSHA付き復元は成功した。新造UIKit画像へのDefault `RecognizeDocumentsRequest` は試行1/返却1、全取得対象global/top1/top5の保存は完了（省略0）。ただし元のf8 `.layouts` は2番目の候補「前艱」confidence .7114で `ambiguous/rasterInput` を返した。Builder・Rules・ValidatorV5・Conversionは未到達、Analysis40コマ照合と正式保存品質は **UNASSESSED**。実行成功を復旧成功に数えていない。

公開Source: `c84b14a403377537642ff2f053cddecce483b313`、実行[37247509343](https://github.com/n624-dev/takupoke-ios/actions/runs/37247509343)。Production baselineはf8b0ca476d6fe6c5627231b1f24f32e73cb816f1。34原本source hash/30dependencyを検証し、元 `.layouts` のRGBA/rasterと観測→glyph/rulesのstatement bytesを機械的に保持した。閾値.85/全文字rangebox/取消/上限を変更せず、別ownerの全頁インク安全修正を混入していない。追加研究用globalInk診断も元.layout拒否のため未到達。

完全新規のcanonical1_2×5曜日×8時限、未結合・全present・無ラベルsubject/teacher/room3行を描画した。共有semantic drawing SHA25e8f581…/assertion oracle SHA448d13ae…は以前のsource-fitモデル不使用40コマ通過と同じだが、UIKit system fontとPillow font/pixelsは異なる。元学校PDF・名前・科目/教員/教室対応・元画像・過去OCR出力は、このgenerator・認識・期待値・CI・公開物の入力に使用していない。学校原本の親エージェントによる理解用閲覧は別作業で、workspaceコピー削除済み。このphaseはPDF入力0。

3740×800 logical basis/font20をproductionの `min(2,2048/max(bounds))` とceil寸法に合わせ直接UIKit描画し、実CGImage2048×439/font約10.95pxとなった。PDFKit thumbnailそのもの・実PDFReader endpoint・同一Windows画像の比較ではない。PNG49791B SHAa890c6ac…、8bit32bpp/row8192/sRGB/provider3596288B SHA f7c17900…を認識前に記録。losslessPNGをメモリ内RGBAへ復号したSHAはproviderと一致した。一時のownedPNGは視覚確認後marker確認で削除し残0、CIのownedPNG/simulatorもcleanup成功。画像はGitに含めない。

実global23行、top1=23/top5=23（各line代替は1候補のみ）、native table0。15候補が.85未満、返却108 Swift Character（top1とtop5を独立保存して計216）、missing rangebox0/原boxpredicate違反0。年「令和14年度」正字/.9204、学期は誤字「前艱」/.7114、タイトルも誤字。月曜日/火曜日は正字。入力画像では全5曜日・40時限数字・分離したgrade1/class2・全授業3行が見えるが、時限見出しの元位置付き観測0/40、grade/class元位置0、科目行のsource文字列0/40。学年/時限数字と同じ数字が年やBODY文字列に出現しても見出し証拠にしない。native table0なので今回取り出した表を隠したとはいえない。nested contents/optional words/潜在候補はこの固定baselineの取得対象外であり未評価。

posthocはraw Unicode piece境界を保持し、元source-generated printed cellとの位置を独立照合する。BODY120成分のsource literal raw部分文字列13、同cell内の余分な文字を拒否したrange中心10/full range containment5（原confidence+boxpredicateを通るのは1）。曜日はraw正字かつ中心2/5、full containment0/5：返却範囲が境界を僅かに越えるためで、未認識という意味ではない。全3成分が揃うBODY40tupleは位置診断0/40。これもAnalysis/Validator/正式保存品質のaccuracy0とは別。substring inventory、中心、全range containment、whole candidate exact、confidenceを各々raw/derivedに保持し、精密glyph ink/unique ownershipの証明にしない。

nativeへ渡したのは実CGImageのみ。drawing/oracle role・layout・scope・blank flagをBuilderへ注入していない。oracleファイルを開くのはactualAnalysis返却後のassertionだけで、今回はAnalysis不返却のためネイティブ認識プロセスはoracle未読。代替候補採用・bboxclamp・空白正規化・時限/教室補完・モデルdownload/invocation・保存/採用0。ordinary-real-PDF・現期間元file確認・手動採用・保存transaction・merged/parallel/verifiedBlank・実iPhone・モデル品質は未評価。このrouteを同じwholepage/presetで反復しない。

`native-output.json` は**元のimage-bearing input record全体を除外**した4recordsの元UTF8行bytesをgzip+base64保存する。PNG/base64imageは圧縮payloadにも含めない。省略lineのbytes/SHA、元stdout/選択rawのbytes/SHAをprovenanceに保持する。元full rawは公開物から復元できない。`input-metadata.json` は選択したCG metadataであり元rawlineではない。`execution.json` と空のstderrのSHAを含む `transport-restoration.json` はexact3stream取得を記録する。raw/providerSHAは元画像の公開や独立再レンダリングの同一性を意味しない。

再集計: `python3 analyze.py native-output.json /tmp/ios-unlabeled-forty-derived.json`。生成されたJSONは `derived-evidence.json` とbyte一致する。public側のPNGは無く、`pixel-verification.json` のlocal memory byte-checkを再実施する材料は提供しない。byte-manifestはこのREADME以外も含む公開各file（manifest自身以外）のbytes/SHAを固定する。追加native0のdata-only公開。
