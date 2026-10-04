"""Posthoc printed-cell evidence from frozen Fixture.swift coordinates, no OCR calls."""
import argparse
from collections import Counter
import json
from pathlib import Path
import analyze


def evidence(raw):
    page,oracle,summary=[json.loads(v) for v in raw.splitlines() if v.strip()]
    assert page['type']=='page' and oracle['type']=='oracle' and summary['type']=='summary'
    regions=list(analyze.text_regions(page['hierarchy']))
    global_regions=[r for r in regions if r['path'].count('.')==2 and r['path'].endswith('.document.text')]
    nested_regions=[r for r in regions if r not in global_regions]
    def hits(values,text,cell):
        out=[]
        for c in values:
            if c.get('rawText')!=text:continue
            chars=c.get('characters',[]);boxes=[v.get('pixelTopLeft') for v in chars]
            if not boxes or not all(isinstance(b,dict) for b in boxes):continue
            x=min(b['x'] for b in boxes);y=min(b['y'] for b in boxes)
            right=max(b['x']+b['width'] for b in boxes);bottom=max(b['y']+b['height'] for b in boxes)
            cx=(x+right)/2;cy=(y+bottom)/2
            if not(cell['x']<=cx<=cell['x']+cell['width'] and cell['y']<=cy<=cell['y']+cell['height']):continue
            out.append({'path':c['path'],'rawText':c['rawText'],'confidence':c['confidence'],
                        'passesOriginalConfidencePredicate':c['passesOriginalConfidencePredicate'],
                        'allOriginalCharacterPredicatesPass':all(v.get('originalLayoutsCharacterPredicate',False) for v in chars),
                        'nativeRangeUnionFullyContainedInPrintedCell':x>=cell['x'] and y>=cell['y'] and right<=cell['x']+cell['width'] and bottom<=cell['y']+cell['height'],
                        'nativeRangeUnionPixelTopLeft':{'x':x,'y':y,'width':right-x,'height':bottom-y}})
        return out
    periods=[]
    for i in range(8):
        # Literal frozen drawing constants x48/classWidth180/col216/y254/header52+54.
        # This is independent posthoc knowledge; none was passed to Vision.
        cell={'x':228+216*i,'y':306,'width':216,'height':54}
        row={'period':i+1,'expectedLiteral':str(i+1),'printedCell':cell}
        for name,rs in [('global',global_regions),('nested',nested_regions)]:
            for kind in ['lines','words']:
                for top in ['top1','top5']:row[name+'/'+kind+'/'+top]=hits(analyze.candidates(rs,kind,top),str(i+1),cell)
        periods.append(row)
    classes=[]
    for text,cell in [('2_XM',{'x':48,'y':360,'width':180,'height':175}),('3_ZQ',{'x':48,'y':535,'width':180,'height':175})]:
        row={'expectedLiteral':text,'printedCell':cell,'formalClassScope':'fictional recognition controls only; not supported canonical-class or formal timetable proof'}
        for name,rs in [('global',global_regions),('nested',nested_regions)]:
            for top in ['top1','top5']:row[name+'/'+top]=hits(analyze.candidates(rs,'lines',top),text,cell)
        classes.append(row)
    top1=analyze.candidates(global_regions,'lines','top1')
    return {'coordinateProvenance':'fde3e233 Fixture.swift frozen independent drawing constants, posthoc only',
      'periods':periods,'classes':classes,'periodGlobalTop1LiteralInPrintedCell':sum(bool(v['global/lines/top1']) for v in periods),
      'periodGlobalTop1RangeFullyContainedInPrintedCell':sum(any(h['nativeRangeUnionFullyContainedInPrintedCell'] for h in v['global/lines/top1']) for v in periods),
      'periodGlobalTop1OriginalGuardPass':sum(any(h['passesOriginalConfidencePredicate'] and h['allOriginalCharacterPredicatesPass'] for h in v['global/lines/top1']) for v in periods),
      'periodGlobalWordTop1LiteralInPrintedCell':sum(bool(v['global/words/top1']) for v in periods),
      'classGlobalTop1CompleteLiteralInPrintedCell':sum(bool(v['global/top1']) for v in classes),
      'classGlobalTop1CompleteLiteralOriginalGuardPass':sum(any(h['passesOriginalConfidencePredicate'] and h['allOriginalCharacterPredicatesPass'] for h in v['global/top1']) for v in classes),
      'globalTop1LineCount':len(top1),'globalLowConfidenceLineCount':sum(not c['passesOriginalConfidencePredicate'] for c in top1),
      'globalMissingCharacterRangeBoxLines':[{'path':c['path'],'rawText':c['rawText'],'missingCharacters':[v['text'] for v in c['characters'] if v.get('missingBoundingBox')]} for c in top1 if any(v.get('missingBoundingBox') for v in c['characters'])],
      'globalTop1LiteralInventory':[{'sourceId':v['id'],'sourceExactText':v['text'],'exactRawCandidateTextCount':sum(c['rawText']==v['text'] for c in top1),
                                   'metric':'full exact candidate text inventory only, no position assertion or whitespace repair'} for v in oracle['drawingRecords']],
      'wordAccessorStates':dict(Counter('nil' if r['wordsAccessorState']=='nil' else 'presentEmpty' if not r['words'] else 'presentNonempty' for r in regions)),
      'limitations':['Printed-cell range containment is not exact glyph extent or unique ink ownership','Narrow typographic drawing matches are separately retained; no failed match is equated with absent recognition','Full exact class values required; prefix 2_XM in misread 2_XMl is not accepted','Original layouts predicates are posthoc only; production layouts was not invoked','No inferred blanks, merged-cell expansion, alternate adoption, source correction or formal quality qualification']}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');p.add_argument('output');args=p.parse_args()
    raw=analyze.restore_envelope(Path(args.folder)/'selected-native-records.json')
    Path(args.output).write_text(json.dumps(evidence(raw),ensure_ascii=False,sort_keys=True,indent=2)+'\n')
