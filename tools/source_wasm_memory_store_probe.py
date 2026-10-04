#!/usr/bin/env python3
"""Observe pinned ConvertToRaw templates and original endian byte layout."""

import argparse
import hashlib
from pathlib import Path
import subprocess

PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"

DRIVER = r'''
#include <stdio.h>
template<typename P> P operand(u64 low,u64 high) {
    if constexpr (IsSame<P,i32>) return bit_cast<i32>((u32)low);
    else if constexpr (IsSame<P,i64>) return bit_cast<i64>(low);
    else if constexpr (IsSame<P,float>) return bit_cast<float>((u32)low);
    else if constexpr (IsSame<P,double>) return bit_cast<double>(low);
    else return u128(low,high);
}
template<typename P,typename S> void record(char const* name,u64 low,u64 high) {
    auto raw = Wasm::ConvertToRaw<S>{}(operand<P>(low,high));
    printf("%s\t%016llx\t%016llx\t",name,(unsigned long long)low,(unsigned long long)high);
    auto const* bytes = reinterpret_cast<u8 const*>(&raw);
    for (size_t i=0;i<sizeof(raw);++i) printf("%02x",bytes[i]);
    printf("\n");
}
int main() {
    u64 const patterns[]={0,1,0x80,0xff,0x8000,0xffff,0x80000000,0xffffffff,
        0x8000000000000000ULL,0xffffffffffffffffULL,0x0123456789abcdefULL,
        0xfedcba9876543210ULL,0x7f800000,0xff800000,0x7fc54321,0xff854321,
        0x7ff0000000000000ULL,0xfff0000000000000ULL,
        0x7ff8000000004321ULL,0xfff0000000004321ULL};
    for (auto low:patterns) {
        auto high=~low;
        record<i32,i32>("i32_i32",low,high);record<i64,i64>("i64_i64",low,high);
        record<float,float>("f32_f32",low,high);record<double,double>("f64_f64",low,high);
        record<i32,i8>("i32_i8",low,high);record<i32,i16>("i32_i16",low,high);
        record<i64,i8>("i64_i8",low,high);record<i64,i16>("i64_i16",low,high);
        record<i64,i32>("i64_i32",low,high);record<u128,u128>("u128_u128",low,high);
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=Path, default=Path("Build/audit-fixes/source-wasm-memory-store-probe"))
    parser.add_argument("--compiler", default="clang++")
    args = parser.parse_args()
    source = args.source.resolve()
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip() == PIN
    subprocess.run(["git", "diff", "--exit-code", PIN, "--", "AK"], cwd=source, check=True)
    path = source / "Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"
    original = path.read_bytes()
    assert subprocess.check_output(["git", "show", f"{PIN}:Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"], cwd=source) == original
    text = original.decode()
    begin = text.index("template<typename T>\nstruct ConvertToRaw")
    end = text.index("// Memory address operands", begin)
    excerpt = text[begin:end]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    build = source / "Build/release"
    generated = '#include <AK/Endian.h>\n#include <AK/BitCast.h>\n#include <AK/UFixedBigInt.h>\nnamespace Wasm {\n' + excerpt + '\n}\n' + DRIVER
    (output / "source.cpp").write_text(generated)
    reference = None
    for optimization in ["-O0", "-O2"]:
        binary = output / f"source-{optimization[1:]}"
        subprocess.run([args.compiler, "-std=c++23", optimization,
            "-Wno-unqualified-std-cast-call", "-Wno-user-defined-literals",
            "-Wno-unknown-warning-option", f"-I{source}", f"-I{build / 'Lagom'}",
            str(output / "source.cpp"), str(build / "lib/liblagom-ak.0.0.0.dylib"),
            f"-Wl,-rpath,{build / 'lib'}", "-o", str(binary)], check=True)
        rows = subprocess.check_output([str(binary)], text=True)
        assert len(rows.splitlines()) == 200
        if reference is not None:
            assert rows == reference
        reference = rows
        print(f"Actual Source ConvertToRaw {optimization}: 200 numeric/float/u128 byte-layout observations PASS", flush=True)
    artifact = f"# Source {PIN}\n# BytecodeInterpreter.cpp sha256={hashlib.sha256(original).hexdigest()}\n" + reference
    (output / "memory_store.tsv").write_text(artifact)


if __name__ == "__main__":
    main()
