import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from pikabu_browser_instructions import (
    frozen_response, content_ready, fingerprint_tree, native_content_state, native_font_gate, URL,
)


class FrozenPikabuTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == 'darwin', 'macOS DYLD interposition')
    def test_network_guard_denies_external_resolution_and_connect_but_allows_loopback(self):
        tools = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as temporary:
            library = Path(temporary) / 'guard.dylib'
            binary = Path(temporary) / 'guard-test'
            subprocess.run(['clang', '-dynamiclib', '-O2', '-Wall', '-Wextra', '-Werror',
                            str(tools / 'pikabu_instruction_network_deny.c'), '-o', str(library)], check=True)
            subprocess.run(['clang', '-O2', '-Wall', '-Wextra', '-Werror',
                            str(tools / 'pikabu_instruction_network_deny_test.c'), '-o', str(binary)], check=True)
            env = dict(os.environ, DYLD_INSERT_LIBRARIES=str(library))
            result = subprocess.run([str(binary)], env=env, check=True, text=True,
                                    capture_output=True, timeout=10)
            self.assertIn('DNS/external connect denied; loopback permitted', result.stdout)

    def test_response_requires_recorded_headers_final_url_and_equal_document_body(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            for name in ['resources', 'pages']:
                (cache / name).mkdir()
            key = hashlib.sha256(URL.encode()).hexdigest()
            resource = cache / 'resources' / key
            resource.write_bytes(b'canonical html')
            (cache / 'pages' / key).write_bytes(b'canonical html')
            self.assertIsNone(frozen_response(cache, URL, 'Document'))
            resource.with_name(key + '.url').write_text(URL)
            resource.with_name(key + '.headers.json').write_text(json.dumps([
                {'name': 'content-type', 'value': 'text/html; charset=windows-1251'},
                {'name': 'content-encoding', 'value': 'gzip'},
                {'name': 'content-length', 'value': '999'},
                {'name': 'set-cookie', 'value': 'one=1'},
                {'name': 'set-cookie', 'value': 'two=2'},
            ]))
            body, headers, path = frozen_response(cache, URL, 'Document')
            self.assertEqual(body, b'canonical html')
            self.assertEqual(path, resource)
            self.assertEqual(headers, [
                {'name': 'content-type', 'value': 'text/html; charset=windows-1251'},
                {'name': 'set-cookie', 'value': 'one=1'},
                {'name': 'set-cookie', 'value': 'two=2'},
                {'name': 'content-length', 'value': '14'},
            ])
            (cache / 'pages' / key).write_bytes(b'different document')
            with self.assertRaisesRegex(RuntimeError, 'Canonical document differs'):
                frozen_response(cache, URL, 'Document')
            resource.with_name(key + '.url').write_text('https://different.invalid/')
            self.assertIsNone(frozen_response(cache, URL, 'Document'))

    def test_ready_gate_rejects_skeleton_missing_image_font_load_or_wrong_viewport(self):
        state = dict(url=URL, ready='complete', width=1024, height=656, scale=1,
                     stories=15, text='Actual content ' * 100, firstTitle='Actual first story',
                     fontsStatus='loaded', images=[dict(complete=True, naturalWidth=700,
                         rect=dict(width=610, height=900, top=340, bottom=1240))])
        self.assertTrue(content_ready(state, 1024, 656))
        for change in [dict(stories=0), dict(firstTitle=''), dict(text='Loading...'),
                       dict(fontsStatus='loading'), dict(width=800), dict(scale=2),
                       dict(images=[]), dict(ready='interactive')]:
            self.assertFalse(content_ready(dict(state, **change), 1024, 656), change)
        bad = json.loads(json.dumps(state))
        bad['images'][0]['naturalWidth'] = 0
        self.assertFalse(content_ready(bad, 1024, 656))
        bad['images'][0]['naturalWidth'] = 700
        bad['images'][0]['complete'] = False
        self.assertFalse(content_ready(bad, 1024, 656))

    def test_cache_fingerprint_uses_names_and_bytes_and_detects_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'a').write_bytes(b'one')
            before = fingerprint_tree(root)
            self.assertEqual(before, fingerprint_tree(root))
            (root / 'a').write_bytes(b'two')
            self.assertNotEqual(before['sha256'], fingerprint_tree(root)['sha256'])
            (root / 'a').write_bytes(b'one')
            (root / 'a').rename(root / 'b')
            self.assertNotEqual(before['sha256'], fingerprint_tree(root)['sha256'])

    def test_native_gate_keeps_unknown_fonts_and_retained_image_provenance(self):
        audit = dict(url=URL, title='Pikabu', ready='complete', viewport_width=1024,
                     viewport_height=656, fonts_status='unmaterialized', selections=[
                         dict(name='stories', count=15, elements=[]),
                         dict(name='first_title', elements=[dict(text='First story')]),
                         dict(name='body', elements=[dict(text='Actual content ' * 100)]),
                         dict(name='story_images', elements=[dict(attributes={'src': 'image.png'},
                              rect=dict(x=0, y=340, width=610, height=900), image=dict(
                                  current_src='', complete=False, natural_width=0, natural_height=0,
                                  paint_decoded=True, paint_width=700, paint_height=1000))])])
        state = native_content_state(audit)
        self.assertEqual(state['fontsStatus'], 'unmaterialized')
        self.assertFalse(content_ready(state, 1024, 656))
        self.assertEqual(state['images'][0]['naturalWidth'], 700)
        audit['fonts_status'] = 'loaded'
        self.assertTrue(content_ready(native_content_state(audit), 1024, 656))
        audit['selections'][-1]['elements'][0]['image']['paint_decoded'] = False
        self.assertFalse(content_ready(native_content_state(audit), 1024, 656))

    def test_native_font_gate_requires_each_real_loaded_retained_roboto_face(self):
        audit = dict(fonts_status='loaded', font_faces=[])
        self.assertFalse(native_font_gate(audit))
        for weight in ('400', '500', '700'):
            audit['font_faces'].append(dict(family='Roboto', style='normal', weight=weight,
                status='loaded', parsed_font_present=True, source_path='/retained/' + weight + '.ttf'))
        self.assertTrue(native_font_gate(audit))
        for key, value in [('status', 'error'), ('parsed_font_present', False), ('source_path', ''),
                           ('family', 'Fallback')]:
            changed = json.loads(json.dumps(audit))
            changed['font_faces'][1][key] = value
            self.assertFalse(native_font_gate(changed), (key, value))


if __name__ == '__main__':
    unittest.main()
