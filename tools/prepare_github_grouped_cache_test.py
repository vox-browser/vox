from contextlib import nullcontext, redirect_stderr
from io import StringIO
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import prepare_github_grouped_cache as workflow


class GroupedCacheWorkflowTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name).resolve()
        self.options = SimpleNamespace(output=self.root / 'results', cache_work=self.root / 'cache',
                                       diff_tool=self.root / 'pixel_diff', pack_jobs=2,
                                       object_checkpoint=self.root / 'pack-objects')

    def test_reopen_requires_the_packed_library(self):
        with patch.object(workflow.benchmark, 'compare') as compare:
            with self.assertRaisesRegex(ValueError, 'did not load'):
                workflow.verify_reopen({}, {'native_library_trace': {'libraries': ['other.dylib']}},
                                       {'library': 'grouped.dylib'}, self.root, self.options.diff_tool)
        compare.assert_not_called()

    def test_reopen_requires_matching_pixels(self):
        separate = {'folder': str(self.root / 'trace')}
        grouped = {'folder': str(self.root / 'reopen'), 'native_library_trace': {'libraries': ['grouped.dylib']}}
        with patch.object(workflow.benchmark, 'compare', return_value={'exact': False}) as compare:
            with self.assertRaisesRegex(ValueError, 'differs from the separate-cache image'):
                workflow.verify_reopen(separate, grouped, {'library': 'grouped.dylib'},
                                       self.root, self.options.diff_tool)
        compare.assert_called_once_with(self.root / 'trace/document.png', self.root / 'reopen/document.png',
                                        self.root / 'grouped-diff.png', self.options.diff_tool)

    def test_publication_change_stops_before_grouped_launch(self):
        binary = self.root / 'Vox'
        binary.write_bytes(b'first release')
        sha = workflow.benchmark.digest(binary)
        production = self.root / 'publication.json'
        receipt = {'exit': 0, 'executable_sha256': sha}
        workflow.benchmark.save(production, receipt)
        visits = []

        def browser(options, **_):
            visits.append(options.output.name)
            options.output.mkdir()
            workflow.benchmark.save(options.output / 'results.json', dict(
                complete=True, production_receipt=receipt, inputs={str(binary): sha}, attempts=[{'valid': True}]))
            return 0

        def pack(seed, trace, output, *, jobs, object_checkpoint):
            self.assertTrue(seed.exists() and trace.exists())
            self.assertEqual(jobs, self.options.pack_jobs)
            self.assertEqual(object_checkpoint, self.options.object_checkpoint)
            image = output / 'abi' / 'group.dylib'
            image.parent.mkdir(parents=True)
            image.write_bytes(b'grouped image')
            binary.write_bytes(b'other release')
            return dict(abi='abi', library=image.name, group_sha256=workflow.benchmark.digest(image))

        with (
            patch.multiple(workflow, BINARY=binary, PRODUCTION=production),
            patch.object(workflow, 'canonical_bundle_lease', return_value=nullcontext()),
            patch.object(workflow.benchmark, 'run', side_effect=browser),
            patch.object(workflow, 'pack_from_benchmark', side_effect=pack),
            redirect_stderr(StringIO()),
        ):
            self.assertEqual(workflow.run(self.options), 1)
        self.assertEqual(visits, ['seed', 'trace'])
        outcome = json.loads((self.options.output / 'results.json').read_text())
        self.assertFalse(outcome['complete'])
        self.assertEqual(outcome['failure']['stage'], 'reopen')
        self.assertIn('Pinned workflow inputs changed', outcome['failure']['error'])
        self.assertTrue((self.options.output / 'pack.json').exists())

    def test_interrupted_seed_accepts_only_matching_libjs_source_inputs(self):
        cache = self.options.cache_work.resolve()
        captures = cache / 'captures'
        abi = 'a' * 64
        (cache / 'separate' / abi).mkdir(parents=True)
        old = self.root / 'old'
        stage = old / 'seed'
        (stage / '0-libjs-native').mkdir(parents=True)
        archive = self.root / 'archive'
        archive.mkdir()
        audit, png = self.root / 'audit.json', self.root / 'reference.png'
        for path in (archive / 'manifest.json', audit, png):
            path.write_bytes(b'fixture')
        binary = self.root / 'Vox'
        binary.write_bytes(b'new executable')
        source = str(workflow.benchmark.ROOT / 'libjs/native_code_cache.v')
        compilations = []
        for name in ('first', 'second'):
            directory = self.root / name
            directory.mkdir()
            workflow.benchmark.save(directory / 'source-manifest.json', {source: 'libjs pin'})
            compilations.append(str(directory / 'frozen-compile.json'))
        earlier, current = (dict(executable_sha256=name, c_compile={'v_prod': True}, frozen_compilation=manifest)
                            for name, manifest in zip(('first', 'second'), compilations))
        checkpoint = old / 'results.json'
        workflow.benchmark.save(checkpoint, dict(complete=False, stages={'seed': 'receipt'},
                                                  production=earlier, cache_work=str(cache)))
        pins = {str(path): workflow.benchmark.digest(path) for path in (archive / 'manifest.json', audit, png)}
        pins.update({str(binary): 'previous executable pin',
                     str(Path(workflow.benchmark.__file__).resolve()): 'previous driver pin'})
        workflow.benchmark.save(stage / 'results.json', dict(prepare_native_cache=True,
                                native_captures=str(captures), inputs=pins))
        workflow.benchmark.save(stage / '0-libjs-native/launch.json',
                                {'browser_overrides': {'VOX_LIBJS_NATIVE_CACHE': str(cache / 'separate')}})
        args = SimpleNamespace(archive=archive, reference_audit=audit, reference_png=png,
                               adblock_assets=None, raster_parity_options=False)
        saved = dict(abi=abi, records=128, batches={'first.dylib': {}})
        with (
            patch.object(workflow, 'BINARY', binary),
            patch.object(workflow.benchmark, 'verify_compiler_captures', return_value=saved),
        ):
            resumed = workflow.verify_interrupted_seed(args, checkpoint, cache, current)
            self.assertEqual((resumed['previous_executable_sha256'], resumed['records'], resumed['batches']),
                             ('first', 128, 1))
            workflow.benchmark.save(Path(compilations[1]).with_name('source-manifest.json'), {source: 'changed'})
            with self.assertRaisesRegex(ValueError, 'different LibJS or compiler inputs'):
                workflow.verify_interrupted_seed(args, checkpoint, cache, current)

    def test_packed_checkpoint_checks_cache_files_and_group_digest(self):
        cache = self.options.cache_work.resolve()
        abi = 'a' * 64
        separate, grouped = (cache / name for name in ('separate', 'grouped'))
        records = separate / abi
        records.mkdir(parents=True)
        record = records / ('b' * 64 + '.json')
        record.write_bytes(b'cache record')
        image = grouped / abi / 'group.dylib'
        image.parent.mkdir(parents=True)
        image.write_bytes(b'packed image')
        archive = self.root / 'archive'
        archive.mkdir()
        audit, png = self.root / 'audit.json', self.root / 'reference.png'
        inputs = (archive / 'manifest.json', audit, png)
        for path in inputs:
            path.write_bytes(b'fixture')
        old = self.root / 'old'
        trace = old / 'trace/results.json'
        trace.parent.mkdir(parents=True)
        workflow.benchmark.save(trace, dict(complete=True, inputs={
            str(path.resolve()): workflow.benchmark.digest(path) for path in (*inputs, record)
        }, attempts=[dict(valid=True, browser_overrides={'VOX_LIBJS_NATIVE_CACHE': str(separate)})]))
        packed = dict(abi=abi, library=image.name, group_sha256=workflow.benchmark.digest(image),
                      benchmark={'trace': dict(path='/old/location/trace/results.json',
                                               sha256=workflow.benchmark.digest(trace))})
        workflow.benchmark.save(old / 'pack.json', packed)
        checkpoint, publication = old / 'results.json', {'executable_sha256': 'published'}
        workflow.benchmark.save(checkpoint, dict(cache_work=str(cache), grouped_cache=str(grouped),
                                                  stages={'pack': 'receipt'}, production=publication))
        args = SimpleNamespace(archive=archive, reference_audit=audit, reference_png=png,
                               adblock_assets=None, raster_parity_options=False)
        self.assertEqual(workflow.verify_packed_checkpoint(args, checkpoint, cache, publication), packed)
        image.write_bytes(b'changed packed image')
        with self.assertRaisesRegex(ValueError, 'Pinned workflow inputs changed'):
            workflow.verify_packed_checkpoint(args, checkpoint, cache, publication)
        (records / ('c' * 64 + '.json')).touch()
        with self.assertRaisesRegex(ValueError, 'file set changed'):
            workflow.verify_packed_checkpoint(args, checkpoint, cache, publication)

    def test_resumes_pack_and_reopens_both_layouts_after_publication_changes(self):
        args = self.options
        cache = args.cache_work.resolve()
        separate, grouped, captures = (cache / name for name in ('separate', 'grouped', 'captures'))
        separate.mkdir(parents=True)
        record = separate / 'record.json'
        record.write_bytes(b'cache record')
        args.archive = self.root / 'archive'
        args.archive.mkdir()
        args.reference_audit = self.root / 'audit.json'
        args.reference_png = self.root / 'reference.png'
        args.adblock_assets = None
        args.raster_parity_options = False
        for path in (args.archive / 'manifest.json', args.reference_audit, args.reference_png):
            path.write_bytes(b'fixture')
        pins = {str(p.resolve()): workflow.benchmark.digest(p) for p in (
            args.archive / 'manifest.json', args.reference_audit, args.reference_png, record)}

        binary = self.root / 'Vox'
        latest = self.root / 'latest.json'
        source = str(workflow.benchmark.ROOT / 'libjs/native_code_cache.v')

        def publish(name):
            directory = self.root / name
            directory.mkdir()
            workflow.benchmark.save(directory / 'source-manifest.json', {source: 'same LibJS'})
            binary.write_text(name)
            receipt = dict(exit=0, executable_sha256=workflow.benchmark.digest(binary),
                           c_compile={'v_prod': True}, frozen_compilation=str(directory / 'frozen-compile.json'))
            workflow.benchmark.save(latest, receipt)
            return receipt

        previous = publish('first')
        reports = self.root / 'relocated'
        stages = {name: reports / name / 'results.json' for name in ('seed', 'trace')}
        for path in stages.values():
            path.parent.mkdir(parents=True)
        loader = reports / 'trace/0-libjs-native/native-library-trace.log'
        loader.parent.mkdir()
        loader.write_bytes(b'loader trace')
        workflow.benchmark.save(stages['seed'], dict(complete=True, prepare_native_cache=True,
            production_receipt=previous, attempts=[dict(compiler_captures={'directory': str(captures)})]))
        workflow.benchmark.save(stages['trace'], dict(complete=True, trace_native_libraries=True,
            production_receipt=previous, inputs=pins,
            attempts=[dict(valid=True, folder='/old/trace/0-libjs-native',
                           browser_overrides={'VOX_LIBJS_NATIVE_CACHE': str(separate)})]))
        args.resume_pack = reports / 'results.json'
        object_checkpoint = args.object_checkpoint
        workflow.benchmark.save(args.resume_pack, dict(complete=False, cache_work=str(cache),
            grouped_cache=str(grouped), object_checkpoint=str(object_checkpoint),
            stages={name: f'/old/{name}/results.json' for name in stages}, production=previous))
        args.object_checkpoint = None
        visits = []

        def pack(seed, trace, output, *, jobs, object_checkpoint):
            self.assertEqual(output, grouped)
            self.assertEqual(seed.read_bytes(), stages['seed'].read_bytes())
            self.assertEqual(trace.read_bytes(), stages['trace'].read_bytes())
            self.assertEqual((trace.parent / '0-libjs-native/native-library-trace.log').read_bytes(), loader.read_bytes())
            self.assertEqual(object_checkpoint, self.root / 'pack-objects')
            image = output / 'abi' / 'group.dylib'
            image.parent.mkdir(parents=True)
            image.write_bytes(b'grouped image')
            publish('second')
            return dict(abi='abi', library=image.name, group_sha256=workflow.benchmark.digest(image))

        def visit(options, **_):
            self.assertFalse(options.prepare_native_cache)
            self.assertTrue(options.trace_native_libraries)
            visits.append((options.output.name, options.native_cache))
            options.output.mkdir()
            workflow.benchmark.save(options.output / 'results.json', dict(complete=True,
                production_receipt=json.loads(latest.read_bytes()), inputs=pins,
                attempts=[dict(valid=True, folder=str(options.output),
                               native_library_trace={'libraries': ['group.dylib']})]))
            return 0

        with (
            patch.multiple(workflow, BINARY=binary, PRODUCTION=latest),
            patch.object(workflow, 'canonical_bundle_lease', return_value=nullcontext()),
            patch.object(workflow.benchmark, 'run', side_effect=visit),
            patch.object(workflow, 'pack_from_benchmark', side_effect=pack),
            patch.object(workflow.benchmark, 'compare', return_value={'exact': True}),
        ):
            self.assertEqual(workflow.run(args), 0)
        outcome = json.loads((args.output / 'results.json').read_text())
        self.assertEqual(visits, [('verify-trace', separate), ('reopen', grouped)])
        self.assertTrue(outcome['complete'])
        self.assertEqual(outcome['resume_pack']['production'], previous)
        self.assertNotEqual(outcome['production']['executable_sha256'], previous['executable_sha256'])
        self.assertEqual(outcome['stages']['trace'], str(args.output / 'trace/results.json'))


if __name__ == '__main__':
    unittest.main()
