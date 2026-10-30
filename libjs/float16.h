#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
/* BSD-2-Clause. AK/Types.h uses _Float16; Runtime/ArrayBuffer.h converts
 * directly between that type and double and copies its representation. V has
 * no binary16 scalar, so these two primitive representation operations stay
 * at the C boundary. All buffer and DataView algorithms are translated in V. */
#ifndef VOX2_LIBJS_FLOAT16_H
#define VOX2_LIBJS_FLOAT16_H
#include <stdint.h>
#include <string.h>
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
#endif

#endif
