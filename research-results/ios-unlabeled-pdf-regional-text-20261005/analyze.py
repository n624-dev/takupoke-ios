"""Offline assertion only: actual raw observation/drawing position and pipeline outcomes."""
import collections,hashlib,json,sys
from pathlib import Path

def match(candidate,drawing):
    text=candidate.get('rawText','');pieces=candidate.get('characters',[])
    if ''.join(c.get('text','') for c in pieces)!=text:return []
    starts=[0]
    for c in pieces:starts.append(starts[-1]+len(c['text']))
    boundary={value:index for index,value in enumerate(starts)}
    needle=drawing['rawText'];cursor=0;hits=[]
    while needle and (found:=text.find(needle,cursor))>=0:
        cursor=found+1;end=found+len(needle)
        if found not in boundary or end not in boundary:continue
        chars=pieces[boundary[found]:boundary[end]]
        boxes=[dict(zip(['x','y','width','height'],c['originalPixelTopLeft'])) if c.get('originalPixelTopLeft') else None for c in chars]
        if not boxes or any(b is None for b in boxes):continue
        x=min(b['x'] for b in boxes);y=min(b['y'] for b in boxes)
        right=max(b['x']+b['width'] for b in boxes);bottom=max(b['y']+b['height'] for b in boxes)
        a,b,c,d=drawing['pixelPrintedBox'];inside=a<=x and b<=y and right<=c and bottom<=d
        same_cell=[]
        for char in pieces:
            box=dict(zip(['x','y','width','height'],char['originalPixelTopLeft'])) if char.get('originalPixelTopLeft') else None
            if box is not None and a<=box['x']+box['width']/2<=c and b<=box['y']+box['height']/2<=d:same_cell.append(char['text'])
        cell_literal=''.join(same_cell)==needle
        centered=a<=(x+right)/2<=c and b<=(y+bottom)/2<=d
        hits.append({'candidatePath':candidate['path'],'rawWholeCandidate':text,'wholeCandidateExact':text==needle,'confidence':candidate.get('confidence'),
                     'confidencePredicate':candidate.get('passesOriginalConfidencePredicate',False),'originalCharacterPredicates':all(c.get('originalLayoutsLocalRangePredicate',False) and c.get('inverseOriginalRangePredicate',False) for c in chars),'actualRegionProvenance':all(c.get('actualRegionRangeProvenancePredicate',False) for c in chars),
                     'sameCellCandidateTextExact':cell_literal,'nativeRangeUnion':[x,y,right-x,bottom-y],'nativeRangeFullyContainedInSourcePrintedCell':inside,'nativeRangeCenterInsideSourcePrintedCell':centered,
                     'scope':'Exact raw substring/native returned range union; source-generated cell containment is posthoc, not exact glyph ink/unique ownership'})
    return hits

def analyze(records,drawing):
    regions=[v for v in records if v['type']=='region']
    by={v['type']:v for v in records if v['type']!='region'}
    top1=[line['top1'] for region in regions for line in region.get('rawOCR',{}).get('lines',[]) if 'top1' in line]
    top5=[candidate for region in regions for line in region.get('rawOCR',{}).get('lines',[]) for candidate in line.get('top5',[])]
    matches=[{'id':d['id'],'sourceLiteral':d['rawText'],'sourcePrintedBox':d['pixelPrintedBox'],'sourceInkBox':d['sourceInkBox'],
      'top1Hits':[h for c in top1 for h in match(c,d)],'top5Hits':[h for c in top5 for h in match(c,d)]} for d in drawing['records']]
    def located(m,rank):return [h for h in m[rank+'Hits'] if h['nativeRangeFullyContainedInSourcePrintedCell'] and h['sameCellCandidateTextExact']]
    def centered(m,rank):return [h for h in m[rank+'Hits'] if h['nativeRangeCenterInsideSourcePrintedCell'] and h['sameCellCandidateTextExact']]
    groups={}
    for name,prefix in [('periods','period-'),('weekdays','day-'),('bodyComponents','body-'),('year','year'),('term','term'),('grade','grade'),('class','class'),('title','title')]:
        subset=[m for m in matches if m['id'].startswith(prefix)]
        groups[name]={'sourceCount':len(subset),'unconstrainedLiteralSubstringInventoryNotPositionEvidence':sum(any(m['sourceLiteral'] in c.get('rawText','') for c in top1) for m in subset),
          'top1LiteralRangeCenterInside':sum(bool(centered(m,'top1')) for m in subset),'top1LiteralRangeContained':sum(bool(located(m,'top1')) for m in subset),'top5LiteralRangeContained':sum(bool(located(m,'top5')) for m in subset),
          'top1ContainedPassingOriginalAndRegionGuards':sum(any(h['confidencePredicate'] and h['originalCharacterPredicates'] and h['actualRegionProvenance'] for h in located(m,'top1')) for m in subset)}
    body={m['id']:m for m in matches if m['id'].startswith('body-')}
    groups['bodyTuples']={'sourceCount':40,'top1AllThreeLiteralRangesContained':sum(all(located(body[f'body-{day}-{period}-{role}'],'top1') for role in ['subject','teacher','room']) for day in range(5) for period in range(1,9)),
      'top1AllThreeLiteralRangeCentersInside':sum(all(centered(body[f'body-{day}-{period}-{role}'],'top1') for role in ['subject','teacher','room']) for day in range(5) for period in range(1,9)),
      'top1AllThreeContainedPassingOriginalAndRegionGuards':sum(all(any(h['confidencePredicate'] and h['originalCharacterPredicates'] and h['actualRegionProvenance'] for h in located(body[f'body-{day}-{period}-{role}'],'top1')) for role in ['subject','teacher','room']) for day in range(5) for period in range(1,9)),
      'scope':'Posthoc raw source-position tuples, not Builder binding, Validator, Analysis, formal quality or blind role qualification.'}
    outcome=by.get('outcome',{})
    pipeline={key:outcome.get(key) for key in ['readerReturned','readerFailure','originalReaderCapture','expectedImageOnlyReaderRefusal','actualAppleOriginalRGBA_SHA256','actualAppleOriginalEqualsPinnedSourceRGBA','allOriginalAndRegionProvenanceGuardsPass','originalWholePageUncoveredInk','uniqueNativeCandidateRangeOwnership','originalInkDiagnosticError','builderReturned','engineState','engineErrors','validatorCanAdopt','validatorErrors','analysisReturned','failureStage','failure','sourceStateScope']}
    return {'pipeline':pipeline,'rawOCRCounts':{'regions':len(regions),'top1Candidates':len(top1),'orderedTop5Candidates':len(top5),'lowConfidenceTop1':sum(c.get('passesOriginalConfidencePredicate') is False for c in top1),
      'top1Characters':sum(len(c.get('characters',[])) for c in top1),'top1MissingRangeBoxes':sum(ch.get('missingBoundingBox') is True for c in top1 for ch in c.get('characters',[])),
      'top1LocalOriginalRangePredicateRejected':sum(ch.get('originalLayoutsLocalRangePredicate') is False for c in top1 for ch in c.get('characters',[])),
      'top1RegionProvenanceRejected':sum(ch.get('actualRegionRangeProvenancePredicate') is False for c in top1 for ch in c.get('characters',[]))},
      'regionAcquisition':[{'regionId':r.get('regionId'),'attempted':r.get('attempted'),'returned':r.get('returned'),'captureComplete':r.get('captureComplete'),'seconds':r.get('seconds'),'executionError':r.get('executionError'),'nativeLines':r.get('rawOCR',{}).get('nativeLineCount'),'omissions':r.get('rawOCR',{}).get('omissions')} for r in regions],
      'regionPlan':by.get('regionPlan'),'actualRecognitionSettings':by.get('environment'),'sourcePositionDiagnostic':groups,'drawingMatches':matches,'literalAssessment':by.get('literalAssessment'),'summary':by.get('summary'),
      'tableScope':'Ordinary Text API only; no native table/container hierarchy requested. Physical rails are measured original image evidence, not Vision table observations.',
      'formalQuality':'UNASSESSED','realSchoolPDFEndpoint':'UNASSESSED','expectedRoleScopesPassedToNativeOrBuilder':False}
if __name__=='__main__':
    records=[json.loads(line) for line in Path(sys.argv[1]).read_bytes().splitlines()]
    drawing=json.loads(Path(sys.argv[2]).read_text())
    value=analyze(records,drawing)
    Path(sys.argv[3]).write_text(json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
