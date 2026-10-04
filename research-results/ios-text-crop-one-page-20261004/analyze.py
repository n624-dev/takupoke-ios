"""Offline component evidence: verify lossless cropping, offsets and eight source positions."""
import argparse,base64,hashlib,io,json
from pathlib import Path
from PIL import Image

def digest(b):return hashlib.sha256(b).hexdigest()
def boxkey(b):return tuple(b[k] for k in ['x','y','width','height'])
def compare(raw_path,previous_path,input_path,drawing_path,output):
 raw=raw_path.read_bytes();records=[json.loads(v) for v in raw.splitlines() if v.strip()];env=next(r for r in records if r.get('type')=='environment');regions=[r for r in records if r.get('type')=='region'];summary=next(r for r in records if r.get('type')=='summary')
 assert [(r['region'],r['offsetX'],r['cropWidth']) for r in regions]==[('left',0,508),('right',476,508)]
 assert summary['plannedRegions']==2 and summary['requestCount']==2 and summary['readReturnedRegions']==2 and summary['diagnosticCompletedRegions']==2
 output.mkdir(parents=True,exist_ok=True)
 def decode(record,name):
  data=base64.b64decode(record['data'],validate=True);assert len(data)==record['bytes'] and digest(data)==record['sha256'];(output/name).write_bytes(data)
  with Image.open(io.BytesIO(data)) as im:im.load();rgba=im.convert('RGBA')
  return data,rgba
 fullbytes,full=decode(env['originalPNG'],'original.png');assert full.size==(984,197)
 previous=previous_path.read_bytes();previous_records=[json.loads(v) for v in previous.splitlines() if v.strip()];prior=next(r for r in previous_records if r.get('type')=='page' and r['fixture']==env['fixture'] and r['page']==1)
 priorPNG=base64.b64decode(prior['renderPNG']['data'],validate=True)
 assert digest(priorPNG)==prior['renderPNG']['sha256']
 manifest=json.loads(input_path.read_text());fixture=next(f for f in manifest['fixtures'] if f['id']==env['fixture']);source_page=fixture['pages'][0]
 assert fixture['pdfSha256']==env['pdfSHA256']
 sx,sy=full.width/source_page['width'],full.height/source_page['height'];drawing=json.loads(drawing_path.read_text());targets=[t for t in drawing['pages'][0]['textsAndInk'] if t['y']==66 and t['text'] in [str(i) for i in range(1,9)]];assert len(targets)==8
 region_receipts=[];all_lines=[]
 for region in regions:
  assert region['readReturned'] and region['diagnosticComplete'] and region['serializationCompleted']
  data,crop=decode(region['cropPNG'],region['region']+'.png');x=region['offsetX'];assert crop.size==(region['cropWidth'],region['cropHeight'])
  pixel_equal=crop.tobytes()==full.crop((x,0,x+crop.width,crop.height)).tobytes();assert pixel_equal
  for line in region['lines']:
   for char in line.get('characters',[]):
    if char.get('finite'):
     a,b=char['cropPixelTopLeft'],char['originalPixelTopLeft'];assert b['x']==a['x']+x and all(b[k]==a[k] for k in ['y','width','height'])
   all_lines.append({'region':region['region'],**line})
  region_receipts.append({'region':region['region'],'offsetX':x,'metadata':region['cropImage'],'PNGBytes':len(data),'PNGHash':digest(data),'RGBAEqualsOriginalPixelSlice':pixel_equal,'rawTexts':[l.get('rawText') for l in region['lines']],'allOriginalPredicatesPass':region['originalLayoutsDiagnosticPredicatesPass'],'diagnosticFailures':region['diagnosticFailures']})
 rows=[]
 for target in targets:
  period=int(target['text']);cell=[(96+116*(period-1))*sx,60*sy,(96+116*period)*sx,90*sy];ink=[target['bbox'][0]*sx,target['bbox'][1]*sy,target['bbox'][2]*sx,target['bbox'][3]*sy];matches=[]
  for line in all_lines:
   for char in line.get('characters',[]):
    if char.get('text')!=str(period) or not char.get('finite'):continue
    b=char['originalPixelTopLeft'];cx=b['x']+b['width']/2;cy=b['y']+b['height']/2
    if not(cell[0]<=cx<cell[2] and cell[1]<=cy<cell[3]):continue
    shared=any(c is not char and c.get('text','').strip() and c.get('finite') and boxkey(c['originalPixelTopLeft'])==boxkey(b) for c in line['characters'])
    overlap=min(b['x']+b['width'],ink[2])>max(b['x'],ink[0]) and min(b['y']+b['height'],ink[3])>max(b['y'],ink[1])
    matches.append({'region':line['region'],'nativeOrder':line['nativeOrder'],'rawText':line['rawText'],'rawCharacter':char['text'],'confidence':line['confidence'],'originalPixelBox':b,'boxSharedWithOtherNonspaceCharacters':shared,'boxOverlapsOriginalDrawingInkBBox':overlap,'passesOriginalConfidencePredicate':line['passesOriginalConfidencePredicate'],'passesOriginalBoxPredicate':char['originalLayoutsCharacterPredicate'],'cropLocalPredicate':char['cropLocalCharacterPredicate'],'nativeRangeBoxFullyContainedInPrintedCell':cell[0]<=b['x'] and cell[1]<=b['y'] and b['x']+b['width']<=cell[2] and b['y']+b['height']<=cell[3]})
  unshared=[m for m in matches if not m['boxSharedWithOtherNonspaceCharacters']]
  old=[c for l in prior['lines'] for c in l['characters'] if c.get('text')==str(period) and c.get('finite') and cell[0]<=c['pixelTopLeft']['x']+c['pixelTopLeft']['width']/2<cell[2] and cell[1]<=c['pixelTopLeft']['y']+c['pixelTopLeft']['height']/2<cell[3]]
  rows.append({'period':period,'expectedPrintedText':str(period),'originalPhysicalCell':cell,'originalDrawingInkBBox':target['bbox'],'nativeDrawingInkBBox':ink,'positionMatches':matches,'locatedUnshared':bool(unshared),'locatedUnsharedOriginalPredicatesPass':any(m['passesOriginalConfidencePredicate'] and m['passesOriginalBoxPredicate'] for m in unshared),'locatedUnsharedInkBBoxOverlap':any(m['boxOverlapsOriginalDrawingInkBBox'] for m in unshared),'locatedUnsharedFullyContainedInPrintedCell':any(m['nativeRangeBoxFullyContainedInPrintedCell'] for m in unshared),'priorFullPageLocated':bool(old)})
 result={'scope':'Independent one-page two-region component diagnostic; no full-page rerun or formal quality assessment','rawSHA256':digest(raw),'rawBytes':len(raw),'analysisScriptSHA256':digest(Path(__file__).read_bytes()),'nativeEnvironment':{k:v for k,v in env.items() if k!='originalPNG'},'nativeSummary':summary,'originalPNG':{'sha256':digest(fullbytes),'bytes':len(fullbytes),'RGBAWidth':full.width,'RGBAHeight':full.height,'previousFullPagePNGByteEqual':fullbytes==priorPNG,'previousPageOneRecordSHA256':digest(previous)},'regions':region_receipts,'periodPositions':rows,'counts':{'expectedPositions':8,'locatedUnshared':sum(r['locatedUnshared'] for r in rows),'locatedUnsharedOriginalPredicatesPass':sum(r['locatedUnsharedOriginalPredicatesPass'] for r in rows),'locatedUnsharedInkBBoxOverlap':sum(r['locatedUnsharedInkBBoxOverlap'] for r in rows),'locatedUnsharedFullyContainedInPrintedCell':sum(r['locatedUnsharedFullyContainedInPrintedCell'] for r in rows),'positionRule':'Native range box center in original physical header cell; full containment and drawing ink overlap are separate metrics','priorFullPageLocated':sum(r['priorFullPageLocated'] for r in rows),'period5Through8LocatedUnshared':sum(r['period']>=5 and r['locatedUnshared'] for r in rows)},'limits':['Character-range boxes are native API range responses, not precise glyph extent or unique ownership proof.','Original physical cells/drawing evidence are posthoc only; none entered native requests.','Pixel equality confirms lossless crops of this run; PNG equality compares saved full-page encoding, not unsaved framework intermediate tensors.','No framework-internal model/detector/stride/ROI cause attribution.','No empty states, period filling, app layouts/rules/validator/tuple binding/adoption/last-good data or physical iPhone/fullformal quality assessment.','All raw observations from both overlapping regions remain separately identified; no merge or deduplication changes source.']}
 (output/'derived-evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'rawSHA256':result['rawSHA256'],'counts':result['counts'],'PNGByteEqual':result['originalPNG']['previousFullPagePNGByteEqual'],'regionTexts':[(r['region'],r['rawTexts']) for r in region_receipts]},ensure_ascii=False,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('previous',type=Path);p.add_argument('inputs',type=Path);p.add_argument('drawing',type=Path);p.add_argument('output',type=Path);a=p.parse_args();compare(a.raw,a.previous,a.inputs,a.drawing,a.output)
