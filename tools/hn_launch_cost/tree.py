#!/usr/bin/env python3
"""Merged top-down busy-sample tree under a named root (per-file average)."""
import argparse, glob
if __package__:
    from . import aggregate as a
else:
    import aggregate as a

def merge(into, node):
    key = node[0].split(' [')[0]
    slot = into.setdefault(key, [0, {}])
    slot[0] += node[3]
    for c in node[2]:
        merge(slot[1], c)

def find(node, root, out):
    if node[0].split(' [')[0] == root:
        out.append(node); return
    for c in node[2]:
        find(c, root, out)

def show(children, n, depth, max_depth, threshold, indent=''):
    for name, (count, sub) in sorted(children.items(), key=lambda kv: -kv[1][0]):
        if count / n < threshold: continue
        print(f'{indent}{count / n:6.2f} {name[:110]}')
        if depth < max_depth:
            show(sub, n, depth + 1, max_depth, threshold, indent + '  ')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pattern')
    parser.add_argument('root')
    parser.add_argument('max_depth', type=int, nargs='?', default=4)
    parser.add_argument('threshold', type=float, nargs='?', default=.3)
    args = parser.parse_args()
    files = glob.glob(args.pattern)
    if not files:
        parser.error('No sample files matched')
    merged = {}
    for path in files:
        for tree in a.parse(path):
            a.busy(tree)
            found = []
            find(tree, args.root, found)
            for node in found:
                merge(merged, node)
    show(merged, len(files), 0, args.max_depth, args.threshold)


if __name__ == '__main__':
    main()
