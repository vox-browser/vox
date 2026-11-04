"""Reviewed, opt-in frozen-page experiment; never a live-site blocking rule.

Only the pinned anonymous homepage's performance bootstrap is changed. Its
original imports and non-home/authenticated paths remain intact. This changes
author-script policy, so comparisons must replay the result in both browsers.
"""
import copy
import hashlib
import json
from pathlib import Path

from page_archive import checked_response_body, load_archive

POLICY = 'chatgpt-home-performance'
URL = 'https://chatgpt.com/'
SCRIPT_URL = URL + 'unauth-mweb/assets/native-performance-bootstrap-DuPGOfFF.js'
SCRIPT_SHA256 = '3dfdbde9c2682dda83be18e3db1b5c8b140ed66d6f3e1a4c76ad20b3d49136cf'
DOCUMENT_SHA256 = '20960cf144422190847df92297356039f0faa822135f12f2b868fb38ad11dd38'
MANIFEST_SHA256 = '5c59adf716301d5a32484f67343db29ba026fa3f8527daa1c8c14c6ae78d9a59'
MARKER = 'data-vox-performance-collector-suppressed'
START = 'var n=({analyticsAnonymousId:n,canStart:s,initialResourceRequestCutoffMs:i,page:m,setPerformanceCollectionAbandoner:l})=>'
END = ';export{n as startOctanePerformanceMetrics};'


def insert_guard(source, diagnostic=False):
    """Keep the original fallback verbatim; exported promise/cleanup contract survives."""
    if source.count(START) != 1 or source.count(END) != 1 or not source.endswith(END):
        raise ValueError('Unreviewed performance bootstrap structure')
    if START + 'Promise.all(' not in source:
        raise ValueError('Unreviewed performance bootstrap entry')
    # The performance-only path installs a reporter which consumes the pending
    # measurement queue, disconnects its initial long-task observer, and supplies
    # an abandoner so native-telemetry can remove its startup listeners. Returning
    # false would make its importer retry. Service-worker cleanup, app readiness,
    # page-view state, consent and sign-in handlers live in unchanged modules.
    marker = f'document.documentElement.setAttribute("{MARKER}","1");' if diagnostic else ''
    guard = ('{if(m.kind==="home"&&!m.auth?.isAuthenticated){'
             'return Promise.resolve().then(()=>{if(!s())return false;'
             'a();o(()=>{});l(()=>{});' + marker + 'return true;});}return ')
    return source.replace(START, START + guard, 1)[:-len(END)] + '}' + END


def prepare_archive(archive, output, diagnostic=False):
    """Create independent fixture bytes; never edit or hardlink the sealed input."""
    archive, output = Path(archive).resolve(), Path(output).absolute()
    manifest_bytes = (archive / 'manifest.json').read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != MANIFEST_SHA256:
        raise ValueError('Performance policy requires the reviewed sealed manifest')
    manifest = load_archive(archive)
    if manifest['url'] != URL or manifest['responses'][URL]['sha256'] != DOCUMENT_SHA256:
        raise ValueError('Performance policy requires the reviewed homepage')
    entry = manifest['responses'].get(SCRIPT_URL, {})
    if entry.get('sha256') != SCRIPT_SHA256 or entry.get('status') != 200 or entry.get('method', 'GET') != 'GET':
        raise ValueError('Performance policy requires the reviewed script response')
    original = checked_response_body(archive, SCRIPT_URL, entry)
    replacement = insert_guard(original.decode('utf-8'), diagnostic).encode('utf-8')
    replacement_sha = hashlib.sha256(replacement).hexdigest()
    # Read/verify every input again as it is copied. Retain the originals for
    # provenance but select only the replacement hash in the derived manifest.
    output.mkdir(parents=True, exist_ok=False)
    (output / 'bodies').mkdir()
    for address, response in manifest['responses'].items():
        body = checked_response_body(archive, address, response)
        destination = output / 'bodies' / response['sha256']
        if not destination.exists():
            destination.write_bytes(body)
    if (archive / 'manifest.json').read_bytes() != manifest_bytes:
        raise ValueError('Reviewed manifest changed while preparing policy')
    (output / 'bodies' / replacement_sha).write_bytes(replacement)
    derived = copy.deepcopy(manifest)
    derived['responses'][SCRIPT_URL].update(sha256=replacement_sha, bytes=len(replacement))
    # A derived representation must not advertise the original entity tag or
    # integrity digest. The replay server already recalculates Content-Length.
    derived['responses'][SCRIPT_URL]['headers'] = [h for h in entry['headers']
        if h['name'].lower() not in {'etag', 'content-md5', 'digest', 'content-digest'}]
    policy = dict(name=POLICY, experimental=True, diagnostic=diagnostic,
        source_archive=str(archive), source_manifest_sha256=MANIFEST_SHA256,
        document_sha256=DOCUMENT_SHA256, script_url=SCRIPT_URL,
        original_script_sha256=SCRIPT_SHA256, replacement_script_sha256=replacement_sha,
        scope='Performance collection on the anonymous home page only; original fallback retained',
        other_scripts='Unchanged; native telemetry lifecycle and readiness are preserved',
        comparison='Changed author-script policy, identical in both browsers; no engine optimization credit')
    derived.update(author_scripts='Reviewed performance collector suppression; all other scripts unchanged',
                   script_policy=policy)
    (output / 'manifest.json').write_text(json.dumps(derived, indent=2) + '\n')
    load_archive(output)
    return policy
