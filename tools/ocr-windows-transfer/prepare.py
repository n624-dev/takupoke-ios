#!/usr/bin/env python3
"""Create an independent, recognizer-only screen; oracle stays out of readers."""
import argparse
import hashlib
import json
from pathlib import Path
import random
import urllib.request


ROOT = Path(__file__).resolve().parent


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fetch(pin, folder):
    path = folder / pin['file']
    if not path.exists():
        with urllib.request.urlopen(pin['url'], timeout=120) as response:
            data = response.read(pin['bytes'] + 1)
        if len(data) != pin['bytes'] or digest(data) != pin['sha256']:
            raise ValueError('Pinned download mismatch: ' + pin['file'])
        path.write_bytes(data)
    if path.stat().st_size != pin['bytes'] or digest(path.read_bytes()) != pin['sha256']:
        raise ValueError('Pinned local artifact mismatch: ' + pin['file'])
    return path


def design(protocol, font_index, supported):
    rng = random.Random(protocol['seed'] + font_index)
    values, seen = [], set()
    variants = [c for c in '渡邊渡邉齋藤齊藤高橋髙橋' if ord(c) in supported]
    if not variants:
        raise ValueError('No native variant glyphs')
    for group in protocol['groups']:
        for i in range(protocol['itemsPerGroupPerFont']):
            while True:
                suffix = ''.join(rng.choice('ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz') for _ in range(4))
                if group == 'mixed-code':
                    value = rng.choice('BODI') + suffix + rng.choice('0101') + str(rng.randrange(10)) + ('_-'[i % 2] if i % 3 == 0 else '')
                elif group == 'alphabetic':
                    value = 'Fx' + suffix + rng.choice('IlOo')
                elif group == 'numeric':
                    value = str(rng.randrange(10000, 1000000))
                elif group == 'japanese':
                    value = rng.choice(['架空科目', '架空教員', '架空教室']) + rng.choice('甲乙丙丁戊己庚辛') + str(rng.randrange(100, 1000))
                elif group == 'variant-japanese':
                    value = '架空' + rng.choice(variants) + rng.choice('甲乙丙丁') + str(rng.randrange(100, 1000))
                elif group == 'english':
                    value = 'Fiction ' + suffix + ' ' + rng.choice(['Lab', 'Tutor', 'Study'])
                else:
                    raise ValueError('Unknown group')
                if value not in seen:
                    break
            if not all(ord(c) in supported for c in value):
                raise ValueError('Never render unsupported glyphs as tofu')
            seen.add(value)
            values.append(dict(group=group, text=value, fontPixels=protocol['fontSizes'][i % 3]))
    rng.shuffle(values)
    return values


def generate(protocol, output):
    from fontTools.ttLib import TTFont
    from PIL import Image, ImageDraw, ImageFont
    from reportlab.pdfgen import canvas
    from reportlab.lib.utils import ImageReader

    fonts = output / 'fonts'
    fonts.mkdir()
    for pin in protocol['fonts']:
        fetch(pin, fonts)
    width, height = protocol['pagePixels']
    pdf = canvas.Canvas(str(output / 'fictional.pdf'), pagesize=(width / 2, height / 2), invariant=1, pageCompression=1)
    pages, expected = [], []
    number = 0
    for font_index, pin in enumerate(p for p in protocol['fonts'] if p['file'].endswith('.ttf')):
        font_path = fonts / pin['file']
        with TTFont(font_path) as font:
            supported = set().union(*(set(t.cmap) for t in font['cmap'].tables if t.isUnicode()))
        values = design(protocol, font_index, supported)
        for offset in range(0, len(values), protocol['itemsPerPage']):
            number += 1
            image = Image.new('RGB', (width, height), 'white')
            draw = ImageDraw.Draw(image)
            regions = []
            for index, item in enumerate(values[offset:offset + protocol['itemsPerPage']]):
                row, col = divmod(index, 4)
                x, y = 40 + col * 460, 40 + row * 254
                draw.rectangle((x, y, x + 450, y + 230), outline='black', width=2)
                face = ImageFont.truetype(str(font_path), item['fontPixels'])
                # Text placement does not determine the crop's ink extent.
                bounds = draw.textbbox((0, 0), item['text'], font=face)
                if bounds[2] - bounds[0] > 406 or bounds[3] - bounds[1] > 120:
                    raise ValueError('Fixture text does not fit its physical cell')
                draw.text((x + 22, y + 84), item['text'], fill='black', font=face, anchor='lt')
                identity = f'p{number}-f{index + 1}'
                # Entire inner physical cell, including whitespace; no answer or
                # text bounding box goes into the reader's region manifest.
                regions.append(dict(id=identity, box=[x + 4, y + 4, 442, 222]))
                expected.append(dict(id=identity, page=number, font=pin['file'], **item))
            png = output / f'source-{number}.png'
            image.save(png)
            pdf.drawImage(ImageReader(image), 0, 0, width=width / 2, height=height / 2)
            pdf.showPage()
            pages.append(dict(page=number, width=width, height=height, regions=regions, sourcePNG=png.name, sourcePNGHash=digest(png.read_bytes())))
    pdf.save()
    if len(expected) != protocol['maximumFields'] or number != 6:
        raise ValueError('Unexpected study inventory')
    write(output / 'inputs.json', dict(pdf='fictional.pdf', pdfSHA256=digest((output / 'fictional.pdf').read_bytes()), pages=pages))
    write(output / 'oracle.json', dict(fields=expected))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--models-only', action='store_true')
    args = parser.parse_args()
    protocol = json.loads((ROOT / 'protocol.json').read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    if args.models_only:
        for pin in protocol['models']:
            fetch(pin, args.output)
    else:
        if any(args.output.iterdir()):
            raise ValueError('Fixture output must be fresh')
        generate(protocol, args.output)


if __name__ == '__main__':
    main()
