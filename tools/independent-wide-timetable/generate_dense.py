#!/usr/bin/env python3
"""Independent compact layout of the already invented lessons; no private inputs.

Only source and assertion JSON belong in Git. All PDFs and public-font copies
are generated into an explicitly owned temporary directory.
"""
import argparse
import json
from pathlib import Path
import random

import fitz
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas

import generate as original

W, H = 1450, 990
LEFT, GRADE_W, CLASS_W, COL_W = 28, 38, 44, 32
TOP, DAY_H, PERIOD_H, ROW_H = 62, 28, 20, 47
BODY_X, BODY_Y = LEFT + GRADE_W + CLASS_W, TOP + DAY_H + PERIOD_H
COLOR_SEED = 704893


def draw(output, variant, classes, cells):
    path = output / (variant + ".pdf")
    c = canvas.Canvas(str(path), pagesize=(W, H), invariant=1, pageCompression=1)
    c.setTitle("完全独立架空時間割 密度比較 " + variant)
    c.setAuthor("Independent fictional test generator")
    c.setCreator("independent-dense-timetable v1")
    rng = random.Random(COLOR_SEED)
    # Independent fixed choices; no OCR result or expected-role lookup.
    colored_indices = set(rng.sample(range(200, 4000), 12))
    character_index, colored = 0, []
    dark = variant.endswith("darkblue")
    labeled = "labeled-control" in variant

    def line(x1, y1, x2, y2):
        c.line(x1, H-y1, x2, H-y2)

    def text(value, x, y, size, centered=True):
        nonlocal character_index
        c.setFont("IndependentJP", size)
        width = pdfmetrics.stringWidth(value, "IndependentJP", size)
        left = x-width/2 if centered else x
        if left < 0 or left+width > W or not 0 < y < H:
            raise ValueError("Independent drawing outside the page")
        # Both black and color variants use identical character operators.
        # Thus segmentation is controlled separately from the color change.
        for ch in value:
            selected = character_index in colored_indices
            c.setFillColorRGB(.02, .04, .12) if dark and selected else c.setFillColorRGB(0, 0, 0)
            c.drawString(left, H-y, ch)
            if dark and selected:
                colored.append({"characterIndex": character_index, "x": left, "baselineY": y, "text": ch})
            left += pdfmetrics.stringWidth(ch, "IndependentJP", size)
            character_index += 1

    right, bottom = BODY_X+40*COL_W, BODY_Y+len(classes)*ROW_H
    c.setLineWidth(.45)
    text("令和14年度 後期 完全独立架空時間割", LEFT, 33, 12, False)
    text("学年", LEFT+GRADE_W/2, TOP+31, 8)
    text("クラス", LEFT+GRADE_W+CLASS_W/2, TOP+31, 8)
    line(LEFT, TOP, right, TOP)
    line(BODY_X, TOP+DAY_H, right, TOP+DAY_H)
    line(LEFT, BODY_Y, right, BODY_Y)
    for x in (LEFT, LEFT+GRADE_W, BODY_X, right):
        line(x, TOP, x, bottom)
    for day in range(5):
        x = BODY_X+day*8*COL_W
        line(x, TOP, x, BODY_Y)
        text(original.DAY_NAMES[day], x+4*COL_W, TOP+18, 10)
        for period in range(1, 9):
            px = x+(period-1)*COL_W
            line(px, TOP+DAY_H, px, BODY_Y)
            text(str(period), px+COL_W/2, BODY_Y-6, 6)
    for row, cls in enumerate(classes):
        y = BODY_Y+row*ROW_H
        line(LEFT+GRADE_W, y, right, y)
        text(cls.split("_")[1], LEFT+GRADE_W+CLASS_W/2, y+27, 9)
    start = 0
    while start < len(classes):
        grade = classes[start].split("_")[0]
        end = start+1
        while end < len(classes) and classes[end].split("_")[0] == grade:
            end += 1
        line(LEFT, BODY_Y+start*ROW_H, LEFT+GRADE_W, BODY_Y+start*ROW_H)
        text(grade, LEFT+GRADE_W/2, BODY_Y+(start+end)*ROW_H/2+3, 10)
        start = end
    line(LEFT, bottom, right, bottom)
    for cell in cells:
        x = BODY_X+((cell["weekday"]-1)*8+cell["firstPeriod"]-1)*COL_W
        y = BODY_Y+cell["row"]*ROW_H
        span = cell["periodCount"]
        line(x, y, x, y+ROW_H)
        line(x+span*COL_W, y, x+span*COL_W, y+ROW_H)
        for i, role in enumerate(("subject", "teacher", "room")):
            if not cell["lessons"]:
                continue
            value = "・".join(lesson[role] for lesson in cell["lessons"])
            if labeled:
                value = ("科目：", "担当：", "教室：")[i]+value
            if value:
                width = pdfmetrics.stringWidth(value, "IndependentJP", 3.1)
                if width >= span*COL_W-2:
                    raise ValueError("Independent content does not fit its measured cell")
                text(value, x+span*COL_W/2, y+13+i*12, 3.1)
    text("架空注記：独立生成した密度比較用資料。実在の学校・授業とは無関係です。", LEFT, bottom+27, 8, False)
    c.showPage(); c.save()
    with fitz.open(path) as doc:
        if len(doc) != 1 or "架空科目" not in doc[0].get_text():
            raise ValueError("Public PDF health check failed; this is not application Reader proof")
    if dark and len(colored) != 12:
        raise ValueError("Independent color selection count changed")
    return path, colored, character_index


def generate(source_root, output, font_file, class_contract=None):
    output.mkdir(parents=True, exist_ok=False)
    (output/".independent-dense-timetable-owned").write_text("v1\n", encoding="utf-8", newline="\n")
    classes, source_sha = original.canonical_classes(source_root, class_contract)
    cells = original.design(classes)
    oracle = original.expected(classes, cells)
    data = (json.dumps(oracle, ensure_ascii=False, indent=2)+"\n").encode()
    (output/"expected.json").write_bytes(data)
    original.install_font(output, font_file)
    artifacts = []
    for kind in ("unlabeled", "labeled-control"):
        for color in ("black", "darkblue"):
            variant = "dense-"+kind+"-"+color
            path, colored, count = draw(output, variant, classes, cells)
            artifacts.append({"variant":variant,"file":path.name,"bytes":path.stat().st_size,
                              "sha256":original.digest(path.read_bytes()),"coloredCharacters":colored,
                              "drawnCharacters":count,"expectedSlots":680})
    manifest = {"schemaVersion":1,"scope":"independent compact source-only comparison; not OCR/model proof",
                "layout":{"width":W,"height":H,"left":LEFT,"gradeWidth":GRADE_W,"classWidth":CLASS_W,
                          "periodWidth":COL_W,"top":TOP,"dayHeight":DAY_H,"periodHeight":PERIOD_H,"rowHeight":ROW_H},
                "colorSeed":COLOR_SEED,"colorRGB":[.02,.04,.12],"lessonSeed":original.SEED,
                "generatorSha256":original.digest(Path(__file__).read_bytes()),
                "baseGeneratorSha256":original.digest(Path(original.__file__).read_bytes()),
                "canonicalClassSourceLineSha256":source_sha,"fontSha256":original.FONT_SHA,
                "fontLicenseSha256":original.LICENSE_SHA,"expectedSha256":original.digest(data),"artifacts":artifacts,
                "limits":["Original wide v1 fixture is unchanged.","Dark color remains subject to existing Reader visibility guards.",
                          "Gold is assertion-only; no role scopes or source IDs supplied from it.",
                          "Black/color character segmentation is identical; all coordinates newly specified here."]}
    (output/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--font-file",type=Path,required=True)
    parser.add_argument("--class-contract",type=Path)
    args = parser.parse_args()
    print(json.dumps(generate(args.source_root,args.output,args.font_file,args.class_contract),ensure_ascii=False))
