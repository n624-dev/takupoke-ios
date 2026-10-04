"""Offline exact text/range comparison; drawing evidence never enters native OCR."""
import argparse,base64,hashlib,json,math
from pathlib import Path
from PIL import Image

def digest(b): return hashlib.sha256(b).hexdigest()
def key(b): return tuple(b[k] for k in ['x','y','width','height'])
def utf16(s): return len(s.encode('utf-16-le'))//2

def compare(raw_path,input_path,draw_root,output):
 raw=raw_path.read_bytes(); records=[json.loads(v) for v in raw.splitlines() if v.strip()]
 pages=[v for v in records if v.get('type')=='page'];manifest=json.loads(input_path.read_text())
 expected=[(f['id'],p['page']) for f in manifest['fixtures'] for p in f['pages']]
 assert [(p['fixture'],p['page']) for p in pages]==expected
 assert len([r for r in records if r.get('type')=='summary'])==1
 summary=next(r for r in records if r.get('type')=='summary');assert summary['requestCount']==10
 env=next(r for r in records if r.get('type')=='environment')
 output.mkdir(parents=True,exist_ok=True)
 rows=[]; png_receipts=[]; page_rows=[]
 for page in pages:
  fid,n=page['fixture'],page['page']; fixture=next(f for f in manifest['fixtures'] if f['id']==fid)
  original=next(p for p in fixture['pages'] if p['page']==n)
  assert page['pdfSHA256']==fixture['pdfSha256']
  assert page['readReturned'] and page['serializationCompleted'] and page['diagnosticComplete']
  png=base64.b64decode(page['renderPNG']['data'],validate=True)
  assert len(png)==page['renderPNG']['bytes'] and digest(png)==page['renderPNG']['sha256']
  name=f'{fid}-page-{n}.png';(output/name).write_bytes(png)
  with Image.open(output/name) as image:
   image.load();assert image.size==(page['width'],page['height'])
  png_receipts.append({'fixture':fid,'page':n,'file':name,'sha256':digest(png),'bytes':len(png),'width':page['width'],'height':page['height']})
  sx,sy=page['width']/original['width'],page['height']/original['height']
  drawing=json.loads((draw_root/fid/'drawing-source.json').read_text());config=drawing['configuration']
  dpage=next(p for p in drawing['pages'] if p['page']==n)
  page_rows.append({'fixture':fid,'page':n,'nativeObservations':page['observations'],'rawTexts':[v.get('rawText') for v in page['lines']], 'confidencePredicatePass':page['originalLayoutsDiagnosticPredicatesPass'],'diagnosticFailures':page['diagnosticFailures']})
  for target in dpage['textsAndInk']:
   text=target['text']
   if not text: continue  # No OCR absence-to-empty claim.
   if text in [str(i) for i in range(1,9)] and target['y']==66:
    category='period'; digit=int(text);cell=[96+116*(digit-1),60,96+116*digit,90]
   elif text in config['classes']: category='class';cell=[0,90,96,90+config['row']]
   elif text in ['月','火','水','木','金']: category='weekday';cell=[96,30,212,60]
   elif text in config['values']: category='printedValue';cell=[96,90,212,90+config['row']]
   else: continue
   cell=[cell[0]*sx,cell[1]*sy,cell[2]*sx,cell[3]*sy]
   matches=[]
   for line in page['lines']:
    rawtext=line.get('rawText','');start=0
    while True:
     pos=rawtext.find(text,start)
     if pos<0: break
     start=pos+1;a=utf16(rawtext[:pos]);b=a+utf16(text)
     span=[c for c in line['characters'] if c['utf16Start']>=a and c['utf16End']<=b]
     boxes=[c['pixelTopLeft'] for c in span if c.get('finite') and 'pixelTopLeft' in c]
     if boxes:
      x=min(v['x'] for v in boxes);y=min(v['y'] for v in boxes);right=max(v['x']+v['width'] for v in boxes);bottom=max(v['y']+v['height'] for v in boxes)
      center=[(x+right)/2,(y+bottom)/2]
      located=cell[0]<=center[0]<cell[2] and cell[1]<=center[1]<cell[3]
      shared=any(c.get('text','').strip() and c.get('finite') and 'pixelTopLeft' in c and key(c['pixelTopLeft']) in {key(v) for v in boxes} for c in line['characters'] if c['utf16Start']<a or c['utf16End']>b)
      allboxes=len(boxes)==len(span) and bool(span)
      predicates=allboxes and all(c.get('originalLayoutsCharacterPredicate') for c in span)
      match={'nativeOrder':line['nativeOrder'],'rawText':rawtext,'utf16Start':a,'utf16End':b,'rangeBoxUnion':[x,y,right,bottom],'rangeBoxUnionCenterInPhysicalCell':located,'rangeBoxesSharedWithOtherNonspaceCharacters':shared,'allRangeBoxesReturned':allboxes,'passesOriginalConfidencePredicate':line['passesOriginalConfidencePredicate'],'rangePredicatesPass':predicates,'confidence':line['confidence']}
      matches.append(match)
   located=[v for v in matches if v['rangeBoxUnionCenterInPhysicalCell']]
   unshared=[v for v in located if v['allRangeBoxesReturned'] and not v['rangeBoxesSharedWithOtherNonspaceCharacters']]
   rows.append({'fixture':fid,'page':n,'category':category,'expectedPrintedText':text,'originalDrawingInkBBox':target['bbox'],'nativePhysicalCell':cell,'matches':matches,'rawExactSubstringExists':bool(matches),'exactRangeLocated':bool(located),'exactRangeLocatedUnshared':bool(unshared),'exactRangeLocatedUnsharedOriginalPredicatesPass':any(v['passesOriginalConfidencePredicate'] and v['rangePredicatesPass'] for v in unshared)})
 for row in rows:
  if row['category']!='period': continue
  native=next(v for v in png_receipts if v['fixture']==row['fixture'] and v['page']==row['page'])
  original=next(v for v in next(f for f in manifest['fixtures'] if f['id']==row['fixture'])['pages'] if v['page']==row['page'])
  sx,sy=native['width']/original['width'],native['height']/original['height'];b=row['originalDrawingInkBBox']
  crop=[math.floor(b[0]*sx),math.floor(b[1]*sy),math.ceil(b[2]*sx),math.ceil(b[3]*sy)]
  with Image.open(output/native['file']) as image:
   patch=image.convert('RGB').crop(crop);pixels=list(patch.getdata());dark=sum(max(rgb)<128 for rgb in pixels)
  row['nativeDrawingInkCropBounds']=crop;row['nativeDrawingInkDarkPixelsRGBChannelsAllBelow128']=dark
  row['nativeDrawingInkCropPixels']=len(pixels)
 counts={}
 for category in ['period','class','weekday','printedValue']:
  selected=[r for r in rows if r['category']==category]
  counts[category]={'expectedPrintedPositions':len(selected),**{k:sum(r[k] for r in selected) for k in ['rawExactSubstringExists','exactRangeLocated','exactRangeLocatedUnshared','exactRangeLocatedUnsharedOriginalPredicatesPass']}}
 periods=[r for r in rows if r['category']=='period']
 counts['periodByPrintedDigit']={str(i):{'expected':sum(r['expectedPrintedText']==str(i) for r in periods),'locatedUnshared':sum(r['expectedPrintedText']==str(i) and r['exactRangeLocatedUnshared'] for r in periods),'originalPredicatesPass':sum(r['expectedPrintedText']==str(i) and r['exactRangeLocatedUnsharedOriginalPredicatesPass'] for r in periods)} for i in range(1,9)}
 result={'scope':'Independent ordinary accurate text OCR, posthoc exact printed-text comparison only; no formal recovery quality or empty-cell proof','rawSHA256':digest(raw),'rawBytes':len(raw),'analysisScriptSHA256':digest(Path(__file__).read_bytes()),'nativeEnvironment':env,'nativeSummary':summary,'counts':counts,'nativeInkCounts':{'printedPeriodRegions':80,'positiveDarkPixelRegions':sum(r['nativeDrawingInkDarkPixelsRGBChannelsAllBelow128']>0 for r in periods),'period5Through8Regions':40,'positivePeriod5Through8DarkPixelRegions':sum(int(r['expectedPrintedText'])>=5 and r['nativeDrawingInkDarkPixelsRGBChannelsAllBelow128']>0 for r in periods),'rule':'Scale original drawing ink bbox to native dimensions, floor/ceil crop; all RGB channels <128. Positive pixels alone do not identify a character or prove an empty cell.'},'renderPNGs':png_receipts,'pageRows':page_rows,'printedTextRows':rows,'limits':['Raw Character-range API boxes are not precise glyph geometry. Unshared boxes only eliminate identical-box sharing ambiguity, not establish exact geometry.','Source image-to-native physical cells use actual width/height ratios; no box clipping or text normalization.','Previous document OCR run did not preserve its pixels; matching render recipe does not establish previous native byte identity.','Confidence from the two APIs is not presumed calibrated identically.','No rules/cells/semantic tuple binding, validator/manual adoption/last-good or fullformal evaluation executed.','Printed blank value is excluded; no missing observation proves EMPTY.','No latent-recognition/model-versus-render cause inference. PNGs allow separate inspection of actual rendered ink.']}
 (output/'derived-evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'rawSHA256':result['rawSHA256'],'counts':counts,'nativeSummary':summary,'PNGs':len(png_receipts)},ensure_ascii=False,indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('inputs',type=Path);p.add_argument('drawing_root',type=Path);p.add_argument('output',type=Path);a=p.parse_args();compare(a.raw,a.inputs,a.drawing_root,a.output)
