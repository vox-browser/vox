from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from prepare_linux_modules import stage_module
from prepare_ui2 import (load_ui2_lock, prepare_gg_gradient, prepare_ui2_source,
                         validate_embedding_api)
from ui2_snapshot_cache import process_alive, snapshot_cache_path


class GGGradientCompatibilityTests(unittest.TestCase):
    def test_linux_and_ui2_stages_can_alternate_without_modifying_the_compiler(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            vlib, modules = root / 'vlib', root / 'modules'
            source = vlib / 'gg'
            contents = {
                'gg.v': 'module gg\nfn size(n int) uint { return usize(n) }\n',
                'render/context.v': 'module render\nfn size(n int) uint { return usize(n) }\n',
                'canvas/gpu_gradient.v': 'module canvas\n',
                'canvas/other.v': 'module canvas\n',
                'canvas/shaders/reference.metal': 'unchanged compiler shader',
            }
            for relative, content in contents.items():
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            stage_module(source, modules / 'gg', 'gg')
            for _ in range(2):
                prepare_gg_gradient(modules, vlib)
                stage_module(source, modules / 'gg', 'gg')
                self.assertIn('uint(n)', (modules / 'gg/render/context.v').read_text())
                self.assertFalse((modules / 'gg/render').is_symlink())
                self.assertEqual((modules / 'gg/canvas/shaders/reference.metal').resolve(),
                                 source / 'canvas/shaders/reference.metal')
                for relative, content in contents.items():
                    self.assertFalse((source / relative).is_symlink())
                    self.assertEqual((source / relative).read_text(), content)

    def test_gradient_override_preserves_the_other_compiler_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            vlib, modules = root / 'vlib', root / 'modules'
            source = vlib / 'gg/canvas'
            source.mkdir(parents=True)
            modules.mkdir()
            shader = "module canvas\nfn shader() {\n\tbodies_tile := (snippets['bodies_tile'] + snippets['body_colorize_${stops}']).replace('_skTemp',\n\t\t'_skTempB')\n}\n"
            (source / 'gpu_gradient.v').write_text(shader)
            (source / 'other.v').write_text('module canvas\n')
            (source / 'gpu_context.v').write_text('module canvas\n#include "@DIR/gpu_metal_darwin.h"\nfn C.v_canvas_metal_device() voidptr\n')
            (source / 'gpu_metal_darwin.h').write_text('static void* v_canvas_metal_device(void) { return 0; }\n')
            (source / 'path.v').write_text('module canvas\nfn C.gg_canvas_sincosf(x f32, s &f32, c &f32)\n')
            (vlib / 'gg/gg.v').write_text('module gg\n')
            prepare_gg_gradient(modules, vlib)
            actual = (modules / 'gg/canvas/gpu_gradient.v').read_text()
            self.assertIn('bodies_tile := tile_source.replace(', actual)
            self.assertIn("tile_source := snippets['bodies_tile'] + snippets['body_colorize_${stops}']", actual)
            self.assertEqual((source / 'gpu_gradient.v').read_text(), shader)
            self.assertEqual((modules / 'gg/canvas/other.v').resolve(), source / 'other.v')
            self.assertFalse((modules / 'gg/canvas/gpu_context.v').is_symlink())
            self.assertIn('"@DIR/vox_gpu_metal_darwin.m"',
                          (modules / 'gg/canvas/gpu_context.v').read_text())
            self.assertIn(str(source / 'gpu_metal_darwin.h'),
                          (modules / 'gg/canvas/vox_gpu_metal_darwin.m').read_text())
            self.assertFalse((modules / 'gg/canvas/path.v').is_symlink())
            self.assertEqual((modules / 'gg/canvas/path.v').read_text(), (source / 'path.v').read_text())
            prepare_gg_gradient(modules, vlib)
            self.assertEqual((modules / 'gg/canvas/gpu_gradient.v').read_text(), actual)


class EmbeddingAPIContractTests(unittest.TestCase):
    def test_supported_declaration_with_comments(self):
        validate_embedding_api(
            'module ui2\n\n'
            '// API generation for embedded controls.\n'
            '/* Reviewed upstream API. */\n'
            'pub const embedded_controls_version = 1\n')

    def test_invalid_or_unsupported_declarations_fail(self):
        declarations = {
            'missing': 'module ui2\n',
            'line comment': 'module ui2\n// pub const embedded_controls_version = 1\n',
            'block comment': 'module ui2\n/* pub const embedded_controls_version = 1 */\n',
            'duplicate': ('module ui2\npub const embedded_controls_version = 1\n'
                          'pub const embedded_controls_version = 1\n'),
            'private': 'module ui2\nconst embedded_controls_version = 1\n',
            'expression': 'module ui2\npub const embedded_controls_version = 1 + 1\n',
            'numeric prefix': 'module ui2\npub const embedded_controls_version = 1wrong\n',
            'wrong module': 'module other\npub const embedded_controls_version = 1\n',
            'old API': 'module ui2\npub const embedded_controls_version = 0\n',
            'future API': 'module ui2\npub const embedded_controls_version = 2\n',
        }
        for name, declaration in declarations.items():
            with self.subTest(name=name), self.assertRaises(RuntimeError):
                validate_embedding_api(declaration)


class SnapshotCacheLocationTests(unittest.TestCase):
    def test_default_and_override_paths_are_outside_build_scratch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            repo = root / 'project'
            with patch.dict(os.environ, {'XDG_CACHE_HOME': str(root / 'user-cache')}, clear=True):
                self.assertEqual(snapshot_cache_path(repo),
                                 root / 'user-cache/vox/ui2-snapshots')
                with patch.dict(os.environ, {'VOX_UI2_CACHE_DIR': str(root / 'override')}):
                    self.assertEqual(snapshot_cache_path(repo), root / 'override')
            with patch.dict(os.environ, {}, clear=True), patch.object(Path, 'home', return_value=root):
                self.assertEqual(snapshot_cache_path(repo), root / '.cache/vox/ui2-snapshots')

    def test_build_paths_and_symlink_aliases_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            repo = root / 'project'
            (repo / 'Build').mkdir(parents=True)
            alias = root / 'alias'
            alias.symlink_to(repo / 'Build', target_is_directory=True)
            for path in (repo / 'Build', repo / 'Build/v/ui2-snapshots', alias / 'ui2'):
                with self.subTest(path=path), self.assertRaisesRegex(RuntimeError, 'outside Build/'):
                    snapshot_cache_path(repo, path)
            with patch.dict(os.environ, {'VOX_UI2_CACHE_DIR': str(alias / 'ui2')}):
                with self.assertRaisesRegex(RuntimeError, 'outside Build/'):
                    snapshot_cache_path(repo)


class UpstreamUI2Tests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / 'source'
        self.cache = self.root / 'cache'
        self.source.mkdir()
        self.contents = {
            'v.mod': b"Module { name: 'ui2', subdirs: ['ui'] }\n",
            'ui/ui.v': b'module ui2\npub fn draw() {}\n',
            'ui/embedding.v': b'module ui2\npub const embedded_controls_version = 1\n',
            'ui/native.h': b'/* retained native helper */\n',
            'assets/icon.bin': bytes(range(256)),
        }
        for relative, content in self.contents.items():
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        self.git('init', '--quiet')
        self.lock = self.commit()

    def git(self, *arguments):
        return subprocess.check_output(
            ['git', '-C', str(self.source), '-c', 'user.name=UI2 staging tests',
             '-c', 'user.email=ui2-tests@example.invalid', '-c', 'commit.gpgsign=false',
             *arguments], stderr=subprocess.PIPE, text=True).strip()

    def commit(self):
        self.git('add', '--all')
        self.git('commit', '--quiet', '-m', 'UI2 fixture')
        return {
            'schema_version': 1,
            'repository': 'https://github.com/vlang/ui2.git',
            'revision': self.git('rev-parse', 'HEAD'),
            'tree': self.git('rev-parse', 'HEAD^{tree}'),
            'embedding_api': 1,
        }

    def stage(self, lock=None, **kwargs):
        return prepare_ui2_source(self.source, self.cache, self.lock if lock is None else lock,
                                  **kwargs)

    def snapshots(self):
        return sorted(path for path in self.cache.glob('*') if len(path.name) == 64)

    def owner_process(self):
        owner = subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.read()'],
                                 stdin=subprocess.PIPE)
        self.addCleanup(self.stop_owner, owner)
        return owner

    @staticmethod
    def stop_owner(owner):
        if not owner.stdin.closed:
            owner.stdin.close()
        owner.wait(timeout=10)

    def next_revision(self, owner_pid):
        self.git('commit', '--quiet', '--allow-empty', '-m', 'Next reviewed fixture')
        self.lock = dict(self.lock, revision=self.git('rev-parse', 'HEAD'))
        return self.stage(lease_pid=owner_pid)

    def assert_contents(self, modules, expected):
        dependency = modules / 'ui2'
        paths = list(dependency.rglob('*'))
        self.assertFalse(modules.is_symlink())
        self.assertFalse(dependency.is_symlink())
        self.assertFalse(any(path.is_symlink() for path in paths))
        actual = {path.relative_to(dependency).as_posix(): path.read_bytes()
                  for path in paths if path.is_file()}
        self.assertEqual(actual, expected)

    def test_stage_contains_exact_committed_sources_and_assets(self):
        modules = self.stage()
        self.assert_contents(modules, self.contents)
        self.assertFalse((modules / 'ui2/.git').exists())
        self.assertEqual(self.git('status', '--porcelain', '--untracked-files=all'), '')
        for relative, content in self.contents.items():
            self.assertEqual((self.source / relative).read_bytes(), content)
        receipt = json.loads((modules.parent / 'manifest.json').read_text())
        serialized = json.dumps(receipt, sort_keys=True)
        self.assertIn(self.lock['revision'], serialized)
        self.assertIn(self.lock['tree'], serialized)

    def test_repeated_preparation_reuses_the_completed_stage_without_writing_it(self):
        modules = self.stage()
        before = {path.relative_to(modules): path.stat().st_mtime_ns
                  for path in modules.rglob('*') if path.is_file()}
        self.assertEqual(self.stage(), modules)
        after = {path.relative_to(modules): path.stat().st_mtime_ns
                 for path in modules.rglob('*') if path.is_file()}
        self.assertEqual(before, after)
        self.assert_contents(modules, self.contents)

    def test_source_edits_after_staging_cannot_change_an_existing_consumer(self):
        modules = self.stage()
        (self.source / 'ui/ui.v').write_text('module ui2\npub fn changed() {}\n')
        (self.source / 'assets/icon.bin').unlink()
        self.assert_contents(modules, self.contents)
        entries = sorted(path.name for path in self.cache.iterdir())
        with self.assertRaises(RuntimeError):
            self.stage()
        self.assertEqual(sorted(path.name for path in self.cache.iterdir()), entries)
        self.assert_contents(modules, self.contents)

    def test_next_revision_has_a_new_path_and_preserves_the_previous_stage(self):
        previous = self.stage()
        (self.source / 'assets/icon.bin').unlink()
        changed = b'module ui2\npub fn revised_draw() {}\n'
        (self.source / 'ui/ui.v').write_bytes(changed)
        new_lock = self.commit()
        current = self.stage(new_lock)
        self.assertNotEqual(previous, current)
        self.assert_contents(previous, self.contents)
        expected = dict(self.contents, **{'ui/ui.v': changed})
        del expected['assets/icon.bin']
        self.assert_contents(current, expected)
        self.assertFalse((current / 'ui2/assets/icon.bin').exists())

    def test_unsupported_revision_fails_without_replacing_an_existing_stage(self):
        modules = self.stage()
        self.git('commit', '--quiet', '--allow-empty', '-m', 'Unreviewed revision')
        with self.assertRaises(RuntimeError):
            self.stage()
        self.assert_contents(modules, self.contents)
        self.assertEqual(len(self.snapshots()), 1)

    def test_wrong_tree_fails_before_publication(self):
        with self.assertRaises(RuntimeError):
            self.stage(dict(self.lock, tree='0' * 40))
        self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))

    def test_uncommitted_and_untracked_inputs_fail(self):
        cases = ['modified', 'staged', 'untracked']
        for case in cases:
            with self.subTest(case=case):
                path = self.source / ('ui/extra.v' if case == 'untracked' else 'ui/ui.v')
                path.write_text('module ui2\npub fn unreviewed() {}\n')
                if case == 'staged':
                    self.git('add', 'ui/ui.v')
                with self.assertRaises(RuntimeError):
                    self.stage()
                self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))
                if case == 'untracked':
                    path.unlink()
                else:
                    self.git('reset', '--quiet', 'HEAD', '--', 'ui/ui.v')
                    self.git('checkout', '--', 'ui/ui.v')

    def test_ignored_local_artifacts_are_not_staged(self):
        (self.source / '.gitignore').write_text('build-output/\n')
        self.contents['.gitignore'] = b'build-output/\n'
        lock = self.commit()
        (self.source / 'build-output').mkdir()
        (self.source / 'build-output/ignored.bin').write_bytes(b'local artifact')
        modules = self.stage(lock)
        self.assert_contents(modules, self.contents)
        self.assertFalse((modules / 'ui2/build-output').exists())

    def test_missing_embedding_file_fails_before_publication(self):
        (self.source / 'ui/embedding.v').unlink()
        lock = self.commit()
        with self.assertRaises(RuntimeError):
            self.stage(lock)
        self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))

    def test_future_embedding_api_fails_even_in_an_identified_revision(self):
        (self.source / 'ui/embedding.v').write_text(
            'module ui2\npub const embedded_controls_version = 2\n')
        lock = self.commit()
        with self.assertRaises(RuntimeError):
            self.stage(lock)
        self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))

    def test_source_symlink_is_rejected_instead_of_retaining_mutable_targets(self):
        (self.source / 'ui/linked.h').symlink_to('native.h')
        lock = self.commit()
        with self.assertRaises(RuntimeError):
            self.stage(lock)
        self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))

    def test_submodule_entry_is_rejected(self):
        self.git('update-index', '--add', '--cacheinfo',
                 '160000,' + self.lock['revision'] + ',nested')
        self.git('commit', '--quiet', '-m', 'Fixture gitlink')
        # An empty directory models a clean, uninitialized submodule. A
        # missing directory would stop at the dirty-checkout guard instead.
        (self.source / 'nested').mkdir()
        self.assertEqual(self.git('status', '--porcelain=v1', '--untracked-files=all',
                                  '--ignore-submodules=none'), '')
        lock = dict(self.lock, revision=self.git('rev-parse', 'HEAD'),
                    tree=self.git('rev-parse', 'HEAD^{tree}'))
        with self.assertRaisesRegex(RuntimeError, 'links/submodules'):
            self.stage(lock)
        self.assertFalse(self.cache.exists() and any(self.cache.iterdir()))

    def test_modified_cached_bytes_are_rejected_without_repairing_live_inputs(self):
        modules = self.stage()
        path = modules / 'ui2/ui/ui.v'
        path.chmod(0o644)
        path.write_bytes(b'corrupt cached source')
        with self.assertRaises(RuntimeError):
            self.stage()
        self.assertEqual(path.read_bytes(), b'corrupt cached source')
        self.assertEqual((self.source / 'ui/ui.v').read_bytes(), self.contents['ui/ui.v'])

    def test_unexpected_cached_files_are_rejected(self):
        modules = self.stage()
        extra = modules / 'ui2/ui/unreviewed.v'
        extra.parent.chmod(0o755)
        extra.write_text('module ui2\n')
        with self.assertRaises(RuntimeError):
            self.stage()
        self.assertTrue(extra.is_file())

    def test_cached_symlink_is_rejected_even_when_bytes_match(self):
        modules = self.stage()
        path = modules / 'ui2/ui/ui.v'
        path.parent.chmod(0o755)
        path.unlink()
        path.symlink_to(self.source / 'ui/ui.v')
        with self.assertRaises(RuntimeError):
            self.stage()
        self.assertTrue(path.is_symlink())

    def test_concurrent_staging_publishes_one_complete_snapshot(self):
        with ThreadPoolExecutor(max_workers=4) as executor:
            modules = list(executor.map(lambda _: self.stage(), range(4)))
        self.assertEqual(len(set(modules)), 1)
        self.assertEqual(len(self.snapshots()), 1)
        self.assert_contents(modules[0], self.contents)

    def test_failed_write_does_not_publish_or_leave_a_partial_stage(self):
        write_bytes = Path.write_bytes

        def failed_write(path, data):
            if path.name == 'ui.v':
                raise OSError('Injected staging failure')
            return write_bytes(path, data)

        with patch.object(Path, 'write_bytes', failed_write):
            with self.assertRaisesRegex((OSError, RuntimeError), 'Injected staging failure'):
                self.stage()
        self.assertEqual(self.snapshots(), [])
        self.assertEqual(list(self.cache.glob('.ui2-*')), [])
        self.assertEqual(self.git('status', '--porcelain', '--untracked-files=all'), '')
        self.assert_contents(self.stage(), self.contents)

    def test_retention_reaps_exited_consumers_and_keeps_two_recent_snapshots(self):
        owner = self.owner_process()
        previous = [self.stage(lease_pid=owner.pid)]
        previous.extend(self.next_revision(owner.pid) for _ in range(3))
        self.assertEqual(len(self.snapshots()), 4)
        self.stop_owner(owner)
        self.assertFalse(process_alive(owner.pid))
        current = self.stage()
        self.assertEqual(self.snapshots(), sorted(path.parent for path in previous[-2:]))
        self.assertEqual(current, previous[-1])
        self.assert_contents(current, self.contents)
        self.assertFalse((self.cache / '.leases' / previous[0].parent.name).exists())

    def test_old_snapshot_survives_until_all_of_its_consumers_exit(self):
        first, second, recent = (self.owner_process() for _ in range(3))
        old = self.stage(lease_pid=first.pid)
        self.assertEqual(self.stage(lease_pid=second.pid), old)
        self.next_revision(recent.pid)
        self.next_revision(recent.pid)
        newest = self.next_revision(recent.pid)
        self.stop_owner(recent)
        self.stop_owner(first)
        self.stage()
        self.assertEqual(len(self.snapshots()), 3)
        self.assert_contents(old, self.contents)
        self.stop_owner(second)
        self.stage()
        self.assertEqual(len(self.snapshots()), 2)
        self.assertFalse(old.exists())
        self.assert_contents(newest, self.contents)

    def test_invalid_lease_is_rejected_before_publication(self):
        for pid in (0, -1):
            with self.subTest(pid=pid), self.assertRaisesRegex(RuntimeError, 'live build/test'):
                self.stage(lease_pid=pid)
        self.assertFalse(self.cache.exists())

    def test_crashed_preparation_scratch_is_removed_under_the_cache_lock(self):
        modules = self.stage()
        incomplete = self.cache / '.ui2-interrupted'
        incomplete.mkdir()
        (incomplete / 'partial.v').write_text('partial source')
        self.assertEqual(self.stage(), modules)
        self.assertFalse(incomplete.exists())
        self.assert_contents(modules, self.contents)

    def test_non_checkout_source_fails_with_an_actionable_error(self):
        source = self.root / 'not-a-checkout'
        source.mkdir()
        with self.assertRaisesRegex(RuntimeError, '(UI2|checkout|Git)'):
            prepare_ui2_source(source, self.cache, self.lock)

    def test_lock_loader_rejects_incomplete_or_invalid_contracts(self):
        path = self.root / 'dependency.json'
        path.write_text(json.dumps(self.lock))
        self.assertEqual(load_ui2_lock(path), self.lock)
        invalid = [dict(self.lock, schema_version=2), dict(self.lock, revision='master'),
                   dict(self.lock, tree='not-a-tree'), dict(self.lock, embedding_api=2),
                   {'revision': self.lock['revision']}]
        for contract in invalid:
            with self.subTest(contract=contract):
                path.write_text(json.dumps(contract))
                with self.assertRaises(RuntimeError):
                    load_ui2_lock(path)


class GgCacheTests(unittest.TestCase):
    def test_repeated_preparation_preserves_compiler_sources(self):
        for linked_directory in [False, True]:
            with self.subTest(linked_directory=linked_directory), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                vlib, modules = root / 'vlib', root / 'modules'
                source, target = vlib / 'gg', modules / 'gg'
                (source / 'canvas').mkdir(parents=True)
                (source / 'canvas/shaders').mkdir()
                (source / 'render').mkdir()
                (source / 'keyboard.v').write_text('module gg\n')
                (source / 'render/render.v').write_text('module render\n')
                (source / 'render/helper.h').write_text('/* native renderer */\n')
                (source / 'canvas/gpu_gradient.v').write_text('module canvas\n')
                (source / 'canvas/shaders/fill.glsl').write_text('// native shader\n')
                target.mkdir(parents=True)
                (target / 'canvas').mkdir()
                (target / 'keyboard.v').write_text('stale cached module\n')
                if linked_directory:
                    (target / 'render').symlink_to(source / 'render', target_is_directory=True)
                    (target / 'canvas/shaders').symlink_to(source / 'canvas/shaders', target_is_directory=True)
                else:
                    (target / 'render').mkdir()
                    (target / 'render/render.v').write_text('stale renderer\n')
                    (target / 'canvas/shaders').mkdir()
                original = {p.relative_to(source): p.read_bytes() for p in source.rglob('*') if p.is_file()}
                for _ in range(2):
                    prepare_gg_gradient(modules, vlib)
                    self.assertFalse((target / 'render').is_symlink())
                    self.assertFalse((target / 'canvas/shaders').is_symlink())
                    stage_module(source, target, 'gg')
                    actual = {p.relative_to(source): p.read_bytes() for p in source.rglob('*') if p.is_file()}
                    self.assertEqual(actual, original)


if __name__ == '__main__':
    unittest.main()
