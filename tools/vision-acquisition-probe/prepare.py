"""Verify immutable real source; extract acquisition-only declarations without edits."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def sha(data):
    return hashlib.sha256(data).hexdigest()

def block(text, marker):
    if text.count(marker) != 1:
        raise ValueError('Ambiguous/missing source selector: ' + marker)
    start = text.index(marker)
    opening = text.index('{', start)
    depth, i = 1, opening + 1
    while i < len(text):
        if text.startswith('//', i):
            i = text.index('\n', i) + 1
            continue
        if text.startswith('/*', i):
            nesting = 1; i += 2
            while nesting and i < len(text):
                if text.startswith('/*', i): nesting += 1; i += 2
                elif text.startswith('*/', i): nesting -= 1; i += 2
                else: i += 1
            if nesting: raise ValueError('Unclosed comment')
            continue
        if text[i] == '"':
            i += 1
            while i < len(text):
                if text[i] == '\\': i += 2
                elif text[i] == '"': i += 1; break
                else: i += 1
            continue
        if text[i] == '{': depth += 1
        if text[i] == '}':
            depth -= 1
            if depth == 0: return text[start:i + 1]
        i += 1
    raise ValueError('Unclosed declaration')

def prepare(output):
    pins = json.loads((HERE / 'source-pins.json').read_text(encoding='utf-8'))
    texts = {}
    for name, expected in pins['files'].items():
        data = (ROOT / 'Takupoke' / name).read_bytes()
        if sha(data) != expected: raise ValueError('Original source changed: ' + name)
        texts[name] = data.decode('utf-8', errors='strict')
    snippets = []
    def add(file, marker):
        value = block(texts[file], marker)
        snippets.append(dict(file=file, selector=marker, sha256=sha(value.encode()), bytes=len(value.encode())))
        return value
    bodies = [
        add('RecoveryModels.swift', 'enum RecoveryInputState:'),
        add('MaterialModels.swift', 'enum MaterialKind:'),
        add('PDFAnalysis.swift', 'struct PDFGlyph:'),
        add('PDFAnalysis.swift', 'struct PDFBox:'),
        add('PDFAnalysis.swift', 'struct PDFCellGeometryDiagnostic:'),
        add('PDFDiagnostics.swift', 'struct PDFDiagnosticSnapshot:'),
        add('PDFParseError.swift', 'struct PDFParseError:'),
        '@available(iOS 26.0, *)\n' + add('PDFRecoveryRecognition.swift', 'struct RecoveryRecognizedPage:'),
    ]
    # These namespace wrappers contain only the exact real declarations used by read/diagnostics.
    material = texts['MaterialLibrary.swift']
    constant = 'static let maximumBytes = 50 * 1024 * 1024'
    if material.count(constant) != 1: raise ValueError('Material limit declaration changed')
    bodies.append('final class MaterialLibrary {\n    ' + constant + '\n}')
    analysis = texts['PDFAnalysis.swift']
    version = 'static let parserVersion = 21'
    if analysis.count(version) != 1: raise ValueError('Parser version declaration changed')
    bodies.append('struct PDFAnalysis {\n    ' + version + '\n    ' + add('PDFAnalysis.swift', 'static func currentVersion(') + '\n}')
    read = add('PDFRecoveryRecognition.swift', 'static func read(')
    bodies.append('@available(iOS 26.0, *)\nenum PDFRecoveryRecognition {\n    ' + read + '\n}')
    generated = ('import Foundation\nimport Vision\nimport PDFKit\nimport UIKit\n' + '\n\n'.join(bodies) + '\n').encode()
    output.mkdir(parents=True, exist_ok=False)
    (output / 'OriginalAcquisition.swift').write_bytes(generated)
    receipt = dict(sourceCommit=pins['commit'], sourceFiles=pins['files'], selectors=snippets,
                   generatedSourceSHA256=sha(generated), readBodySHA256=sha(read.encode()),
                   scope='Source-extracted native .read acquisition measurement; namespace wrappers are not the full app; layouts is never called')
    (output / 'extraction.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    inputs = json.loads((HERE / 'inputs.json').read_text(encoding='utf-8'))
    assembler = HERE / 'original_assemble.py'
    if sha(assembler.read_bytes()) != inputs['assemblerSha256']: raise ValueError('Original assembler changed')
    spec = importlib.util.spec_from_file_location('original_assembler', assembler)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    for fixture in inputs['fixtures']:
        pages = []
        for page in fixture['pages']:
            path = HERE / 'inputs' / fixture['id'] / page['imageFile']
            if sha(path.read_bytes()) != page['imageSha256']: raise ValueError('Original pixel changed')
            width, height, _ = module.png_stream(path)
            if (width, height) != (page['width'], page['height']): raise ValueError('Original dimensions changed')
            pages.append(path)
        dest = output / (fixture['id'] + '.pdf')
        module.assemble(dest, pages)
        if sha(dest.read_bytes()) != fixture['pdfSha256']: raise ValueError('Original PDF changed')
    (output / 'inputs.json').write_bytes((HERE / 'inputs.json').read_bytes())
    print(json.dumps(receipt))

if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
