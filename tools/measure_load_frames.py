#!/usr/bin/env python3
"""Measure the frames Vox renders while a replayed page loads in a normal window.

A capture paints the document once, after its resources are ready. A user's
window paints it as soon as it is laid out and again as scripts and resources
change it. Each trial opens the archived page (tools/page_archive.py) in an
ordinary window with an empty profile and cache, lets it run for a fixed time
and reads VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS: one line per rendered frame
that cost at least 20 ms, with its end time after the document's first frame,
its main-thread cost from frame start to end, and how many frame requests the
load-frame throttle deferred or released early. Cheaper frames are not listed.

The first frame includes document installation. Main-thread CPU covers the
whole observation, including startup. --control-env runs a matched control on
the same executable in alternating order. Run it through run_memory_bounded.
"""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import threading
import time

from measure_load_parallelism import ThreadCounters, clean_environment, digest
from page_archive import Replay, load_archive

ROOT = Path(__file__).resolve().parents[1]
FRAME = re.compile(r'^VOX_LOAD_RENDER_THROTTLE t_ms=(\d+) cost_ms=(\d+) deferred=(\d+)(?: quiet=(\d+))?$')


def parse_frames(lines):
    """Return the logged frames of the first document in [(seconds, text)]."""
    frames = []
    for seconds, line in lines:
        match = FRAME.match(line)
        if not match:
            continue
        end, cost, deferred, quiet = (int(value) if value else 0 for value in match.groups())
        # A later navigation starts its own loading window at zero.
        if frames and end == 0:
            break
        frames.append(dict(end_ms=end, cost_ms=cost, deferred=deferred, quiet_releases=quiet,
                           log_received_ms=seconds * 1000))
    return frames


def summarize_frames(frames, requests_ms):
    if not frames:
        raise ValueError('The page rendered no frame of 20 ms or more')
    first = frames[0]
    # The log line of a frame is written when it ends.
    first_end = first['log_received_ms']
    later = frames[1:]
    after_first = [value - first_end for value in requests_ms if value > first_end]
    return dict(
        first_frame_end_ms=first_end, first_frame_cost_ms=first['cost_ms'],
        later_frames=len(later), later_frame_cost_ms=[frame['cost_ms'] for frame in later],
        later_frame_end_ms=[frame['end_ms'] for frame in later],
        second_frame_end_ms=later[0]['end_ms'] if later else None,
        last_frame_end_ms=later[-1]['end_ms'] if later else 0,
        frame_cost_ms=sum(frame['cost_ms'] for frame in frames),
        deferred=frames[-1]['deferred'], quiet_releases=frames[-1]['quiet_releases'],
        last_request_after_first_frame_ms=max(after_first) if after_first else None)


def run_trial(args, counters, index, label, extra_environment):
    folder = args.output / f'{label}-{index}'
    folder.mkdir()
    profile, cache = folder / 'profile', folder / 'http-cache'
    profile.mkdir()
    cache.mkdir()
    replay = Replay(args.archive, folder / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    env = clean_environment()
    env.update(VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache), VOX_COOKIE_FILE='',
               VOX_TEST_WINDOW='1', VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
               VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS='1',
               # The allocator policy otherwise re-executes the browser once.
               MallocSpaceEfficient='1')
    for assignment in extra_environment:
        key, _, value = assignment.partition('=')
        env[key] = value
    command = [str(args.vox), '--enable-javascript', '--js-engine=' + args.js_engine,
               '--window-width', str(args.width), '--window-height', str(args.height + 112), args.url]
    lines = []
    row = dict(trial=index, variant=label, command=command, folder=str(folder),
               extra_environment=extra_environment,
               host_before=dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg()))
    launched, launched_unix = time.monotonic(), time.time()
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)

    def read_log():
        with (folder / 'browser.log').open('wb') as log:
            for line in process.stdout:
                lines.append((time.monotonic() - launched, line.decode(errors='replace').rstrip('\n')))
                log.write(line)

    reader = threading.Thread(target=read_log, daemon=True)
    reader.start()
    main, main_cpu, process_cpu = None, 0, 0
    try:
        while time.monotonic() - launched < args.seconds:
            if process.poll() is not None:
                raise RuntimeError(f'{label} trial {index} exited early ({process.returncode}); see {folder}')
            total = counters.process_cpu_ns(process.pid)
            threads = counters.threads(process.pid)
            if total is not None and threads:
                # A re-executed image replaces every thread; its first sample
                # holds only the main thread.
                if main not in threads:
                    main = max(threads, key=lambda handle: threads[handle][0])
                main_cpu, process_cpu = threads[main][0], total
            time.sleep(.005)
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        reader.join(timeout=5)
        replay.server.shutdown()
        replay.server.server_close()
    requests = [json.loads(line) for line in
                (replay.output / 'requests.jsonl').read_text().splitlines()]
    requests_ms = [(request['t_unix'] - launched_unix) * 1000 for request in requests if 'url' in request]
    row.update(host_after=dict(unix=time.time(), load=os.getloadavg()),
               replayed_requests=len(requests_ms), frames=parse_frames(lines),
               main_thread_cpu_ms=main_cpu / 1e6, process_cpu_ms=process_cpu / 1e6)
    row.update(summarize_frames(row['frames'], requests_ms))
    (folder / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    return row


def summarize(rows):
    def median(key):
        values = [row[key] for row in rows if row[key] is not None]
        return statistics.median(values) if values else None
    later = [cost for row in rows for cost in row['later_frame_cost_ms']]
    return dict(
        trials=len(rows),
        first_frame_end_ms=median('first_frame_end_ms'), first_frame_cost_ms=median('first_frame_cost_ms'),
        second_frame_end_ms=median('second_frame_end_ms'), last_frame_end_ms=median('last_frame_end_ms'),
        later_frames=median('later_frames'),
        later_frame_cost_ms=statistics.median(later) if later else None,
        frame_cost_ms=median('frame_cost_ms'), main_thread_cpu_ms=median('main_thread_cpu_ms'),
        process_cpu_ms=median('process_cpu_ms'), deferred=median('deferred'),
        quiet_releases=median('quiet_releases'), replayed_requests=sorted({row['replayed_requests'] for row in rows}),
        second_frame_end_ms_all=[row['second_frame_end_ms'] for row in rows],
        last_frame_end_ms_all=[row['last_frame_end_ms'] for row in rows],
        first_frame_cost_ms_all=[row['first_frame_cost_ms'] for row in rows])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--url', help='Defaults to the archived page URL.')
    parser.add_argument('--seconds', type=float, default=6, help='Observation time per trial.')
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('--js-engine', default='javascriptcore')
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768)
    parser.add_argument('--env', action='append', default=[], metavar='NAME=VALUE',
                        help='Extra browser environment for every trial.')
    parser.add_argument('--control-env', action='append', default=[], metavar='NAME=VALUE',
                        help='Also run a matched control with this extra environment in every '
                             'round, alternating which variant goes first.')
    args = parser.parse_args()
    args.vox, args.archive, args.output = args.vox.resolve(), args.archive.resolve(), args.output.resolve()
    args.url = args.url or load_archive(args.archive)['url']
    args.output.mkdir(parents=True, exist_ok=False)
    counters = ThreadCounters()
    identity = dict(executable=str(args.vox), executable_sha256=digest(args.vox),
                    archive=str(args.archive), manifest_sha256=digest(args.archive / 'manifest.json'))
    variants = [('candidate', args.env)]
    if args.control_env:
        variants.append(('control', args.env + args.control_env))
    rows = []
    for index in range(1, args.repeat + 1):
        for label, extra_environment in (variants if index % 2 else variants[::-1]):
            rows.append(run_trial(args, counters, index, label, extra_environment))
            if digest(args.vox) != identity['executable_sha256']:
                raise RuntimeError('Measured executable changed during the cohort')
            row = rows[-1]
            print(json.dumps(dict(variant=label, trial=index, first_frame_cost_ms=row['first_frame_cost_ms'],
                                  later_frame_end_ms=row['later_frame_end_ms'],
                                  later_frame_cost_ms=row['later_frame_cost_ms'],
                                  quiet_releases=row['quiet_releases'], deferred=row['deferred'],
                                  main_thread_cpu_ms=round(row['main_thread_cpu_ms']))), flush=True)
    summary = {label: summarize([row for row in rows if row['variant'] == label]) for label, _ in variants}
    result = dict(scope=__doc__, url=args.url, viewport=[args.width, args.height],
                  js_engine=args.js_engine, seconds=args.seconds,
                  variants={label: extra_environment for label, extra_environment in variants},
                  **identity, summary=summary, trials=rows)
    (args.output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
