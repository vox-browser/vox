#!/usr/bin/env python3
"""Exercise the real injected publication probe with late document/chrome paints.

Run through tools/run_memory_bounded.py with a 3 GiB focused-test budget.
The Cocoa fixture creates no visible window and sends no physical input.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    probe_source = ROOT/'tools/measure_page_switch_darwin.m'
    fixture_source = ROOT/'tools/page_switch_probe_test_darwin.m'
    probe, fixture = output/'probe.dylib', output/'fixture'
    evidence = dict(pins={str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in [probe_source, fixture_source, Path(__file__).resolve()]})
    try:
        for name, source, target, extra in [('probe', probe_source, probe, ['-dynamiclib']),
                                           ('fixture', fixture_source, fixture, [])]:
            command = ['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-fobjc-arc', *extra,
                       str(source), '-framework', 'Cocoa', '-framework', 'QuartzCore', '-o', str(target)]
            with (output/(name+'-compile.log')).open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            evidence[name+'_compile_exit_code'] = result.returncode
            if result.returncode:
                raise RuntimeError(name+' compile failed')
        env = {k: v for k, v in os.environ.items() if not k.startswith(('VOX_', 'DYLD_'))}
        env.update(DYLD_INSERT_LIBRARIES=str(probe), VOX_SWITCH_OUTPUT=str(output),
                   VOX_SWITCH_FROM='https://old.reddit.com/r/example/',
                   VOX_SWITCH_TO='https://old.reddit.com/r/example/new/',
                   VOX_SWITCH_FROM_TITLE='hot source', VOX_SWITCH_TO_TITLE='new destination',
                   VOX_SWITCH_SETTLE='0', VOX_SWITCH_QUIET='.7')
        with (output/'test.log').open('w') as log:
            result = subprocess.run([str(fixture)], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=10)
        evidence['test_exit_code'] = result.returncode
        text = (output/'test.log').read_text()
        assert result.returncode == 0 and text.count('PAGE_SWITCH_DONE') == 1, text
        first = re.search(r'PAGE_SWITCH_RESULT navigation_ms=([\d.]+).*published_s=([\d.]+)', text)
        stable = re.search(r'PAGE_SWITCH_STABLE navigation_ms=([\d.]+).*published_s=([\d.]+) document_publications=(\d+)', text)
        paints = re.findall(r'FIXTURE_PAINT phase=(\d) chrome=(\d) before=([\d.]+) after=([\d.]+)', text)
        assert first and stable and len(paints) == 3, text
        assert float(first[1]) < float(stable[1]) and int(stable[3]) == 2, text
        assert float(paints[0][2]) <= float(first[2]) <= float(paints[0][3]), text
        assert float(paints[1][2]) <= float(stable[2]) <= float(paints[1][3]), text
        images = {name: Image.open(output/(name+'.png')).convert('RGBA')
                  for name in ['first-new', 'loaded-new', 'settled-new']}
        scale = images['first-new'].width/64
        docs = {name: image.crop((0, round(60*scale), image.width, round(124*scale)))
                for name, image in images.items()}
        assert ImageChops.difference(docs['first-new'], docs['loaded-new']).convert('RGB').getbbox()
        assert not ImageChops.difference(docs['loaded-new'], docs['settled-new']).convert('RGB').getbbox()
        # Chrome changes are visible in the retained full images, but must not
        # advance the recorded settled publication beyond the late document.
        assert ImageChops.difference(images['loaded-new'], images['settled-new']).convert('RGB').getbbox()
        evidence.update(status='passed', document_publications=2,
                        late_document_counted=True, chrome_excluded=True,
                        quiet_delay_excluded=True, loaded_pixels_match_settled=True)
    except Exception as error:
        evidence.update(status='failed', error=str(error))
        raise
    finally:
        (output/'result.json').write_text(json.dumps(evidence, indent=2)+'\n')
    print(json.dumps(evidence))


if __name__ == '__main__':
    main()
