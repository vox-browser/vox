/* Check both the compiler's binary16 path and the portable fallback. */
#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#ifdef VOX_TEST_NO_FLOAT16
#undef __FLT16_MANT_DIG__
#undef __FLT16_MAX_EXP__
#undef _Float16
#define _Float16 vox_test_unsupported_float16
#endif
#include "float16.h"

/* An independent arithmetic decoder supplies exact expected binary64 values. */
static double reference(uint16_t bits)
{
    unsigned exponent = (bits >> 10) & 31;
    unsigned fraction = bits & 1023;
    double value;
    if (exponent == 31)
        value = fraction ? NAN : INFINITY;
    else if (!exponent)
        value = ldexp((double)fraction, -24);
    else
        value = ldexp((double)(1024 + fraction), (int)exponent - 25);
    return bits & 0x8000 ? -value : value;
}

int main(void)
{
    for (unsigned bits = 0; bits <= 0xffff; ++bits) {
        double expected = reference((uint16_t)bits);
        double actual = vox2_libjs_float16_from_bits((uint16_t)bits);
        if (isnan(expected)) {
            assert(isnan(actual));
            assert((vox2_libjs_float16_bits(actual) & 0x7fff) > 0x7c00);
        } else {
            assert(actual == expected);
            assert(!!signbit(actual) == !!signbit(expected));
            assert(vox2_libjs_float16_bits(expected) == bits);
        }
    }
    /* Every finite rounding boundary, including zero, the normal/subnormal
     * transition, exponent carries and the overflow boundary at 65520. */
    for (unsigned bits = 0; bits < 0x7c00; ++bits) {
        double lower = reference((uint16_t)bits);
        double upper = bits == 0x7bff ? 65536.0 : reference((uint16_t)(bits + 1));
        double midpoint = (lower + upper) / 2;
        uint16_t tie = (uint16_t)(bits + (bits & 1));
        double below = nextafter(midpoint, 0);
        double above = nextafter(midpoint, INFINITY);
        assert(vox2_libjs_float16_bits(below) == bits);
        assert(vox2_libjs_float16_bits(midpoint) == tie);
        assert(vox2_libjs_float16_bits(above) == bits + 1);
        assert(vox2_libjs_float16_bits(-below) == (bits | 0x8000));
        assert(vox2_libjs_float16_bits(-midpoint) == (tie | 0x8000));
        assert(vox2_libjs_float16_bits(-above) == ((bits + 1) | 0x8000));
    }
    assert(vox2_libjs_float16_bits(DBL_MAX) == 0x7c00);
    assert(vox2_libjs_float16_bits(-DBL_MAX) == 0xfc00);
    assert(vox2_libjs_float16_bits(DBL_MIN) == 0);
    assert(vox2_libjs_float16_bits(-DBL_MIN) == 0x8000);
    assert(vox2_libjs_float16_bits(nextafter(0, 1)) == 0);
    assert(vox2_libjs_float16_bits(nextafter(0, -1)) == 0x8000);
    return 0;
}
