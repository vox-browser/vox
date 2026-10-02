/*
 * Copyright (c) 2021, Leon Albrecht <leon2002.la@gmail.com>.
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * AK/Math.h::round_to<int>(float) ABI. Keep the source conversion instruction,
 * including its rounding mode and exceptional conversion behavior.
 */
#pragma once
#include <math.h>

static inline int libweb_v_css_affine_round_to_int(float value)
{
#if defined(__aarch64__)
    int result;
    __asm__("fcvtns %w0, %s1" : "=r"(result) : "w"(value));
    return result;
#elif defined(__x86_64__)
    int result;
    __asm__("cvtss2si %1, %0" : "=r"(result) : "xm"(value));
    return result;
#else
    return (int)__builtin_llrintf(value);
#endif
}
