#!/usr/bin/env python3
"""Fixed CPU recognizers, without an oracle, network calls or candidate voting."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import resource
import sys
import time


ROOT = Path(__file__).resolve().parent
MODELS = [('paddle-v6', 'rec.onnx', 'dictionary-v6.json'),
          ('english-v1', 'ascii-rec.onnx', 'ascii-dictionary.json'),
          ('english-v3', 'manual-code-rec.onnx', 'ascii-dictionary.json'),
          ('japanese-v3', 'japanese-uncertain-rec.onnx', 'japanese-uncertain-dictionary.json')]


def transform(rgb):
    """Windows half-pixel, rounded uint8 BGR and post-normalization zero pad."""
    import numpy as np
    height, width, channels = rgb.shape
    if channels != 3 or width < 1 or height < 1:
        raise ValueError('Invalid original pixels')
    ratio = width / height
    input_width = math.floor(48 * max(320 / 48, ratio))
    if input_width > 960:
        raise ValueError('Native Windows recognizer width bound exceeded')
    valid = min(input_width, math.ceil(48 * ratio))
    xs = np.clip((np.arange(valid, dtype=np.float64) + .5) * width / valid - .5, 0, width - 1)
    ys = np.clip((np.arange(48, dtype=np.float64) + .5) * height / 48 - .5, 0, height - 1)
    x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
    x1, y1 = np.minimum(x0 + 1, width - 1), np.minimum(y0 + 1, height - 1)
    fx, fy = (xs - x0)[None, :, None], (ys - y0)[:, None, None]
    a, b = rgb[y0[:, None], x0], rgb[y0[:, None], x1]
    d, e = rgb[y1[:, None], x0], rgb[y1[:, None], x1]
    sampled = np.floor((a * (1-fx) + b * fx) * (1-fy) + (d * (1-fx) + e * fx) * fy + .5).astype(np.float32)
    normalized = (sampled[:, :, ::-1] / np.float32(255) - np.float32(.5)) / np.float32(.5)
    tensor = np.zeros((1, 3, 48, input_width), dtype=np.float32)
    tensor[0, :, :, :valid] = normalized.transpose(2, 0, 1)
    return tensor, valid, input_width


def decode(probabilities, dictionary):
    import numpy as np
    if (probabilities.ndim != 3 or probabilities.shape[0] != 1 or probabilities.shape[1] < 1
            or probabilities.shape[2] != len(dictionary) or dictionary[0] != ''
            or not np.isfinite(probabilities).all() or (probabilities < 0).any() or (probabilities > 1).any()):
        raise ValueError('Invalid native CTC probabilities')
    previous, pieces = -1, []
    for t, row in enumerate(probabilities[0]):
        best = int(row.argmax())
        score = float(row[best])
        if best != 0 and best != previous:
            pieces.append(dict(text=dictionary[best], start=t, end=t+1, confidence=score))
        elif best != 0:
            pieces[-1]['end'] = t+1
            pieces[-1]['confidence'] = max(pieces[-1]['confidence'], score)
        previous = best
    return pieces


def infer(model_folder, study):
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    protocol = json.loads((ROOT / 'protocol.json').read_text())
    for pin in protocol['models']:
        path = model_folder / pin['file']
        if path.stat().st_size != pin['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != pin['sha256']:
            raise ValueError('Recognizer artifact changed')
    frames = json.loads((study / 'frames.json').read_text())['frames']
    if len(frames) != 288 or len({(f['id'], f['frame']) for f in frames}) != 288:
        raise ValueError('Incomplete/duplicate frame inventory')
    ort.disable_telemetry_events()
    records = []
    for name, model, dictionary_file in MODELS:
        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        options.inter_op_num_threads = 1
        options.log_severity_level = 3
        dictionary = json.loads((model_folder / dictionary_file).read_text())
        if len(dictionary) != {'paddle-v6': 18710, 'english-v1': 438, 'english-v3': 438, 'japanese-v3': 4401}[name]:
            raise ValueError('Native dictionary changed')
        session = ort.InferenceSession(str(model_folder / model), sess_options=options, providers=['CPUExecutionProvider'])
        ascii_model = name.startswith('english-')
        if {i.name for i in session.get_inputs()} != ({'x', 'valid_width'} if ascii_model else {'x'}):
            raise ValueError('Native model input contract changed')
        for frame in frames:
            path = study / frame['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != frame['sha256']:
                raise ValueError('Original crop changed')
            with Image.open(path) as image:
                rgb = np.asarray(image.convert('RGB'))
            tensor, valid, padded = transform(rgb)
            inputs = {'x': tensor}
            if ascii_model:
                inputs['valid_width'] = np.array([valid], dtype=np.int64)
            started = time.monotonic()
            output = dict(zip((o.name for o in session.get_outputs()), session.run(None, inputs)))
            elapsed = time.monotonic() - started
            probability = output['probabilities'] if ascii_model else next(iter(output.values()))
            pieces = decode(probability, dictionary)
            reject = float(output['reject_probability'][0]) if ascii_model else None
            if reject is not None and (not math.isfinite(reject) or not 0 <= reject <= 1):
                raise ValueError('Invalid native reject probability')
            supported = all(p['end'] * padded <= valid * probability.shape[1] for p in pieces)
            records.append(dict(id=frame['id'], frame=frame['frame'], reader=name,
                                imageSHA256=frame['sha256'], inputSHA256=hashlib.sha256(tensor.tobytes()).hexdigest(),
                                text=''.join(p['text'] for p in pieces), pieces=pieces, timeCount=probability.shape[1],
                                validWidth=valid, inputWidth=padded, paddingSupported=supported,
                                rejectProbability=reject, seconds=elapsed))
        del session
    rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return dict(records=records, calls=len(records), runtime=ort.__version__, platform=sys.platform,
                maxRSSBytes=rss if sys.platform == 'darwin' else rss * 1024)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--models', type=Path, required=True)
    parser.add_argument('--study', type=Path, required=True)
    args = parser.parse_args()
    path = args.study / 'onnx.json'
    if path.exists():
        raise ValueError('Never overwrite a prior inference')
    result = infer(args.models, args.study)
    path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True) + '\n')
    print('ONNX_READERS actualCalls=' + str(result['calls']) + ' maxRSSBytes=' + str(result['maxRSSBytes']))


if __name__ == '__main__':
    main()
