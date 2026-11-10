#!/usr/bin/env python3
"""Package the Windows build into a portable zip.

Zips every file under Build/windows except the zip itself, storing paths
relative to Build/windows so the archive extracts into one folder.
"""
import argparse
import pathlib
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, default=pathlib.Path('Build/windows'))
    parser.add_argument('--output', type=pathlib.Path, default=pathlib.Path('Build/windows/vox-portable.zip'))
    args = parser.parse_args()
    root = args.source.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob('*')):
            if path.is_file() and path != output:
                archive.write(path, path.relative_to(root))
    print(f'packaged {output} ({output.stat().st_size} bytes)')


if __name__ == '__main__':
    main()
