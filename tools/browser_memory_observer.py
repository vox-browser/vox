"""Opt-in external browser memory sampling, independent of instruction claims."""
import gzip
import json
import time

from process_instruction_counts import CounterSampler, MacCounters
from wikipedia_browser_memory import PhysicalTree


def summarize_peak(samples, root_pid, root_start):
    live = [row for row in samples if row['processes']]
    if len(live) < 5:
        raise RuntimeError('Insufficient live browser memory samples')
    for row in live:
        if row['physical_footprint_bytes'] != sum(p['physical_footprint_bytes'] for p in row['processes']):
            raise RuntimeError('Memory total must sum simultaneous task readings')
        if any(p['pid'] == root_pid and p['start_ticks'] != root_start for p in row['processes']):
            raise RuntimeError('Browser root identity changed')
    peak = max(live, key=lambda row: row['physical_footprint_bytes'])
    return dict(metric='observed simultaneous process-tree physical footprint',
                observed_peak_bytes=peak['physical_footprint_bytes'],
                peak_sample=peak, sample_count=len(live),
                first_sample_seconds=live[0]['seconds'], last_sample_seconds=live[-1]['seconds'],
                max_sample_gap_seconds=max(b['seconds'] - a['seconds'] for a, b in zip(live, live[1:])),
                scope='Fresh root discovery through normal browser exit, including capture and semantic audits; observed descendants retained across reparenting. Observer/replay and external services excluded.',
                limitations='Polling lower bound; earlier startup and short-lived unsampled helpers may be missed. Physical footprint is macOS charged memory, not summed RSS or a sum of task lifetime maxima.')


class BrowserMemoryObserver:
    def __init__(self, pid, start, folder, interval=.02):
        if MacCounters().read(pid).start != start:
            raise RuntimeError('Browser identity changed before memory sampling')
        self.pid, self.start, self.folder = pid, start, folder
        self.counter = PhysicalTree(pid, time.monotonic())
        self.sampler = CounterSampler(self.counter, interval)
        self.sampler.__enter__()

    def finish(self):
        self.sampler.__exit__(None, None, None)
        path = self.folder / 'memory-samples.json.gz'
        path.write_bytes(gzip.compress(json.dumps(self.counter.samples).encode(), mtime=0))
        return dict(summarize_peak(self.counter.samples, self.pid, self.start), raw_samples=str(path))
