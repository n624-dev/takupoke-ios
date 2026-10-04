"""Post-observation evidence only. Never imported by the native helper."""
from pathlib import Path
import base64,hashlib,json,struct,unicodedata,zlib
ROOT=Path(__file__).resolve().parent
obligations=json.loads((ROOT/'original-source-obligations.json').read_text(encoding='utf-8'))
wrapper=next(v for v in json.loads((ROOT/'raw-evidence.json').read_text(encoding='utf-8'))['files'] if v['name'].endswith('raw.jsonl'))
compressed=base64.b64decode(wrapper['data'],validate=True)
assert hashlib.sha256(compressed).hexdigest()==wrapper['compressedSHA256']
raw=zlib.decompress(compressed)
assert len(raw)==wrapper['uncompressedBytes'] and hashlib.sha256(raw).hexdigest()==wrapper['sha256']
records=[json.loads(v) for v in raw.splitlines() if v.strip()]
pages=[v for v in records if v.get('type')=='page']
summary={'plannedPages':10,'recordedPages':len(pages),'readReturnedPages':sum(bool(v.get('readReturned')) for v in pages),'serializationCompletedPages':sum(bool(v.get('serializationCompleted')) for v in pages),'selectedHierarchyCaptureCompletePages':sum(bool(v.get('hierarchyCaptureComplete')) for v in pages),'operationalErrors':sum('operationalError' in v for v in pages),'formalAssessed':0}
page_rows=[];matrix=[]
for page in pages:
 h=page.get('hierarchy',{});nodes=[];lines=[]
 def visit(v):
  if isinstance(v,dict):
   if 'nativeLineCount' in v and 'transcript' in v:nodes.append(v)
   if 'top1VsTop5FirstTextConfidenceAgreement' in v:lines.append(v)
   for key,child in v.items():
    if key not in ('omissions',):visit(child)
  elif isinstance(v,list):
   for child in v:visit(child)
 visit(h.get('roots',[]))
 originals={f"observations[{v['observation']}].document.text.lines[{v['line']}]":v for v in page.get('lines',[])}
 original_agreements=[]
 for line in lines:
  if line['path'] in originals:
   o=originals[line['path']];n=line.get('top1')
   equal=(o.get('rawText')==n.get('rawText') and o.get('confidence')==n.get('confidence')) if isinstance(n,dict) else bool(o.get('candidateMissing'))
   original_agreements.append({'path':line['path'],'textConfidenceEqual':equal})
 selected=[]
 for line in lines:
  candidates=[('top1',None,line.get('top1'))]+[('top5',i,c) for i,c in enumerate(line.get('top5',[]))]
  for accessor,rank,c in candidates:
   if not isinstance(c,dict):continue
   for ch in c.get('characters',[]):
    b=ch.get('pixelTopLeft')
    if not b or not ch.get('finite'):continue
    selected.append({'containerPath':line['path'],'candidatePath':c.get('path'),'accessor':accessor,'rank':rank,'candidateRawText':c.get('rawText'),'candidateConfidence':c.get('confidence'),'candidateConfidencePass':c.get('passesOriginalConfidencePredicate'),'rawCharacter':ch.get('text'),'characterIndex':ch.get('nativeCharacterIndex'),'pixelTopLeft':b,'originalBoxPredicate':ch.get('originalLayoutsCharacterPredicate')})
 w,he=obligations[page['fixture']]['originalPNGDimensions']
 draw=obligations[page['fixture']]['drawingSource'];printed=draw['pages'][page['page']-1]['textsAndInk']
 for period in range(1,9):
  literal=[v for v in printed if v.get('text')==str(period) and v.get('y')==66]
  assert len(literal)==1
  # Fixed original ruled header cell, from frozen generator: left96/cell116, y60..90.
  bounds={'x':96+116*(period-1),'y':60,'width':116,'height':30}
  matches=[];all_here=[]
  for c in selected:
   b=c['pixelTopLeft'];x=(b['x']+b['width']/2)*w/page['width'];y=(b['y']+b['height']/2)*he/page['height']
   if bounds['x']<=x<bounds['x']+bounds['width'] and bounds['y']<=y<bounds['y']+bounds['height']:
    entry={**c,'originalPixelCenter':{'x':x,'y':y}}
    all_here.append(entry)
    if unicodedata.normalize('NFKC',c['rawCharacter'])==str(period):matches.append(entry)
  transcript_occurrences=[{'path':n['path']+'.transcript','substringOccurrenceCount':(n.get('transcript') or '').count(str(period)),'positionKnown':False} for n in nodes if str(period) in (n.get('transcript') or '')]
  matrix.append({'fixture':page['fixture'],'page':page['page'],'period':period,'printedLiteral':literal[0],'sourcePNGDimensions':[w,he],'actualRenderDimensions':[page['width'],page['height']],'positionRule':'candidate character center mapped to fixed original ruled header cell; half-open x/y intervals; no text reconstruction','originalHeaderCell':bounds,'selectedHierarchyCaptureComplete':page.get('hierarchyCaptureComplete',False),'positionMatchedLiteralOccurrences':matches,'allPositionMatchedCandidateCharacters':all_here,'transcriptSubstringOccurrencesPositionUnknown':transcript_occurrences,'globalTop1HeaderFound':any(v['accessor']=='top1' and '.document.text.lines[' in v['containerPath'] and '.tables[' not in v['containerPath'] for v in matches),'anyTop1HeaderFound':any(v['accessor']=='top1' for v in matches),'anyTop5HeaderFound':any(v['accessor']=='top5' for v in matches),'tableHeaderFound':any('.tables[' in v['containerPath'] for v in matches),'anyTop1OriginalConfidenceAndBoxPredicatePass':any(v['accessor']=='top1' and v['candidateConfidencePass'] and v['originalBoxPredicate'] for v in matches),'autoAdopted':False,'formalBindingAssessed':False})
 page_rows.append({'fixture':page['fixture'],'page':page['page'],'readReturned':page.get('readReturned',False),'serializationCompleted':page.get('serializationCompleted',False),'selectedHierarchyCaptureComplete':page.get('hierarchyCaptureComplete',False),'omissions':h.get('omissions',[]),'omissionCount':h.get('omissionCount'),'budgetCounts':h.get('counts'),'textRegionCount':len(nodes),'lineRepresentationCount':len(lines),'nativeTableCounts':[r.get('nativeTableCount') for r in h.get('roots',[])],'top1VsTop5Disagreements':[v['path'] for v in lines if not v.get('top1VsTop5FirstTextConfidenceAgreement')],'originalGlobalTop1Comparisons':original_agreements,'originalGlobalTop1AllEqual':all(v['textConfidenceEqual'] for v in original_agreements),'formalBindingAssessed':False})
summary.update({'periodHeaderRows':len(matrix),'globalTop1PositionFound':sum(v['globalTop1HeaderFound'] for v in matrix),'anyTop1PositionFound':sum(v['anyTop1HeaderFound'] for v in matrix),'anyTop5PositionFound':sum(v['anyTop5HeaderFound'] for v in matrix),'tablePositionFound':sum(v['tableHeaderFound'] for v in matrix),'originalGlobalTop1Comparisons':sum(len(v['originalGlobalTop1Comparisons']) for v in page_rows),'originalGlobalTop1AllEqual':all(v['originalGlobalTop1AllEqual'] for v in page_rows)})
summary['top1PositionFoundPassingOriginalConfidenceAndBoxPredicates']=sum(v['anyTop1OriginalConfidenceAndBoxPredicatePass'] for v in matrix)
summary['periodPositionFoundCounts']={str(p):sum(v['anyTop1HeaderFound'] for v in matrix if v['period']==p) for p in range(1,9)}
summary['top5AdditionalCorrectHeaderPositions']=sum(v['anyTop5HeaderFound'] and not v['anyTop1HeaderFound'] for v in matrix)
old=json.loads((ROOT/'previous-main-lines.json').read_text(encoding='utf-8'))
oldpages=[v for v in old['records'] if v.get('type')=='page']
summary['oldVsNewOriginalMainLinesAllEqual']=len(oldpages)==len(pages) and all(a['lines']==b['lines'] for a,b in zip(oldpages,pages))
v={'scope':'same-run posthoc selected-accessor observation; numeric substrings are not period evidence; matched glyph centers are positional diagnostics only, not full geometry/ink/state/formal proof','rawSHA256':hashlib.sha256(raw).hexdigest(),'analysisScriptSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'summary':summary,'pageRows':page_rows,'periodHeaderMatrix':matrix,'formalTupleBinding':'unassessed; no candidate adopted or missing numeric header filled','latentAbsenceClaim':False}
(ROOT/'header-evidence.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary))
