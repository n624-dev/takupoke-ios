#!/usr/bin/env python3
"""Bounded numeric CI annotations for fictional research; never publish source text."""
import argparse
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent


def count(value, maximum=100000):
    if type(value) is not int or not 0 <= value <= maximum:
        raise ValueError('Invalid bounded research count')
    return value


def digest(value):
    if not isinstance(value, str) or re.fullmatch('[0-9a-f]{64}', value) is None:
        raise ValueError('Invalid research digest')
    return value


def number(value, maximum):
    if type(value) not in [int, float] or not math.isfinite(value) or not 0 <= value <= maximum:
        raise ValueError('Invalid bounded research measurement')
    return value


def source_receipt(comparison, acquisition, case, native_log):
    protocol = json.loads((ROOT/'ocr-document-qualification/protocol.json').read_text())
    if case not in protocol['cases']:
        raise ValueError('Unknown fixed fictional source case')
    if (native_log.count('FULL_SOURCE_CAPTURE_FINISHED pages=2 actualVisionCalls=1') != 1 or
            len(re.findall(r'Test Case .*testAcquireCompleteFrozenOriginalSource.*passed', native_log)) != 1 or
            'Executed 1 test, with 0 failures' not in native_log):
        raise ValueError('Native acquisition did not complete its exact inventory')
    if len(comparison['summaries']) != 1 or len(acquisition['documents']) != 1:
        raise ValueError('Incomplete fictional source receipt')
    row, receipt, document = comparison['summaries'][0], comparison['receipt'], acquisition['documents'][0]
    kind = case.split('-', 1)[1]; fields = protocol['requiredBodyFields'][kind]
    if (row['id'] != 'qualification-'+case or document['id'] != row['id'] or document['kind'] != kind or
            any(r['variant'] != 'source2x4096' for r in [row, receipt, acquisition]) or receipt['documents'] != 1 or
            row['fields'] != fields or receipt['requiredBodyFields'] != fields or row['classNameFields'] != 17 or
            document['nativeVisionState'] != 'notRequestedDimensionBound' or
            receipt['visionInputVariant'] != 'current2048' or receipt['visionAllocationUsesOwnOriginalGeometry'] is not True):
        raise ValueError('Fixed target source scope changed')
    result = dict(study='ios-ocr-full-scope-source2x-v1', case=case, variant='source2x4096', bodyFields=fields, classNames=17,
                  sourcePDFSHA256=digest(document['sourcePDFSHA256']), recognizedFileSHA256=digest(receipt['recognizedFileSHA256']),
                  actualBaselineVisionCalls=1, actualCandidateVisionCalls=count(receipt['actualVisionCalls'], 0),
                  formalAdoptionVerified=False, physicalIPhoneExecution=False)
    for key in ['visionExact','paddleExact','paddleOwnPiecesEligibleWrong']:
        result[key] = count(row[key], fields)
    for key in ['paddleUnassignedInBody','paddleUnassignedIncludingHeaders']:
        result[key] = count(row[key])
    for key in ['classOriginalExact','classCandidateExact','classCandidateEligibleExact','classCandidateEligibleWrong',
                'classASCIIExact','classASCIIEligibleExact','classASCIIEligibleWrong','classASCIIGainsOverCellV6',
                'classASCIILossesOverCellV6','classCandidateRefusedCells','classCandidateUnexpectedCellInk','classASCIIUnexpectedCellInk']:
        result[key] = count(row[key], 17)
    for key in ['actualV6Calls','actualASCIICalls','actualONNXCalls','actualClassCellCalls']:
        result[key] = count(receipt[key])
    if (result['classASCIIExact'] != result['classCandidateExact']+result['classASCIIGainsOverCellV6']-result['classASCIILossesOverCellV6'] or
            result['actualONNXCalls'] != result['actualV6Calls']+result['actualASCIICalls'] or
            result['actualASCIICalls'] > result['actualClassCellCalls'] or result['actualClassCellCalls'] > 17 or
            row['hybridExact'] != row['paddleExact']):
        raise ValueError('Inconsistent research counters or unexpected body replacement')
    return result


def native_receipt(receipt):
    if (receipt['study'] != 'ios-ascii-v1-cpu-native-input-parity-v1' or receipt['runtime'] != '1.23.2' or
            receipt['actualNativeCalls'] != 288 or receipt['actualReferenceCalls'] != 288 or
            receipt['nativeRGBTransforms'] != 292 or receipt['nativeInputCount'] != 2 or receipt['nativeOutputCount'] != 2 or
            receipt['nativeValidWidthType'] != 'INT64' or receipt['physicalIPhoneExecution'] is not False or
            receipt['applicationChanged'] is not False or any(receipt[key] is not True for key in
                ['sameGreedyTextAndIntervals','same085Floor','sameReject005Decision'])):
        raise ValueError('Incomplete native two-input/output parity receipt')
    runtime = receipt['iosRuntime']
    if not isinstance(runtime, str) or re.fullmatch(r'(26|27)\.\d+(\.\d+)?', runtime) is None:
        raise ValueError('Unexpected native iOS Runtime')
    transform, inference = receipt['verifiedTransformProcessIdentity'], receipt['verifiedInferenceProcessIdentity']
    if (transform['udid'] != inference['udid'] or inference['compileTarget'] != 'IOS_SIMULATOR' or
            transform['simulatorCompileTarget'] is not True or count(transform['pid'], 2**31-1) == 0 or count(inference['pid'], 2**31-1) == 0):
        raise ValueError('Missing independent native process identities')
    return dict(study=receipt['study'], runtime='1.23.2', iosRuntime=runtime, actualNativeCalls=288, actualReferenceCalls=288,
        nativeRGBTransforms=292, nativeInputs=2, nativeOutputs=2, sameGreedyTextAndIntervals=True, same085Floor=True,
        sameReject005Decision=True, fullProbabilityMaxDifference=number(receipt['fullProbabilityMaxDifference'], 5e-5),
        fullRejectProbabilityMaxDifference=number(receipt['fullRejectProbabilityMaxDifference'], 5e-5),
        nativePeakRSSBytes=count(receipt['nativePeakRSSBytes'], 64*1024**3), nativeBatchSeconds=number(receipt['nativeBatchSeconds'], 1800),
        physicalIPhoneExecution=False, applicationChanged=False)


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest='kind', required=True)
    source = commands.add_parser('source')
    source.add_argument('--case', required=True)
    source.add_argument('--comparison', type=Path, required=True)
    source.add_argument('--acquisition', type=Path, required=True)
    source.add_argument('--native-log', type=Path, required=True)
    native = commands.add_parser('native'); native.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    if args.kind == 'source':
        result = source_receipt(json.loads(args.comparison.read_text()), json.loads(args.acquisition.read_text()), args.case, args.native_log.read_text())
    else:
        result = native_receipt(json.loads(args.receipt.read_text()))
    payload = json.dumps(result, sort_keys=True, separators=(',', ':'))
    payload = payload.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print('::notice title=Bounded fictional OCR research receipt::'+payload, flush=True)


if __name__ == '__main__':
    main()
