"""Observer accounting/transport/posthoc tests; no fake Apple API or OCR runs."""
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib
import analyze
import log_transport
import run_simulator

HERE=Path(__file__).resolve().parent


def candidate(path,confidence=.9,x=5):
    return {'path':path,'rawText':'架空','confidence':confidence,'confidenceScope':'candidate string, not individual character','passesOriginalConfidencePredicate':confidence>=.85,
            'characters':[{'text':v,'pixelTopLeft':{'x':x+i*10,'y':5,'width':10,'height':10}} for i,v in enumerate('架空')],'captureComplete':True}


def region(path,c,words=None):
    return {'path':path,'nativeLineCount':1,'lines':[{'top1':c,'top5':[c]}],
            'wordsAccessorState':'nil' if words is None else 'present','words':words}


def raw_record(c=None):
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\xff\xff'))+chunk(b'IEND',b'')
    a=candidate('observations[0].document.text.lines[0].top1')
    b=c or candidate('observations[0].document.tables[0].rows[0][0].content.text.lines[0].top1')
    h={'captureComplete':True,'omissionCount':0,'roots':[{'text':region('observations[0].document.text',a),
       'tableCell':region('observations[0].document.tables[0].rows[0][0].content.text',b,words=[])}]}
    return [ {'type':'input','image':{'width':1,'height':1,'pngBytes':len(png),'pngSHA256':hashlib.sha256(png).hexdigest(),'losslessPNGBase64':base64.b64encode(png).decode()}},
             {'type':'page','serializationCompleted':True,'hierarchy':h},
             {'type':'oracle','drawingRecords':[{'id':'test','text':'架空','pixelTopLeft':{'x':0,'y':0,'width':30,'height':20}}]},
             {'type':'summary','attemptedRequests':1,'returnedRequests':1} ]


def encoded(records):return ('\n'.join(json.dumps(v,ensure_ascii=False) for v in records)+'\n').encode()


class AuditTests(unittest.TestCase):
    def test_full_candidate_match_removes_only_path_and_keeps_duplicate_observations(self):
        records=raw_record()
        cell=records[1]['hierarchy']['roots'][0]['tableCell']
        cell['lines']*=2
        actual=analyze.analyze(encoded(records))
        count=actual['candidateComparisons']['lines/top1']
        self.assertEqual((count['globalEntries'],count['nestedEntries'],count['nestedEntriesAbsentFromGlobalFullIdentity']),(1,2,0))
        self.assertEqual(actual['wordAccessorStates'],{'nil':1,'present':1})
        self.assertEqual(len(actual['drawingMatches'][0]['nested/lines/top1']),2)

    def test_same_text_changed_confidence_or_geometry_is_not_equal(self):
        for c in [candidate('nested',confidence=.5),candidate('nested',x=500)]:
            actual=analyze.analyze(encoded(raw_record(c)))
            self.assertEqual(actual['candidateComparisons']['lines/top1']['nestedEntriesAbsentFromGlobalFullIdentity'],1)
        c=candidate('nested',x=500)
        self.assertEqual(analyze.analyze(encoded(raw_record(c)))['drawingMatches'][0]['nested/lines/top1'],[])

    def test_native_graphemes_map_codepoint_offsets_without_partial_grapheme_boxes(self):
        c=candidate('graphemes')
        c['characters']=[{'text':'e\u0301','pixelTopLeft':{'x':100,'y':100,'width':10,'height':10}},*c['characters']]
        good={'text':'架空','pixelTopLeft':{'x':0,'y':0,'width':30,'height':20}}
        self.assertEqual(len(analyze.matching(c,good)),1)
        partial={'text':'\u0301','pixelTopLeft':{'x':100,'y':100,'width':10,'height':10}}
        self.assertEqual(analyze.matching(c,partial),[])

    def test_words_matches_are_separate_from_line_comparisons(self):
        records=raw_record()
        cell=records[1]['hierarchy']['roots'][0]['tableCell']
        word=candidate('native-word')
        cell['words']=[{'top1':word,'top5':[word]}]
        actual=analyze.analyze(encoded(records))
        self.assertEqual(len(actual['drawingMatches'][0]['nested/words/top1']),1)
        comparison=actual['candidateComparisons']['words/top1']
        self.assertTrue(comparison['wordSegmentationIsNotRecognitionImprovement'])
        self.assertEqual(actual['candidateComparisons']['lines/top1']['nestedEntriesAbsentFromGlobalFullIdentity'],0)

    def test_input_image_sha_and_dimensions_reject_corruption(self):
        for field,value in [('pngSHA256','0'*64),('width',2)]:
            records=raw_record();records[0]['image'][field]=value
            with self.assertRaises(AssertionError):analyze.analyze(encoded(records))

    def test_operational_failure_is_unassessed_and_missing_records_never_complete(self):
        records=raw_record();records[1]={'type':'page','serializationCompleted':False,'operationalError':'native execution failure'}
        self.assertEqual(analyze.analyze(encoded(records))['recognitionComparison'],'unassessed')
        for v in [records[:2],[],records+[records[-1]]]:
            self.assertFalse(run_simulator.receipt(encoded(v))['recordSequenceComplete'])
            with self.assertRaises(AssertionError):analyze.analyze(encoded(v))

    def test_bounded_unicode_transport_requires_exact_three_streams(self):
        raw=encoded(raw_record())*2000
        lines=[]
        for k,v in [('native/stdout',raw),('native/stderr',b''),('metadata/execution',b'{}')]:lines.extend(log_transport.encode(v,k))
        self.assertTrue(all(len(v.encode())<8192 for v in lines))
        restored=run_simulator.restore_complete('\n'.join('timestamp '+v for v in lines))
        self.assertEqual(restored['native/stdout'],raw)
        for bad in ['', '\n'.join(lines[:-1]),'\n'.join(lines[:1]+lines[2:]),'\n'.join(lines+list(log_transport.encode(b'','extra')))]:
            with self.assertRaises((AssertionError,KeyError)):run_simulator.restore_complete(bad)

    def test_actual_swift_budget_shared_across_rows_columns_words_and_bytes(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc');self.assertTrue(compiler)
        source=(HERE/'HierarchyObservation.swift').read_text()
        start=source.index('final class HierarchyCaptureBudget');end=source.index('\n@available',start)
        source='import Foundation\n'+source[start:end]+'''
@main struct Check {
 static func main() {
  let b=HierarchyCaptureBudget()
  for _ in 0..<1024 { precondition(b.take("rows",path:"rows")) }
  for _ in 0..<1024 { precondition(b.take("rows",path:"columns")) }
  precondition(!b.take("rows",path:"columns overflow"));precondition(b.omissionCount==1)
  let shared=HierarchyCaptureBudget()
  precondition(shared.take("lines",8191,path:"lines"));precondition(shared.take("lines",path:"words"))
  precondition(!shared.take("lines",path:"words overflow"));precondition(shared.counts["lines"]==8192)
  let bytes=HierarchyCaptureBudget()
  precondition(bytes.take("containers",path:"root",estimatedBytes:4194304))
  precondition(!bytes.take("containers",path:"overflow",estimatedBytes:1));precondition(bytes.outputExhausted)
  for _ in 0..<5000 { bytes.omit("x","bounded",available:1) }
  precondition(bytes.omissions.count==2048 && bytes.omissionCount==5001)
  print("budget PASS")
 }
}
'''
        with tempfile.TemporaryDirectory(prefix='fresh-hierarchy-budget-') as folder:
            p=Path(folder);(p/'Budget.swift').write_text(source)
            subprocess.run([compiler,'-parse-as-library',str(p/'Budget.swift'),'-o',str(p/'check')],check=True,capture_output=True,text=True)
            result=subprocess.run([str(p/'check')],check=True,capture_output=True,text=True)
            self.assertIn('budget PASS',result.stdout)


if __name__=='__main__':unittest.main()
