"""Strict original-ID decoder. It never sorts or repairs returned evidence."""
import json

def decode_ids(raw, groups):
    def unique(pairs):
        result={}
        for key,value in pairs:
            if key in result:raise ValueError('Duplicate JSON property')
            result[key]=value
        return result
    if type(raw) is not str or len(raw.encode('utf-8'))>16384:raise ValueError('Invalid or oversized raw output')
    value=json.loads(raw,object_pairs_hook=unique)
    if type(value) is not dict or set(value)!={'ids'}:raise ValueError('Exactly one ids property on an object required')
    selected=value['ids'];order={g['id']:i for i,g in enumerate(groups)}
    if len(order)!=len(groups):raise ValueError('Invalid nonunique input IDs')
    if type(selected) is not list or len(selected)>48 or any(type(x) is not str or x not in order for x in selected):raise ValueError('Unknown ID or invalid array')
    if len(set(selected))!=len(selected) or selected!=sorted(selected,key=order.__getitem__):raise ValueError('Duplicate or reordered IDs')
    return value
