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
        self.root = Path(scratch.name)
        self.options = SimpleNamespace(output=self.root / 'results', cache_work=self.root / 'cache',
                                       diff_tool=self.root / 'pixel_diff')

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

        def pack(seed, trace, output):
            self.assertTrue(seed.exists() and trace.exists())
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


if __name__ == '__main__':
    unittest.main()
