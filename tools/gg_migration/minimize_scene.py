#!/usr/bin/env python3
"""Shrinks a failing scene of a corpus script: removes lines one at a time
while canvas_scene still reports the scene as different from the oracle, and
prints the smallest failing scene.
Usage: minimize_scene.py ORACLE CANVAS_SCENE SCRIPT NAME WORK_DIRECTORY"""
import os, subprocess, sys
oracle, tool, script, name, out = sys.argv[1:6]
os.makedirs(out, exist_ok=True)
scenes, cur = {}, None
for line in open(script).read().splitlines():
    w = line.split()
    if w and w[0] == 'scene':
        cur = w[1]; scenes[cur] = [line]
    elif cur:
        scenes[cur].append(line)
        if w and w[0] == 'end':
            cur = None
lines = scenes[name]
header, body = lines[0], lines[1:-1]

def run(variants):
    text = ''
    for i, b in enumerate(variants):
        h = header.split(); h[1] = f'v{i:04d}'
        text += '\n'.join([' '.join(h)] + b + ['end']) + '\n'
    path = os.path.join(out, 'script.txt')
    open(path, 'w').write(text)
    subprocess.run([oracle, path, out], capture_output=True)
    r = subprocess.run([tool, path, out, '--verbose'], capture_output=True, text=True)
    failing = set()
    for l in r.stdout.splitlines() + r.stderr.splitlines():
        if l.startswith('FAIL v'):
            failing.add(int(l.split()[1][1:5]))
    return failing

assert 0 in run([body]), 'scene does not fail'
changed = True
while changed:
    changed = False
    variants = [body[:i] + body[i + 1:] for i in range(len(body))]
    failing = run(variants)
    for i in range(len(body)):
        if i in failing:
            body = variants[i]
            changed = True
            break
print('\n'.join([header] + body + ['end']))
