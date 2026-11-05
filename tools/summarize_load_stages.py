#!/usr/bin/env python3
"""Reconcile nested main-thread stage intervals with the capture CPU budget.

Stages read process-wide counters, including concurrent threads. Exclusive
counts subtract measured children; inclusive counts must never be added.
Coalition minus process is an explicitly unattributed endpoint reconciliation.
"""
import argparse
import collections
import csv
import json
from pathlib import Path
import re


BEGIN = re.compile(r'^Vox instruction stage begin: (\d+) (\d+) (\d+) ([a-z_]+)$')
END = re.compile(r'^Vox instruction stage end: (\d+) (\d+) (\d+)$')
CHECKPOINT = re.compile(r'^Vox instructions cumulative: (.*?) (\d+)$')
COALITION = 'Vox coalition instructions: '


def capture_boundary(text):
    checkpoints = []
    coalitions = []
    for line in text.splitlines():
        if match := CHECKPOINT.fullmatch(line):
            if match[1].strip() == 'capture_document_encoded':
                checkpoints.append(int(match[2]))
        elif line.startswith(COALITION):
            record = json.loads(line[len(COALITION):])
            if record['label'] == 'capture_document_encoded':
                coalitions.append(record)
    if len(checkpoints) != 1 or len(coalitions) != 1:
        raise ValueError('Expected exactly one process and coalition PNG endpoint')
    if not checkpoints[0] > 0 or not coalitions[0]['instructions'] > 0:
        raise ValueError('Unavailable capture counters')
    return checkpoints[0], coalitions[0]


def summarize(text, pid=None):
    process_end, coalition = capture_boundary(text)
    for line in text.splitlines():
        if line.startswith('Vox instruction stage begin:') and not BEGIN.fullmatch(line):
            raise ValueError('Malformed stage event')
        if line.startswith('Vox instruction stage end:') and not END.fullmatch(line):
            raise ValueError('Malformed stage event')
    events = [match for line in text.splitlines() if (match := BEGIN.fullmatch(line))]
    processes = {int(match[1]) for match in events}
    roots = {int(match[1]) for match in events if match[4] == 'browser_main'}
    if pid is None:
        choices = roots or processes
        if len(choices) != 1:
            raise ValueError('Expected one stage process or an explicit PID')
        pid = next(iter(choices))
    stack = []
    seen = set()
    totals = collections.defaultdict(lambda: dict(calls=0, partial_calls=0,
                                                exclusive=0, inclusive=0))
    previous = 0
    root_total = 0
    capture_phase = None
    capture_parents = set()
    transfers = collections.Counter()

    def close(count, partial=False):
        nonlocal root_total
        frame = stack.pop()
        inclusive = count - frame['start']
        exclusive = inclusive - frame['children']
        if exclusive < 0:
            raise ValueError('Child instructions exceed parent')
        row = totals[frame['label']]
        row['calls'] += 1
        row['partial_calls'] += int(partial)
        row['inclusive'] += inclusive
        row['exclusive'] += exclusive
        if stack:
            stack[-1]['children'] += inclusive
        else:
            root_total += inclusive

    for line in text.splitlines():
        if line.startswith('Vox instruction stage unavailable:'):
            owner = line.split(':', 1)[1].strip().split()[0]
            if owner == str(pid):
                raise ValueError('Unavailable stage counter')
            continue
        begin = BEGIN.fullmatch(line)
        end = END.fullmatch(line)
        point = CHECKPOINT.fullmatch(line)
        capture_label = point[1].strip() if point else None
        is_capture = capture_label in ['capture_started', 'capture_cached',
                                       'capture_converted', 'capture_document_encoded']
        if not begin and not end and not is_capture:
            if line.startswith(('Vox instruction stage begin:', 'Vox instruction stage end:')):
                raise ValueError('Malformed stage event')
            continue
        if (begin or end) and int(begin[1] if begin else end[1]) != pid:
            continue
        count = int(begin[3] if begin else end[3] if end else point[2])
        if count > process_end:
            break
        if count < previous:
            raise ValueError('Nonmonotonic stage counter')
        if capture_phase and (not stack or stack[-1]['id'] in capture_parents):
            source = stack[-1]['label'] if stack else 'unscoped_process'
            transfers[source, capture_phase] += count - previous
        previous = count
        if is_capture:
            if capture_label == 'capture_started':
                capture_phase = 'capture_snapshot'
                capture_parents = {frame['id'] for frame in stack}
            elif capture_label == 'capture_cached' and capture_phase:
                capture_phase = 'capture_conversion'
            elif capture_label == 'capture_converted' and capture_phase:
                capture_phase = 'png_encoding'
            elif capture_label == 'capture_document_encoded':
                capture_phase = None
            continue
        identity = int(begin[2] if begin else end[2])
        if begin:
            if not identity or identity in seen:
                raise ValueError('Duplicate or zero stage identity')
            seen.add(identity)
            stack.append(dict(id=identity, start=count, label=begin[4], children=0))
        else:
            if not stack or stack[-1]['id'] != identity:
                raise ValueError('Unbalanced stage nesting')
            close(count)
    if not seen:
        raise ValueError('No nested stage events')
    while stack:
        close(process_end, True)
    if sum(row['exclusive'] for row in totals.values()) != root_total:
        raise ValueError('Exclusive stage totals do not reconcile')
    unscoped = process_end - root_total
    if unscoped < 0:
        raise ValueError('Stages exceed process endpoint')
    totals['unscoped_process'] = dict(calls=0, partial_calls=0, exclusive=unscoped,
                                      inclusive=None)
    for (source, target), instructions in transfers.items():
        totals[source]['exclusive'] -= instructions
        if totals[source]['exclusive'] < 0:
            raise ValueError('Capture attribution exceeds parent self work')
        totals[target]['exclusive'] += instructions
        totals[target]['inclusive'] = None
        totals[target]['calls'] = 1
    rows = [dict(stage=label, **values) for label, values in totals.items()]
    remainder = coalition['instructions'] - process_end
    rows.append(dict(stage='coalition_endpoint_remainder', calls=0, partial_calls=0,
                     exclusive=remainder, inclusive=None))
    for row in rows:
        row['percent'] = 100 * row['exclusive'] / coalition['instructions']
    rows.sort(key=lambda row: row['exclusive'], reverse=True)
    assert sum(row['exclusive'] for row in rows) == coalition['instructions']
    return dict(pid=pid, process_instructions=process_end,
                coalition_instructions=coalition['instructions'], coalition=coalition,
                rows=rows, complete=True,
                qualification='Exclusive process-interval attribution with measured children '
                'subtracted; concurrent threads and tracing overhead remain included. Open '
                'scopes are clipped at encoded PNG and marked partial. Inclusive counts '
                'overlap and are non-additive. Existing native capture checkpoints split '
                'snapshot/conversion/encoding out of parent self work; child scopes entered '
                'during capture retain their own attribution. The coalition endpoint remainder includes '
                'owned helpers and process/coalition boundary differences; it is not a '
                'separately measured helper stage. No scaling to a different run.')


def legacy_intervals(text):
    """Exact accounting of old checkpoint gaps, not exclusive function costs."""
    process_end, coalition = capture_boundary(text)
    totals = collections.Counter()
    counts = collections.Counter()
    previous = 0
    for line in text.splitlines():
        if not (match := CHECKPOINT.fullmatch(line)):
            continue
        count = int(match[2])
        if count < previous:
            raise ValueError('Nonmonotonic checkpoint counter')
        label = match[1].strip()
        totals[label] += count - previous
        counts[label] += 1
        previous = count
        if label == 'capture_document_encoded':
            break
    if previous != process_end:
        raise ValueError('Missing process capture endpoint')
    rows = [dict(checkpoint=label, instructions=value, calls=counts[label])
            for label, value in totals.items()]
    rows.append(dict(checkpoint='coalition_endpoint_remainder',
                     instructions=coalition['instructions'] - process_end, calls=0))
    assert sum(row['instructions'] for row in rows) == coalition['instructions']
    return dict(complete=True, process_instructions=process_end,
                coalition_instructions=coalition['instructions'], rows=rows,
                qualification='Non-overlapping gaps ending at named checkpoints. A gap can '
                'include preceding unmarked parent work; its name is not a pure function '
                'attribution. Nested scope records are excluded. No retroactive attribution.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--legacy', action='store_true')
    parser.add_argument('--pid', type=int, help='Audited browser process; required if ambiguous')
    args = parser.parse_args()
    text = args.log.read_text()
    result = legacy_intervals(text) if args.legacy else summarize(text, args.pid)
    args.output.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    rows = result['rows']
    with args.output.with_suffix('.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
