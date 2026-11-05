#!/usr/bin/env python3
"""Counts the Brave fixtures whose traced Metal work uses each Graphite render step.

Usage: classify_inventory.py RUNS_DIRECTORY, where every fixture directory holds the
process-*.trace files and shaders/ written by libvox_metal_trace.dylib and a `done` file.
Render steps are recognized by their vertex layouts; shaders that Dawn translated with
Tint are reported together, as are layout-less shaders of Vox itself.
"""
import collections
import glob
import os
import re
import sys

runs = sys.argv[1]
def kv(line): return dict(re.findall(r'(\w+)=(\S+)', line))
shader_kind = {}
def kind_of(fx, vs, layouts):
    path = glob.glob(os.path.join(runs, fx, 'shaders', vs + '.metal'))
    src = open(path[0]).read() if path else ''
    if 'dawn_entry_point' in src: return 'Dawn (Tint MSL)'
    if not layouts: return 'Vox native shader'
    l = ' '.join(layouts)
    if 's108' in l: return 'AnalyticRRect'
    if 'b3:s60:step2' in l: return 'CoverBounds'
    if 's48:step2' in l: return 'TessellateWedges'
    if 's76:step2' in l: return 'CoverageMask'
    if 'b3:s12:step1' in l: return 'MiddleOutFan'
    if 's56:step2' in l: return 'TessellateStrokes'
    if 's80:step2' in l: return 'PerEdgeAAQuad'
    return 'other ' + l
per = collections.defaultdict(set)
fixtures = sorted(d for d in os.listdir(runs) if os.path.exists(os.path.join(runs, d, 'done')))
for fx in fixtures:
    for path in glob.glob(os.path.join(runs, fx, 'process-*.trace')):
        pipes, layouts, cur = {}, collections.defaultdict(list), None
        for line in open(path, errors='replace'):
            w = line.split(' ', 1)[0]
            if w == 'pipeline': d = kv(line); pipes[d['id']] = d
            elif w == 'pipeline_layout': d = kv(line); layouts[d['id']].append(f"b{d['buffer']}:s{d['stride']}:step{d['step']}")
            elif w == 'set_pipeline': cur = kv(line)['id']
            elif w in ('draw', 'draw_indexed') and cur in pipes:
                per[kind_of(fx, pipes[cur]['vertex'].split(':')[0], layouts[cur])].add(fx)
none = [fx for fx in fixtures if not any(fx in s for s in per.values())]
print(f'{len(fixtures)} fixtures; {len(none)} without Metal draws')
for k, s in sorted(per.items(), key=lambda kv: -len(kv[1])):
    print(f'{len(s):4d}  {k}')
only_vox = [fx for fx in fixtures if fx in per['Vox native shader'] and not any(fx in s for k, s in per.items() if k != 'Vox native shader')]
print(f'{len(only_vox)} fixtures use only the Vox native shader')
