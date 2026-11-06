#!/usr/bin/env python3
"""Copy an app's third-party dylibs into the app and verify that it is self-contained.

Production builds link vcpkg and Homebrew libraries through absolute search
paths that exist only on the build machine. A release must carry them itself:
copy every non-system library the bundle's Mach-O files load, including the
libraries the browser opens with dlopen("@rpath/..."), into
Contents/Frameworks. Address them through @rpath and drop every absolute
search path, so another machine's Homebrew cannot supply different code.
Bundling invalidates code signatures; the caller signs the modified files.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

SYSTEM_PREFIXES = ('/usr/lib/', '/System/Library/')
REQUIRED_COMMANDS = {'LC_LOAD_DYLIB', 'LC_REEXPORT_DYLIB', 'LC_LOAD_UPWARD_DYLIB', 'LC_LAZY_LOAD_DYLIB'}
OPTIONAL_COMMANDS = {'LC_LOAD_WEAK_DYLIB'}
MACHO_MAGICS = {0xfeedface, 0xfeedfacf, 0xcefaedfe, 0xcffaedfe, 0xcafebabe, 0xbebafeca}
LOAD_COMMAND = re.compile(r'^\s*cmd (LC_\w+)\n\s*cmdsize \d+\n\s*(?:name|path) (.*?) \(offset \d+\)$', re.M)
# String literals passed to dlopen. Load commands also match; they are deduplicated.
RUNTIME_NAME = re.compile(rb'@rpath/[A-Za-z0-9_.+-]+\.dylib')


def is_macho(path):
    if path.is_symlink() or not path.is_file():
        return False
    with path.open('rb') as file:
        magic = file.read(4)
    return len(magic) == 4 and int.from_bytes(magic, 'big') in MACHO_MAGICS


def macho_files(app):
    return [path for path in sorted((app / 'Contents').rglob('*')) if is_macho(path)]


class Image:
    def __init__(self, path):
        output = subprocess.check_output(['/usr/bin/otool', '-l', str(path)], text=True)
        commands = LOAD_COMMAND.findall(output)
        self.identity = next((value for command, value in commands if command == 'LC_ID_DYLIB'), None)
        self.dependencies = list(dict.fromkeys(
            (value, command in REQUIRED_COMMANDS) for command, value in commands
            if command in REQUIRED_COMMANDS | OPTIONAL_COMMANDS))
        self.rpaths = [value for command, value in commands if command == 'LC_RPATH']


def is_system(name):
    return name.startswith(SYSTEM_PREFIXES)


def substitute(path, loader, executable_directory):
    for token, folder in (('@loader_path', loader.parent), ('@executable_path', executable_directory)):
        if path == token or path.startswith(token + '/'):
            return Path(str(folder) + path[len(token):])
    return Path(path)


def search_paths(image, location, executable_directory):
    return [substitute(rpath, location, executable_directory) for rpath in image.rpaths]


def locate(name, paths, loader, executable_directory):
    """Return the file dyld loads for name, searching paths for @rpath names."""
    if name.startswith('@rpath/'):
        candidates = [folder / name[len('@rpath/'):] for folder in paths]
    else:
        candidates = [substitute(name, loader, executable_directory)]
    return next((candidate for candidate in candidates if candidate.is_file()), None)


def executable_paths(images, executable_directory):
    # dyld falls back to the main executable's search paths for every image.
    return [path for location, image in images.items()
            if image.identity is None and location.parent == executable_directory
            for path in search_paths(image, location, executable_directory)]


def bundle_libraries(app):
    """Copy external libraries into Contents/Frameworks; return the Mach-O files changed."""
    contents = app / 'Contents'
    executable_directory = contents / 'MacOS'
    frameworks = contents / 'Frameworks'
    inside = app.resolve()
    originals = {path: Image(path) for path in macho_files(app)}
    fallback = executable_paths(originals, executable_directory)
    copies = {}  # real source file -> bundled file
    changes = {}  # bundled image -> {original reference: @rpath reference}
    aliases = {}  # dlopen leaf name -> bundled file
    referencing = set()  # images that load a bundled library
    images = dict(originals)
    pending = [(location, location) for location in originals]
    while pending:
        location, origin = pending.pop(0)
        image = images[location]
        paths = search_paths(image, origin, executable_directory) + fallback
        references = list(image.dependencies)
        if location in originals:
            listed = {name for name, _ in references}
            runtime = {match.decode() for match in RUNTIME_NAME.findall(location.read_bytes())}
            references += [(name, None) for name in sorted(runtime - listed - {image.identity})]
        for name, required in references:
            if is_system(name):
                continue
            source = locate(name, paths, origin, executable_directory)
            if source is None:
                if required:
                    raise RuntimeError('%s links %s, which is not on this machine'
                                       % (location.relative_to(app), name))
                if required is None:
                    print('Optional runtime library not found; leaving it out: ' + name, flush=True)
                continue
            real = source.resolve()
            if real.is_relative_to(inside):
                continue
            if real not in copies:
                source_image = Image(real)
                target = frameworks / Path(source_image.identity or real.name).name
                if target.exists() or target.is_symlink():
                    raise RuntimeError('Two libraries are both named ' + target.name)
                frameworks.mkdir(exist_ok=True)
                shutil.copyfile(real, target)
                target.chmod(0o755)
                copies[real] = target
                images[target] = source_image
                pending.append((target, real))
            target = copies[real]
            referencing.add(location)
            if required is None:
                leaf = name[len('@rpath/'):]
                if aliases.setdefault(leaf, target) != target:
                    raise RuntimeError('%s refers to two different libraries' % name)
            else:
                changes.setdefault(location, {})[name] = '@rpath/' + target.name

    # dlopen names an unversioned or major-version file; the copy keeps its install name.
    for leaf, target in aliases.items():
        alias = frameworks / leaf
        if leaf == target.name:
            continue
        if alias.exists() or alias.is_symlink():
            raise RuntimeError('Two libraries are both named ' + leaf)
        alias.symlink_to(target.name)
    modified = []
    for location, image in images.items():
        arguments = []
        if location.parent == frameworks:
            arguments += ['-id', '@rpath/' + location.name]
        for old, new in changes.get(location, {}).items():
            if old != new:
                arguments += ['-change', old, new]
        for rpath in image.rpaths:
            if not rpath.startswith('@'):
                arguments += ['-delete_rpath', rpath]
        if location in referencing or location.parent == frameworks:
            if location.parent == frameworks:
                wanted = '@loader_path'
            elif image.identity is None and location.parent == executable_directory:
                wanted = '@executable_path/../Frameworks'
            else:
                wanted = '@loader_path/' + os.path.relpath(frameworks, location.parent)
            if wanted not in image.rpaths:
                arguments += ['-add_rpath', wanted]
        if arguments:
            subprocess.run(['/usr/bin/install_name_tool', *arguments, str(location)],
                           check=True, capture_output=True)
            modified.append(location)
    return modified


def verify_self_contained(app):
    """Reject a bundle whose Mach-O files load code from outside the app and the OS."""
    executable_directory = app / 'Contents/MacOS'
    inside = app.resolve()
    images = {path: Image(path) for path in macho_files(app)}
    fallback = executable_paths(images, executable_directory)
    problems = []
    for location, image in images.items():
        name = str(location.relative_to(app))
        for rpath in image.rpaths:
            if not rpath.startswith(('@loader_path', '@executable_path')):
                problems.append('%s searches %s' % (name, rpath))
        paths = search_paths(image, location, executable_directory) + fallback
        for dependency, required in image.dependencies:
            if is_system(dependency):
                continue
            found = locate(dependency, paths, location, executable_directory)
            if found is None and not required:
                continue
            if found is None or not found.resolve().is_relative_to(inside):
                problems.append('%s loads %s from outside the app' % (name, dependency))
    if problems:
        raise RuntimeError('The release is not self-contained:\n  ' + '\n  '.join(problems))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    if not args.verify_only:
        for path in bundle_libraries(args.app):
            print('Updated ' + str(path.relative_to(args.app)))
    verify_self_contained(args.app)


if __name__ == '__main__':
    main()
