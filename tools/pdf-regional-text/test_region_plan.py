"""Actual Swift physical planner safety: no OCR or synthetic native API."""
from pathlib import Path
import os,shutil,subprocess,tempfile,unittest

HERE=Path(__file__).resolve().parent
HARNESS='''
func rails(_ top:Double=50,_ middle:Double=90,_ bottom:Double=200)->[MeasuredRail] {
    var result=[top,middle,bottom].map{MeasuredRail(x1:100,y1:$0,x2:1000,y2:$0)}
    for x in stride(from:100.0,through:1000.0,by:180) {result.append(MeasuredRail(x1:x,y1:top,x2:x,y2:bottom))}
    return result
}
func plan(_ input:[MeasuredRail],metadata:PhysicalBox?=PhysicalBox(x:30,y:10,width:200,height:20),check:()throws->Void={})throws->[PlannedRegion] {
    try RegionalPlan.derive(rails:input,coarseWidth:1000,coarseHeight:400,originalWidth:2000,originalHeight:800,coarseScale:0.5,upperInkExtent:{_ in metadata},check:check)
}
func refuses(_ body:()throws->Void) {do {try body();fatalError("Unsafe plan returned")}catch {}}
'''

class RegionPlanTests(unittest.TestCase):
    def run_swift(self,body):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc');self.assertTrue(compiler)
        with tempfile.TemporaryDirectory(prefix='ios-region-plan-') as folder:
            main=Path(folder)/'main.swift';main.write_text(HARNESS+body+'\nprint("PASS")\n')
            binary=Path(folder)/'plan'
            subprocess.run([compiler,str(HERE/'RegionPlan.swift'),str(main),'-o',str(binary)],check=True,capture_output=True)
            self.assertEqual(subprocess.run([str(binary)],check=True,capture_output=True,text=True).stdout.strip(),'PASS')

    def test_closed_measured_band_and_inverse_basis_make_only_seven_bounded_regions(self):
        self.run_swift('''let result=try plan(rails())
precondition(result.count==7)
precondition(result[0].box==PhysicalBox(x:198,y:98,width:364,height:304))
precondition(result[5].box==PhysicalBox(x:0,y:98,width:202,height:304))
precondition(result[6].box==PhysicalBox(x:28,y:8,width:204,height:24))
precondition(result.allSatisfy{$0.scale==2 && $0.box.right<=2000 && $0.box.bottom<=800 && $0.box.width*2<=2048})''')

    def test_missing_closed_rail_cannot_be_filled_from_known_cell_ordinal(self):
        self.run_swift('''let broken=rails().filter{!($0.x1==460 && $0.x2==460)}
refuses {_=try plan(broken)}''')

    def test_two_equal_closed_bands_are_ambiguous(self):
        self.run_swift('''refuses {_=try plan(rails()+rails(250,290,350))}''')

    def test_invalid_or_missing_metadata_and_oversized_region_refuse(self):
        self.run_swift('''refuses {_=try plan(rails(),metadata:nil)}
refuses {_=try plan(rails(),metadata:PhysicalBox(x:0,y:0,width:1500,height:20))}
refuses {_=try plan(rails(),metadata:PhysicalBox(x:-1,y:0,width:20,height:20))}
refuses {_=try plan(rails()+[MeasuredRail(x1:Double.nan,y1:0,x2:20,y2:0)])}''')

    def test_cancellation_is_terminal_before_plan_can_return(self):
        self.run_swift('''enum Cancel:Error {case requested}
var observed=false
do {_=try plan(rails(),check:{throw Cancel.requested});fatalError("cancelled plan returned")}
catch Cancel.requested {observed=true}
precondition(observed)''')

    def test_actual_ceil_height_affine_and_neighboring_roi_refusal(self):
        self.run_swift("""
let scale=2048.0/3740.0
let affine=RasterAffine(sourceBox:PhysicalBox(x:0,y:0,width:3740,height:800),scale:scale,renderedHeight:439)
precondition(abs(affine.offsetY-(439-800*scale))<1e-12)
for sourceY in [0.0,100.0,799.0] {
    let measured=PhysicalBox(x:200*scale,y:sourceY*scale+affine.offsetY,width:30*scale,height:2*scale)
    let returned=affine.original(measured)
    precondition(abs(returned.x-200)<1e-9 && abs(returned.y-sourceY)<1e-9)
    precondition(abs(returned.width-30)<1e-9 && abs(returned.height-2)<1e-9)
}
let region=RasterAffine(sourceBox:PhysicalBox(x:100,y:200,width:300,height:400),scale:2,renderedHeight:800)
let outside=PhysicalBox(x:599,y:50,width:2,height:10)
let original=region.original(outside)
precondition(original.right<3740) // Inside page alone is insufficient: neighboring never-observed pixel.
precondition(!RasterAffine.localRangeProvenance(outside,width:600,height:800))
precondition(RasterAffine.localRangeProvenance(PhysicalBox(x:590,y:790,width:10,height:10),width:600,height:800))
""")

if __name__=='__main__':unittest.main()
