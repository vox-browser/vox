#!/usr/bin/env python3
"""Observe actual Source lane destination views and AK byte copies.

This probes vector layout, not MemoryBuffer cage ownership or interpreter execution."""
import argparse
import hashlib
from pathlib import Path
import subprocess
from source_wasm_memory_store_probe import PIN

DRIVER = r'''
#include <stdio.h>
template<size_t N> void record(u64 low,u64 high) {
    for (u8 lane=0;lane<128/N;++lane) {
        u128 vector(low,high);
        Wasm::SourceProbeInstruction::MemoryAndLaneArgument memarg_and_lane{{0,0,Wasm::MemoryIndex(0)},lane};
        SOURCE_POINTER
        u128 replacement(high,low);
        ReadonlyBytes incoming{bit_cast<u8 const*>(&replacement),N/8};
        incoming.copy_to({dst,N/8});
        printf("%zu\t%u\t%016llx\t%016llx\t",N,lane,(unsigned long long)low,(unsigned long long)high);
        for (auto byte:incoming) printf("%02x",byte);
        printf("\t%016llx\t%016llx",(unsigned long long)vector.low(),(unsigned long long)vector.high());
        printf("\n");
    }
}
int main() {
    u64 const patterns[]={0,1,0x80,0xff,0x8000,0xffff,0x80000000,0xffffffff,
        0x8000000000000000ULL,0xffffffffffffffffULL,0x0123456789abcdefULL,
        0xfedcba9876543210ULL,0x7f800000,0xff800000,0x7fc54321,0xff854321,
        0x7ff0000000000000ULL,0xfff0000000000000ULL,
        0x7ff8000000004321ULL,0xfff0000000004321ULL};
    for (auto low:patterns) {auto high=~low;record<8>(low,high);record<16>(low,high);record<32>(low,high);record<64>(low,high);}
}
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,default=Path.home()/"code/3rd/ladybird")
    parser.add_argument("--output",type=Path,default=Path("Build/audit-fixes/source-wasm-memory-lane-load-probe"))
    parser.add_argument("--compiler",default="clang++")
    args=parser.parse_args();source=args.source.resolve();build=source/"Build/release"
    assert subprocess.check_output(["git","rev-parse","HEAD"],cwd=source,text=True).strip()==PIN
    subprocess.run(["git","diff","--exit-code",PIN,"--","AK","Libraries/LibWasm","Libraries/LibCore","Libraries/LibSync"],cwd=source,check=True)
    path=source/"Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"
    original=path.read_bytes()
    assert subprocess.check_output(["git","show",f"{PIN}:Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp"],cwd=source)==original
    text=original.decode();begin=text.index("bool BytecodeInterpreter::load_and_push_lane_n(")
    pointer=next(line.strip() for line in text[begin:text.index("\n}",begin)].splitlines() if "auto dst =" in line)
    assert pointer=="auto dst = bit_cast<u8*>(&vector) + memarg_and_lane.lane * N / 8;"
    types_path=source/"Libraries/LibWasm/Types.h";types=types_path.read_bytes()
    assert subprocess.check_output(["git","show",f"{PIN}:Libraries/LibWasm/Types.h"],cwd=source)==types
    types_text=types.decode();arg_begin=types_text.index("    struct MemoryArgument {");arg_end=types_text.index("    struct LaneIndex {",arg_begin)
    original_args=types_text[arg_begin:arg_end]
    index=next(line for line in types_text.splitlines() if line=="AK_TYPEDEF_DISTINCT_ORDERED_ID(u32, MemoryIndex);")
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    # This declaration-only shell encloses the two verbatim nested aggregates.
    # Full Types.h currently requires an unavailable generated LibSync export;
    # no Instruction object, configuration or interpreter is substituted here.
    declaration="#include <AK/BitCast.h>\n#include <AK/DistinctNumeric.h>\n#include <AK/Span.h>\n#include <AK/UFixedBigInt.h>\nnamespace Wasm {\n"+index+"\nstruct SourceProbeInstruction {\n"+original_args+"};\n}\n"
    (output/"source.cpp").write_text(declaration+DRIVER.replace("SOURCE_POINTER",pointer))
    reference=None
    for optimization in ["-O0","-O2"]:
        binary=output/f"source-{optimization[1:]}"
        subprocess.run([args.compiler,"-std=c++23",optimization,"-Wno-unqualified-std-cast-call","-Wno-user-defined-literals",
            f"-I{source}",f"-I{source/'Libraries'}",f"-I{build/'Lagom'}",f"-I{build/'Lagom/Libraries'}",
            str(output/"source.cpp"),str(build/"lib/liblagom-ak.0.0.0.dylib"),f"-Wl,-rpath,{build/'lib'}","-o",str(binary)],check=True)
        rows=subprocess.check_output([str(binary)],text=True);assert len(rows.splitlines())==600
        if reference is not None:assert rows==reference
        reference=rows
        print(f"Actual Source lane destination {optimization}: 600 exact native u128 lane copies PASS",flush=True)
    (output/"memory_lane_load.tsv").write_text(f"# Source {PIN}\n# BytecodeInterpreter.cpp sha256={hashlib.sha256(original).hexdigest()}\n# Types.h sha256={hashlib.sha256(types).hexdigest()}\n"+reference)

if __name__=="__main__":main()
