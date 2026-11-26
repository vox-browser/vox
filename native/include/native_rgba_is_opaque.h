#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#if defined(__APPLE__)
#include <dispatch/dispatch.h>
#endif
#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

// Inspect only alpha bytes, including padded or unaligned RGBA rows. Bounded
// word loads let the compiler check sixteen pixels together without reading
// row padding or changing the fallback for a single translucent pixel. NEON
// de-interleaves sixty-four pixels per step and checks only their alpha lanes.
static int vox_rgba8_rows_are_opaque(const unsigned char *pixels,
    size_t width, size_t height, size_t pitch, int scalar)
{
    for (size_t y = 0; y < height; ++y) {
        const unsigned char *row = pixels + y * pitch;
        size_t x = 0;
#if defined(__ARM_NEON)
        if (!scalar) {
            for (; width - x >= 64; x += 64) {
                const unsigned char *block = row + x * 4;
                uint8x16_t alpha = vandq_u8(
                    vandq_u8(vld4q_u8(block).val[3], vld4q_u8(block + 64).val[3]),
                    vandq_u8(vld4q_u8(block + 128).val[3], vld4q_u8(block + 192).val[3]));
                if (vminvq_u8(alpha) != 255) return 0;
            }
        }
#endif
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        if (!scalar) for (; width - x >= 16; x += 16) {
            uint64_t channels = UINT64_MAX;
            for (int i = 0; i < 8; ++i) {
                uint64_t pair;
                memcpy(&pair, row + x * 4 + i * 8, sizeof pair);
                channels &= pair;
            }
            const uint64_t alpha = UINT64_C(0xff000000ff000000);
            if ((channels & alpha) != alpha) return 0;
        }
#else
        (void)scalar;
#endif
        for (; x < width; ++x) if (row[x * 4 + 3] != 255) return 0;
    }
    return 1;
}

#if defined(__APPLE__)
typedef struct {
    const unsigned char *pixels;
    size_t width, height, pitch, lanes;
    unsigned char opaque[4];
} VoxOpacityScan;

static void vox_rgba8_scan_range(void *context, size_t lane)
{
    VoxOpacityScan *scan = (VoxOpacityScan *)context;
    size_t first = scan->height * lane / scan->lanes;
    size_t end = scan->height * (lane + 1) / scan->lanes;
    scan->opaque[lane] = vox_rgba8_rows_are_opaque(scan->pixels + first * scan->pitch,
        scan->width, end - first, scan->pitch, 0);
}
#endif

static int vox_rgba8_is_opaque(const unsigned char *pixels,
    size_t width, size_t height, size_t pitch)
{
    if (!pixels || !width || !height || width > SIZE_MAX / 4
        || pitch < width * 4 || pitch > SIZE_MAX / height) return 0;
    int scalar = getenv("VOX_DISABLE_BLOCK_OPACITY_SCAN") != NULL;
#if defined(__APPLE__)
    size_t remaining = height - 1;
    size_t lanes = width * 4 * remaining / (2u * 1024u * 1024u);
    if (lanes > 4) lanes = 4;
    if (lanes > remaining) lanes = remaining;
    if (!scalar && lanes > 1) {
        const char *serial = getenv("VOX_SERIAL_CPU_RASTER");
        if (!serial || strcmp(serial, "1") != 0) {
            // Reject a translucent leading row before sending the rest to
            // workers. The read-only bitmap stays borrowed until they join.
            if (!vox_rgba8_rows_are_opaque(pixels, width, 1, pitch, 0)) return 0;
            VoxOpacityScan scan = {pixels + pitch, width, remaining, pitch, lanes, {0}};
            dispatch_apply_f(lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
                &scan, vox_rgba8_scan_range);
            for (size_t lane = 0; lane < lanes; ++lane)
                if (!scan.opaque[lane]) return 0;
            return 1;
        }
    }
#endif
    return vox_rgba8_rows_are_opaque(pixels, width, height, pitch, scalar);
}
