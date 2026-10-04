"""Prepare next research source from reviewed ZIP and an actual CI model receipt.
No model conversion/output is fabricated; input receipt must come from successful
reviewed model-export CI and be checked against downloaded actual model bytes.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import zipfile

BASE_SOURCE_SHA = 'bcf9a930df495613187152f90acc44110ced12c7d7e4e63bef33dcf44e84f8cc'
OLD_MODEL_ZIP_SHA = '1f753dada34567ff6571a12834c4cbe6f63dad01de974ab3b18422d2070026c1'
BUNDLE_NAME = 'qwen3-0.6b-c1899de-ios-mixed'

parser=argparse.ArgumentParser()
parser.add_argument('source_zip',type=Path)
parser.add_argument('actual_model_receipt',type=Path)
parser.add_argument('actual_model_zip',type=Path)
parser.add_argument('destination',type=Path)
args=parser.parse_args()
assert hashlib.sha256(args.source_zip.read_bytes()).hexdigest()==BASE_SOURCE_SHA
assert not args.destination.exists()
receipt=json.loads(args.actual_model_receipt.read_text())
manifest=receipt['bundleManifest']
assert receipt['bundleFolder']==BUNDLE_NAME
assert receipt['runId'].isdigit() and receipt['attempt'].isdigit()
assert args.actual_model_zip.stat().st_size==receipt['archiveBytes']
h=hashlib.sha256()
with args.actual_model_zip.open('rb') as source:
    while chunk:=source.read(1024*1024):h.update(chunk)
assert h.hexdigest()==receipt['archiveSHA256']
files=manifest['files'];assert len(files)==7 and len({v['path'] for v in files})==7
assert hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()==manifest['bundleSHA256']
with zipfile.ZipFile(args.actual_model_zip) as zipped:
    assert len(zipped.infolist())<=128 and sum(v.file_size for v in zipped.infolist())<=2_500_000_000
    for item in zipped.infolist():
        parts=PurePosixPath(item.filename).parts
        assert parts and not item.filename.startswith('/') and '..' not in parts and '\\' not in item.filename
        assert (item.external_attr>>16)&0o170000!=0o120000
    for item in files:
        h=hashlib.sha256();count=0
        with zipped.open(BUNDLE_NAME+'/'+item['path']) as source:
            while chunk:=source.read(1024*1024):h.update(chunk);count+=len(chunk)
        assert count==item['bytes'] and h.hexdigest()==item['sha256']
    # Actual conversion provenance must match the independently reviewed source.
    provenance=json.loads(zipped.read('MODEL-PROVENANCE.json'))
    assert provenance['sourceRevision']=='c1899de289a04d12100db370d81485cdf75e47ca'
    assert provenance['coreAIModelsRevision']=='52c84ba874b2c57adcede08a671ce96ed1b3f433'
    assert provenance['bundleManifest']==manifest
args.destination.mkdir()
with zipfile.ZipFile(args.source_zip) as zipped:
    assert len(zipped.infolist())==46 and sum(v.file_size for v in zipped.infolist())<=5_000_000
    for item in zipped.infolist():
        parts=PurePosixPath(item.filename).parts
        assert parts[0]=='ios-high-phone-benchmark' and '..' not in parts and not item.filename.startswith('/')
        assert (item.external_attr>>16)&0o170000!=0o120000
    zipped.extractall(args.destination)
project=args.destination/'ios-high-phone-benchmark'
(project/'Resources/ModelBundleManifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
readme=project/'README.md';text=readme.read_text()
text=text.replace(OLD_MODEL_ZIP_SHA,receipt['archiveSHA256']).replace('374,332,450',f"{receipt['archiveBytes']:,}")
text=text.replace('ios-high-coreai-qwen3-06-offline-smoke.zip',f"ios-coreai-model-{receipt['runId']}-{receipt['attempt']}.zip")
text=text.replace('APACHE-2.0.txt / SOURCE-MODEL-CARD.txt / MODEL-PROVENANCE.json','SOURCE-MODEL-LICENSE.txt / SOURCE-MODEL-CARD.txt / MODEL-PROVENANCE.json')
text+='\nCIではiOS 27シミュレーターでも実際のCore AI読み込み・推論を試します。シミュレーターのメモリ量と処理時間はMacホスト上の値であり、iPhone 14の実測値ではありません。シミュレーター専用の `--ci-native-probe` はアプリ内Documents/CIModelの固定モデルだけを確認し、同じ架空4入力を実行します。\n'
readme.write_text(text)
prepare=project/'tools/prepare-coreai-runtime.py';text=prepare.read_text()
old='    if os.environ.get("PLATFORM_NAME") != "iphoneos":\n        return\n'
new='    platform = os.environ.get("PLATFORM_NAME")\n    if platform not in {"iphoneos", "iphonesimulator"}:\n        return\n    architecture = "arm64" if platform == "iphoneos" else os.uname().machine\n    if architecture not in {"arm64", "x86_64"}:\n        raise ValueError("Unsupported simulator host architecture")\n    triple = architecture + "-apple-ios27.0" + ("-simulator" if platform == "iphonesimulator" else "")\n'
assert text.count(old)==1;text=text.replace(old,new)
text=text.replace('["xcrun", "--sdk", "iphoneos",','["xcrun", "--sdk", platform,')
text=text.replace('"--triple", "arm64-apple-ios27.0",','"--triple", triple,')
text=text.replace('["iPhoneOS"]','["iPhoneSimulator" if platform == "iphonesimulator" else "iPhoneOS"]')
prepare.write_text(text)
app=project/'Sources/ProbeApp.swift';text=app.read_text()
text=text.replace('    private var importTask: Task<ImportedProbeBundle, Error>?','    private var importTask: Task<ImportedProbeBundle, Error>?\n    private var ciStarted = false')
needle='    func discard() {'
method='''    func startSimulatorCIIfRequested() async {
        #if targetEnvironment(simulator)
        guard !ciStarted, CommandLine.arguments.contains("--ci-native-probe") else { return }
        ciStarted = true
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        importBundle(docs.appendingPathComponent("CIModel", isDirectory: true))
        while running {
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { cancel(); return }
        }
        guard imported != nil else {
            let failure: [String: Any] = ["scope": "Simulator model import diagnostic only; no inference/quality", "status": status]
            if let data = try? JSONSerialization.data(withJSONObject: failure, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: docs.appendingPathComponent("ci-import-failure.json"), options: .atomic)
            }
            return
        }
        run()
        #endif
    }
'''
assert text.count(needle)==1;text=text.replace(needle,method+needle)
needle='            .onChange(of: phase)'
assert text.count(needle)==1;text=text.replace(needle,'            .task { await model.startSimulatorCIIfRequested() }\n'+needle)
app.write_text(text)
probe=project/'Sources/CoreAIProbe.swift';text=probe.read_text()
needle='        var operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString'
replacement='''        #if targetEnvironment(simulator)
        var executionEnvironment = "iOSSimulator: host memory/time, not iPhone physical evidence"
        #else
        var executionEnvironment = "iOSDevice"
        #endif
'''+needle
assert text.count(needle)==1;probe.write_text(text.replace(needle,replacement))
statuspath=project/'RESEARCH-STATUS.json';status=json.loads(statuspath.read_text());status.update(status='Prepared actual CI model pins; pending new Apple SDK/simulator/physical inference',modelArchiveSHA256=receipt['archiveSHA256'],simulator='Same original C bridge; real iOS27 simulator attempt, host memory/time scope only')
statuspath.write_text(json.dumps(status,indent=2)+'\n')
(project/'ACTUAL-CI-MODEL-RECEIPT.json').write_bytes(args.actual_model_receipt.read_bytes())
print(project)
