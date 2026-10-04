#!/usr/bin/env python3
"""Probe the pinned Source File.h byte-name overload's WTF-8 decoder.

File.h calls Utf16String::from_utf8(String const&), which reconstructs lone
surrogates by iterating Utf8View and applying UnicodeUtils::code_point_to_utf16.
This compiles those actual AK header helpers, without rewriting their logic.
It does not compile a full File/LibWeb object or its upstream runtime.
"""

import argparse
import hashlib
import pathlib
import subprocess


CPP = r"""#include <AK/CharacterTypes.h>
#include <AK/Utf8View.h>
#include <cstdio>
#include <cstdlib>
extern "C" void ak_verification_failed(char const* message) { std::fputs(message, stderr); std::abort(); }
void run(char const* label, unsigned char const* bytes, size_t size, char16_t const* expected, size_t count) {
    AK::Utf8View view {AK::StringView {reinterpret_cast<char const*>(bytes), size}};
    char16_t decoded[32] {};
    size_t length = 0;
    for (auto point : view)
        (void)AK::UnicodeUtils::code_point_to_utf16(point, [&](auto unit) { decoded[length++] = unit; });
    std::printf("%s: ", label);
    if (length != count) std::abort();
    for (size_t i = 0; i < length; ++i) {
        std::printf("%04x ", decoded[i]);
        if (decoded[i] != expected[i]) std::abort();
    }
    std::printf("\n");
}
int main() {
    unsigned char const name[] = {'n', 0xed, 0xa0, 0x80, 0, 0xed, 0xb0, 0x80, 0xf0, 0x9f, 0x98, 0x80, 'x'};
    char16_t const name_units[] = {u'n', 0xd800, 0, 0xdc00, 0xd83d, 0xde00, u'x'};
    run("raw name", name, sizeof(name), name_units, 7);
    unsigned char const invalid[] = {0xff, 0xfe};
    char16_t const two_bad[] = {0xfffd, 0xfffd};
    run("invalid leading", invalid, sizeof(invalid), two_bad, 2);
    unsigned char const broken[] = {0xe2, 0x28, 0xa1};
    char16_t const broken_units[] = {0xfffd, 0x28, 0xfffd};
    run("bad continuation", broken, sizeof(broken), broken_units, 3);
    unsigned char const short3[] = {0xe2, 0x82};
    run("truncated three", short3, sizeof(short3), two_bad, 2);
    unsigned char const short4[] = {0xf0, 0x9f, 0x98};
    char16_t const three_bad[] = {0xfffd, 0xfffd, 0xfffd};
    run("truncated four", short4, sizeof(short4), three_bad, 3);
    unsigned char const too_large[] = {0xf4, 0x90, 0x80, 0x80};
    char16_t const one_bad[] = {0xfffd};
    run("out of range", too_large, sizeof(too_large), one_bad, 1);
    unsigned char const fifth[] = {0xf8, 0x80};
    run("five byte leading", fifth, sizeof(fifth), two_bad, 2);
    unsigned char const overlong[] = {0xc0, 0xaf};
    char16_t const slash[] = {u'/'};
    run("overlong slash", overlong, sizeof(overlong), slash, 1);
    unsigned char const null[] = {0xe0, 0x80, 0x80};
    char16_t const nul[] = {0};
    run("overlong null", null, sizeof(null), nul, 1);
    char16_t const uppercase[] = {u'A', u'Z', 0xd800, 0, 0xdc00, 0x00c9, u'a', u'0'};
    char16_t const lowercase[] = {u'a', u'z', 0xd800, 0, 0xdc00, 0x00c9, u'a', u'0'};
    std::printf("ASCII lowercase: ");
    for (size_t i = 0; i < 8; ++i) {
        auto lower = AK::to_ascii_lowercase(uppercase[i]);
        std::printf("%04x ", lower);
        if (lower != lowercase[i]) std::abort();
    }
    std::printf("\n");
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--source-build", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-drag-wtf8-probe"))
    args = parser.parse_args()
    source = args.source.resolve()
    source_build = (args.source_build or source / "Build/release").resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    references = ["Libraries/LibWeb/FileAPI/File.h", "AK/Utf16String.h", "AK/Utf16StringData.cpp", "AK/StringBuilder.cpp", "AK/Utf8View.h", "AK/UnicodeUtils.h", "AK/Utf16View.cpp", "AK/CharacterTypes.h"]
    for relative in references:
        print(relative, hashlib.sha256((source / relative).read_bytes()).hexdigest(), flush=True)
    fixture = output / "probe.cpp"
    fixture.write_text(CPP)
    for optimize in ["-O0", "-O2"]:
        executable = output / ("probe" + optimize)
        subprocess.run(["clang++", "-std=c++23", optimize, "-Wno-unqualified-std-cast-call", "-Wno-user-defined-literals", "-Wno-unknown-warning-option", "-I" + str(source), "-I" + str(source_build / "Lagom"), str(fixture), "-o", str(executable)], check=True)
        print(optimize, flush=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
