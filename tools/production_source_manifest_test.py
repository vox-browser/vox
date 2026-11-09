import hashlib
from pathlib import Path
import subprocess
import sys
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

    def test_documentation_changes_do_not_invalidate_unrelated_compilation(self):
        for name in ['tools/gg_migration/README.md', 'encoding/PORT_STATUS.md']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                self.fixture(root)
                document = root / name
                document.parent.mkdir(parents=True)
                document.write_text('old tooling notes')
                inventory = manifest.begin(root)
                component = self.component(root, 'component', [root / 'browser.v'])
                document.write_text('new tooling notes')
                (document.parent / 'NEW.md').write_text('another tooling note')
                manifest.validate_inventory(root, inventory)
                combined = manifest.combine(root, inventory, [component])
                self.assertNotIn(str(document), combined)
                self.assertIn(str(root / 'native.h'), combined)

    def test_explicitly_consumed_markdown_remains_pinned(self):
        for name in ['tools/embedded.md', 'encoding/embedded.md']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                self.fixture(root)
                document = root / name
                document.parent.mkdir()
                document.write_text('compiled text')
                inventory = manifest.begin(root)
                component = self.component(root, 'component', [root / 'browser.v', document])
                combined = manifest.combine(root, inventory, [component])
                self.assertIn(str(document), combined)
                document.write_text('changed compiled text')
                with self.assertRaisesRegex(RuntimeError, 'input changed'):
                    manifest.combine(root, inventory, [component])

    def test_package_tsv_corpora_do_not_change_browser_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = (Path(temporary) / 'repo').resolve()
            self.fixture(root)
            fixtures = root / 'jpegxl/testdata'
            fixtures.mkdir(parents=True)
            corpus = fixtures / 'modular.tsv'
            corpus.write_text('old fixture')
            inventory = manifest.begin(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            before = manifest.fingerprint([root / 'browser.v', root / 'native.h'])
            from rebuild_browser import repository_state, same_build_inputs
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Fixture',
                            '-c', 'user.email=fixture@example.com', 'commit',
                            '--allow-empty', '-qm', 'Initialize test repository'], check=True)
            state = repository_state(root)
            corpus.write_text('new fixture')
            (fixtures / 'new.tsv').write_text('another focused test')
            manifest.validate_inventory(root, inventory)
            self.assertTrue(same_build_inputs(state, repository_state(root)))
            combined = manifest.combine(root, inventory, [component])
            self.assertEqual(combined, before)
            self.assertTrue(manifest.matches_compiled_checkout(root, dict(
                source_inventory=inventory, exact_source_manifest=combined)))

    def test_explicit_fixture_inputs_and_native_testdata_headers_stay_pinned(self):
        for name in ['embedded.tsv', 'embedded.jxl', 'runtime.h']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                self.fixture(root)
                fixtures = root / 'jpegxl/testdata'
                fixtures.mkdir(parents=True)
                data = fixtures / name
                data.write_text('compiled bytes')
                inventory = manifest.begin(root)
                component = self.component(root, 'component', [root / 'browser.v', data])
                combined = manifest.combine(root, inventory, [component])
                self.assertIn(str(data), combined)
                data.write_text('changed compiled bytes')
                with self.assertRaisesRegex(RuntimeError, 'input changed'):
                    manifest.combine(root, inventory, [component])
                self.assertFalse(manifest.matches_compiled_checkout(root, dict(
                    source_inventory=inventory, exact_source_manifest=combined)))

    def test_embedded_fixture_is_pinned_when_compiler_reports_only_v_sources(self):
        forms = [(form, suffix) for form in ['relative', 'vmodroot', 'dir', 'absolute', 'expression', 'comment']
                 for suffix in ('.tsv', '.jxl')]
        for form, suffix in forms:
            with self.subTest(form=form, suffix=suffix), tempfile.TemporaryDirectory() as temporary:
                root = (Path(temporary) / 'repo').resolve()
                self.fixture(root)
                relative = 'testdata/embedded' + suffix
                data = root / relative
                data.parent.mkdir()
                data.write_text('compiled bytes')
                path = {'relative': relative, 'vmodroot': '@VMODROOT/' + relative,
                        'dir': '@DIR/' + relative, 'absolute': str(data)}.get(form)
                argument = repr(path) if path else 'fixture_path'
                embedded = '$embed_file(' + argument + ')'
                if form == 'comment':
                    embedded = "$embed_file /* separated tokens */ ('" + relative + "')"
                (root / 'browser.v').write_text('module main\nconst bytes = ' + embedded + '\n')
                inventory = manifest.begin(root)
                self.assertIn(str(data), inventory['early_inputs'])
                component = self.component(root, 'component', [root / 'browser.v'])
                combined = manifest.combine(root, inventory, [component])
                self.assertIn(str(data), combined)
                data.write_text('changed payload')
                with self.assertRaisesRegex(RuntimeError, 'input changed'):
                    manifest.combine(root, inventory, [component])

    def test_unconsumed_jpegxl_fixtures_can_change_during_browser_compilation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = (Path(temporary) / 'repo').resolve()
            self.fixture(root)
            fixtures = root / 'jpegxl/testdata/grouped'
            fixtures.mkdir(parents=True)
            frame = fixtures / 'frame.jxl'
            frame.write_bytes(b'old test image')
            inventory = manifest.begin(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            frame.write_bytes(b'updated test image')
            (fixtures / 'multipass.jxl').write_bytes(b'new test image')
            manifest.validate_inventory(root, inventory)
            combined = manifest.combine(root, inventory, [component])
            self.assertNotIn(str(frame), combined)
            self.assertIn(str(root / 'native.h'), combined)

    def test_tsv_aliases_and_nested_module_roots_remain_pinned(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = (Path(temporary) / 'repo').resolve()
            self.fixture(root)
            package = root / 'nested'
            fixtures = package / 'testdata'
            fixtures.mkdir(parents=True)
            (package / 'v.mod').write_text('Module { name: "nested" }')
            target = fixtures / 'data.tsv'
            target.write_text('payload')
            alias = fixtures / 'alias.tsv'
            alias.symlink_to(target)
            (package / 'main.v').write_text("module nested\nconst bytes = $embed_file('@VMODROOT/testdata/alias.tsv')\n")
            inventory = manifest.begin(root)
            self.assertIn(str(target), inventory['early_inputs'])
            self.assertIn(str(alias), inventory['early_inputs'])

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

    def test_production_python_dependency_closure_keeps_unrelated_work_independent(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            self.fixture(root)
            (root / 'tools').mkdir()
            (root / 'build-prod-browser.sh').write_text('python3 "$repo_dir/tools/build_fixture.py"\n')
            (root / 'tools/build_fixture.py').write_text('import shared_build_input\n')
            shared = root / 'tools/shared_build_input.py'
            shared.write_text('VALUE = 1\n')
            inventory = manifest.begin(root)
            (root / 'tools/wpt_fixtures.py').write_text('unused test tooling')
            manifest.validate_inventory(root, inventory)
            self.assertIn(str(shared), inventory['early_inputs'])
            shared.write_text('VALUE = 2\n')
            with self.assertRaisesRegex(RuntimeError, 'input changed'):
                manifest.validate_inventory(root, inventory)

    def test_compiled_checkout_matching_ignores_reports_and_rejects_new_or_edited_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            frozen = dict(source_inventory=inventory,
                          exact_source_manifest=manifest.fingerprint([root / 'worker.v', root / 'native.h']))
            (root / 'docs').mkdir()
            (root / 'docs/report.json').write_text('{}')
            self.assertTrue(manifest.matches_compiled_checkout(root, frozen))
            (root / 'worker.v').write_text('new compiled source')
            self.assertFalse(manifest.matches_compiled_checkout(root, frozen))
            (root / 'worker.v').write_text('module main\n')
            (root / 'new.v').write_text('new package member')
            self.assertFalse(manifest.matches_compiled_checkout(root, frozen))

    def test_partial_or_malformed_compiler_manifests_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            self.fixture(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            for data in [b'', b'bad', b'0' * 64 + b'\0' + b'1' * 64]:
                (component / 'v_source_digests').write_bytes(data)
                with self.assertRaises(RuntimeError):
                    manifest.component_inputs(component)

    def verify(self, component):
        from rebuild_browser import write_json
        write_json(component / 'parsed-verified.json', dict(protocol='verified-parsed-buffers-v1',
                   sources=manifest.v_inputs(manifest.component_inputs(component))))

    def test_verified_buffers_survive_later_v_edits_but_native_inputs_stay_pinned(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            self.verify(component)
            (root / 'browser.v').write_text('later editor change')
            (root / 'new.v').write_text('new member after parsing')
            combined = manifest.combine(root, inventory, [component], parsed=True)
            self.assertNotEqual(combined[str(root / 'browser.v')], hashlib.sha256((root / 'browser.v').read_bytes()).hexdigest())
            (root / 'native.h').write_text('changed native input')
            with self.assertRaisesRegex(RuntimeError, 'input changed'):
                manifest.combine(root, inventory, [component], parsed=True)

    def test_final_manifest_cannot_replace_verified_buffers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            component = self.component(root, 'component', [root / 'browser.v'])
            self.verify(component)
            (component / 'v_source_digests').write_bytes(b'0' * 64)
            with self.assertRaisesRegex(RuntimeError, 'buffers changed'):
                manifest.combine(root, inventory, [component], parsed=True)

    def test_compiler_wrapper_seals_before_later_source_edits(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            component = root.parent / 'component'
            # The child models V's parse/Cgen boundary. Its later edit happens
            # only after the monitor has verified the parsed source buffers.
            program = '''import hashlib,os,time
from pathlib import Path
p=Path(os.environ['V_MACOS_V3_C_ERROR_DIR']);p.mkdir()
s=Path(__import__('sys').argv[1]);(p/'v_sources').write_bytes(str(s).encode())
(p/'v_source_digests').write_bytes(hashlib.sha256(s.read_bytes()).hexdigest().encode())
deadline=time.monotonic()+10
while not (p/'parsed-verified.json').exists():
 if time.monotonic()>deadline:raise SystemExit(3)
 time.sleep(.01)
s.write_text('later edit after parsed buffers were sealed')
'''
            self.assertEqual(manifest.compile_component(root, inventory, component,
                             [sys.executable, '-c', program, str(root / 'browser.v')]), 0)
            manifest.combine(root, inventory, [component], parsed=True)

    def test_compiler_wrapper_rejects_sources_edited_before_verification(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'
            inventory = self.fixture(root)
            component = root.parent / 'component'
            program = '''import hashlib,os
from pathlib import Path
p=Path(os.environ['V_MACOS_V3_C_ERROR_DIR']);p.mkdir()
s=Path(__import__('sys').argv[1]);digest=hashlib.sha256(s.read_bytes()).hexdigest()
s.write_text('changed before parsed-buffer verification')
(p/'v_sources').write_bytes(str(s).encode());(p/'v_source_digests').write_bytes(digest.encode())
'''
            with self.assertRaisesRegex(RuntimeError, 'input changed'):
                manifest.compile_component(root, inventory, component,
                    [sys.executable, '-c', program, str(root / 'browser.v')])
            self.assertTrue((component / 'verification-error.json').exists())
            self.assertFalse((component / 'parsed-verified.json').exists())

    def test_compiler_membership_is_scoped_to_its_consumed_packages(self):
        for consumed in [False, True]:
            with self.subTest(consumed=consumed), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / 'repo'
                inventory = self.fixture(root)
                component = root.parent / 'component'
                program = '''import hashlib,os,sys
from pathlib import Path
p=Path(os.environ['V_MACOS_V3_C_ERROR_DIR']);p.mkdir()
s=Path(sys.argv[1]);added=Path(sys.argv[2]);added.parent.mkdir(exist_ok=True)
added.write_text('new package member')
(p/'v_sources').write_bytes(str(s).encode());(p/'v_source_digests').write_bytes(hashlib.sha256(s.read_bytes()).hexdigest().encode())
'''
                added = root / ('new.v' if consumed else 'css/new.v')
                command = [sys.executable, '-c', program, str(root / 'worker.v'), str(added)]
                if consumed:
                    with self.assertRaisesRegex(RuntimeError, 'package membership changed'):
                        manifest.compile_component(root, inventory, component, command)
                else:
                    self.assertEqual(manifest.compile_component(root, inventory, component, command), 0)
                    manifest.combine(root, inventory, [component], parsed=True)


if __name__ == '__main__':
    unittest.main()
