import unittest
import json
import struct
import tempfile
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from pikabu_browser_memory import clean_environment, comparison, native_readiness, validate_native_document, runtime_identity, crop_native_document, measure


class ComparisonTests(unittest.TestCase):
    def row(self, value):
        return {'memory': {'settled_physical_footprint_bytes': value}}

    def test_overlapping_trial_ranges_do_not_pass_on_a_lower_median(self):
        self.assertFalse(comparison([self.row(100), self.row(210)],
                                    [self.row(200), self.row(220)])['target_met'])
        self.assertFalse(comparison([self.row(200)], [self.row(200)])['target_met'])
        self.assertTrue(comparison([self.row(100), self.row(150)],
                                   [self.row(200), self.row(220)])['target_met'])

    def test_native_endpoint_rejects_blank_and_unpainted_windows(self):
        painted = 'Ladybird V timing: first_paint_replay (2000 commands) 10 ms\n'
        installed = 'Ladybird V timing: install_total 100 ms\n'
        for log in ['', painted, installed, installed * 2,
                    installed * 2 + painted, (installed + painted) * 2,
                    installed + painted * 2]:
            with self.assertRaises(RuntimeError):
                native_readiness(log)
        self.assertEqual(native_readiness(installed + painted)['completed_installs'], 1)
        with self.assertRaises(RuntimeError):
            native_readiness(installed + painted + installed + 'Ladybird V timing: first_paint_replay (0 commands) 1 ms\n')

    def test_native_endpoint_rejects_navigation_away_from_a_previously_painted_page(self):
        document = dict(url='https://pikabu.ru/', ready='complete', title='Pikabu',
                        paint_commands=600, selections=[dict(name='stories', count=15)])
        validate_native_document(document)
        for change in [dict(url='about:blank'), dict(ready='loading'), dict(title=''),
                       dict(paint_commands=0), dict(selections=[]), dict(visibility='hidden'),
                       dict(fully_active=False)]:
            with self.assertRaises(RuntimeError):
                validate_native_document(document | change)

    def test_ambient_local_proxies_cannot_bypass_the_offline_guard(self):
        inherited = {key: 'http://127.0.0.1:7890' for key in
                     ['HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy', 'VOX_PROXY']}
        self.assertFalse(set(inherited) & set(clean_environment(inherited)))

    def test_runtime_identity_detects_changes_to_the_backend_and_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / 'MacOS/Vox'
            binary.parent.mkdir()
            binary.write_bytes(b'executable')
            library = binary.with_name('libVoxAVIF.dylib')
            library.write_bytes(b'backend')
            snapshot = root / 'Resources/adblock.snapshot.bin'
            snapshot.parent.mkdir()
            snapshot.write_bytes(b'snapshot')
            before = runtime_identity(binary)
            self.assertEqual(len(before), 3)
            library.write_bytes(b'changed backend')
            self.assertNotEqual(before, runtime_identity(binary))

    def test_native_crop_preserves_the_measured_device_pixel_density(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / 'window.png', Path(directory) / 'document.png'
            source.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('!II', 2048, 1760))
            with patch('pikabu_browser_memory.subprocess.run') as run:
                crop_native_document(source, target, dict(viewport_width=1024, viewport_height=796))
                self.assertEqual(run.call_args.args[0][1:7],
                                 ['--cropToHeightWidth', '1592', '2048', '--cropOffset', '120', '0'])
                with self.assertRaises(RuntimeError):
                    crop_native_document(source, target, dict(viewport_width=1024, viewport_height=600))

    def test_rejected_trials_keep_samples_without_publishing_a_result(self):
        for early_exit in [False, True]:
            with self.subTest(early_exit=early_exit), tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
                root = Path(directory)
                cache = root / 'cache'
                cache.mkdir()
                args = SimpleNamespace(vox=root / 'Vox', cache=cache,
                    network_deny=root / 'guard.dylib', seconds=60 if early_exit else 0,
                    background=False)
                process = MagicMock(pid=123)
                process.poll.return_value = 1
                samples = [dict(seconds=1, physical_footprint_bytes=400)]
                counter = MagicMock(samples=samples)
                foreground = MagicMock(checks=[dict(seconds=1, foreground=False)])
                foreground.verify_steady.side_effect = RuntimeError('lost focus')
                replacements = dict(placement=dict(scale=1), digest='hash', runtime_identity={},
                    PhysicalTree=counter, ForegroundControl=foreground, CounterSampler=MagicMock(),
                    memory_result=dict(settled_physical_footprint_bytes=400))
                for name, value in replacements.items():
                    stack.enter_context(patch('pikabu_browser_memory.' + name, return_value=value))
                stack.enter_context(patch('pikabu_browser_memory.subprocess.Popen', return_value=process))
                stop = stack.enter_context(patch('pikabu_browser_memory.stop_process'))
                output = root / 'trial'
                with self.assertRaisesRegex(RuntimeError, 'exited before' if early_exit else 'lost focus'):
                    measure(args, 'vox', output)
                failure = json.loads((output / 'failure.json').read_text())
                self.assertFalse(failure['accepted'])
                self.assertEqual(failure['samples'], samples)
                self.assertEqual(failure['memory_diagnostic'], None if early_exit else
                                 dict(settled_physical_footprint_bytes=400))
                self.assertFalse((output / 'result.json').exists())
                stop.assert_called_once_with(process)


if __name__ == '__main__':
    unittest.main()
