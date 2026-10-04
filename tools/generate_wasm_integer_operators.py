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
ARITHMETIC_NAMES = ("Add", "Subtract", "Multiply", "BitAnd", "BitOr", "BitXor")
FLOAT_ARITHMETIC_NAMES = ("Add", "Subtract", "Multiply", "Divide")
FLOAT_EXTREMA_NAMES = ("Minimum", "Maximum", "CopySign")
FLOAT_UNARY_NAMES = ("Absolute", "Negate", "Ceil", "Floor", "Truncate", "NearbyIntegral", "SquareRoot")
FLOAT_WIDTH_NAMES = ("Promote", "Demote")
INTEGER_WIDTH_NAMES = ("Wrap", "Extend", "SignExtend")
REINTERPRET_NAMES = ("Reinterpret",)
INTEGER_FLOAT_NAMES = ("Convert",)
FLOAT_TRUNCATE_NAMES = ("CheckedTruncate",)

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


ARITHMETIC_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void arithmetic_result(char const* name, u64 lhs, u64 rhs, T value)
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
            arithmetic_result("add_u32", lhs, rhs, Add{}((u32)lhs, (u32)rhs));
            arithmetic_result("add_u64", lhs, rhs, Add{}((u64)lhs, (u64)rhs));
            arithmetic_result("sub_u32", lhs, rhs, Subtract{}((u32)lhs, (u32)rhs));
            arithmetic_result("sub_u64", lhs, rhs, Subtract{}((u64)lhs, (u64)rhs));
            arithmetic_result("mul_u32", lhs, rhs, Multiply{}((u32)lhs, (u32)rhs));
            arithmetic_result("mul_u64", lhs, rhs, Multiply{}((u64)lhs, (u64)rhs));
            arithmetic_result("and_i32", lhs, rhs, BitAnd{}(std::bit_cast<i32>((u32)lhs), std::bit_cast<i32>((u32)rhs)));
            arithmetic_result("and_i64", lhs, rhs, BitAnd{}(std::bit_cast<i64>((u64)lhs), std::bit_cast<i64>((u64)rhs)));
            arithmetic_result("or_i32", lhs, rhs, BitOr{}(std::bit_cast<i32>((u32)lhs), std::bit_cast<i32>((u32)rhs)));
            arithmetic_result("or_i64", lhs, rhs, BitOr{}(std::bit_cast<i64>((u64)lhs), std::bit_cast<i64>((u64)rhs)));
            arithmetic_result("xor_i32", lhs, rhs, BitXor{}(std::bit_cast<i32>((u32)lhs), std::bit_cast<i32>((u32)rhs)));
            arithmetic_result("xor_i64", lhs, rhs, BitXor{}(std::bit_cast<i64>((u64)lhs), std::bit_cast<i64>((u64)rhs)));
        }
    }
}
"""


FLOAT_COMPARISON_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void float_comparison_result(char const* name, u64 lhs, u64 rhs, T value)
{
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)value);
}
int main()
{
    using namespace Wasm::Operators;
    u32 const inputs32[] = {0, 0x80000000U, 0x3f800000U, 0xbf800000U,
        1, 0x007fffffU, 0x00800000U, 0x7f7fffffU, 0x7f800000U, 0xff800000U,
        0x7fc12345U, 0xffc54321U, 0x7f812345U, 0xff854321U, 0x3f000000U, 0xbf000000U};
    u64 const inputs64[] = {0, 0x8000000000000000ULL, 0x3ff0000000000000ULL,
        0xbff0000000000000ULL, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x7fefffffffffffffULL, 0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8123456789abcULL, 0xfff8543210abcdefULL,
        0x7ff0123456789abcULL, 0xfff0543210abcdefULL,
        0x3fe0000000000000ULL, 0xbfe0000000000000ULL};
    for (auto lhs : inputs32) {
        for (auto rhs : inputs32) {
            auto left = std::bit_cast<float>(lhs);
            auto right = std::bit_cast<float>(rhs);
            float_comparison_result("eq_f32", lhs, rhs, Equals{}(left, right));
            float_comparison_result("ne_f32", lhs, rhs, NotEquals{}(left, right));
            float_comparison_result("lt_f32", lhs, rhs, LessThan{}(left, right));
            float_comparison_result("gt_f32", lhs, rhs, GreaterThan{}(left, right));
            float_comparison_result("le_f32", lhs, rhs, LessThanOrEquals{}(left, right));
            float_comparison_result("ge_f32", lhs, rhs, GreaterThanOrEquals{}(left, right));
        }
    }
    for (auto lhs : inputs64) {
        for (auto rhs : inputs64) {
            auto left = std::bit_cast<double>(lhs);
            auto right = std::bit_cast<double>(rhs);
            float_comparison_result("eq_f64", lhs, rhs, Equals{}(left, right));
            float_comparison_result("ne_f64", lhs, rhs, NotEquals{}(left, right));
            float_comparison_result("lt_f64", lhs, rhs, LessThan{}(left, right));
            float_comparison_result("gt_f64", lhs, rhs, GreaterThan{}(left, right));
            float_comparison_result("le_f64", lhs, rhs, LessThanOrEquals{}(left, right));
            float_comparison_result("ge_f64", lhs, rhs, GreaterThanOrEquals{}(left, right));
        }
    }
}
"""


FLOAT_ARITHMETIC_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void float_arithmetic_result(char const* name, u64 lhs, u64 rhs, T value)
{
    u64 bits;
    if constexpr (sizeof(T) == sizeof(u32))
        bits = std::bit_cast<u32>(value);
    else
        bits = std::bit_cast<u64>(value);
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)bits);
}
int main()
{
    using namespace Wasm::Operators;
    u32 const inputs32[] = {0, 0x80000000U, 0x3f800000U, 0xbf800000U,
        1, 0x007fffffU, 0x00800000U, 0x7f7fffffU, 0x7f800000U, 0xff800000U,
        0x7fc12345U, 0xffc54321U, 0x7f812345U, 0xff854321U, 0x3f000000U, 0xbf000000U};
    u64 const inputs64[] = {0, 0x8000000000000000ULL, 0x3ff0000000000000ULL,
        0xbff0000000000000ULL, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x7fefffffffffffffULL, 0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8123456789abcULL, 0xfff8543210abcdefULL,
        0x7ff0123456789abcULL, 0xfff0543210abcdefULL,
        0x3fe0000000000000ULL, 0xbfe0000000000000ULL};
    for (auto lhs : inputs32) {
        for (auto rhs : inputs32) {
            auto left = std::bit_cast<float>(lhs);
            auto right = std::bit_cast<float>(rhs);
            float_arithmetic_result("add_f32", lhs, rhs, Add{}(left, right));
            float_arithmetic_result("sub_f32", lhs, rhs, Subtract{}(left, right));
            float_arithmetic_result("mul_f32", lhs, rhs, Multiply{}(left, right));
            float_arithmetic_result("div_f32", lhs, rhs, Divide{}(left, right));
        }
    }
    for (auto lhs : inputs64) {
        for (auto rhs : inputs64) {
            auto left = std::bit_cast<double>(lhs);
            auto right = std::bit_cast<double>(rhs);
            float_arithmetic_result("add_f64", lhs, rhs, Add{}(left, right));
            float_arithmetic_result("sub_f64", lhs, rhs, Subtract{}(left, right));
            float_arithmetic_result("mul_f64", lhs, rhs, Multiply{}(left, right));
            float_arithmetic_result("div_f64", lhs, rhs, Divide{}(left, right));
        }
    }
}
"""

FLOAT_EXTREMA_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void float_extrema_result(char const* name, u64 lhs, u64 rhs, T value)
{
    u64 bits;
    if constexpr (sizeof(T) == sizeof(u32))
        bits = std::bit_cast<u32>(value);
    else
        bits = std::bit_cast<u64>(value);
    printf("%s\t%016llx\t%016llx\t%016llx\n", name,
        (unsigned long long)lhs, (unsigned long long)rhs, (unsigned long long)bits);
}
int main()
{
    using namespace Wasm::Operators;
    u32 const inputs32[] = {0, 0x80000000U, 0x3f800000U, 0xbf800000U,
        1, 0x007fffffU, 0x00800000U, 0x7f7fffffU, 0x7f800000U, 0xff800000U,
        0x7fc12345U, 0xffc54321U, 0x7f812345U, 0xff854321U, 0x3f000000U, 0xbf000000U};
    u64 const inputs64[] = {0, 0x8000000000000000ULL, 0x3ff0000000000000ULL,
        0xbff0000000000000ULL, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x7fefffffffffffffULL, 0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8123456789abcULL, 0xfff8543210abcdefULL,
        0x7ff0123456789abcULL, 0xfff0543210abcdefULL,
        0x3fe0000000000000ULL, 0xbfe0000000000000ULL};
    for (auto lhs : inputs32) {
        for (auto rhs : inputs32) {
            auto left = std::bit_cast<float>(lhs);
            auto right = std::bit_cast<float>(rhs);
            float_extrema_result("min_f32", lhs, rhs, Minimum{}(left, right));
            float_extrema_result("max_f32", lhs, rhs, Maximum{}(left, right));
            float_extrema_result("copysign_f32", lhs, rhs, CopySign{}(left, right));
        }
    }
    for (auto lhs : inputs64) {
        for (auto rhs : inputs64) {
            auto left = std::bit_cast<double>(lhs);
            auto right = std::bit_cast<double>(rhs);
            float_extrema_result("min_f64", lhs, rhs, Minimum{}(left, right));
            float_extrema_result("max_f64", lhs, rhs, Maximum{}(left, right));
            float_extrema_result("copysign_f64", lhs, rhs, CopySign{}(left, right));
        }
    }
}
"""

FLOAT_UNARY_DRIVER = r"""
#include <bit>
#include <fenv.h>
#include <stdio.h>
#include <stdint.h>

template<typename T> void float_unary_result(char const* mode, char const* name, u64 input, T value)
{
    u64 bits;
    if constexpr (sizeof(T) == sizeof(u32))
        bits = std::bit_cast<u32>(value);
    else
        bits = std::bit_cast<u64>(value);
    printf("%s/%s\t%016llx\t%016llx\n", mode, name,
        (unsigned long long)input, (unsigned long long)bits);
}
int main()
{
    using namespace Wasm::Operators;
    u32 const inputs32[] = {0, 0x80000000U, 0x3f800000U, 0xbf800000U,
        1, 0x007fffffU, 0x00800000U, 0x7f7fffffU, 0x7f800000U, 0xff800000U,
        0x7fc12345U, 0xffc54321U, 0x7f812345U, 0xff854321U, 0x3f000000U, 0xbf000000U,
        0x3fc00000U, 0xbfc00000U, 0x40200000U, 0xc0200000U, 0x40600000U, 0xc0600000U,
        0x40800000U, 0xc0800000U, 0xff7fffffU, 0x80000001U, 0x4b000001U, 0xcb000001U};
    u64 const inputs64[] = {0, 0x8000000000000000ULL, 0x3ff0000000000000ULL,
        0xbff0000000000000ULL, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x7fefffffffffffffULL, 0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8123456789abcULL, 0xfff8543210abcdefULL,
        0x7ff0123456789abcULL, 0xfff0543210abcdefULL,
        0x3fe0000000000000ULL, 0xbfe0000000000000ULL,
        0x3ff8000000000000ULL, 0xbff8000000000000ULL,
        0x4004000000000000ULL, 0xc004000000000000ULL,
        0x400c000000000000ULL, 0xc00c000000000000ULL,
        0x4010000000000000ULL, 0xc010000000000000ULL,
        0xffefffffffffffffULL, 0x8000000000000001ULL,
        0x4330000000000001ULL, 0xc330000000000001ULL};
    char const* const names[] = {"nearest", "down", "up", "zero"};
    int const modes[] = {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO};
    auto old_rounding = fegetround();
    for (unsigned mode = 0; mode < 4; ++mode) {
        if (fesetround(modes[mode]))
            return 1;
        for (auto bits : inputs32) {
            auto value = std::bit_cast<float>(bits);
            float_unary_result(names[mode], "abs_f32", bits, Absolute{}(value));
            float_unary_result(names[mode], "neg_f32", bits, Negate{}(value));
            float_unary_result(names[mode], "ceil_f32", bits, Ceil{}(value));
            float_unary_result(names[mode], "floor_f32", bits, Floor{}(value));
            float_unary_result(names[mode], "trunc_f32", bits, Truncate{}(value));
            float_unary_result(names[mode], "nearest_f32", bits, NearbyIntegral{}(value));
            float_unary_result(names[mode], "sqrt_f32", bits, SquareRoot{}(value));
        }
        for (auto bits : inputs64) {
            auto value = std::bit_cast<double>(bits);
            float_unary_result(names[mode], "abs_f64", bits, Absolute{}(value));
            float_unary_result(names[mode], "neg_f64", bits, Negate{}(value));
            float_unary_result(names[mode], "ceil_f64", bits, Ceil{}(value));
            float_unary_result(names[mode], "floor_f64", bits, Floor{}(value));
            float_unary_result(names[mode], "trunc_f64", bits, Truncate{}(value));
            float_unary_result(names[mode], "nearest_f64", bits, NearbyIntegral{}(value));
            float_unary_result(names[mode], "sqrt_f64", bits, SquareRoot{}(value));
        }
    }
    return fesetround(old_rounding);
}
"""



FLOAT_WIDTH_DRIVER = r"""
#include <bit>
#include <fenv.h>
#include <stdio.h>
#include <stdint.h>

template<typename T> void float_width_result(char const* mode, char const* name, u64 input, T value)
{
    u64 bits;
    if constexpr (sizeof(T) == sizeof(u32))
        bits = std::bit_cast<u32>(value);
    else
        bits = std::bit_cast<u64>(value);
    printf("%s/%s\t%016llx\t%016llx\n", mode, name,
        (unsigned long long)input, (unsigned long long)bits);
}
int main()
{
    using namespace Wasm::Operators;
    u32 const inputs32[] = {0, 0x80000000U, 0x3f800000U, 0xbf800000U,
        1, 0x007fffffU, 0x00800000U, 0x7f7fffffU, 0x7f800000U, 0xff800000U,
        0x7fc12345U, 0xffc54321U, 0x7f812345U, 0xff854321U, 0x3f000000U, 0xbf000000U,
        0x3fc00000U, 0xbfc00000U, 0x40200000U, 0xc0200000U, 0x40600000U, 0xc0600000U,
        0x40800000U, 0xc0800000U, 0xff7fffffU, 0x80000001U, 0x4b000001U, 0xcb000001U};
    u64 const inputs64[] = {0, 0x8000000000000000ULL, 0x3ff0000000000000ULL,
        0xbff0000000000000ULL, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x7fefffffffffffffULL, 0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8123456789abcULL, 0xfff8543210abcdefULL,
        0x7ff0123456789abcULL, 0xfff0543210abcdefULL,
        0x3fe0000000000000ULL, 0xbfe0000000000000ULL,
        0x3ff8000000000000ULL, 0xbff8000000000000ULL,
        0x4004000000000000ULL, 0xc004000000000000ULL,
        0x400c000000000000ULL, 0xc00c000000000000ULL,
        0x4010000000000000ULL, 0xc010000000000000ULL,
        0xffefffffffffffffULL, 0x8000000000000001ULL,
        0x4330000000000001ULL, 0xc330000000000001ULL,
        0x3ff0000010000000ULL, 0xbff0000010000000ULL,
        0x3ff0000030000000ULL, 0xbff0000030000000ULL,
        0x47efffffe0000000ULL, 0xc7efffffe0000000ULL,
        0x47effffff0000000ULL, 0xc7effffff0000000ULL,
        0x36a0000000000000ULL, 0xb6a0000000000000ULL,
        0x3690000000000000ULL, 0xb690000000000000ULL};
    char const* const names[] = {"nearest", "down", "up", "zero"};
    int const modes[] = {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO};
    auto old_rounding = fegetround();
    for (unsigned mode = 0; mode < 4; ++mode) {
        if (fesetround(modes[mode]))
            return 1;
        for (auto bits : inputs32) {
            auto value = std::bit_cast<float>(bits);
            float_width_result(names[mode], "promote_f32", bits, Promote{}(value));
        }
        for (auto bits : inputs64) {
            auto value = std::bit_cast<double>(bits);
            float_width_result(names[mode], "demote_f64", bits, Demote{}(value));
        }
    }
    return fesetround(old_rounding);
}
"""


INTEGER_WIDTH_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void integer_width_result(char const* name, u64 input, T value)
{
    printf("%s\t%016llx\t%016llx\n", name, (unsigned long long)input,
        (unsigned long long)value);
}
void run_integer_width(u64 bits)
{
    using namespace Wasm::Operators;
    auto lhs32 = std::bit_cast<i32>((u32)bits);
    auto lhs64 = std::bit_cast<i64>(bits);
    integer_width_result("wrap_i64_i32", bits, Wrap<i32>{}(lhs64));
    integer_width_result("extend_i32_i64", bits, Extend<i64>{}(lhs32));
    integer_width_result("extend_u32_i64", bits, Extend<i64>{}((u32)bits));
    integer_width_result("sign_i8_i32", bits, SignExtend<i8>{}(lhs32));
    integer_width_result("sign_i16_i32", bits, SignExtend<i16>{}(lhs32));
    integer_width_result("sign_i8_i64", bits, SignExtend<i8>{}(lhs64));
    integer_width_result("sign_i16_i64", bits, SignExtend<i16>{}(lhs64));
    integer_width_result("sign_i32_i64", bits, SignExtend<i32>{}(lhs64));
}
int main()
{
    u64 const inputs[] = {0, 1, 2, 7, 0xfffffffffffffff9ULL,
        0x7fffffffULL, 0x80000000ULL, 0xffffffffULL,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xfffffffffffffffeULL, 0xffffffffffffffffULL,
        0x7f, 0x80, 0xff, 0x7fff, 0x8000, 0xffff};
    for (auto bits : inputs)
        run_integer_width(bits);
    for (unsigned bit = 0; bit < 64; ++bit) {
        u64 single = u64(1) << bit;
        run_integer_width(single);
        run_integer_width(~single);
    }
    for (unsigned bits = 0; bits < 256; ++bits)
        run_integer_width(0xa5a5deadbeef0000ULL | bits);
}
"""


REINTERPRET_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>

template<typename T> void reinterpret_result(char const* name, u64 input, T value)
{
    u64 output;
    if constexpr (IsSame<T, float>)
        output = std::bit_cast<u32>(value);
    else if constexpr (IsSame<T, double>)
        output = std::bit_cast<u64>(value);
    else
        output = (u64)value;
    printf("%s\t%016llx\t%016llx\n", name, (unsigned long long)input,
        (unsigned long long)output);
}
void run_reinterpret(u64 bits)
{
    using namespace Wasm::Operators;
    reinterpret_result("reinterpret_f32_i32", bits, Reinterpret<i32>{}(std::bit_cast<float>((u32)bits)));
    reinterpret_result("reinterpret_f64_i64", bits, Reinterpret<i64>{}(std::bit_cast<double>(bits)));
    reinterpret_result("reinterpret_i32_f32", bits, Reinterpret<float>{}(std::bit_cast<i32>((u32)bits)));
    reinterpret_result("reinterpret_i64_f64", bits, Reinterpret<double>{}(std::bit_cast<i64>(bits)));
}
int main()
{
    u64 const inputs[] = {0, 1, 0x7fffff, 0x800000, 0x80000000,
        0x7f800000, 0x7fc54321, 0x7f854321, 0xff854321,
        0x7ff0000000000000ULL, 0xfff0000000000000ULL,
        0x7ff8000000004321ULL, 0x7ff0000000004321ULL,
        0xfff0000000004321ULL, 0xffffffffffffffffULL, 0x8000000000000000ULL};
    for (auto bits : inputs)
        run_reinterpret(bits);
    for (unsigned bit = 0; bit < 64; ++bit) {
        u64 single = u64(1) << bit;
        run_reinterpret(single);
        run_reinterpret(~single);
    }
}
"""


INTEGER_FLOAT_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>
#include <fenv.h>
#pragma STDC FENV_ACCESS ON

template<typename T> void integer_float_result(char const* mode, char const* name, u64 input, T value)
{
    u64 output;
    if constexpr (IsSame<T, float>)
        output = std::bit_cast<u32>(value);
    else
        output = std::bit_cast<u64>(value);
    printf("%s/%s\t%016llx\t%016llx\n", mode, name,
        (unsigned long long)input, (unsigned long long)output);
}
void run_integer_float(char const* mode, u64 bits)
{
    using namespace Wasm::Operators;
    auto lhs32 = std::bit_cast<i32>((u32)bits);
    auto lhs64 = std::bit_cast<i64>(bits);
    integer_float_result(mode, "convert_i32_f32", bits, Convert<float>{}(lhs32));
    integer_float_result(mode, "convert_u32_f32", bits, Convert<float>{}((u32)bits));
    integer_float_result(mode, "convert_i64_f32", bits, Convert<float>{}(lhs64));
    integer_float_result(mode, "convert_u64_f32", bits, Convert<float>{}(bits));
    integer_float_result(mode, "convert_i32_f64", bits, Convert<double>{}(lhs32));
    integer_float_result(mode, "convert_u32_f64", bits, Convert<double>{}((u32)bits));
    integer_float_result(mode, "convert_i64_f64", bits, Convert<double>{}(lhs64));
    integer_float_result(mode, "convert_u64_f64", bits, Convert<double>{}(bits));
}
int main()
{
    int const modes[] = {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO};
    char const* names[] = {"nearest", "down", "up", "zero"};
    u64 const inputs[] = {0, 1, 2, 0x7fffffff, 0x80000000, 0xffffffff,
        0x7fffffffffffffffULL, 0x8000000000000000ULL,
        0xffffffffffffffffULL, 0xfffffffffffffffeULL};
    for (unsigned mode = 0; mode < 4; ++mode) {
        if (fesetround(modes[mode]))
            return 1;
        for (auto bits : inputs)
            run_integer_float(names[mode], bits);
        for (unsigned bit = 0; bit < 64; ++bit) {
            u64 single = u64(1) << bit;
            run_integer_float(names[mode], single);
            run_integer_float(names[mode], single - 1);
            run_integer_float(names[mode], single + 1);
            run_integer_float(names[mode], ~single);
        }
    }
    return fesetround(FE_TONEAREST);
}
"""


FLOAT_TRUNCATE_DRIVER = r"""
#include <bit>
#include <stdio.h>
#include <stdint.h>
#include <math.h>

template<typename T> void truncation_result(char const* name, u64 input, T value)
{
    if (value.is_error()) {
        auto reason = value.error();
        printf("%s\t%016llx\terror:%.*s\n", name, (unsigned long long)input,
            (int)reason.length(), reason.characters_without_null_termination());
    } else {
        printf("%s\t%016llx\t%016llx\n", name, (unsigned long long)input,
            (unsigned long long)value.value());
    }
}
void run_truncation(float value)
{
    using namespace Wasm::Operators;
    u64 bits=std::bit_cast<u32>(value);
    truncation_result("truncate_f32_i32", bits, CheckedTruncate<i32>{}(value));
    truncation_result("truncate_f32_u32", bits, CheckedTruncate<u32>{}(value));
    truncation_result("truncate_f32_i64", bits, CheckedTruncate<i64>{}(value));
    truncation_result("truncate_f32_u64", bits, CheckedTruncate<u64>{}(value));
}
void run_truncation(double value)
{
    using namespace Wasm::Operators;
    u64 bits=std::bit_cast<u64>(value);
    truncation_result("truncate_f64_i32", bits, CheckedTruncate<i32>{}(value));
    truncation_result("truncate_f64_u32", bits, CheckedTruncate<u32>{}(value));
    truncation_result("truncate_f64_i64", bits, CheckedTruncate<i64>{}(value));
    truncation_result("truncate_f64_u64", bits, CheckedTruncate<u64>{}(value));
}
int main()
{
    u32 const f32_inputs[] = {0,0x80000000,1,0x80000001,0x3f000000,0xbf000000,
        0x7f7fffff,0xff7fffff,0x7f800000,0xff800000,0x7fc54321,0xffc54321,
        0x7f854321,0xff854321};
    u64 const f64_inputs[] = {0,0x8000000000000000ULL,1,0x8000000000000001ULL,
        0x3fe0000000000000ULL,0xbfe0000000000000ULL,0x3fffffffffffffffULL,
        0xbfffffffffffffffULL,0x7fefffffffffffffULL,0xffefffffffffffffULL,
        0x7ff0000000000000ULL,0xfff0000000000000ULL,0x7ff8000000004321ULL,
        0xfff8000000004321ULL,0x7ff0000000004321ULL,0xfff0000000004321ULL,
        0x3ff0000000000000ULL,0xbff0000000000000ULL};
    for (auto bits : f32_inputs) run_truncation(std::bit_cast<float>(bits));
    for (auto bits : f64_inputs) run_truncation(std::bit_cast<double>(bits));
    double const bounds[]={0,-2147483648.0,2147483648.0,4294967296.0,
        -9223372036854775808.0,9223372036854775808.0,18446744073709551616.0};
    for (auto bound : bounds) {
        float f=(float)bound;
        run_truncation(nextafterf(f,-INFINITY));
        run_truncation(f);
        run_truncation(nextafterf(f,INFINITY));
        run_truncation(nextafter(bound,-INFINITY));
        run_truncation(bound);
        run_truncation(nextafter(bound,INFINITY));
    }
    for (auto value : {-1.9,-0.9,0.9,1.9}) {
        run_truncation((float)value);
        run_truncation(value);
    }
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--compiler", default="clang++")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--family", choices=("binary", "unary", "shift", "comparison", "arithmetic", "floating", "float_arithmetic", "float_extrema", "float_unary", "float_width", "integer_width", "reinterpret", "integer_float", "float_truncate"), default="binary")
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
        "arithmetic": (ARITHMETIC_NAMES, ARITHMETIC_DRIVER, 1728, "arithmetic_integer_operators.tsv"),
        "floating": (COMPARISON_NAMES, FLOAT_COMPARISON_DRIVER, 3072, "comparison_float_operators.tsv"),
        "float_arithmetic": (FLOAT_ARITHMETIC_NAMES, FLOAT_ARITHMETIC_DRIVER, 2048, "arithmetic_float_operators.tsv"),
        "float_extrema": (FLOAT_EXTREMA_NAMES, FLOAT_EXTREMA_DRIVER, 1536, "extrema_float_operators.tsv"),
        "float_unary": (FLOAT_UNARY_NAMES, FLOAT_UNARY_DRIVER, 1568, "unary_float_operators.tsv"),
        "float_width": (FLOAT_WIDTH_NAMES, FLOAT_WIDTH_DRIVER, 272, "width_float_operators.tsv"),
        "integer_width": (INTEGER_WIDTH_NAMES, INTEGER_WIDTH_DRIVER, 3216, "width_integer_operators.tsv"),
        "reinterpret": (REINTERPRET_NAMES, REINTERPRET_DRIVER, 576, "reinterpret_operators.tsv"),
        "integer_float": (INTEGER_FLOAT_NAMES, INTEGER_FLOAT_DRIVER, 8512, "convert_integer_float_operators.tsv"),
        "float_truncate": (FLOAT_TRUNCATE_NAMES, FLOAT_TRUNCATE_DRIVER, 328, "checked_truncate_operators.tsv"),
    }
    names, driver, expected_count, filename = families[args.family]
    if args.family in ("comparison", "arithmetic", "floating", "float_arithmetic"):
        macro = re.search(r"^#define DEFINE_BINARY_OPERATOR\(Name, operation\).*?(?=^DEFINE_BINARY_OPERATOR\(Equals)", source, re.MULTILINE | re.DOTALL)
        if macro is None:
            parser.error("Missing exact Source binary operator macro")
        excerpts.append(macro.group(0))
        hashes.append(f"# DEFINE_BINARY_OPERATOR sha256={hashlib.sha256(macro.group(0).encode()).hexdigest()}")
    for name in names:
        expression = (r"^DEFINE_BINARY_OPERATOR\(" + name + r", .*?\);" if name != "Divide" and args.family in ("comparison", "arithmetic", "floating", "float_arithmetic")
                      else r"^struct " + name + r" \{.*?^};")
        if args.family in ("integer_width", "reinterpret", "integer_float", "float_truncate"):
            expression = r"^template<typename [^\n]+>\nstruct " + name + r" \{.*?^};"
        match = re.search(expression, source, re.MULTILINE | re.DOTALL)
        if match is None:
            parser.error(f"Missing exact Source operator record: {name}")
        text = match.group(0)
        excerpts.append(text)
        hashes.append(f"# {name} sha256={hashlib.sha256(text.encode()).hexdigest()}")
    if args.family in ("comparison", "arithmetic", "floating", "float_arithmetic"):
        excerpts.append("#undef DEFINE_BINARY_OPERATOR")
    if args.family == "float_truncate":
        checked_header = (upstream / "AK/Checked.h").read_bytes()
        hashes.append(f"# AK/Checked.h sha256={hashlib.sha256(checked_header).hexdigest()}")
    # Only the selected verbatim Source records are needed. This avoids unrelated
    # LibWasm Types/LibSync generated exports; AK headers remain the actual source.
    generated = "#include <limits.h>\n#include <AK/Checked.h>\n#include <AK/BuiltinWrappers.h>\n#include <AK/Error.h>\n#include <AK/StringView.h>\n"
    if args.family in ("float_extrema", "float_unary", "float_width", "float_truncate"):
        generated += "#include <AK/Math.h>\n#include <math.h>\n"
    generated += "namespace Wasm::Operators {\n" + "\n\n".join(excerpts) + "\n}\n" + driver
    work = repo / "Build/audit-fixes" / ("wasm-integer-operators" if args.family == "binary"
                                       else "wasm-floating-comparison-operators" if args.family == "floating"
                                       else "wasm-floating-arithmetic-operators" if args.family == "float_arithmetic"
                                       else "wasm-floating-extrema-operators" if args.family == "float_extrema"
                                       else "wasm-floating-unary-operators" if args.family == "float_unary"
                                       else "wasm-floating-width-operators" if args.family == "float_width"
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
    print(f"Generated {expected_count} exact Source {args.family} operator cases: {output}")


if __name__ == "__main__":
    main()
