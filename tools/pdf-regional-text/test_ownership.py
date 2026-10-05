"""Actual pinned raster + candidate ownership ledger; no Vision or model APIs."""
import os,shutil,subprocess,tempfile,unittest,hashlib,json,sys
import fitz
from pathlib import Path
import prepare
HERE=Path(__file__).resolve().parent
class OwnershipTests(unittest.TestCase):
    def test_actual_pixel_support_shared_ranges_missing_ink_and_bounded_inventory(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc');self.assertTrue(compiler)
        with tempfile.TemporaryDirectory(prefix='pdf-region-ownership-') as folder:
            root=Path(folder);prepare.prepare(root/'prepared')
            main=root/'main.swift'
            main.write_text(r'''import Foundation
enum Stop:Error {case cancel}
func check(_ condition:Bool,_ message:String) {precondition(condition,message)}
var gray=[UInt8](repeating:255,count:400);gray[105]=0;gray[106]=0
let raster=try RecoveryRasterGrid(width:20,height:20,grayscale:gray).preparingRules([])
let box=RecoveryBox(x:5,y:5,width:2,height:1)
func proof(_ owners:[NativeRangeOwner])throws->[String:Any] {try OriginalInkOwnership.measure(raster,owners:owners,check:{})}
let good=try proof([NativeRangeOwner(id:"line",boxes:[box,box])])
check(good["completeUniqueCandidateRangeOwnership"] as? Bool==true,"same word-range repetitions retain one candidate owner")
check(good["singleCandidateOwnerPixels"] as? Int==2,"actual ink pixels counted")
let shared=try proof([NativeRangeOwner(id:"one",boxes:[box]),NativeRangeOwner(id:"two",boxes:[box])])
check(shared["multipleCandidateOwnerPixels"] as? Int==2,"distinct candidates sharing ink refuse")
check(shared["completeUniqueCandidateRangeOwnership"] as? Bool==false,"cross candidate overlap cannot prove ownership")
let missing=try proof([]);check(missing["unownedNonrulePixels"] as? Int==2,"whole original ink cannot disappear")
let white=try proof([NativeRangeOwner(id:"white",boxes:[RecoveryBox(x:0,y:0,width:1,height:1)])])
check(white["ownersWithoutNonruleInk"] as? [String]==["white"],"white boxes do not prove readable support")
// Aggregate inventory guard occurs before per-box/map work. Only 100001 tiny value boxes, no giant raster.
let many=[NativeRangeOwner(id:"mass",boxes:Array(repeating:box,count:100001))]
do {_=try proof(many);fatalError("aggregate inventory exceeded")}catch let e as NSError {check(e.domain=="NativeOwnerInventoryCap","inventory bound")}
// Cancellation during validation, after initial check, must happen before pixel ownership traversal.
var checks=0
let bounded=[NativeRangeOwner(id:"bounded",boxes:Array(repeating:box,count:100000))]
do {_=try OriginalInkOwnership.measure(raster,owners:bounded,check:{checks+=1;if checks==2 {throw Stop.cancel}});fatalError("cancel ignored")}catch Stop.cancel {}
check(checks==2,"charged inventory polls cancellation")
// Every original nonrule pixel is still audited beside a physically verified border.
var ruledGray=gray;for x in 0..<20 {ruledGray[x]=0}
let rule=PDFRule(x1:0,y1:0,x2:19,y2:0)
let ruled=try RecoveryRasterGrid(width:20,height:20,grayscale:ruledGray).preparingRules([rule])
let ruledProof=try OriginalInkOwnership.measure(ruled,owners:[NativeRangeOwner(id:"line",boxes:[box])],check:{})
check(ruledProof["physicalRulePixels"] as? Int==20,"actual prepared rule mask used")
check(ruledProof["completeUniqueCandidateRangeOwnership"] as? Bool==true,"physical border is not missing text")
if CommandLine.arguments.count==4 {
    let originalBytes=[UInt8](try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
    let coarseBytes=[UInt8](try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2])))
    let dims=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[3]))) as! [String:Any]
    let original=RecoveryRasterGrid(width:3740,height:800,grayscale:originalBytes)
    let coarse=RecoveryRasterGrid(width:dims["width"] as! Int,height:dims["height"] as! Int,grayscale:coarseBytes)
    let rails=try coarse.rules(check:{})
    let plan=try RegionalPlan.derive(rails:rails.map{MeasuredRail(x1:$0.x1,y1:$0.y1,x2:$0.x2,y2:$0.y2)},coarseWidth:coarse.width,coarseHeight:coarse.height,originalWidth:3740,originalHeight:800,coarseScale:dims["scale"] as! Double,upperInkExtent:{before in
        var left=3740,right = -1,top=800,bottom = -1
        for y in 0..<Int(floor(before)) {for x in 0..<3740 where original.grayscale[y*3740+x] != 255 {left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)}}
        return right>=left ? PhysicalBox(x:Double(left),y:Double(top),width:Double(right-left+1),height:Double(bottom-top+1)):nil
    },check:{})
    check(plan.count==7,"actual source-generated PDF physical rails can plan seven regions")
    print("model-free PyMuPDF rails preflight \(String(data:try JSONEncoder().encode(plan),encoding:.utf8)!)")
}
print("ownership controls PASS")
''')
            binary=root/'test';sources=[root/'prepared'/name for name in prepare.SOURCES if name!='RecoveryConversion.swift' or sys.platform=='darwin']+[root/'prepared/SourceParameters.swift',HERE/'OriginalInkOwnership.swift',HERE/'RegionPlan.swift',main]
            compiled=subprocess.run([compiler,'-swift-version','5',*map(str,sources),'-o',str(binary)],capture_output=True,text=True)
            self.assertEqual(compiled.returncode,0,compiled.stderr[-8000:])
            pdf_path=Path(os.environ['PDF_REGION_TEST_PDF'])
            pdf_bytes=pdf_path.read_bytes();self.assertEqual(hashlib.sha256(pdf_bytes).hexdigest(),'7ceb34d191dc48a5d6bc072e75898172cd20f356f6c9c312f558635d6a454323')
            pdf=fitz.open(stream=pdf_bytes,filetype='pdf');self.assertEqual(len(pdf),1)
            args=[]
            for name,scale in [('original',1),('coarse',2048/3740)]:
                pixels=pdf[0].get_pixmap(matrix=fitz.Matrix(scale,scale),alpha=False)
                data=pixels.samples;gray=bytes(min(data[i:i+3]) for i in range(0,len(data),3))
                path=root/(name+'.gray');path.write_bytes(gray);args.append(str(path))
            metadata=root/'basis.json';metadata.write_text(json.dumps({'width':pixels.width,'height':pixels.height,'scale':2048/3740}));args.append(str(metadata))
            result=subprocess.run([str(binary),*args],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr[-4000:]);self.assertIn('controls PASS',result.stdout);print(result.stdout.strip())
if __name__=='__main__':unittest.main()
