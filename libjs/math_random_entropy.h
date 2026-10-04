/* Copyright (c) 2024-present, the Ladybird developers.
 * SPDX-License-Identifier: BSD-2-Clause
 * AK/Random.cpp::csprng and fill_with_random, native ABI for two u64 seeds.
 */
#ifndef VOX_MATH_RANDOM_ENTROPY_H
#define VOX_MATH_RANDOM_ENTROPY_H
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#if defined(__linux__)
#include <sys/random.h>
#endif
#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
typedef BOOL (WINAPI *vox_process_prng_fn)(PBYTE, SIZE_T);
#endif
#if defined(__GLIBC__)
#define VOX_RANDOM_GLIBC_PREREQ(major, minor) __GLIBC_PREREQ(major, minor)
#else
#define VOX_RANDOM_GLIBC_PREREQ(major, minor) 0
#endif

static int vox_ak_fill_with_random(void* const buf, size_t size)
{
    /* The conditions map AK/Platform.h's Source OS families. */
#if defined(__serenity__) || defined(__ANDROID__) || (defined(__APPLE__) && defined(__MACH__)) || defined(__IOS__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__) || defined(__sun) || defined(__HAIKU__) || VOX_RANDOM_GLIBC_PREREQ(2, 36)
    arc4random_buf(buf, size);
#elif defined(__linux__)
    unsigned char* out = (unsigned char*)buf;
    while (size > 0u) {
        int ret = getrandom(out, size, 0);
        if (ret == -1 && errno != EINTR)
            return errno;
        if (ret > 0) {
            size -= ret;
            out += ret;
        }
    }
#elif defined(_WIN32) || defined(_WIN64)
    /* AK/Windows.h::SystemApi loads this same required entry point. */
    static vox_process_prng_fn process_prng;
    if (!process_prng) {
        HMODULE library = LoadLibraryW(L"bcryptprimitives.dll");
        if (!library)
            abort();
        process_prng = (vox_process_prng_fn)GetProcAddress(library, "ProcessPrng");
        if (!process_prng)
            abort();
    }
    process_prng((PBYTE)buf, size);
#else
#error This target has no CSPRNG interface in pinned AK/Random.cpp.
#endif
    return 0;
}

static uint64_t vox_ak_random_seed_u64(void)
{
    uint64_t value;
    /* Source get_random<u64>() fills the object's native byte representation;
     * fill_with_random's MUST makes a platform error fatal. */
    if (vox_ak_fill_with_random(&value, sizeof(value)) != 0)
        abort();
    return value;
}
#endif
