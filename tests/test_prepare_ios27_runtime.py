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
args=sys.argv[1:]; mode=os.environ['MODE']; marker=Path(os.environ['MARKER'])
with open(os.environ['CALLS'],'a') as log: log.write(json.dumps([Path(sys.argv[0]).name]+args)+'\n')
if args[:1] == ['--sdk']: print('27.1')
elif args[:2] == ['simctl','list']:
    runtimes=[]
    if mode=='installed' or marker.exists():
        version='26.6' if mode=='wrong-version' else '26.5'
        # Registration depends on its real exported file remaining available.
        backing=Path(marker.read_text()) if marker.exists() else None
        runtimes=[{'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+version.replace('.','-'),
                   'version':version,'isAvailable':backing is None or backing.is_file()}]
    print(json.dumps({'runtimes':runtimes}))
elif args[:1] == ['-downloadPlatform']:
    assert args[args.index('-buildVersion')+1]=='26.5'
    if mode=='download-fails': sys.exit(9)
    if mode!='no-image':
        image=Path(args[args.index('-exportPath')+1])/'fictional.dmg'
        image.write_text('fictional image')
        if mode=='auto-installed': marker.write_text(str(image))
elif args[:1] == ['-importPlatform']:
    assert Path(args[1]).read_text()=='fictional image'
    if mode=='import-fails': sys.exit(8)
    marker.write_text(args[1])
else: sys.exit(99)
'''
        for mode in ('installed','auto-installed','import','download-fails','no-image','import-fails','wrong-version'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='takupoke-runtime-lifetime-') as directory:
                root=Path(directory);scratch=root/'scratch';scratch.mkdir()
                for name in ('xcrun','xcodebuild'):
                    tool=root/name;tool.write_text(fake);tool.chmod(0o700)
                calls=root/'calls'
                env=os.environ | {'PATH':directory+os.pathsep+os.environ['PATH'],'MODE':mode,
                    'MARKER':str(root/'registered'),'CALLS':str(calls),'RUNNER_TEMP':str(scratch),
                    'TKPK_EXPECTED_IOS_SDK':'27.1','PYTHONDONTWRITEBYTECODE':'1'}
                command=[sys.executable,'-B',str(ROOT/'tools/prepare-ios26-runtime.py')]
                prepared=subprocess.run(command+['--hold-export'],env=env,capture_output=True,text=True,timeout=15)
                self.assertEqual(prepared.returncode==0,mode in ('installed','auto-installed','import'),prepared.stdout+prepared.stderr)
                owned=scratch/'takupoke-ios26-runtime-export-owned'
                self.assertEqual(owned.exists(),mode!='installed')
                if mode in ('auto-installed','import'):
                    self.assertEqual((owned/'fictional.dmg').read_text(),'fictional image')
                    observed=subprocess.run([str(root/'xcrun'),'simctl','list','runtimes','-j'],env=env,
                        capture_output=True,text=True,check=True,timeout=5)
                    self.assertTrue(json.loads(observed.stdout)['runtimes'][0]['isAvailable'])
                before=calls.read_text()
                for _ in range(2):
                    cleaned=subprocess.run(command+['--cleanup-export'],env=env,capture_output=True,text=True,timeout=5)
                    self.assertEqual(cleaned.returncode,0,cleaned.stderr)
                    self.assertEqual(list(scratch.iterdir()),[])
                self.assertEqual(calls.read_text(),before) # Cleanup does not mutate runtime registration.

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
    print(json.dumps({'runtimes':[{'identifier':'com.apple.CoreSimulator.SimRuntime.iOS-'+v.replace('.','-'),'version':v,'isAvailable':True} for v in ['26.5','27.0','27.1']]}))
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
