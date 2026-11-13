import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from build_harfbuzz import VERSION, cached, check_executable, digest, extract_sources


class HarfBuzzSourceTests(unittest.TestCase):
    def test_dependency_check_rejects_graphite_libraries_and_native_vm_symbols(self):
        for libraries, symbols, rejected in [
            ('/usr/lib/libSystem.B.dylib', ' U _malloc', False),
            ('/opt/homebrew/lib/libgraphite2.3.dylib', '', True),
            ('/usr/lib/libSystem.B.dylib', ' U _gr_make_seg', True),
        ]:
            with self.subTest(libraries=libraries, symbols=symbols), \
                    patch('build_harfbuzz.subprocess.check_output', side_effect=[libraries, symbols]):
                if rejected:
                    with self.assertRaisesRegex(RuntimeError, 'still depends on Graphite2'):
                        check_executable(Path('/browser'))
                else:
                    check_executable(Path('/browser'))

    def test_cache_rejects_changed_or_missing_link_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            library = root / 'lib/libharfbuzz.a'
            header = root / 'include/harfbuzz/hb.h'
            for path in [library, header]:
                path.parent.mkdir(parents=True)
                path.write_bytes(b'original')
            identity = {'version': VERSION}
            (root / 'build.json').write_text(json.dumps(dict(inputs=identity,
                outputs={str(p.relative_to(root)): digest(p) for p in [library, header]})))
            self.assertTrue(cached(root, identity))
            self.assertFalse(cached(root, {'version': 'other'}))
            library.write_bytes(b'changed')
            self.assertFalse(cached(root, identity))
            library.write_bytes(b'original')
            header.unlink()
            self.assertFalse(cached(root, identity))

    def test_source_extraction_rejects_escaping_paths_and_links(self):
        for name, kind in [(f'harfbuzz-{VERSION}/../escape', tarfile.REGTYPE),
                           ('/escape', tarfile.REGTYPE),
                           (f'harfbuzz-{VERSION}/src/escape', tarfile.SYMTYPE)]:
            with self.subTest(name=name, kind=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                archive = root / 'source.tar'
                with tarfile.open(archive, 'w') as bundle:
                    entry = tarfile.TarInfo(name)
                    entry.type = kind
                    entry.linkname = '/escape'
                    bundle.addfile(entry, io.BytesIO())
                with self.assertRaises(RuntimeError):
                    extract_sources(archive, root / 'source')


if __name__ == '__main__':
    unittest.main()
