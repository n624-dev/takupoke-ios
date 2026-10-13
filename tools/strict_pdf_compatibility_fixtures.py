"""Independent source designs for the three Strict PDF entry points.

The oracle comes from the source design, never from parser/OCR output. Only a
pinned public font is downloaded. All output belongs to the caller's scratch.
"""
import argparse
import json
from pathlib import Path
import re
import sys
import unicodedata

import fitz
from reportlab.pdfgen import canvas

sys.path.insert(0, str(Path(__file__).parent / "independent-wide-timetable"))
import generate as public_font

CLASSES = ["1_1", "1_2", "1_3"] + [f"{y}_{c}" for y in range(2, 6)
                                           for c in ("CN", "ES", "IT")] + ["AI_1", "AI_2"]
TIMES = [f"{8+p}:00~{8+p}:40" for p in range(8)]
VALUES = ["架空科目甲", "架空教員乙", "仮想教室丙"]


def finish(path, mode):
    # ReportLab includes unused control-code mappings in its font subset. This
    # independent design has no control text; omit those unused mappings so it
    # exercises the 239 reader as well as current use-site Unicode validation.
    with fitz.open(path) as pdf:
        for xref in range(1, pdf.xref_length()):
            if not pdf.xref_is_stream(xref):
                continue
            stream = pdf.xref_stream(xref)
            if b"begincmap" not in stream:
                continue
            def clean(match):
                pairs = re.findall(rb"(<[0-9A-Fa-f]+>)\s*(<[0-9A-Fa-f]+>)", match[1])
                retained = []
                for code, value in pairs:
                    text = bytes.fromhex(value[1:-1].decode()).decode("utf-16-be")
                    if not any(unicodedata.category(c) == "Cc" for c in text):
                        retained.append(code + b" " + value)
                return str(len(retained)).encode() + b" beginbfchar\n" + b"\n".join(retained) + b"\nendbfchar"
            stream = re.sub(rb"\d+\s+beginbfchar(.*?)endbfchar", clean, stream, flags=re.S)
            pdf.update_stream(xref, stream)
        if mode:
            for page in pdf:
                kind, value = pdf.xref_get_key(page.xref, "Resources")
                if kind == "xref":
                    resources = int(value.split()[0])
                    key = "ExtGState/Compatibility"
                elif kind == "dict":
                    resources = page.xref
                    key = "Resources/ExtGState/Compatibility"
                else:
                    raise ValueError("Independent generator resource shape changed")
                pdf.xref_set_key(resources, key,
                                 "<< /BM [/Normal] /ca 1 /CA 1 >>")
                for xref in page.get_contents():
                    pdf.update_stream(xref, b"/Compatibility gs 0 0 m 1 1 2 2 3 3 c n "
                                      b"[1 3] 0 d [] 0 d\n" + pdf.xref_stream(xref))
        data = pdf.tobytes(garbage=4, deflate=True)
    path.write_bytes(data)


class Drawing:
    def __init__(self, path, width, height, mode):
        self.path, self.height, self.mode = path, height, mode
        self.c = canvas.Canvas(str(path), pagesize=(width, height), invariant=1,
                               pageCompression=1, initialFontName="IndependentJP")
        self.c.setTitle("独立架空Strict互換性資料")
        self.c.setAuthor("Independent fictional source design")

    def text(self, value, x, y, size=7):
        t = self.c.beginText(x, self.height-y)
        t.setFont("IndependentJP", size)
        t.setTextRenderMode(self.mode)
        t.textOut(value)
        self.c.drawText(t)

    def line(self, x1, y1, x2, y2):
        self.c.line(x1, self.height-y1, x2, self.height-y2)

    def page(self):
        self.c.setLineWidth(.2)
        self.c.setLineJoin(1)
        self.c.setFillColorRGB(*(3*[1 if self.mode == 1 else 0]))

    def lesson(self, x, top, pitch=13):
        for role, value in enumerate(VALUES):
            self.text(value, x+8, top+14+role*pitch)

    def save(self):
        self.c.save()
        finish(self.path, self.mode)


def normal(path, mode):
    d = Drawing(path, 3100, 500, mode); d.page()
    left, grade, body, width = 24, 54, 100, 72
    right = body+40*width
    d.text("令和14年度 前期時間割", 140, 30, 12)
    for y in [48, 78, 90, 154, 218, 282]:
        d.line(left, y, right, y)
    for x in [left, grade, body, right]:
        d.line(x, 48, x, 282)
    for col in range(40):
        x = body+col*width
        d.line(x, 48, x, 282)
        d.text(str(col % 8+1), x+width/2, 66, 9)
    for row, cls in enumerate(["1_1", "2_CN", "AI_1"]):
        top = 90+row*64
        year, name = cls.split("_")
        d.text(year, left+8, top+36, 9); d.text(name, grade+8, top+36, 9)
        d.lesson(body+row*9*width, top)
    d.c.showPage(); d.save()


def exam(path, mode):
    d = Drawing(path, 1400, 680, mode)
    for number in range(6):
        d.page()
        classes = CLASSES[number*3:number*3+3]
        body, width, right = 100, 68, 100+len(classes)*6*68
        d.text("令和14年度 試験時間割", 30, 28, 12)
        for col, cls in enumerate(classes):
            label = cls.replace("_", "-") if number < 5 else cls[-1]+"年"
            d.text(label, body+col*6*width+2*width, 76, 9)
        for col in range(len(classes)*6):
            x = body+col*width
            d.text(str(col % 6+1), x+width/2, 106, 9)
            d.line(x, 118, x, 438)
        d.line(0, 118, 0, 438); d.line(right, 118, right, 438)
        for row in range(6):
            top = 118+row*64
            d.line(0, top, right, top)
            if row < 5:
                d.text(f"4月{row+1}日", 16, top+35, 9)
        for col in range(len(classes)):
            d.lesson(body+(col*6+col)*width, 118+col*64)
        for p in range(6):
            d.text(f"{p+1}時限目{TIMES[p]}", 20, 505+p*17, 9)
        d.c.showPage()
    d.save()


def returned(path, mode):
    d = Drawing(path, 3100, 1200, mode); d.page()
    body, width, top, row_h = 140, 72, 120, 40
    right, bottom = body+40*width, top+17*row_h
    d.text("令和14年度 試験返却時間割", 30, 28, 12)
    for col in range(40):
        x = body+col*width
        d.text(str(col % 8+1), x+width/2, 106, 9)
        d.line(x, top, x, bottom)
        if col % 8 == 0:
            d.text(f"4/{col//8+1}", x+2*width, 78, 9)
    d.line(0, top, 0, bottom); d.line(110, top, 110, bottom)
    d.line(right, top, right, bottom)
    for row in range(18):
        d.line(0, top+row*row_h, right, top+row*row_h)
    for row, cls in enumerate(CLASSES):
        grade, name = cls.split("_")
        d.text(name, 120, top+row*row_h+24, 9)
        if row in [1, 4, 7, 10, 13, 15]:
            d.text(grade, 30, top+row*row_h+24, 9)
    d.lesson(body, top, pitch=8)
    d.lesson(body+9*width, top+4*row_h, pitch=8)
    d.lesson(body+39*width, top+16*row_h, pitch=8)
    d.text("4月1日の時間割は以下のとおりです。", 1300, 920, 9)
    d.text("4月2日~5日は通常の授業日どおりの授業時間です。", 1300, 942, 9)
    for p in range(8):
        d.text(f"{p+1}時限目{TIMES[p]}", 20, 1000+p*17, 9)
    d.c.showPage(); d.save()


def generate(output):
    output.mkdir(parents=True, exist_ok=False)
    (output/".strict-compatibility-owned").write_text("v1\n")
    public_font.install_font(output)
    for mode in range(3):
        for name, draw in [("normal", normal), ("exam", exam), ("return", returned)]:
            draw(output/f"{name}-{mode}.pdf", mode)
            # Separate decoration variants; leave the original nine inputs intact.
            decoration = b"q 0.2 0.35 0.6 rg 15 5 60 10 re f Q\n"
            for order in ("before", "after"):
                with fitz.open(output/f"{name}-{mode}.pdf") as pdf:
                    for page in pdf:
                        content = page.read_contents()
                        xref = pdf.get_new_xref()
                        pdf.update_object(xref, "<<>>")
                        painted = decoration+content if order == "before" else content+b"\n"+decoration
                        pdf.update_stream(xref, painted)
                        page.set_contents(xref)
                    destination = output/f"{name}-{mode}-{order}.pdf"
                    destination.write_bytes(pdf.tobytes(garbage=4,deflate=True))
    (output/"design.json").write_text(json.dumps({"values":VALUES,"classes":CLASSES}, ensure_ascii=False)+"\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    generate(parser.parse_args().output)
