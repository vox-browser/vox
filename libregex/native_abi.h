// SPDX-License-Identifier: BSD-2-Clause
// ABI declarations and V pointer adapters for the pinned Rust/src/ffi.rs.
#ifndef VOX2_REGEX_NATIVE_ABI_H
#define VOX2_REGEX_NATIVE_ABI_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#if defined(_WIN32) && (!defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER))
#include "rust_panic_windows.h"
#endif
typedef struct RustRegex RustRegex;
typedef struct RustRegexFlags {
    bool global_, ignore_case, multiline, dot_all, unicode, unicode_sets, sticky, has_indices;
} RustRegexFlags;
typedef struct RustRegexNamedGroup {
    const uint8_t* name;
    size_t name_len;
    uint32_t index;
} RustRegexNamedGroup;
RustRegex* rust_regex_compile(const uint16_t*, size_t, RustRegexFlags, const uint8_t**, size_t*);
RustRegex* rust_regex_compile_ascii(const uint8_t*, size_t, RustRegexFlags, const uint8_t**, size_t*);
void rust_regex_free_error(uint8_t*, size_t);
void rust_regex_free(RustRegex*);
int32_t rust_regex_exec_into(const RustRegex*, const uint16_t*, size_t, size_t, int32_t*, uint32_t);
int32_t rust_regex_exec_into_ascii(const RustRegex*, const uint8_t*, size_t, size_t, int32_t*, uint32_t);
int32_t rust_regex_test(const RustRegex*, const uint16_t*, size_t, size_t);
int32_t rust_regex_test_ascii(const RustRegex*, const uint8_t*, size_t, size_t);
uint32_t rust_regex_capture_count(const RustRegex*);
bool rust_regex_is_single_non_bmp_literal(const RustRegex*);
int32_t rust_regex_find_all(const RustRegex*, const uint16_t*, size_t, size_t, int32_t*, uint32_t);
int32_t rust_regex_find_all_ascii(const RustRegex*, const uint8_t*, size_t, size_t, int32_t*, uint32_t);
RustRegexNamedGroup* rust_regex_get_named_groups(const RustRegex*, uint32_t*);
void rust_regex_free_named_groups(RustRegexNamedGroup*, uint32_t);

// V has no const-qualified pointer slots. Preserve the native output type and
// expose the allocated error buffer to V for reading and rust_regex_free_error.
static inline RustRegex* vox_rust_regex_compile(const uint16_t* pattern, size_t length,
    RustRegexFlags flags, uint8_t** error_out, size_t* error_length)
{
    const uint8_t* native_error = error_out ? *error_out : NULL;
    RustRegex* regex = rust_regex_compile(pattern, length, flags,
        error_out ? &native_error : NULL, error_length);
    if (error_out)
        *error_out = (uint8_t*)native_error;
    return regex;
}

static inline RustRegex* vox_rust_regex_compile_ascii(const uint8_t* pattern, size_t length,
    RustRegexFlags flags, uint8_t** error_out, size_t* error_length)
{
    const uint8_t* native_error = error_out ? *error_out : NULL;
    RustRegex* regex = rust_regex_compile_ascii(pattern, length, flags,
        error_out ? &native_error : NULL, error_length);
    if (error_out)
        *error_out = (uint8_t*)native_error;
    return regex;
}
#endif
