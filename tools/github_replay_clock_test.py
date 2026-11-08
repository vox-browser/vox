import subprocess
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from github_replay_clock import RUNTIME, date_prefix, prepare_archive


class ReplayClockTests(unittest.TestCase):
    def test_date_constructor_statics_elapsed_time_and_subclasses(self):
        epoch = 1794133741593
        script = '''
import assert from 'node:assert/strict';
const NativeDate=Date;
let tick=12.5;
globalThis.performance={now:()=>tick};
const attributes={};
globalThis.document={documentElement:{setAttribute:(k,v)=>attributes[k]=v}};
'''+date_prefix(epoch)+'''
assert.equal(Date.now(),EPOCH);
assert.equal(new Date().getTime(),EPOCH);
assert.equal(Date(),new NativeDate(EPOCH).toString());
assert.equal(new Date(123).getTime(),123);
assert.equal(new Date('2020-01-02T00:00:00Z').getTime(),NativeDate.parse('2020-01-02T00:00:00Z'));
assert.equal(Date.parse('2020-01-02'),NativeDate.parse('2020-01-02'));
assert.equal(Date.UTC(2020,0,2),NativeDate.UTC(2020,0,2));
assert.equal(new Date().constructor,Date);
assert.ok(new Date() instanceof NativeDate);
class ChildDate extends Date {}
assert.ok(new ChildDate() instanceof ChildDate);
assert.equal(new ChildDate().getTime(),EPOCH);
tick+=1234.7;
assert.equal(Date.now(),EPOCH+1234);
assert.equal(new Date().getTime(),EPOCH+1234);
assert.equal(performance.now(),1247.2);
assert.equal(attributes['data-vox-benchmark-clock'],String(EPOCH));
'''.replace('EPOCH', str(epoch))+date_prefix(epoch)+'''
assert.equal(Date.now(),EPOCH+1234);
'''.replace('EPOCH', str(epoch))
        subprocess.run(['node', '--input-type=module', '-e', script], check=True)

    def test_invalid_epoch_is_rejected_before_generating_script(self):
        for epoch in [0, -1, 1.5, '123', 8_640_000_000_000_001]:
            with self.assertRaises(ValueError):
                date_prefix(epoch)

    def test_replay_retains_original_bytes_and_changes_only_runtime_aliases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = root / 'source', root / 'target'
            (source / 'bodies').mkdir(parents=True)
            runtime = b'export const originalModule = 42;\n'
            runtime_hash = hashlib.sha256(runtime).hexdigest()
            responses = {}
            for url, body in [(RUNTIME, runtime), (RUNTIME + '?vox_css_original=1', runtime),
                              ('https://github.com/vlang/v', b'<html>original page</html>')]:
                digest = hashlib.sha256(body).hexdigest()
                (source / 'bodies' / digest).write_bytes(body)
                responses[url] = dict(status=200, sha256=digest, bytes=len(body),
                                      headers=[dict(name='date', value='original date')])
            manifest = dict(version=1, sealed_unix=1, responses=responses)
            raw = json.dumps(manifest)
            (source / 'manifest.json').write_text(raw)
            with patch('github_replay_clock.RUNTIME_SHA256', runtime_hash):
                clock = prepare_archive(source, target, 123456789)
            result = json.loads((target / 'manifest.json').read_text())
            self.assertEqual((source / 'manifest.json').read_text(), raw)
            self.assertEqual((source / 'bodies' / runtime_hash).read_bytes(), runtime)
            for url in [RUNTIME, RUNTIME + '?vox_css_original=1']:
                entry = result['responses'][url]
                self.assertEqual(entry['sha256'], clock['prefixed_sha256'])
                self.assertEqual((target / 'bodies' / entry['sha256']).read_bytes(),
                                 date_prefix(123456789).encode() + runtime)
                self.assertEqual(entry['headers'], responses[url]['headers'])
            self.assertEqual(result['responses']['https://github.com/vlang/v'],
                             responses['https://github.com/vlang/v'])
            with self.assertRaisesRegex(ValueError, 'Unreviewed'):
                prepare_archive(source, root / 'rejected', 123456789)
            self.assertFalse((root / 'rejected').exists())


if __name__ == '__main__':
    unittest.main()
