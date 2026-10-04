/* Copyright (c) 2021, Nick Johnson <sylvyrfysh@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 * Concrete AK/BuiltinWrappers.h specializations used by Source Operators.h.
 */
#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#if defined(__clang__) || defined(__GNUC__)
#    define VOX_WASM_CLZ(Type, Suffix)                                      \
        static inline int vox_wasm_clz##Suffix(Type value)                  \
        {                                                                  \
            if (sizeof(Type) <= sizeof(unsigned int))                       \
                return __builtin_clz(value) - (32 - (8 * sizeof(Type)));    \
            if (sizeof(Type) == sizeof(unsigned long))                      \
                return __builtin_clzl(value);                              \
            if (sizeof(Type) == sizeof(unsigned long long))                 \
                return __builtin_clzll(value);                             \
            abort();                                                       \
        }
#    define VOX_WASM_CTZ(Type, Suffix)                                      \
        static inline int vox_wasm_ctz##Suffix(Type value)                  \
        {                                                                  \
            if (sizeof(Type) <= sizeof(unsigned int))                       \
                return __builtin_ctz(value);                               \
            if (sizeof(Type) == sizeof(unsigned long))                      \
                return __builtin_ctzl(value);                              \
            if (sizeof(Type) == sizeof(unsigned long long))                 \
                return __builtin_ctzll(value);                             \
            abort();                                                       \
        }
#    define VOX_WASM_POPCOUNT(Type, Suffix)                                  \
        static inline int vox_wasm_popcount##Suffix(Type value)             \
        {                                                                  \
            if (sizeof(Type) <= sizeof(unsigned int))                       \
                return __builtin_popcount(value);                          \
            if (sizeof(Type) == sizeof(unsigned long))                      \
                return __builtin_popcountl(value);                         \
            if (sizeof(Type) == sizeof(unsigned long long))                 \
                return __builtin_popcountll(value);                        \
            abort();                                                       \
        }
#else
/* Preserve the pinned AK fallback bodies, including its CLZ return value. */
#    define VOX_WASM_CLZ(Type, Suffix)                                      \
        static inline int vox_wasm_clz##Suffix(Type value)                  \
        {                                                                  \
            for (size_t i = (8 * sizeof(Type)) - 1; i < 8 * sizeof(Type); --i) { \
                if ((value >> i) & 1)                                      \
                    return (int)i;                                        \
            }                                                              \
            return 8 * sizeof(Type);                                       \
        }
#    define VOX_WASM_CTZ(Type, Suffix)                                      \
        static inline int vox_wasm_ctz##Suffix(Type value)                  \
        {                                                                  \
            for (size_t i = 0; i < 8 * sizeof(Type); ++i) {                  \
                if ((value >> i) & 1)                                      \
                    return (int)i;                                        \
            }                                                              \
            return 8 * sizeof(Type);                                       \
        }
#    define VOX_WASM_POPCOUNT(Type, Suffix)                                  \
        static inline int vox_wasm_popcount##Suffix(Type value)             \
        {                                                                  \
            int ones = 0;                                                  \
            for (size_t i = 0; i < 8 * sizeof(Type); ++i) {                  \
                if ((value >> i) & 1)                                      \
                    ++ones;                                               \
            }                                                              \
            return ones;                                                   \
        }
#endif

VOX_WASM_CLZ(uint32_t, 32)
VOX_WASM_CLZ(uint64_t, 64)
VOX_WASM_CTZ(uint32_t, 32)
VOX_WASM_CTZ(uint64_t, 64)
VOX_WASM_POPCOUNT(uint8_t, 8)
VOX_WASM_POPCOUNT(uint16_t, 16)
VOX_WASM_POPCOUNT(uint32_t, 32)
VOX_WASM_POPCOUNT(uint64_t, 64)
#undef VOX_WASM_CLZ
#undef VOX_WASM_CTZ
#undef VOX_WASM_POPCOUNT
