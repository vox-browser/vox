#!/usr/bin/env python3
"""Stage Vox's Sokol texture transfers without changing the V checkout."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import tempfile


def patch_header(source, helper):
    start = '_SOKOL_PRIVATE bool _sg_v_mtl_transfer('
    end = '\n}\n#endif\n\n#if defined(_SOKOL_ANY_GL)'
    if source.count(start) != 1 or source.count(end, source.index(start)) != 1:
        raise RuntimeError('Unsupported Sokol Metal image-transfer implementation')
    first = source.index(start)
    last = source.index(end, first) + len('\n}')
    body = source[first:last]
    for token in ['_sg_v_mtl_flush()', '[cmd_buffer waitUntilCompleted]',
                  'copyFromTexture:tex', '_SG_OBJC_RELEASE(staging)']:
        if body.count(token) != 1:
            raise RuntimeError('Unsupported Sokol Metal transfer: ' + token)
    body = body.replace('_sg_v_mtl_transfer(', '_sg_v_mtl_transfer_separate(', 1)
    return source[:first] + body + '\n#include ' + json.dumps(str(helper.resolve())) + source[last:]


def patch_d3d11_transfers(source, helper):
    patches = json.loads(Path(__file__).with_name('buildtools').joinpath('gg_patches.json').read_text())
    for operation in patches['prepare_sokol_d3d11_transfers']:
        old = operation['old']
        if source.count(old) != 1:
            raise RuntimeError('Unsupported Sokol D3D11 transfer implementation: ' + old)
        source = source.replace(old, operation['new'], 1)
    return source.replace('#include "native_gg_d3d11_transfer.h"',
                          '#include ' + json.dumps(str(helper.resolve())), 1)


def prepare_sokol_metal(modules, vlib, output_root=None, *, d3d11=False):
    repo = Path(__file__).resolve().parents[1]
    helper = repo / 'native/include/native_gg_metal_transfer.h'
    source = vlib.parent / 'thirdparty/sokol/sokol_gfx.h'
    declaration = vlib / 'sokol/c/declaration.c.v'
    original = declaration.read_text()
    include = '#include "sokol_gfx.h"'
    if original.count(include) != 1:
        raise RuntimeError('Unsupported Sokol native include declaration')
    header = patch_header(source.read_text(), helper)
    helpers = [helper]
    if d3d11:
        d3d11_helper = repo / 'native/include/native_gg_d3d11_transfer.h'
        header = patch_d3d11_transfers(header, d3d11_helper)
        helpers.append(d3d11_helper)
    digest = hashlib.sha256(Path(__file__).read_bytes())
    for data in [str(vlib.resolve()).encode(), header.encode(), original.encode(),
                 *(path.read_bytes() for path in helpers)]:
        digest.update(data)
    root = (output_root or repo / 'Build/v/native-gg-runtime') / digest.hexdigest()
    target = root / 'sokol_gfx.h'
    text = original.replace(include, '#include ' + json.dumps(str(target.resolve())))
    # Retain real cache directories; later module staging may write into them.
    from prepare_ui2 import link_directory_files
    root.parent.mkdir(parents=True, exist_ok=True)
    with (root.parent / (root.name + '.lock')).open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        files = {'sokol_gfx.h': header, 'declaration.c.v': text}
        if root.exists():
            if any(not (root / name).is_file() or (root / name).read_text() != value
                   for name, value in files.items()):
                raise RuntimeError('Modified staged Sokol runtime: ' + str(root))
        else:
            with tempfile.TemporaryDirectory(dir=root.parent) as temporary:
                stage = Path(temporary) / 'runtime'
                stage.mkdir()
                for name, value in files.items():
                    (stage / name).write_text(value)
                (stage / 'manifest.json').write_text(json.dumps({
                    'source': str(source.resolve()),
                    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'helpers': {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in helpers},
                    'sha256': digest.hexdigest(),
                }, indent=2) + '\n')
                stage.rename(root)
        os.utime(root)
    link_directory_files(modules / 'sokol/c', vlib / 'sokol/c')
    staged = modules / 'sokol/c/declaration.c.v'
    staged.unlink()
    staged.symlink_to(root / 'declaration.c.v')
    return root
