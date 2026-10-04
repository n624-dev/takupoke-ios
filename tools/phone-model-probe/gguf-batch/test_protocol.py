import json
import unittest
from run_batch import decode, grammar, prompt

class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.groups = [dict(id='b8', text='科目:'), dict(id='a1', text='架空科目A'), dict(id='k4', text='教員:'), dict(id='r2', text='教室:')]
        self.good = dict(subject=['b8'], teacher=['k4'], room=['r2'])
    def test_decoder_preserves_original_order_and_rejects_boundary_failures(self):
        self.assertEqual(decode(json.dumps(self.good), self.groups), self.good)
        bad = [dict(subject=['a1','b8'],teacher=[],room=[]), dict(subject=['b8','b8'],teacher=[],room=[]), dict(subject=['b8'],teacher=['b8'],room=[]), dict(subject=['unknown'],teacher=[],room=[]), dict(subject=[1],teacher=[],room=[]), dict(subject=[],teacher=[],room=[],extra=[])]
        for value in bad:
            with self.subTest(value=value), self.assertRaises(ValueError): decode(json.dumps(value), self.groups)
        with self.assertRaises(ValueError):decode('{"subject":[],"subject":[],"teacher":[],"room":[]}',self.groups)
    def test_prompt_and_grammar_do_not_consult_expected_assignment(self):
        case=dict(groups=self.groups,expected=self.good,negative=False,name='hidden')
        first=prompt(case,dict(subject=['科目:']))
        case['expected']=dict(subject=['a1'],teacher=['b8'],room=[])
        self.assertEqual(first,prompt(case,dict(subject=['科目:'])))
        self.assertNotIn('hidden',first)
        self.assertNotIn('expected',first)
        gbnf=grammar(self.groups)
        for group in self.groups:self.assertIn(json.dumps(json.dumps(group['id'])),gbnf)
        self.assertIn('{0,47}',gbnf)
    def test_grammar_escapes_original_ID_content(self):
        gbnf=grammar([dict(id='a"\\b',text='untrusted')])
        self.assertIn(json.dumps(json.dumps('a"\\b')),gbnf)
        self.assertNotIn('untrusted',gbnf)

if __name__=='__main__':unittest.main()
