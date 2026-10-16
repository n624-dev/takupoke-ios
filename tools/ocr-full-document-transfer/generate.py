#!/usr/bin/env python3
"""Invent image-only whole sources; keep all assertion geometry out of reader input."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import shutil


ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    if path.exists():
        raise ValueError('Never overwrite an earlier source design')
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True) + '\n')


def shared_fetch():
    spec = importlib.util.spec_from_file_location('fixed_public_font_fetch', ROOT.parent / 'ocr-windows-transfer/prepare.py')
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result.fetch


class Drawing:
    def __init__(self, root, identity, width, height, font_path):
        from PIL import Image, ImageDraw
        from fontTools.ttLib import TTFont
        self.root, self.identity, self.width, self.height = root, identity, width, height
        self.font_path = font_path
        self.fonts = {}
        self.image = Image.new('RGB', (width * 2, height * 2), 'white')
        self.draw = ImageDraw.Draw(self.image)
        with TTFont(font_path) as font:
            self.supported = set().union(*(set(t.cmap) for t in font['cmap'].tables if t.isUnicode()))
        self.records = []

    def rule(self, x1, y1, x2, y2):
        self.draw.line((x1 * 2, y1 * 2, x2 * 2, y2 * 2), fill='black', width=2)

    def text(self, value, x, y, size, category, *, cell=None, target=None):
        from PIL import ImageFont
        if not all(ord(c) in self.supported for c in value):
            raise ValueError('Never render an unsupported source glyph')
        if size not in self.fonts:
            self.fonts[size] = ImageFont.truetype(str(self.font_path), size * 2)
        font = self.fonts[size]
        measured = self.draw.textbbox((0, 0), value, font=font, anchor='lt')
        width, height = (measured[2] - measured[0]) / 2, (measured[3] - measured[1]) / 2
        box = [x - width / 2, y, width, height]
        if not (0 <= box[0] and 0 <= y and box[0] + width < self.width and y + height < self.height):
            raise ValueError('Independent source text is outside its page')
        if cell and not (cell[0] + 2 <= box[0] and box[0] + width <= cell[0] + cell[2] - 2 and
                         cell[1] + 2 <= y and y + height <= cell[1] + cell[3] - 2):
            raise ValueError('Independent source text does not fit its physical cell')
        self.draw.text((box[0] * 2, y * 2), value, font=font, anchor='lt', fill='black')
        self.records.append(dict(text=value, box=box, category=category, cell=cell, target=target))

    def finish(self, kind):
        from reportlab.pdfgen import canvas
        from reportlab.lib.utils import ImageReader
        png = self.root / (self.identity + '-source.png')
        if png.exists():
            raise ValueError('Source image already exists')
        self.image.save(png)
        pdf = self.root / (self.identity + '.pdf')
        if pdf.exists():
            raise ValueError('Source PDF already exists')
        c = canvas.Canvas(str(pdf), pagesize=(self.width, self.height), invariant=1, pageCompression=1)
        c.setTitle('Entirely fictional OCR source design')
        c.setAuthor('Independent fictional source generator')
        c.drawImage(ImageReader(self.image), 0, 0, width=self.width, height=self.height)
        c.showPage(); c.save()
        return dict(id=self.identity, kind=kind, pdf=pdf.name, pdfSHA256=sha(pdf.read_bytes()), pageCount=1), dict(
            id=self.identity, sourcePDFSHA256=sha(pdf.read_bytes()), page=1, width=self.width, height=self.height, sourcePNG=png.name,
            sourcePNGSHA256=sha(png.read_bytes()), records=self.records)


def literals(rng, number):
    return ['架空科目' + f'{number:02d}', '架空教員' + rng.choice('甲乙丙丁') + str(number % 10),
            '架空室' + rng.choice(['O0', 'I1', 'S5', 'B8']) + str(number % 10)]


def normal(root, identity, font, rng):
    d = Drawing(root, identity, 1720, 420, font)
    left, class_right, right, top, day_bottom, body, bottom = 24, 104, 1704, 64, 94, 116, 256
    for y in [top, body, bottom]:
        d.rule(left, y, right, y)
    d.rule(class_right, day_bottom, right, day_bottom)
    for x in [left, class_right, right]:
        d.rule(x, top, x, bottom)
    d.text('令和16年度 前期', 230, 25, 14, 'year-term')
    d.text('クラス', 64, 78, 10, 'class-label')
    d.text('1_1', 64, 172, 12, 'class')
    for day, label in enumerate('月火水木金', 1):
        x = class_right + (day - 1) * 320
        d.rule(x, top, x, bottom)
        d.text(label, x + 160, 71, 13, 'weekday')
        for period in range(1, 9):
            column = x + (period - 1) * 40
            d.rule(column, day_bottom, column, bottom)
            d.text(str(period), column + 20, 99, 8, 'period')
            cell = [column, body, 40, bottom-body]
            for role, value, y in zip(['subject', 'teacher', 'room'], literals(rng, (day-1)*8+period), [132, 152, 172]):
                d.text(value, column + 20, y, 6, 'body', cell=cell,
                       target=dict(className='1_1', day=str(day), period=period, role=role))
    return d.finish('timetable')


def special(root, identity, kind, font, rng, classes):
    d = Drawing(root, identity, 720, 900, font)
    left, divider, right, top, split, body, row = 24, 124, 696, 70, 96, 156, 38
    bottom = body + len(classes) * row
    date = '2034-06-19' if kind == 'exam' else '2034-06-26'
    d.text('令和16年度', 130, 20, 14, 'year')
    d.text('試験時間割' if kind == 'exam' else '試験返却時間割', 420, 20, 14, 'document-label')
    for y in [top, body, bottom]:
        d.rule(left, y, right, y)
    d.rule(divider, split, right, split)
    for x in [left, divider, right]:
        d.rule(x, top, x, bottom)
    d.text('クラス', 74, 104, 11, 'class-label')
    d.text('6月19日' if kind == 'exam' else '6月26日', 410, 76, 10, 'date')
    d.text('1限', 410, 103, 10, 'period')
    d.text('09:10~09:55' if kind == 'exam' else '14:20~15:05', 410, 132, 9, 'clock')
    for index, cls in enumerate(classes):
        y = body + index * row
        d.rule(left, y, right, y)
        d.text(cls, 74, y + 12, 10, 'class')
        cell = [divider, y, right-divider, row]
        for role, value, delta in zip(['subject', 'teacher', 'room'], literals(rng, index+41), [5, 15, 25]):
            d.text(value, 410, y+delta, 7, 'body', cell=cell,
                   target=dict(className=cls, day=date, period=1, role=role))
    return d.finish(kind)


def generate(output, font_root=None):
    protocol = json.loads((ROOT / 'protocol.json').read_text())
    font_protocol = json.loads((ROOT.parent / 'ocr-windows-transfer/protocol.json').read_text())
    output.mkdir()
    fonts = output / 'fonts'; fonts.mkdir()
    for pin in font_protocol['fonts']:
        if font_root is not None:
            source = font_root / pin['file']
            if source.stat().st_size != pin['bytes'] or sha(source.read_bytes()) != pin['sha256']:
                raise ValueError('Pinned public font copy changed')
            shutil.copyfile(source, fonts / pin['file'])
        shared_fetch()(pin, fonts)
    inputs, oracle = [], []
    for index, font in enumerate(p for p in font_protocol['fonts'] if p['file'].endswith('.ttf')):
        rng = random.Random(protocol['seed'] + index)
        for kind in ['timetable', 'exam', 'return']:
            identity = f'f{index+1}-{kind}'
            if kind == 'timetable':
                entry, assertion = normal(output, identity, fonts / font['file'], rng)
            else:
                entry, assertion = special(output, identity, kind, fonts / font['file'], rng, protocol['specialClasses'])
            inputs.append(entry); oracle.append(assertion)
    if len(inputs) != protocol['documents'] or sum(r['category'] == 'body' for d in oracle for r in d['records']) != protocol['bodyFields']:
        raise ValueError('Incomplete invented source inventory')
    save(output / 'inputs.json', dict(documents=inputs))
    save(output / 'oracle.json', dict(study=protocol['study'], documents=oracle))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--font-root', type=Path)
    args = parser.parse_args()
    generate(args.output, args.font_root)


if __name__ == '__main__':
    main()
