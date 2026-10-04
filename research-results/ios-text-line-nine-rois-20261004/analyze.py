"""Posthoc fictional physical-position evidence; never imported by the native probe."""
import base64, hashlib, io, json, sys
from pathlib import Path
from PIL import Image

def sha(data): return hashlib.sha256(data).hexdigest()
def bounds(box): return [box['x'],box['y'],box['x']+box['width'],box['y']+box['height']]
def center_in(box, cell):
    x,y,r,b=bounds(box);return cell[0]<=(x+r)/2<cell[2] and cell[1]<=(y+b)/2<cell[3]
def contains(cell, box):
    x,y,r,b=bounds(box);return x>=cell[0] and y>=cell[1] and r<=cell[2] and b<=cell[3]
def overlap(a,b):return max(a[0],b[0])<min(a[2],b[2]) and max(a[1],b[1])<min(a[3],b[3])
def raw_normal(text):return ''.join(text.split())
def analyze(raw_path,prior_folder,manifest_path,output):
    raw=raw_path.read_bytes();records=[json.loads(line) for line in raw.splitlines() if line.strip()]
    env=next(r for r in records if r['type']=='environment');regions=[r for r in records if r['type']=='region'];summary=next(r for r in records if r['type']=='summary')
    manifest=json.loads(manifest_path.read_text());assert len(regions)==summary['requestCount']==manifest['requestCount']==9
    assert summary['plannedRegions']==9
    assert [r['region'] for r in regions]==[r['id'] for r in manifest['rois']]
    output.mkdir(parents=True,exist_ok=True);images=output/'native-render';images.mkdir(exist_ok=True)
    def image(record,name):
        data=base64.b64decode(record['data'],validate=True);assert len(data)==record['bytes'] and sha(data)==record['sha256'];(images/name).write_bytes(data)
        with Image.open(io.BytesIO(data)) as pic:pic.load();rgba=pic.convert('RGBA')
        return data,rgba
    original_bytes,original=image(env['originalPNG'],'original.png')
    assert original_bytes==(prior_folder/'native-render/original.png').read_bytes()
    assert sha(original.tobytes())==manifest['originalRGBA_SHA256']==env['originalRGBA_SHA256']
    prior=[json.loads(line) for line in (prior_folder/'native-raw.jsonl').read_bytes().splitlines()]
    old_regions=[r for r in prior if r['type']=='region'];prior_lines=[{'region':r['region'],**line} for r in old_regions for line in r['lines']]
    page_records=[json.loads(line) for line in (prior_folder/'previous-page-one.jsonl').read_bytes().splitlines()]
    whole=next(r for r in page_records if r.get('type')=='page')
    whole_lines=[]
    for line in whole['lines']:
        value={'region':'whole-page',**line};value['observationBox']={'originalPixelTopLeft':line['observationBox']['pixelTopLeft']}
        value['characters']=[dict(char,originalPixelTopLeft=char['pixelTopLeft']) if char.get('finite') else char for char in line['characters']]
        whole_lines.append(value)
    input_manifest=json.loads((prior_folder/'input-manifest.json').read_text());fixture=next(f for f in input_manifest['fixtures'] if f['id']==env['fixture']);page=fixture['pages'][0]
    sx,sy=original.width/page['width'],original.height/page['height']
    drawing=json.loads((prior_folder/'drawing-source.json').read_text())['pages'][0]['textsAndInk']
    def scaled(box):return [box[0]*sx,box[1]*sy,box[2]*sx,box[3]*sy]
    targets=[]
    for text,cell in [('2027年度 前期',[0,0,125,30]),('時間割',[200,0,290,30]),('月',[96,30,1025,60]),('5_ES',[0,90,96,166])]:
        target=next(t for t in drawing if t['text']==text);targets.append({'printed':text,'physicalRegion':scaled(cell),'drawingInkBBox':scaled(target['bbox'])})
    for period in range(1,9):
        target=next(t for t in drawing if t['text']==str(period) and t['y']==66)
        targets.append({'printed':str(period),'physicalRegion':scaled([96+116*(period-1),60,96+116*period,90]),'drawingInkBBox':scaled(target['bbox'])})
    def matches(target,lines):
        found=[]
        for line in lines:
            if raw_normal(line.get('rawText',''))!=raw_normal(target['printed']):continue
            box=line['observationBox']['originalPixelTopLeft']
            chars=[c for c in line['characters'] if c.get('text','').strip()]
            center=center_in(box,target['physicalRegion'])
            found.append({'region':line['region'],'nativeOrder':line['nativeOrder'],'rawText':line['rawText'],
                'confidence':line['confidence'],'literalUTF8TextMatch':line['rawText']==target['printed'],'whitespaceRemovedComparisonMatch':True,'observationCenterInPrintedRegion':center,
                'observationFullyContainedInPrintedRegion':contains(target['physicalRegion'],box),
                'observationOverlapsDrawingInkBBox':overlap(bounds(box),target['drawingInkBBox']),
                'allNativeCharacterRangeCentersInPrintedRegion':bool(chars) and all(c.get('finite') and center_in(c['originalPixelTopLeft'],target['physicalRegion']) for c in chars),
                'allOriginalCharacterPredicatesPass':bool(chars) and all(c.get('originalLayoutsCharacterPredicate',False) for c in chars),
                'passesConfidenceGuard':bool(line.get('passesOriginalConfidencePredicate')),
                'originalObservationPixelBox':box})
        return found
    # Range predicate is calculated independently from unmodified original coords.
    def guard_chars(lines):
        for line in lines:
            for char in line['characters']:
                if char.get('finite'):
                    b=char['originalPixelTopLeft'];char['originalLayoutsCharacterPredicate']=b['width']>0 and b['height']>0 and b['x']>=0 and b['y']>=0
    guard_chars(prior_lines);guard_chars(whole_lines)
    new_lines=[];receipts=[]
    for record,roi in zip(regions,manifest['rois']):
        assert record.get('cropPNG'), 'Crop pixel record required for this comparison'
        assert (record['offsetX'],record['offsetY'],record['cropWidth'],record['cropHeight'])==(roi['x'],roi['y'],roi['width'],roi['height'])
        data,crop=image(record['cropPNG'],roi['id']+'.png');expected=original.crop((roi['x'],roi['y'],roi['x']+roi['width'],roi['y']+roi['height']))
        assert crop.size==expected.size and crop.tobytes()==expected.tobytes()
        for line in record.get('lines',[]):
            for item in [line['observationBox'],*line['characters']]:
                if not item.get('finite'):continue
                local,global_box=item['cropPixelTopLeft'],item['originalPixelTopLeft']
                assert global_box['x']==local['x']+roi['x'] and global_box['y']==local['y']+roi['y']
                assert global_box['width']==local['width'] and global_box['height']==local['height']
            new_lines.append({'region':record['region'],**line})
        roi_bounds=[roi['x'],roi['y'],roi['x']+roi['width'],roi['y']+roi['height']]
        receipts.append({'id':roi['id'],'originalPixelROI':roi_bounds,'nativeCGImage':record['cropImage'],'pngSHA256':sha(data),'RGBAEqualsOriginalPixelSlice':True,
            'overlappingPrintedInk':[t['printed'] for t in targets if overlap(roi_bounds,t['drawingInkBBox'])],
            'capturedSourceRawText':next(l['rawText'] for l in prior_lines if l['region']==roi['sourceRegion'] and l['nativeOrder']==roi['sourceNativeOrder']),
            'newRawTexts':[l['rawText'] for l in record.get('lines',[])], 'newConfidences':[l['confidence'] for l in record.get('lines',[])],
            'readReturned':record.get('readReturned',False),'observations':record.get('observations'),'operationalError':record.get('operationalError'),'diagnosticFailures':record.get('diagnosticFailures',[]),'allOriginalPredicatesPass':record.get('originalLayoutsDiagnosticPredicatesPass',False)})
    guard_chars(new_lines)
    rows=[]
    for target in targets:
        comparisons={phase:matches(target,lines) for phase,lines in [('wholePage',whole_lines),('halfPage',prior_lines),('lineROI',new_lines)]}
        rows.append({**target,**comparisons,'lineROIWasRequested':any(overlap(receipt['originalPixelROI'],target['drawingInkBBox']) for receipt in receipts)})
    result={'scope':'Nine fixed low-confidence line ROIs, first fictional literal page; independent posthoc physical-position comparison only',
        'rawSHA256':sha(raw),'rawBytes':len(raw),'nativeEnvironment':{k:v for k,v in env.items() if k!='originalPNG'},'nativeSummary':summary,
        'originalPNGByteEqualToCaptured':True,'originalRGBA_SHA256':sha(original.tobytes()),'ROIs':receipts,'printedHeaders':rows,
        'limits':['Whitespace removal is explicitly separate from original raw UTF8; no text normalization entered OCR.',
                  'Observation/range-box centers, whole-region containment and ink overlap are diagnostics, not precise glyph extent or ownership proof.',
                  'Unrequested high-confidence half-page observations are not combined into a new formal source.',
                  'No cell tuples, empty states, source adapter, adoption, physical-device quality or model qualification.']}
    counts={}
    for phase in ['wholePage','halfPage','lineROI']:
        counts[phase]={'printedHeaderPositions':len(targets),
            'rawTextInventoryMatch':sum(bool(row[phase]) for row in rows),
            'literalUTF8TextMatch':sum(any(m['literalUTF8TextMatch'] for m in row[phase]) for row in rows),
            'matchingObservationCenterInPhysicalRegion':sum(any(m['observationCenterInPrintedRegion'] for m in row[phase]) for row in rows),
            'matchingTextAndRangeCentersAndGuard':sum(any(m['observationCenterInPrintedRegion'] and m['allNativeCharacterRangeCentersInPrintedRegion'] and m['allOriginalCharacterPredicatesPass'] and m['passesConfidenceGuard'] for m in row[phase]) for row in rows)}
    selected=[row for row in rows if row['lineROIWasRequested']]
    result['selectedROIHeaderPositions']=len(selected)
    result['unrequestedPrintedHeaders']=[row['printed'] for row in rows if not row['lineROIWasRequested']]
    result['selectedPositionCounts']={phase:{
        'rawTextInventoryMatch':sum(bool(row[phase]) for row in selected),
        'matchingObservationCenterInPhysicalRegion':sum(any(m['observationCenterInPrintedRegion'] for m in row[phase]) for row in selected),
        'matchingTextAndRangeCentersAndGuard':sum(any(m['observationCenterInPrintedRegion'] and m['allNativeCharacterRangeCentersInPrintedRegion'] and m['allOriginalCharacterPredicatesPass'] and m['passesConfidenceGuard'] for m in row[phase]) for row in selected)} for phase in ['wholePage','halfPage','lineROI']}
    result['counts']=counts
    (output/'derived-evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'counts':counts,'ROIs':[{k:v for k,v in r.items() if k not in ['nativeCGImage','pngSHA256']} for r in receipts]},ensure_ascii=False,indent=2))

if __name__=='__main__':analyze(Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]),Path(sys.argv[4]))
