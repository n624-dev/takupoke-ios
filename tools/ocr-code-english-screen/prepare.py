"""Independent code glyphs; no expected text enters either recognizer."""
import argparse
import importlib.util
import json
from pathlib import Path
from code_english_contract import COUNT, ROOT, public_pins, sha


def generate(destination, fonts):
    from PIL import Image, ImageChops, ImageDraw, ImageFont
    protocol = json.loads((ROOT/'protocol.json').read_text())
    pins = {p['file']:p for p in public_pins()['fonts']}
    if (len(protocol['words']) != 16 or len(set(protocol['words'])) != 16 or
            protocol['fields'] != COUNT or protocol['sizes'] != [10,14,20,24,32,40] or
            protocol['fonts'] != ['KaiseiOpti-Regular.ttf','ZenKakuGothicAntique-Medium.ttf']):
        raise ValueError('Frozen developmental inventory changed')
    for name in protocol['fonts']:
        data = (fonts/name).read_bytes()
        if len(data) != pins[name]['bytes'] or sha(data) != pins[name]['sha256']:
            raise ValueError('Original font differs from the public pin')
    destination.mkdir()
    frames, oracle = [], []
    for font in protocol['fonts']:
        for size in protocol['sizes']:
            for word in protocol['words']:
                canvas = Image.new('RGB',(400,100),'white')
                ImageDraw.Draw(canvas).text((10,10),word,font=ImageFont.truetype(str(fonts/font),size),fill='black',anchor='lt')
                bounds = ImageChops.invert(canvas).getbbox()
                if bounds is None:
                    raise ValueError('An independently printed word has no ink')
                a,b,c,d = bounds
                image = canvas.crop((max(0,a-2),max(0,b-2),min(canvas.width,c+2),min(canvas.height,d+2)))
                raw = image.tobytes(); identity = f'code-{len(frames):04}'
                (destination/(identity+'.rgb')).write_bytes(raw)
                frames.append(dict(id=identity,rgb=identity+'.rgb',rgbSHA256=sha(raw),width=image.width,height=image.height))
                oracle.append(dict(id=identity,text=word,font=font,size=size))
    if len(frames) != COUNT:
        raise ValueError('Missing developmental source frames')
    (destination/'inputs.json').write_text(json.dumps(dict(frames=frames),sort_keys=True)+'\n')
    (destination/'oracle.json').write_text(json.dumps(dict(fields=oracle),sort_keys=True)+'\n')


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--output',required=True,type=Path); args = parser.parse_args()
    args.output.mkdir()
    fonts = args.output/'fonts'; fonts.mkdir()
    models = args.output/'models'; models.mkdir()
    spec = importlib.util.spec_from_file_location('fixed_public_download',ROOT.parent/'ocr-windows-transfer/prepare.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    pins = public_pins()
    for pin in pins['fonts']:
        module.fetch(pin,fonts)
    for pin in pins['models']:
        if pin['file'] in ['ascii-rec.onnx','ascii-dictionary.json']:
            module.fetch(pin,models)
    generate(args.output/'inputs',fonts)


if __name__ == '__main__':
    main()
