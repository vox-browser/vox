#!/usr/bin/env python3
"""Generate exact scalar results from pinned LibWasm C++ operator records."""

import argparse
import hashlib
from pathlib import Path
import re
import subprocess

SOURCE_PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"
NAMES = ("Divide", "Modulo", "BitRotateLeft", "BitRotateRight")

DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void result(char const* name, u64 lhs, u64 rhs, T value)
{
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)value);
}
template<typename T> void checked(char const* name, u64 lhs, u64 rhs, T value)
{
    if (value.is_error()) {
        auto reason = value.error();
        printf("%s\t%016llx\t%016llx\terror:%.*s\n", name,
            (unsigned long long)lhs, (unsigned long long)rhs,
            (int)reason.length(), reason.characters_without_null_termination());
    } else {
        result(name, lhs, rhs, value.value());
    }
}
int main()
{
    using namespace Wasm::Operators;
    u64 const inputs[] = {0, 1, 2, 7, 0xfffffffffffffff9ULL,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xffffffffffffffffULL};
    u64 const divisors[] = {0, 1, 2, 3, 7, 31, 32, 33, 63, 64, 65, 127,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL, 0x7fffffffffffffffULL,
        0x8000000000000000ULL, 0xffffffffffffffffULL};
    u64 const shifts[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
        14, 15, 16, 17, 18, 19, 20, 31, 32, 33, 63, 64, 65, 127,
        0xffffffffULL, 0xffffffffffffffffULL, 0x100000000ULL, 0x8000000000000000ULL};
    for (auto lhs : inputs) {
        for (auto rhs : divisors) {
            auto sl32 = std::bit_cast<i32>((u32)lhs);
            auto sr32 = std::bit_cast<i32>((u32)rhs);
            auto sl64 = std::bit_cast<i64>(lhs);
            auto sr64 = std::bit_cast<i64>(rhs);
            checked("div_i32", lhs, rhs, Divide{}(sl32, sr32));
            checked("div_u32", lhs, rhs, Divide{}((u32)lhs, (u32)rhs));
            checked("div_i64", lhs, rhs, Divide{}(sl64, sr64));
            checked("div_u64", lhs, rhs, Divide{}(lhs, rhs));
            checked("mod_i32", lhs, rhs, Modulo{}(sl32, sr32));
            checked("mod_u32", lhs, rhs, Modulo{}((u32)lhs, (u32)rhs));
            checked("mod_i64", lhs, rhs, Modulo{}(sl64, sr64));
            checked("mod_u64", lhs, rhs, Modulo{}(lhs, rhs));
        }
        for (auto rhs : shifts) {
            result("rotl_u32", lhs, rhs, BitRotateLeft{}((u32)lhs, (u32)rhs));
            result("rotr_u32", lhs, rhs, BitRotateRight{}((u32)lhs, (u32)rhs));
            result("rotl_u64", lhs, rhs, BitRotateLeft{}(lhs, rhs));
            result("rotr_u64", lhs, rhs, BitRotateRight{}(lhs, rhs));
        }
    }
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--compiler", default="clang++")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    upstream = args.upstream.resolve()
    actual_pin = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=upstream, text=True).strip()
    if actual_pin != SOURCE_PIN:
        parser.error(f"Source pin differs: expected {SOURCE_PIN}, got {actual_pin}")
    header = upstream / "Libraries/LibWasm/AbstractMachine/Operators.h"
    source = header.read_text()
    excerpts = []
    hashes = []
    for name in NAMES:
        match = re.search(r"^struct " + name + r" \{.*?^};", source, re.MULTILINE | re.DOTALL)
        if match is None:
            parser.error(f"Missing exact Source operator record: {name}")
        text = match.group(0)
        excerpts.append(text)
        hashes.append(f"# {name} sha256={hashlib.sha256(text.encode()).hexdigest()}")
    # Only the four verbatim Source records are needed. This avoids unrelated
    # LibWasm Types/LibSync generated exports; AK headers remain the actual source.
    generated = "#include <limits.h>\n#include <AK/Checked.h>\n#include <AK/Error.h>\n#include <AK/StringView.h>\n"
    generated += "namespace Wasm::Operators {\n" + "\n\n".join(excerpts) + "\n}\n" + DRIVER
    work = repo / "Build/audit-fixes/wasm-integer-operators"
    work.mkdir(parents=True, exist_ok=True)
    cpp = work / "source.cpp"
    binary = work / "source"
    cpp.write_text(generated)
    build = (args.build_dir or upstream / "Build/release").resolve()
    ak_library = build / "lib/liblagom-ak.0.0.0.dylib"
    command = [args.compiler, "-std=c++23", "-Wno-unqualified-std-cast-call",
               "-Wno-unknown-warning-option", "-Wno-user-defined-literals",
               f"-I{upstream}", f"-I{build / 'Lagom'}", str(cpp), str(ak_library),
               f"-Wl,-rpath,{build / 'lib'}", "-o", str(binary)]
    subprocess.run(command, check=True)
    results = subprocess.check_output([str(binary)], text=True)
    assert len(results.splitlines()) == 3264
    output = args.output or repo / "webassembly/fixtures/integer_operators.tsv"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f"# Source {SOURCE_PIN}\n" + "\n".join(hashes) + "\n" + results)
    print(f"Generated 3264 exact Source integer operator cases: {output}")


if __name__ == "__main__":
    main()
