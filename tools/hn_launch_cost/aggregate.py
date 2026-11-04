#!/usr/bin/env python3
"""Aggregate /usr/bin/sample call graphs: busy inclusive/self samples per function.

Waiting leaves (mach_msg, cv/semaphore waits, sleeps, kevent...) and the probe's own
delay frames are excluded. Recursion counts once per stack.
usage: aggregate.py PATTERN_GLOB... [--thread main|other|all] [--top N] [--under NAME]
"""
import argparse, collections, glob, re
from pathlib import Path

IDLE = {'mach_msg2_trap', 'mach_msg_trap', '__psynch_cvwait', '__psynch_mutexwait', '__semwait_signal',
        'semaphore_wait_trap', 'semaphore_timedwait_trap', 'kevent', 'kevent64', 'kevent_id',
        '__workq_kernreturn', '__select', 'poll', '__ulock_wait', '__ulock_wait2', 'nanosleep',
        '__wait4', '__sigsuspend', 'read', '__read_nocancel', 'accept', '__accept', 'recvfrom',
        '__recvfrom', '__open', 'start_wqthread', 'thread_start', '_pthread_wqthread', 'usleep',
        '__pselect', 'psynch_cvwait', 'swtch_pri', 'thread_switch'}
LINE = re.compile(r'^([ +!:|]*)(\d+) (.*)$')


def clean(name):
    name = re.sub(r'\s+\[0x[0-9a-f]+\]$', '', name)
    name = re.sub(r'\s+\+ \d+$', '', name)
    m = re.match(r'^(.*?)\s+\(in ([^)]+)\)', name)
    return f'{m.group(1)} [{m.group(2)}]' if m else name


def parse(path):
    """Yield (thread_name, root) trees of [name, count, children]."""
    text = Path(path).read_text(errors='replace')
    body = text.split('Call graph:', 1)[1].split('Total number in stack', 1)[0]
    body = body.split('\nBinary Images:', 1)[0]
    stack = []
    trees = []
    for raw in body.splitlines():
        m = LINE.match(raw)
        if not m:
            continue
        depth = len(m.group(1))
        node = [clean(m.group(3)), int(m.group(2)), []]
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if stack:
            stack[-1][1][2].append(node)
        else:
            trees.append(node)
        stack.append((depth, node))
    return trees


def busy(node):
    # callers()/tree.py may reuse a parsed tree; recomputing must replace the
    # cached value rather than leave a stale fourth entry.
    del node[3:]
    child = sum(c[1] for c in node[2])
    own = node[1] - child
    base = node[0].split(' [')[0]
    if base in IDLE or base in ('load_delay', 'exit_delay'):
        node.append(0)
        for c in node[2]:
            busy(c)
        node[3] = 0 if base in ('load_delay', 'exit_delay') else sum(c[3] for c in node[2])
        return node[3]
    node.append(own + sum(busy(c) for c in node[2]))
    return node[3]


def walk(node, seen, inclusive, selfc, under, active):
    name = node[0]
    active = active or (under is None) or under in name
    if active and name not in seen and node[3]:
        inclusive[name] += node[3]
    child_busy = sum(c[3] for c in node[2])
    if active and node[3] - child_busy > 0:
        selfc[name] += node[3] - child_busy
    seen = seen | {name}
    for c in node[2]:
        walk(c, seen, inclusive, selfc, under, active)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('files', nargs='+')
    p.add_argument('--thread', choices=['main', 'other', 'all'], default='all')
    p.add_argument('--top', type=int, default=60)
    p.add_argument('--under')
    p.add_argument('--self', action='store_true')
    a = p.parse_args()
    files = [f for pattern in a.files for f in glob.glob(pattern)]
    if not files:
        p.error('No sample files matched')
    inclusive, selfc = collections.Counter(), collections.Counter()
    total = 0
    threads = collections.Counter()
    for f in files:
        for tree in parse(f):
            is_main = 'Main Thread' in tree[0]
            if a.thread == 'main' and not is_main or a.thread == 'other' and is_main:
                continue
            busy(tree)
            label = re.sub(r'Thread_\d+:?\s*', '', tree[0])[:70]
            threads[label] += tree[3]
            total += tree[3]
            for c in tree[2]:
                walk(c, frozenset(), inclusive, selfc, a.under, False)
    n = len(files)
    print(f'{n} files, busy samples per file: {total / n:.0f}')
    for label, count in threads.most_common(12):
        print(f'  thread {count / n:8.1f}  {label}')
    table = selfc if a.self else inclusive
    for name, count in table.most_common(a.top):
        print(f'{count / n:8.1f} {100 * count / total if total else 0:5.1f}%  {name[:150]}')


if __name__ == '__main__':
    main()


def callers(files, needle, depth=4, top=25):
    paths = collections.Counter()
    n = 0
    for f in files:
        n += 1
        for tree in parse(f):
            busy(tree)
            def visit(node, ancestry):
                if needle == node[0].split(' [')[0] and node[3]:
                    paths[' <- '.join(a.split(' [')[0][:60] for a in reversed(ancestry[-depth:]))] += node[3]
                    return
                for c in node[2]:
                    visit(c, ancestry + [node[0]])
            visit(tree, [])
    for path, count in paths.most_common(top):
        print(f'{count / n:7.2f}  {path}')
