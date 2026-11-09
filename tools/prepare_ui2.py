#!/usr/bin/env python3
"""Use the current upstream UI2 checkout and prepare compiler compatibility modules."""

import argparse
import os
import re
from pathlib import Path
import shutil
import sys


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


def prepare_ui2_source(source, target):
    """Link the installed UI2 checkout directly, without pinning or copying it."""
    source = Path(source).resolve()
    if not all((source / name).is_file() for name in ('v.mod', 'ui/ui.v', 'ui/embedding.v')):
        raise RuntimeError('UI2 is missing its embedding API. Install or update the latest '
                           'UI2 with v install ui2 / v up ui2, or set UI2_SOURCE_DIR '
                           'to your current UI2 checkout.')
    target.parent.mkdir(parents=True, exist_ok=True)
    link_to(target, source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiler', nargs='?', help='V compiler used for compatibility modules')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    modules = Path(os.environ.get('VMODULES', str(Path.home() / '.vmodules')))
    source = Path(os.environ.get('UI2_SOURCE_DIR', str(modules / 'ui2'))).resolve()
    platform_dir = 'linux' if sys.platform.startswith('linux') else 'windows' if os.name == 'nt' else 'v'
    target = repo / 'Build' / platform_dir / 'modules'
    target.mkdir(parents=True, exist_ok=True)
    prepare_ui2_source(source, target / 'ui2')
    compiler_name = args.compiler or os.environ.get(
        'V_BIN', shutil.which('v') or str(Path.home() / 'code/v/v'))
    compiler = Path(compiler_name).resolve()
    prepare_gg_gradient(target, compiler.parent / 'vlib')
    if sys.platform == 'darwin':
        from prepare_gg_metal import prepare_sokol_metal
        prepare_sokol_metal(target, compiler.parent / 'vlib')
        macos_source = compiler.parent / 'vlib/macos'
        if not (macos_source / 'objc_bridge.h').is_file():
            raise SystemExit('UI2 requires a current V checkout with vlib/macos.')
        macos = target / 'macos'
        if macos.is_dir() and not macos.is_symlink():
            shutil.rmtree(macos)
        link_to(macos, macos_source)
    print(target)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        raise SystemExit(str(error))
