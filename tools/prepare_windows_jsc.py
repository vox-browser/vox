#!/usr/bin/env python3
"""Create a MinGW import library from an actual Windows JavaScriptCore DLL."""

import argparse
import os
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dll', type=Path)
    parser.add_argument('--objdump', default=os.environ.get('OBJDUMP', 'objdump'))
    parser.add_argument('--dlltool', default=os.environ.get('DLLTOOL', 'dlltool'))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    header = (repo / 'browserjs/include/JavaScriptCore/JavaScript.h').read_text()
    required = set(re.findall(r'^JS_EXPORT\s+.+?\s+(JS\w+)\(', header, re.MULTILINE))
    exports = subprocess.check_output([args.objdump, '-p', str(args.dll)], text=True)
    if 'pei-x86-64' not in exports:
        raise SystemExit('JavaScriptCore must be a Windows x86-64 DLL')
    available = set(re.findall(r'^\s*\[\s*\d+\].*?\s(JS\w+)\s*$', exports, re.MULTILINE))
    missing = required - available
    if missing:
        raise SystemExit('JavaScriptCore DLL lacks: ' + ', '.join(sorted(missing)))
    output = repo / 'Build/deps/windows/native'
    output.mkdir(parents=True, exist_ok=True)
    definition = output / 'JavaScriptCore.def'
    definition.write_text('LIBRARY ' + args.dll.name + '\nEXPORTS\n'
                          + '\n'.join(sorted(required)) + '\n')
    archive = output / 'libJavaScriptCore.dll.a'
    temporary = archive.with_suffix('.tmp.a')
    subprocess.run([args.dlltool, '-m', 'i386:x86-64', '-d', str(definition),
                    '-l', str(temporary)], check=True)
    temporary.replace(archive)
    print(f'Imported {len(required)} verified JavaScriptCore exports: {archive}')


if __name__ == '__main__':
    main()
