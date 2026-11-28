#!/usr/bin/env python3
"""Measure how many cores Vox uses while it loads and renders a replayed page.

Each trial launches a fresh process with an empty profile and cache against an
offline page archive (tools/page_archive.py). A sampler reads cumulative CPU
time of every thread through libproc until the document PNG is written, so the
report separates main-thread work from work that ran on other threads.

Reported intervals start at process launch and end when the encoded document
PNG is complete. They include startup, replayed fetches, scripts, layout,
raster and PNG encoding. Wall times include the local replay proxy's latency.
Thread CPU is polled: a thread that exits between two samples loses its last
interval, so per-thread sums are lower bounds; the process total comes from
rusage and includes exited threads. GPU execution and helper processes are not
counted. This is a parallelism diagnostic, not an instruction acceptance gate.

--control-env adds a matched control on the same executable: every round runs
both variants, alternating which goes first, and the summary states whether
all their captures have identical bytes. A hydrating page needs
--ready-selector: without one, 2 of 30 GitHub captures were taken between two
script phases, with fewer replayed requests and other pixels. Run it through
run_memory_bounded.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import threading
import time

from page_archive import Replay, load_archive
from process_instruction_counts import RusageInfoV4

ROOT = Path(__file__).resolve().parents[1]
PNG_END_CHUNK = b'\x00\x00\x00\x00IEND\xaeB`\x82'
PROC_PIDTHREADINFO, PROC_PIDLISTTHREADS = 5, 6
# A thread counts as busy in a sampling interval when it ran for at least this
# share of it.
BUSY_SHARE = 0.5


class ThreadInfo(ctypes.Structure):
    _fields_ = [('user', ctypes.c_uint64), ('system', ctypes.c_uint64),
                ('cpu_usage', ctypes.c_int32), ('policy', ctypes.c_int32),
                ('run_state', ctypes.c_int32), ('flags', ctypes.c_int32),
                ('sleep_time', ctypes.c_int32), ('curpri', ctypes.c_int32),
                ('priority', ctypes.c_int32), ('maxpriority', ctypes.c_int32),
                ('name', ctypes.c_char * 64)]


class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]


class ThreadCounters:
    """libproc thread times are nanoseconds; rusage times are Mach ticks."""
    def __init__(self):
        self.lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64,
                                          ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_pidinfo.restype = ctypes.c_int
        self.lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.lib.proc_pid_rusage.restype = ctypes.c_int
        timebase = Timebase()
        ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_timebase_info(ctypes.byref(timebase))
        self.numer, self.denom = timebase.numer, timebase.denom
        self.handles = (ctypes.c_uint64 * 1024)()

    def process_cpu_ns(self, pid):
        usage = RusageInfoV4()
        if self.lib.proc_pid_rusage(pid, 4, ctypes.byref(usage)) != 0:
            return None
        return (usage.ri_user_time + usage.ri_system_time) * self.numer // self.denom

    def threads(self, pid):
        """Return {handle: (cpu_ns, name)} for the live threads of pid."""
        size = self.lib.proc_pidinfo(pid, PROC_PIDLISTTHREADS, 0, self.handles,
                                     ctypes.sizeof(self.handles))
        result = {}
        info = ThreadInfo()
        for handle in self.handles[:max(size, 0) // 8]:
            if self.lib.proc_pidinfo(pid, PROC_PIDTHREADINFO, handle, ctypes.byref(info),
                                     ctypes.sizeof(info)) == ctypes.sizeof(info):
                result[handle] = (info.user + info.system, info.name.decode(errors='replace'))
        return result


def clean_environment():
    return {key: value for key, value in os.environ.items()
            if not key.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_'))
            and 'proxy' not in key.lower()}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def png_complete(path):
    try:
        with path.open('rb') as handle:
            handle.seek(-len(PNG_END_CHUNK), os.SEEK_END)
            return handle.read() == PNG_END_CHUNK
    except (OSError, ValueError):
        return False


def summarize_samples(samples, main, start, end):
    """Reduce [(seconds, process_cpu_ns, {handle: (cpu_ns, name)})] to one interval."""
    window = [sample for sample in samples if start <= sample[0] <= end]
    if len(window) < 2:
        raise ValueError('Too few thread samples in the measured interval')
    first, last = window[0], window[-1]
    wall = last[0] - first[0]
    process_cpu = (last[1] - first[1]) / 1e9
    per_thread = {}
    for handle, (cpu, name) in last[2].items():
        before = first[2].get(handle, (0, ''))[0]
        per_thread[handle] = [(cpu - before) / 1e9, name]
    # Threads that exited inside the window keep their last observed total.
    for _, _, threads in window:
        for handle, (cpu, name) in threads.items():
            if handle not in last[2]:
                before = first[2].get(handle, (0, ''))[0]
                value = (cpu - before) / 1e9
                if handle not in per_thread or value > per_thread[handle][0]:
                    per_thread[handle] = [value, name]
    main_cpu = per_thread.get(main, [0.0, ''])[0]
    busy_seconds = {}
    for previous, current in zip(window, window[1:]):
        interval = current[0] - previous[0]
        if interval <= 0:
            continue
        busy = 0
        for handle, (cpu, _) in current[2].items():
            before = previous[2].get(handle)
            if before is not None and (cpu - before[0]) / 1e9 >= BUSY_SHARE * interval:
                busy += 1
        busy_seconds[busy] = busy_seconds.get(busy, 0.0) + interval
    named = {}
    for handle, (cpu, name) in per_thread.items():
        label = 'main' if handle == main else (name or 'unnamed')
        named[label] = named.get(label, 0.0) + cpu
    top = sorted(named.items(), key=lambda item: -item[1])[:12]
    return dict(
        wall_ms=wall * 1000, process_cpu_ms=process_cpu * 1000, main_thread_cpu_ms=main_cpu * 1000,
        other_threads_cpu_ms=(process_cpu - main_cpu) * 1000,
        main_thread_share=main_cpu / process_cpu if process_cpu else None,
        average_busy_cores=process_cpu / wall if wall else None,
        main_thread_utilization=main_cpu / wall if wall else None,
        wall_ms_with_two_or_more_busy_threads=sum(
            seconds for count, seconds in busy_seconds.items() if count >= 2) * 1000,
        wall_ms_by_busy_thread_count={str(count): seconds * 1000
                                      for count, seconds in sorted(busy_seconds.items())},
        sample_count=len(window),
        top_threads_cpu_ms=[[label, cpu * 1000] for label, cpu in top])


def run_trial(args, counters, index, label, extra_environment):
    folder = args.output / f'{label}-{index}'
    folder.mkdir()
    profile, cache, png = folder / 'profile', folder / 'http-cache', folder / 'document.png'
    profile.mkdir()
    cache.mkdir()
    replay = Replay(args.archive, folder / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    env = clean_environment()
    env.update(VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache), VOX_COOKIE_FILE='',
               VOX_TEST_WINDOW='1', VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
               VOX_CAPTURE_DOCUMENT_ONLY='1',
               LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds),
               LADYBIRD_SCREENSHOT_SCALE=str(args.screenshot_scale),
               # The allocator policy otherwise re-executes the browser once.
               MallocSpaceEfficient='1')
    if args.ready_selector:
        env['VOX_CAPTURE_READY_SELECTOR'] = args.ready_selector
    if args.first_submission:
        # The first-submission timer needs the instruction endpoints, whose
        # readings add work to every frame. Keep it out of plain timing cohorts.
        env.update(VOX_MEASURE_NATIVE_SUBMISSION='1', VOX_PROFILE_INSTRUCTIONS='1')
    for assignment in extra_environment:
        key, _, value = assignment.partition('=')
        env[key] = value
    command = [str(args.vox), '--enable-javascript', '--js-engine=' + args.js_engine,
               '--window-width', str(args.width), '--window-height', str(args.height + 112),
               '--screenshot-viewport-height', str(args.height), '--screenshot', str(png), args.url]
    samples, lines = [], []
    row = dict(trial=index, variant=label, command=command, folder=str(folder),
               extra_environment=extra_environment,
               host_before=dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg()))
    process = None
    try:
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
        main = None
        png_at = None
        deadline = launched + args.timeout
        while process.poll() is None:
            now = time.monotonic()
            if now > deadline:
                raise TimeoutError('Page capture timed out')
            total = counters.process_cpu_ns(process.pid)
            threads = counters.threads(process.pid)
            if total is not None and threads:
                # The allocator policy can re-execute the browser, which replaces
                # the task and every thread handle. A new image has run only its
                # main thread when it is first sampled: pick its busiest handle.
                if main not in threads:
                    main = max(threads, key=lambda handle: threads[handle][0])
                    row['threads_when_main_identified'] = len(threads)
                    row['main_identified_ms'] = (now - launched) * 1000
                samples.append((now - launched, total, threads))
            if png_at is None and png_complete(png):
                png_at = now - launched
            time.sleep(args.sample_interval)
        row['exit'] = process.wait()
        row['exit_ms'] = (time.monotonic() - launched) * 1000
        reader.join(timeout=5)
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        replay.server.shutdown()
        replay.server.server_close()
    row['host_after'] = dict(unix=time.time(), load=os.getloadavg())
    if row.get('exit') != 0 or png_at is None:
        raise RuntimeError(f'{label} trial {index} failed (exit {row.get("exit")}); see {folder}')
    requests = [json.loads(line) for line in
                (replay.output / 'requests.jsonl').read_text().splitlines()]
    missing = [request for request in requests if request.get('archived') is False]
    timings = {}
    for seconds, line in lines:
        if line.startswith('Ladybird V timing: ') and line.endswith(' ms'):
            name, value = line[len('Ladybird V timing: '):-3].rsplit(' ', 1)
            timings.setdefault(name, dict(reported_ms=int(value), log_received_ms=seconds * 1000))
    row.update(png_ms=png_at * 1000, png_sha256=digest(png), replayed_requests=len(requests),
               unarchived_requests=len(missing), native_timings=timings,
               launch_to_png=summarize_samples(samples, main, 0, png_at))
    submission = timings.get('navigation_to_first_native_layer_submission')
    if submission:
        row['launch_to_first_submission'] = summarize_samples(
            samples, main, 0, submission['log_received_ms'] / 1000)
    (folder / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    # Cumulative milliseconds per sample, for locating idle and serial spans.
    timeline = [[round(seconds * 1000, 3), round(total / 1e6, 3),
                 round(threads.get(main, (0, ''))[0] / 1e6, 3)] for seconds, total, threads in samples]
    (folder / 'timeline.json').write_text(json.dumps(dict(
        columns=['ms_since_launch', 'process_cpu_ms', 'main_thread_cpu_ms'], launched_unix=launched_unix,
        samples=timeline, log=[[round(seconds * 1000, 3), line] for seconds, line in lines])) + '\n')
    return row


def median_of(rows, section, key):
    values = [row[section][key] for row in rows if section in row and row[section][key] is not None]
    return statistics.median(values) if values else None


def summarize(rows):
    summary = dict(trials=len(rows), png_sha256=sorted({row['png_sha256'] for row in rows}),
                   # Captures of one page state replay the same requests; a
                   # smaller count marks a capture taken before the page settled.
                   replayed_requests=sorted({row['replayed_requests'] for row in rows}))
    for section in ['launch_to_png', 'launch_to_first_submission']:
        summary[section] = {key: median_of(rows, section, key) for key in [
            'wall_ms', 'process_cpu_ms', 'main_thread_cpu_ms', 'other_threads_cpu_ms',
            'main_thread_share', 'average_busy_cores', 'main_thread_utilization',
            'wall_ms_with_two_or_more_busy_threads']}
        summary[section]['wall_ms_all'] = [row[section]['wall_ms'] for row in rows if section in row]
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--url', help='Defaults to the archived page URL.')
    parser.add_argument('--repeat', type=int, default=5)
    parser.add_argument('--js-engine', default='javascriptcore')
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768)
    parser.add_argument('--settle-seconds', type=float, default=0)
    parser.add_argument('--screenshot-scale', type=int, default=1, choices=[1, 2],
                        help='2 rasterizes the document at the density of a Retina window.')
    parser.add_argument('--sample-interval', type=float, default=.002)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--ready-selector', metavar='SELECTOR',
                        help='Capture only after this selector matches. A page that hydrates '
                             'can otherwise be captured between two of its script phases.')
    parser.add_argument('--first-submission', action='store_true',
                        help='Also report launch to the first submitted document layer (instrumented).')
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
                    archive=str(args.archive),
                    manifest_sha256=digest(args.archive / 'manifest.json'))
    variants = [('candidate', args.env)]
    if args.control_env:
        variants.append(('control', args.env + args.control_env))
    rows = []
    for index in range(1, args.repeat + 1):
        # Alternate the order between rounds to reduce order and warm-up bias.
        for label, extra_environment in (variants if index % 2 else variants[::-1]):
            rows.append(run_trial(args, counters, index, label, extra_environment))
            if digest(args.vox) != identity['executable_sha256']:
                raise RuntimeError('Measured executable changed during the cohort')
            print(json.dumps(dict(variant=label, trial=index, png_ms=round(rows[-1]['png_ms']),
                                  **{key: round(value, 3)
                                     for key, value in rows[-1]['launch_to_png'].items()
                                     if isinstance(value, float)})), flush=True)
    summary = {label: summarize([row for row in rows if row['variant'] == label])
               for label, _ in variants}
    result = dict(scope=__doc__, url=args.url, viewport=[args.width, args.height],
                  js_engine=args.js_engine, screenshot_scale=args.screenshot_scale,
                  ready_selector=args.ready_selector,
                  variants={label: extra_environment for label, extra_environment in variants},
                  first_submission_instrumented=args.first_submission, **identity,
                  summary=summary, trials=rows)
    if args.control_env:
        result['variants_render_identical_pixels'] = (
            summary['candidate']['png_sha256'] == summary['control']['png_sha256']
            and len(summary['candidate']['png_sha256']) == 1)
    (args.output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items()
                      if key in ('summary', 'variants_render_identical_pixels')}, indent=2))


if __name__ == '__main__':
    main()
