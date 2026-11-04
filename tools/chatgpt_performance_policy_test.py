import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import chatgpt_performance_policy as policy
from page_archive import load_archive


# Synthetic author code only. Tests never execute code from the saved site.
SOURCE = policy.START + 'Promise.all([Promise.resolve(7)]).then(v=>v[0])' + policy.END


class PerformancePolicyTests(unittest.TestCase):
    def test_only_inserts_guard_and_preserves_original_fallback(self):
        changed = policy.insert_guard(SOURCE)
        self.assertIn('return Promise.all([Promise.resolve(7)]).then(v=>v[0])}', changed)
        self.assertTrue(changed.endswith(policy.END))
        self.assertNotIn(policy.MARKER, changed)
        self.assertIn(policy.MARKER, policy.insert_guard(SOURCE, True))

    def test_rejects_unknown_module_structure(self):
        for source in [SOURCE + '\n', SOURCE.replace('Promise.all', 'Promise.any'),
                       SOURCE.replace('canStart:s', 'canStart:z'), SOURCE + SOURCE]:
            with self.assertRaises(ValueError):
                policy.insert_guard(source)

    def test_promise_readiness_cleanup_and_fallback_contracts(self):
        program = r'''
const vm=require('node:vm'),assert=require('node:assert/strict');
let source='';process.stdin.setEncoding('utf8');process.stdin.on('data',s=>source+=s);
process.stdin.on('end',async()=>{
 const calls=[],sandbox={Promise,a:()=>calls.push('drain'),o:cb=>{calls.push('reporter');cb({});},
 l:null,document:{documentElement:{setAttribute:(k,v)=>calls.push([k,v])}}};
 vm.createContext(sandbox);vm.runInContext(source.replace(/;export\{n as startOctanePerformanceMetrics\};$/,';'),sandbox);
 const run=(page,allowed=true)=>sandbox.n({page,canStart:()=>allowed,
  setPerformanceCollectionAbandoner:cb=>{calls.push('abandoner');cb();}});
 const pending=run({kind:'home',auth:{isAuthenticated:false}});
 assert.equal(typeof pending.then,'function');assert.deepEqual(calls,[]);
 assert.equal(await pending,true);
 assert.deepEqual(calls.slice(0,3),['drain','reporter','abandoner']);
 assert.deepEqual(calls[3],['data-vox-performance-collector-suppressed','1']);
 calls.length=0;assert.equal(await run({kind:'home'},false),false);assert.deepEqual(calls,[]);
 assert.equal(await run({kind:'conversation'}),7);assert.deepEqual(calls,[]);
 assert.equal(await run({kind:'home',auth:{isAuthenticated:true}}),7);assert.deepEqual(calls,[]);
 assert.equal(await run({kind:'privacy'}),7);assert.deepEqual(calls,[]);
});
'''
        result = subprocess.run(['node', '--unhandled-rejections=strict', '-e', program], input=policy.insert_guard(SOURCE, True),
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)

    def fixture(self, root):
        archive = root / 'source'
        (archive / 'bodies').mkdir(parents=True)
        document, source = b'<title>ChatGPT</title>', SOURCE.encode()
        document_sha, script_sha = [hashlib.sha256(b).hexdigest() for b in [document, source]]
        bodies = {policy.URL: document, policy.SCRIPT_URL: source}
        responses = {}
        for url, body in bodies.items():
            sha = hashlib.sha256(body).hexdigest()
            (archive / 'bodies' / sha).write_bytes(body)
            responses[url] = dict(sha256=sha, bytes=len(body), method='GET', status=200,
                headers=[dict(name='Content-Type', value='text/javascript'),
                         dict(name='ETag', value='original'), dict(name='Digest', value='old'),
                         dict(name='Access-Control-Allow-Origin', value='*')])
        manifest = dict(version=1, url=policy.URL, sealed_unix=1,
                        author_scripts='original bytes retained', responses=responses)
        raw = json.dumps(manifest).encode()
        (archive / 'manifest.json').write_bytes(raw)
        patches = mock.patch.multiple(policy, MANIFEST_SHA256=hashlib.sha256(raw).hexdigest(),
            SCRIPT_SHA256=script_sha, DOCUMENT_SHA256=document_sha)
        return archive, patches

    def test_derived_archive_preserves_document_other_bodies_and_input_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, patches = self.fixture(root)
            original = {p.relative_to(archive): p.read_bytes() for p in archive.rglob('*') if p.is_file()}
            with patches:
                report = policy.prepare_archive(archive, root / 'derived')
            derived = load_archive(root / 'derived')
            self.assertEqual(derived['script_policy'], report)
            self.assertNotEqual(report['original_script_sha256'], report['replacement_script_sha256'])
            old = json.loads(original[Path('manifest.json')])
            self.assertEqual(derived['responses'][policy.URL], old['responses'][policy.URL])
            for relative, body in original.items():
                self.assertEqual((archive / relative).read_bytes(), body)
                if relative != Path('manifest.json'):
                    self.assertEqual((root / 'derived' / relative).read_bytes(), body)
                    self.assertNotEqual((archive / relative).stat().st_ino,
                                        (root / 'derived' / relative).stat().st_ino)
            headers = derived['responses'][policy.SCRIPT_URL]['headers']
            self.assertEqual([h['name'] for h in headers], ['Content-Type', 'Access-Control-Allow-Origin'])

    def test_requires_exact_reviewed_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, patches = self.fixture(root)
            with patches:
                with (archive / 'manifest.json').open('ab') as output:
                    output.write(b' ')
                with self.assertRaisesRegex(ValueError, 'reviewed sealed manifest'):
                    policy.prepare_archive(archive, root / 'derived')
            self.assertFalse((root / 'derived').exists())

    def test_changed_body_is_rejected_before_creating_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, patches = self.fixture(root)
            with patches:
                (archive / 'bodies' / policy.SCRIPT_SHA256).write_bytes(b'changed')
                with self.assertRaisesRegex(ValueError, 'Archived response changed'):
                    policy.prepare_archive(archive, root / 'derived')
            self.assertFalse((root / 'derived').exists())

    def test_unknown_script_identity_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, patches = self.fixture(root)
            with patches, mock.patch.object(policy, 'SCRIPT_SHA256', 'f' * 64):
                with self.assertRaisesRegex(ValueError, 'reviewed script response'):
                    policy.prepare_archive(archive, root / 'derived')

    def test_existing_destination_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, patches = self.fixture(root)
            with patches:
                policy.prepare_archive(archive, root / 'derived')
                with self.assertRaises(FileExistsError):
                    policy.prepare_archive(archive, root / 'derived')


if __name__ == '__main__':
    unittest.main()
