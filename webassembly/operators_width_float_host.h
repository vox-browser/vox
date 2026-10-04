// Copyright (c) 2021-2023, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_WASM_WIDTH_FLOAT_HOST_H
#define VOX_WASM_WIDTH_FLOAT_HOST_H
#include <math.h>

static inline int vox_wasm_isinf_f64(double value) { return isinf(value); }
static inline double vox_wasm_empty_nan_f64(void) { return nan(""); }
static inline float vox_wasm_empty_nan_f32(void) { return nanf(""); }
static inline float vox_wasm_huge_f32(void) { return __builtin_huge_valf(); }
#endif
