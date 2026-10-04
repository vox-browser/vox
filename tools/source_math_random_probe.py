#!/usr/bin/env python3
"""Run unchanged pinned AK RNG bodies with deterministic test-only entropy.

Only the external fill_with_random boundary is supplied by the fixture. The
constructor, splitmix, advance and double projection are extracted verbatim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"
SEEDS = [(0, 0), (1, 2), (2**64 - 1, 0), (0, 2**64 - 1),
         (0x0123456789abcdef, 0xfedcba9876543210),
         (0x8000000000000000, 0x8000000000000001)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=Path, default=Path("Build/audit-fixes/source-math-random-probe"))
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--entropy-header", type=Path, help="Check the translated native entropy ABI on this host")
    args = parser.parse_args()
    source = args.source.resolve()
    head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if head != PIN:
        raise SystemExit(f"Source HEAD {head} differs from required pin {PIN}")
    print("Source HEAD", head, flush=True)
    for name in ["AK/Random.cpp", "AK/Random.h", "AK/Platform.h", "AK/Windows.h",
                 "Libraries/LibJS/Runtime/MathObject.cpp"]:
        print(name, hashlib.sha256((source / name).read_bytes()).hexdigest(), flush=True)
    contents = (source / "AK/Random.cpp").read_text()

    def extract(declaration):
        start = contents.index(declaration)
        opening = contents.index("{", start)
        position, depth = opening + 1, 1
        while depth:
            depth += (contents[position] == "{") - (contents[position] == "}")
            position += 1
        result = contents[start:position]
        print(declaration, hashlib.sha256(result.encode()).hexdigest(), flush=True)
        return result

    bodies = "\n".join(extract(name) for name in [
        "XorShift128PlusRNG::XorShift128PlusRNG()", "double XorShift128PlusRNG::get()",
        "u64 XorShift128PlusRNG::splitmix64", "u64 XorShift128PlusRNG::advance()"])
    pairs = ",".join("{%dULL,%dULL}" % pair for pair in SEEDS)
    cpp = r'''#include <AK/Random.h>
#include <bit>
#include <cstdio>
#include <cstring>
#include <cstdlib>
static uint64_t seeds[2];
static size_t draws;
namespace AK {
void fill_with_random(Bytes bytes) {
    if (draws >= 2 || bytes.size() != sizeof(uint64_t)) std::abort();
    std::memcpy(bytes.data(), &seeds[draws++], sizeof(uint64_t));
}
''' + bodies + r'''
}
int main() {
    uint64_t cases[][2] = {''' + pairs + r'''};
    std::puts("[");
    for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); ++index) {
        std::memcpy(seeds, cases[index], sizeof(seeds)); draws = 0;
        AK::XorShift128PlusRNG rng;
        if (draws != 2) std::abort();
        std::printf("{\"seeds\":[%llu,%llu],\"bits\":[", (unsigned long long)seeds[0], (unsigned long long)seeds[1]);
        for (size_t item = 0; item < 8; ++item) {
            double value = rng.get();
            if (!(value >= 0 && value < 1)) std::abort();
            std::printf("%s%llu", item ? "," : "", (unsigned long long)std::bit_cast<uint64_t>(value));
        }
        std::printf("]}%s\n", index + 1 < sizeof(cases) / sizeof(cases[0]) ? "," : "");
    }
    std::puts("]");
}
'''
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    unit = output / "source-rng.cpp"
    unit.write_text(cpp)
    library = source / "Build/release/lib/liblagom-ak.0.0.0.dylib"
    print("assertion dependency", hashlib.sha256(library.read_bytes()).hexdigest(), flush=True)
    results = []
    for optimize in ["-O0", "-O2"]:
        executable = output / ("source-rng" + optimize)
        subprocess.run(["clang++", "-std=c++23", optimize, "-Wno-user-defined-literals",
                        "-Wno-unqualified-std-cast-call", "-I" + str(source), str(unit),
                        str(library), "-Wl,-rpath," + str(library.parent), "-o", str(executable)], check=True)
        result = subprocess.check_output([str(executable)], text=True)
        (output / ("cases" + optimize + ".json")).write_text(result)
        results.append(json.loads(result))
        print(optimize, "PASS: constructor consumes two native-width draws;", len(results[-1]) * 8, "exact outputs", flush=True)
    if results[0] != results[1]:
        raise SystemExit("optimization outputs differ")
    if args.fixture:
        # Preserve all 64 bits independently of JSON consumer number precision.
        fixture = [{key: [str(value) for value in values] for key, values in case.items()}
                   for case in results[0]]
        args.fixture.write_text(json.dumps(fixture, indent=2) + "\n")
    if args.entropy_header:
        header = args.entropy_header.resolve()
        print("translated native entropy ABI", hashlib.sha256(header.read_bytes()).hexdigest(), flush=True)
        # Both the unchanged Source CSPRNG body and native ABI call the same
        # test-only external OS entry point. No generator algorithm is copied.
        native_unit = output / "entropy-abi.cpp"
        native_unit.write_text(r'''#include <AK/Error.h>
#include <AK/Platform.h>
#include <cstdint>
#include <cstdlib>
#include <cstring>
static size_t draws;
static uint64_t seeds[] = {0x0123456789abcdefULL, 0xfedcba9876543210ULL};
static void test_arc4random_buf(void* buffer, size_t size) {
    if (size != sizeof(uint64_t) || draws >= 2) std::abort();
    std::memcpy(buffer, &seeds[draws++], size);
}
#define arc4random_buf test_arc4random_buf
''' + extract("static inline ErrorOr<void> csprng(") + '\n#include "' + str(header) + r'''"
int main() {
    uint64_t first, second;
    if (csprng(&first, sizeof(first)).is_error() || csprng(&second, sizeof(second)).is_error()) std::abort();
    if (draws != 2 || first != seeds[0] || second != seeds[1]) std::abort();
    draws = 0;
    first = vox_ak_random_seed_u64(); second = vox_ak_random_seed_u64();
    if (draws != 2 || first != seeds[0] || second != seeds[1]) std::abort();
}
''')
        for optimize in ["-O0", "-O2"]:
            executable = output / ("entropy-abi" + optimize)
            subprocess.run(["clang++", "-std=c++23", optimize, "-Wno-user-defined-literals",
                            "-Wno-unqualified-std-cast-call", "-I" + str(source), str(native_unit),
                            str(library), "-Wl,-rpath," + str(library.parent), "-o", str(executable)], check=True)
            subprocess.run([str(executable)], check=True)
            print(optimize, "native Source/ABI two-draw byte representation PASS", flush=True)


if __name__ == "__main__":
    main()
