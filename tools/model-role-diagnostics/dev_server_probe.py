"""Loopback-only actual runtime/template/grammar development controls; no quality gate."""
import hashlib,json,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path('/workspace/review-notes/ios-role-diagnostics-qwen25-server-dev.json')
INSTRUCTION=(ROOT/'tools/recovery-prompt-contracts/prompts/single-header-role-ja-v1.txt').read_text(encoding='utf-8')
CORPUS=Path('/tmp/takupoke-ios-model-probe-20261004/tools/phone-model-probe/gguf-batch/corpus.json')
assert hashlib.sha256(CORPUS.read_bytes()).hexdigest() == '7a0c210890d713cc1f597f30f76a538027d47d9ae2fc960de90cc85aaaabffd3'
assert hashlib.sha256(INSTRUCTION.encode()).hexdigest() == '4827fa46956a14d375792000e9bdba62a7c0bc153a19ceb4c6202063877debc7'
c=json.loads(CORPUS.read_text());case=c['cases'][0]
cell={'sources':case['groups'],'allowedRoleLabels':c['allowedRoleLabels']}
ids=' | '.join(json.dumps(json.dumps(g['id'])) for g in cell['sources'])
grammar='root ::= "{" ws "\\\"ids\\\"" ws ":" ws "[" ws (id (ws "," ws id){0,47})? ws "]" ws "}"\nws ::= [ \\t\\n\\r]{0,4}\nid ::= '+ids+'\n'
report={'scope':'Consumed development runtime/grammar diagnosis, no heldout or useful-AI qualification','recipe':{'runtime':'llama.cpp b11371','path':'upstream server Jinja','temperature':0,'seed':17,'context':4096,'CPUThreads':2,'maxTokens':128,'model':'qwen25-1.5B-Q4.gguf','reasoning':'off'},'instructionSHA256':hashlib.sha256(INSTRUCTION.encode()).hexdigest(),'corpusSHA256':hashlib.sha256(CORPUS.read_bytes()).hexdigest(),'results':[]}
controls=[('literal-marker','Return exactly READY. No other text.','Return exactly READY.',None,'READY'),('arithmetic','Answer the arithmetic question with its correct single-digit result.','Compute 2 + 2. Return the single numeral for the result.',None,'4'),('role-meaning','Answer one word: subject, teacher, or room.','What does the Japanese timetable heading 教室 mean?',None,'room')]
for role in ['subject','teacher','room']:
 prompt=json.dumps({'targetRole':role,'cellData':cell},ensure_ascii=False,separators=(',',':'))
 for mode in ['free','gbnf']:
  controls.append(('head-'+role+'-'+mode,INSTRUCTION,prompt,grammar if mode=='gbnf' else None,{'ids':case['expected'][role]}))
def observe_response(call, expected, groups):
    # Invocation/HTTP failure is operational. Returned model content is assessed
    # separately even when JSON format, IDs or semantic assignment are wrong.
    row = {"nativeReturned": False}
    try:
        response = call()
        raw = response["choices"][0]["message"]["content"]
        row.update(response=response, raw=raw, nativeReturned=True, operationalError=False)
    except Exception as error:
        row.update(operationalError=True, error=repr(error))
        return row
    if not isinstance(expected, dict):
        row["exact"] = type(raw) is str and raw.strip() == expected
        return row
    try:
        def unique(pairs):
            value = {}
            for key, item in pairs:
                if key in value:
                    raise ValueError("Duplicate JSON property")
                value[key] = item
            return value
        if type(raw) is not str or len(raw.encode("utf-8")) > 16384:
            raise ValueError("Invalid or oversized content")
        value = json.loads(raw, object_pairs_hook=unique)
        if type(value) is not dict or set(value) != {"ids"}:
            raise ValueError("Exactly one ids array required")
        selected = value["ids"]
        order = {g["id"]: i for i, g in enumerate(groups)}
        if type(selected) is not list or len(selected) > 48 or any(type(x) is not str or x not in order for x in selected):
            raise ValueError("Unknown ID or invalid array")
        if len(set(selected)) != len(selected) or selected != sorted(selected, key=order.__getitem__):
            raise ValueError("Duplicate or reordered IDs")
        row.update(strictDecoded=True, exact=value == expected)
    except Exception as error:
        row.update(strictDecoded=False, strictDecodeFailure=True, outputFormatError=repr(error), exact=False)
    return row

if __name__ == "__main__":
    for name,system,prompt,g,expected in controls:
        payload={"messages":[{"role":"system","content":system},{"role":"user","content":prompt}],"temperature":0,"seed":17,"max_tokens":128,"cache_prompt":False}
        if g:payload["grammar"]=g
        started=time.monotonic()
        def call():
            request=urllib.request.Request("http://127.0.0.1:18251/v1/chat/completions",json.dumps(payload,ensure_ascii=False).encode(),{"Content-Type":"application/json"})
            with urllib.request.urlopen(request,timeout=120) as response:
                return json.load(response)
        row={"name":name,"request":payload,"expected":expected,**observe_response(call,expected,case["groups"])}
        row["seconds"]=time.monotonic()-started;report["results"].append(row)
        OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
        print(name,row.get("raw"),row.get("exact"),row.get("error"),flush=True)
