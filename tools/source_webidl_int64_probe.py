#!/usr/bin/env python3
"""Compile the pinned Source's numeric LongLong conversion path unchanged.

The input is already a primitive Number after ToNumber. EnforceRange and Clamp
are No, so the Source enters steps 8–12. This probe copies those exact steps,
integer_part and floating JS::modulo, including the final native signed cast.
It does not approximate the helper with a JS BigInt/int64 conversion.
"""

import argparse
import hashlib
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-webidl-int64-probe"))
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    webidl = (source / "Libraries/LibWeb/WebIDL/AbstractOperations.cpp").read_text()
    operations = (source / "Libraries/LibJS/Runtime/AbstractOperations.h").read_text()
    integer_part = webidl.split("double integer_part(double n)", 1)[1].split("// https://webidl.spec.whatwg.org/#abstract-opdef-converttoint", 1)[0]
    numeric = webidl.split("JS::ThrowCompletionOr<T> convert_to_int", 1)[1].split("template WEB_API", 1)[0]
    numeric = numeric[numeric.index("    // 8. If x is NaN") :]
    modulo = operations.split("template<Arithmetic T, Arithmetic U>", 1)[1].split("auto modulo(Crypto::BigInteger", 1)[0]
    exact = "double integer_part(double n)" + integer_part + "template<Arithmetic T, Arithmetic U>" + modulo + numeric
    print("Source numeric bodies SHA256:", hashlib.sha256(exact.encode()).hexdigest(), flush=True)
    cpp = """#include <AK/Assertions.h>
#include <AK/Math.h>
#include <AK/NumericLimits.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
using namespace AK;
using std::floor;
using std::fmod;
using std::isfinite;
using std::isinf;
using std::isnan;
extern "C" void ak_verification_failed(char const* message) { std::fputs(message, stderr); std::abort(); }
namespace JS {
template<Arithmetic T, Arithmetic U>""" + modulo + """}
namespace Web::WebIDL {
using AK::abs;
double integer_part(double n)""" + integer_part + """template<Integral T>
T source_numeric_conversion(double x)
{
""" + numeric + """}
int main()
{
    double inputs[] = {-7, -1, -4096, 45.9, 123.9, -0.0, std::numeric_limits<double>::quiet_NaN(), std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity(), 18446744073709551616.0};
    for (double x : inputs)
        std::printf("%.17g -> %lld\\n", x, static_cast<long long>(Web::WebIDL::source_numeric_conversion<i64>(x)));
}
"""
    fixture = output / "source_numeric_conversion.cpp"
    fixture.write_text(cpp)
    for optimize in ["-O0", "-O2"]:
        executable = output / ("probe" + optimize)
        subprocess.run(["clang++", "-std=c++23", "-Wno-unqualified-std-cast-call", "-Wno-user-defined-literals", optimize, "-I" + str(source), str(fixture), "-o", str(executable)], check=True)
        print(optimize, flush=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
