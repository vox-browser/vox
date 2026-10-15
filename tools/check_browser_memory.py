#!/usr/bin/env python3
"""Check repeated Vox/Chrome memory observations against the 20% reduction target."""

import argparse
import json
from pathlib import Path
import statistics


def compare(vox, chrome, max_ratio=.8):
    if not vox or not chrome or not 0 < max_ratio < 1:
        raise ValueError('Both browser cohorts and a ratio between zero and one are required')
    reference = chrome[0]
    for engine, cohort in [('vox', vox), ('chrome', chrome)]:
        for sample in cohort:
            if sample['engine'] != engine:
                raise ValueError('Observation belongs to the wrong browser cohort')
            for key in ['metric', 'url', 'viewport', 'settle_seconds', 'native_display_backing_scale']:
                if sample[key] != reference[key]:
                    raise ValueError('Mismatched comparison condition: ' + key)
            if not sample['matched_native_raster_scale']:
                raise ValueError('Chrome and Vox must use the same raster scale')
            if not sample.get('foreground_controlled') or not sample.get('activation', {}).get('active'):
                raise ValueError('Both browsers must be activated for the foreground comparison')
            if engine == 'chrome':
                document = sample.get('document', {})
                if not document.get('focused') or document.get('visibility') != 'visible':
                    raise ValueError('Chrome must remain visible and focused through the settled observation')
                if (document.get('url') != sample['url']
                        or [document.get('width'), document.get('height')] != sample['viewport']
                        or document.get('scale') != sample['native_display_backing_scale']):
                    raise ValueError('Chrome document audit does not match the requested comparison')
            if (sample.get('diagnostic_library') or sample.get('collector_overrides')
                    or sample.get('runtime_overrides')):
                raise ValueError('Diagnostic instrumentation/collector overrides cannot establish the target')
            if sample['binary_sha256'] != cohort[0]['binary_sha256']:
                raise ValueError('Browser executable changed within a cohort')
            runtime_hashes = lambda item: {key: value['sha256'] for key, value in item.get('runtime_files', {}).items()}
            if runtime_hashes(sample) != runtime_hashes(cohort[0]):
                raise ValueError('Browser runtime inputs changed within a cohort')
            if engine == 'vox' and '--enable-javascript' not in sample['command']:
                raise ValueError('Vox must enable JavaScript for the Chrome comparison')
    summary = {}
    for engine, cohort in [('vox', vox), ('chrome', chrome)]:
        steady = [s['memory']['steady_bytes'] for s in cohort]
        peak = [s['memory']['peak_simultaneous_bytes'] for s in cohort]
        if min(steady + peak) <= 0:
            raise ValueError('Memory observations must be positive')
        summary[engine] = {
            'steady_bytes': statistics.median(steady),
            'peak_bytes': statistics.median(peak),
            'steady_runs_bytes': steady,
            'peak_runs_bytes': peak,
        }
    ratio = summary['vox']['steady_bytes'] / summary['chrome']['steady_bytes']
    return {
        'summary': summary,
        'maximum_vox_ratio': max_ratio,
        'steady_reduction_percent': 100 * (1 - ratio),
        'peak_reduction_percent': 100 * (1 - summary['vox']['peak_bytes'] / summary['chrome']['peak_bytes']),
        'target_met': ratio <= max_ratio,
        'all_vox_runs_below_target_for_all_chrome_runs': (
            max(summary['vox']['steady_runs_bytes']) <= max_ratio * min(summary['chrome']['steady_runs_bytes'])),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, nargs='+', required=True)
    parser.add_argument('--chrome', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--max-ratio', type=float, default=.8)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Preserve prior comparison: ' + str(args.output))
    result = compare([json.loads(p.read_text()) for p in args.vox],
                     [json.loads(p.read_text()) for p in args.chrome], args.max_ratio)
    result['observations'] = {'vox': [str(p) for p in args.vox], 'chrome': [str(p) for p in args.chrome]}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['target_met'] else 1)


if __name__ == '__main__':
    main()
