#!/usr/bin/env python3
"""Symbolize a tools/gc_allocation_sampler.c report and rank allocation sites.

Modes:
  site      bytes by the first frame outside V/collector runtime helpers
  stack     bytes by the first DEPTH such frames
  retained  like `site`, counting only sampled bytes that were never finalized
            (requires GC_ALLOC_SAMPLE_TRACK_FREES=1 while sampling)
"""

import argparse
import bisect
import collections
import re
import subprocess

RUNTIME = re.compile(r'^(builtin__|GC_|_v_malloc|malloc_noscan|memdup|vcalloc|sampled_|'
                     r'vmemory_block_|prealloc_|v_malloc|v_realloc|malloc_uninit|alloc_array_data|VMapData__|new_dense_array|'
                     r'__v3_internal_symbol_array_new|malloc_string_buffer|'
                     r'tracked_|record|__new_array|new_array|array_|map_|string_|'
                     r'strings__Builder|DenseArray|new_map|realloc_data|vmemdup)')


def load(path):
    images, sites = [], []
    for line in open(path):
        if line.startswith('# image '):
            _, _, base, name = line.rstrip('\n').split(' ', 3)
            images.append((int(base, 16), name))
            continue
        fields = line.split()
        if len(fields) < 3:
            continue
        sites.append((int(fields[0]), int(fields[2]), [int(frame, 16) for frame in fields[3:]]))
    return sorted(images), sites


def symbolize(images, sites):
    bases = [base for base, _ in images]
    by_image = collections.defaultdict(list)
    for address in sorted({frame for _, _, frames in sites for frame in frames}):
        by_image[bisect.bisect_right(bases, address) - 1].append(address)
    names = {}
    for image, addresses in by_image.items():
        if image < 0:
            continue
        base, path = images[image]
        for start in range(0, len(addresses), 2000):
            chunk = addresses[start:start + 2000]
            output = subprocess.run(['atos', '-o', path, '-l', hex(base)]
                                    + [hex(address - 1) for address in chunk],
                                    capture_output=True, text=True).stdout.splitlines()
            for address, symbol in zip(chunk, output):
                symbol = re.sub(r' \(in [^)]*\)', '', symbol)
                names[address] = re.sub(r' \([^)]*:\d+\)$', '', symbol).split(' + ')[0][:120]
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('report')
    parser.add_argument('--mode', choices=('site', 'stack', 'retained'), default='site')
    parser.add_argument('--depth', type=int, default=5)
    parser.add_argument('--top', type=int, default=30)
    args = parser.parse_args()
    images, sites = load(args.report)
    names = symbolize(images, sites)
    totals = collections.Counter()
    for sampled, freed, frames in sites:
        weight = max(0, sampled - freed) if args.mode == 'retained' else sampled
        frames = [names.get(frame, hex(frame)) for frame in frames]
        frames = [frame for frame in frames if not RUNTIME.match(frame)] or frames
        depth = args.depth if args.mode == 'stack' else 1
        totals[' <- '.join(frames[:depth])] += weight
    total = sum(totals.values()) or 1
    print(f'{args.mode}: {total / 1048576:.1f} MB sampled')
    for name, weight in totals.most_common(args.top):
        print(f'{weight / 1048576:9.2f} MB {100 * weight / total:5.1f}%  {name}')


if __name__ == '__main__':
    main()
