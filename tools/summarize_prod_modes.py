#!/usr/bin/env python3
"""Summarize paired precise-scroll runs, retaining exact instruction counts."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics


def summarize(directory, calibration=None):
    directory = Path(directory)
    attempts = json.loads((directory / 'attempts.json').read_text())
    protocol = json.loads((directory / 'protocol.json').read_text())
    restored = json.loads((directory / 'restoration.json').read_text())
    if not restored['restored'] or restored['expected'] != restored['actual']:
        raise ValueError('Canonical executable was not restored')
    factor = 1
    if calibration:
        if not .98 < calibration['converted_to_posix_ratio'] < 1.02:
            raise ValueError('CPU clock calibration failed')
        factor = calibration['mach_numer'] / calibration['mach_denom']
    rows = []
    for attempt in attempts:
        path = directory / attempt['name']
        run = json.loads((path / 'run.json').read_text())
        data = json.loads((path / 'summary.json').read_text())
        if attempt['exit'] or run['browser_exit_code'] or not run['valid']:
            raise ValueError('Invalid trial: ' + attempt['name'])
        for name, expected in protocol['runtime_inputs'].items():
            actual = run['source_and_binary_sha256'].get(name)
            if actual is not None and actual != expected:
                raise ValueError('Cohort input changed: ' + name)
        row = dict(attempt, summary={key: value for key, value in data.items()
                                    if key not in ('inputs', 'publications')}, run=run,
                   effective_diagnostic_only=attempt['cohort'] != 'timing')
        if attempt['cohort'] == 'counters':
            counter = data['instruction_measurement']
            start, end = (counter['samples'][phase] for phase in ('start', 'complete'))
            raw_cpu = sum(end[field] - start[field] for field in ('user_ns', 'system_ns'))
            cpu_ms = raw_cpu * factor / 1e6
            row['measured'] = dict(instructions=counter['instructions'], cpu_ms=cpu_ms,
                wall_ms=counter['wall_ms'], moving_publications=data['moving_intervals'],
                instructions_per_scroll_publication=counter['instructions'] / data['moving_intervals'],
                cpu_ms_per_scroll_publication=cpu_ms / data['moving_intervals'])
        rows.append(row)
    result = dict(scope='vlang.io scrolling in the canonical production bundle; only the V executable varies',
                  protocol=protocol, restoration=restored, cpu_calibration=calibration,
                  raw_cpu_note='Legacy user_ns/system_ns fields contain Mach ticks; original summaries retained; corrected CPU milliseconds are in measured/medians.' if calibration else None,
                  attempts=rows, medians={}, timing={}, paired_changes=[])
    for mode in ('single', 'parallel'):
        if len({row['executable_sha256'] for row in rows if row['mode'] == mode}) != 1:
            raise ValueError('Executable changed within a mode')
        counters = [row for row in rows if row['mode'] == mode and row['cohort'] == 'counters']
        timings = [row for row in rows if row['mode'] == mode and row['cohort'] == 'timing']
        if len(counters) != protocol['counter_pairs'] or len(timings) != protocol['timing_pairs']:
            raise ValueError('Incomplete paired cohort')
        result['medians'][mode] = {key: statistics.median(row['measured'][key] for row in counters)
                                   for key in counters[0]['measured']}
        result['timing'][mode] = [dict(name=row['name'], fps=row['summary']['mean_scroll_fps'],
            median_ms=row['summary']['scroll_interval_us']['median']/1000,
            p95_ms=row['summary']['scroll_interval_us']['p95']/1000,
            max_ms=row['summary']['scroll_interval_us']['max']/1000,
            fraction_over_budget=row['summary']['fraction_over_budget'],
            update_layer_mean_ms=row['summary']['update_layer_us']['mean']/1000,
            completed_inputs=row['summary']['completed_inputs'],
            publications=row['summary']['completed_publications']) for row in timings]
    a, b = (result['medians'][mode] for mode in ('single', 'parallel'))
    result['parallel_change_percent'] = {key: (b[key]/a[key]-1)*100 for key in a}
    for pair in range(1, protocol['counter_pairs'] + 1):
        matched = {row['mode']: row['measured'] for row in rows if row['cohort'] == 'counters' and row['pair'] == pair}
        if set(matched) != {'single', 'parallel'}:
            raise ValueError('Missing control/candidate pair')
        result['paired_changes'].append(dict(pair=pair, parallel_change_percent={
            key: (matched['parallel'][key]/matched['single'][key]-1)*100 for key in a}))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--legacy-cpu-calibration', type=Path)
    args = parser.parse_args()
    calibration = None
    if args.legacy_cpu_calibration:
        calibration = json.loads(args.legacy_cpu_calibration.read_text().splitlines()[0])
        calibration['receipt_sha256'] = hashlib.sha256(args.legacy_cpu_calibration.read_bytes()).hexdigest()
    result = summarize(args.input, calibration)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('medians', 'parallel_change_percent', 'timing')}, indent=2))


if __name__ == '__main__':
    main()
