"""Verify exact runtime preparation without downloading Apple resources."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class PrepareRuntimeTests(unittest.TestCase):
    def test_ios26_export_lives_until_explicit_job_cleanup_including_preparation_failures(self):
        fake = '#!' + sys.executable + '\n' + r'''
import json, os, sys
from pathlib import Path
args=sys.argv[1:];mode=os.environ['MODE'];marker=Path(os.environ['MARKER'])
downloaded=marker.with_name('downloaded');imported=marker.with_name('imported');removed=marker.with_name('removed')
partial=marker.with_name('partial');rescanned=marker.with_name('rescanned')
first_id='11111111-1111-4111-8111-111111111111';local_id='22222222-2222-4222-8222-222222222222'
foreign_id='33333333-3333-4333-8333-333333333333';recovered_id='44444444-4444-4444-8444-444444444444'
asset='/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/'+'a'*40+'.asset/AssetData'
with open(os.environ['CALLS'],'a') as log:log.write(json.dumps([Path(sys.argv[0]).name]+args)+'\n')
if args[:1]==['--sdk']:print('27.1')
elif args[:3]==['simctl','runtime','list']:
    records={'unrelated-watch':{'runtimeIdentifier':'com.apple.CoreSimulator.SimRuntime.watchOS-27-0','state':'Unusable'}}
    def record(uid,path,state='Ready'):
        return {'identifier':uid,'runtimeIdentifier':'com.apple.CoreSimulator.SimRuntime.iOS-26-5',
                'build':'23F73' if mode=='download-wrong-build' else '23F77','version':'26.5',
                'platformIdentifier':'com.apple.platform.iphonesimulator','path':path,'state':state,
                'deletable':mode!='not-deletable','unusableSubstate':'Cryptex Mount Preferred'}
    complete=removed.exists() and removed.read_text()=='complete'
    if mode=='pre-existing-image' or downloaded.exists() and not removed.exists():
        records[first_id]=record(first_id,'/unrelated-asset' if mode=='wrong-asset-path' else asset)
    if mode=='pre-existing-id' and not downloaded.exists():records[first_id]={'runtimeIdentifier':'unrelated'}
    if mode=='two-downloads' and downloaded.exists():records[foreign_id]=record(foreign_id,asset)
    if partial.exists() and mode=='partial-foreign-image':records[foreign_id]=record(foreign_id,'/unrelated-asset')
    if rescanned.exists() and not complete:
        counter=marker.with_name('observations');count=int(counter.read_text())+1 if counter.exists() else 1
        counter.write_text(str(count))
        if mode!='partial-pending' and not (mode=='partial-lag' and count<3):
            records[recovered_id]=record(recovered_id,'/unrelated-asset' if mode=='partial-rescan-wrongpath' else asset)
    if imported.exists():
        path='/elsewhere' if mode=='wrong-local-path' else '/Library/Developer/CoreSimulator/Cryptex/Images/'+local_id
        records[local_id]=record(local_id,path,'Unusable' if mode=='local-not-ready' else 'Ready')
        if mode=='two-locals':records[foreign_id]=record(foreign_id,'/Library/Developer/CoreSimulator/Cryptex/Images/'+foreign_id)
        if mode=='foreign-post-import':records[foreign_id]=record(foreign_id,'/unrelated-asset')
    print(json.dumps(records))
elif args[:3]==['simctl','list','devices']:
    devices={}
    if mode=='already-booted' or rescanned.exists() and mode in ('partial-booted','partial-unknown','partial-other-booted'):
        runtime='com.apple.CoreSimulator.SimRuntime.iOS-27-0' if mode=='partial-other-booted' else 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'
        devices[runtime]=[{'state':'Unknown' if mode=='partial-unknown' else 'Booted'}]
    print(json.dumps({'devices':devices}))
elif args[:3]==['simctl','runtime','delete']:
    assert not imported.exists(), 'The downloaded asset must be removed BEFORE import'
    assert args==['simctl','runtime','delete',recovered_id if rescanned.exists() else first_id]
    if mode=='delete-fails':sys.exit(7)
    if mode.startswith('partial') and not partial.exists():
        partial.write_text('partial');removed.write_text('registration only')
        print('An error was encountered processing the command (domain=com.apple.CoreSimulator.simdiskimaged.SimDiskImageError, code=30):')
        print('Removed the runtime, but did not reclaim its MobileAsset: '+asset+('/wrong/' if mode=='partial-wrong-path' else '/'))
        print('unknown advice' if mode=='partial-badmessage' else "Run 'xcrun simctl runtime scan-and-mount' to re-register the runtime, then delete it again.")
        sys.exit(30)
    if mode=='partial-second-fails':sys.exit(30)
    if mode!='delete-stuck':removed.write_text('complete')
elif args[:3]==['simctl','runtime','scan-and-mount']:
    assert partial.exists() and not imported.exists()
    if mode=='partial-scan-fails':sys.exit(9)
    rescanned.write_text('rescanned')
    if mode=='partial-already-reclaimed':removed.write_text('complete')
elif args[:2]==['simctl','list']:
    runtimes=[]
    if mode.startswith('installed') or marker.exists():
        version='26.6' if mode=='wrong-version' else '26.5'
        backing=Path(marker.read_text()) if marker.exists() else None
        runtimes=[{'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+version.replace('.','-'),
                   'version':version,'buildversion':'23F77','isAvailable':mode!='installed-unavailable' and (backing is None or backing.is_file())}]
        if mode in ('installed-wrong-build','download-wrong-build'):runtimes[0]['buildversion']='23F73'
        if mode=='installed-build-missing':del runtimes[0]['buildversion']
        if mode=='installed-duplicate-build':runtimes.append(runtimes[0] | {'buildversion':'23F73'})
    print(json.dumps({'runtimes':runtimes}))
elif args[:1]==['-downloadPlatform']:
    assert args[args.index('-buildVersion')+1]=='23F77'
    assert args[args.index('-architectureVariant')+1]=='arm64'
    if mode=='download-fails':sys.exit(9)
    downloaded.write_text('owned acquisition')
    if mode!='no-image':
        image=Path(args[args.index('-exportPath')+1])/'fictional.exportedBundle'
        image.mkdir();(image/'image').write_text('portable fictional image')
        if mode=='dmg-export':
            (image/'image').unlink();image.rmdir();image=image.with_suffix('.dmg');image.write_text('portable fictional image')
        if mode=='export-symlink':
            backing=image.with_name('backing');image.rename(backing);image.symlink_to(backing,target_is_directory=True)
        if mode=='two-exports':(image.parent/'second.dmg').write_text('fictional image')
        if mode=='auto-installed':marker.write_text(str(image/'image'))
elif args[:1]==['-importPlatform']:
    assert removed.exists() and removed.read_text()=='complete', 'Import must follow complete owned asset reclamation'
    exported=Path(args[1]);image=exported/'image' if exported.is_dir() else exported
    assert image.read_text()=='portable fictional image', 'Portable export must survive source asset removal'
    if mode=='import-fails':sys.exit(8)
    marker.write_text(str(image));imported.write_text('local import')
else:sys.exit(99)
'''
        wrapper=r'''
import os,runpy,sys
from pathlib import Path
from unittest.mock import patch
actual_exists=Path.exists
asset='/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/'+'a'*40+'.asset/AssetData'
def observed_exists(path):
    if str(path)==asset:
        root=Path(os.environ['MARKER']).parent;removed=root/'removed'
        return actual_exists(root/'downloaded') and not (actual_exists(removed) and removed.read_text()=='complete')
    return actual_exists(path)
sys.argv=sys.argv[1:]
with patch.object(Path,'exists',observed_exists):runpy.run_path(sys.argv[0],run_name='__main__')
'''
        successes={'installed','auto-installed','import','dmg-export','partial','partial-already-reclaimed','partial-lag'}
        no_delete={'installed','installed-wrong-build','installed-build-missing','installed-duplicate-build','installed-unavailable',
            'download-fails','no-image','export-symlink','two-exports','pre-existing-image','pre-existing-id','two-downloads',
            'download-wrong-build','not-deletable','already-booted','wrong-asset-path'}
        imports=(successes-{'installed'}) | {'import-fails','wrong-version','wrong-local-path','two-locals','foreign-post-import','local-not-ready'}
        for mode in ('installed','auto-installed','import','dmg-export','partial','partial-already-reclaimed','partial-lag',
                     'download-fails','no-image','import-fails','wrong-version','installed-wrong-build','installed-build-missing',
                     'installed-duplicate-build','installed-unavailable','download-wrong-build','export-symlink','two-exports',
                     'pre-existing-image','pre-existing-id','two-downloads','not-deletable','already-booted','delete-fails','delete-stuck',
                     'partial-second-fails','partial-scan-fails','partial-badmessage','partial-wrong-path','partial-foreign-image',
                     'partial-rescan-wrongpath','partial-pending','partial-booted','partial-unknown','partial-other-booted',
                     'wrong-local-path','two-locals','foreign-post-import','local-not-ready','wrong-asset-path'):
            with self.subTest(mode=mode),tempfile.TemporaryDirectory(prefix='takupoke-runtime-lifetime-') as directory:
                root=Path(directory);scratch=root/'scratch';scratch.mkdir()
                for name in ('xcrun','xcodebuild'):
                    tool=root/name;tool.write_text(fake);tool.chmod(0o700)
                calls=root/'calls';env=os.environ | {'PATH':directory+os.pathsep+os.environ['PATH'],'MODE':mode,
                    'MARKER':str(root/'registered'),'CALLS':str(calls),'RUNNER_TEMP':str(scratch),
                    'TKPK_EXPECTED_IOS_SDK':'27.1','PYTHONDONTWRITEBYTECODE':'1'}
                command=[sys.executable,'-B','-c',wrapper,str(ROOT/'tools/prepare-ios26-runtime.py')]
                prepared=subprocess.run(command+['--hold-export'],env=env,capture_output=True,text=True,timeout=40 if mode=='partial-pending' else 15)
                self.assertEqual(prepared.returncode==0,mode in successes,prepared.stdout+prepared.stderr)
                owned=scratch/'takupoke-ios26-runtime-export-owned'
                self.assertEqual(owned.exists(),not mode.startswith('installed'))
                if mode in successes-{'installed'}:
                    observed=subprocess.run([str(root/'xcrun'),'simctl','list','runtimes','-j'],env=env,
                        capture_output=True,text=True,check=True,timeout=5)
                    self.assertTrue(json.loads(observed.stdout)['runtimes'][0]['isAvailable'])
                before=calls.read_text();commands=[json.loads(line) for line in before.splitlines()]
                self.assertEqual(sum(row[1:2]==['-downloadPlatform'] for row in commands),int(not mode.startswith('installed') and mode!='pre-existing-image'))
                self.assertEqual(sum(row[1:2]==['-importPlatform'] for row in commands),int(mode in imports))
                ids=[] if mode in no_delete else ['11111111-1111-4111-8111-111111111111']
                if mode in ('partial','partial-lag','partial-second-fails'):ids.append('44444444-4444-4444-8444-444444444444')
                self.assertEqual([row for row in commands if 'delete' in row],
                    [['xcrun','simctl','runtime','delete',uid] for uid in ids])
                self.assertEqual(sum(row[1:4]==['simctl','runtime','scan-and-mount'] for row in commands),int(
                    mode.startswith('partial') and mode not in ('partial-badmessage','partial-wrong-path','partial-foreign-image')))
                if mode in imports:
                    imported_at=next(i for i,row in enumerate(commands) if row[1:2]==['-importPlatform'])
                    self.assertTrue(all(i<imported_at for i,row in enumerate(commands) if 'delete' in row))
                for _ in range(2):
                    cleaned=subprocess.run(command+['--cleanup-export'],env=env,capture_output=True,text=True,timeout=5)
                    self.assertEqual(cleaned.returncode,0,cleaned.stderr);self.assertEqual(list(scratch.iterdir()),[])
                self.assertEqual(calls.read_text(),before)

    def test_ios26_export_cleanup_rejects_unknown_directories_and_symlinks(self):
        for kind in ('unmarked','wrong-marker','directory-symlink','marker-symlink'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root=Path(directory);owned=root/'takupoke-ios26-runtime-export-owned'
                external=root/'unrelated';external.mkdir();(external/'keep').write_text('unrelated')
                if kind=='directory-symlink': owned.symlink_to(external,target_is_directory=True)
                else:
                    owned.mkdir();marker=owned/'.takupoke-owner'
                    if kind=='wrong-marker': marker.write_bytes(b'unknown')
                    elif kind=='marker-symlink': marker.symlink_to(external/'keep')
                result=subprocess.run([sys.executable,'-B',str(ROOT/'tools/prepare-ios26-runtime.py'),'--cleanup-export'],
                    env=os.environ|{'RUNNER_TEMP':directory},capture_output=True,text=True,timeout=5)
                self.assertNotEqual(result.returncode,0)
                self.assertTrue(owned.exists())
                self.assertEqual((external/'keep').read_text(),'unrelated')

    def test_exact_installed_download_import_and_failures(self):
        fake = '#!' + sys.executable + '\n' + r'''
import json, os, sys
from pathlib import Path
args=sys.argv[1:]; mode=os.environ['MODE']; marker=Path(os.environ['MARKER'])
with open(os.environ['CALLS'],'a') as log: log.write(json.dumps([Path(sys.argv[0]).name]+args)+'\n')
if args[:1] == ['--sdk']: print('27.1' if mode=='wrong-sdk' else '27.0')
elif args[:2] == ['simctl','list']:
    runtimes=[{'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-27-1','version':'27.1','isAvailable':True}]
    if mode in ('installed','unavailable') or marker.exists():
        version=marker.read_text() if marker.exists() else '27.0'
        runtimes.append({'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+version.replace('.','-'),'version':version,'isAvailable':mode!='unavailable'})
    print(json.dumps({'runtimes':runtimes}))
elif args[:1] == ['-downloadPlatform']:
    assert args[args.index('-buildVersion')+1]=='27.0'
    if mode=='download-fails': sys.exit(9)
    if mode=='auto-installed': marker.write_text('27.0')
    elif mode!='no-image':
        (Path(args[args.index('-exportPath')+1])/'fictional.dmg').write_text('fictional image')
elif args[:1] == ['-importPlatform']:
    assert Path(args[1]).read_text()=='fictional image'
    if mode=='import-fails': sys.exit(8)
    marker.write_text('27.1' if mode=='wrong-version' else '27.0')
else: sys.exit(99)
'''
        for mode in ('installed','auto-installed','import','unavailable','wrong-sdk',
                     'download-fails','no-image','import-fails','wrong-version'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='takupoke-runtime-check-') as directory:
                root=Path(directory); scratch=root/'scratch';scratch.mkdir()
                for name in ('xcrun','xcodebuild'):
                    tool=root/name;tool.write_text(fake);tool.chmod(0o755)
                calls=root/'calls.jsonl'
                env=os.environ | {'PATH':directory+os.pathsep+os.environ['PATH'],'MODE':mode,
                    'MARKER':str(root/'installed-version'),'CALLS':str(calls),'RUNNER_TEMP':str(scratch),
                    'PYTHONDONTWRITEBYTECODE':'1'}
                result=subprocess.run([sys.executable,'-B','tools/prepare-ios27-runtime.py'],cwd=ROOT,
                    env=env,capture_output=True,text=True,timeout=15)
                self.assertEqual(result.returncode==0,mode in ('installed','auto-installed','import'),result.stdout+result.stderr)
                commands=[json.loads(line) for line in calls.read_text().splitlines()]
                downloads=[row for row in commands if row[1:2]==['-downloadPlatform']]
                imports=[row for row in commands if row[1:2]==['-importPlatform']]
                self.assertEqual(len(downloads),int(mode not in ('installed','unavailable','wrong-sdk')))
                self.assertEqual(len(imports),int(mode in ('import','import-fails','wrong-version')))
                self.assertEqual(list(scratch.iterdir()),[])
                self.assertFalse(any('delete' in row for row in commands))

    def test_new_toolchain_requires_exact_sdk_without_changing_either_runtime(self):
        fake = '#!' + sys.executable + '\n' + r'''
import json, os, sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['CALLS'],'a') as log: log.write(json.dumps(args)+'\n')
if args[:1] == ['--sdk']: print(os.environ['FAKE_SDK'])
elif args[:2] == ['simctl','list']:
    print(json.dumps({'runtimes':[{'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+v.replace('.','-'),'version':v,'buildversion':'23F77' if v=='26.5' else 'irrelevant','isAvailable':True} for v in ['26.5','27.0','27.1']]}))
else: sys.exit(99)
'''
        for script in ('prepare-ios26-runtime.py', 'prepare-ios27-runtime.py'):
            for requested, actual, success in [('27.1','27.1',True),('27.2','27.2',True),
                                               ('27.1','27.0',False),('27.2','27.1',False),
                                               ('28.0','28.0',False)]:
                with self.subTest(script=script, requested=requested, actual=actual), tempfile.TemporaryDirectory() as directory:
                    root=Path(directory); calls=root/'calls'
                    tool=root/'xcrun'; tool.write_text(fake); tool.chmod(0o700)
                    env=os.environ | {'PATH':directory+os.pathsep+os.environ['PATH'],
                        'TKPK_EXPECTED_IOS_SDK':requested,'FAKE_SDK':actual,'CALLS':str(calls)}
                    result=subprocess.run([sys.executable,'-B',str(ROOT/'tools'/script)],
                                          env=env,text=True,capture_output=True,timeout=5)
                    self.assertEqual(result.returncode == 0,success,result.stdout+result.stderr)
                    commands=[json.loads(x) for x in calls.read_text().splitlines()] if calls.exists() else []
                    self.assertFalse(any('delete' in x or '-downloadPlatform' in x for x in commands))
                    if success:
                        expected='26.5' if '26' in script else '27.0'
                        self.assertIn('Comparison runtime: iOS '+expected,result.stdout)

if __name__=='__main__': unittest.main()
