#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#if defined(__aarch64__) && defined(__ARM_FEATURE_CRC32) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#include <arm_acle.h>
#endif

// IEEE CRC-32 (zlib's crc32), including incremental use: pass a previous
// result as `initial`. A NULL buffer returns 0, as zlib does. Vox links no
// zlib; the portable path below computes the same values.
static uint32_t vox_crc32_portable(uint32_t initial, const unsigned char *bytes, size_t length)
{
    uint32_t crc = ~initial;
    if (length >= 64 * 1024) {
        // Slicing-by-8 over a stack table: building it costs about one 8 KiB
        // pass, repaid many times on the large adblock snapshot payload, and
        // keeps the header free of shared mutable state.
        uint32_t table[8][256];
        for (uint32_t n = 0; n < 256; ++n) {
            uint32_t value = n;
            for (int bit = 0; bit < 8; ++bit) value = value & 1 ? 0xedb88320u ^ (value >> 1) : value >> 1;
            table[0][n] = value;
        }
        for (uint32_t n = 0; n < 256; ++n)
            for (int k = 1; k < 8; ++k)
                table[k][n] = table[0][table[k - 1][n] & 0xff] ^ (table[k - 1][n] >> 8);
        while (length >= 8) {
            uint32_t low = crc ^ ((uint32_t)bytes[0] | (uint32_t)bytes[1] << 8
                | (uint32_t)bytes[2] << 16 | (uint32_t)bytes[3] << 24);
            crc = table[7][low & 0xff] ^ table[6][(low >> 8) & 0xff]
                ^ table[5][(low >> 16) & 0xff] ^ table[4][low >> 24]
                ^ table[3][bytes[4]] ^ table[2][bytes[5]] ^ table[1][bytes[6]] ^ table[0][bytes[7]];
            bytes += 8; length -= 8;
        }
        while (length--) crc = table[0][(crc ^ *bytes++) & 0xff] ^ (crc >> 8);
        return ~crc;
    }
    while (length--) {
        crc ^= *bytes++;
        for (int bit = 0; bit < 8; ++bit) crc = crc & 1 ? 0xedb88320u ^ (crc >> 1) : crc >> 1;
    }
    return ~crc;
}

// Apple Silicon exposes the matching CRC instructions. Other compilation
// targets, and VOX_DISABLE_HARDWARE_SNAPSHOT_CRC, use the portable path.
static uint32_t vox_crc32(uint32_t initial, const unsigned char *bytes, size_t length)
{
    if (!bytes) return 0;
#if defined(__aarch64__) && defined(__ARM_FEATURE_CRC32) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    if (getenv("VOX_DISABLE_HARDWARE_SNAPSHOT_CRC")) return vox_crc32_portable(initial, bytes, length);
    uint32_t crc = ~initial;
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
    return ~crc;
#else
    return vox_crc32_portable(initial, bytes, length);
#endif
}
