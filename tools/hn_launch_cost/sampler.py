#!/usr/bin/env python3
"""Run canonical Vox HN trials with /usr/bin/sample attached to Vox and its worker.

Diagnostic only: the injected delay dylib and sampling perturb the counts.
usage: sampler.py OUTPUT RUNS --delay-library DYLIB --memory-guard-registry PATH
"""
import argparse, subprocess, sys, threading, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import hacker_news_launch_pilot as driver  # noqa: E402
from hn_launch_cost import aggregate  # noqa: E402
hn = driver.hn


def children(pid):
    out = subprocess.run(['/bin/ps', '-axo', 'pid=,ppid=,comm='], capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[1].isdigit() and int(parts[1]) == pid:
            rows.append((int(parts[0]), parts[2]))
    return rows


def sample_statistics(folder):
    records = {}
    for name in ['vox', 'worker']:
        path = folder / f'sample-{name}.txt'
        trees = aggregate.parse(path) if path.is_file() else []
        records[name] = dict(threads=len(trees), busy_samples=sum(aggregate.busy(tree) for tree in trees))
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('runs', type=int)
    parser.add_argument('--app', type=Path, default=driver.REPO / 'Build/v/Vox.app')
    parser.add_argument('--seconds', type=int, default=7)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--delay-library', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, default=driver.REPO / 'Build/pixel-tools/pixel_diff')
    options = parser.parse_args()
    if options.runs < 1 or options.seconds < 1:
        parser.error('Need positive run and sample-duration counts')
    args = driver.prepare_capture(options.output, options.diff_tool,
                                  options.memory_guard_registry, timeout=180)
    environment = dict(DYLD_INSERT_LIBRARIES=str(options.delay_library.resolve(strict=True)),
                       VOXPROBE_DELAY_MS='1500', VOXPROBE_EXIT_DELAY_MS='4000', MallocSpaceEfficient='1')
    app = options.app.absolute()
    binary = app / 'Contents/MacOS/Vox'
    variant = dict(name='sampled', app=str(app), environment=environment)
    paths = driver.input_paths(args, [variant]) | {Path(__file__), HERE / 'delay.c'}
    pinned = hn.fingerprint(paths)
    hn.write_json(args.output / 'inputs.json', dict(files=pinned, variant=variant,
        diagnostic_only=True, command=sys.argv, scope=hn.LAUNCH_SCOPE))
    rows = []
    with hn.fixture_server(args.document, args.output, args.home_archive) as args.url:
        for run in range(1, options.runs + 1):
            folder = args.output / f'trial-{run}-sampled'
            png = str(folder / 'document.png')
            samplers = []

            def attach():
                deadline = time.monotonic() + 20
                root = None
                while time.monotonic() < deadline and not root:
                    try:
                        root = hn.root_for(binary, png)
                    except Exception:
                        root = None
                    time.sleep(.01)
                if not root:
                    return
                samplers.append(subprocess.Popen(['/usr/bin/sample', str(root['pid']), str(options.seconds), '1',
                    '-file', str(folder / 'sample-vox.txt')], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT))
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    workers = [pid for pid, comm in children(root['pid']) if comm.endswith('VoxAdblockWorker')]
                    if workers:
                        samplers.append(subprocess.Popen(['/usr/bin/sample', str(workers[0]), str(options.seconds), '1',
                            '-file', str(folder / 'sample-worker.txt')], stdout=subprocess.DEVNULL,
                            stderr=subprocess.STDOUT))
                        return
                    time.sleep(.005)

            thread = threading.Thread(target=attach)
            thread.start()
            result = driver.checked_trial(args, variant, run, paths, pinned)
            thread.join()
            result['sampler_exits'] = [process.wait() for process in samplers]
            result['samples'] = sample_statistics(folder)
            if (len(samplers) != 2 or any(result['sampler_exits'])
                    or not all(record['threads'] for record in result['samples'].values())):
                result.update(exit=1, error='Both browser and worker samples must contain stacks and finish successfully')
            rows.append(result)
            hn.write_json(args.output / 'rows.json', rows)
            print(run, result, [p.name for p in folder.glob('sample-*.txt')], flush=True)
    return 0 if all(row['exit'] == 0 for row in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
