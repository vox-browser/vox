#!/usr/bin/env python3
"""Package the Windows build into a portable zip.

Zips the runtime payload under Build/windows, storing paths relative to
Build/windows so the archive extracts into one folder. Generated artifacts
(the zip itself, NSIS setup executables, debug symbols) are excluded so a
later `package-zip` run never bundles stale build outputs.
"""
import argparse
import fnmatch
import pathlib
import zipfile

# File-name patterns (matched against the name, not the full path) that are
# never part of the runtime payload.
EXCLUDED = ('Vox-*-setup.exe', '*.pdb')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, default=pathlib.Path('Build/windows'))
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('Build/windows/vox-portable.zip'))
    args = parser.parse_args()
    root = args.source.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    skipped = []

    def excluded(path):
        if path == output:
            return True
        return any(fnmatch.fnmatchcase(path.name, pattern) for pattern in EXCLUDED)

    count = 0
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob('*')):
            if not path.is_file():
                continue
            if excluded(path):
                skipped.append(path.name)
                continue
            archive.write(path, path.relative_to(root))
            count += 1
    print(f'packaged {count} file(s) into {output} ({output.stat().st_size} bytes)')
    if skipped:
        print(f'skipped {len(skipped)} generated artifact(s): {", ".join(sorted(skipped))}')


if __name__ == '__main__':
    main()
