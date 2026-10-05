"""Pin f8 production and copy exact raster/conversion statement blocks; no native APIs on Linux."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
RUNTIME='f8b0ca4'
SOURCES=['SchoolDate.swift','SchoolDataRetention.swift','TimetableLessonNames.swift','ChangeAnalysis.swift','ChangeNormalizer.swift','ChangeNormalizer+Dates.swift',
 'PDFAnalysis.swift','PDFParseError.swift','PDFGrid.swift','PDFSchoolParser.swift','PDFSchoolParser+Timetable.swift','PDFSchoolParser+Events.swift','PDFDiagnostics.swift',
 'PDFTextGeometry.swift','PDFUnicodeMap.swift','PDFDrawnTextReader.swift','PDFDrawnTextReader+Fonts.swift','PDFPathReader.swift','PDFKitReader.swift',
 'RecoveryModels.swift','RecoveryValidator.swift','RecoveryEngine.swift','RecoveryStructure.swift','RecoveryDocumentBuilder.swift','RecoveryRasterGrid.swift',
 'RecoveryConversion.swift','SpecialSchedule.swift','SpecialScheduleParser.swift','SpecialScheduleParser+Pages.swift','SpecialScheduleParser+Times.swift']

def sha(data):return hashlib.sha256(data).hexdigest()

def block(source,marker):
    assert source.count(marker)==1
    start=source.index(marker);brace=source.index('{',start);depth=1;cursor=brace+1
    while depth:
        if source[cursor]=='{':depth+=1
        elif source[cursor]=='}':depth-=1
        cursor+=1
    return source[start:cursor]

def pure_layouts(source):
    method=block(source,'    static func layouts(')
    start=method.index('            var rgba =')
    native=method.index('            let observations = try await RecognizeDocumentsRequest().perform(on:cg)')
    raster=method[start:native]
    suffix_start=method.index('            var glyphs =',native)
    append_end=method.index('\n        }\n        return output',suffix_start)
    suffix=method[suffix_start:append_end]
    assert raster.count('RecoveryRasterGrid.fromRGBA')==1 and suffix.count('candidate.confidence >= 0.85')==1
    assert 'RecognizeDocumentsRequest' not in raster+suffix
    shell='''import Foundation
import UIKit
import Vision
@available(iOS 26.0, *)
enum ProductionPureLayouts {
    struct LayoutPage { var page:Int; var layout:PDFPageLayout; var raster:RecoveryRasterGrid }
    static func raster(_ cg:CGImage,check:() throws -> Void) throws -> RecoveryRasterGrid {
'''+raster+'''        return raster
    }
    static func convert(_ cg:CGImage,observations:[DocumentObservation],raster:RecoveryRasterGrid,check:() throws -> Void) throws -> LayoutPage {
        let index=0
        var output=[LayoutPage]()
'''+suffix+'''
        guard output.count==1 else { throw PDFParseError(code:.storage) }
        return output[0]
    }
}
'''
    return shell.encode(),raster.encode(),suffix.encode()

def parameters():
    kind=block((ROOT/'Takupoke/MaterialModels.swift').read_text(),'enum MaterialKind:')
    maximum=re.search(r'^    static let maximumBytes = .+$',(ROOT/'Takupoke/MaterialLibrary.swift').read_text(),re.M).group()
    assert maximum.strip()=='static let maximumBytes = 50 * 1024 * 1024'
    times=re.search(r'^    static let normalPeriodTimes = \[\n.*?^    \]',(ROOT/'Takupoke/TimetableSchedule.swift').read_text(),re.M|re.S).group()
    return ('import Foundation\n'+kind+'\nenum MaterialLibrary {\n'+maximum+'\n}\nenum TimetableSchedule {\n'+times+'\n}\n').encode()

def prepare(output):
    assert output.parent.is_dir() and not output.exists();output.mkdir()
    pins=json.loads((HERE/'fixture-pins.json').read_text())
    for name,digest in pins['files'].items():assert sha((HERE/name).read_bytes())==digest
    rows=[]
    for name in SOURCES+['PDFRecoveryRecognition.swift','MaterialModels.swift','MaterialLibrary.swift','TimetableSchedule.swift']:
        current=(ROOT/'Takupoke'/name).read_bytes()
        original=subprocess.check_output(['git','show',RUNTIME+':Takupoke/'+name],cwd=ROOT)
        assert current==original,'Immutable f8 baseline differs: '+name
        rows.append({'path':'Takupoke/'+name,'sha256':sha(current),'byteExactF8':True})
        if name in SOURCES:(output/name).write_bytes(current)
    original=(ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text()
    pure,raster,suffix=pure_layouts(original);(output/'ProductionPureLayouts.swift').write_bytes(pure)
    param=parameters();(output/'SourceParameters.swift').write_bytes(param)
    receipt={'runtimeSourceCommit':subprocess.check_output(['git','rev-parse',RUNTIME],cwd=ROOT).decode().strip(),'sourceFiles':rows,
      'exactOriginalStatementBlocks':{'rasterBytes':len(raster),'rasterSHA256':sha(raster),'observationsToLayoutBytes':len(suffix),'observationsToLayoutSHA256':sha(suffix)},
      'generatedWrapperSHA256':sha(pure),'sourceParametersSHA256':sha(param),'fixturePins':pins,
      'wrapperScope':'Method-boundary containers only. Exact f8 RGBA/raster and observation-to-glyph/rules/prepared-raster statements are retained without replacement.',
      'oneNativeRequest':'External default Document request only; extraction contains no request/PDF render call','runtimeSourceProductionPatchMixedIn':False}
    (output/'source-receipt.json').write_text(json.dumps(receipt,sort_keys=True,indent=2)+'\n')

if __name__=='__main__':prepare(Path(sys.argv[1]))
