"""Build the real app UI with synthetic local stores in an isolated project."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from picker_test_project import generate as generate_picker

def generate(destination):
    repo = Path(__file__).resolve().parents[1]
    destination = Path(destination)
    # Reuse the standard UITest target/scheme machinery, not a second app UI.
    generate_picker(destination)
    generated = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(destination/'PickerChecks.xcodeproj/project.pbxproj')]))
    real = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(repo/'Takupoke.xcodeproj/project.pbxproj')]))
    copied = destination/'Takupoke'
    shutil.copytree(repo/'Takupoke', copied)
    for path in copied.glob('*.swift'):
        text = path.read_text()
        # A URLProtocol below rejects every request. Rewrite URLs as a second
        # guard against any production communication from the test app.
        text = re.sub(r'https?://[^"\s)]+', 'https://fixture.example.test', text)
        path.write_text(text)
    shutil.copyfile(repo/'tests/ui/ApplicationFixture.swift',copied/'TakupokeApp.swift')
    real['objects']['C00000000000000000000002']['sourceTree']='<absolute>'
    real['objects']['C00000000000000000000002']['path']=str(copied)
    for obj in real['objects'].values():
        if obj.get('isa')=='XCBuildConfiguration':
            settings=obj['buildSettings']
            settings['CODE_SIGNING_ALLOWED']='NO'
            if 'INFOPLIST_FILE' in settings:
                settings['INFOPLIST_FILE']=str(copied/'Info.plist')
                settings['PRODUCT_BUNDLE_IDENTIFIER']='jp.n624.takupoke.app-checks'
                settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
    # The generated object's IDs are numeric; real project's IDs have A-F/9 prefixes.
    test_target=next(k for k,v in generated['objects'].items() if v.get('productType')=='com.apple.product-type.bundle.ui-testing')
    app_target='D00000000000000000000001'
    for key,obj in generated['objects'].items():
        if obj.get('isa') in ['PBXProject','PBXNativeTarget','PBXGroup'] and key!=test_target: continue
        if obj.get('isa')=='PBXFileReference' and obj.get('path','').endswith('MaterialPickerTapChecks.swift'):
            obj['path']=str(repo/'tests/ui/ApplicationChecks.swift')
        if obj.get('isa')=='PBXTargetDependency': obj['target']=app_target
        if obj.get('isa')=='PBXContainerItemProxy':
            obj['containerPortal']=real['rootObject']
            obj['remoteGlobalIDString']=app_target
            obj['remoteInfo']='Takupoke'
        if obj.get('isa')=='XCBuildConfiguration': obj['buildSettings']['TEST_TARGET_NAME']='Takupoke'
        real['objects'][key]=obj
    real['objects'][real['rootObject']]['targets'].append(test_target)
    real['objects'][real['rootObject']].setdefault('attributes',{}).setdefault('TargetAttributes',{})[test_target]={'CreatedOnToolsVersion':'27.0','TestTargetID':app_target}
    def encode(v):
        if isinstance(v,dict): return '{'+''.join(f'{json.dumps(k)}={encode(x)};' for k,x in v.items())+'}'
        if isinstance(v,list): return '('+','.join(encode(x) for x in v)+')'
        return json.dumps(v)
    project=destination/'AppChecks.xcodeproj'
    project.mkdir()
    (project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(real))
    scheme=(destination/'PickerChecks.xcodeproj/xcshareddata/xcschemes/PickerChecks.xcscheme').read_text()
    old_app=next(k for k,v in generated['objects'].items() if v.get('productType')=='com.apple.product-type.application')
    scheme=scheme.replace(old_app,app_target).replace('PickerChecks.app','Takupoke.app').replace('BlueprintName="PickerChecks"','BlueprintName="Takupoke"').replace('container:PickerChecks.xcodeproj','container:AppChecks.xcodeproj')
    folder=project/'xcshareddata/xcschemes'; folder.mkdir(parents=True)
    (folder/'AppChecks.xcscheme').write_text(scheme)

if __name__=='__main__': generate(sys.argv[1])
