"""Oracle-free framing of a measured class column; keep original ink and records."""
import math


def column(cells, records):
    if not cells:
        return [], dict(state='noPhysicalCells')
    labels = [r for r in records if r.get('text') == 'クラス' and r.get('ownPieceFloor085') and
              r.get('paddingSupported') and r.get('ownerCell') is not None]
    # A printed word in a body cell must not become a header merely by spelling.
    left, top = min(c[0] for c in cells), min(c[1] for c in cells)
    anchors = [r for r in labels if cells[r['ownerCell']][0] == left and cells[r['ownerCell']][1] == top]
    if len(anchors) != 1:
        return [], dict(state='missingOrAmbiguousTopLeftClassLabel')
    anchor = anchors[0]; header = cells[anchor['ownerCell']]
    if len([r for r in records if r.get('ownerCell') == anchor['ownerCell']]) != 1:
        return [], dict(state='otherInkInClassHeader')
    chain = sorted([(i, c) for i, c in enumerate(cells) if c[0] == left and c[2] == header[2]], key=lambda item: item[1][1])
    if (not chain or chain[0][0] != anchor['ownerCell'] or len(chain) < 2 or
            any(a[1][1]+a[1][3] != b[1][1] for a, b in zip(chain, chain[1:]))):
        return [], dict(state='nonContiguousMeasuredClassColumn')
    # Reject a second measured cell overlapping the same column, rather than
    # selecting a convenient equal-width subset of an ambiguous table.
    members = {i for i, _ in chain}
    if any(i not in members and max(c[0], left) < min(c[0]+c[2], left+header[2]) for i, c in enumerate(cells)):
        return [], dict(state='competingMeasuredClassColumn')
    return [i for i, _ in chain[1:]], dict(state='measuredClassColumn', anchorRecord=anchor['index'],
        headerCell=anchor['ownerCell'], classCells=[i for i, _ in chain[1:]])


def frame(gray, mask, cells, records, owner):
    import numpy as np
    x, y, w, h = cells[owner]
    left, top = max(0, math.ceil(x-.5)), max(0, math.ceil(y-.5))
    right, bottom = min(gray.shape[1], math.floor(x+w-.5)+1), min(gray.shape[0], math.floor(y+h-.5)+1)
    ink = (gray[top:bottom, left:right] != 255) & (mask[top:bottom, left:right] == 0)
    yy, xx = np.nonzero(ink)
    expected = sum(r['originalInkPixels'] for r in records if r['ownerCell'] == owner)
    if int(ink.sum()) != expected:
        raise ValueError('Measured class cell original ink inventory changed')
    if not len(xx):
        return None, dict(state='emptyMeasuredClassCell', ownerCell=owner)
    # This trial supports one observed text-height band, including a detached
    # underscore. Two printed lines remain unsupported, never silently joined.
    active = ink.any(axis=1)
    runs, opened = [], None
    for i, value in enumerate([*active, False]):
        if value and opened is None:
            opened = i
        elif not value and opened is not None:
            runs.append((opened, i)); opened = None
    ink_height = int(yy.max()-yy.min()+1)
    if ink_height*2 > 3*max(b-a for a, b in runs):
        return None, dict(state='multipleMeasuredTextBands', ownerCell=owner)
    a, b = left+max(0, int(xx.min())-2), top+max(0, int(yy.min())-2)
    c, d = left+min(right-left, int(xx.max())+3), top+min(bottom-top, int(yy.max())+3)
    ink_box = [left+int(xx.min()), top+int(yy.min()), int(xx.max()-xx.min()+1), ink_height]
    return dict(ownerCell=owner, inkBox=ink_box, frameBox=[a, b, c-a, d-b], originalInkPixels=expected,
                originalRecordIndices=[r['index'] for r in records if r['ownerCell'] == owner]), dict(state='framedAllOriginalClassCellInk')


def ascii_eligible(primary):
    text = primary.get('text') or ''
    return primary.get('state') == 'recognized' and 2 <= len(text) <= 32 and (
        all(32 <= ord(c) <= 126 for c in text) and any('0' <= c <= '9' for c in text))


def select_ascii_candidates(originals, ascii_records, selects):
    if ([r['ownerCell'] for r in originals] != [r['ownerCell'] for r in ascii_records] or
            len({r['ownerCell'] for r in originals}) != len(originals)):
        raise ValueError('ASCII class inventory differs from original cells')
    output = []
    for primary, candidate in zip(originals, ascii_records):
        if bool(candidate['actualCall']) != bool(ascii_eligible(primary)):
            raise ValueError('ASCII class call does not match declared eligibility')
        if candidate['actualCall']:
            if any(candidate[k] != primary[k] for k in ['inkBox', 'frameBox', 'sourcePixelsSHA256', 'originalInkPixels']):
                raise ValueError('ASCII class did not use the same original source frame')
            expert = candidate['expert']
            if (candidate['sourcePixelsSHA256'] != expert['sourcePixelsSHA256'] or candidate['text'] != expert['text'] or expert['text'] != ''.join(p['text'] for p in expert['pieces']) or
                    candidate['ownPieceFloor085'] != (bool(expert['pieces']) and all(p['confidence'] >= .85 for p in expert['pieces'])) or
                    candidate['paddingSupported'] != expert['paddingSupported']):
                raise ValueError('ASCII class original result changed')
            selected = selects(primary['text'], expert)
            if candidate['selected'] != selected:
                raise ValueError('ASCII class selection differs from fixed conditions')
            output.append(candidate if selected else primary)
        else:
            if candidate['selected']:
                raise ValueError('Unexecuted ASCII class cannot be selected')
            output.append(primary)
    return output
