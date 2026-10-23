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

if __name__=='__main__': unittest.main()
