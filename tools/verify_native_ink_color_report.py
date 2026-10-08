"""Check a synthetic native shadow report without granting adoption credit."""
import json
import math
import sys
from pathlib import Path


def verify(path):
    groups = {key: [] for key in ('SCOPE', 'ITEM', 'OUTCOME')}
    for line in Path(path).read_text().splitlines():
        prefix, content = line.split(' ', 1)
        assert prefix.startswith('NATIVE_INK_'), 'Unexpected report record'
        key = prefix.removeprefix('NATIVE_INK_')
        assert key in groups, 'Unexpected record type'
        groups[key].append(json.loads(content))
    scopes, items, outcomes = (groups[key] for key in ('SCOPE', 'ITEM', 'OUTCOME'))
    palette = {
        'black': [0, 0, 0], 'navy': [.05, .1, .3], 'red': [.65, .08, .08],
        'green': [.05, .35, .05], 'dark-gray': [28 / 255] * 3,
        'medium-gray': [.35] * 3, 'light-gray': [.65] * 3,
        'very-light-gray': [.85] * 3,
    }
    readers = ('documents', 'accurate-text')
    kinds = ('ascii-header', 'japanese-header', 'japanese-body', 'code')
    expected_scopes = {(c, color) for c in range(2) for color in palette}
    assert len(scopes) == 16 and {(r['cohort'], r['color']) for r in scopes} == expected_scopes
    scope_by_key = {(r['cohort'], r['color']): r for r in scopes}
    assert len({r['imageRGBAHash'] for r in scopes}) == 16, 'Original images reused across colors/fonts'
    for row in scopes:
        assert row['RGB'] == palette[row['color']]
        assert row['font'] == ('HiraginoSans-W3', 'HiraMinProN-W3')[row['cohort']]
        assert row['items'] == 32 and row['calls'] == 2 and row['width'] == row['height'] == 1920
        assert row['languages'] == ['ja', 'en'] and row['languageCorrection'] is True and row['automaticLanguage'] is False
        assert row['qualified'] is False and row['adoptionCalls'] == row['newIndependentItems'] == 0
        assert len(row['imageRGBAHash']) == 64 and all(c in '0123456789abcdef' for c in row['imageRGBAHash'])
    expected_items = {(c, color, reader, ordinal) for c, color in expected_scopes for reader in readers for ordinal in range(32)}
    assert len(items) == 1024 and {(r['cohort'], r['color'], r['reader'], r['ordinal']) for r in items} == expected_items
    item_by_key = {(r['cohort'], r['color'], r['reader'], r['ordinal']): r for r in items}
    for row in items:
        scope = scope_by_key[row['cohort'], row['color']]
        assert row['imageRGBAHash'] == scope['imageRGBAHash']
        assert row['qualified'] is False and row['adoptionCalls'] == 0 and row['crossReaderScoreSubstitution'] is False
        baseline = item_by_key[row['cohort'], 'black', 'documents', row['ordinal']]
        assert all(row[key] == baseline[key] for key in ('kind', 'sourcePixels', 'evaluationRegion', 'expectedAfterRecognition')), 'Color changed the source layout or literal'
        assert row['kind'] == kinds[row['ordinal'] // 8]
        observations = row['observations']
        top = observations[0]['candidates'][0] if len(observations) == 1 and observations[0]['candidates'] else None
        assert row['observed'] == (top['text'] if top else None)
        assert row['nativeScore'] == (top['score'] if top else None), 'Own native confidence replaced'
        for obs in observations:
            assert 0 <= obs['sourceOrder'] and 0 <= len(obs['candidates']) <= 5
            assert len(obs['box']) == 4 and all(math.isfinite(v) for v in obs['box']) and all(v > 0 for v in obs['box'][2:])
            assert all(isinstance(c['text'], str) and math.isfinite(c['score']) and 0 <= c['score'] <= 1 for c in obs['candidates'])
        region = row['evaluationRegion']
        assert len(region) == 4 and all(math.isfinite(v) for v in region)
        contains = len(observations) == 1 and all((observations[0]['box'][axis] >= region[axis] and
            observations[0]['box'][axis] + observations[0]['box'][axis + 2] <= region[axis] + region[axis + 2]) for axis in (0, 1))
        status = ('missing' if not observations else 'split-or-conflicting' if len(observations) > 1 else
                  'candidate-missing' if not top else 'single-contained' if contains else 'spanning-region')
        assert row['status'] == status and row['exact'] == (status == 'single-contained' and row['observed'] == row['expectedAfterRecognition'])
    expected_outcomes = {(c, color, reader, kind) for c, color in expected_scopes for reader in readers for kind in kinds}
    assert len(outcomes) == 128 and {(r['cohort'], r['color'], r['reader'], r['kind']) for r in outcomes} == expected_outcomes
    for row in outcomes:
        selected = [item_by_key[row['cohort'], row['color'], row['reader'], i] for i in range(32) if kinds[i // 8] == row['kind']]
        above = lambda r: r['status'] == 'single-contained' and r['nativeScore'] >= .85
        assert row['items'] == len(selected) == 8
        assert row['qualified'] is False and row['adoptionCalls'] == 0 and row['productionThresholdChanged'] is False
        counted = {'exact': sum(r['exact'] for r in selected),
            'correctAtOrAbove085': sum(r['exact'] and above(r) for r in selected),
            'wrongAtOrAbove085': sum(not r['exact'] and above(r) for r in selected),
            'missing': sum(r['status'] == 'missing' for r in selected)}
        assert all(row[key] == count for key, count in counted.items()), 'Outcome differs from per-reader records'
        print('VERIFIED_NATIVE_INK_OUTCOME ' + json.dumps(row, sort_keys=True))
    print('Verified16 original synthetic images,1024 own-reader items,128 outcomes,32 fixed calls;0 independent/adoption credit')


if __name__ == '__main__':
    verify(sys.argv[1])
