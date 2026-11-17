"""Focused format/binding regression sources; no GPU or capture fixture required."""
import struct
import tempfile
import unittest
from pathlib import Path

from decode_metal_capture import decode, pipeline_descriptor


def record(tag, signature, payload):
    raw = bytearray(36) + signature.encode('ascii') + b'\0'
    raw += bytes(-len(raw) % 4)
    raw += payload
    raw += bytes(-len(raw) % 4)
    struct.pack_into('<II', raw, 0, len(raw), tag)
    return raw


def inline(stage, name, length=32, slot=30):
    payload = struct.pack('<Q', 1) + name.encode() + b'\0'
    payload += bytes(-len(payload) % 4)
    payload += struct.pack('<QQ', length, slot)
    return record(0xffffc09f if stage == 'vertex' else 0xffffc0a1, 'CU<b>ulul', payload)


def draw():
    return record(0xffffc0a7, 'Cululultulullul',
                  struct.pack('<7QqQ', 1, 3, 3, 0, 9, 0, 1, 0, 0))


class FakeCapture:
    def __init__(self, root, commands, **resources):
        self.root = root
        self.pins = {}
        self.resources = dict(capture=b'MTSP\0\4\0\0' + commands, **resources)

    def resource(self, name):
        return self.resources[name]

    def verify(self):
        pass


class CaptureBindingTests(unittest.TestCase):
    def test_image_bindings_and_nonindexed_draws_snapshot_texture_identity(self):
        def texture(name):
            payload = struct.pack('<Q', 9) + name.encode() + b'\0'
            payload += bytes(-len(payload) % 4)
            return record(0xffffc04a, 'CU', payload + struct.pack('<IQ', 116, 7))

        bind = record(0xffffc07b, 'Ctul', struct.pack('<3Q', 1, 7, 0))
        sampler = record(0xffffc07d, 'Ctul', struct.pack('<3Q', 1, 8, 0))
        quad = record(0xffffc0a6, 'Cululululul', struct.pack('<6Q', 1, 4, 0, 4, 2, 19))
        commands = texture('first') + bind + sampler + quad + texture('reused') + draw()
        descriptor = struct.pack('<9Q', 225, 2, 80, 40, 40, 1, 6, 1, 1)
        with tempfile.TemporaryDirectory() as directory:
            result = decode(FakeCapture(Path(directory), commands,
                                        first=descriptor, reused=descriptor))
        first, = result['nonindexed_draws']
        self.assertEqual(first['primitive'], 4)
        self.assertEqual(first['vertex_count'], 4)
        self.assertEqual(first['instance_count'], 2)
        self.assertEqual(first['base_instance'], 19)
        self.assertNotIn('index_buffer', first)
        self.assertEqual(first['fragment_textures']['0']['descriptor'], 'first')
        self.assertEqual(first['fragment_samplers']['0']['pointer'], '0x8')
        second, = result['indexed_draws']
        self.assertEqual(second['fragment_textures']['0']['descriptor'], 'reused')
        self.assertEqual(result['textures']['0x7']['width'], 40)
        self.assertEqual(result['textures']['0x7']['mipmap_levels'], 6)
        self.assertIn('Not reconstructed', result['texture_contents'])

    def test_unknown_texture_version_and_changed_binding_signature_are_rejected(self):
        payload = struct.pack('<Q', 9) + b'bad\0' + struct.pack('<IQ', 116, 7)
        commands = record(0xffffc04a, 'CU', payload)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'Unsupported texture descriptor version'):
                decode(FakeCapture(Path(directory), commands, bad=struct.pack('<9Q', *([0] * 9))))
            with self.assertRaisesRegex(ValueError, 'Changed signature'):
                decode(FakeCapture(Path(directory), record(0xffffc07b, 'Ct', bytes(24))))

    def test_inline_bytes_replace_buffer_bindings_and_later_buffers_replace_bytes(self):
        bind = lambda tag: record(tag, 'C@1t@1ul@2ul', struct.pack('<5Q', 1, 7, 16, 30, 1))
        commands = (bind(0xffffc06b) + bind(0xffffc07a) + inline('vertex', 'v')
                    + inline('fragment', 'f') + draw() + bind(0xffffc06b)
                    + bind(0xffffc07a) + draw())
        with tempfile.TemporaryDirectory() as directory:
            result = decode(FakeCapture(Path(directory), commands, v=bytes(32), f=bytes(32)))
        first, second = result['indexed_draws']
        self.assertEqual(first['vertex_inline_bytes'][30]['file'], 'v')
        self.assertEqual(first['fragment_inline_bytes'][30]['file'], 'f')
        self.assertNotIn('30', first['vertex_buffers'])
        self.assertNotIn('30', first['fragment_buffers'])
        self.assertEqual(second['vertex_inline_bytes'], {})
        self.assertEqual(second['fragment_inline_bytes'], {})
        self.assertEqual(second['vertex_buffers']['30']['offset'], 16)
        self.assertEqual(second['fragment_buffers']['30']['offset'], 16)

    def test_inline_length_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            capture = FakeCapture(Path(directory), inline('vertex', 'v', 64), v=bytes(32))
            with self.assertRaisesRegex(ValueError, 'Invalid inline shader bytes'):
                decode(capture)

    def test_exports_cannot_write_into_the_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, 'outside the capture'):
                decode(FakeCapture(root, b''), rectangle_exports={1: root/'new'})

    def test_pipeline_retains_attachment_format_and_blending_and_rejects_truncation(self):
        raw = (struct.pack('<5Q', 225, 1, 2, 0, 0)
               + struct.pack('<9Q', 4, 2**64-1, 0x3f800000, 0, 0, 1, 260, 260, 8)
               + struct.pack('<9Q', 1, 1, 5, 0, 1, 5, 0, 15, 80)
               + struct.pack('<9Q', 0, 1, 0, 0, 1, 0, 0, 15, 0)*7)
        color = pipeline_descriptor(raw)['color_attachments'][0]
        self.assertEqual(color['pixel_format'], 80)
        self.assertTrue(color['blend_enabled'])
        self.assertEqual(color['destination_rgb'], 5)
        self.assertEqual(color['write_mask'], 15)
        with self.assertRaisesRegex(ValueError, 'Truncated capture value'):
            pipeline_descriptor(raw[:-8])


if __name__ == '__main__':
    unittest.main()
