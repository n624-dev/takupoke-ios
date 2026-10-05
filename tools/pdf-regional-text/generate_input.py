"""Materialize only the frozen public fictional PDF, verify hashes, remove owned font."""
import hashlib,json,platform,subprocess,sys,urllib.request,zlib
from pathlib import Path
import PIL,PIL.features,fitz
FONT_URL='https://raw.githubusercontent.com/notofonts/noto-cjk/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTC/NotoSansCJK-Regular.ttc'
FONT_BYTES=19484784
FONT_SHA='b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a'
ROOT=Path(__file__).resolve().parents[2]
def generate(work):
    assert work.is_dir() and (work/'.pdf-regional-owned').is_file()
    font=work/'owned-public-font.ttc';out=work/'generated-input'
    assert not font.exists() and not out.exists()
    try:
        with urllib.request.urlopen(FONT_URL,timeout=60) as response,font.open('xb') as target:
            size=0;digest=hashlib.sha256()
            while True:
                chunk=response.read(65536)
                if not chunk:break
                size+=len(chunk);assert size<=FONT_BYTES,'Public font exceeded immutable bound'
                digest.update(chunk);target.write(chunk)
        assert size==FONT_BYTES and digest.hexdigest()==FONT_SHA,'Public font drift; no substitute'
        out.mkdir();(out/'.owned-unlabeled-pdf-input').write_bytes(b'unlabeled-pdf-input-v1\n')
        subprocess.run([sys.executable,'-B',str(ROOT/'tools/unlabeled-pdf-input/generate_pdf.py'),'--font',str(font),'--owned-output',str(out)],check=True)
        pdf=(out/'unlabeled-consumed-development.pdf').read_bytes()
        pins=json.loads((ROOT/'tools/unlabeled-pdf-input/input-pins.json').read_text())
        assert len(pdf)==pins['PDFBytes'] and hashlib.sha256(pdf).hexdigest()==pins['PDFSHA256']
        (work/'unlabeled-consumed-development.pdf').write_bytes(pdf)
        metadata={'generatorCommit':'4b08662d3c4613b22ffad5c0263915a14771e324','runtimeSourceCommit':'63ea9c88212bfe6a3755743e9c6288ff7d62adfb',
          'PDFSHA256':pins['PDFSHA256'],'PDFBytes':len(pdf),'publicFontURL':FONT_URL,'fontBytes':size,'fontSHA256':FONT_SHA,
          'python':platform.python_version(),'Pillow':PIL.__version__,'FreeType':PIL.features.version('freetype2'),'PillowZlib':PIL.features.version('zlib'),
          'pythonZlibBuild':zlib.ZLIB_VERSION,'pythonZlibRuntime':zlib.ZLIB_RUNTIME_VERSION,'PyMuPDF':fitz.VersionBind,
          'generatorReceipt':json.loads((out/'receipt.json').read_text()),'nativeCalls':0,'originalPrivateInputs':0,'fontBinaryDeletedBeforeNative':True}
        (work/'input-generation-receipt.json').write_text(json.dumps(metadata,sort_keys=True,indent=2)+'\n')
    finally:
        if font.is_file():font.unlink()
if __name__=='__main__':generate(Path(sys.argv[1]).resolve())
