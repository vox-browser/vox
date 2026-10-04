#!/usr/bin/env python3
"""Generate exact scalar results from pinned LibWasm C++ operator records."""

import argparse
import hashlib
from pathlib import Path
import re
import subprocess

SOURCE_PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"
BINARY_NAMES = ("Divide", "Modulo", "BitRotateLeft", "BitRotateRight")
UNARY_NAMES = ("EqualsZero", "CountLeadingZeros", "CountTrailingZeros", "PopCount")
SHIFT_NAMES = ("BitShiftLeft", "BitShiftRight")
COMPARISON_NAMES = ("Equals", "NotEquals", "LessThan", "GreaterThan", "LessThanOrEquals", "GreaterThanOrEquals")

BINARY_DRIVER = r"""
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


UNARY_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void unary_result(char const* name, u64 bits, T value)
{
    printf("%s\t%016llx\t%d\n", name, (unsigned long long)bits, (int)value);
}
void run(u64 bits)
{
    using namespace Wasm::Operators;
    auto lhs32 = std::bit_cast<i32>((u32)bits);
    auto lhs64 = std::bit_cast<i64>(bits);
    unary_result("eqz_i32", bits, EqualsZero{}(lhs32));
    unary_result("eqz_i64", bits, EqualsZero{}(lhs64));
    unary_result("clz_i32", bits, CountLeadingZeros{}(lhs32));
    unary_result("clz_i64", bits, CountLeadingZeros{}(lhs64));
    unary_result("ctz_i32", bits, CountTrailingZeros{}(lhs32));
    unary_result("ctz_i64", bits, CountTrailingZeros{}(lhs64));
    unary_result("pop_i8", bits, PopCount{}(std::bit_cast<i8>((u8)bits)));
    unary_result("pop_i16", bits, PopCount{}(std::bit_cast<i16>((u16)bits)));
    unary_result("pop_i32", bits, PopCount{}(lhs32));
    unary_result("pop_i64", bits, PopCount{}(lhs64));
}
int main()
{
    u64 const inputs[] = {0, 1, 2, 7, 0xfffffffffffffff9ULL,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xffffffffffffffffULL};
    for (auto bits : inputs)
        run(bits);
    for (unsigned bit = 0; bit < 64; ++bit) {
        u64 single = u64(1) << bit;
        run(single);
        run(~single);
    }
    for (unsigned bits = 0; bits < 256; ++bits)
        unary_result("pop_i8", bits, Wasm::Operators::PopCount{}(std::bit_cast<i8>((u8)bits)));
}
"""


SHIFT_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void shift_result(char const* name, u64 lhs, u64 rhs, T value)
{
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)value);
}
void run(u64 rhs)
{
    using namespace Wasm::Operators;
    u64 const inputs[] = {0, 1, 2, 7, 0xfffffffffffffff9ULL,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xffffffffffffffffULL};
    for (auto lhs : inputs) {
        shift_result("shl_u32", lhs, rhs, BitShiftLeft{}((u32)lhs, (u32)rhs));
        shift_result("shl_u64", lhs, rhs, BitShiftLeft{}(lhs, rhs));
        shift_result("shr_i32", lhs, rhs, BitShiftRight{}(std::bit_cast<i32>((u32)lhs), std::bit_cast<i32>((u32)rhs)));
        shift_result("shr_u32", lhs, rhs, BitShiftRight{}((u32)lhs, (u32)rhs));
        shift_result("shr_i64", lhs, rhs, BitShiftRight{}(std::bit_cast<i64>(lhs), std::bit_cast<i64>(rhs)));
        shift_result("shr_u64", lhs, rhs, BitShiftRight{}(lhs, rhs));
    }
}
int main()
{
    for (u64 rhs = 0; rhs <= 65; ++rhs)
        run(rhs);
    u64 const extra[] = {127, 128, 129, 255, 256, 0x7fffffffULL,
        0x80000000ULL, 0xffffffffULL, 0x100000000ULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xfffffffffffffff9ULL, 0xffffffffffffffffULL};
    for (auto rhs : extra)
        run(rhs);
}
"""


COMPARISON_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void comparison_result(char const* name, u64 lhs, u64 rhs, T value)
{
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)value);
}
int main()
{
    using namespace Wasm::Operators;
    u64 const inputs[] = {0, 1, 2, 7, 0xfffffffffffffff9ULL,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xffffffffffffffffULL};
    for (auto lhs : inputs) {
        for (auto rhs : inputs) {
            auto sl32 = std::bit_cast<i32>((u32)lhs);
            auto sr32 = std::bit_cast<i32>((u32)rhs);
            auto sl64 = std::bit_cast<i64>(lhs);
            auto sr64 = std::bit_cast<i64>(rhs);
            comparison_result("eq_i32", lhs, rhs, Equals{}(sl32, sr32));
            comparison_result("eq_i64", lhs, rhs, Equals{}(sl64, sr64));
            comparison_result("ne_i32", lhs, rhs, NotEquals{}(sl32, sr32));
            comparison_result("ne_i64", lhs, rhs, NotEquals{}(sl64, sr64));
            comparison_result("lt_i32", lhs, rhs, LessThan{}(sl32, sr32));
            comparison_result("lt_u32", lhs, rhs, LessThan{}((u32)lhs, (u32)rhs));
            comparison_result("lt_i64", lhs, rhs, LessThan{}(sl64, sr64));
            comparison_result("lt_u64", lhs, rhs, LessThan{}(lhs, rhs));
            comparison_result("gt_i32", lhs, rhs, GreaterThan{}(sl32, sr32));
            comparison_result("gt_u32", lhs, rhs, GreaterThan{}((u32)lhs, (u32)rhs));
            comparison_result("gt_i64", lhs, rhs, GreaterThan{}(sl64, sr64));
            comparison_result("gt_u64", lhs, rhs, GreaterThan{}(lhs, rhs));
            comparison_result("le_i32", lhs, rhs, LessThanOrEquals{}(sl32, sr32));
            comparison_result("le_u32", lhs, rhs, LessThanOrEquals{}((u32)lhs, (u32)rhs));
            comparison_result("le_i64", lhs, rhs, LessThanOrEquals{}(sl64, sr64));
            comparison_result("le_u64", lhs, rhs, LessThanOrEquals{}(lhs, rhs));
            comparison_result("ge_i32", lhs, rhs, GreaterThanOrEquals{}(sl32, sr32));
            comparison_result("ge_u32", lhs, rhs, GreaterThanOrEquals{}((u32)lhs, (u32)rhs));
            comparison_result("ge_i64", lhs, rhs, GreaterThanOrEquals{}(sl64, sr64));
            comparison_result("ge_u64", lhs, rhs, GreaterThanOrEquals{}(lhs, rhs));
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
    parser.add_argument("--family", choices=("binary", "unary", "shift", "comparison"), default="binary")
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
    families = {
        "binary": (BINARY_NAMES, BINARY_DRIVER, 3264, "integer_operators.tsv"),
        "unary": (UNARY_NAMES, UNARY_DRIVER, 1656, "unary_integer_operators.tsv"),
        "shift": (SHIFT_NAMES, SHIFT_DRIVER, 5760, "shift_integer_operators.tsv"),
        "comparison": (COMPARISON_NAMES, COMPARISON_DRIVER, 2880, "comparison_integer_operators.tsv"),
    }
    names, driver, expected_count, filename = families[args.family]
    if args.family == "comparison":
        macro = re.search(r"^#define DEFINE_BINARY_OPERATOR\(Name, operation\).*?(?=^DEFINE_BINARY_OPERATOR\(Equals)", source, re.MULTILINE | re.DOTALL)
        if macro is None:
            parser.error("Missing exact Source binary operator macro")
        excerpts.append(macro.group(0))
        hashes.append(f"# DEFINE_BINARY_OPERATOR sha256={hashlib.sha256(macro.group(0).encode()).hexdigest()}")
    for name in names:
        expression = (r"^DEFINE_BINARY_OPERATOR\(" + name + r", .*?\);" if args.family == "comparison"
                      else r"^struct " + name + r" \{.*?^};")
        match = re.search(expression, source, re.MULTILINE | re.DOTALL)
        if match is None:
            parser.error(f"Missing exact Source operator record: {name}")
        text = match.group(0)
        excerpts.append(text)
        hashes.append(f"# {name} sha256={hashlib.sha256(text.encode()).hexdigest()}")
    if args.family == "comparison":
        excerpts.append("#undef DEFINE_BINARY_OPERATOR")
    # Only the selected verbatim Source records are needed. This avoids unrelated
    # LibWasm Types/LibSync generated exports; AK headers remain the actual source.
    generated = "#include <limits.h>\n#include <AK/Checked.h>\n#include <AK/BuiltinWrappers.h>\n#include <AK/Error.h>\n#include <AK/StringView.h>\n"
    generated += "namespace Wasm::Operators {\n" + "\n\n".join(excerpts) + "\n}\n" + driver
    work = repo / "Build/audit-fixes" / ("wasm-integer-operators" if args.family == "binary"
                                       else "wasm-" + args.family + "-integer-operators")
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
    assert len(results.splitlines()) == expected_count
    output = args.output or repo / "webassembly/fixtures" / filename
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(f"# Source {SOURCE_PIN}\n" + "\n".join(hashes) + "\n" + results)
    print(f"Generated {expected_count} exact Source {args.family} integer operator cases: {output}")


if __name__ == "__main__":
    main()
