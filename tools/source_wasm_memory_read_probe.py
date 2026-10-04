#!/usr/bin/env python3
"""Run the pinned BytecodeInterpreter read_value bodies verbatim."""

import argparse
import hashlib
from pathlib import Path
import subprocess

PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"

DRIVER = r'''
#include <bit>
#include <stdio.h>
#include <string.h>
template<typename T> void record(char const* name, u8 const* data, size_t offset) {
    Wasm::BytecodeInterpreter interpreter;
    auto value = interpreter.read_value<T>({data + offset, sizeof(T)});
    u64 low;
    u64 high = 0;
    if constexpr (IsSame<T, float>) low = (u64)(i64)std::bit_cast<i32>(value);
    else if constexpr (IsSame<T, double>) low = std::bit_cast<u64>(value);
    else if constexpr (IsSame<T, u128>) {low = value.low(); high = value.high();}
    else low = (u64)value;
    printf("%s\t%zu\t", name, offset);
    for (size_t i = 0; i < sizeof(T); ++i) printf("%02x", data[offset + i]);
    printf("\t%016llx\t%016llx\n", (unsigned long long)low, (unsigned long long)high);
}
int main(int argc, char**) {
    if (argc > 1) {
        Wasm::BytecodeInterpreter interpreter;
        (void)interpreter.read_value<u64>({});
        return 1;
    }
    u64 const patterns[] = {0, 1, 0x80, 0xff, 0x8000, 0xffff, 0x80000000,
        0xffffffff, 0x8000000000000000ULL, 0xffffffffffffffffULL,
        0x0123456789abcdefULL, 0xfedcba9876543210ULL,
        0x7f800000, 0xff800000, 0x7fc54321, 0xff854321,
        0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8000000004321ULL, 0xfff0000000004321ULL};
    alignas(16) u8 data[32];
    for (auto pattern : patterns) {
        for (size_t offset = 0; offset < 16; ++offset) {
            auto low = LittleEndian<u64>(pattern);
            auto high = LittleEndian<u64>(~pattern);
            memcpy(data + offset, &low, 8);
            memcpy(data + offset + 8, &high, 8);
            record<i8>("i8",data,offset); record<u8>("u8",data,offset);
            record<i16>("i16",data,offset); record<u16>("u16",data,offset);
            record<i32>("i32",data,offset); record<u32>("u32",data,offset);
            record<i64>("i64",data,offset); record<u64>("u64",data,offset);
            record<float>("f32",data,offset); record<double>("f64",data,offset);
            record<u128>("u128",data,offset);
        }
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=Path, default=Path("Build/audit-fixes/source-wasm-memory-read-probe"))
    parser.add_argument("--compiler", default="clang++")
    args = parser.parse_args()
    source = args.source.resolve()
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip() == PIN
    subprocess.run(["git", "diff", "--exit-code", PIN, "--", "AK"], cwd=source, check=True)
    path = source / "Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"
    original = path.read_bytes()
    assert subprocess.check_output(["git", "show", f"{PIN}:Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"], cwd=source) == original
    text = original.decode()
    begin = text.index("template<typename T>\nT BytecodeInterpreter::read_value(ReadonlyBytes data)")
    end = text.index("\nvoid InstructionStorage::add_chunk()", begin)
    excerpt = text[begin:end]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    build = source / "Build/release"
    generated = '#include <AK/Endian.h>\n#include <AK/Span.h>\n#include <AK/BitCast.h>\n#include <AK/UFixedBigInt.h>\n#include <string.h>\nnamespace Wasm {\nstruct BytecodeInterpreter {template<typename T> T read_value(ReadonlyBytes);};\n' + excerpt + '\n}\n' + DRIVER
    (output / "source.cpp").write_text(generated)
    reference = None
    for optimization in ["-O0", "-O2"]:
        binary = output / f"source-{optimization[1:]}"
        subprocess.run([args.compiler, "-std=c++23", optimization,
            "-Wno-unqualified-std-cast-call", "-Wno-user-defined-literals",
            f"-I{source}", f"-I{build / 'Lagom'}", str(output / "source.cpp"),
            str(build / "lib/liblagom-ak.0.0.0.dylib"), f"-Wl,-rpath,{build / 'lib'}", "-o", str(binary)], check=True)
        rows = subprocess.check_output([str(binary)], text=True)
        assert len(rows.splitlines()) == 3520
        if reference is not None:
            assert rows == reference
        reference = rows
        print(f"Actual Source read_value {optimization}: 3520 aligned/unaligned integer/float/u128 cases PASS", flush=True)
        fatal = subprocess.run([str(binary), "--short-span"], capture_output=True, text=True)
        (output / f"short-read-{optimization[1:]}.log").write_text(fatal.stdout + fatal.stderr)
        assert fatal.returncode < 0 and "sizeof(T) <= data.size()" in fatal.stderr
        print(f"Actual Source read_value {optimization}: short-span VERIFY abort PASS", flush=True)
    artifact = f"# Source {PIN}\n# BytecodeInterpreter.cpp sha256={hashlib.sha256(original).hexdigest()}\n" + reference
    (output / "memory_read.tsv").write_text(artifact)


if __name__ == "__main__":
    main()
