// SPDX-License-Identifier: BSD-2-Clause
#pragma once
#include <math.h>
// ABI for Source's original float-width isinf classification.
static inline int vox_wasm_isinf_f32(float value) { return isinf(value); }
