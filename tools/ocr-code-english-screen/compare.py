"""Post-inference literal comparison only; physical ownership is not qualified."""
import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import re
from code_english_contract import COUNT, inputs, sha


def digest(value):
    return isinstance(value,str) and re.fullmatch('[0-9a-f]{64}',value) is not None


def finite(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)


def geometry(row, width, height):
    normalized, source = row['nativeNormalizedBox'], row['sourceBox']
    if (len(normalized) != 4 or len(source) != 4 or not all(finite(v) for v in normalized+source) or
            normalized[2] < 0 or normalized[3] < 0):
        raise ValueError('Invalid original native geometry')
    x,y,w,h = normalized
    if source != [x*width,(1-(y+h))*height,w*width,h*height]:
        raise ValueError('Native affine mapping changed')
    return 0 <= source[0] and 0 <= source[1] and source[0]+source[2] <= width and source[1]+source[3] <= height


def evaluate(frames, oracle, native, model):
    identities = [f'code-{i:04}' for i in range(COUNT)]
    if (len(frames) != COUNT or [r['id'] for r in frames] != identities or
            len(oracle) != COUNT or [r['id'] for r in oracle] != identities):
        raise ValueError('Frozen expected field inventory incomplete')
    for capture in [native,model]:
        if type(capture['actualCalls']) is not int or capture['actualCalls'] != COUNT or [r['id'] for r in capture['records']] != identities:
            raise ValueError('Missing, duplicate, reordered or extra actual call')
    result, native_errors, mapping_errors, outside, missing_boxes = [], 0, 0, 0, 0
    for frame, expected, n, m in zip(frames,oracle,native['records'],model['records']):
        width, height = frame['width'], frame['height']
        if (not digest(frame['rgbSHA256']) or n['sourceRGBSHA256'] != frame['rgbSHA256'] or
                n['actualRGBSHA256'] != frame['rgbSHA256'] or m['sourcePixelsSHA256'] != frame['rgbSHA256'] or
                n['originalPixelsReadbackVerified'] is not True or n['width'] != width or n['height'] != height or
                n['revision'] != 3 or n['languages'] != ['en-US'] or n['usesLanguageCorrection'] is not False or
                n['recognitionLevel'] != 'accurate' or n['automaticLanguageDetection'] is not False or
                n['minimumTextHeight'] != 0 or n['customWords'] != [] or
                not finite(n['seconds']) or n['seconds'] < 0):
            raise ValueError('Actual original pixels or native configuration changed')
        text, eligible = None, False
        if n['state'] == 'nativeError':
            if 'observations' in n or not isinstance(n['errorDomain'],str) or type(n['errorCode']) is not int:
                raise ValueError('Native error was replaced with recognized data')
            native_errors += 1
        elif n['state'] == 'recognized':
            if type(n['characterMappingErrors']) is not int or n['characterMappingErrors'] < 0:
                raise ValueError('Missing original native geometry error count')
            observed_mapping_errors = 0
            observations = n['observations']
            for observation in observations:
                outside += not geometry(observation,width,height)
                candidates = observation['candidates']
                if len(candidates) > 5:
                    raise ValueError('Changed native candidate limit')
                for candidate in candidates:
                    if (not isinstance(candidate['text'],str) or not finite(candidate['confidence']) or
                            not 0 <= candidate['confidence'] <= 1 or
                            ''.join(c['text'] for c in candidate['characters']) != candidate['text']):
                        raise ValueError('Original native candidate changed')
                    for character in candidate['characters']:
                        if 'mappingErrorDomain' in character or 'mappingErrorCode' in character:
                            if (not isinstance(character.get('mappingErrorDomain'),str) or
                                    type(character.get('mappingErrorCode')) is not int or
                                    'sourceBox' in character or 'nativeNormalizedBox' in character):
                                raise ValueError('Original character API error was changed')
                            observed_mapping_errors += 1
                        if ('sourceBox' in character) != ('nativeNormalizedBox' in character):
                            raise ValueError('Incomplete original native affine mapping')
                        if 'sourceBox' in character:
                            geometry(character,width,height)
                        else:
                            missing_boxes += 1
            if observed_mapping_errors != n['characterMappingErrors']:
                raise ValueError('Original native character API error count changed')
            mapping_errors += observed_mapping_errors
            if len(observations) == 1 and observations[0]['candidates']:
                top = observations[0]['candidates'][0]
                text, eligible = top['text'], top['confidence'] >= .85
        else:
            raise ValueError('Unknown original native state')
        pieces = m['pieces']
        padded = math.floor(48*max(320/48,width/height))
        valid = min(padded,math.ceil(48*width/height))
        if (m['reader'] != 'english-v1' or not digest(m['inputSHA256']) or
                m['inputWidth'] != padded or m['validWidth'] != valid or
                type(m['timeCount']) is not int or m['timeCount'] < 1 or
                not finite(m['rejectProbability']) or not 0 <= m['rejectProbability'] <= 1 or
                not finite(m['seconds']) or m['seconds'] < 0 or
                m['text'] != ''.join(p['text'] for p in pieces)):
            raise ValueError('Original CTC input/output contract changed')
        end = 0
        for piece in pieces:
            if (not isinstance(piece['text'],str) or not piece['text'] or not finite(piece['confidence']) or
                    not 0 <= piece['confidence'] <= 1 or any(type(piece[k]) is not int for k in ['start','end']) or
                    not end <= piece['start'] < piece['end'] <= m['timeCount']):
                raise ValueError('Invalid original CTC piece')
            end = piece['end']
        padding = all(p['end']*padded <= valid*m['timeCount'] for p in pieces)
        if m['paddingSupported'] is not padding:
            raise ValueError('Original CTC padding decision changed')
        model_eligible = bool(pieces) and padding and m['rejectProbability'] <= .05 and all(p['confidence'] >= .85 for p in pieces)
        result.append(dict(id=frame['id'],font=expected['font'],size=expected['size'],expected=expected['text'],
            nativeText=text,nativeExact=text == expected['text'],nativeOwn085=eligible,
            modelText=m['text'],modelExact=m['text'] == expected['text'],modelOwnConditions=model_eligible))
    literal_by_pixels = defaultdict(Counter)
    for frame, expected in zip(frames,oracle):
        literal_by_pixels[(frame['rgbSHA256'],frame['width'],frame['height'])][expected['text']] += 1
    summary = dict(study='ios-original-code-english-screen-v1',fields=COUNT,actualNativeCalls=COUNT,actualModelCalls=COUNT,
        nativeLiteral=sum(r['nativeExact'] for r in result),modelLiteral=sum(r['modelExact'] for r in result),
        nativeOwn085Exact=sum(r['nativeExact'] and r['nativeOwn085'] for r in result),
        nativeOwn085Wrong=sum(not r['nativeExact'] and r['nativeOwn085'] for r in result),
        modelOwnConditionsExact=sum(r['modelExact'] and r['modelOwnConditions'] for r in result),
        modelOwnConditionsWrong=sum(not r['modelExact'] and r['modelOwnConditions'] for r in result),
        nativeGainsOverV1=sum(r['nativeExact'] and not r['modelExact'] for r in result),
        nativeLossesOverV1=sum(not r['nativeExact'] and r['modelExact'] for r in result),
        nativeErrors=native_errors,nativeGeometryErrors=mapping_errors,nativeBoxesOutsideSmallFrame=outside,
        nativeMissingCharacterBoxes=missing_boxes,physicalOwnershipQualified=False,wholeDocumentQualified=False,
        physicalIPhoneExecution=False,applicationChanged=False,alreadyConsumedFonts=True,
        differentLiteralIdenticalImageGroups=sum(len(counts) > 1 for counts in literal_by_pixels.values()),
        sourceByteLiteralCeiling=sum(max(counts.values()) for counts in literal_by_pixels.values()))
    return result, summary


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('root',type=Path); args = parser.parse_args()
    def load(name): return json.loads((args.root/name).read_text())
    frames, native, model = inputs(args.root), load('native.json'), load('model.json')
    # Both readers have exited. Only this process reads expected literals.
    oracle = load('oracle.json')['fields']
    for tag, rows in [('NATIVE',native['records']),('MODEL',model['records'])]:
        for row in rows:
            print('CODE_ENGLISH_'+tag+' '+json.dumps(row,sort_keys=True),flush=True)
    fields, receipt = evaluate(frames,oracle,native,model)
    for frame, field in zip(frames,fields):
        print('CODE_ENGLISH_FIELD '+json.dumps(dict(frame=frame,**field),sort_keys=True),flush=True)
    receipt.update(nativeFileSHA256=sha((args.root/'native.json').read_bytes()),modelFileSHA256=sha((args.root/'model.json').read_bytes()),
        oracleFileSHA256=sha((args.root/'oracle.json').read_bytes()),inputsFileSHA256=sha((args.root/'inputs.json').read_bytes()))
    print('CODE_ENGLISH_RECEIPT '+json.dumps(receipt,sort_keys=True),flush=True)
    if receipt['nativeErrors'] or receipt['nativeGeometryErrors']:
        raise ValueError('Native API/geometry errors remain failures after all raw calls were retained')


if __name__ == '__main__':
    main()
