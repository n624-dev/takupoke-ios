#!/usr/bin/env python3
"""Freeze complete independently invented sources before looking at OCR output."""
import argparse
import importlib.util
import json
from pathlib import Path
import random
import shutil

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('independent_drawing_primitives', ROOT.parent/'ocr-full-document-transfer/generate.py')
shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)


def values(rng):
    # Fresh invented prefixes; no name map, original school data or GT crop hints.
    return ['架空講座'+f'{rng.randrange(100):02d}', '架空担当'+rng.choice('甲乙丙丁')+str(rng.randrange(10)),
            '架空棟'+rng.choice(['O0', 'I1', 'S5', 'B8'])+str(rng.randrange(10))]


def normal(output, identity, font, rng, classes):
    d = shared.Drawing(output, identity, 1720, 800, font)
    left, divider, right, top, day_bottom, body, row = 24, 104, 1704, 64, 94, 116, 38
    bottom = body+row*len(classes)
    d.text('令和17年度 後期', 230, 25, 14, 'year-term')
    for y in [top, body, bottom]: d.rule(left, y, right, y)
    d.rule(divider, day_bottom, right, day_bottom)
    for x in [left, divider, right]: d.rule(x, top, x, bottom)
    d.text('クラス', (left+divider)/2, 78, 10, 'class-label')
    for day, label in enumerate('月火水木金', 1):
        x = divider+(day-1)*320
        d.rule(x, top, x, bottom); d.text(label, x+160, 71, 13, 'weekday')
        for period in range(1, 9):
            column = x+(period-1)*40
            d.rule(column, day_bottom, column, bottom)
            d.text(str(period), column+20, 99, 8, 'period')
    for ordinal, cls in enumerate(classes):
        y = body+ordinal*row
        d.rule(left, y, right, y); d.text(cls, (left+divider)/2, y+12, 10, 'class')
        for day in range(1, 6):
            for period in range(1, 9):
                column = divider+(day-1)*320+(period-1)*40
                cell = [column, y, 40, row]
                for role, text, delta in zip(['subject','teacher','room'], values(rng), [5,15,25]):
                    d.text(text, column+20, y+delta, 6, 'body', cell=cell,
                        target=dict(className=cls, day=str(day), period=period, role=role))
    return d.finish('timetable')


def special(output, identity, font, rng, classes, kind):
    d = shared.Drawing(output, identity, 1816, 900, font)
    left, divider, right, top, day_bottom, period_bottom, body, row = 24, 124, 1792, 70, 96, 122, 156, 38
    count = 6 if kind == 'exam' else 8
    day_width = (right-divider)/5; width = day_width/count
    bottom = body+len(classes)*row
    d.text('令和17年度', 130, 20, 14, 'year')
    d.text('試験時間割' if kind == 'exam' else '試験返却時間割', 1000, 20, 14, 'document-label')
    for y in [top, body, bottom]: d.rule(left, y, right, y)
    for y in [day_bottom, period_bottom]: d.rule(divider, y, right, y)
    for x in [left, divider, right]: d.rule(x, top, x, bottom)
    d.text('クラス', (left+divider)/2, 104, 11, 'class-label')
    for day in range(5):
        x = divider+day*day_width
        d.rule(x, top, x, bottom)
        date = 18+day if kind == 'exam' else 25+day
        d.text(f'6月{date}日', x+day_width/2, 76, 10, 'date')
        for period in range(1, count+1):
            column = x+(period-1)*width
            d.rule(column, day_bottom, column, bottom)
            d.text(f'{period}限', column+width/2, 103, 8, 'period')
            start = 8*60+30+(period-1)*50; end = start+40
            clock = f'{start//60:02d}:{start%60:02d}~{end//60:02d}:{end%60:02d}'
            d.text(clock, column+width/2, 132, 6, 'clock')
    for ordinal, cls in enumerate(classes):
        y = body+ordinal*row
        d.rule(left, y, right, y); d.text(cls, (left+divider)/2, y+12, 10, 'class')
        for day in range(5):
            date = 18+day if kind == 'exam' else 25+day
            for period in range(1, count+1):
                column = divider+day*day_width+(period-1)*width
                cell = [column, y, width, row]
                for role, text, delta in zip(['subject','teacher','room'], values(rng), [5,15,25]):
                    d.text(text, column+width/2, y+delta, 6, 'body', cell=cell,
                        target=dict(className=cls, day=f'2035-06-{date:02d}', period=period, role=role))
    return d.finish(kind)


def generate(output, case, font_root=None):
    protocol = json.loads((ROOT/'protocol.json').read_text())
    if case not in protocol['cases']: raise ValueError('Undeclared frozen source case')
    output.mkdir(); fonts = output/'fonts'; fonts.mkdir()
    font_index = int(case[1])-1; kind = case.split('-',1)[1]
    pins = json.loads((ROOT.parent/'ocr-windows-transfer/protocol.json').read_text())['fonts']
    pin = [p for p in pins if p['file'].endswith('.ttf')][font_index]
    for entry in [p for p in pins if p['file'].endswith('.ttf')]:
        if font_root is not None:
            original = font_root/entry['file']
            if original.stat().st_size != entry['bytes'] or shared.sha(original.read_bytes()) != entry['sha256']:
                raise ValueError('Pinned public font copy changed')
            shutil.copyfile(original, fonts/entry['file'])
        shared.shared_fetch()(entry, fonts)
    font = fonts/pin['file']
    identity = 'qualification-'+case
    rng = random.Random(protocol['seed']+protocol['cases'].index(case))
    if kind == 'timetable': entry, oracle = normal(output, identity, font, rng, protocol['classes'])
    else: entry, oracle = special(output, identity, font, rng, protocol['classes'], kind)
    if sum(r['category']=='body' for r in oracle['records']) != protocol['requiredBodyFields'][kind]:
        raise ValueError('Complete source body inventory changed')
    if sum(r['category']=='class' for r in oracle['records']) != protocol['requiredClassNames']:
        raise ValueError('Complete source class inventory changed')
    shared.save(output/'inputs.json', dict(documents=[entry]))
    shared.save(output/'oracle.json', dict(study=protocol['study'], documents=[oracle]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--case', required=True)
    parser.add_argument('--font-root', type=Path)
    args = parser.parse_args(); generate(args.output, args.case, args.font_root)


if __name__ == '__main__': main()
