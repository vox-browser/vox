#!/usr/bin/env python3
"""Stage the reviewed upstream UI2 and prepare compiler compatibility modules."""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile


UI2_LOCK = Path(__file__).with_name('ui2') / 'dependency.json'


def load_ui2_lock(path=UI2_LOCK):
    """The ordinary build and CI select the same reviewed dependency."""
    try:
        lock = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise RuntimeError(f'Cannot read UI2 dependency lock {path}: {error}') from error
    if (not isinstance(lock, dict) or lock.get('schema_version') != 1
            or lock.get('repository') != 'https://github.com/vlang/ui2.git'
            or type(lock.get('embedding_api')) is not int or lock['embedding_api'] != 1
            or any(not re.fullmatch(r'[0-9a-f]{40}', str(lock.get(key, '')))
                   for key in ('revision', 'tree'))):
        raise RuntimeError(f'Unsupported UI2 dependency lock: {path}')
    return lock


def validate_embedding_api(text, expected_version=1):
    """Check the public API marker, never an implementation-text patch anchor."""
    # embedding.v is deliberately a small API-generation declaration. Require
    # the whole declaration so comments, duplicates and expressions cannot
    # accidentally satisfy the contract or admit an unreviewed future API.
    code = re.sub(r'//[^\n]*|/\*.*?\*/', '', text, flags=re.DOTALL)
    version = re.fullmatch(
        r'\s*module\s+ui2\s+pub\s+const\s+embedded_controls_version\s*=\s*(0|[1-9][0-9]*)\s*',
        code)
    if version is None or int(version[1]) != expected_version:
        raise RuntimeError(f'Unsupported UI2 embedding API: expected one public '
                           f'embedded_controls_version = {expected_version} declaration')


def ui2_git(source, *arguments, input=None):
    try:
        return subprocess.run(
            ['git', '--no-replace-objects', '--no-optional-locks', '-c', 'core.fsmonitor=false',
             '-C', str(source), *arguments], input=input, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        detail = error.stderr.decode(errors='replace').strip() if isinstance(
            error, subprocess.CalledProcessError) else str(error)
        raise RuntimeError(f'Cannot read UI2 checkout {source}: {detail}') from error


def checked_ui2_files(source, lock):
    """Read committed blobs, so a checkout edit cannot race the staged copy."""
    root = Path(os.fsdecode(ui2_git(source, 'rev-parse', '--show-toplevel')).strip()).resolve()
    if root != source:
        raise RuntimeError(f'UI2_SOURCE_DIR must name the UI2 checkout root: {source}')
    revision = ui2_git(source, 'rev-parse', '--verify', 'HEAD').decode().strip()
    if revision != lock['revision']:
        raise RuntimeError(f'Unsupported UI2 revision {revision}; expected {lock["revision"]}. '
                           'See tools/ui2/README.md for the reviewed checkout instructions, '
                           'then set UI2_SOURCE_DIR to that checkout.')
    tree = ui2_git(source, 'rev-parse', '--verify', revision + '^{tree}').decode().strip()
    if tree != lock['tree']:
        raise RuntimeError(f'UI2 tree does not match the dependency lock: {tree}')
    if ui2_git(source, 'status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none'):
        raise RuntimeError('UI2 checkout is dirty (modified or untracked files). Preserve your '
                           'changes and use a clean checkout of the reviewed revision; '
                           'see tools/ui2/README.md.')

    entries = []
    for record in ui2_git(source, 'ls-tree', '-rz', '--full-tree', tree).split(b'\0'):
        if not record:
            continue
        metadata, raw_name = record.split(b'\t', 1)
        mode, kind, oid = metadata.decode().split()
        name = raw_name.decode('utf-8')
        relative = PurePosixPath(name)
        if (mode not in ('100644', '100755') or kind != 'blob'
                or relative.is_absolute() or any(part in ('.', '..', '.git') for part in relative.parts)
                or '\\' in name or ':' in name):
            raise RuntimeError(f'Unsupported UI2 tree entry (links/submodules are not staged): {name}')
        entries.append((name, mode, oid))
    if not entries:
        raise RuntimeError('The reviewed UI2 tree is empty')

    # cat-file ignores checkout filters, export-ignore attributes and mutable
    # symlink targets. Its length-prefixed protocol also preserves binary assets.
    objects = ui2_git(source, 'cat-file', '--batch',
                      input=('\n'.join(oid for _, _, oid in entries) + '\n').encode())
    files, offset = {}, 0
    for name, mode, oid in entries:
        end = objects.index(b'\n', offset)
        header = objects[offset:end].decode().split()
        if len(header) != 3 or header[:2] != [oid, 'blob']:
            raise RuntimeError(f'Cannot read reviewed UI2 blob: {name}')
        size = int(header[2])
        start, offset = end + 1, end + size + 2
        data = objects[start:offset - 1]
        if len(data) != size or objects[offset - 1:offset] != b'\n':
            raise RuntimeError(f'Incomplete reviewed UI2 blob: {name}')
        files[name] = (mode, data)
    if offset != len(objects):
        raise RuntimeError('Unexpected data in reviewed UI2 blobs')
    for name in ('ui/ui.v', 'ui/embedding.v', 'v.mod'):
        if name not in files:
            raise RuntimeError(f'Reviewed UI2 is missing required file: {name}')
    validate_embedding_api(files['ui/embedding.v'][1].decode('utf-8'), lock['embedding_api'])
    return files


def verify_ui2_stage(stage, manifest):
    """A published stage is reused as-is or rejected, never repaired in place."""
    expected = {'manifest.json'} | {'modules/ui2/' + name for name in manifest['files']}
    actual = set()
    if stage.is_symlink() or not stage.is_dir():
        raise RuntimeError(f'Invalid UI2 snapshot: {stage}')
    for path in stage.rglob('*'):
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise RuntimeError(f'Invalid UI2 snapshot entry: {path}')
        if path.is_file():
            actual.add(path.relative_to(stage).as_posix())
    if actual != expected:
        raise RuntimeError(f'UI2 snapshot contents changed: {stage}; remove it only after builds finish')
    try:
        if json.loads((stage / 'manifest.json').read_text()) != manifest:
            raise ValueError('manifest mismatch')
        for name, identity in manifest['files'].items():
            path = stage / 'modules/ui2' / name
            if hashlib.sha256(path.read_bytes()).hexdigest() != identity['sha256']:
                raise ValueError(f'content mismatch: {name}')
            if os.name != 'nt' and bool(path.stat().st_mode & 0o111) != (identity['mode'] == '100755'):
                raise ValueError(f'mode mismatch: {name}')
    except (OSError, ValueError) as error:
        raise RuntimeError(f'UI2 snapshot contents changed: {stage}: {error}; '
                           'remove it only after builds finish') from error


def write_if_changed(path, text):
    if not path.is_file() or path.read_text() != text:
        path.write_text(text)


def link_to(path, source):
    if path.is_symlink():
        if path.resolve() == source.resolve():
            return
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()
    path.symlink_to(source, target_is_directory=source.is_dir())


def link_directory_files(path, source):
    """Keep cache directories real so later module staging cannot edit vlib."""
    if path.is_symlink() or path.is_file():
        path.unlink()
    path.mkdir(parents=True, exist_ok=True)
    for entry in source.iterdir():
        if entry.is_dir():
            link_directory_files(path / entry.name, entry)
        else:
            link_to(path / entry.name, entry)


def prepare_gg_gradient(modules, vlib):
    """Keep FastC's map-string arithmetic separate from its method receiver."""
    source = vlib / 'gg'
    gradient = source / 'canvas/gpu_gradient.v'
    if not gradient.is_file():
        return
    original = "(snippets['bodies_tile'] + snippets['body_colorize_${stops}']).replace('_skTemp',"
    text = gradient.read_text()
    if original in text:
        text = text.replace('bodies_tile := ' + original,
                            "tile_source := snippets['bodies_tile'] + snippets['body_colorize_${stops}']\n"
                            "\tbodies_tile := tile_source.replace('_skTemp',")
    target = modules / 'gg'
    target.mkdir(exist_ok=True)
    for entry in source.iterdir():
        if entry.name != 'canvas':
            if entry.is_dir():
                link_directory_files(target / entry.name, entry)
            else:
                link_to(target / entry.name, entry)
    canvas = target / 'canvas'
    canvas.mkdir(exist_ok=True)
    for entry in (source / 'canvas').iterdir():
        if entry.name == gradient.name:
            if (canvas / entry.name).is_symlink():
                (canvas / entry.name).unlink()
            write_if_changed(canvas / entry.name, text)
        elif entry.is_file() and entry.suffix == '.v' and 'fn C.' in entry.read_text():
            # Native canvas helpers must be exported by FastC's native bridge.
            # Keep Apple's headers and paired sin/cos in that native owner.
            if (canvas / entry.name).is_symlink():
                (canvas / entry.name).unlink()
            def native_include(match):
                name = match[1]
                if 'darwin' not in name and name != 'path_math.h':
                    return match[0]
                wrapper = 'vox_' + Path(name).stem + '.m'
                header = (source / 'canvas' / name).resolve()
                if not header.is_file():
                    raise RuntimeError('Missing GG native helper: ' + str(header))
                write_if_changed(canvas / wrapper, '#include "' + str(header) + '"\n')
                return '#include "@DIR/' + wrapper + '"'
            context = re.sub(r'#include "@DIR/([^"\n]+\.h)"', native_include, entry.read_text())
            write_if_changed(canvas / entry.name, context)
        elif entry.is_dir():
            link_directory_files(canvas / entry.name, entry)
        else:
            link_to(canvas / entry.name, entry)


def prepare_ui2_source(source, cache, lock=None):
    """Publish unmodified UI2 blobs at a stable, content-identified module path."""
    lock = load_ui2_lock() if lock is None else lock
    files = checked_ui2_files(Path(source).resolve(), lock)
    manifest = {
        'schema_version': 1,
        'dependency': lock,
        'files': {name: {'mode': mode, 'sha256': hashlib.sha256(data).hexdigest()}
                  for name, (mode, data) in files.items()},
    }
    serialized = json.dumps(manifest, indent=2, sort_keys=True) + '\n'
    identity = hashlib.sha256(serialized.encode()).hexdigest()
    cache = Path(cache).resolve()
    cache.mkdir(parents=True, exist_ok=True)
    stage = cache / identity
    if stage.exists() or stage.is_symlink():
        verify_ui2_stage(stage, manifest)
        return stage / 'modules'

    # A compiler only sees complete stages. Concurrent preparations may race
    # to publish the same bytes, but never change a previously returned path.
    temporary = Path(tempfile.mkdtemp(prefix='.ui2-', dir=cache))
    try:
        for name, (mode, data) in files.items():
            destination = temporary / 'modules/ui2' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            destination.chmod(0o755 if mode == '100755' else 0o644)
        (temporary / 'manifest.json').write_text(serialized)
        verify_ui2_stage(temporary, manifest)
        try:
            temporary.rename(stage)
        except OSError:
            if not (stage.exists() or stage.is_symlink()):
                raise
            verify_ui2_stage(stage, manifest)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)
    return stage / 'modules'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiler', nargs='?', help='V compiler used for compatibility modules')
    parser.add_argument('--print-revision', action='store_true',
                        help='print the reviewed UI2 revision without staging')
    args = parser.parse_args()
    lock = load_ui2_lock()
    if args.print_revision:
        print(lock['revision'])
        return
    repo = Path(__file__).resolve().parent.parent
    modules = Path(os.environ.get('VMODULES', str(Path.home() / '.vmodules')))
    source = Path(os.environ.get('UI2_SOURCE_DIR', str(modules / 'ui2'))).resolve()
    if not (source / 'ui/ui.v').is_file():
        raise SystemExit('UI2 not found. Set UI2_SOURCE_DIR to your UI2 checkout.')
    platform_dir = 'linux' if sys.platform.startswith('linux') else 'windows' if os.name == 'nt' else 'v'
    target = repo / 'Build' / platform_dir / 'modules'
    target.mkdir(parents=True, exist_ok=True)
    ui2_modules = prepare_ui2_source(source, target.parent / 'ui2-snapshots', lock)
    compiler_name = args.compiler or os.environ.get(
        'V_BIN', shutil.which('v') or str(Path.home() / 'code/v/v'))
    compiler = Path(compiler_name).resolve()
    prepare_gg_gradient(target, compiler.parent / 'vlib')
    if sys.platform == 'darwin':
        macos_source = compiler.parent / 'vlib/macos'
        if not (macos_source / 'objc_bridge.h').is_file():
            raise SystemExit('UI2 requires a current V checkout with vlib/macos.')
        macos = target / 'macos'
        if macos.is_dir() and not macos.is_symlink():
            shutil.rmtree(macos)
        link_to(macos, macos_source)
    # The first path owns only UI2; the second still holds V/GG compatibility
    # modules. Keep UI2 ahead of any legacy modules/ui2 symlink, and do not
    # change that old path underneath a build which already obtained it.
    print(f'{ui2_modules}|{target}')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        raise SystemExit(str(error))
