#!/usr/bin/env python3
"""Probe pinned AK's actual unchecked ASCII UTF16 ownership and projections.

Compile exact unchanged ASCII constructors with real current AK headers and
kmalloc.cpp's system-allocator instrumentation branch. The existing AK library
supplies verification and unreachable non-ASCII dependencies only. Current
fly-string destruction definitions are compiled unchanged from Source too.
The probe checks the raw ASCII span used by to_utf8's direct ASCII arm; it
does not compile or exercise that complete String-returning method.
No translated implementation or replacement conversion algorithm is compiled.
"""

import argparse
import hashlib
import pathlib
import subprocess

SOURCE_PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"

CPP = r"""#include <AK/Utf16String.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
void require(bool value) { if (!value) std::abort(); }
void run(char const* label, unsigned char const* bytes, size_t size) {
    auto string = AK::Utf16String::from_ascii_without_validation({bytes, size});
    require(string.has_ascii_storage());
    require(string.has_short_ascii_storage() == (size <= AK::Detail::MAX_SHORT_STRING_BYTE_COUNT));
    require(string.length_in_code_units() == size);
    require(string.length_in_code_points() == size);
    auto projection = string.ascii_view().bytes();
    require(projection.size() == size);
    require(!size || std::memcmp(projection.data(), bytes, size) == 0);
    for (size_t index = 0; index < size; ++index)
        require(string.code_unit_at(index) == static_cast<char16_t>(static_cast<char>(bytes[index])));
    auto copy = string;
    require(copy.has_ascii_storage() && copy.ascii_view().bytes() == projection);
    std::printf("%s: bytes=%zu short=%d units", label, size, string.has_short_ascii_storage());
    for (size_t index = 0; index < size; ++index)
        std::printf(" %04x", string.code_unit_at(index));
    std::puts("");
}
int main() {
    std::printf("plain-char-signed=%d short-limit=%zu\n", std::numeric_limits<char>::is_signed, AK::Detail::MAX_SHORT_STRING_BYTE_COUNT);
    unsigned char empty[1] {};
    run("empty", empty, 0);
    unsigned char short_bytes[] = {'A', 0, 0x7f, 0x80, 0xff, 0xed, 0xa0};
    run("inline unchecked", short_bytes, sizeof(short_bytes));
    unsigned char long_bytes[] = {'A', 0, 0x7f, 0x80, 0xff, 0xed, 0xa0, 0x80};
    run("heap unchecked", long_bytes, sizeof(long_bytes));
    unsigned char all[256];
    for (size_t index = 0; index < 256; ++index) all[index] = static_cast<unsigned char>(index);
    run("all byte values", all, 256);
    auto owned = AK::Utf16String::from_ascii_without_validation({all, 256});
    all[0] = 'Z';
    auto bytes = owned.ascii_view().bytes();
    require(owned.code_unit_at(0) == 0 && bytes[0] == 0);
    auto copy = owned;
    owned = AK::Utf16String {};
    require(copy.length_in_code_units() == 256 && copy.code_unit_at(255) == static_cast<char16_t>(static_cast<char>(0xff)));
    std::puts("input mutation and copied owner survive: PASS");
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--source-build", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-utf16-ascii-probe"))
    args = parser.parse_args()
    source = args.source.resolve()
    source_head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if source_head != SOURCE_PIN:
        raise SystemExit(f"Source HEAD {source_head} differs from required pin {SOURCE_PIN}")
    print("Source HEAD", source_head, flush=True)
    source_build = (args.source_build or source / "Build/release").resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    files = ["AK/Utf16String.h", "AK/Utf16String.cpp", "AK/Utf16StringBase.h", "AK/Utf16StringData.h", "AK/Utf16StringData.cpp", "AK/Utf16View.h", "AK/Utf16View.cpp", "AK/StringData.h", "AK/kmalloc.cpp", "AK/kmalloc.h", "AK/Utf16FlyString.cpp", "Libraries/LibWeb/Infra/SerializedURL.h", "Libraries/LibWeb/FileAPI/FileReader.cpp"]
    for relative in files:
        print(relative, hashlib.sha256((source / relative).read_bytes()).hexdigest(), flush=True)
    ak_library = source_build / "lib/liblagom-ak.0.0.0.dylib"
    print("AK dependency library", hashlib.sha256(ak_library.read_bytes()).hexdigest(), flush=True)
    vcpkg = source_build / "vcpkg_installed/arm64-osx-dynamic"
    fixture = output / "probe.cpp"
    fixture.write_text(CPP)
    # Select whole, unchanged Source functions because the existing Source
    # build predates current StringBuilder ABI and replacement-simdutf helpers.
    def function(relative, declaration):
        contents = (source / relative).read_text()
        start = contents.index(declaration)
        opening = contents.index("{", start)
        depth = 1
        position = opening + 1
        while depth:
            depth += (contents[position] == "{") - (contents[position] == "}")
            position += 1
        body = contents[start:position]
        print(declaration, hashlib.sha256(body.encode()).hexdigest(), flush=True)
        return body
    constructors = output / "ascii-constructors.cpp"
    macro = next(line for line in (source / "AK/Utf16StringData.cpp").read_text().splitlines() if line.startswith("#define VERIFY_UTF16_LENGTH"))
    constructors.write_text("#include <AK/Utf16String.h>\n#include <AK/TypedTransfer.h>\n" + macro + "\nnamespace AK {\n" + function("AK/Utf16String.cpp", "Utf16String Utf16String::from_ascii_without_validation") + "\n}\nnamespace AK::Detail {\n" + function("AK/Utf16StringData.cpp", "NonnullRefPtr<Utf16StringData> Utf16StringData::create_uninitialized(") + "\n" + function("AK/Utf16StringData.cpp", "NonnullRefPtr<Utf16StringData> Utf16StringData::from_ascii(") + "\n}\n")
    fly_prefix = (source / "AK/Utf16FlyString.cpp").read_text().split("\ntemplate<typename ViewType>", 1)[0]
    fly_unit = output / "Utf16FlyString-destroy.cpp"
    fly_unit.write_text(fly_prefix + "\n}\n")
    print("exact fly-string destruction prefix", hashlib.sha256(fly_prefix.encode()).hexdigest(), flush=True)
    units = [constructors, fly_unit, source / "AK/kmalloc.cpp"]
    for optimize in ["-O0", "-O2"]:
        executable = output / ("probe" + optimize)
        subprocess.run(["clang++", "-std=c++23", optimize, "-Wno-unqualified-std-cast-call", "-Wno-user-defined-literals", "-Wno-unknown-warning-option", "-D__SANITIZE_ADDRESS__=1", "-I" + str(source), "-I" + str(source_build / "Lagom"), "-I" + str(vcpkg / "include"), str(fixture), *map(str, units), str(ak_library), "-L" + str(vcpkg / "lib"), "-lsimdutf", "-Wl,-rpath," + str(source_build / "lib"), "-Wl,-rpath," + str(vcpkg / "lib"), "-o", str(executable)], check=True)
        print(optimize, flush=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
