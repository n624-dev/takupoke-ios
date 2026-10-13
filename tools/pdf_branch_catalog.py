"""Index fixed Strict rejection codes from public source only; never reads PDFs."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SOURCES = {
    "PDFAnalysis.swift": "ページの文字・罫線が表示範囲に入るか",
    "PDFCharacterGeometry.swift": "文字と選択範囲の対応",
    "PDFContentVisibility.swift": "色・破線・clip・表示タグ",
    "PDFDiagnostics.swift": "PDF以外のエラーを失敗表示へ変換",
    "PDFDrawnTextReader+Fonts.swift": "字体・文字対応表・幅の読み取り",
    "PDFDrawnTextReader.swift": "PDF文字描画命令・描画状態",
    "PDFGrid.swift": "セルの境界・原文の行・授業欄の対応",
    "PDFKitReader.swift": "ファイル・ページ・PDFKit選択・表示領域",
    "PDFPaintSpace.swift": "色空間・ICCプロファイルの支持範囲と上限",
    "PDFPathReader.swift": "罫線・塗り図形・文字との重なり",
    "PDFSchoolParser+Events.swift": "旧行事PDFの列・日付・行",
    "PDFSchoolParser+Timetable.swift": "通常時間割のクラス・曜日・時限・授業",
    "PDFSchoolParser.swift": "文書全体・年度・資料名・ページ数",
    "PDFTextGeometry.swift": "文字の描画状態・文字位置・Unicode照合",
    "PDFUnicodeMap.swift": "ToUnicodeの書式・重複・範囲・文字幅",
    "SpecialScheduleParser+Pages.swift": "試験・返却のページ構成・日付・クラス",
    "SpecialScheduleParser+Times.swift": "試験・返却の時刻・時限",
    "SpecialScheduleParser.swift": "試験・返却の文書全体と授業欄",
}
STAGES = dict(zip(
    ["characterMapping", "pageRotation", "yearHeading", "documentHeading", "periodHeading",
     "gridColumn", "gridRow", "gridCell", "eventColumns", "calendarDates", "monthHeading",
     "vectorObjects", "textOrder", "classLabel", "gradeLabel", "duplicateClass", "lessonLines",
     "parallelLessons", "emptySubject", "fragmentOverlap", "fragmentAlignment", "rasterInput",
     "paintVisibility", "clippingBounds", "contentTags"],
    [f"P{number:02d}" for number in range(1, 26)]))

NOTES = {
    "121": "曲線を実際に描く、または破線で罫線を描く",
    "122": "塗りまたは線の色が可視と確認できない",
    "123": "文字描画後の塗りに対して元文字の範囲がない",
    "124": "塗り矢印が元文字に重なる、または範囲を取得できない",
    "125": "塗り図形が閉じた軸平行矩形ではない",
    "126": "矩形の四隅が各1回の対応でない。旧版では辺・原文字範囲・重なりも同じ番号",
    "263": "矩形の辺が軸平行でない",
    "264": "罫線以外の矩形について原文字範囲の根拠がない",
    "265": "文字と重なる塗りが文字描画後、線付き、または細い罫線",
    "266": "文字描画前の背景の実描画色を確認できない",
    "267": "背景と後続文字の実描画色のコントラストを保証できない",
    "268": "背景より前の罫線・矢印・他の描画が背景で消える可能性がある",
    "269": "背景と後続の罫線・矢印・装飾の色のコントラストを保証できない",
    "270": "背景の塗りに複数subpathがあり、偶奇／windingの穴や消去を除外できない",
    "271": "背景の単色描画だけでは有効／未知のoverprint合成を確認できない",
    "127": "罫線の変換が角度保持でない、または変換後の線幅が支持範囲外",
    "128": "罫線の辺が軸平行でない、または元文字と重なる",
    "140": "XObjectの描画がある",
    "141": "破線設定の配列を読み取れない",
    "142": "破線設定の形式・値が不正",
    "143": "線幅が負である",
    "144": "ExtGStateの透明度・mask・blend・字体・線幅等が支持範囲外",
    "145": "文字描画モードが0／1／2以外",
    "147": "輪郭文字に破線または支持範囲外の線幅が使われる",
    "148": "inline画像またはshadingの描画がある",
    "150": "描画状態の保存／復元が釣り合わない",
    "153": "輪郭文字の描画範囲が罫線や塗り図形と重なる",
}


def document(root=ROOT):
    declared = re.findall(r'b(\d{3}) = "R\1"', (root / "Takupoke/PDFParseError.swift").read_text())
    rows, seen = [], set()
    for name, description in SOURCES.items():
        source = (root / "Takupoke" / name).read_text()
        # Every failure creation site owns one fixed code. The text helper alone
        # forwards its caller's code, instead of replacing it with a shared code.
        creation_count = len(re.findall(r'PDFParseError\(|PDFTextFailure\.unsupported\(', source))
        identifiers = list(re.finditer(r'(?:branch:\s*|unsupported\()\.b(\d{3})', source))
        if name == "PDFTextGeometry.swift":
            creation_count -= 1
        if creation_count != len(identifiers):
            raise ValueError(f"Missing or extra Strict branch: {name}")
        for match in identifiers:
            identifier = match[1]
            if identifier in seen:
                raise ValueError(f"Reused Strict branch R{identifier}")
            seen.add(identifier)
            line = source.count("\n", 0, match.start()) + 1
            start = source.rfind("\n", 0, match.start()) + 1
            end = source.find("\n", match.end())
            text = source[start:end if end >= 0 else len(source)]
            stage = re.search(r'stage:\s*\.(\w+)', text)
            label = STAGES.get(stage[1], "呼出元") if stage else (
                "P01" if "PDFTextFailure.unsupported" in text else "分類なし／呼出元")
            # The source excerpt identifies the exact check without duplicating
            # its expected result in a test. Links remain the full condition.
            condition = text.split("PDFParseError(")[0].split("PDFTextFailure.unsupported")[0]
            condition = NOTES.get(identifier, condition.strip())
            if len(condition) < 25:
                condition = "複合条件の拒否。実装リンクの条件全文を参照"
            condition = condition.replace("|", "&#124;").replace("`", "'")
            rows.append((identifier, name, line, label, description, condition))
    if set(declared) != seen or len(declared) != len(seen):
        raise ValueError("Strict branch enum and source sites differ")
    header = ["# Strict PDF解析の詳細番号", "",
              "通常・試験・試験返却のStrict解析と共通判定の拒否箇所を示す一覧。",
              "原PDFは239.1で読めた時から不変。番号付き版の実機では3種類すべてP12／R126で拒否された。", "",
              "画面のP01〜P25は大分類、R番号は実装内の失敗生成箇所を示す。",
              "例えばP12とR127なら、罫線の変換・線幅を確認する条件で拒否された。",
              "資料の種類・P番号・R番号・ページ番号だけを伝えればよく、本文や画像は不要。",
              "複合guardは1箇所として扱う。その中のどの条件かまでは番号だけで断定しない。",
              "R126の条件は四隅／R263の辺／R264の根拠／R265の重なりに分離した。旧保存番号は変更しない。",
              "呼出元が分類を付け直した場合、画面のP番号と表の生成時分類が異なる場合がある。", "",
              "番号は固定enum。既存番号を別の条件へ転用せず、新しい箇所は未使用番号を追加する。",
              "本文・座標・フォント名・色・原本情報を番号に含めず、自動送信や診断コピーを追加しない。",
              "旧保存エラーは番号なしで復元する。手動の解析は新たにReaderを実行する。",
              "番号は拒否理由の識別用。幅広矩形の扱いを修正しても、実資料の復旧は別に確認する。", "",
              "外部エラーが診断helperで変換された場合、番号は変換箇所を示す。元エラーの原因までは示さない。",
              "共通ヘルパーを復旧処理が使う場合も同じ番号になるため、番号だけで経路は判断しない。", "",
              "更新: `python3 -B tools/pdf_branch_catalog.py write`。",
              "整合性: `python3 -B tools/pdf_branch_catalog.py check`。学校資料は読み込まない。", "",
              f"## 対応一覧（{len(rows)}箇所）", ""]
    for name, description in SOURCES.items():
        header += [f"### {description}", "", "| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |",
                   "|---|---|---|---|"]
        for identifier, filename, line, label, _, condition in rows:
            if filename == name:
                link = f"[確認条件](../Takupoke/{filename}#L{line})"
                header.append(f"| R{identifier} | {label} | `{condition}` | {link} |")
        header.append("")
    return "\n".join(header)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["write", "check"])
    args = parser.parse_args()
    target = ROOT / "docs/strict-pdf-branch-catalog.md"
    content = document()
    if args.command == "write":
        target.write_text(content)
    elif target.read_text() != content:
        raise SystemExit("Strict branch document is stale; run pdf_branch_catalog.py write")


if __name__ == "__main__":
    main()
