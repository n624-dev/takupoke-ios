"""Offline assertion only: actual raw observation/drawing position and pipeline outcomes."""
import collections,hashlib,json,sys,base64,gzip
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
        boxes=[c.get('pixelTopLeft') for c in chars]
        if not boxes or any(b is None for b in boxes):continue
        x=min(b['x'] for b in boxes);y=min(b['y'] for b in boxes)
        right=max(b['x']+b['width'] for b in boxes);bottom=max(b['y']+b['height'] for b in boxes)
        a,b,c,d=drawing['pixelPrintedBox'];inside=a<=x and b<=y and right<=c and bottom<=d
        same_cell=[]
        for char in pieces:
            box=char.get('pixelTopLeft')
            if box is not None and a<=box['x']+box['width']/2<=c and b<=box['y']+box['height']/2<=d:same_cell.append(char['text'])
        cell_literal=''.join(same_cell)==needle
        centered=a<=(x+right)/2<=c and b<=(y+bottom)/2<=d
        hits.append({'candidatePath':candidate['path'],'rawWholeCandidate':text,'wholeCandidateExact':text==needle,'confidence':candidate.get('confidence'),
                     'confidencePredicate':candidate.get('passesOriginalConfidencePredicate',False),'originalCharacterPredicates':all(c.get('originalCharacterPredicate',False) for c in chars),
                     'sameCellCandidateTextExact':cell_literal,'nativeRangeUnion':[x,y,right-x,bottom-y],'nativeRangeFullyContainedInSourcePrintedCell':inside,'nativeRangeCenterInsideSourcePrintedCell':centered,
                     'scope':'Exact raw substring/native returned range union; source-generated cell containment is posthoc, not exact glyph ink/unique ownership'})
    return hits

def analyze(records):
    by={v['type']:v for v in records};page=by['page'];regions=page.get('rawOCR',{}).get('observations',[])
    top1=[line['top1'] for region in regions for line in region['lines']]
    top5=[candidate for region in regions for line in region['lines'] for candidate in line['top5']]
    drawings=by['drawing']['records'];matches=[]
    for drawing in drawings:
        matches.append({'id':drawing['id'],'sourceLiteral':drawing['rawText'],'sourcePrintedBox':drawing['pixelPrintedBox'],
          'top1Hits':[h for candidate in top1 for h in match(candidate,drawing)],'top5Hits':[h for candidate in top5 for h in match(candidate,drawing)]})
    def located(m,rank):return [h for h in m[rank+'Hits'] if h['nativeRangeFullyContainedInSourcePrintedCell'] and h['sameCellCandidateTextExact']]
    groups={}
    def centered(m,rank):return [h for h in m[rank+'Hits'] if h['nativeRangeCenterInsideSourcePrintedCell'] and h['sameCellCandidateTextExact']]
    for name,prefix in [('periods','period-'),('weekdays','weekday-'),('bodyComponents','body-')]:
        subset=[m for m in matches if m['id'].startswith(prefix)]
        groups[name]={'sourceCount':len(subset),'unconstrainedLiteralSubstringInventoryNotPositionEvidence':sum(any(m['sourceLiteral'] in c.get('rawText','') for c in top1) for m in subset),'top1LiteralRangeCenterInside':sum(bool(centered(m,'top1')) for m in subset),'top1LiteralRangeContained':sum(bool(located(m,'top1')) for m in subset),
          'top5LiteralRangeContained':sum(bool(located(m,'top5')) for m in subset),
          'top1ContainedPassingOriginalGuards':sum(any(h['confidencePredicate'] and h['originalCharacterPredicates'] for h in located(m,'top1')) for m in subset)}
    body={m['id']:m for m in matches if m['id'].startswith('body-')}
    groups['bodyTuples']={'sourceCount':40,'top1AllThreeLiteralRangesContained':sum(all(located(body[f'body-{day}-{period}-{row}'],'top1') for row in range(3)) for day in range(5) for period in range(1,9)),
      'top1AllThreeLiteralRangeCentersInside':sum(all(centered(body[f'body-{day}-{period}-{row}'],'top1') for row in range(3)) for day in range(5) for period in range(1,9)),
      'scope':'Posthoc raw three-components positioned in source generated rows, not Builder/Validator/Analysis or blind-role qualification'}
    guard={key:page.get(key) for key in ['requestAttempted','requestReturned','pureLayoutsReturned','builderReturned','analysisReturned','failureStage','failure','additionalGlobalInkDiagnostic','engineState','engineErrors','validatorCanAdopt','validatorErrors']}
    counts={'observations':len(regions),'globalLines':len(top1),'orderedTop5Candidates':len(top5),'nativeTableCount':sum(r.get('nativeTableCount',0) for r in regions),
      'lowConfidenceTop1':sum(not c.get('passesOriginalConfidencePredicate',False) for c in top1),
      'top1MissingRangeBoxes':sum(sum(bool(c.get('missingBoundingBox')) for c in v.get('characters',[])) for v in top1),
      'top1InvalidOriginalRangePredicate':sum(sum(c.get('originalCharacterPredicate') is False for c in v.get('characters',[])) for v in top1)}
    return {'pipeline':guard,'rawGlobalCounts':counts,'rawGlobalCaptureComplete':page.get('rawOCR',{}).get('captureComplete'),'captureOmissions':page.get('rawOCR',{}).get('omissions'),
      'sourcePositionDiagnostic':groups,'drawingMatches':matches,'literalAssessment':by['literalAssessment'],'summary':by['summary'],
      'tableScope':'Only native table count captured; table contents/nested words unassessed in this finite baseline, no extra request',
      'ordinaryPDFEndpoint':'UNASSESSED','formalStorageQuality':'UNASSESSED','expectedRoleScopesPassedToNativeOrBuilder':False}

if __name__=='__main__':
    envelope=json.loads(Path(sys.argv[1]).read_text());raw=gzip.decompress(base64.b64decode(envelope['compressedBase64'],validate=True))
    proof=envelope['provenance'];assert len(raw)==proof['selectedUTF8Bytes'] and hashlib.sha256(raw).hexdigest()==proof['selectedUTF8SHA256']
    assert b'losslessPNGBase64' not in raw
    records=[json.loads(line) for line in raw.splitlines()]
    assert [v['type'] for v in records]==['page','drawing','literalAssessment','summary']
    value=analyze(records)
    Path(sys.argv[2]).write_text(json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
