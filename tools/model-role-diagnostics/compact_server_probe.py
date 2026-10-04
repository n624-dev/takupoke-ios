"""Frozen compact HEAD consumed-dev trial; expected IDs never enter inference payload."""
import hashlib,json,time,urllib.request,sys
from response_protocol import decode_ids
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
assert len(sys.argv) in (4,5)
model,port,pid=sys.argv[1:4]
variant=sys.argv[4] if len(sys.argv)==5 else 'v1'
assert variant in ('v1','v2')
assert model in ('qwen25','qwen35','qwen06','qwen17') and port in ('18251','18252','18253','18254') and pid.isdecimal()
model_files={'qwen25':'qwen25-1.5B-Q4.gguf','qwen35':'qwen35-2B-Q4.gguf','qwen06':'qwen3-0.6B-Q8.gguf','qwen17':'qwen3-1.7B-Q8.gguf'}
source=Path('/tmp/takupoke-ios-model-probe-20261004/tools/phone-model-probe/gguf-batch/corpus.json')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='7a0c210890d713cc1f597f30f76a538027d47d9ae2fc960de90cc85aaaabffd3'
corpus=json.loads(source.read_text());case=corpus['cases'][0];groups=case['groups']
instruction=(ROOT/('tools/model-role-diagnostics/prompts/compact-header-role-'+variant+'.txt')).read_text(encoding='utf-8')
assert hashlib.sha256(instruction.encode()).hexdigest()=={'v1':'93c98914185bb2211574ed52395505a76c825203320495232debafe5fe6a4e3b','v2':'d24d3520e32dcd44d7a7440adc5ff20169580285d12190e04c2feb42329ad741'}[variant]
ids=' | '.join(json.dumps(json.dumps(g['id'])) for g in groups)
grammar='root ::= "{" ws "\\\"ids\\\"" ws ":" ws "[" ws (id (ws "," ws id){0,47})? ws "]" ws "}"\nws ::= [ \\t\\n\\r]{0,4}\nid ::= '+ids+'\n'
report={'scope':'Consumed development compact HEAD component only; useful recovery denominator0','instructionSHA256':hashlib.sha256(instruction.encode()).hexdigest(),'instructionVariant':variant,'corpusSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'model':model_files[model],'runtime':'llama.cpp b11371 upstream server Jinja/reasoningoff CPU2/context4096','plannedRoles':3,'results':[]}
out=Path('/workspace/review-notes/ios-role-diagnostics-'+model+'-compact-dev'+('-v2' if variant=='v2' else '')+'.json')
weight=Path('/workspace/recovery-research/artifacts')/model_files[model]
h=hashlib.sha256()
with weight.open('rb') as stream:
 while chunk:=stream.read(1048576):h.update(chunk)
report['artifact']={'bytes':weight.stat().st_size,'sha256':h.hexdigest()}
report['memoryScope']='Actual Linux native server process VmRSS/VmHWM KiB; includes model mmap, not iPhone available memory. Concurrent two CPU-thread servers may affect walltime.'
for role in ('subject','teacher','room'):
 prompt='targetRole: '+role+'\nallowedHeaders: '+json.dumps(corpus['allowedRoleLabels'][role],ensure_ascii=False)+'\nsources (original order):\n'+'\n'.join(json.dumps(g['id'])+': '+json.dumps(g['text'],ensure_ascii=False) for g in groups)
 payload={'messages':[{'role':'system','content':instruction},{'role':'user','content':prompt}],'temperature':0,'seed':17,'max_tokens':128,'cache_prompt':False,'grammar':grammar}
 row={'role':role,'request':payload,'nativeReturned':False};started=time.monotonic()
 try:
  request=urllib.request.Request('http://127.0.0.1:'+port+'/v1/chat/completions',json.dumps(payload,ensure_ascii=False).encode(),{'Content-Type':'application/json'})
  with urllib.request.urlopen(request,timeout=120) as r:response=json.load(r)
  row.update(nativeReturned=True,response=response,raw=response['choices'][0]['message'].get('content'),operationalError=False)
 except Exception as error:row.update(operationalError=True,error=repr(error))
 if row['nativeReturned']:
  try:
   value=decode_ids(row['raw'],groups)
   row.update(strictDecoded=True,decoded=value,exact=value['ids']==case['expected'][role])
  except Exception as error:row.update(strictDecoded=False,exact=False,outputFormatError=repr(error))
 row['seconds']=time.monotonic()-started
 status=Path('/proc/'+pid+'/status').read_text()
 row['nativeProcessMemoryKiB']={line.split(':')[0]:int(line.split()[1]) for line in status.splitlines() if line.startswith(('VmRSS:','VmHWM:'))}
 report['results'].append(row);out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(role,row.get('raw'),row.get('exact'),flush=True)
