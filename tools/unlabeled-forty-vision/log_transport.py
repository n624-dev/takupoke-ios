"""Lossless raw byte transport through bounded CI log lines; no artifact/cache."""
import base64
import hashlib
import json
import math

PREFIX = 'IOS_UNLABELED_FORTY_RAW '
CHUNK_BYTES = 4096
MAX_BYTES = 64 * 1024 * 1024


def encode(raw, key):
    assert len(raw) <= MAX_BYTES
    header = {'schema': 1, 'key': key, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
              'chunkBytes': CHUNK_BYTES, 'chunks': math.ceil(len(raw) / CHUNK_BYTES)}
    for record in [{'type': 'begin', **header}]:
        yield PREFIX + json.dumps(record, separators=(',', ':'))
    for index in range(header['chunks']):
        data = raw[index * CHUNK_BYTES:(index + 1) * CHUNK_BYTES]
        line = PREFIX + json.dumps({'type': 'chunk', 'key': key, 'index': index, 'base64': base64.b64encode(data).decode('ascii')}, separators=(',', ':'))
        assert len(line.encode('ascii')) < 8192
        yield line
    yield PREFIX + json.dumps({'type': 'end', **header}, separators=(',', ':'))


def restore(log):
    """Reject missing, reordered, duplicated, truncated or corrupted chunks."""
    pending, completed = {}, {}
    for line in log.splitlines():
        offset = line.find(PREFIX)
        if offset < 0:
            continue
        value = json.loads(line[offset + len(PREFIX):])
        key, kind = value['key'], value['type']
        if kind == 'begin':
            assert key not in pending and key not in completed
            assert value['schema'] == 1 and value['chunkBytes'] == CHUNK_BYTES
            assert 0 <= value['bytes'] <= MAX_BYTES and value['chunks'] == math.ceil(value['bytes'] / CHUNK_BYTES)
            pending[key] = (value, [])
        elif kind == 'chunk':
            header, chunks = pending[key]
            assert value['index'] == len(chunks) and len(chunks) < header['chunks']
            data = base64.b64decode(value['base64'], validate=True)
            assert len(data) == min(CHUNK_BYTES, header['bytes'] - len(chunks) * CHUNK_BYTES)
            chunks.append(data)
        elif kind == 'end':
            header, chunks = pending.pop(key)
            assert {k: v for k, v in value.items() if k != 'type'} == {k: v for k, v in header.items() if k != 'type'}
            assert len(chunks) == header['chunks']
            raw = b''.join(chunks)
            assert len(raw) == header['bytes'] and hashlib.sha256(raw).hexdigest() == header['sha256']
            completed[key] = raw
        else:
            raise ValueError('Unknown transport record')
    assert not pending, 'Unfinished raw transport; no completeness claim'
    return completed
