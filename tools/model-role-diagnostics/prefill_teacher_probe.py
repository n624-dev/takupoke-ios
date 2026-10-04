"""One native prefill diagnostic, not a HEAD quality pass or output repair."""
import copy, hashlib, json, time, urllib.request
from pathlib import Path
SOURCE=Path('/workspace/review-notes/ios-role-diagnostics-qwen25-compact-dev-v2.json')
old=json.loads(SOURCE.read_text(encoding='utf-8'))
row=next(x for x in old['results'] if x['role']=='teacher')
payload=copy.deepcopy(row['request']);payload.pop('grammar')
prefix='{"ids":['
payload['messages'].append({'role':'assistant','content':prefix})
assert all(x not in json.dumps(payload) for x in ('expectedAlias','expectedIds','expectedID'))
report={'task':'native_assistant_prefill_diagnostic','version':1,'scope':'Consumed dev, one teacher free-v2 request with public schema-only prefix. Raw native continuation is not a standalone HEAD JSON result; no qualified HEAD/certificate success is claimed.','sourceRequestSHA256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'runtime':'llama.cpp b11371 upstreamJinja CPU2/context4096/reasoningoff','planned':1,'model':'qwen25-1.5B-Q4.gguf','nativeReturned':False,'request':payload,'assistantPrefix':prefix}
start=time.monotonic()
try:
 req=urllib.request.Request('http://127.0.0.1:18251/v1/chat/completions',json.dumps(payload,ensure_ascii=False).encode('utf-8'),{'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=120) as response: reply=json.load(response)
 report.update(nativeReturned=True,operationalError=False,response=reply,raw=reply['choices'][0]['message'].get('content'))
except Exception as error:report.update(operationalError=True,error=repr(error))
report['seconds']=time.monotonic()-start
Path('/workspace/review-notes/ios-role-diagnostics-qwen25-teacher-prefill.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(report,ensure_ascii=False))
