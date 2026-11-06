#!/usr/bin/env python3
"""Reconcile calling-main-thread scopes with a separate full coalition endpoint.

The original process-counter stage stream remains independently parseable.
The residual includes other threads, helpers and endpoint sampling skew; it
cannot be attributed wholesale to JavaScript or to any other subsystem.
"""
import argparse
import csv
import json
from pathlib import Path

from summarize_load_stages import summarize


def summarize_main_thread(text, pid=None):
    translated = []
    for line in text.splitlines():
        if line.startswith('Vox thread instructions unavailable:'):
            raise ValueError('Unavailable main-thread capture counter')
        if line.startswith('Vox thread instruction stage '):
            translated.append(line.replace('Vox thread instruction stage ',
                                           'Vox instruction stage ', 1))
        elif line.startswith('Vox thread instructions cumulative:'):
            translated.append(line.replace('Vox thread instructions cumulative:',
                                           'Vox instructions cumulative:', 1))
        elif line.startswith('Vox coalition instructions:'):
            translated.append(line)
    result = summarize('\n'.join(translated), pid)
    result['main_thread_instructions'] = result.pop('process_instructions')
    for row in result['rows']:
        if row['stage'] == 'unscoped_process':
            row['stage'] = 'unscoped_main_thread'
        elif row['stage'] == 'coalition_endpoint_remainder':
            row['stage'] = 'other_threads_helpers_and_endpoint_skew'
    result['counter'] = 'calling-main-thread hardware instructions (XNU THSC_CPI)'
    result['qualification'] = (
        'Exclusive main-thread instruction scopes subtract nested children; '
        'inclusive totals overlap. Open scopes are clipped at the main-thread '
        'encoded-PNG reading. The full coalition endpoint is independently '
        'sampled and retained. Its signed difference from main-thread cumulative '
        'instructions includes other threads, owned helpers and sampling skew; '
        'it is not an isolated JavaScript-engine count. Tracing overhead remains '
        'included. No scaling to another run or optimization credit.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pid', type=int)
    args = parser.parse_args()
    result = summarize_main_thread(args.log.read_text(), args.pid)
    args.output.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    with args.output.with_suffix('.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(result['rows'][0]))
        writer.writeheader()
        writer.writerows(result['rows'])
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
