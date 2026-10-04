// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_WASM_UNARY_FLOAT_HOST_H
#define VOX_WASM_UNARY_FLOAT_HOST_H
#include <math.h>

// Preserve the operand width of Source's type-generic isnan invocation.
static inline int vox_wasm_isnan_f32(float value) { return isnan(value); }
static inline int vox_wasm_isnan_f64(double value) { return isnan(value); }

// AK::abs's runtime floating specializations use these compiler builtins.
static inline float vox_wasm_abs_f32(float value) { return __builtin_fabsf(value); }
static inline double vox_wasm_abs_f64(double value) { return __builtin_fabs(value); }
#endif
