"""Posthoc comparison only: native representations and drawing text/position separately."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


def text_regions(value):
    if isinstance(value,dict):
        if 'nativeLineCount' in value and 'wordsAccessorState' in value:yield value
        for child in value.values():yield from text_regions(child)
    elif isinstance(value,list):
        for child in value:yield from text_regions(child)


def identity(candidate):
    # Remove ONLY parent path. Every confidence, character box, raw value and flag remains.
    return json.dumps({k:v for k,v in candidate.items() if k!='path'},sort_keys=True,ensure_ascii=False,separators=(',',':'))


def candidates(regions,kind,top):
    values=[]
    for region in regions:
        for line in region.get(kind) or []:
            cs=[line.get('top1')] if top=='top1' else line.get('top5',[])
            values.extend(c for c in cs if isinstance(c,dict))
    return values


def matching(candidate,expected):
    # UIKit drawn bounds are typographic, not ink ownership. Match center of the
    # native returned character-range union; do not clamp or repair native boxes.
    chars=candidate.get('characters',[])
    text=''.join(c.get('text','') for c in chars)
    token=expected['text'];hits=[];start=0
    boundaries={0:0};position=0
    for index,c in enumerate(chars):
        position+=len(c.get('text',''));boundaries[position]=index+1
    while True:
        offset=text.find(token,start)
        if offset<0:break
        end=offset+len(token)
        if offset not in boundaries or end not in boundaries:
            start=offset+1;continue
        selected=chars[boundaries[offset]:boundaries[end]]
        boxes=[v.get('pixelTopLeft') for v in selected]
        if all(isinstance(b,dict) for b in boxes) and boxes:
            x=min(b['x'] for b in boxes);y=min(b['y'] for b in boxes)
            right=max(b['x']+b['width'] for b in boxes);bottom=max(b['y']+b['height'] for b in boxes)
            drawn=expected['pixelTopLeft'];cx=(x+right)/2;cy=(y+bottom)/2
            centered=drawn['x']<=cx<=drawn['x']+drawn['width'] and drawn['y']<=cy<=drawn['y']+drawn['height']
            if centered:hits.append({'path':candidate['path'],'confidence':candidate.get('confidence'),'passesOriginalConfidencePredicate':candidate.get('passesOriginalConfidencePredicate'),
                'nativeRangeUnionPixelTopLeft':{'x':x,'y':y,'width':right-x,'height':bottom-y},'matchingMetric':'center of native returned range union inside source typographic drawing bounds; not exact glyph ink'})
        start=offset+1
    return hits


def analyze(raw,image_metadata):
    records=[json.loads(v) for v in raw.splitlines() if v.strip()]
    assert [v.get('type') for v in records]==['page','oracle','summary'],'Incomplete selected records; unassessed'
    page,oracle,summary=records
    result={'inputPNGPublished':False,'inputPixelVerificationScope':'See input-image-receipt.json; unpublished pixels cannot be independently verified from this text-only dataset',
            'imageSHA256':image_metadata['pngSHA256'],'summary':summary,'formalEvaluation':'unassessed','qualityQualification':False}
    if not page.get('serializationCompleted'):
        result['recognitionComparison']='unassessed';result['operationalError']=page.get('operationalError');return result
    hierarchy=page['hierarchy'];regions=list(text_regions(hierarchy))
    global_regions=[r for r in regions if r['path'].count('.')==2 and r['path'].endswith('.document.text')]
    nested_regions=[r for r in regions if r not in global_regions]
    result.update({'captureComplete':hierarchy['captureComplete'],'omissionCount':hierarchy['omissionCount'],'globalTextRegionCount':len(global_regions),'nestedTextRegionCount':len(nested_regions),
                   'wordAccessorStates':dict(Counter(r['wordsAccessorState'] for r in regions))})
    result['candidateComparisons']={}
    for kind in ['lines','words']:
        for top in ['top1','top5']:
            a=candidates(global_regions,kind,top);b=candidates(nested_regions,kind,top)
            known=set(map(identity,a));extra=[c for c in b if identity(c) not in known]
            result['candidateComparisons'][kind+'/'+top]={'globalEntries':len(a),'nestedEntries':len(b),'nestedEntriesAbsentFromGlobalFullIdentity':len(extra),'extra':extra,
                'identityScope':'only path removed; all native raw text/confidence/character-range geometry retained','wordSegmentationIsNotRecognitionImprovement':kind=='words'}
    result['drawingMatches']=[]
    for expected in oracle['drawingRecords']:
        row={'id':expected['id'],'expectedText':expected['text'],'sourceTypographicBounds':expected['pixelTopLeft']}
        for name,rs in [('global',global_regions),('nested',nested_regions)]:
            for kind in ['lines','words']:
                for top in ['top1','top5']:
                    row[name+'/'+kind+'/'+top]=[hit for c in candidates(rs,kind,top) for hit in matching(c,expected)]
        result['drawingMatches'].append(row)
    result['limitations']=['Posthoc drawing comparison only; expected records never passed to Vision','Range boxes may have word precision; no exact glyph extent or ink ownership proof','Absence under captured accessors/top5 does not establish absence from latent Vision recognition','No verified empty cells, Builder, Validator, formal timetable or model qualification']
    return result


def restore_envelope(path):
    import gzip
    import base64
    value=json.loads(Path(path).read_text())
    raw=gzip.decompress(base64.b64decode(value['gzipBase64'],validate=True))
    assert len(raw)==value['originalBytes'] and hashlib.sha256(raw).hexdigest()==value['originalSHA256']
    return raw


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder');p.add_argument('output');a=p.parse_args()
    folder=Path(a.folder)
    raw=restore_envelope(folder/'selected-native-records.json')
    image_metadata=json.loads((folder/'input-image-receipt.json').read_text())['imageMetadata']
    value=analyze(raw,image_metadata)
    Path(a.output).write_text(json.dumps(value,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
