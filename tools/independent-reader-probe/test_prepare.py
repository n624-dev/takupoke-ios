import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('reader_prepare',HERE/'prepare.py')
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)

class NativePreparationTests(unittest.TestCase):
    def fixtures(self,folder):
        # Minimal synthetic transport data never reaches a native Reader.
        (folder/'expected.json').write_text('{}')
        rows=[]
        for name in prepare.FILES:
            data=b'%PDF-synthetic-byte-verification-only-'+name.encode()
            (folder/name).write_bytes(data)
            rows.append({'file':name,'bytes':len(data),'sha256':prepare.sha(data)})
        pins={'expectedSha256':prepare.sha((folder/'expected.json').read_bytes()),'artifacts':rows}
        (folder/'manifest.json').write_text(json.dumps(pins))
        return pins

    def test_prepared_sources_preserve_bytes_and_export_only_pdf_inputs(self):
        with tempfile.TemporaryDirectory() as owned:
            root=Path(owned);fixtures=root/'fixtures';fixtures.mkdir();pins=self.fixtures(fixtures)
            output=root/'prepared';prepare.prepare(output,fixtures,pins)
            manifest=json.loads((output/'native-inputs.json').read_text())
            self.assertEqual([row['file'] for row in manifest['files']],prepare.FILES)
            for row in manifest['files']:self.assertEqual(set(row),{'file','bytes','sha256'})
            self.assertFalse((output/'expected.json').exists())
            for name in prepare.SOURCES:
                self.assertEqual((output/'fixed'/name).read_bytes(),(prepare.ROOT/'Takupoke'/name).read_bytes())
                baseline=subprocess.check_output(['git','show',prepare.BASELINE+':Takupoke/'+name],cwd=prepare.ROOT)
                self.assertEqual((output/'baseline'/name).read_bytes(),baseline)

    def test_changed_pdf_is_rejected_before_native_input_export(self):
        with tempfile.TemporaryDirectory() as owned:
            root=Path(owned);fixtures=root/'fixtures';fixtures.mkdir();pins=self.fixtures(fixtures)
            (fixtures/prepare.FILES[0]).write_bytes(b'changed synthetic bytes')
            with self.assertRaises(AssertionError):prepare.prepare(root/'prepared',fixtures,pins)
            self.assertFalse((root/'prepared/native-inputs.json').exists())

    def test_production_parameters_match_the_actual_source_contract(self):
        generated=prepare.source_parameters().decode()
        self.assertIn('enum MaterialKind:',generated)
        self.assertIn('static let maximumBytes = 50 * 1024 * 1024',generated)
        self.assertNotIn('PDFKitReader',generated)
        self.assertNotIn('RecoveryDocumentBuilder',generated)

if __name__=='__main__':unittest.main()
