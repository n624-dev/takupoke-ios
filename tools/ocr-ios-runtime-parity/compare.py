#!/usr/bin/env python3
"""Actual iOS-simulator C API outputs versus CPU reference on identical tensors."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import queue
import subprocess
import threading
import time


ROOT = Path(__file__).resolve().parent


def shared_infer():
    spec = importlib.util.spec_from_file_location('closed_ocr_transform', ROOT.parent / 'ocr-windows-transfer/infer.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def compare_probabilities(expected, actual, dictionary, tolerance):
    import numpy as np
    infer = shared_infer()
    if expected.shape != actual.shape:
        raise ValueError('iOS native tensor shape changed')
    reference = infer.decode(expected, dictionary)
    native = infer.decode(actual, dictionary)
    maximum = float(np.max(np.abs(expected - actual)))
    if maximum > tolerance:
        raise ValueError('iOS full probability tensor drift exceeded bound')
    if [(p['text'], p['start'], p['end']) for p in reference] != [(p['text'], p['start'], p['end']) for p in native]:
        raise ValueError('iOS native greedy text or CTC intervals changed')
    if any((a['confidence'] >= .85) != (b['confidence'] >= .85) for a, b in zip(reference, native)):
        raise ValueError('iOS native selected-piece .85 floor changed')
    return maximum, native


def verify_native_tensors(output, expected, root):
    lines = output.splitlines()
    if len(lines) != len(expected):
        raise ValueError('Native transform inventory changed')
    for index, (line, original) in enumerate(zip(lines, expected)):
        if not line.startswith('ORT_IOS_TENSOR '):
            raise ValueError('Native transform output changed')
        record = json.loads(line.split(' ', 1)[1])
        data = (root / f'{index}.native.f32').read_bytes()
        if (record['index'] != index or record['rgbSHA256'] != original['rgbSHA256'] or
                record['validWidth'] != original['validWidth'] or record['inputWidth'] != original['inputWidth'] or
                record['tensorSHA256'] != hashlib.sha256(data).hexdigest() or data != original['bytes']):
            raise ValueError('Native RGB-to-tensor transform changed')
    return len(expected)


def verify_native_identity(line, owned, runtime):
    if not line.startswith('ORT_IOS_IDENTITY '):
        raise ValueError('Missing real simulator process identity')
    record = json.loads(line.split(' ', 1)[1])
    def version(value):
        parts = tuple(map(int, value.split('.')))
        if len(parts) not in (2, 3):
            raise ValueError('Invalid native Runtime version')
        return parts + (0,) * (3-len(parts))
    if (record['udid'] != owned or version(record['runtime']) != version(runtime) or
            record['simulatorCompileTarget'] is not True or type(record['pid']) is not int or record['pid'] <= 0):
        raise ValueError('Real simulator process identity or Runtime changed')
    return record


def command(*args, timeout=120, allow_nonzero=False):
    started = time.monotonic()
    label = list(args[:4])
    print('ORT_IOS_STAGE ' + json.dumps(dict(command=label, state='start', timeout=timeout)), flush=True)
    try:
        value = subprocess.check_output(args, text=True, timeout=timeout).strip()
    except Exception as error:
        print('ORT_IOS_STAGE ' + json.dumps(dict(command=label, state='failure',
              seconds=time.monotonic()-started, error=type(error).__name__)), flush=True)
        if allow_nonzero and isinstance(error, subprocess.CalledProcessError):
            return (error.output or '').strip()
        raise
    print('ORT_IOS_STAGE ' + json.dumps(dict(command=label, state='success',
          seconds=time.monotonic()-started)), flush=True)
    return value


def boot_owned_simulator(identity, developer):
    # Match the existing successful UI harness's selected-Xcode frontend.
    # This is a different launch context, not a retry or a relaxed boot check.
    simulator = developer / 'Applications/Simulator.app'
    hub = developer.parent / 'Applications/DeviceHub.app'
    if not simulator.is_dir() and not hub.is_dir():
        raise ValueError('No supported simulator frontend in the selected Xcode')
    command('xcrun', 'simctl', 'boot', identity)
    if simulator.is_dir():
        command('open', '-a', str(simulator), '--args', '-CurrentDeviceUDID', identity)
    else:
        command('open', '-a', str(hub))
    command('xcrun', 'simctl', 'bootstatus', identity, '-b', timeout=360)
    if not simulator.is_dir():
        command('open', '-a', str(hub), 'devices://device/open?id=' + identity)


def remove_owned_simulator(identity):
    # Deletion must still be attempted when boot/shutdown already failed.
    try:
        command('xcrun', 'simctl', 'shutdown', identity, timeout=60, allow_nonzero=True)
    finally:
        command('xcrun', 'simctl', 'delete', identity, timeout=60)


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
    if len(dictionary) != 18710 or dictionary[0] != '':
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
    manifest_lines, inventory = [], []
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
        manifest_lines.append(f'{index}\t{width}\t{native_pixels / (str(index) + ".native.f32")}\t{digest}\n')
        inventory.append(dict(frame=frame, inputSHA256=digest, valid=valid, width=width, tensor=target))
    # Asymmetric colors and odd sizes expose channel/row/rounding/padding bugs
    # that grayscale text crops cannot detect. No recognition oracle is used.
    for width, height in [(1, 1), (7, 5), (960, 48), (319, 47)]:
        rgb = (np.arange(width * height * 3, dtype=np.uint32) * 37 + 11).astype(np.uint8).reshape(height, width, 3)
        prepare_transform(rgb)
    (native_pixels / 'inputs.json').write_text(json.dumps(pixel_inputs))
    manifest = args.study / 'native-inputs.tsv'
    manifest.write_text(''.join(manifest_lines))
    ort.disable_telemetry_events()
    options = ort.SessionOptions(); options.intra_op_num_threads = 2; options.inter_op_num_threads = 1; options.log_severity_level = 3
    session = ort.InferenceSession(str(models / protocol['model']['file']), sess_options=options, providers=['CPUExecutionProvider'])
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
            calls, ready, finished, maximum, rss, seconds = 0, False, False, 0., None, None
            while True:
                line = messages.get(timeout=120)
                if line is None:
                    break
                if line.startswith('ORT_IOS_READY\t'):
                    if ready or line.split('\t') != ['ORT_IOS_READY', protocol['runtime']['version']]:
                        raise ValueError('Native Runtime handshake changed')
                    ready = True
                elif line.startswith('ORT_IOS_RESULT\t'):
                    fields = line.split('\t')
                    if not ready or finished or len(fields) != 6 or int(fields[1]) != calls or calls >= len(inventory):
                        raise ValueError('Native inference call order changed')
                    item = inventory[calls]
                    if fields[4] != item['inputSHA256']:
                        raise ValueError('iOS did not read the identical tensor bytes')
                    native_path = probabilities / f'{calls}.f32'
                    data = native_path.read_bytes()
                    if hashlib.sha256(data).hexdigest() != fields[5]:
                        raise ValueError('Native probability bytes changed')
                    native = np.frombuffer(data, dtype='<f4').reshape(1, int(fields[2]), int(fields[3]))
                    tensor_bytes = item['tensor'].read_bytes()
                    if hashlib.sha256(tensor_bytes).hexdigest() != item['inputSHA256']:
                        raise ValueError('Reference input changed')
                    tensor = np.frombuffer(tensor_bytes, dtype='<f4').reshape(1, 3, 48, item['width'])
                    expected = session.run(None, {'x': tensor})[0]
                    difference, pieces = compare_probabilities(expected, native, dictionary, protocol['maximumAllProbabilityDifference'])
                    maximum = max(maximum, difference)
                    print('ORT_IOS_PARITY ' + json.dumps(dict(index=calls, id=item['frame']['id'], frame=item['frame']['frame'],
                        inputSHA256=item['inputSHA256'], nativeProbabilitySHA256=fields[5],
                        sourceImageSHA256=item['frame']['sha256'], maxAllProbabilityDifference=difference,
                        validWidth=item['valid'], inputWidth=item['width'], timeCount=int(fields[2]), nativePieces=pieces),
                        ensure_ascii=False, sort_keys=True), flush=True)
                    native_path.unlink()
                    calls += 1
                elif line.startswith('ORT_IOS_FINISHED\t'):
                    fields = line.split('\t')
                    if finished or len(fields) != 4 or int(fields[1]) != calls:
                        raise ValueError('Native completion inventory changed')
                    finished = True; rss = int(fields[2]); seconds = float(fields[3])
                else:
                    print('ORT_IOS_PROCESS ' + line, flush=True)
            code = process.wait(timeout=30)
        if code or not finished or calls != protocol['nativeCalls']:
            raise ValueError('Native process did not complete the entire fixed inventory')
        receipt = dict(study=protocol['study'], iosRuntime=runtime['version'], actualNativeCalls=calls,
                       actualReferenceCalls=calls, fullProbabilityMaxDifference=maximum,
                       nativePeakRSSBytes=rss, nativeBatchSeconds=seconds, runtime=protocol['runtime']['version'],
                       scope=protocol['scope'], sameGreedyTextAndIntervals=True, same085Floor=True,
                       physicalIPhoneExecution=False, applicationChanged=False)
        receipt['nativeRGBTransforms'] = native_transforms
        receipt['verifiedNativeProcessIdentity'] = native_identity
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
