"""Preserve sealed replay bytes and fixed references before browser launches."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile

from page_archive import load_archive


def identity(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            size += len(chunk)
            digest.update(chunk)
    return dict(bytes=size, sha256=digest.hexdigest())


def verify_preserved_inputs(destination, records):
    """Read every payload back; reject duplicate names, links and extra files."""
    seen = set()
    with tarfile.open(destination, 'r|gz') as archive:
        for member in archive:
            if member.name in seen or member.name not in records:
                raise ValueError('Preserved replay file inventory changed')
            seen.add(member.name)
            if not member.isfile():
                raise ValueError('Preserved replay contains a non-regular member')
            if member.size != records[member.name]['bytes']:
                raise ValueError('Preserved replay payload size changed: ' + member.name)
            digest = hashlib.sha256()
            size = 0
            with archive.extractfile(member) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    size += len(chunk)
                    digest.update(chunk)
            if dict(bytes=size, sha256=digest.hexdigest()) != records[member.name]:
                raise ValueError('Preserved replay payload changed: ' + member.name)
    if seen != set(records):
        raise ValueError('Preserved replay file inventory changed')


def verify_preservation_identity(receipt, pinned):
    """Reject source or evidence changes between preservation and cohort pinning."""
    expected = dict(receipt['files'])
    expected[receipt['path']] = dict(bytes=receipt['bytes'], sha256=receipt['sha256'])
    for path, value in expected.items():
        if pinned.get(path) != value:
            raise ValueError('Replay input changed after preservation: ' + path)


def preserve_replay_inputs(source, references, destination):
    """Create a verified tar.gz without overwriting an existing destination.

    Only the replay manifest, its referenced bodies and supplied reference PNGs
    are selected. The original manifest bytes and PNG encodings are retained.
    """
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if destination == source or source in destination.parents:
        raise ValueError('Input archive must be outside the replay directory')
    if set(references) - {'vox', 'brave'}:
        raise ValueError('Reference engines must be vox or brave')
    manifest_path = source / 'manifest.json'
    manifest_identity = identity(manifest_path)
    manifest = load_archive(source)
    if identity(manifest_path) != manifest_identity:
        raise ValueError('Replay manifest changed during preservation')
    sources = {'replay/manifest.json': manifest_path}
    for entry in manifest['responses'].values():
        sources['replay/bodies/' + entry['sha256']] = source / 'bodies' / entry['sha256']
    for engine, path in references.items():
        sources['references/' + engine + '.png'] = Path(path)
    if any(path.is_symlink() for path in sources.values()):
        raise ValueError('Replay preservation requires regular source files')
    sources = {name: path.resolve() for name, path in sources.items()}
    if destination in sources.values():
        raise ValueError('Input archive cannot replace a source file')
    records = {name: identity(path) for name, path in sources.items()}
    if records['replay/manifest.json'] != manifest_identity:
        raise ValueError('Replay manifest changed during preservation')
    for entry in manifest['responses'].values():
        expected = dict(bytes=entry['bytes'], sha256=entry['sha256'])
        if records['replay/bodies/' + entry['sha256']] != expected:
            raise ValueError('Replay body changed during preservation')
    index = (json.dumps(dict(version=1, files=records), indent=2, sort_keys=True) + '\n').encode()
    records['INPUTS.json'] = dict(bytes=len(index), sha256=hashlib.sha256(index).hexdigest())

    def verify_sources():
        for name, path in sources.items():
            if identity(path) != records[name]:
                raise ValueError('Replay input changed during preservation: ' + str(path))

    reused = destination.exists()
    if reused:
        verify_preserved_inputs(destination, records)
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(prefix='.' + destination.name + '.',
                                                    dir=destination.parent)
        temporary = Path(temporary_name)
        try:
            with os.fdopen(descriptor, 'wb') as output:
                with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as compressed:
                    with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
                        for name in sorted(records):
                            member = tarfile.TarInfo(name)
                            member.size = records[name]['bytes']
                            member.mode = 0o600
                            with (io.BytesIO(index) if name == 'INPUTS.json'
                                  else sources[name].open('rb')) as stream:
                                archive.addfile(member, stream)
                output.flush()
                os.fsync(output.fileno())
            verify_preserved_inputs(temporary, records)
            verify_sources()
            # Publishing a complete file must never overwrite another session's
            # destination. A racing writer leaves this attempt unsuccessful.
            os.link(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    verify_sources()
    return dict(path=str(destination), **identity(destination),
                replay_manifest_sha256=manifest_identity['sha256'],
                files={str(path): records[name] for name, path in sources.items()},
                members=len(records), reused=reused, round_trip_verified=True)
