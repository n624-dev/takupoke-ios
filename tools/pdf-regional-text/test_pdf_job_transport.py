"""Actual frozen fictional PDF parts; missing, swapped, tampered and oversized refuse."""
import json,os,tempfile,unittest
from pathlib import Path
import pdf_job_transport as transport
class PDFJobTransportTests(unittest.TestCase):
    def values(self):
        pdf=Path(os.environ['PDF_REGION_TEST_PDF']).read_bytes()
        pins=json.loads((Path(__file__).resolve().parents[1]/'unlabeled-pdf-input/input-pins.json').read_text())
        receipt={'PDFSHA256':pins['PDFSHA256'],'PDFBytes':pins['PDFBytes'],'generatorCommit':'4b08662d3c4613b22ffad5c0263915a14771e324','runtimeSourceCommit':'63ea9c88212bfe6a3755743e9c6288ff7d62adfb','nativeCalls':0,'originalPrivateInputs':0,'generatorReceipt':pins,'fontBinaryDeletedBeforeNative':True}
        return pdf,receipt,transport.encode(pdf,json.dumps(receipt).encode())
    def test_exact_actual_pdf_and_receipt_roundtrip(self):
        pdf,receipt,values=self.values();actual,raw=transport.decode(values)
        self.assertEqual(actual,pdf);self.assertEqual(json.loads(raw),receipt)
        with tempfile.TemporaryDirectory(prefix='regional-pdf-receive-') as folder:
            root=Path(folder);(root/'.pdf-regional-owned').touch()
            transport.receive(root,{'REGIONAL_'+k.upper():v for k,v in values.items()})
            self.assertEqual((root/'unlabeled-consumed-development.pdf').read_bytes(),pdf)
    def test_missing_swapped_changed_or_oversized_parts_refuse(self):
        _,_,values=self.values()
        for key in values:
            changed=dict(values);del changed[key]
            with self.assertRaises((AssertionError,KeyError)):transport.decode(changed)
        for changes in [{'pdf_count':'2'},{'pdf_part0':values['pdf_part1'],'pdf_part1':values['pdf_part0']},{'pdf_part2':values['pdf_part2'][:-4]},{'pdf_part0':'A'*20001},{'receipt_base64':'A'*24001}]:
            with self.assertRaises((AssertionError,ValueError)):transport.decode({**values,**changes})
    def test_missing_pixel_proof_or_changed_receipt_refuses_before_write(self):
        pdf,receipt,_=self.values()
        for changes in [{'PDFSHA256':'0'*64},{'nativeCalls':1},{'fontBinaryDeletedBeforeNative':False}]:
            with self.assertRaises(AssertionError):transport.encode(pdf,json.dumps({**receipt,**changes}).encode())
        receipt['generatorReceipt']['verification']['embeddedPixelEquality']=False
        with self.assertRaises(AssertionError):transport.encode(pdf,json.dumps(receipt).encode())
if __name__=='__main__':unittest.main()
