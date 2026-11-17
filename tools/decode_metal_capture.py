#!/usr/bin/env python3
"""Read draw state from an MTSP 0x400 Metal capture without replaying it.

This is a diagnostic for the GPUTools format recorded on macOS 26. It decodes
only the listed commands, preserves unknown opcode counts, and rejects changed
type signatures. It does not claim to decode every Metal command or to replay
the captured rendering. No private frameworks or GPU are needed.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
import zlib


def unpack(data, offset, fmt):
    size = struct.calcsize('<' + fmt)
    if offset < 0 or offset + size > len(data):
        raise ValueError('Truncated capture value')
    return struct.unpack_from('<' + fmt, data, offset)


def text_at(data, offset, size):
    if offset < 0 or offset + size > len(data):
        raise ValueError('Truncated capture string')
    return data[offset:offset + size].split(b'\0', 1)[0].decode('ascii')


class Capture:
    def __init__(self, root):
        self.root = root.resolve()
        self.pins = {}
        data = self.read('index')
        if data[:8] != b'xdic\0\0\0\0':
            raise ValueError('Unsupported capture directory version')
        buckets, count, capacity = unpack(data, 8, 'III')
        if count != capacity or count > 1_000_000:
            raise ValueError('Unsupported capture directory capacity')
        base = 20 + 12 * buckets
        cursor = base + count * 26
        self.entries = {}
        for i in range(count):
            length, stored, offset, kind, reserved = unpack(data, base + i * 24, 'IIQII')
            size, = unpack(data, base + count * 24 + i * 2, 'H')
            name = text_at(data, cursor, size)
            cursor += size
            if not name or Path(name).name != name or name in self.entries or reserved:
                raise ValueError('Unsupported capture directory entry')
            self.entries[name] = (length, stored, offset, kind)
        if cursor != len(data):
            raise ValueError('Unexpected capture directory tail')
        self.store = None

    def read(self, name):
        path = self.root / name
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if name in self.pins and self.pins[name] != digest:
            raise ValueError('Capture resource changed during decoding: ' + name)
        self.pins[name] = digest
        return data

    def resource(self, name):
        length, stored, offset, kind = self.entries[name]
        if kind == 2:
            data = self.read(name)
        elif kind == 1:
            if self.store is None:
                self.store = self.read('store0')
            compressed = self.store[offset:offset + stored]
            decoder = zlib.decompressobj()
            data = decoder.decompress(compressed, length + 1)
            if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
                raise ValueError('Invalid compressed capture resource: ' + name)
        else:
            raise ValueError('Unsupported capture resource storage: ' + str(kind))
        if len(data) != length:
            raise ValueError('Capture resource length mismatch: ' + name)
        return data

    def verify(self):
        changed = [name for name, digest in self.pins.items()
                   if hashlib.sha256((self.root / name).read_bytes()).hexdigest() != digest]
        if changed:
            raise ValueError('Capture changed during decoding: ' + ', '.join(changed))


def records(data):
    if data[:8] != b'MTSP\0\4\0\0':
        raise ValueError('Unsupported Metal stream version')
    offset = 8
    while offset < len(data):
        length, tag = unpack(data, offset, 'II')
        if length < 40 or length % 4 or offset + length > len(data):
            raise ValueError('Invalid record boundary at ' + str(offset))
        record = data[offset:offset + length]
        end = record.index(0, 36)
        signature = record[36:end].decode('ascii')
        payload = (end + 4) & ~3
        yield offset, tag, signature, record[payload:]
        offset += length


def pipeline_descriptor(raw):
    if unpack(raw, 0, 'Q')[0] != 225:
        raise ValueError('Unsupported pipeline descriptor version')
    vertex, fragment = unpack(raw, 8, 'QQ')
    cursor = 24
    for _ in range(2):  # Layout and attribute arrays, three uint64 values each.
        count, = unpack(raw, cursor, 'Q')
        if count > 31:
            raise ValueError('Unsupported vertex descriptor array')
        cursor += 8 + count * 24
    samples, mask, coverage_bits, alpha_coverage, alpha_one, raster, depth, stencil = unpack(
        raw, cursor, '8Q')
    return dict(vertex_function=hex(vertex), fragment_function=hex(fragment),
                samples=samples, sample_mask=hex(mask),
                sample_coverage=struct.unpack('<f', struct.pack('<I', coverage_bits))[0],
                alpha_to_coverage=bool(alpha_coverage), alpha_to_one=bool(alpha_one),
                rasterization_enabled=bool(raster), depth_format=depth, stencil_format=stencil)


def decode(capture, graphite_rectangles=False):
    counts = Counter()
    states, names, depths, draws, pipelines, copies = {}, {}, {}, [], {}, {}
    libraries, functions = {}, {}

    def binding(pointer, position):
        return dict(pointer=hex(pointer), offset=position, **names.get(pointer, {}))

    def captured_slice(entry, start, length):
        if entry:
            data = capture.resource(entry['file'])
            start -= entry['update_offset']
            if start < 0 or start + length > len(data):
                raise ValueError('Buffer slice outside captured update')
            return data[start:start + length]

    def buffer_bytes(pointer, start, length):
        if pointer in names:
            return captured_slice(names[pointer], start, length)
        for destination, size, source, position in reversed(copies.get(pointer, [])):
            if destination <= start and start + length <= destination + size:
                if not source:
                    raise ValueError('Copy source has no captured CPU buffer update')
                return captured_slice(source, position + start - destination, length)
        raise ValueError('No captured bytes for buffer ' + hex(pointer))
    total = 0
    for offset, tag, signature, data in records(capture.resource('capture')):
        total += 1
        counts[f'{tag:08x} {signature}'] += 1
        expected = {
            0xffffd800: 'CtU<b>ulul',
            0xffffc007: 'Ctultulul',
            0xffffc049: 'CU',
            0xffffc04f: 'CU<b>Ut',
            0xffffc051: 'CUt',
            0xffffc05e: 'CS',
            0xffffc069: 'Ct',
            0xffffc06b: None,  # Variable array sizes are checked below.
            0xffffc072: 'C@6d',
            0xffffc077: 'C@4l',
            0xffffc082: 'Ct',
            0xffffc08a: 'C',
            0xffffc0a7: 'Cululultulullul',
        }
        if tag not in expected:
            continue
        if expected[tag] is not None and signature != expected[tag]:
            raise ValueError(f'Changed signature for {tag:08x}: {signature}')
        if tag == 0xffffd800:
            _, buffer = unpack(data, 0, 'QQ')
            end = data.index(0, 16)
            name = text_at(data, 16, end - 16 + 1)
            update_offset, update_length = unpack(data, (end + 4) & ~3, 'QQ')
            names[buffer] = dict(file=name, update_offset=update_offset,
                                 update_length=update_length)
            copies.pop(buffer, None)
        elif tag == 0xffffc007:
            _, source, position, destination, start, length = unpack(data, 0, '6Q')
            # Save the source version at the copy, before a later upload or
            # pointer reuse can replace its name. GPU-generated bytes are unknown.
            copies.setdefault(destination, []).append((start, length, names.get(source), position))
            names.pop(destination, None)
        elif tag == 0xffffc04f:
            end = data.index(0, 8)
            source = text_at(data, 8, end - 8 + 1)
            options_end = data.index(0, end + 1)
            marker, library = unpack(data, ((options_end + 4) & ~3) + 8, 'IQ')
            if marker != ord('t'):
                raise ValueError('Unsupported library return encoding')
            libraries[library] = dict(source=source, source_sha256=hashlib.sha256(
                capture.resource(source)).hexdigest())
        elif tag == 0xffffc05e:
            library, = unpack(data, 0, 'Q')
            end = data.index(0, 8)
            entry = text_at(data, 8, end - 8 + 1)
            marker, function = unpack(data, (end + 4) & ~3, 'IQ')
            if marker != ord('t'):
                raise ValueError('Unsupported function return encoding')
            functions[function] = dict(library=hex(library), entry_point=entry,
                                       **libraries.get(library, {}))
        elif tag == 0xffffc051:
            end = data.index(0, 8)
            descriptor = text_at(data, 8, end - 8 + 1)
            marker, pipeline = unpack(data, ((end + 4) & ~3) + 8, 'IQ')
            if marker != ord('t'):
                raise ValueError('Unsupported pipeline return encoding')
            pipelines[pipeline] = dict(descriptor=descriptor,
                                       **pipeline_descriptor(capture.resource(descriptor)))
        elif tag == 0xffffc049:
            end = data.index(0, 8)
            descriptor = text_at(data, 8, end - 8 + 1)
            marker, state = unpack(data, (end + 4) & ~3, 'IQ')
            raw = capture.resource(descriptor)
            if marker != ord('t') or len(raw) != 144 or unpack(raw, 0, 'Q')[0] != 225:
                raise ValueError('Unsupported depth-stencil descriptor')
            compare, write = unpack(raw, 8, 'QQ')
            if compare > 7 or write > 1:
                raise ValueError('Invalid depth state')
            depths[state] = dict(descriptor=descriptor, compare=compare,
                                 write_enabled=bool(write), raw_hex=raw.hex())
        else:
            encoder, = unpack(data, 0, 'Q')
            state = states.setdefault(encoder, dict(vertex_buffers={}))
            if tag == 0xffffc08a:
                states.pop(encoder)
            elif tag in (0xffffc069, 0xffffc082):
                value, = unpack(data, 8, 'Q')
                state['pipeline' if tag == 0xffffc069 else 'depth'] = value
            elif tag == 0xffffc072:
                state['viewport'] = unpack(data, 8, '6d')
            elif tag == 0xffffc077:
                state['scissor'] = unpack(data, 8, '4Q')
            elif tag == 0xffffc06b:
                # The current capture uses singleton arrays. Do not guess other layouts.
                if signature != 'C@1t@1ul@2ul':
                    raise ValueError('Unsupported vertex-buffer array: ' + signature)
                buffer, start, slot, count = unpack(data, 8, '4Q')
                if count != 1:
                    raise ValueError('Vertex-buffer array count mismatch')
                state['vertex_buffers'][slot] = (buffer, start)
            elif tag == 0xffffc0a7:
                primitive, count, index_type, buffer, start, instances, vertex, instance = unpack(
                    data, 8, '6QqQ')
                draw = dict(offset=offset, encoder=hex(encoder), primitive=primitive,
                                  index_count=count, index_type=index_type,
                                  index_buffer=binding(buffer, start), instance_count=instances,
                                  base_vertex=vertex, base_instance=instance,
                                  pipeline=hex(state['pipeline']) if 'pipeline' in state else None,
                                  depth=depths.get(state.get('depth')),
                                  viewport=state.get('viewport'),
                                  scissor=state.get('scissor'),
                                  vertex_buffers={str(slot): binding(*value)
                                                  for slot, value in state['vertex_buffers'].items()})
                if graphite_rectangles and (primitive, count, index_type, vertex) == (4, 69, 0, 12):
                    # Dawn's captured Graphite shader uses buffers 2/3 for vertex pulling.
                    static, static_start = state['vertex_buffers'][2]
                    dynamic, dynamic_start = state['vertex_buffers'][3]
                    draw['graphite_rectangles'] = dict(
                        indices=unpack(buffer_bytes(buffer, start, count * 2), 0, '69H'),
                        vertex_bytes_sha256=hashlib.sha256(buffer_bytes(
                            static, static_start + vertex * 28, 36 * 28)).hexdigest(),
                        instances=[dict(index=i, values=unpack(buffer_bytes(
                            dynamic, dynamic_start + i * 108, 108), 0, '27f'))
                            for i in range(instance, instance + instances)])
                draws.append(draw)
    capture.verify()
    return dict(format='MTSP 0x400; selected commands only', trace=str(capture.root),
                decoder_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                record_count=total, opcode_counts=dict(sorted(counts.items())),
                depth_states={hex(key): value for key, value in depths.items()},
                pipelines={hex(key): value for key, value in pipelines.items()},
                functions={hex(key): value for key, value in functions.items()},
                indexed_draws=draws, input_sha256=capture.pins)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--graphite-rectangles', action='store_true',
                        help='Read the captured Dawn Graphite 69-index rectangle buffers')
    args = parser.parse_args()
    result = decode(Capture(args.trace), args.graphite_rectangles)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(records=result['record_count'], indexed_draws=len(result['indexed_draws']),
                          depth_states=len(result['depth_states']), output=str(args.output))))


if __name__ == '__main__':
    main()
