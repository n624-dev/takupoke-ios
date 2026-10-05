"""Execute actual portable comparison/geometry XCTest source; no native claims."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]

class ManualReviewControlTests(unittest.TestCase):
    def test_actual_xctest_comparison_and_pixel_geometry(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        if not compiler: self.skipTest('Swift unavailable; the same XCTest runs in package CI')
        tests=(ROOT/'tests/RecoveryManualReviewTests.swift').read_text().replace('@testable import TakupokeParsing','')
        names=re.findall(r'    func (test\w+)\(',tests)
        self.assertEqual(len(names),10)
        runner='\nXCTMain([testCase(['+','.join('("'+n+'",RecoveryManualReviewTests.'+n+')' for n in names)+'])])\n'
        with tempfile.TemporaryDirectory(prefix='manual-review-controls-') as scratch:
            path=Path(scratch);(path/'main.swift').write_text(tests+runner)
            subprocess.run([compiler,'-swift-version','5',str(ROOT/'Takupoke/RecoveryManualReview.swift'),str(path/'main.swift'),'-o',str(path/'controls')],check=True)
            subprocess.run([str(path/'controls')],check=True)

if __name__=='__main__': unittest.main()
