import copy
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import cnn_browser_instructions as benchmark


class RuntimePinTests(unittest.TestCase):
    def test_all_collector_and_loader_overrides_are_reported(self):
        environment = dict(PATH='/bin', GC_DONT_GC='1', GC_ENABLE_INCREMENTAL='1',
            GC_INITIAL_HEAP_SIZE='100', DYLD_LIBRARY_PATH='/alternate/runtime',
            DYLD_IMAGE_SUFFIX='_debug', VOX_TEST_WINDOW='1')
        with patch.dict(os.environ, environment, clear=True):
            self.assertEqual(benchmark.runtime_overrides(),
                {k: v for k, v in environment.items() if k.startswith(('GC_', 'DYLD_'))})
        with patch.dict(os.environ, {'PATH': '/bin'}, clear=True):
            self.assertEqual(benchmark.runtime_overrides(), {})

    def test_resolves_first_existing_rpath_and_follows_runtime_symlink(self):
        with tempfile.TemporaryDirectory(prefix='vox collector ') as directory:
            root = Path(directory)
            real = root / 'real collector.dylib'
            real.write_bytes(b'pinned collector')
            (root / 'libgc.dylib').symlink_to(real)
            binary = root / 'Vox'
            loads = f'{binary}:\n\t@rpath/libgc.dylib (compatibility version 7.0.0, current version 7.3.0)\n'
            paths = f'Load command 0\n cmd LC_RPATH\n cmdsize 40\n path /missing (offset 12)\nLoad command 1\n cmd LC_RPATH\n cmdsize 40\n path @executable_path (offset 12)\n'
            with patch.object(benchmark.subprocess, 'check_output', side_effect=[loads, paths]):
                self.assertEqual(benchmark.linked_collector(binary), real.resolve())

    def test_resolves_absolute_dependency_and_versioned_collector_name(self):
        with tempfile.TemporaryDirectory() as directory:
            real = Path(directory) / 'libgc.1.5.6.dylib'
            real.write_bytes(b'collector')
            loads = f'Vox:\n\t{real} (compatibility version 1.0.0, current version 1.5.6)\n'
            with patch.object(benchmark.subprocess, 'check_output', return_value=loads):
                self.assertEqual(benchmark.linked_collector(Path(directory) / 'Vox'), real.resolve())

    def test_missing_or_unresolvable_collector_fails_closed(self):
        for loads, paths in [('Vox:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n', ''),
                ('Vox:\n\t@rpath/libgc.dylib (compatibility version 1.0.0)\n', '')]:
            with self.subTest(loads=loads):
                with patch.object(benchmark.subprocess, 'check_output', side_effect=[loads, paths]):
                    with self.assertRaises(RuntimeError): benchmark.linked_collector(Path('/Vox'))


class CaptureGateTests(unittest.TestCase):
    def state(self):
        return dict(ready='complete', fonts='loaded', width=1024, height=768, scale=1,
            text='story '*300, images=[dict(x=32, y=127, width=269, height=151,
                complete=True, naturalWidth=960)])

    def test_visible_images_fonts_and_viewport_are_required(self):
        state = self.state()
        self.assertTrue(benchmark.ready(state))
        for changes in [dict(ready='loading'), dict(fonts='loading'), dict(scale=2),
                        dict(width=800), dict(text='error'), dict(images=[])]:
            with self.subTest(changes=changes):
                self.assertFalse(benchmark.ready(dict(state, **changes)))
        for changes in [dict(complete=False), dict(naturalWidth=0)]:
            modified = copy.deepcopy(state)
            modified['images'][0].update(changes)
            self.assertFalse(benchmark.ready(modified))
        # Missing below-viewport images do not conceal a loaded visible image.
        state['images'].append(dict(x=32, y=900, width=269, height=151,
            complete=False, naturalWidth=0))
        self.assertTrue(benchmark.ready(state))

    def test_native_gate_reads_actual_model_and_retained_paint_sources(self):
        audit = dict(url='https://edition.cnn.com/', ready='complete', fonts_status='loaded',
            viewport_width=1024, viewport_height=768, selections=[
                dict(name='body', elements=[dict(text='story '*300)]),
                dict(name='images', elements=[dict(rect=dict(x=32, y=127, width=269, height=151),
                    image=dict(complete=False, natural_width=0, paint_decoded=True, paint_width=960))])])
        self.assertTrue(benchmark.ready(benchmark.native_state(audit)))
        audit['selections'][1]['elements'][0]['image']['paint_decoded'] = False
        self.assertFalse(benchmark.ready(benchmark.native_state(audit)))

    def test_native_fonts_need_all_three_real_loaded_cnn_display_faces(self):
        faces = [dict(family='cnn_sans_display', weight=w, status='loaded',
            parsed_font_present=True, source_path='/decoded/font.ttf') for w in ['auto', '500', '700']]
        self.assertTrue(benchmark.native_fonts_ready(dict(font_faces=faces)))
        for key, value in [('status', 'unloaded'), ('parsed_font_present', False),
                           ('source_path', ''), ('family', 'fallback')]:
            modified = copy.deepcopy(faces)
            modified[0][key] = value
            self.assertFalse(benchmark.native_fonts_ready(dict(font_faces=modified)))

    def test_proxy_and_capture_environment_are_restored_after_failure(self):
        original = dict(VOX_PROXY='socks5h://localhost:1080', HTTPS_PROXY='http://proxy',
                        DYLD_INSERT_LIBRARIES='original', VOX_COOKIE_FILE='cookies')
        with patch.dict(os.environ, original, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'failed capture'):
                with benchmark.cnn_native_environment(Path('/offline-guard.dylib')):
                    self.assertEqual(os.environ['VOX_PROXY'], '')
                    self.assertEqual(os.environ['DYLD_INSERT_LIBRARIES'], '/offline-guard.dylib')
                    self.assertNotIn('HTTPS_PROXY', os.environ)
                    raise RuntimeError('failed capture')
            self.assertEqual(dict(os.environ), original)


class FilterGateTests(unittest.TestCase):
    def report(self):
        return dict(counts=dict(requests=124, mismatches=0, oracle_disagreements=0),
            common_stream=dict(matches=True), navigation=dict(coverage='page'),
            cosmetic=dict(css_matches=True, procedural_matches=True, scriptlet_filters_match=True))

    def test_requires_nonempty_exact_common_request_and_header_stream(self):
        benchmark.check_filter_report(self.report())
        for key, value in [('requests', 0), ('mismatches', 1), ('oracle_disagreements', 1)]:
            report = self.report()
            report['counts'][key] = value
            with self.assertRaises(RuntimeError): benchmark.check_filter_report(report)
        report = self.report()
        report['common_stream']['matches'] = False
        with self.assertRaises(RuntimeError): benchmark.check_filter_report(report)

    def test_reference_requires_loaded_page_and_all_document_filter_kinds(self):
        benchmark.check_filter_report(self.report(), cosmetics=True)
        for field in ['css_matches', 'procedural_matches', 'scriptlet_filters_match']:
            report = self.report()
            report['cosmetic'][field] = False
            with self.assertRaises(RuntimeError): benchmark.check_filter_report(report, cosmetics=True)
        report = self.report()
        report['navigation']['coverage'] = 'challenge'
        with self.assertRaises(RuntimeError): benchmark.check_filter_report(report, cosmetics=True)


if __name__ == '__main__': unittest.main()
