"""Compile the actual Foundation-only accounting class; no fake Vision types."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('prepare',HERE/'prepare.py')
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)
class BudgetTests(unittest.TestCase):
    def test_shared_empty_rows_bytes_and_bounded_omissions(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        self.assertTrue(compiler, 'Actual Swift compiler is required')
        source='import Foundation\n'+prepare.block((HERE/'HierarchyObservation.swift').read_text(), 'final class HierarchyCaptureBudget')
        source+='''
@main struct Check {
 static func main() {
  let rows=HierarchyCaptureBudget()
  for i in 0..<2048 { precondition(rows.take("rows",path:"emptyRows[\\(i)]",estimatedBytes:64)) }
  precondition(!rows.take("rows",path:"emptyRows[2048]",estimatedBytes:64))
  precondition(rows.counts["rows"]==2048 && rows.omissionCount==1)
  let bytes=HierarchyCaptureBudget()
  precondition(bytes.take("containers",path:"root",estimatedBytes:4194304))
  precondition(!bytes.take("containers",path:"over",estimatedBytes:1))
  precondition(bytes.outputExhausted && bytes.estimatedBytes==4194304 && bytes.counts["containers"]==1)
  let bad=HierarchyCaptureBudget()
  precondition(!bad.take("rows",-1,path:"negative"))
  for _ in 0..<5000 { bad.omit("bounded","stress",available:1) }
  precondition(bad.omissions.count==2048 && bad.omissionCount==5001)
  precondition(HierarchyCaptureBudget().counts.isEmpty)
  print("budget boundaries PASS")
 }
}
'''
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);(p/'Budget.swift').write_text(source)
            subprocess.run([compiler,'-parse-as-library',str(p/'Budget.swift'),'-o',str(p/'check')],check=True,capture_output=True,text=True)
            actual=subprocess.run([str(p/'check')],check=True,capture_output=True,text=True)
            self.assertIn('budget boundaries PASS',actual.stdout)
if __name__=='__main__': unittest.main()
