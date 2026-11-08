"""Keep frozen site resources extractable and usable from Windows source ZIPs."""
import hashlib
import html
import json
import os
from pathlib import Path
import re
import unittest
from urllib.parse import quote, unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'pixel_tests'
RESERVED = re.compile(r'^(?:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|$)', re.I)


def reference_pattern(relative):
    # Wget fixtures encode literal ? and % in local URLs. HTML may additionally
    # escape query separators. Keep URL punctuation used in the frozen pages.
    encoded = quote(relative, safe="/!$&'()*+,-.:;=@_~")
    spellings = {relative, encoded, html.escape(relative, quote=False),
                 html.escape(encoded, quote=False)}
    alternatives = '|'.join(re.escape(s) for s in sorted(spellings, key=len, reverse=True))
    return re.compile(r'(?<![\w/:%.-])(?:' + alternatives + r')(?=[\s\"\'<>\)#]|$)')


class SiteFixturePathsTests(unittest.TestCase):
    def test_fixture_paths_are_portable_to_windows(self):
        seen = {}
        for path in sorted((FIXTURES / 'sites').rglob('*')):
            relative = path.relative_to(ROOT).as_posix()
            with self.subTest(path=relative):
                # Leave room for the destination directory and ZIP root prefix.
                self.assertLessEqual(len(relative.encode('utf-16-le')) // 2, 180)
                self.assertIsNone(re.search(r'[<>:"\\|?*\x00-\x1f]', path.name))
                self.assertFalse(path.name.endswith(('.', ' ')))
                self.assertIsNone(RESERVED.match(path.name))
                folded = relative.casefold()
                self.assertNotIn(folded, seen, f'Case collision with {seen.get(folded)}')
                seen[folded] = relative

    def test_relocated_resources_keep_their_original_bytes_and_links(self):
        resources = json.loads((FIXTURES / 'portable_resources.json').read_text())
        self.assertTrue(resources)
        references = 0
        for resource in resources:
            original = FIXTURES / resource['original']
            target = FIXTURES / resource['path']
            with self.subTest(path=resource['path']):
                self.assertFalse(original.exists())
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(),
                                 resource['sha256'])
                site = FIXTURES / Path(resource['path']).parts[0] / Path(resource['path']).parts[1]
                for source in site.rglob('*'):
                    if source.suffix not in {'.html', '.css'}:
                        continue
                    text = source.read_text(encoding='utf-8', errors='replace')
                    old = os.path.relpath(original, source.parent).replace(os.sep, '/')
                    self.assertIsNone(reference_pattern(old).search(text), str(source))
                    new = os.path.relpath(target, source.parent).replace(os.sep, '/')
                    references += len(reference_pattern(new).findall(text))
        self.assertGreater(references, 0)

    def test_shortened_resource_urls_resolve(self):
        # Check URL decoding and relative paths from both HTML and nested CSS.
        pattern = re.compile(r'''[^\s"'<>()[\]{}]*asset-[0-9a-f]{16}\.[a-z0-9]+''')
        references = 0
        for source in (FIXTURES / 'sites').rglob('*'):
            if source.suffix not in {'.html', '.css'}:
                continue
            for match in pattern.finditer(source.read_text(encoding='utf-8', errors='replace')):
                value = urlsplit(html.unescape(match.group()))
                with self.subTest(source=str(source), url=match.group()):
                    self.assertFalse(value.scheme or value.netloc)
                    self.assertTrue((source.parent / unquote(value.path)).is_file())
                references += 1
        self.assertGreater(references, 0)


if __name__ == '__main__':
    unittest.main()
