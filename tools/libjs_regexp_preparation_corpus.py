#!/usr/bin/env python3
"""Refresh exact RegExp preparation fixtures from the pinned LibJS/AK sources.

The oracle extracts upstream helper bodies without algorithm changes. A minimal
carrier holds the actual Flags declaration; escape_regexp_pattern's member
signature becomes a free function taking m_pattern. The regex compiler and GC
are never used. AK is compiled afresh because an older native build may have an
incompatible UTF-16 ABI. All build artifacts stay in a temporary directory.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import itertools
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile

UPSTREAM_COMMIT = '963d46a829f3e1b79f44dba9d02afb70654300fa'

DRIVER = r'''
void print_utf16(Utf16String const& text) {
    if (text.is_empty()) std::cout << '-';
    for (size_t i = 0; i < text.length_in_code_units(); ++i)
        std::cout << std::hex << std::setfill('0') << std::setw(4) << unsigned(text.code_unit_at(i));
    std::cout << std::dec;
}
int main() {
    std::string operation, hex;
    bool unicode, unicode_sets;
    while (std::cin >> operation >> unicode >> unicode_sets >> hex) {
        std::u16string units;
        if (hex != "-")
            for (size_t i = 0; i < hex.size(); i += 4)
                units.push_back(static_cast<char16_t>(std::stoul(hex.substr(i, 4), nullptr, 16)));
        auto input = Utf16String::from_utf16(Utf16View { units.data(), units.size() });
        std::cout << operation << '\t' << unicode << '\t' << unicode_sets << '\t' << hex << '\t';
        if (operation == "flags") {
            auto result = JS::validate_flags(input);
            if (result.is_error()) { std::cout << "error\t"; print_utf16(result.release_error()); }
            else std::cout << "ok\t" << unsigned(result.release_value());
        } else if (operation == "bits") {
            std::cout << "ok\t" << unsigned(JS::to_flag_bits(input));
        } else if (operation == "parse") {
            auto result = JS::parse_regex_pattern(input, unicode, unicode_sets);
            if (result.is_error()) { std::cout << "error\t"; print_utf16(result.release_error().error); }
            else { std::cout << "ok\t"; print_utf16(result.release_value()); }
        } else if (operation == "escape") {
            std::cout << "ok\t"; print_utf16(JS::escape_regexp_pattern(input));
        } else return 2;
        std::cout << '\n';
    }
}
'''


def between(text, start, end):
    assert text.count(start) == 1 and text.count(end) == 1, (start, end)
    return text[text.index(start):text.index(end)]


def oracle_source(upstream):
    source = (upstream / 'Libraries/LibJS/Runtime/RegExpObject.cpp').read_text()
    header = (upstream / 'Libraries/LibJS/Runtime/RegExpObject.h').read_text()
    record = between(header, 'struct ParseRegexPatternError {',
                     'ErrorOr<Utf16String, ParseRegexPatternError> parse_regex_pattern')
    flags = between(header, '    enum class Flags {',
                    '    static GC::Ref<RegExpObject> create(Realm&);')
    preparation = between(source, 'namespace {\n',
                          '// 22.2.3.4 Static Semantics: ParsePattern ( patternText, u, v ), '
                          'https://tc39.es/ecma262/#sec-parsepattern\n'
                          'ThrowCompletionOr<Utf16String> parse_regex_pattern')
    bits = between(source, 'static RegExpObject::Flags to_flag_bits',
                   'RegExpObject::RegExpObject(Utf16String pattern')
    escape = between(source, 'Utf16String RegExpObject::escape_regexp_pattern() const',
                     'void RegExpObject::visit_edges')
    escape = escape.replace('Utf16String RegExpObject::escape_regexp_pattern() const',
                            'Utf16String escape_regexp_pattern(Utf16String const& m_pattern)', 1)
    token = (upstream / 'Libraries/LibJS/Token.h').read_text()
    separators = '\n'.join(re.findall(r'^constexpr u32 (?:LINE|PARAGRAPH)_SEPARATOR = .*;$', token, re.M))
    assert separators.count('constexpr') == 2
    return '''#include <AK/CharacterTypes.h>
#include <AK/EnumBits.h>
#include <AK/Result.h>
#include <AK/UnicodeUtils.h>
#include <AK/Utf16StringBuilder.h>
#include <LibJS/Forward.h>
#include <LibJS/Runtime/ErrorTypes.h>
#include <simdutf/simdutf_version.h>
#include <iomanip>
#include <iostream>
#include <string>
static_assert(simdutf::SIMDUTF_VERSION_MAJOR == 9 && simdutf::SIMDUTF_VERSION_MINOR == 1
    && simdutf::SIMDUTF_VERSION_REVISION == 0);
namespace JS {
''' + record + 'class RegExpObject { public:\n' + flags + '''};
AK_ENUM_BITWISE_OPERATORS(RegExpObject::Flags);
''' + separators + '\n' + preparation + bits + escape + '}\n' + DRIVER


def utf16_units(text):
    data = text.encode('utf-16-le', errors='surrogatepass')
    return tuple(int.from_bytes(data[i:i + 2], 'little') for i in range(0, len(data), 2))


def cases():
    flags = utf16_units('dgimsvuy')
    for mask in range(256):
        text = tuple(unit for bit, unit in enumerate(flags) if mask & (1 << bit))
        for operation in ['flags', 'bits']:
            yield operation, False, False, text
        for flag in flags:
            yield 'flags', False, False, text + (flag, flag)
    invalid = [unit for unit in range(128) if unit not in flags]
    invalid += [0x80, 0xe9, 0xd7ff, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xe000, 0xffff]
    for unit in invalid:
        for operation in ['flags', 'bits']:
            yield operation, False, False, (ord('u'), ord('v'), unit)
    boundaries = [0, 0x7f, 0x80, 0xe9, 0x2028, 0xd7ff, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xe000, 0xffff]
    patterns = [(), *itertools.product(boundaries, repeat=2)]
    for unit in boundaries:
        for count in range(6):
            patterns.append((ord('\\'),) * count + (unit, 0xd83d, 0xde00))
    fragments = ['a', '', '\\u0061', '\\u123g', '\\x61', '\\u{0000000000061}',
                 '\\u{10ffff}', '\\u{110000}', '\\u{}', '\\u{123', '\\uD800', '\\uDC00',
                 '\\u{D800}', '\\u{DC00}', '\ud800', '\udc00', '\ud800\udc00', '\\']
    for first, second in itertools.product(fragments, repeat=2):
        for template in ['(?<{}>a)', '\\k<{}>(?<a>a)']:
            patterns.append(utf16_units(template.format(first + second)))
    for name in fragments:
        for template in ['\\k<{}>', '[\\k<{}>]', '[(?<{}>)]', '\\(?<{}>)',
                         '(?<=a)\\k<{}>', '(?<!a)\\k<{}>', '\\k<{}>(?<', '(?<{}']:
            patterns.append(utf16_units(template.format(name)))
    patterns += [utf16_units(text) for text in ['[', '(', '(?<', '(?<>)', '(?<1>)']]
    rng = random.Random(0x22_2_34)
    alphabet = boundaries + list(utf16_units('\\[]/(?<>=!ku0123abc{}'))
    for _ in range(500):
        patterns.append(tuple(rng.choice(alphabet) for _ in range(rng.randrange(33))))
    for text in patterns:
        for unicode, unicode_sets in [(False, False), (True, False), (False, True)]:
            yield 'parse', unicode, unicode_sets, text
        yield 'escape', False, False, text
    for text in patterns[:20]:
        yield 'parse', True, True, text
    for text in itertools.product([0x0a, 0x0d, 0x2028, 0x2029, ord('/'), ord('\\'), ord('['), ord(']')], repeat=3):
        yield 'escape', False, False, text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream', type=Path, default=Path.home() / 'code/3rd/ladybird')
    parser.add_argument('--build-dir', type=Path)
    parser.add_argument('--dependency-prefix', type=Path)
    parser.add_argument('--simdutf-prefix', type=Path, default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs', type=int, default=8)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'libjs/testdata/regexp-preparation.tsv')
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == UPSTREAM_COMMIT, f'expected pinned upstream {UPSTREAM_COMMIT}, got {revision}'
    build = (args.build_dir or upstream / 'Build/release').resolve()
    prefix = (args.dependency_prefix or build / 'vcpkg_installed/arm64-osx-dynamic').resolve()
    simdutf = args.simdutf_prefix.resolve()
    records = list(dict.fromkeys(f'{operation}\t{int(unicode)}\t{int(unicode_sets)}\t' +
                                (''.join(f'{unit:04x}' for unit in units) or '-')
                                for operation, unicode, unicode_sets, units in cases()))
    with tempfile.TemporaryDirectory(prefix='vox2-regexp-') as directory:
        temporary = Path(directory)
        source, binary = temporary / 'oracle.cpp', temporary / 'oracle'
        source.write_text(oracle_source(upstream))
        # ASan selects AK's upstream system-allocator branch without altering its
        # implementation, and checks ownership in the freshly compiled oracle.
        compiler = [os.environ.get('CXX', 'c++'), '-w', '-std=c++23', '-DLAGOM', '-fsanitize=address',
                    '-I' + str(simdutf / 'include'), '-I' + str(upstream), '-I' + str(upstream / 'Libraries'),
                    '-I' + str(build / 'Lagom'), '-I' + str(build / 'Lagom/Libraries'),
                    '-I' + str(prefix / 'include')]
        ak_cmake = (upstream / 'AK/CMakeLists.txt').read_text().split('if (WIN32)')[0]
        ak_files = re.findall(r'^    (\w+\.cpp)$', ak_cmake, re.M)
        # FFIHelpers is unrelated and needs libffi. Keep all other AK objects.
        ak_files.remove('FFIHelpers.cpp')
        ak_files.append('LexicalPathWindows.cpp' if sys.platform == 'win32' else 'LexicalPath.cpp')

        def compile_ak(name):
            output = temporary / (name + '.o')
            subprocess.run(compiler + ['-c', str(upstream / 'AK' / name), '-o', str(output)],
                           capture_output=True, text=True, check=True)
            return str(output)

        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            objects = list(pool.map(compile_ak, ak_files))
        link = compiler + [str(source), str(upstream / 'Libraries/LibJS/Runtime/ErrorTypes.cpp')] + objects
        if sys.platform == 'darwin':
            link += ['-Wl,-U,_ak_assertion_handler']  # The same optional handler as AK/CMakeLists.txt.
        for dependency in [simdutf, prefix]:
            link += ['-L' + str(dependency / 'lib'), '-Wl,-rpath,' + str(dependency / 'lib')]
        subprocess.run(link + ['-lsimdutf', '-lfmt', '-o', str(binary)],
                       capture_output=True, text=True, check=True)
        result = subprocess.run([str(binary)], input='\n'.join(records) + '\n',
                                capture_output=True, text=True, check=True)
    answers = result.stdout.splitlines()
    assert len(answers) == len(records)
    assert all(answer.startswith(record + '\t') for answer, record in zip(answers, records))
    args.output.write_text(f'# LibJS/AK {revision}; simdutf 9.1.0; native UTF-16 exact outputs\n'
                           '# operation, u, v, input units, status, result units or flag bits\n' +
                           '\n'.join(answers) + '\n')
    print(f'{len(answers)} exact RegExp preparation fixtures written to {args.output}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        raise SystemExit(error.returncode)
