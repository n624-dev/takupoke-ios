"""Frozen fictional PDF via bounded transient job outputs; never print image bytes."""
import base64,hashlib,json,os,sys
from pathlib import Path
PDF_SHA='7ceb34d191dc48a5d6bc072e75898172cd20f356f6c9c312f558635d6a454323'
PDF_BYTES=41545
RGB_SHA='62f80f469cd0d36cb98ddc8ecebee71c94a278c2ee3c7e22336688f844e38fd9'
RGBA_SHA='1840402f64f9e0343c414fa23d1d27f7528f9b225a66cd93a35c57d2e102f0df'
PNG_SHA='3bb95ebcce616cf24c6b4c431f6fe9b790491e5d22085f74e4430cfd5871b946'
def validate(pdf,receipt):
    assert len(pdf)==PDF_BYTES and hashlib.sha256(pdf).hexdigest()==PDF_SHA,'Frozen PDF byte identity'
    assert receipt['PDFSHA256']==PDF_SHA and receipt['PDFBytes']==PDF_BYTES
    assert receipt['generatorCommit']=='4b08662d3c4613b22ffad5c0263915a14771e324'
    assert receipt['runtimeSourceCommit']=='63ea9c88212bfe6a3755743e9c6288ff7d62adfb'
    assert receipt['nativeCalls']==0 and receipt['originalPrivateInputs']==0
    generated=receipt['generatorReceipt'];verification=generated['verification']
    assert generated['PDFSHA256']==PDF_SHA and generated['PNGSHA256']==PNG_SHA
    assert verification['embeddedDecodedRGBSHA256']==RGB_SHA and verification['actualPDFRenderedRGBA1xSHA256']==RGBA_SHA
    assert verification['embeddedPixelEquality'] is True and verification['actual1xRenderPixelEquality'] is True
    assert verification['width']==3740 and verification['height']==800 and verification['pageCount']==1 and verification['rotation']==0
    assert receipt['fontBinaryDeletedBeforeNative'] is True

def encode(pdf,receipt_bytes):
    assert len(receipt_bytes)<=16000
    receipt=json.loads(receipt_bytes.decode('utf-8'));validate(pdf,receipt)
    raw=base64.b64encode(pdf).decode('ascii');parts=[raw[i:i+20000] for i in range(0,len(raw),20000)]
    assert len(parts)==3
    return {'pdf_count':'3',**{f'pdf_part{i}':part for i,part in enumerate(parts)},'receipt_base64':base64.b64encode(receipt_bytes).decode('ascii')}

def decode(values):
    assert values['pdf_count']=='3','Missing/fixed part count'
    parts=[values[f'pdf_part{i}'] for i in range(3)]
    assert len(parts[0])==len(parts[1])==20000 and 0<len(parts[2])<=20000,'Ordered bounded part lengths'
    receipt64=values['receipt_base64'];assert len(receipt64)<=24000
    pdf=base64.b64decode(''.join(parts),validate=True)
    receipt_bytes=base64.b64decode(receipt64,validate=True);assert len(receipt_bytes)<=16000
    validate(pdf,json.loads(receipt_bytes.decode('utf-8')))
    return pdf,receipt_bytes

def owned(work):
    assert work.is_dir() and not work.is_symlink() and (work/'.pdf-regional-owned').is_file()

def write_outputs(work,path):
    owned(work);values=encode((work/'unlabeled-consumed-development.pdf').read_bytes(),(work/'input-generation-receipt.json').read_bytes())
    assert sum(len(v) for v in values.values())*2<900000
    with path.open('a',encoding='utf-8',newline='\n') as target:
        for key,value in values.items():target.write(key+'='+value+'\n')
    print(json.dumps({'transientPDFBytes':PDF_BYTES,'transientPDFSHA256':PDF_SHA,'transientParts':3,'printedBinaryPayload':False}))

def receive(work,environment):
    owned(work);assert {p.name for p in work.iterdir()}=={'.pdf-regional-owned'}
    values={key:environment['REGIONAL_'+key.upper()] for key in ['pdf_count','pdf_part0','pdf_part1','pdf_part2','receipt_base64']}
    pdf,receipt=decode(values)
    with (work/'unlabeled-consumed-development.pdf').open('xb') as target:target.write(pdf)
    with (work/'input-generation-receipt.json').open('xb') as target:target.write(receipt)
    print(json.dumps({'receivedPDFBytes':len(pdf),'receivedPDFSHA256':PDF_SHA,'receiptBytes':len(receipt),'receiptSHA256':hashlib.sha256(receipt).hexdigest(),'MacFontRenderCalls':0,'nativeCalls':0}))
if __name__=='__main__':
    if sys.argv[1]=='outputs':write_outputs(Path(sys.argv[2]),Path(sys.argv[3]))
    elif sys.argv[1]=='receive':receive(Path(sys.argv[2]),os.environ)
    else:raise ValueError('Unknown operation')
