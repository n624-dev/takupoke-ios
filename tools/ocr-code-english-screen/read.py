"""Original RGB8 -> fixed EnglishV1 CPU. No oracle or native output access."""
import argparse
import importlib.util
import json
from pathlib import Path
from code_english_contract import ROOT, inputs


def main():
    import numpy as np
    import onnxruntime as ort
    parser = argparse.ArgumentParser(); parser.add_argument('root',type=Path); parser.add_argument('models',type=Path); args = parser.parse_args()
    def module(name,path):
        spec = importlib.util.spec_from_file_location(name,path)
        result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result); return result
    infer = module('fixed_rgb_ctc',ROOT.parent/'ocr-windows-transfer/infer.py')
    tail = module('fixed_ascii_reader',ROOT.parent/'ocr-full-document-transfer/code_tail.py')
    ort.disable_telemetry_events()
    options = ort.SessionOptions(); options.intra_op_num_threads = 2; options.inter_op_num_threads = 1
    options.log_severity_level = 3
    reader = tail.ASCIITailReader(args.models,infer,ort,np,options)
    rows = []
    for frame in inputs(args.root):
        image = np.frombuffer((args.root/frame['rgb']).read_bytes(),dtype=np.uint8).reshape(frame['height'],frame['width'],3)
        row = reader.recognize(image)
        if row['sourcePixelsSHA256'] != frame['rgbSHA256']:
            raise ValueError('Actual model pixels differ from original source')
        rows.append(dict(id=frame['id'],**row))
    if reader.calls != 192 or len(rows) != 192:
        raise ValueError('Original model call inventory incomplete')
    with (args.root/'model.json').open('x') as output:
        json.dump(dict(actualCalls=reader.calls,records=rows),output,sort_keys=True)
    print('CODE_ENGLISH_MODEL_FINISHED actualCalls=192',flush=True)


if __name__ == '__main__':
    main()
