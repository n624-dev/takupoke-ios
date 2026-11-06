"""Execute actual portable comparison/geometry XCTest source; no native claims."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]

class ManualReviewControlTests(unittest.TestCase):
    def test_actual_review_readiness_requires_one_coherent_state_with_original_deadline(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        if not compiler: self.skipTest('Swift unavailable')
        source=(ROOT/'tests/ui/ManualAssistanceChecks+Review.swift').read_text()
        body=source.split('        var observedState=',1)[1].split('        XCTAssertFalse(ambiguousState,',1)[0]
        body='        var observedState='+body
        harness='''import Foundation
final class Element {
    let values:[String]; var reads=0
    init(_ values:[String]) { self.values=values }
    var label:String { defer { reads += 1 }; return values[min(reads,values.count-1)] }
}
final class Query {
    let elements:[Element]; var queries=0
    init(_ elements:[Element]) { self.elements=elements }
    func matching(identifier:String)->Query { precondition(identifier=="manual-coordinator-state");return self }
    var allElementsBoundByAccessibilityElement:[Element] { queries += 1;return elements }
}
final class Container { let staticTexts:Query;init(_ query:Query) { staticTexts=query } }
final class Containers {
    let container:Container;init(_ query:Query) { container=Container(query) }
    subscript(_ identifier:String)->Container { precondition(identifier=="manual-observation");return container }
}
final class App:NSObject {
    let staticTexts:Query;var otherElements:Containers { Containers(staticTexts) }
    init(_ values:[[String]]) { staticTexts=Query(values.map(Element.init)) }
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
    let app:App;init(_ values:[[String]]) { app=App(values) }
    func run()->(Bool,String) {
BODY
        precondition(app.staticTexts.queries==1)
        precondition(app.staticTexts.elements.allSatisfy { $0.reads <= 1 })
        return (outcome == .completed && !ambiguousState,observedState)
    }
}
let valid="review=true;preview=false;running=false"
precondition(Checks([[valid]]).run().0)
for values in [[], [["review=false;preview=false"]], [["review=true;preview=true"]], [[valid],[valid]],
               [["review=true;preview=true","review=false;preview=false"]]] as [[[String]]] {
    precondition(!Checks(values).run().0)
}
precondition(Checks([[valid]]).run().1==valid)
'''.replace('BODY',body)
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
        self.assertEqual(len(geometry_names),8)
        runner='\nXCTMain([testCase(['+','.join('("'+n+'",RecoveryManualReviewTests.'+n+')' for n in names)+']),testCase(['+','.join('("'+n+'",ObservedScreenGeometryTests.'+n+')' for n in geometry_names)+'])])\n'
        with tempfile.TemporaryDirectory(prefix='manual-review-controls-') as scratch:
            path=Path(scratch);(path/'main.swift').write_text(tests+geometry+runner)
            subprocess.run([compiler, '-swift-version', '5', '-module-cache-path', str(path/'modules'),
                            str(ROOT/'Takupoke/RecoveryManualReview.swift'), str(ROOT/'tests/Support/ObservedScreenGeometry.swift'), str(path/'main.swift'),
                            '-o', str(path/'controls')], check=True)
            subprocess.run([str(path/'controls')],check=True)

if __name__=='__main__': unittest.main()
