"""Distinct whole-alias semantic diagnostic, not original-ID HEAD or adoption."""
import hashlib,json,time,urllib.request,itertools
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'tools/model-role-diagnostics/prompts/whole-header-alias-v1.txt'
instruction=p.read_text();assert hashlib.sha256(instruction.encode()).hexdigest()=='99dd8fcd5ad5a018f20b3023dc5fe0cd1eb5222edcef8c704ebcc59b2e5112fa'
source=Path('/tmp/takupoke-ios-model-probe-20261004/tools/phone-model-probe/gguf-batch/corpus.json')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='7a0c210890d713cc1f597f30f76a538027d47d9ae2fc960de90cc85aaaabffd3'
corpus=json.loads(source.read_text());case=corpus['cases'][0];groups=case['groups']
out=Path('/workspace/review-notes/ios-role-diagnostics-qwen25-whole-alias-dev.json')
report={'task':'whole_header_alias_diagnostic','version':1,'scope':'Consumed-dev whole-label semantic controls; no original-ID HEAD pass, certificate pass or model qualification','instructionSHA256':hashlib.sha256(instruction.encode()).hexdigest(),'planned':3,'model':'qwen25-1.5B-Q4.gguf','runtime':'llama.cpp b11371 upstreamJinja CPU2/context4096/reasoningoff','results':[]}
for role in ('subject','teacher','room'):
 allowed=corpus['allowedRoleLabels'][role]
 prompt='targetRole: '+role+'\nallowedHeaders: '+json.dumps(allowed,ensure_ascii=False)+'\nsources (original order):\n'+'\n'.join(json.dumps(g['id'])+': '+json.dumps(g['text'],ensure_ascii=False) for g in groups)
 grammar='root ::= "{" ws "\\\"alias\\\"" ws ":" ws alias ws "}"\nws ::= [ \\t\\n\\r]{0,4}\nalias ::= "null" | '+' | '.join(json.dumps(json.dumps(s,ensure_ascii=False),ensure_ascii=False) for s in allowed)+'\n'
 payload={'messages':[{'role':'system','content':instruction},{'role':'user','content':prompt}],'temperature':0,'seed':17,'max_tokens':128,'cache_prompt':False,'grammar':grammar}
 row={'role':role,'request':payload,'nativeReturned':False};t=time.monotonic()
 try:
  req=urllib.request.Request('http://127.0.0.1:18251/v1/chat/completions',json.dumps(payload,ensure_ascii=False).encode(),{'Content-Type':'application/json'});response=json.load(urllib.request.urlopen(req,timeout=120));row.update(nativeReturned=True,operationalError=False,response=response,raw=response['choices'][0]['message']['content'])
 except Exception as error:row.update(operationalError=True,error=repr(error))
 if row['nativeReturned']:
  try:
   def unique(pairs):
    value={}
    for key,item in pairs:
     if key in value:raise ValueError('Duplicate property')
     value[key]=item
    return value
   value=json.loads(row['raw'],object_pairs_hook=unique)
   if type(value) is not dict or set(value)!={'alias'} or not(value['alias'] is None or type(value['alias']) is str and value['alias'] in allowed):raise ValueError('Invalid alias output')
   # Separate post-return oracle and all-alias text grounding; no geometry certificate claim.
   byid={g['id']:g['text'] for g in groups};expected=''.join(byid[s] for s in case['expected'][role]);row.update(strictDecoded=True,decoded=value,expectedAlias=expected,aliasExact=value['alias']==expected)
   matches=[]
   for count in range(1,len(groups)+1):
    for indices in itertools.combinations(range(len(groups)),count):
     text=''.join(groups[i]['text'] for i in indices)
     if text in allowed:matches.append({'alias':text,'ids':[groups[i]['id'] for i in indices]})
   row['allTextAliasChains']=matches
  except Exception as error:row.update(strictDecoded=False,aliasExact=False,outputFormatError=repr(error))
 row['seconds']=time.monotonic()-t;report['results'].append(row);out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(role,row.get('raw'),row.get('aliasExact'),flush=True)
