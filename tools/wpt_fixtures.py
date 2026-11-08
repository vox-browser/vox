"""Materialize and verify imported WPT fixtures at an immutable Git revision.

Only test inputs and expectations are exported. The upstream working checkout
and Vox source tree are never changed.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile


PREFIXES = ('Tests/LibWeb/Text/input/wpt-import',
            'Tests/LibWeb/Text/expected/wpt-import')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_fixture_tree(root, manifest):
    expected = manifest['files']
    actual = {str(path.relative_to(root)) for prefix in PREFIXES
              for path in (root / prefix).rglob('*') if path.is_file() or path.is_symlink()}
    if actual != set(expected):
        raise ValueError('WPT fixture file list changed')
    for relative, digest in expected.items():
        path = root / relative
        if path.is_symlink() or sha256(path) != digest:
            raise ValueError(f'WPT fixture changed: {relative}')


def export_fixtures(repository, revision, cache):
    commit = subprocess.check_output(
        ['git', '-C', str(repository), 'rev-parse', '--verify', revision + '^{commit}'],
        text=True).strip()
    root = cache / ('ladybird-imported-' + commit)
    if root.exists():
        manifest = json.loads((root / 'source.json').read_text())
        if manifest.get('revision') != commit or manifest.get('prefixes') != list(PREFIXES):
            raise ValueError('WPT fixture cache identity mismatch')
        verify_fixture_tree(root, manifest)
        return root, manifest
    cache.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='wpt-export-', dir=cache) as temporary:
        staging = Path(temporary) / 'fixtures'
        staging.mkdir()
        process = subprocess.Popen(['git', '-C', str(repository), 'archive', commit, '--', *PREFIXES],
                                   stdout=subprocess.PIPE)
        try:
            with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
                for member in archive:
                    relative = PurePosixPath(member.name)
                    if relative.is_absolute() or '..' in relative.parts:
                        raise ValueError('Unsafe WPT archive path')
                    destination = staging.joinpath(*relative.parts)
                    if member.isdir():
                        destination.mkdir(parents=True, exist_ok=True)
                    elif member.isfile():
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        destination.write_bytes(archive.extractfile(member).read())
                    else:
                        raise ValueError(f'Unsupported WPT archive member: {member.name}')
            if process.wait():
                raise ValueError('git archive failed')
        finally:
            process.stdout.close()
            if process.poll() is None:
                process.kill()
                process.wait()
        if any(not (staging / prefix).is_dir() for prefix in PREFIXES):
            raise ValueError('Imported WPT trees are missing from this revision')
        files = {str(path.relative_to(staging)): sha256(path)
                 for prefix in PREFIXES for path in sorted((staging / prefix).rglob('*'))
                 if path.is_file()}
        manifest = dict(revision=commit, repository=str(repository.resolve()),
                        prefixes=list(PREFIXES), files=files)
        (staging / 'source.json').write_text(json.dumps(manifest, indent=1) + '\n')
        staging.rename(root)
    return root, manifest
