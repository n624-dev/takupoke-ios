#!/usr/bin/env python3
"""Native two-input/two-output ASCII runtime proof; no oracle or app code."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import queue
import struct
import subprocess
import threading

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ios_cpu_parity_helpers', ROOT.parent/'ocr-ios-runtime-parity/compare.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)
shared_infer = shared.shared_infer
compare_probabilities = shared.compare_probabilities
verify_native_tensors = shared.verify_native_tensors
verify_native_identity = shared.verify_native_identity
command = shared.command
boot_owned_simulator = shared.boot_owned_simulator
remove_owned_simulator = shared.remove_owned_simulator


def compare_reject(expected, actual, tolerance):
    import numpy as np
    if expected.shape != (1,) or actual.shape != (1,) or not all(
            np.isfinite(v).all() and ((v >= 0) & (v <= 1)).all() for v in [expected, actual]):
        raise ValueError('Invalid original reject output')
    difference = float(np.max(np.abs(expected-actual)))
    if difference > tolerance:
        raise ValueError('Native reject probability drift exceeded bound')
    if bool(expected[0] <= .05) != bool(actual[0] <= .05):
        raise ValueError('Native reject .05 decision changed')
    return difference


def verify_width(record, valid):
    # Read-back of the actual native INT64 OrtValue used by Run, not a score.
    if int(record[8]) != valid or record[6] != hashlib.sha256(struct.pack('<q', valid)).hexdigest():
        raise ValueError('Native valid_width input changed')


def verify_inference_identity(line, owned):
    fields = line.split('\t')
    if (len(fields) != 4 or fields[0] != 'ORT_IOS_INFERENCE_IDENTITY' or
            fields[1] != owned or not fields[2].isdigit() or int(fields[2]) <= 0 or fields[3] != 'IOS_SIMULATOR'):
        raise ValueError('Native inference process identity changed')
    return dict(udid=fields[1], pid=int(fields[2]), compileTarget=fields[3])


def main():
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    parser = argparse.ArgumentParser()
    parser.add_argument('--study', type=Path, required=True)
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--runner', type=Path, required=True)
    parser.add_argument('--transform-runner', type=Path, required=True)
    parser.add_argument('--ios', type=int, choices=[26, 27], required=True)
    args = parser.parse_args()
    protocol = json.loads((ROOT / 'protocol.json').read_text())
    if ort.__version__ != protocol['runtime']['version']:
        raise ValueError('Reference Runtime changed')
    models = args.assets / 'models'
    for pin in [protocol['model'], protocol['dictionary']]:
        path = models / pin['file']
        if path.stat().st_size != pin['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != pin['sha256']:
            raise ValueError('Pinned model/dictionary changed')
    infer = shared_infer()
    dictionary = json.loads((models / protocol['dictionary']['file']).read_text())
    if len(dictionary) != 438 or dictionary[0] != '':
        raise ValueError('Native vocabulary changed')
    frames = json.loads((args.study / 'frames.json').read_text())['frames']
    if len(frames) != protocol['frames'] or len({(f['id'], f['frame']) for f in frames}) != protocol['frames']:
        raise ValueError('Incomplete input inventory')
    tensors, probabilities = args.study / 'native-tensors', args.study / 'native-probabilities'
    tensors.mkdir(); probabilities.mkdir()
    native_pixels = args.study / 'native-pixels'
    native_pixels.mkdir()
    pixel_inputs, expected_tensors = [], []
    def prepare_transform(rgb):
        tensor, valid, width = infer.transform(rgb)
        index = len(pixel_inputs)
        pixels = rgb.tobytes()
        digest = hashlib.sha256(pixels).hexdigest()
        (native_pixels / f'{index}.rgb').write_bytes(pixels)
        pixel_inputs.append(dict(index=index, width=rgb.shape[1], height=rgb.shape[0], file=f'{index}.rgb', sha256=digest))
        expected_tensors.append(dict(rgbSHA256=digest, validWidth=valid, inputWidth=width, bytes=tensor.tobytes()))
        return tensor, valid, width
    inventory = []
    for index, frame in enumerate(frames):
        path = args.study / frame['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != frame['sha256']:
            raise ValueError('Original source crop changed')
        with Image.open(path) as image:
            tensor, valid, width = prepare_transform(np.asarray(image.convert('RGB')))
        data = tensor.tobytes()
        digest = hashlib.sha256(data).hexdigest()
        target = tensors / f'{index}.f32'
        target.write_bytes(data)
        inventory.append(dict(frame=frame, inputSHA256=digest, valid=valid, width=width, tensor=target))
    # Asymmetric colors and odd sizes expose channel/row/rounding/padding bugs
    # that grayscale text crops cannot detect. No recognition oracle is used.
    for width, height in [(1, 1), (7, 5), (960, 48), (319, 47)]:
        rgb = (np.arange(width * height * 3, dtype=np.uint32) * 37 + 11).astype(np.uint8).reshape(height, width, 3)
        prepare_transform(rgb)
    (native_pixels / 'inputs.json').write_text(json.dumps(pixel_inputs))
    manifest = args.study / 'native-inputs.tsv'
    ort.disable_telemetry_events()
    options = ort.SessionOptions(); options.intra_op_num_threads = 2; options.inter_op_num_threads = 1; options.log_severity_level = 3
    session = ort.InferenceSession(str(models / protocol['model']['file']), sess_options=options, providers=['CPUExecutionProvider'])
    if ({v.name for v in session.get_inputs()} != {'x', 'valid_width'} or
            {v.name for v in session.get_outputs()} != {'probabilities', 'reject_probability'}):
        raise ValueError('ASCII I/O names changed')
    simulation = json.loads(command('xcrun', 'simctl', 'list', '-j'))
    available = [r for r in simulation['runtimes'] if r.get('isAvailable') and
                 r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and int(r['version'].split('.')[0]) == args.ios]
    if not available:
        raise ValueError('Required iOS Runtime is unavailable; never substitute another OS')
    runtime = max(available, key=lambda r: tuple(map(int, r['version'].split('.'))))
    device = next(d for d in simulation['devicetypes'] if d['name'] == 'iPhone 16')
    owned = None; process = None
    try:
        owned = command('xcrun', 'simctl', 'create', 'Takupoke owned OCR CPU parity', device['identifier'], runtime['identifier'])
        boot_owned_simulator(owned, Path(command('xcode-select', '-p')))
        transformed = command('xcrun', 'simctl', 'spawn', owned, str(args.transform_runner), str(native_pixels))
        identity_line, separator, tensor_lines = transformed.partition('\n')
        native_identity = verify_native_identity(identity_line, owned, runtime['version'])
        if not separator:
            raise ValueError('Native transform inventory is missing after identity')
        native_transforms = verify_native_tensors(tensor_lines, expected_tensors, native_pixels)
        if native_transforms != protocol['nativeRGBTransforms']:
            raise ValueError('Native transform protocol inventory changed')
        print(identity_line, flush=True)
        print('ORT_IOS_TENSORS_VERIFIED ' + json.dumps(dict(nativeTransforms=native_transforms,
              identicalBytes=True, scope='Explicit RGB8 to FP32 only; not native image decoding')), flush=True)
        native_records = [json.loads(line.split(' ', 1)[1]) for line in tensor_lines.splitlines()]
        manifest.write_text(''.join(f'{i}\t{native_records[i]["inputWidth"]}\t{native_pixels / (str(i)+".native.f32")}\t{native_records[i]["tensorSHA256"]}\t{native_records[i]["validWidth"]}\n' for i in range(len(inventory))))
        del expected_tensors
        with (args.study / 'native-stderr.txt').open('w') as errors:
            process = subprocess.Popen(['xcrun', 'simctl', 'spawn', owned, str(args.runner),
                                        str(models / protocol['model']['file']), str(manifest), str(probabilities)],
                                       stdout=subprocess.PIPE, stderr=errors, text=True)
            messages = queue.Queue()
            def receive():
                for line in process.stdout:
                    messages.put(line.rstrip('\n'))
                messages.put(None)
            threading.Thread(target=receive, daemon=True).start()
            calls, ready, finished, maximum, reject_maximum, rss, seconds = 0, False, False, 0., 0., None, None
            inference_identity = None
            while True:
                line = messages.get(timeout=120)
                if line is None:
                    break
                if line.startswith('ORT_IOS_INFERENCE_IDENTITY\t'):
                    if inference_identity is not None or ready or calls:
                        raise ValueError('Native inference identity order changed')
                    inference_identity = verify_inference_identity(line, owned)
                    print(line, flush=True)
                elif line.startswith('ORT_IOS_READY\t'):
                    if ready or line.split('\t') != ['ORT_IOS_READY', protocol['runtime']['version']]:
                        raise ValueError('Native Runtime handshake changed')
                    ready = True
                elif line.startswith('ORT_IOS_RESULT\t'):
                    fields = line.split('\t')
                    if not ready or finished or len(fields) != 9 or int(fields[1]) != calls or calls >= len(inventory):
                        raise ValueError('Native inference call order changed')
                    item = inventory[calls]
                    if fields[4] != item['inputSHA256']:
                        raise ValueError('iOS did not read the identical tensor bytes')
                    verify_width(fields, item['valid'])
                    native_path = probabilities / f'{calls}.f32'
                    data = native_path.read_bytes()
                    if hashlib.sha256(data).hexdigest() != fields[5]:
                        raise ValueError('Native probability bytes changed')
                    native = np.frombuffer(data, dtype='<f4').reshape(1, int(fields[2]), int(fields[3]))
                    tensor_bytes = item['tensor'].read_bytes()
                    if hashlib.sha256(tensor_bytes).hexdigest() != item['inputSHA256']:
                        raise ValueError('Reference input changed')
                    tensor = np.frombuffer(tensor_bytes, dtype='<f4').reshape(1, 3, 48, item['width'])
                    outputs = dict(zip((v.name for v in session.get_outputs()), session.run(None,
                        {'x': tensor, 'valid_width': np.array([item['valid']], dtype=np.int64)})))
                    expected = outputs['probabilities']
                    reject_path = probabilities / f'{calls}.reject.f32'
                    reject_bytes = reject_path.read_bytes()
                    if len(reject_bytes) != 4 or hashlib.sha256(reject_bytes).hexdigest() != fields[7]:
                        raise ValueError('Native reject output bytes changed')
                    native_reject = np.frombuffer(reject_bytes, dtype='<f4')
                    reject_difference = compare_reject(outputs['reject_probability'], native_reject, protocol['maximumAllProbabilityDifference'])
                    difference, pieces = compare_probabilities(expected, native, dictionary, protocol['maximumAllProbabilityDifference'])
                    maximum = max(maximum, difference)
                    reject_maximum = max(reject_maximum, reject_difference)
                    print('ORT_IOS_PARITY ' + json.dumps(dict(index=calls, id=item['frame']['id'], frame=item['frame']['frame'],
                        inputSHA256=item['inputSHA256'], nativeProbabilitySHA256=fields[5], nativeValidWidthSHA256=fields[6],
                        nativeRejectProbabilitySHA256=fields[7], nativeRejectProbability=float(native_reject[0]),
                        maxRejectProbabilityDifference=reject_difference, sameReject005Decision=True,
                        sourceImageSHA256=item['frame']['sha256'], maxAllProbabilityDifference=difference,
                        validWidth=item['valid'], inputWidth=item['width'], timeCount=int(fields[2]), nativePieces=pieces),
                        ensure_ascii=False, sort_keys=True), flush=True)
                    native_path.unlink(); reject_path.unlink()
                    calls += 1
                elif line.startswith('ORT_IOS_FINISHED\t'):
                    fields = line.split('\t')
                    if finished or len(fields) != 4 or int(fields[1]) != calls:
                        raise ValueError('Native completion inventory changed')
                    finished = True; rss = int(fields[2]); seconds = float(fields[3])
                else:
                    print('ORT_IOS_PROCESS ' + line, flush=True)
            code = process.wait(timeout=30)
        if code or not finished or calls != protocol['nativeCalls'] or inference_identity is None:
            raise ValueError('Native process did not complete the entire fixed inventory')
        receipt = dict(study=protocol['study'], iosRuntime=runtime['version'], actualNativeCalls=calls,
                       actualReferenceCalls=calls, fullProbabilityMaxDifference=maximum,
                       nativePeakRSSBytes=rss, nativeBatchSeconds=seconds, runtime=protocol['runtime']['version'],
                       scope=protocol['scope'], sameGreedyTextAndIntervals=True, same085Floor=True,
                       fullRejectProbabilityMaxDifference=reject_maximum, sameReject005Decision=True,
                       nativeValidWidthType='INT64', nativeInputCount=2, nativeOutputCount=2,
                       physicalIPhoneExecution=False, applicationChanged=False)
        receipt['nativeRGBTransforms'] = native_transforms
        receipt['verifiedTransformProcessIdentity'] = native_identity
        receipt['verifiedInferenceProcessIdentity'] = inference_identity
        (args.study / 'runtime-receipt.json').write_text(json.dumps(receipt, sort_keys=True)+'\n')
        print('ORT_IOS_RECEIPT ' + json.dumps(receipt, sort_keys=True), flush=True)
    finally:
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
        stderr = args.study / 'native-stderr.txt'
        if stderr.exists() and stderr.stat().st_size:
            print('ORT_IOS_STDERR ' + stderr.read_text(errors='replace')[-10000:], flush=True)
        if owned:
            remove_owned_simulator(owned)


if __name__ == '__main__':
    main()
