import unittest
import json
import hashlib
import shutil
from pathlib import Path
from tempfile import TemporaryDirectory

from bbc_browser_instructions import URL, audit_instruction_logging, discover_runtime_libraries, loaded_native_images, evaluate_cohort, jsc_baseline_environment, parse_args, preserve_production_compilation, replay_vox_environment, trial_order, run_trial, validate_document, verify_benchmark_inputs
from types import SimpleNamespace
from unittest.mock import patch
from hacker_news_browser_instructions import evaluate_pairs
from measure_sealed_github_instructions import fingerprint, native_dependencies


def document():
    expected = dict(title='BBC Home | News', headlines=['First story', 'Second story'],
                    image_sources=['https://images.test/photo.jpg'], placeholder_sources=[])
    audit = dict(url=URL, title=expected['title'], ready='complete', viewport_width=1024,
                 viewport_height=768, fonts_status='loaded', font_faces=[], selections=[
        dict(name='body', count=1, elements=[dict(text='Full document text ' * 100)]),
        dict(name='headlines', count=2, elements=[dict(text=text) for text in expected['headlines']]),
        dict(name='images', count=1, elements=[dict(rect=dict(x=10, y=20, width=200, height=100),
            attributes=dict(src='https://images.test/photo.jpg'),
            image=dict(complete=True, natural_width=480))]),
        dict(name='all', count=2000, elements=[])])
    return audit, expected


class BBCInstructionTests(unittest.TestCase):
    def parallel_compilation_fixture(self, root):
        app, binary, source, metadata, published, output = self.compilation_fixture(root)
        folder = root / 'Build/production-build/receipts/parallel-fixture'
        folder.mkdir(parents=True)
        compiler = root / 'Build/prealloc/stage/compiler/v'
        compiler.parent.mkdir(parents=True)
        compiler.write_bytes(b'pinned split compiler')
        runtime = compiler.parent.parent / 'manifest.json'
        runtime.write_text(json.dumps(dict(compiler_sha256=hashlib.sha256(compiler.read_bytes()).hexdigest())))
        receipt = dict(exit=0, executable=str(binary),
            executable_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
            c_compile=dict(mode='parallel', requested='parallel', units=33, compiler=str(compiler)),
            inputs=dict(build_inputs_sha256='stable-inputs', head='before'),
            verified_inputs=dict(build_inputs_sha256='stable-inputs', head='after'))
        serialized = json.dumps(receipt, indent=2, sort_keys=True) + '\n'
        published.write_text(serialized)
        (folder / 'result.json').write_text(serialized)
        (folder / 'c-compile.json').write_text(json.dumps(receipt['c_compile']))
        (folder / 'inputs-before.json').write_text(json.dumps(receipt['inputs']))
        return app, binary, published, output, folder, compiler, receipt

    def test_parallel_compilation_preserves_verified_receipts_without_claiming_sealed_c(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            app, binary, published, output, folder, compiler, receipt = self.parallel_compilation_fixture(root)
            with patch('bbc_browser_instructions.REPO', root):
                paths = preserve_production_compilation(output, dict(vox=app, control=app), fingerprint({binary}))
            manifest = json.loads((output / 'production-compilation.json').read_text())
            self.assertTrue(manifest['passed'])
            self.assertEqual(manifest['engines']['vox'], manifest['engines']['control'])
            self.assertFalse(manifest['engines']['vox']['generated_c_preserved'])
            self.assertEqual(manifest['engines']['vox']['c_compile']['mode'], 'parallel')
            self.assertEqual(len(manifest['files']), 5)
            self.assertFalse(any(path.name == 'Vox' or path.name == 'v' or path.suffix == '.i' for path in paths))
            pins = fingerprint(paths)
            for path in folder.iterdir():
                path.unlink()
            compiler.unlink()
            self.assertEqual(fingerprint(paths), pins)

    def test_parallel_compilation_rejects_incomplete_inconsistent_or_changed_provenance(self):
        for failure in ['wrong-mode', 'changed-inputs', 'superseded', 'missing-result',
                        'wrong-c-mode', 'wrong-before', 'changed-compiler']:
            with self.subTest(failure=failure), TemporaryDirectory() as directory:
                root = Path(directory).resolve()
                app, binary, published, output, folder, compiler, receipt = self.parallel_compilation_fixture(root)
                if failure == 'wrong-mode':
                    receipt['c_compile']['mode'] = 'single'
                elif failure == 'changed-inputs':
                    receipt['verified_inputs']['build_inputs_sha256'] = 'changed'
                elif failure == 'superseded':
                    receipt['superseded'] = True
                elif failure == 'missing-result':
                    (folder / 'result.json').unlink()
                elif failure == 'wrong-c-mode':
                    (folder / 'c-compile.json').write_text('{}')
                elif failure == 'wrong-before':
                    (folder / 'inputs-before.json').write_text('{}')
                elif failure == 'changed-compiler':
                    compiler.write_bytes(b'changed compiler')
                serialized = json.dumps(receipt, indent=2, sort_keys=True) + '\n'
                published.write_text(serialized)
                if failure != 'missing-result':
                    (folder / 'result.json').write_text(serialized)
                with patch('bbc_browser_instructions.REPO', root):
                    with self.assertRaises((RuntimeError, FileNotFoundError)):
                        preserve_production_compilation(output, dict(vox=app), fingerprint({binary}))
                self.assertFalse(json.loads((output / 'production-compilation.json').read_text())['passed'])

    def test_parallel_compilation_rejects_metadata_changes_after_its_initial_read(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            app, binary, published, output, folder, compiler, receipt = self.parallel_compilation_fixture(root)
            original_read = Path.read_bytes
            changed = False
            def replace_after_read(path):
                nonlocal changed
                data = original_read(path)
                if path == folder / 'c-compile.json' and not changed:
                    changed = True
                    path.write_bytes(b'{}')
                return data
            with patch('bbc_browser_instructions.REPO', root), patch.object(Path, 'read_bytes', replace_after_read):
                with self.assertRaisesRegex(RuntimeError, 'Parallel receipt changed'):
                    preserve_production_compilation(output, dict(vox=app), fingerprint({binary}))
            self.assertTrue(changed)
            self.assertFalse(json.loads((output / 'production-compilation.json').read_text())['passed'])

    def compilation_fixture(self, root):
        app = root / 'Build/v/Vox.app'
        binary = app / 'Contents/MacOS/Vox'
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b'pinned browser')
        source = root / 'Build/receipt/0-Vox.c.i'
        source.parent.mkdir()
        source.write_bytes(b'generated compiler input')
        library = root / 'library.dylib'
        library.write_bytes(b'native library stays in place')
        metadata = source.parent / 'frozen-compile.json'
        metadata.write_text(json.dumps(dict(sealed_inputs={
            str(source): hashlib.sha256(source.read_bytes()).hexdigest(),
            str(library): hashlib.sha256(library.read_bytes()).hexdigest()})))
        published = root / 'Build/production-build/latest.json'
        published.parent.mkdir()
        published.write_text(json.dumps(dict(exit=0, executable=str(binary),
            executable_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
            frozen_compilation=str(metadata))))
        output = root / 'observations'
        output.mkdir()
        return app, binary, source, metadata, published, output

    def test_compilation_evidence_survives_original_receipt_pruning_and_deduplicates_controls(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            app, binary, source, metadata, published, output = self.compilation_fixture(root)
            with patch('bbc_browser_instructions.REPO', root):
                paths = preserve_production_compilation(output, dict(vox=app, control=app),
                                                       fingerprint({binary}))
            pins = fingerprint(paths)
            manifest = json.loads((output / 'production-compilation.json').read_text())
            self.assertTrue(manifest['passed'])
            self.assertEqual(manifest['engines']['vox'], manifest['engines']['control'])
            self.assertEqual(len(manifest['files']), 3)
            self.assertFalse(any(path.name.endswith('.dylib') or path.name == 'Vox' for path in paths))
            source.unlink()
            metadata.unlink()
            published.unlink()
            self.assertEqual(fingerprint(paths), pins)
            self.assertEqual(len(list((output / 'production-compilation').rglob('*.i'))), 1)
            self.assertEqual(binary.read_bytes(), b'pinned browser')

    def test_compilation_preservation_rejects_wrong_receipt_missing_or_changed_sources(self):
        for failure in ['wrong_executable', 'missing_source', 'changed_source', 'missing_main']:
            with self.subTest(failure=failure), TemporaryDirectory() as directory:
                root = Path(directory).resolve()
                app, binary, source, metadata, published, output = self.compilation_fixture(root)
                if failure == 'wrong_executable':
                    receipt = json.loads(published.read_text())
                    receipt['executable_sha256'] = 'wrong'
                    published.write_text(json.dumps(receipt))
                elif failure == 'missing_source':
                    source.unlink()
                elif failure == 'changed_source':
                    source.write_bytes(b'replaced compiler input')
                else:
                    metadata.write_text(json.dumps(dict(sealed_inputs={})))
                with patch('bbc_browser_instructions.REPO', root):
                    with self.assertRaises((RuntimeError, FileNotFoundError)):
                        preserve_production_compilation(output, dict(vox=app), fingerprint({binary}))
                self.assertFalse(json.loads((output / 'production-compilation.json').read_text())['passed'])

    def test_compilation_preservation_rejects_browser_or_publication_changes_during_copy(self):
        original_copy = shutil.copyfile
        for failure in ['browser', 'publication']:
            with self.subTest(failure=failure), TemporaryDirectory() as directory:
                root = Path(directory).resolve()
                app, binary, source, metadata, published, output = self.compilation_fixture(root)
                def replace(source_path, target_path):
                    original_copy(source_path, target_path)
                    (binary if failure == 'browser' else published).write_bytes(b'changed')
                with patch('bbc_browser_instructions.REPO', root), \
                     patch('bbc_browser_instructions.shutil.copyfile', side_effect=replace):
                    with self.assertRaises(RuntimeError):
                        preserve_production_compilation(output, dict(vox=app), fingerprint({binary}))
                self.assertFalse(json.loads((output / 'production-compilation.json').read_text())['passed'])

    def test_external_comparison_app_does_not_claim_canonical_compiler_evidence(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            output = root / 'observations'
            output.mkdir()
            with patch('bbc_browser_instructions.REPO', root):
                paths = preserve_production_compilation(output, dict(vox=root / 'External.app'), {})
            self.assertEqual(paths, {output / 'production-compilation.json'})
            manifest = json.loads((output / 'production-compilation.json').read_text())
            self.assertTrue(manifest['passed'])
            self.assertEqual(manifest['engines'], {})

    def test_late_library_dependencies_use_the_original_executable_rpaths(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable, sibling = root / 'Vox', root / 'sibling.dylib'
            late = root / 'plugins/late.dylib'
            dependency = root / 'libraries/dependency.dylib'
            for path in [executable, sibling, late, dependency]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'image')
            def otool(command, text):
                image = Path(command[-1])
                if command[1] == '-l':
                    return (f'cmd LC_RPATH\ncmdsize 64\npath {dependency.parent} (offset 12)\n'
                            if image == executable else '')
                if image == late:
                    return (str(image) + ':\n\t@rpath/dependency.dylib (compatibility version 1.0)\n'
                            '\t@executable_path/sibling.dylib (compatibility version 1.0)\n')
                return str(image) + ':\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0)\n'
            with patch('measure_sealed_github_instructions.subprocess.check_output', side_effect=otool):
                self.assertEqual(native_dependencies(executable), {executable})
                self.assertEqual(native_dependencies(executable, extra_images=[late]),
                                 {executable, late, sibling, dependency})

    def test_runtime_images_belong_to_root_and_precede_png(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'Vox'
            library = root / 'library with spaces.dylib'
            late = root / 'late.dylib'
            for path in [executable, library, late]:
                path.write_bytes(b'image')
            log = (f'dyld[42]: <uuid> {executable}\n'
                   f'dyld[43]: <uuid> {late}\n'
                   f'dyld[42]: <uuid> /usr/lib/libSystem.B.dylib\n'
                   f'dyld[42]: <uuid> {library}\n'
                   'Vox coalition instructions: {"label":"capture_document_encoded"}\n'
                   f'dyld[42]: <uuid> {late}\n')
            self.assertEqual(loaded_native_images(log, 42, executable), {executable, library})
            for pid, text in [(True, log), (0, log), (42, log.split('Vox coalition')[0]),
                              (44, log), (42, log.replace(str(executable), str(root / 'missing')))]:
                with self.subTest(pid=pid, text=text), self.assertRaises(RuntimeError):
                    loaded_native_images(text, pid, executable)

    def runtime_discovery_fixture(self, directory):
        root = Path(directory).resolve()
        apps = {name: root / name for name in ['vox', 'control']}
        paths = set()
        for app in apps.values():
            executable = app / 'Contents/MacOS/Vox'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b'original browser')
            paths.add(executable)
        library, dependency = root / 'late.dylib', root / 'dependency.dylib'
        library.write_bytes(b'dynamic library')
        dependency.write_bytes(b'transitive library')
        output = root / 'output'
        output.mkdir()
        args = SimpleNamespace(output=output, vox_environment={'VOX_PROXY': 'fixture'})
        return args, apps, paths, library, dependency

    def test_runtime_discovery_pins_transitive_libraries_and_restores_environment(self):
        with TemporaryDirectory() as directory:
            args, apps, paths, library, dependency = self.runtime_discovery_fixture(directory)
            original = args.vox_environment
            calls = []
            def trial(engine, app, folder, options):
                calls.append((engine, folder.name, dict(options.vox_environment)))
                folder.mkdir()
                executable = app / 'Contents/MacOS/Vox'
                (folder / 'browser.log').write_text(
                    f'dyld[42]: <uuid> {executable}\ndyld[42]: <uuid> {library}\n'
                    '{"label":"capture_document_encoded"}\n')
                return dict(exit=0, kernel_exit_status=0, pixels_exact=True, content_exact=True,
                            root=dict(pid=42))
            def dependencies(image, extra_images=()):
                return {image, dependency, *extra_images}
            with patch('bbc_browser_instructions.run_trial', side_effect=trial), \
                 patch('bbc_browser_instructions.browser.native_dependencies', side_effect=dependencies):
                expanded, pins = discover_runtime_libraries(args, apps, paths, fingerprint(paths))
            self.assertEqual([name for _, name, _ in calls], ['runtime-discovery-vox',
                'runtime-discovery-control', 'runtime-validation-vox', 'runtime-validation-control'])
            self.assertTrue(all(env == dict(original, DYLD_PRINT_LIBRARIES='1') for _, _, env in calls))
            self.assertIs(args.vox_environment, original)
            self.assertTrue({library, dependency} <= expanded)
            self.assertEqual(pins, fingerprint(expanded))
            manifest = json.loads((args.output / 'runtime-libraries.json').read_text())
            self.assertTrue(manifest['passed'])
            self.assertFalse(manifest['acceptance'])

    def test_runtime_discovery_rejects_browser_replacement_and_validation_drift(self):
        for failure in ['browser', 'library', 'new_image', 'pixels', 'exception']:
            with self.subTest(failure=failure), TemporaryDirectory() as directory:
                args, apps, paths, library, dependency = self.runtime_discovery_fixture(directory)
                original = args.vox_environment
                calls = []
                def trial(engine, app, folder, options):
                    calls.append(folder.name)
                    if failure == 'exception':
                        raise RuntimeError('browser failed')
                    folder.mkdir()
                    executable = app / 'Contents/MacOS/Vox'
                    if failure == 'browser':
                        executable.write_bytes(b'changed browser')
                    if failure == 'library' and 'validation' in folder.name:
                        library.write_bytes(b'changed library')
                    extra = (f'dyld[42]: <uuid> {dependency}\n'
                             if failure == 'new_image' and 'validation' in folder.name else '')
                    (folder / 'browser.log').write_text(f'dyld[42]: <uuid> {executable}\n'
                        f'dyld[42]: <uuid> {library}\n{extra}'
                        '{"label":"capture_document_encoded"}\n')
                    return dict(exit=0, kernel_exit_status=0,
                                pixels_exact=failure != 'pixels', content_exact=True, root=dict(pid=42))
                with patch('bbc_browser_instructions.run_trial', side_effect=trial), \
                     patch('bbc_browser_instructions.browser.native_dependencies',
                           side_effect=lambda p, extra_images=(): {p, *extra_images}):
                    with self.assertRaises(RuntimeError):
                        discover_runtime_libraries(args, apps, paths, fingerprint(paths))
                self.assertIs(args.vox_environment, original)
                self.assertFalse(json.loads((args.output / 'runtime-libraries.json').read_text())['passed'])
                self.assertTrue(calls)

    def test_resolved_edge_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-resolved-edge-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_resolved_edge_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RESOLVED_EDGE_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_flex_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-flex-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_flex_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_FLEX_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_flex_image_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-flex-image-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_flex_image_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_FLEX_IMAGE_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_relative_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-relative-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_relative_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RELATIVE_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_svg_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-svg-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_svg_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_SVG_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_inline_tree_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-inline-tree-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_inline_tree_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INLINE_TREE_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_covered_style_sheet_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-retain-covered-style-sheet-walk']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_retain_covered_style_sheet_walk)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_COVERED_STYLE_SHEET_WALK='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_covered_style_sheet_anchor_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-retain-covered-style-sheet-anchor-walks']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_retain_covered_style_sheet_anchor_walks)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_COVERED_STYLE_SHEET_ANCHOR_WALKS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_fifo_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-retain-fifo-measurement-eviction']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_retain_fifo_measurement_eviction)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_FIFO_MEASUREMENT_EVICTION='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_markerless_measurements_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-markerless-measurements']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_markerless_measurements)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_MARKERLESS_MEASUREMENTS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_grid_placement_reuse_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-grid-placement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_grid_placement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_GRID_PLACEMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_unused_measurement_heights_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-unused-measurement-heights']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_unused_measurement_heights)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_UNUSED_MEASUREMENT_HEIGHTS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_native_callback_call_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-native-callback-call']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_native_callback_call)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_NATIVE_CALLBACK_CALL='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_extended_image_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-extended-image-measurements']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_extended_image_measurements)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EXTENDED_IMAGE_MEASUREMENTS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_extended_image_tree_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-extended-image-trees']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_extended_image_trees)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EXTENDED_IMAGE_TREES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_flow_image_tree_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-retained-flow-image-trees']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_retained_flow_image_trees)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FLOW_IMAGE_TREES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_committed_flex_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-committed-flex-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_committed_flex_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COMMITTED_FLEX_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_committed_grid_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-committed-grid-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_committed_grid_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COMMITTED_GRID_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_committed_inline_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-committed-inline-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_committed_inline_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COMMITTED_INLINE_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_compact_query_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-compact-query-envelope']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_compact_query_envelope)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COMPACT_QUERY_ENVELOPE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_grid_measurement_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference',
                '--control-disable-grid-measurement-reuse']
        with self.assertRaises(SystemExit):
            parse_args(argv)
        args = parse_args(argv + ['--control-vox-app', 'Build/v/Vox.app'])
        self.assertTrue(args.control_disable_grid_measurement_reuse)
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_GRID_MEASUREMENT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_svg_layout_policy_is_explicit_and_common_to_both_vox_arms(self):
        ready = dict(proxy='socks5h://fixture', ca='/fixture/ca.pem')
        for retain in (False, True):
            argv = ['--archive', 'archive', '--output', 'Build/result',
                    '--memory-guard-registry', 'pids.json', '--capture-reference',
                    '--control-vox-app', 'Build/v/Vox.app',
                    '--control-retain-broad-conditional-rule-deletion']
            args = parse_args(argv + (['--retain-css-layout-for-svg'] if retain else []))
            environment = replay_vox_environment(args, ready)
            self.assertEqual(environment.get('VOX_RETAIN_CSS_LAYOUT_FOR_SVG'),
                             '1' if retain else None)
            args.vox_environment = environment
            seen = []
            def observe(engine, app, folder, options):
                seen.append(dict(options.vox_environment))
                return {'exit': 0}
            with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                for engine in ('control', 'vox'):
                    run_trial(engine, 'same-app', engine, args)
            self.assertEqual(seen, [dict(environment, VOX_RETAIN_BROAD_CONDITIONAL_RULE_DELETION='1'),
                                    environment])
            self.assertIs(args.vox_environment, environment)

    def test_historical_rendering_policies_are_explicit_and_common_to_both_vox_arms(self):
        ready = dict(proxy='socks5h://fixture', ca='/fixture/ca.pem')
        for logical in (False, True):
            for webp in (False, True):
                args = SimpleNamespace(retain_logical_paint_snapping=logical,
                                       retain_incremental_webp_paint_policy=webp,
                                       control_disable_grid_width_only=False,
                                       control_retain_inline_measurement_indefinite_height=True)
                environment = replay_vox_environment(args, ready)
                self.assertEqual(environment.get('VOX_RETAIN_LOGICAL_PAINT_SNAPPING'),
                                 '1' if logical else None)
                self.assertEqual(environment.get('VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY'),
                                 '1' if webp else None)
                args.vox_environment = environment
                seen = []
                def observe(engine, app, folder, options):
                    seen.append(dict(options.vox_environment))
                    return {'exit': 0}
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                    for engine in ('control', 'vox'):
                        run_trial(engine, 'same-app', engine, args)
                self.assertEqual(seen, [dict(environment, VOX_RETAIN_INLINE_MEASUREMENT_INDEFINITE_HEIGHT='1'),
                                        environment])
                self.assertIs(args.vox_environment, environment)

    def test_historical_border_sampling_is_explicit_and_shared_with_the_control(self):
        ready = dict(proxy='socks5h://fixture', ca='/fixture/ca.pem')
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        for retain in (False, True):
            args = parse_args(base + (['--retain-degenerate-border-msaa'] if retain else []))
            self.assertEqual(args.retain_degenerate_border_msaa, retain)
            environment = replay_vox_environment(args, ready)
            self.assertEqual(environment.get('VOX_RETAIN_DEGENERATE_BORDER_MSAA'),
                             '1' if retain else None)
            args.vox_environment = environment
            args.control_disable_flex_measurement_reuse = True
            seen = []
            def observe(engine, app, folder, options):
                seen.append(dict(options.vox_environment))
                return {'exit': 0}
            with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                for engine in ('control', 'vox'):
                    run_trial(engine, 'same-app', engine, args)
            self.assertEqual(seen, [dict(environment, VOX_DISABLE_FLEX_MEASUREMENT_REUSE='1'),
                                    environment])
            self.assertIs(args.vox_environment, environment)

    def test_frame_task_layout_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-frame-task-layout-coalescing']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_frame_task_layout_coalescing)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_FRAME_TASK_LAYOUT_COALESCING='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_adblock_token_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-adblock-token-reuse']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_adblock_token_reuse)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_ADBLOCK_TOKEN_REUSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_grid_auto_height_seed_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-grid-auto-height-seed']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_grid_auto_height_seed)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_GRID_AUTO_HEIGHT_SEED='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_flow_svg_trees_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-retained-flow-svg-trees']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_retained_flow_svg_trees)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FLOW_SVG_TREES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_object_receiver_call_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-object-receiver-call']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_object_receiver_call)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_OBJECT_RECEIVER_CALL='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_positioned_definite_image_reuse_control_requires_app_and_restores_environment_after_failure(self):
        base = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference', '--control-disable-positioned-definite-image-reuse']
        with self.assertRaises(SystemExit):
            parse_args(base)
        args = parse_args(base + ['--control-vox-app', 'Vox.app'])
        self.assertTrue(args.control_disable_positioned_definite_image_reuse)
        environment = {'VOX_PROXY': 'socks5h://fixture', 'VOX_RETAIN_DEGENERATE_BORDER_MSAA': '1'}
        args.vox_environment = environment
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_POSITIONED_DEFINITE_IMAGE_REUSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_input_preservation_is_optional_and_requires_independent_storage(self):
        argv = ['--archive', 'archive', '--output', 'Build/result',
                '--memory-guard-registry', 'pids.json', '--capture-reference']
        self.assertIsNone(parse_args(argv).preserve_inputs)
        path = Path('docs/performance/raw/bbc-inputs.tar.gz').resolve()
        self.assertEqual(parse_args(argv + ['--preserve-inputs', str(path)]).preserve_inputs, path)
        for destination in ['Build/inputs.tar.gz', 'Build', 'Build/result/inputs.tar.gz']:
            with self.subTest(destination=destination), self.assertRaises(SystemExit):
                parse_args(argv + ['--preserve-inputs', destination])
        with TemporaryDirectory() as directory:
            output = str(Path(directory) / 'trial')
            external = ['--archive', 'archive', '--output', output,
                        '--memory-guard-registry', 'pids.json', '--capture-reference']
            with self.assertRaises(SystemExit):
                parse_args(external + ['--preserve-inputs', output + '/inputs.tar.gz'])

    def test_verified_identity_survives_a_later_shared_bundle_replacement(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            with patch('bbc_browser_instructions.time.time', return_value=12345):
                verify_benchmark_inputs({source}, pinned, root)
            self.assertFalse((root / 'input-identity-failure.json').exists())
            source.write_text('later production bundle')
            receipt = json.loads((root / 'input-identity-after.json').read_text())
            self.assertEqual(receipt, dict(passed=True, observed_unix=12345, files=pinned))
            self.assertNotEqual(receipt['files'], fingerprint({source}))

    def test_transient_input_change_remains_recorded_after_original_bytes_return(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            source.write_text('changed')
            changed = fingerprint({source})
            with self.assertRaisesRegex(RuntimeError, 'Pinned benchmark input changed'):
                verify_benchmark_inputs({source}, pinned, root)
            source.write_text('original')
            self.assertEqual(fingerprint({source}), pinned)
            receipt = json.loads((root / 'input-identity-failure.json').read_text())
            self.assertTrue(receipt['invalidates_cohort'])
            self.assertEqual(receipt['changed_inputs'], [dict(path=str(source),
                expected=pinned[str(source)], observed=changed[str(source)])])
            self.assertFalse((root / 'input-identity-after.json').exists())

    def test_unavailable_input_is_recorded_and_still_rejected(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'input.txt'
            source.write_text('original')
            pinned = fingerprint({source})
            source.unlink()
            with self.assertRaises(FileNotFoundError):
                verify_benchmark_inputs({source}, pinned, root)
            receipt = json.loads((root / 'input-identity-failure.json').read_text())
            self.assertTrue(receipt['invalidates_cohort'])
            self.assertEqual(receipt['unavailable_input'], str(source))
            self.assertFalse((root / 'input-identity-after.json').exists())

    def test_baseline_jit_settings_are_isolated_from_brave_and_restored_on_failure(self):
        environment = dict(VOX_PROXY='socks5h://fixture', VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY='1')
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               jsc_baseline_warmup=50, control_jsc_baseline_warmup=500)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, JSC_thresholdForJITAfterWarmUp='500',
                                            JSC_thresholdForJITSoon='100')),
                                ('vox', dict(environment, JSC_thresholdForJITAfterWarmUp='50',
                                            JSC_thresholdForJITSoon='10')),
                                ('brave', environment)])
        for engine in ['control', 'vox']:
            with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                with self.assertRaises(RuntimeError):
                    run_trial(engine, 'same-app', engine, args)
            self.assertIs(args.vox_environment, environment)

    def test_baseline_jit_thresholds_are_explicit_and_bounded(self):
        args = ['--archive', 'fixture', '--output', 'results', '--memory-guard-registry', 'pids',
                '--capture-reference']
        defaults = parse_args(args)
        self.assertIsNone(defaults.jsc_baseline_warmup)
        self.assertIsNone(defaults.control_jsc_baseline_warmup)
        self.assertEqual(jsc_baseline_environment(None), {})
        self.assertEqual(jsc_baseline_environment(1), dict(JSC_thresholdForJITAfterWarmUp='1',
                                                         JSC_thresholdForJITSoon='1'))
        self.assertEqual(parse_args(args + ['--jsc-baseline-warmup', '50']).jsc_baseline_warmup, 50)
        controlled = parse_args(args + ['--control-vox-app', 'Vox.app', '--control-jsc-baseline-warmup', '500'])
        self.assertEqual(controlled.control_jsc_baseline_warmup, 500)
        for flag in ['--jsc-baseline-warmup', '--control-jsc-baseline-warmup']:
            for invalid in ['0', '-1', '2147483648', '1.5']:
                with self.subTest(flag=flag, invalid=invalid), self.assertRaises(SystemExit):
                    parse_args(args + ['--control-vox-app', 'Vox.app', flag, invalid])
        with self.assertRaises(SystemExit):
            parse_args(args + ['--control-jsc-baseline-warmup', '500'])

    def test_instruction_logging_accepts_phase_counters_without_verbose_font_traces(self):
        row = audit_instruction_logging({'exit': 0}, 'Vox instructions cumulative: frame_complete 123\n')
        self.assertEqual(row['exit'], 0)
        self.assertEqual(row['font_generation_diagnostic_lines'], 0)

    def test_instruction_logging_rejects_all_font_trace_kinds_and_preserves_prior_error(self):
        log = '\n'.join('Vox retained ' + kind + ' font generation: 1 -> 2'
                        for kind in ['block', 'inline', 'text'])
        row = audit_instruction_logging({'exit': 0, 'error': 'prior error'}, log)
        self.assertEqual(row['exit'], 1)
        self.assertEqual(row['font_generation_diagnostic_lines'], 3)
        self.assertIn('prior error', row['error'])
        self.assertIn('outside a diagnostic run', row['error'])

    def test_instruction_logging_retains_explicit_diagnostic_observations(self):
        row = audit_instruction_logging({'exit': 0}, 'Vox retained text font generation: 1 -> 2', True)
        self.assertEqual(row['exit'], 0)
        self.assertEqual(row['font_generation_diagnostic_lines'], 1)
        self.assertTrue(row['font_generation_diagnostics_allowed'])

    def test_instruction_logging_missing_log_invalidates_even_a_diagnostic(self):
        for diagnostic in [False, True]:
            row = audit_instruction_logging({'exit': 0}, None, diagnostic)
            self.assertEqual(row['exit'], 1)
            self.assertIsNone(row['font_generation_diagnostic_lines'])

    def test_conditional_sheet_invalidation_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_conditional_sheet_invalidation=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CONDITIONAL_SHEET_INVALIDATION='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_inactive_conditional_sheet_skip_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_inactive_conditional_sheet_skip=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INACTIVE_CONDITIONAL_SHEET_SKIP='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_classic_import_word_scan_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_classic_import_word_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CLASSIC_IMPORT_WORD_SCAN='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_classic_import_call_scan_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_classic_import_call_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CLASSIC_IMPORT_CALL_SCAN='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_classic_import_named_method_scan_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_classic_import_named_method_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CLASSIC_IMPORT_NAMED_METHOD_SCAN='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_keyword_free_module_lexer_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_keyword_free_module_lexer=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_KEYWORD_FREE_MODULE_LEXER='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_empty_pseudo_candidate_lookups_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_empty_pseudo_candidate_lookups=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_EMPTY_PSEUDO_CANDIDATE_LOOKUPS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_attribute_bucket_candidates_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_attribute_bucket_candidates=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_ATTRIBUTE_BUCKET_CANDIDATES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_text_bidi_scan_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_text_bidi_scans=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_TEXT_BIDI_SCANS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_longhand_shape_reuse_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_longhand_shape_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LONGHAND_SHAPE_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_longhand_eligibility_first_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_longhand_eligibility_first=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LONGHAND_ELIGIBILITY_FIRST='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_protected_value_index_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_protected_value_index=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_PROTECTED_VALUE_INDEX='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_shared_element_geometry_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_shared_element_geometry=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_SHARED_ELEMENT_GEOMETRY='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_grid_layout_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_grid_layout=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_GRID_LAYOUT='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_intrinsic_seed_visits_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_intrinsic_seed_visits=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INTRINSIC_SEED_VISITS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_document_filter_memo_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_document_filter_memo=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_DOCUMENT_FILTER_MEMO='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_static_user_style_filter_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_static_user_style_filter=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_STATIC_USER_STYLE_FILTER='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_targeted_user_style_changes_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_targeted_user_style_changes=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_TARGETED_USER_STYLE_CHANGES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_deleted_style_rule_invalidation_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_deleted_style_rule_invalidation=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_DELETED_STYLE_RULE_INVALIDATION='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_attribute_tag_buckets_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_attribute_tag_buckets=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_ATTRIBUTE_TAG_BUCKETS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_shared_node_properties_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture',
                       'VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY': '1'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_shared_node_properties=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_SHARED_NODE_PROPERTIES='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_positioned_image_ratio_reuse_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_positioned_image_ratio_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_POSITIONED_IMAGE_RATIO_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_live_pending_font_refresh_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_live_pending_font_refresh=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LIVE_PENDING_FONT_REFRESH='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_live_pending_text_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_live_pending_text_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_LIVE_PENDING_TEXT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_pending_intrinsic_font_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_pending_intrinsic_font_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_intrinsic_font_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_intrinsic_font_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INTRINSIC_FONT_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_constant_longhand_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_constant_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_CONSTANT_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_font_display_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_face_specific_font_display=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_FACE_SPECIFIC_FONT_DISPLAY='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_retained_item_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_flow_items=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FLOW_ITEMS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_stationary_copy_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_copy_stationary_raster_commands=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_COPY_STATIONARY_RASTER_COMMANDS='1')),
                                ('vox', environment), ('brave', environment)])
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_color_control_keeps_other_extensions_enabled_and_restores_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_color_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_COLOR_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_extended_longhand_control_is_isolated_and_restored_on_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_extended_longhand_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EXTENDED_LONGHAND_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_cohort_projects_controls_and_preserves_the_integer_brave_gate(self):
        def row(count):
            return dict(exit=0, pixels_exact=True, content_exact=True,
                        capture_ownership_audit=dict(passed=True),
                        launch_instruction_interval=dict(lower=count, upper=count))
        pairs = [dict(vox=row(9 * 10**17), brave=row(10**18), control=row(11 * 10**17))
                 for _ in range(7)]
        result = evaluate_cohort(pairs, True)
        self.assertTrue(result['passed'])
        self.assertTrue(result['matched_control']['passed'])
        self.assertEqual(result['pairs'], 7)
        pairs[0]['vox'] = row(9 * 10**17 + 1)
        self.assertFalse(evaluate_cohort(pairs, True)['passed'])
        plain = [dict(vox=pair['vox'], brave=pair['brave']) for pair in pairs]
        self.assertEqual(evaluate_cohort(plain)['passed'], False)
        for invalid in [pairs[:6], plain, [dict(pair, extra=row(1)) for pair in pairs]]:
            with self.assertRaises(RuntimeError):
                evaluate_cohort(invalid, True)
        for key, value in [('exit', 1), ('pixels_exact', False), ('content_exact', False),
                           ('launch_instruction_interval', dict(lower=0, upper=1))]:
            with self.subTest(key=key):
                broken = [dict(pair) for pair in pairs]
                broken[0]['control'] = dict(row(11 * 10**17), **{key: value})
                with self.assertRaises(RuntimeError):
                    evaluate_cohort(broken, True)

    def test_cohort_rejects_missing_or_failed_capture_ownership_even_with_lower_counts(self):
        def row(count):
            return dict(exit=0, pixels_exact=True, content_exact=True,
                        capture_ownership_audit=dict(passed=True),
                        launch_instruction_interval=dict(lower=count, upper=count))
        for engine in ['vox', 'control']:
            for audit in [None, {}, dict(passed=False)]:
                pairs = [dict(vox=row(100), brave=row(1000), control=row(200)) for _ in range(7)]
                if audit is None:
                    del pairs[0][engine]['capture_ownership_audit']
                else:
                    pairs[0][engine]['capture_ownership_audit'] = audit
                with self.subTest(engine=engine, audit=audit), self.assertRaisesRegex(
                        RuntimeError, 'endpoint-matched live coalition ownership'):
                    evaluate_cohort(pairs, True)

    def test_attribute_and_scope_controls_never_leak_between_trials(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        for attributes, scopes in [(True, False), (False, True), (True, True)]:
            args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                control_disable_attribute_case_buckets=attributes, control_disable_persistent_scope_jumps=scopes)
            expected = dict(environment)
            if attributes:
                expected['VOX_DISABLE_ATTRIBUTE_CASE_BUCKETS'] = '1'
            if scopes:
                expected['VOX_DISABLE_PERSISTENT_SCOPE_JUMPS'] = '1'
            seen = []
            def observe(engine, app, folder, options):
                seen.append((engine, dict(options.vox_environment)))
                return {'exit': 0}
            with self.subTest(attributes=attributes, scopes=scopes):
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                    for engine in ['control', 'vox', 'brave']:
                        run_trial(engine, 'same-app', engine, args)
                self.assertEqual(seen, [('vox', expected), ('vox', environment), ('brave', environment)])
                self.assertIs(args.vox_environment, environment)
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                    with self.assertRaises(RuntimeError):
                        run_trial('control', 'same-app', 'control', args)
                self.assertIs(args.vox_environment, environment)

    def test_geometry_and_allocator_controls_are_isolated_and_restored(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        for geometry, allocator in [(True, False), (False, True), (True, True)]:
            args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                control_disable_client_geometry_index=geometry,
                control_disable_tracked_persistent_shortcut=allocator)
            expected = dict(environment)
            if geometry:
                expected['VOX_DISABLE_VISUAL_CONTEXT_INDEX'] = '1'
            if allocator:
                expected['VOX_DISABLE_TRACKED_PERSISTENT_SHORTCUT'] = '1'
            seen = []
            def observe(engine, app, folder, options):
                seen.append((engine, dict(options.vox_environment)))
                return {'exit': 0}
            with self.subTest(geometry=geometry, allocator=allocator):
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
                    for engine in ['control', 'vox', 'brave']:
                        run_trial(engine, 'same-app', engine, args)
                self.assertEqual(seen, [('vox', expected), ('vox', environment), ('brave', environment)])
                self.assertIs(args.vox_environment, environment)
                with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
                    with self.assertRaises(RuntimeError):
                        run_trial('control', 'same-app', 'control', args)
                self.assertIs(args.vox_environment, environment)

    def test_historical_webp_policy_is_explicit_and_does_not_require_a_control_app(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        self.assertFalse(parse_args(args).retain_incremental_webp_paint_policy)
        self.assertTrue(parse_args(args + ['--retain-incremental-webp-paint-policy']).retain_incremental_webp_paint_policy)

    def test_optimization_controls_require_a_control_app(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json',
                '--capture-reference']
        for flag in ['--control-retain-initial-resource-viewport-after-style', '--control-retain-parent-longhand-hashing', '--control-retain-invalidation-value-copies', '--control-retain-flow-style-identities', '--control-disable-retained-simple-svg', '--control-retain-definite-intrinsic-measurement', '--control-retain-selector-substring-scan', '--control-retain-redundant-sheet-removal', '--control-retain-full-font-input-scan', '--control-disable-early-text-font-requests', '--control-retain-selector-rule-font-sync', '--control-retain-empty-procedural-styles', '--control-copy-stationary-raster-pixels', '--control-disable-inline-measurement-reuse',
                     '--control-disable-grid-width-only', '--control-disable-stationary-raster',
                     '--control-disable-client-geometry-index',
                     '--control-disable-tracked-persistent-shortcut',
                     '--control-disable-attribute-case-buckets', '--control-disable-persistent-scope-jumps',
                     '--control-disable-extended-longhand-reuse', '--control-disable-color-longhand-reuse',
                     '--control-copy-stationary-raster-commands', '--control-disable-retained-flow-items',
                     '--control-disable-face-specific-font-display', '--control-disable-constant-longhand-reuse',
                     '--control-disable-intrinsic-font-reuse', '--control-disable-pending-intrinsic-font-reuse', '--control-disable-live-pending-text-reuse', '--control-disable-live-pending-font-refresh', '--control-disable-positioned-image-ratio-reuse', '--control-disable-conditional-sheet-invalidation', '--control-disable-inactive-conditional-sheet-skip', '--control-disable-classic-import-word-scan', '--control-disable-classic-import-call-scan', '--control-disable-classic-import-named-method-scan', '--control-disable-keyword-free-module-lexer', '--control-retain-empty-pseudo-candidate-lookups', '--control-retain-attribute-bucket-candidates', '--control-retain-text-bidi-scans', '--control-disable-longhand-shape-reuse', '--control-disable-longhand-eligibility-first', '--control-disable-protected-value-index', '--control-disable-shared-element-geometry', '--control-disable-shared-node-properties', '--control-disable-attribute-tag-buckets', '--control-disable-deleted-style-rule-invalidation', '--control-disable-targeted-user-style-changes', '--control-disable-static-user-style-filter', '--control-disable-document-filter-memo', '--control-disable-retained-grid-layout', '--control-disable-intrinsic-seed-visits']:
            with self.subTest(flag=flag):
                with self.assertRaises(SystemExit):
                    parse_args(args + [flag])
                self.assertTrue(getattr(parse_args(args + [flag, '--control-vox-app', 'Vox.app']),
                                        flag[2:].replace('-', '_')))

    def test_stationary_control_flag_never_reaches_candidate_or_brave(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_stationary_raster=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_STATIONARY_RASTER_REUSE='1')),
                                ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)

    def test_initial_resource_viewport_after_style_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_initial_resource_viewport_after_style=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_INITIAL_RESOURCE_VIEWPORT_AFTER_STYLE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_parent_longhand_hashing_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_parent_longhand_hashing=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_PARENT_LONGHAND_HASHING='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_invalidation_value_copies_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_invalidation_value_copies=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_INVALIDATION_VALUE_COPIES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_cascade_value_copies_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_cascade_value_copies=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_CASCADE_VALUE_COPIES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_absolute_length_context_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_absolute_length_context=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_ABSOLUTE_LENGTH_CONTEXT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_empty_deleted_conditional_targets_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_empty_deleted_conditional_targets=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_EMPTY_DELETED_CONDITIONAL_TARGETS='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)


    def test_broad_conditional_rule_deletion_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_broad_conditional_rule_deletion=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_BROAD_CONDITIONAL_RULE_DELETION='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)


    def test_descendant_navigable_scan_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_descendant_navigable_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_DESCENDANT_NAVIGABLE_SCAN='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)


    def test_uncached_item_paint_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_uncached_item_paint=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_UNCACHED_ITEM_PAINT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)


    def test_empty_deleted_conditional_targets_control_requires_a_control_app(self):
        with self.assertRaises(SystemExit):
            parse_args(['--archive', 'fixture', '--output', 'out',
                        '--memory-guard-registry', 'registry', '--control-retain-empty-deleted-conditional-targets'])

    def test_conditional_rule_deletion_control_requires_a_control_app(self):
        with self.assertRaises(SystemExit):
            parse_args(['--archive', 'fixture', '--output', 'out',
                        '--memory-guard-registry', 'registry', '--control-retain-broad-conditional-rule-deletion'])

    def test_descendant_navigable_control_requires_a_control_app(self):
        with self.assertRaises(SystemExit):
            parse_args(['--archive', 'fixture', '--output', 'out',
                        '--memory-guard-registry', 'registry', '--control-retain-descendant-navigable-scan'])

    def test_item_paint_control_requires_a_control_app(self):
        with self.assertRaises(SystemExit):
            parse_args(['--archive', 'fixture', '--output', 'out',
                        '--memory-guard-registry', 'registry', '--control-retain-uncached-item-paint'])

    def test_inline_measurement_indefinite_height_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_inline_measurement_indefinite_height=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_INLINE_MEASUREMENT_INDEFINITE_HEIGHT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)


    def test_image_attribute_source_parse_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_image_attribute_source_parse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_IMAGE_ATTRIBUTE_SOURCE_PARSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_flow_style_identities_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_flow_style_identities=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_FLOW_STYLE_IDENTITIES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_ancestor_rehash_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_ancestor_rehash=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_ANCESTOR_REHASH='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_formatting_tree_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_formatting_trees=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_FORMATTING_TREES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_property_edge_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_property_edge_resolution=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_PROPERTY_EDGE_RESOLUTION='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_definite_intrinsic_measurement_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_definite_intrinsic_measurement=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_DEFINITE_INTRINSIC_MEASUREMENT='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_simple_svg_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_retained_simple_svg=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_RETAINED_SIMPLE_SVG='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_selector_substring_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_selector_substring_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_SELECTOR_SUBSTRING_SCAN='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_redundant_sheet_removal_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_redundant_sheet_removal=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_REDUNDANT_SHEET_REMOVAL='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_full_font_input_scan_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_full_font_input_scan=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_FULL_FONT_INPUT_SCAN='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_early_text_font_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_early_text_font_requests=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_EARLY_TEXT_FONT_REQUESTS='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_selector_rule_font_sync_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_selector_rule_font_sync=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_SELECTOR_RULE_FONT_SYNC='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_empty_procedural_style_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_retain_empty_procedural_styles=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_RETAIN_EMPTY_PROCEDURAL_STYLES='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_stationary_snapshot_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_copy_stationary_raster_pixels=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_COPY_STATIONARY_RASTER_PIXELS='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_inline_measurement_control_is_isolated_and_restored_after_failure(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=False,
                               control_disable_inline_measurement_reuse=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            for engine in ['control', 'vox', 'brave']:
                run_trial(engine, 'same-app', engine, args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_INLINE_MEASUREMENT_REUSE='1')),
                               ('vox', environment), ('brave', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_same_binary_control_disables_only_its_grid_width_optimization(self):
        environment = {'VOX_PROXY': 'socks5h://fixture'}
        args = SimpleNamespace(vox_environment=environment, control_disable_grid_width_only=True)
        seen = []
        def observe(engine, app, folder, options):
            seen.append((engine, dict(options.vox_environment)))
            return {'exit': 0}
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=observe):
            run_trial('control', 'same-app', 'control', args)
            run_trial('vox', 'same-app', 'candidate', args)
        self.assertEqual(seen, [('vox', dict(environment, VOX_DISABLE_GRID_WIDTH_ONLY='1')),
                                ('vox', environment)])
        self.assertIs(args.vox_environment, environment)
        with patch('bbc_browser_instructions.browser.run_browser', side_effect=RuntimeError('failed')):
            with self.assertRaises(RuntimeError):
                run_trial('control', 'same-app', 'control', args)
        self.assertIs(args.vox_environment, environment)

    def test_matched_controls_alternate_with_candidate_and_brave(self):
        self.assertEqual(trial_order(0), ['vox', 'brave'])
        self.assertEqual(trial_order(1), ['brave', 'vox'])
        self.assertEqual(trial_order(0, True), ['control', 'vox', 'brave'])
        self.assertEqual(trial_order(1, True), ['brave', 'vox', 'control'])
        self.assertEqual(trial_order(2, True), ['control', 'vox', 'brave'])

    def test_full_source_content_and_visible_images_are_required(self):
        audit, expected = document()
        result = validate_document(audit, expected)
        self.assertTrue(result['passed'])
        self.assertEqual(result['headlines'], 2)
        self.assertEqual(result['visible_decoded_images'], 1)

    def test_wrong_document_or_unsettled_state_is_rejected(self):
        for key, value in [('url', URL + 'news'), ('title', 'BBC unavailable'),
                           ('ready', 'interactive'), ('viewport_height', 767),
                           ('fonts_status', 'loading')]:
            audit, expected = document()
            audit[key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_truncated_missing_and_reordered_headlines_are_rejected(self):
        for mutation in ('truncate', 'reorder', 'replace', 'count', 'missing'):
            audit, expected = document()
            row = audit['selections'][1]
            if mutation == 'truncate':
                row['elements'].pop()
            elif mutation == 'reorder':
                row['elements'].reverse()
            elif mutation == 'replace':
                row['elements'][0]['text'] = 'Different news'
            elif mutation == 'count':
                row['count'] += 1
            else:
                audit['selections'].pop(1)
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_missing_images_or_visible_decode_failures_reject_credit(self):
        for mutation in ('missing', 'incomplete', 'zero', 'hidden'):
            audit, expected = document()
            row = audit['selections'][2]
            if mutation == 'missing':
                row['elements'].clear()
            elif mutation == 'incomplete':
                row['elements'][0]['image']['complete'] = False
            elif mutation == 'zero':
                row['elements'][0]['image']['natural_width'] = 0
            else:
                row['elements'][0]['rect']['y'] = 800
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_retained_native_decode_and_offscreen_lazy_images(self):
        audit, expected = document()
        audit['selections'][2]['elements'][0]['image'] = dict(paint_decoded=True, paint_width=480)
        validate_document(audit, expected)
        expected['image_sources'].append('https://images.test/second.jpg')
        expected['image_sources'].sort()
        row = audit['selections'][2]
        row['count'] += 1
        row['elements'].append(dict(rect=dict(x=0, y=900, width=480, height=240), image={},
                                   attributes=dict(src='https://images.test/second.jpg')))
        validate_document(audit, expected)

    def test_hydration_can_remove_only_source_loading_placeholders(self):
        audit, expected = document()
        expected['placeholder_sources'] = ['https://assets.test/grey-placeholder.png']
        validate_document(audit, expected)
        images = audit['selections'][2]
        images['count'] += 1
        images['elements'].append(dict(rect=dict(x=0, y=900, width=200, height=100), image={},
            attributes=dict(src=expected['placeholder_sources'][0])))
        validate_document(audit, expected)
        images['elements'][-1]['attributes']['src'] = 'https://images.test/unexpected.jpg'
        with self.assertRaises(RuntimeError):
            validate_document(audit, expected)

    def test_requested_font_errors_and_missing_parsed_font_reject_credit(self):
        for face in [dict(status='error'), dict(status='loading'),
                     dict(status='loaded', parsed_font_present=False)]:
            audit, expected = document()
            audit['font_faces'] = [face]
            with self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_only_proven_local_font_absence_may_use_platform_fallback(self):
        audit, expected = document()
        expected['local_font_fallback_sources'] = {'bbc-fallback': ['Arial', 'Arial Bold']}
        face = dict(family='BBC-Fallback', status='error', declared_sources=['Arial'])
        audit['font_faces'] = [face]
        result = validate_document(audit, expected)
        self.assertEqual(result['unavailable_local_fallbacks'], [dict(family='BBC-Fallback', sources=['Arial'])])
        for sources in [[], ['Arial', 'https://fonts.test/missing.woff2'], ['Unknown font']]:
            face['declared_sources'] = sources
            with self.subTest(sources=sources), self.assertRaises(RuntimeError):
                validate_document(audit, expected)

    def test_acceptance_requires_seven_pairs_and_existing_references(self):
        args = ['--archive', 'archive', '--output', 'output', '--memory-guard-registry', 'pids.json']
        for extra in [[], ['--expected-vox', 'v.png', '--expected-brave', 'b.png', '--repeat', '6']]:
            with self.assertRaises(SystemExit):
                parse_args(args + extra)
        parsed = parse_args(args + ['--expected-vox', 'v.png', '--expected-brave', 'b.png'])
        self.assertEqual(parsed.repeat, 7)
        self.assertEqual(parsed.scale, 2)
        self.assertFalse(parsed.capture_reference)
        self.assertTrue(parse_args(args + ['--capture-reference']).capture_reference)
        self.assertEqual(parse_args(args + ['--capture-reference', '--reference-engine', 'brave'])
                         .reference_engine, 'brave')
        with self.assertRaises(SystemExit):
            parse_args(args + ['--expected-vox', 'v.png', '--expected-brave', 'b.png',
                               '--reference-engine', 'brave'])

    def test_reference_capture_cannot_pass_acceptance(self):
        pairs = [dict(vox=dict(exit=0, content_exact=True, reference_capture=True),
                      brave=dict(exit=0, content_exact=True, reference_capture=True))] * 7
        with self.assertRaises(RuntimeError):
            evaluate_pairs(pairs, .9, 'launch')


if __name__ == '__main__':
    unittest.main()
