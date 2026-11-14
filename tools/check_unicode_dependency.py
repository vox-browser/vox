#!/usr/bin/env python3
"""Reject direct ICU bridges/links in Vox source and an optional built executable."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
SOURCE_ICU = re.compile(
    r'#\s*include\s*[<"][^>"\n]*unicode/'
    r'|#(?:flag|pkgconfig)[^\n]*(?:-licu|libicu|icu4c|icu-uc|icu-i18n)'
    r'|\bfn\s+C\.(?:u_|ubidi_|ucasemap_|unorm2_|uset_|uidna_|uscript_|uloc_|ubrk_)')
SYMBOL_ICU = re.compile(r'\b_?(?:u_|ubidi_|ucasemap_|unorm2_|uset_|uidna_|uscript_|uloc_|ubrk_)\w+')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable', nargs='?', type=Path)
    args = parser.parse_args()
    files = subprocess.check_output(['git', 'ls-files', '-z', '-c', '-o', '--exclude-standard'], cwd=ROOT)
    errors = []
    for raw in set(files.split(b'\0')):
        if not raw:
            continue
        path = ROOT / raw.decode()
        if not path.is_file() or path.suffix not in {'.v', '.h', '.cpp'}:
            continue
        for number, line in enumerate(path.read_text(errors='replace').splitlines(), 1):
            if SOURCE_ICU.search(line):
                errors.append(f'{path.relative_to(ROOT)}:{number}: {line.strip()}')
    if args.executable:
        binary = args.executable.resolve()
        command = ['otool', '-L', str(binary)] if sys.platform == 'darwin' else ['readelf', '-d', str(binary)]
        libraries = subprocess.check_output(command, text=True)
        symbols = subprocess.check_output(['nm', '-u', str(binary)], text=True)
        if re.search(r'libicu|icu4c', libraries, re.I):
            errors.append(libraries)
        errors.extend(SYMBOL_ICU.findall(symbols))
    if errors:
        raise SystemExit('\n'.join(errors))
    print('No direct ICU source, library or symbol dependency')


if __name__ == '__main__':
    main()
