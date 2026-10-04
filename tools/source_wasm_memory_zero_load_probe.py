#!/usr/bin/env python3
"""Probe actual Source zero vector and native low-byte copy destination.

This observes actual AK vector/Span bytes, not Source cage or VM execution.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
from source_wasm_memory_store_probe import PIN

DRIVER = r'''
#include <AK/BitCast.h>
#include <AK/Span.h>
#include <AK/UFixedBigInt.h>
#include <stdio.h>
template<size_t N> void record(u64 low,u64 high) {
    SOURCE_ZERO
    u128 incoming(low,high);
    ReadonlyBytes bytes{bit_cast<u8 const*>(&incoming),N/8};
    bytes.copy_to({bit_cast<u8*>(&vector),N/8});
    printf("%zu\t",N);
    for(auto byte:bytes) printf("%02x",byte);
    printf("\t%016llx\t%016llx\n",(unsigned long long)vector.low(),(unsigned long long)vector.high());
}
int main() {
    u64 const patterns[]={0,1,0x80,0xff,0x8000,0xffff,0x80000000,0xffffffff,
        0x8000000000000000ULL,0xffffffffffffffffULL,0x0123456789abcdefULL,
        0xfedcba9876543210ULL,0x7f800000,0xff800000,0x7fc54321,0xff854321,
        0x7ff0000000000000ULL,0xfff0000000000000ULL,
        0x7ff8000000004321ULL,0xfff0000000004321ULL};
    for(auto low:patterns) {record<32>(low,~low);record<64>(low,~low);}
}
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,default=Path.home()/"code/3rd/ladybird")
    parser.add_argument("--output",type=Path,default=Path("Build/audit-fixes/source-wasm-memory-zero-load-probe"))
    parser.add_argument("--compiler",default="clang++")
    args=parser.parse_args();source=args.source.resolve();build=source/"Build/release"
    assert subprocess.check_output(["git","rev-parse","HEAD"],cwd=source,text=True).strip()==PIN
    subprocess.run(["git","diff","--exit-code",PIN,"--","AK","Libraries/LibWasm"],cwd=source,check=True)
    path=source/"Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp";original=path.read_bytes()
    assert subprocess.check_output(["git","show",f"{PIN}:Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"],cwd=source)==original
    text=original.decode();begin=text.index("bool BytecodeInterpreter::load_and_push_zero_n(")
    body=text[begin:text.index("\n}",begin)]
    zero=next(line.strip() for line in body.splitlines() if "u128 vector =" in line)
    assert zero=="u128 vector = 0;"
    assert "memory->data().copy_to(instance_address, { bit_cast<u8*>(&vector), N / 8 });" in body
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    (output/"source.cpp").write_text(DRIVER.replace("SOURCE_ZERO",zero))
    reference=None
    for optimization in ["-O0","-O2"]:
        binary=output/f"source-{optimization[1:]}"
        subprocess.run([args.compiler,"-std=c++23",optimization,"-Wno-unqualified-std-cast-call","-Wno-user-defined-literals",
            f"-I{source}",f"-I{source/'Libraries'}",f"-I{build/'Lagom'}",f"-I{build/'Lagom/Libraries'}",
            str(output/"source.cpp"),str(build/"lib/liblagom-ak.0.0.0.dylib"),f"-Wl,-rpath,{build/'lib'}","-o",str(binary)],check=True)
        rows=subprocess.check_output([str(binary)],text=True);assert len(rows.splitlines())==40
        if reference is not None:assert rows==reference
        reference=rows
        print(f"Actual Source zero vector {optimization}: 40 exact native low-byte copies PASS",flush=True)
    (output/"memory_zero_load.tsv").write_text(f"# Source {PIN}\n# BytecodeInterpreter.cpp sha256={hashlib.sha256(original).hexdigest()}\n"+reference)

if __name__=="__main__":main()
