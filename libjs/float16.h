#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
/* BSD-2-Clause. AK/Types.h uses _Float16; Runtime/ArrayBuffer.h converts
 * directly between that type and double and copies its representation. V has
 * no binary16 scalar, so these two primitive representation operations stay
 * at the C boundary, with a binary64 fallback for compilers without _Float16.
 * All buffer and DataView algorithms are translated in V. */
#ifndef VOX2_LIBJS_FLOAT16_H
#define VOX2_LIBJS_FLOAT16_H
#include <stdint.h>
#include <string.h>
#if defined(__FLT16_MANT_DIG__) && defined(__FLT16_MAX_EXP__)
_Static_assert(__FLT16_MANT_DIG__ == 11 && __FLT16_MAX_EXP__ == 16,
    "LibJS requires IEEE binary16");
static inline uint16_t vox2_libjs_float16_bits(double number)
{
    _Float16 value = (_Float16)number;
    uint16_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}
static inline double vox2_libjs_float16_from_bits(uint16_t bits)
{
    _Float16 value;
    memcpy(&value, &bits, sizeof(value));
    return (double)value;
}
#else
#include <float.h>
_Static_assert(sizeof(double) == sizeof(uint64_t) && DBL_MANT_DIG == 53
    && DBL_MAX_EXP == 1024, "LibJS requires IEEE binary64");

static inline uint16_t vox2_libjs_float16_bits(double number)
{
    uint64_t bits;
    memcpy(&bits, &number, sizeof(bits));
    uint16_t sign = (uint16_t)((bits >> 48) & 0x8000);
    unsigned exponent = (unsigned)((bits >> 52) & 0x7ff);
    uint64_t fraction = bits & UINT64_C(0x000fffffffffffff);
    if (exponent == 0x7ff)
        return sign | 0x7c00 | (fraction ? 0x0200 : 0);
    int unbiased = (int)exponent - 1023;
    if (unbiased < -25)
        return sign;
    if (unbiased > 15)
        return sign | 0x7c00;

    /* Round directly from double, avoiding double rounding through float.
     * Subnormals use units of 2^-24; normals retain eleven significant bits. */
    uint64_t significand = fraction | (UINT64_C(1) << 52);
    unsigned shift = unbiased < -14 ? (unsigned)(28 - unbiased) : 42;
    uint64_t rounded = significand >> shift;
    uint64_t remainder = significand & ((UINT64_C(1) << shift) - 1);
    uint64_t halfway = UINT64_C(1) << (shift - 1);
    if (remainder > halfway || (remainder == halfway && (rounded & 1)))
        ++rounded;
    /* The retained leading bit supplies the first exponent unit. Carry also
     * handles subnormal-to-normal rounding and overflow to infinity. */
    unsigned base = unbiased < -14 ? 0 : (unsigned)(unbiased + 14) << 10;
    return sign | (uint16_t)(base + rounded);
}

static inline double vox2_libjs_float16_from_bits(uint16_t bits)
{
    uint64_t result = (uint64_t)(bits & 0x8000) << 48;
    unsigned exponent = (bits >> 10) & 0x1f;
    uint64_t fraction = bits & 0x03ff;
    if (exponent == 0x1f) {
        result |= UINT64_C(0x7ff0000000000000);
        if (fraction)
            result |= UINT64_C(0x0008000000000000) | (fraction << 42);
    } else if (exponent || fraction) {
        int unbiased = (int)exponent - 15;
        if (!exponent) {
            unbiased = -14;
            while (!(fraction & 0x0400)) {
                fraction <<= 1;
                --unbiased;
            }
            fraction &= 0x03ff;
        }
        result |= (uint64_t)(unbiased + 1023) << 52;
        result |= fraction << 42;
    }
    double number;
    memcpy(&number, &result, sizeof(number));
    return number;
}
#endif
#endif

#endif
