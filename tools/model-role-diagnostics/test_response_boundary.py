"""Returned format/semantic failure must never become a native runtime failure."""
import importlib.util,unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from response_protocol import decode_ids
spec=importlib.util.spec_from_file_location('probe',Path(__file__).with_name('dev_server_probe.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class BoundaryTests(unittest.TestCase):
 def result(self,raw):
  return m.observe_response(lambda:{'choices':[{'message':{'content':raw}}]}, {'ids':['a']}, [{'id':'a'},{'id':'b'}])
 def test_returned_fence_is_format_failure(self):
  r=self.result('```json\n{"ids":["a"]}\n```');self.assertTrue(r['nativeReturned']);self.assertFalse(r['operationalError']);self.assertFalse(r['exact']);self.assertTrue(r['strictDecodeFailure'])
 def test_wrong_valid_selection_is_semantic_failure(self):
  r=self.result('{"ids":["b"]}');self.assertTrue(r['strictDecoded']);self.assertFalse(r['exact']);self.assertFalse(r['operationalError'])
 def test_invocation_failure_is_unassessed(self):
  def fail():raise TimeoutError('controlled timeout')
  r=m.observe_response(fail,{'ids':['a']},[{'id':'a'}]);self.assertTrue(r['operationalError']);self.assertFalse(r['nativeReturned']);self.assertNotIn('exact',r)
 def test_duplicate_key_and_order_are_returned_failures(self):
  for raw in ['{"ids":[],"ids":["a"]}','{"ids":["b","a"]}','{"ids":["a","a"]}']:
   r=self.result(raw);self.assertTrue(r['nativeReturned']);self.assertFalse(r['operationalError']);self.assertFalse(r['strictDecoded'])
 def test_array_imitating_object_never_decodes(self):
  for raw in ['[["ids",["a"]]]','{"ids":[["a"]]}','{"ids":null}','{"ids":["unknown"]}']:
   with self.assertRaises(ValueError):decode_ids(raw,[{'id':'a'},{'id':'b'}])
 def test_good_order_preserves_raw_selection(self):
  self.assertEqual(decode_ids('{"ids":["a","b"]}',[{'id':'a'},{'id':'b'}]),{'ids':['a','b']})
if __name__=='__main__':unittest.main()
