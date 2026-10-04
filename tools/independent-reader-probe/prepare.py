"""Copy exact production vector Reader/parser/recovery sources, without OCR."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '71d28af'
SOURCES = ['SchoolDate.swift','SchoolDataRetention.swift','TimetableLessonNames.swift',
    'ChangeAnalysis.swift','ChangeNormalizer.swift','ChangeNormalizer+Dates.swift',
    'PDFAnalysis.swift','PDFParseError.swift','PDFGrid.swift','PDFSchoolParser.swift',
    'PDFSchoolParser+Timetable.swift','PDFSchoolParser+Events.swift','PDFDiagnostics.swift',
    'PDFTextGeometry.swift','PDFUnicodeMap.swift','PDFDrawnTextReader.swift','PDFDrawnTextReader+Fonts.swift',
    'PDFPathReader.swift','PDFKitReader.swift','RecoveryModels.swift','RecoveryValidator.swift',
    'RecoveryEngine.swift','RecoveryStructure.swift','RecoveryDocumentBuilder.swift','RecoveryRasterGrid.swift',
    'RecoveryConversion.swift','SpecialSchedule.swift','SpecialScheduleParser.swift',
    'SpecialScheduleParser+Pages.swift','SpecialScheduleParser+Times.swift']
FILES = ['unlabeled.pdf','labeled-control.pdf','unlabeled-no-unused-font.pdf',
         'labeled-control-no-unused-font.pdf','parallel-mismatch.pdf','unreadable-body.pdf']

def sha(data): return hashlib.sha256(data).hexdigest()
def block(source, marker):
    start=source.index(marker); brace=source.index('{',start); depth=1; cursor=brace+1
    while depth:
        if source[cursor]=='{':depth+=1
        elif source[cursor]=='}':depth-=1
        cursor+=1
    return source[start:cursor]

def source_parameters():
    kind=block((ROOT/'Takupoke/MaterialModels.swift').read_text(),'enum MaterialKind:')
    maximum=re.search(r'^    static let maximumBytes = .+$',(ROOT/'Takupoke/MaterialLibrary.swift').read_text(),re.M)
    assert maximum and maximum.group().strip()=='static let maximumBytes = 50 * 1024 * 1024'
    times=normal_times((ROOT/'Takupoke/TimetableSchedule.swift').read_text())
    baseline=subprocess.check_output(['git','show',BASELINE+':Takupoke/TimetableSchedule.swift'],cwd=ROOT).decode()
    assert times==normal_times(baseline), 'Baseline public normalPeriodTimes changed'
    return ('import Foundation\n'+kind+'\nenum MaterialLibrary {\n'+maximum.group()+'\n}\n'+'enum TimetableSchedule {\n'+times+'\n}\n').encode()

def normal_times(source):
    declaration=re.search(r'^    static let normalPeriodTimes = \[\n.*?^    \]',source,re.M|re.S)
    assert declaration, 'Exact public normalPeriodTimes declaration missing'
    return declaration.group()

def prepare(output, fixtures, pins=None):
    assert output.parent.is_dir() and not output.exists()
    output.mkdir()
    if pins is None: pins=json.loads((ROOT/'tools/independent-wide-timetable/artifact-pins.json').read_text())
    manifest=json.loads((fixtures/'manifest.json').read_text())
    # Assertions/source provenance only; expected values never enter a source API.
    assert sha((fixtures/'expected.json').read_bytes())==manifest['expectedSha256']==pins['expectedSha256']
    inputs=[]
    for name in FILES:
        artifact=next(item for item in manifest['artifacts'] if item['file']==name)
        pinned=next(item for item in pins['artifacts'] if item['file']==name)
        assert artifact['sha256']==pinned['sha256'] and artifact['bytes']==pinned['bytes']
        data=(fixtures/name).read_bytes();assert sha(data)==artifact['sha256'] and len(data)==artifact['bytes']
        inputs.append({'file':name,'sha256':sha(data),'bytes':len(data)})
    (output/'native-inputs.json').write_text(json.dumps({'schema':1,'files':inputs},indent=2)+'\n')
    source_rows=[]
    parameters=source_parameters()
    for mode in ['baseline','fixed']:
        folder=output/mode;folder.mkdir()
        (folder/'SourceParameters.swift').write_bytes(parameters)
        for name in SOURCES:
            current=(ROOT/'Takupoke'/name).read_bytes()
            if mode=='baseline':
                data=subprocess.check_output(['git','show',BASELINE+':Takupoke/'+name],cwd=ROOT)
            else:data=current
            (folder/name).write_bytes(data)
            source_rows.append({'mode':mode,'path':'Takupoke/'+name,'sha256':sha(data),'source':'baseline71d28' if mode=='baseline' else 'exactCurrentSource'})
    receipt={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
        'baselineCommit':subprocess.check_output(['git','rev-parse',BASELINE],cwd=ROOT).decode().strip(),
        'sourceFiles':source_rows,'sourceParameterSHA256':sha(parameters),
        'sourceParameters':'Exact MaterialKind block, maximumBytes and normalPeriodTimes constants only; no Reader/parser/recovery substitutions',
        'normalPeriodTimes':{'source':'Takupoke/TimetableSchedule.swift','sourceSHA256':sha((ROOT/'Takupoke/TimetableSchedule.swift').read_bytes()),
            'declarationSHA256':sha(normal_times((ROOT/'Takupoke/TimetableSchedule.swift').read_text()).encode()),'baselineDeclarationIdentical':True},
        'generatedFixtureManifestSHA256':sha((fixtures/'manifest.json').read_bytes()),
        'scope':'Baseline Reader-only4 calls; fixed actualReader/Strict/completecapture/Builder/Rules/Validator/in-memoryAnalysis6 calls',
        'ocrRequests':0,'modelInvocations':0,'expectedUse':'Only after an actual Analysis is returned, for680literal assertions',
        'nativeInputs':inputs,'fixedRequests':6,'baselineRequests':4}
    (output/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':prepare(Path(sys.argv[1]),Path(sys.argv[2]))
