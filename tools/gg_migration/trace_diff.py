#!/usr/bin/env python3
"""Compare the draw calls of a Graphite oracle trace with a gg.canvas trace.

Pipelines are identified by their shader hashes and color blend state, draw
calls by pipeline and instance count, and instances by their bytes with the
ssboIndex field masked (the two renderers number uniforms differently).
"""
import argparse
import re

# Byte offset of the uint ssboIndex in each instance layout, by stride.
SSBO_OFFSETS = {108: 68, 60: 20, 48: 44}


def parse(path, definitions):
    pipelines = {}
    text = open(definitions).read().split('\n') + open(path).read().split('\n')
    for line in text:
        m = re.match(r'pipeline id=(\d+) vertex=(\S+) fragment=(\S+) samples=(\d+)', line)
        if m:
            vertex = m.group(2).split(':')[0]
            fragment = m.group(3).split(':')[0]
            pipelines[m.group(1)] = [vertex, fragment, m.group(4)]
        m = re.match(r'pipeline_color id=(\d+) .*blend=(\d) .*mask=(\d+)', line)
        if m and m.group(1) in pipelines:
            pipelines[m.group(1)] += [m.group(2), m.group(3)]
    calls = []
    current = None
    lines = open(path).read().split('\n')
    for i, line in enumerate(lines):
        if line.startswith('set_pipeline'):
            current = pipelines.get(line.split('=')[1])
        elif line.startswith('draw'):
            instances = int(re.search(r'instances=(\d+)', line).group(1))
            data = None
            for follow in lines[i + 1:]:
                if not follow.startswith('  '):
                    break
                m = re.match(r'  vertex_buffer index=(\d+) .*data=([0-9a-f]+)', follow)
                if m and len(m.group(2)) // 2 == instances * stride_of(len(m.group(2)) // 2, instances):
                    data = bytes.fromhex(m.group(2))
            records = []
            if data is not None:
                stride = len(data) // instances
                for k in range(instances):
                    record = bytearray(data[k * stride:(k + 1) * stride])
                    offset = SSBO_OFFSETS.get(stride)
                    if offset is not None:
                        record[offset:offset + 4] = b'\0\0\0\0'
                    records.append(bytes(record))
            calls.append((tuple(current or ()), instances, records))
    return calls


def stride_of(size, instances):
    if instances and size % instances == 0 and size // instances in SSBO_OFFSETS:
        return size // instances
    return -1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('oracle_trace')
    parser.add_argument('oracle_definitions')
    parser.add_argument('gg_trace')
    parser.add_argument('gg_definitions')
    parser.add_argument('--skip-oracle-calls', type=int, default=0,
                        help='ignore leading oracle calls (e.g. 2 for the forced-MSAA path)')
    args = parser.parse_args()
    expected = parse(args.oracle_trace, args.oracle_definitions)[args.skip_oracle_calls:]
    actual = parse(args.gg_trace, args.gg_definitions)
    print(f'oracle: {len(expected)} calls, gg: {len(actual)} calls')
    for index, (e, a) in enumerate(zip(expected, actual)):
        # Depth-only pipelines (color write mask 0) have no fragment shader in
        # Graphite; gg.canvas binds an empty one.
        depth_only = e[0][4:] == ('0',) and a[0][4:] == ('0',)
        same_shaders = e[0][:1] == a[0][:1] and (depth_only or e[0][1:2] == a[0][1:2])
        if not same_shaders or e[0][3:] != a[0][3:] or e[1] != a[1] or e[2] != a[2]:
            print(f'first difference at call {index}:')
            print(f'  oracle pipeline {e[0]} instances {e[1]}')
            print(f'  gg     pipeline {a[0]} instances {a[1]}')
            for k, (re_, ra) in enumerate(zip(e[2], a[2])):
                if re_ != ra:
                    print(f'  instance {k} differs:\n    oracle {re_.hex()}\n    gg     {ra.hex()}')
                    break
            return 1
    if len(expected) != len(actual):
        print('call counts differ')
        return 1
    print('draw calls match')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
