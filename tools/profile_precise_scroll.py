#!/usr/bin/env python3
"""Sample the browser during a separate precise-scroll diagnostic run.

Run inside run_memory_bounded.py. Remaining arguments go to the canonical
measure_precise_scroll.py. Sampling starts at its live SCROLL_START marker.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sample-seconds', type=int, default=8)
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    command = [sys.executable, str(root/'tools/measure_precise_scroll.py'), '--output', str(output), *arguments]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 120
        log = output/'browser.log'
        while process.poll() is None and time.monotonic() < deadline:
            if log.exists() and 'SCROLL_START ' in log.read_text(errors='replace'):
                children = subprocess.check_output(['pgrep','-P',str(process.pid)], text=True).split()
                browsers = [pid for pid in children if Path(subprocess.check_output(
                    ['ps','-p',pid,'-o','comm='], text=True).strip()).name == 'Vox']
                if len(browsers) != 1:
                    raise RuntimeError('Cannot identify unique direct browser child')
                sample = ['sample', browsers[0], str(args.sample_seconds), '-file', str(output/'sample.txt')]
                result = subprocess.run(sample, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                (output/'sampling.json').write_text(json.dumps(dict(
                    diagnostic_only=True, command=command, sample_command=sample,
                    sample_exit=result.returncode, sample_output=result.stdout), indent=2)+'\n')
                if result.returncode:
                    raise RuntimeError('Browser sampling failed')
                break
            time.sleep(.1)
        else:
            raise RuntimeError('Browser did not start native scrolling')
        captured, _ = process.communicate(timeout=120)
        (output/'driver.log').write_bytes(captured)
        if process.returncode:
            raise RuntimeError('Precise scroll diagnostic failed')
        print('Completed native scroll sample:', output, flush=True)
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()


if __name__ == '__main__':
    main()
