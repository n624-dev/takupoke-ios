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


def command(*args, timeout=120):
    return subprocess.check_output(args, text=True, timeout=timeout).strip()


def remove_owned_simulator(identity):
    # Deletion must still be attempted when boot/shutdown already failed.
    try:
        subprocess.run(['xcrun', 'simctl', 'shutdown', identity], capture_output=True, timeout=60, check=False)
    finally:
        subprocess.run(['xcrun', 'simctl', 'delete', identity], capture_output=True, timeout=60, check=True)


def main():
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    parser = argparse.ArgumentParser()
    parser.add_argument('--study', type=Path, required=True)
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--runner', type=Path, required=True)
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
    manifest_lines, inventory = [], []
    for index, frame in enumerate(frames):
        path = args.study / frame['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != frame['sha256']:
            raise ValueError('Original source crop changed')
        with Image.open(path) as image:
            tensor, valid, width = infer.transform(np.asarray(image.convert('RGB')))
        data = tensor.tobytes()
        digest = hashlib.sha256(data).hexdigest()
        target = tensors / f'{index}.f32'
        target.write_bytes(data)
        manifest_lines.append(f'{index}\t{width}\t{target}\t{digest}\n')
        inventory.append(dict(frame=frame, inputSHA256=digest, valid=valid, width=width, tensor=target))
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
        command('xcrun', 'simctl', 'boot', owned)
        command('xcrun', 'simctl', 'bootstatus', owned, '-b', timeout=360)
        devices = json.loads(command('xcrun', 'simctl', 'list', 'devices', '-j'))['devices']
        if not any(d['udid'] == owned and d['state'] == 'Booted' for d in devices.get(runtime['identifier'], [])):
            raise ValueError('Owned simulator did not boot in the selected Runtime')
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
