#pragma once

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#if defined(__aarch64__) && defined(__ARM_FEATURE_CRC32) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#include <arm_acle.h>
#endif

// Preserve zlib's IEEE CRC-32, including incremental and null-buffer behavior.
// Apple Silicon exposes the matching instructions. Other compilation targets
// retain the linked zlib implementation without assuming CPU capabilities.
static uLong vox_crc32(uLong initial, Bytef const* bytes, uInt length)
{
#if defined(__aarch64__) && defined(__ARM_FEATURE_CRC32) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    if (!bytes || getenv("VOX_DISABLE_HARDWARE_SNAPSHOT_CRC")) return crc32(initial,bytes,length);
    uint32_t crc = ~(uint32_t)initial;
    while (length >= 64) {
        uint64_t words[8];
        memcpy(words,bytes,sizeof(words));
#pragma clang loop unroll(full)
        for (unsigned i = 0; i < 8; ++i) crc = __crc32d(crc,words[i]);
        bytes += 64; length -= 64;
    }
    while (length >= 8) {
        uint64_t word; memcpy(&word,bytes,sizeof(word));
        crc = __crc32d(crc,word); bytes += 8; length -= 8;
    }
    while (length--) crc = __crc32b(crc,*bytes++);
    return (uLong)~crc;
#else
    return crc32(initial,bytes,length);
#endif
}
