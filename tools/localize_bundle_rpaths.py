#!/usr/bin/env python3
"""Remove the shared build-directory search path from a packaged Mach-O.

V adds -L directories to LC_RPATH. Production helper libraries are copied into
the app, so @executable_path must own their resolution after packaging. Run
before the bundle's final code signature is created.
"""
import argparse
from pathlib import Path
import re
import subprocess


def localize(executable, build_directory):
    commands = subprocess.check_output(['otool', '-l', str(executable)], text=True)
    paths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset \d+\)', commands)
    # V modules can add the canonical library directory independently of the
    # staging directory passed by the production build. Both must disappear:
    # otherwise the app can load newer shared libraries than its signed ones.
    shared_build_directory = Path(__file__).resolve().parents[1] / 'Build/v'
    external = {str(Path(folder).resolve())
                for folder in (build_directory, shared_build_directory)}
    remove = [path for path in paths if str(Path(path).resolve()) in external]
    if remove and '@executable_path' not in paths:
        raise RuntimeError('Cannot remove the shared runtime path without a bundle-local search path')
    for path in dict.fromkeys(remove):
        subprocess.run(['install_name_tool', '-delete_rpath', path, str(executable)], check=True)
    return remove


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable', type=Path)
    parser.add_argument('build_directory', type=Path)
    args = parser.parse_args()
    removed = localize(args.executable, args.build_directory)
    for path in removed:
        print('Removed shared runtime search path:', path)


if __name__ == '__main__':
    main()
