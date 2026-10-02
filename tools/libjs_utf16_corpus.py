#!/usr/bin/env python3
"""Refresh exact UTF-16 validation/repair fixtures from pinned simdutf 7.4.0."""
import argparse
import itertools
import os
from pathlib import Path
import random
import subprocess
import tempfile

ORACLE = r'''
#include <simdutf.h>
#include <simdutf/simdutf_version.h>
#include <iomanip>
#include <iostream>
#include <string>
int main() {
    static_assert(simdutf::SIMDUTF_VERSION_MAJOR == 7 && simdutf::SIMDUTF_VERSION_MINOR == 4
        && simdutf::SIMDUTF_VERSION_REVISION == 0);
    std::string hex;
    while (std::cin >> hex) {
        std::u16string input;
        if (hex != "-")
            for (size_t i = 0; i < hex.size(); i += 4)
                input.push_back(static_cast<char16_t>(std::stoul(hex.substr(i, 4), nullptr, 16)));
        std::u16string output(input.size(), 0);
        bool valid = simdutf::validate_utf16(input.data(), input.size());
        simdutf::to_well_formed_utf16(input.data(), input.size(), output.data());
        std::cout << hex << '\t' << valid << '\t';
        if (output.empty()) std::cout << '-';
        for (char16_t unit : output)
            std::cout << std::hex << std::setfill('0') << std::setw(4) << unsigned(unit);
        std::cout << std::dec << '\n';
    }
}
'''


def cases():
    boundaries = [0, 0x7f, 0x80, 0xd7ff, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xe000, 0xffff]
    yield []
    for unit in boundaries:
        yield [unit]
    yield from itertools.product(boundaries, repeat=2)
    yield from itertools.product(boundaries[:2] + boundaries[3:9], repeat=3)
    for length in [15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128]:
        for pattern in [[0xd800], [0xdc00], [0xd800, 0xdc00], [0xd800, 0xd800, 0xdc00], [0xdc00, 0, 0xd800]]:
            yield (pattern * (length // len(pattern) + 1))[:length]
    rng = random.Random(0x16_74_00)
    for _ in range(1710):
        yield [rng.randrange(65536) if rng.randrange(3) == 0 else rng.choice(boundaries)
               for _ in range(rng.randrange(130))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simdutf-prefix', type=Path, default=Path.home() /
                        'code/3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'libjs/testdata/string-well-formed.tsv')
    args = parser.parse_args()
    records = [''.join(f'{unit:04x}' for unit in units) or '-' for units in cases()]
    with tempfile.TemporaryDirectory(prefix='vox2-utf16-') as directory:
        source = Path(directory) / 'oracle.cpp'
        binary = Path(directory) / 'oracle'
        source.write_text(ORACLE)
        prefix = args.simdutf_prefix.resolve()
        subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', str(source),
                        '-I' + str(prefix / 'include'), '-L' + str(prefix / 'lib'),
                        '-Wl,-rpath,' + str(prefix / 'lib'), '-lsimdutf', '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], input='\n'.join(records) + '\n',
                                capture_output=True, text=True, check=True)
    answers = result.stdout.splitlines()
    assert len(answers) == len(records)
    args.output.write_text('# simdutf 7.4.0 native UTF-16: input, valid, repaired output\n' +
                           '\n'.join(answers) + '\n')
    print(f'{len(records)} exact UTF-16 fixtures written to {args.output}')


if __name__ == '__main__':
    main()
