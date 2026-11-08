from pathlib import Path
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import freeze_browser_compile as freeze
import rebuild_browser as build


class FrozenCompilerFlagsTests(unittest.TestCase):
    def test_option_operands_are_not_mistaken_for_files_and_languages_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'extra.c'
            source.write_text('int extra;')
            flags = ['-I', 'headers.c', '-framework', 'Cocoa', '-x', 'c', str(source),
                     '-x', 'none', '-O3']
            parts = freeze.parse_flags(flags, root)
            self.assertEqual([value for kind, value in parts if kind == 'source'], [(source.resolve(), 'c')])
            self.assertEqual(freeze.preprocess_flags(parts), ['-I', 'headers.c', '-framework', 'Cocoa', '-O3'])
            self.assertEqual(freeze.compile_options(['-include', 'live.h']), [])

    def test_response_files_plugins_modules_and_external_link_lists_fail_closed(self):
        for flags in [['@options'], ['-fmodules'], ['-fpass-plugin=plugin'], ['-fprofile-use=profile'],
                      ['-Xclang', '-load'], ['-Wl,@options'], ['-Wl,-filelist,files'], ['-o', 'out']]:
            with self.subTest(flags=flags), self.assertRaises(ValueError):
                freeze.parse_flags(flags, Path.cwd())

    def test_missing_source_and_missing_non_system_libraries_are_rejected(self):
        with self.assertRaises(FileNotFoundError):
            freeze.parse_flags(['missing.o'], Path.cwd())
        with self.assertRaisesRegex(RuntimeError, 'Cannot pin linker library'):
            freeze.resolved_libraries([('option', ['-lMissingVoxLibrary'])], Path.cwd())

    def test_framework_stubs_follow_the_resolved_sdk_and_detect_a_new_shadow_framework(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sdk = root / 'sdk'
            original = sdk / 'System/Library/Frameworks/Cocoa.framework/Cocoa.tbd'
            original.parent.mkdir(parents=True)
            original.write_text('system stub')
            extra = root / 'frameworks'
            extra.mkdir()
            flags = [('option', ['-F', str(extra)]), ('option', ['-framework', 'Cocoa'])]
            with patch.object(freeze.subprocess, 'check_output', return_value=str(sdk)):
                first = freeze.resolved_libraries(flags, root)
                shadow = extra / 'Cocoa.framework/Cocoa.tbd'
                shadow.parent.mkdir()
                shadow.write_text('other stub')
                second = freeze.resolved_libraries(flags, root)
            self.assertNotEqual(first, second)
            self.assertIn(str(original.resolve()), first.values())
            self.assertIn(str(shadow.resolve()), second.values())


@unittest.skipUnless(sys.platform == 'darwin', 'Production Objective-C compiler boundary')
class FrozenCompilerExecutionTests(unittest.TestCase):
    def fixture(self, root, extra_flags=()):
        stage, receipt = root / 'stage', root / 'receipt'
        stage.mkdir()
        receipt.mkdir()
        (root / 'packaging').mkdir()
        (root / 'tools').mkdir()
        (root / 'packaging/Vox.entitlements.plist').write_text('entitlements')
        (root / 'tools/localize_bundle_rpaths.py').write_text('# packaging fixture')
        resource = stage / 'Vox.app/Contents/Resources/resource'
        resource.parent.mkdir(parents=True)
        resource.write_text('bundled resource')
        before = dict(head='source-head', build_inputs_sha256='source-inputs')
        build.write_json(receipt / 'inputs-before.json', before)
        header = root / 'header.h'
        header.write_text('struct FrozenHeader { int value; };\n#define FROZEN_VALUE 7\n')
        source = receipt / 'main.c'
        source.write_text('#include <stdio.h>\nint object_value(void); int extra_value(void);\n'
                          'int main(void) { printf("%d\\n", FROZEN_VALUE + object_value() + extra_value()); }\n')
        extra = root / 'extra.c'
        extra.write_text('#ifdef __OBJC__\n#error auxiliary source must remain C\n#endif\n'
                         'int extra_value(void) { return 3; }\n')
        obj_source, obj = root / 'object.c', root / 'object.o'
        obj_source.write_text('int object_value(void) { return 2; }\n')
        subprocess.run(['clang', '-c', str(obj_source), '-o', str(obj)], check=True, capture_output=True)
        flags = receipt / 'flags.txt'
        flags.write_text(shlex.join(['-O1', '-x', 'objective-c', '-x', 'none', str(obj),
                                    '-x', 'c', str(extra), '-x', 'none', '-include', str(header), *extra_flags]))
        output = stage / 'main'
        with patch.object(build, 'repository_state', return_value=before):
            data = freeze.prepare(root, stage, receipt, source, flags, output)
        return stage, receipt, before, data, output

    def finish(self, receipt, before, data):
        freeze.validate(receipt, before, require_complete=False)
        result = subprocess.run(data['compiler_command'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        data.update(complete=True, compiler_exit=0)
        build.write_json(receipt / 'frozen-compile.json', data)
        freeze.validate(receipt, before)

    def test_link_uses_sealed_headers_auxiliary_sources_and_objects_after_source_edits(self):
        with tempfile.TemporaryDirectory(prefix="vox compiler's inputs ") as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            (root / 'header.h').write_text('#error live header must not be read\n')
            (root / 'extra.c').write_text('#error live source must not be read\n')
            (root / 'object.c').write_text('int object_value(void) { return 300; }\n')
            subprocess.run(['clang', '-c', str(root / 'object.c'), '-o', str(root / 'object.o')],
                           check=True, capture_output=True)
            self.finish(receipt, before, data)
            self.assertEqual(subprocess.check_output([str(output)], text=True).strip(), '12')
            self.assertFalse(any(path.suffix in ('.py', '.sh', '.v')
                                 for path in (receipt / 'frozen-compiler-inputs').iterdir()))

    def test_changed_source_before_sealing_starts_no_compiler(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            # A new attempt must recheck the original receipt before preprocessing.
            with patch.object(build, 'repository_state', return_value=dict(build_inputs_sha256='changed')), \
                    patch.object(freeze.subprocess, 'run') as compiler:
                with self.assertRaisesRegex(RuntimeError, 'changed before'):
                    freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt', output)
            compiler.assert_not_called()

    def test_exact_source_manifest_allows_unrelated_edits_but_rejects_consumed_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            shutil.rmtree(receipt / 'frozen-compiler-inputs')
            manifest = freeze.fingerprint([root / 'header.h', root / 'extra.c'])
            with patch.object(build, 'repository_state', return_value=dict(build_inputs_sha256='unrelated')):
                data = freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt',
                                      output, source_manifest=manifest)
            self.assertEqual(data['source_inputs'], before)
            self.assertEqual(data['exact_source_manifest'], manifest)
            self.finish(receipt, before, data)
            (root / 'header.h').write_text('changed consumed header')
            with patch.object(freeze.subprocess, 'run') as compiler:
                with self.assertRaisesRegex(RuntimeError, 'Frozen build input changed'):
                    freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt',
                                   output, source_manifest=manifest)
            compiler.assert_not_called()

    def test_changed_source_during_preprocessing_rejects_before_optimization(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            shutil.rmtree(receipt / 'frozen-compiler-inputs')
            with patch.object(build, 'repository_state', side_effect=[before, dict(build_inputs_sha256='changed')]):
                with self.assertRaisesRegex(RuntimeError, 'while sealing'):
                    freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt', output)
            self.assertFalse(output.exists())

    def test_exact_inventory_rechecks_package_membership_after_preprocessing(self):
        import production_source_manifest as manifest
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            shutil.rmtree(receipt / 'frozen-compiler-inputs')
            inventory = dict(protocol='production-source-inventory-v1', names=['engine.v'], early_inputs={})
            sources = freeze.fingerprint([root / 'header.h', root / 'extra.c'])
            def preprocess(*args, **kwargs):
                result = subprocess.run(*args, **kwargs)
                inventory['names'] = ['new.v']
                return result
            with patch.object(manifest, 'input_names', return_value=['engine.v']), \
                    patch.object(build, 'repository_state', return_value=dict(build_inputs_sha256='other')):
                with self.assertRaisesRegex(RuntimeError, 'membership changed'):
                    freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt', output,
                                   run=preprocess, source_manifest=sources, source_inventory=inventory)

    def test_verified_parsed_buffers_survive_edits_through_native_sealing_and_publication(self):
        import production_source_manifest as manifest
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            shutil.rmtree(receipt / 'frozen-compiler-inputs')
            subprocess.run(['git', 'init', '-q', '-b', 'master', str(root)], check=True)
            (root / '.gitignore').write_text('/stage/\n/receipt/\n')
            engine = root / 'engine.v'
            engine.write_text('module main\n')
            inventory = manifest.begin(root)
            component = receipt / 'browser-sources'
            component.mkdir()
            (component / 'v_sources').write_bytes(str(engine).encode())
            (component / 'v_source_digests').write_bytes(freeze.digest(engine).encode())
            build.write_json(component / 'parsed-verified.json', dict(protocol='verified-parsed-buffers-v1',
                             sources={str(engine): freeze.digest(engine)}))
            engine.write_text('edited after compiler parsed immutable buffers')
            sources = manifest.combine(root, inventory, [component], parsed=True)
            with patch.object(build, 'repository_state', return_value=dict(head='later', build_inputs_sha256='later')):
                data = freeze.prepare(root, stage, receipt, receipt / 'main.c', receipt / 'flags.txt', output,
                                      source_manifest=sources, source_inventory=inventory, source_components=[component])
            self.assertEqual(data['source_inputs'], before)
            self.assertEqual(data['source_inputs_at_sealing']['source_kind'],
                             'verified parsed buffers and sealed native inputs')
            self.assertNotEqual(data['source_inputs_at_sealing']['build_inputs_sha256'], 'later')
            self.finish(receipt, before, data)
            self.assertEqual(subprocess.check_output([str(output)], text=True).strip(), '12')
            (component / 'parsed-verified.json').write_text('mutated proof')
            with self.assertRaisesRegex(RuntimeError, 'input changed'):
                freeze.validate(receipt, before)

    def test_mutated_generated_input_packaging_tool_or_resource_rejects_the_result(self):
        for target in ['preprocessed', 'tool', 'resource', 'entitlements']:
            with self.subTest(target=target), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                stage, receipt, before, data, output = self.fixture(root)
                if target == 'preprocessed':
                    path = next((receipt / 'frozen-compiler-inputs').glob('*.i'))
                elif target == 'tool':
                    path = root / 'tools/localize_bundle_rpaths.py'
                elif target == 'resource':
                    path = stage / 'Vox.app/Contents/Resources/resource'
                else:
                    path = root / 'packaging/Vox.entitlements.plist'
                path.write_text('changed')
                with self.assertRaisesRegex(RuntimeError, 'input changed'):
                    freeze.validate(receipt, before, require_complete=False)

    def test_incomplete_unknown_protocol_and_wrong_source_receipts_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, receipt, before, data, output = self.fixture(root)
            with self.assertRaisesRegex(RuntimeError, 'did not complete'):
                freeze.validate(receipt, before)
            with self.assertRaisesRegex(RuntimeError, 'does not match'):
                freeze.validate(receipt, dict(build_inputs_sha256='wrong'))
            data.update(protocol='unknown', complete=True, compiler_exit=0)
            build.write_json(receipt / 'frozen-compile.json', data)
            with self.assertRaisesRegex(RuntimeError, 'does not match'):
                freeze.validate(receipt, before)

    def test_changed_dynamic_library_and_new_earlier_search_result_are_rejected(self):
        for earlier in [False, True]:
            with self.subTest(earlier=earlier), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                first, second = root / 'first', root / 'second'
                first.mkdir()
                second.mkdir()
                source, library = root / 'library.c', second / 'libFrozenFixture.dylib'
                source.write_text('int library_value(void) { return 17; }\n')
                subprocess.run(['clang', '-dynamiclib', str(source), '-o', str(library)],
                               check=True, capture_output=True)
                stage, receipt, before, data, output = self.fixture(root,
                    ['-L' + str(first), '-L' + str(second), '-lFrozenFixture'])
                if earlier:
                    shutil.copyfile(library, first / library.name)
                else:
                    library.write_bytes(b'changed library')
                with self.assertRaisesRegex(RuntimeError, 'changed'):
                    freeze.validate(receipt, before, require_complete=False)


if __name__ == '__main__':
    unittest.main()
