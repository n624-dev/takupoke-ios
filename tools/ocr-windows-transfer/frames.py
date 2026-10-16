#!/usr/bin/env python3
"""Frame observed physical-cell ink without reading any expected/OCR text."""
import argparse
import hashlib
import json
from pathlib import Path


def ink_box(image, margin=2):
    import numpy as np
    pixels = np.asarray(image.convert('RGB'))
    yy, xx = np.where(pixels.min(axis=2) < 250)
    if not len(xx):
        return None
    return (max(0, int(xx.min()) - margin), max(0, int(yy.min()) - margin),
            min(image.width, int(xx.max()) + margin + 1), min(image.height, int(yy.max()) + margin + 1))


def main():
    from PIL import Image
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.root / 'physical.json').read_text())
    frames = []
    for item in manifest['crops']:
        original = args.root / item['file']
        if hashlib.sha256(original.read_bytes()).hexdigest() != item['sha256']:
            raise ValueError('Physical crop changed')
        with Image.open(original) as image:
            for name, box in [('physical-interior', (0, 0, image.width, image.height)),
                              ('observed-ink-margin-2', ink_box(image))]:
                if box is None:
                    raise ValueError('Invented nonempty field has no observed ink')
                path = args.root / (item['id'] + '-' + name + '.png')
                if path.exists():
                    raise ValueError('Never overwrite prior frame')
                image.crop(box).save(path)
                frames.append(dict(id=item['id'], frame=name, file=path.name,
                                   sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                   physicalCropSHA256=item['sha256'], sourceRect=list(box)))
    (args.root / 'frames.json').write_text(json.dumps(dict(frames=frames), sort_keys=True) + '\n')


if __name__ == '__main__':
    main()
