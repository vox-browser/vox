import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import production_source_manifest as manifest


class ProductionSourceManifestTests(unittest.TestCase):
    def fixture(self, root):
        subprocess.run(['git', 'init', '-q', '-b', 'master', str(root)], check=True)
        (root / 'browser.v').write_text('module main\n')
        (root / 'worker.v').write_text('module main\n')
        (root / 'native.h').write_text('int native;\n')
        return manifest.begin(root)

    def component(self, root, name, paths):
        directory = root.parent / name
        directory.mkdir()
        (directory / 'v_sources').write_bytes(b'\0'.join(str(path).encode() for path in paths))
        (directory / 'v_source_digests').write_bytes(b'\0'.join(
            hashlib.sha256(path.read_bytes()).hexdigest().encode() for path in paths))
        return directory

    def test_edit_before_browser_parse_keeps_independent_worker_valid(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            worker = self.component(root, 'worker', [root / 'worker.v'])
            (root / 'browser.v').write_text('module main\nfn latest() {}\n')
            browser = self.component(root, 'browser', [root / 'browser.v'])
            combined = manifest.combine(root, inventory, [worker, browser])
            self.assertEqual(combined[str(root / 'browser.v')], hashlib.sha256((root / 'browser.v').read_bytes()).hexdigest())
            self.assertIn(str(root / 'native.h'), combined)

    def test_conflicting_components_and_consumed_edits_are_rejected(self):
        for conflict in [False, True]:
            with self.subTest(conflict=conflict), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                inventory = self.fixture(root)
                first = self.component(root, 'first', [root / 'worker.v'])
                (root / 'worker.v').write_text('module main\nfn changed() {}\n')
                components = [first]
                if conflict:
                    components.append(self.component(root, 'second', [root / 'worker.v']))
                with self.assertRaisesRegex(RuntimeError, 'different source bytes' if conflict else 'input changed'):
                    manifest.combine(root, inventory, components)

    def test_native_edits_and_new_package_members_are_rejected(self):
        for native in [False, True]:
            with self.subTest(native=native), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                inventory = self.fixture(root)
                component = self.component(root, 'component', [root / 'browser.v'])
                (root / ('native.h' if native else 'new.v')).write_text('changed')
                with self.assertRaisesRegex(RuntimeError, 'input changed' if native else 'membership changed'):
                    manifest.combine(root, inventory, [component])

    def test_reports_and_tests_do_not_change_production_membership(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            (root / 'browser_test.v').write_text('test')
            (root / 'docs').mkdir()
            (root / 'docs/report.json').write_text('{}')
            (root / 'tools').mkdir()
            (root / 'tools/test_windows_runtime_guard.c').write_text('native test helper')
            manifest.validate_inventory(root, inventory)

    def test_native_test_headers_remain_production_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            self.fixture(root)
            (root / 'tools').mkdir()
            header = root / 'tools/test_runtime.h'
            header.write_text('int runtime;')
            inventory = manifest.begin(root)
            header.write_text('int changed;')
            with self.assertRaisesRegex(RuntimeError, 'input changed'):
                manifest.validate_inventory(root, inventory)

    def test_partial_or_malformed_compiler_manifests_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            self.fixture(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            for data in [b'', b'bad', b'0' * 64 + b'\0' + b'1' * 64]:
                (component / 'v_source_digests').write_bytes(data)
                with self.assertRaises(RuntimeError):
                    manifest.component_inputs(component)


if __name__ == '__main__':
    unittest.main()
