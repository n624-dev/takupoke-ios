"""Execute actual portable comparison/geometry XCTest source; no native claims."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]

class ManualReviewControlTests(unittest.TestCase):
    def test_actual_review_readiness_requires_one_coherent_state_with_original_deadline(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        if not compiler: self.skipTest('Swift unavailable')
        source=(ROOT/'tests/ui/ManualAssistanceChecks+Review.swift').read_text()
        selector=source.split('    private func coordinatorState(',1)[1].split('    func requireReview(',1)[0]
        body='        var observedState='+source.split('        var observedState=',1)[1].split('        XCTAssertFalse(ambiguousState,',1)[0]
        preview=source.split('    func requirePreview(revalidatedAfter: Int? = nil) {',1)[1].split('        print("TAKUPOKE-MANUAL-COORDINATOR',1)[0]
        harness='''import Foundation
enum ElementType { case other, staticText, button }
struct Node {
    let elementType:ElementType
    let identifier:String
    var label=""
    var children:[Node]=[]
}
final class App:NSObject {
    let children:[Node];var snapshots=0
    init(_ children:[Node]) { self.children=children }
    func snapshot() throws ->Node {
        snapshots+=1
        return Node(elementType:.other,identifier:"application",children:children)
    }
}
final class XCTNSPredicateExpectation {
    let predicate:NSPredicate,object:Any
    init(predicate:NSPredicate,object:Any) { self.predicate=predicate;self.object=object }
}
enum Outcome { case completed,timedOut }
enum XCTWaiter {
    static func wait(for expectations:[XCTNSPredicateExpectation],timeout:Double)->Outcome {
        precondition(timeout==20 && expectations.count==1)
        return expectations[0].predicate.evaluate(with:expectations[0].object) ? .completed:.timedOut
    }
}
final class Checks {
    let app:App;init(_ nodes:[Node]) { app=App(nodes) }
    func snapshotNodes(in node:Node)->[Node]? {
        node.children.flatMap { [$0]+(snapshotNodes(in:$0) ?? []) }
    }
SELECTOR
    func run()->(Bool,String) {
BODY
        precondition(app.snapshots==1)
        return (outcome == .completed && !ambiguousState,observedState)
    }
    func preview(revalidatedAfter:Int?) -> Bool {
PREVIEW
        precondition(app.snapshots==1)
        return outcome == .completed && !ambiguous
    }
}
let valid="review=true;preview=false;running=false"
func state(_ label:String,_ type:ElementType = .staticText)->Node {
    Node(elementType:type,identifier:"manual-coordinator-state",label:label)
}
func owner(_ children:[Node],_ identifier:String = "manual-observation")->Node {
    Node(elementType:.other,identifier:identifier,children:children)
}
let correct=owner([state(valid)])
let unrelated=owner([state("review=false;preview=true")],"manual-root-observation")
precondition(Checks([correct,unrelated]).run().1==valid)
precondition(Checks([correct,unrelated]).run().0)
for nodes in [[], [unrelated], [owner([state("review=false;preview=false")])],
              [owner([state("review=true;preview=true")])], [owner([state(valid,.button)])],
              [owner([state("review=true;preview=true"),state("review=false;preview=false")])],
              [owner([state(valid),state(valid)])], [correct,correct]] {
    precondition(!Checks(nodes).run().0)
}
func preview(_ fields:String) -> Checks { Checks([owner([state("preview=true;"+fields)])]) }
precondition(preview("running=false;revalidation=false;revalidations=4").preview(revalidatedAfter:nil))
precondition(preview("running=false;revalidation=false;revalidations=5").preview(revalidatedAfter:4))
for fields in ["running=false;revalidation=false;revalidations=4", "running=false;revalidation=false;revalidations=6",
               "running=true;revalidation=false;revalidations=5", "running=false;revalidation=true;revalidations=5",
               "running=false;revalidation=false"] {
    precondition(!preview(fields).preview(revalidatedAfter:4))
}
'''.replace('SELECTOR','    private func coordinatorState('+selector).replace('BODY',body).replace('PREVIEW',preview)
        with tempfile.TemporaryDirectory(prefix='manual-review-state-') as scratch:
            path=Path(scratch);(path/'main.swift').write_text(harness)
            subprocess.run([compiler,'-swift-version','5','-module-cache-path',str(path/'modules'),
                            str(path/'main.swift'),'-o',str(path/'controls')],check=True)
            subprocess.run([str(path/'controls')],check=True)

    def test_actual_xctest_comparison_and_pixel_geometry(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        if not compiler: self.skipTest('Swift unavailable; the same XCTest runs in package CI')
        tests=(ROOT/'tests/RecoveryManualReviewTests.swift').read_text().replace('@testable import TakupokeParsing','')
        names=re.findall(r'    func (test\w+)\(',tests)
        self.assertEqual(len(names),10)
        geometry=(ROOT/'tests/ObservedScreenGeometryTests.swift').read_text()
        geometry_names=re.findall(r'    func (test\w+)\(',geometry)
        self.assertEqual(len(geometry_names),9)
        self.assertIn('testClippedScrollLabelOffersOnlyPointsWithBothDragEndpointsVisible',geometry_names)
        runner='\nXCTMain([testCase(['+','.join('("'+n+'",RecoveryManualReviewTests.'+n+')' for n in names)+']),testCase(['+','.join('("'+n+'",ObservedScreenGeometryTests.'+n+')' for n in geometry_names)+'])])\n'
        with tempfile.TemporaryDirectory(prefix='manual-review-controls-') as scratch:
            path=Path(scratch);(path/'main.swift').write_text(tests+geometry+runner)
            subprocess.run([compiler, '-swift-version', '5', '-module-cache-path', str(path/'modules'),
                            str(ROOT/'Takupoke/RecoveryManualReview.swift'), str(ROOT/'tests/Support/ObservedScreenGeometry.swift'), str(path/'main.swift'),
                            '-o', str(path/'controls')], check=True)
            subprocess.run([str(path/'controls')],check=True)

if __name__=='__main__': unittest.main()
