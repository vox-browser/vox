#pragma once
#include "native_parallel_raster.h"
#include <cstdint>
#include <cstring>
#if defined(__aarch64__)
#include <arm_neon.h>
#endif

inline void vox_swap_red_blue_serial(uint8_t* destination, uint8_t const* source, size_t count)
{
    size_t i = 0;
#if defined(__aarch64__)
    uint8_t const indices[] {2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15};
    auto order = vld1q_u8(indices);
    for (; count - i >= 4; i += 4)
        vst1q_u8(destination + i * 4, vqtbl1q_u8(vld1q_u8(source + i * 4), order));
#endif
    for (; i < count; ++i) {
        uint32_t p;
        std::memcpy(&p, source + i * 4, sizeof(p));
        p = (p & 0xff00ff00u) | ((p & 0xffu) << 16) | ((p >> 16) & 0xffu);
        std::memcpy(destination + i * 4, &p, sizeof(p));
    }
}

inline void vox_swap_red_blue_pixels(uint8_t* destination, uint8_t const* source, size_t count)
{
    vox_raster::parallel_pixels(count, [&](size_t begin, size_t end) {
        vox_swap_red_blue_serial(destination + begin * 4, source + begin * 4, end - begin);
    }, "channel-swap");
}

// Independent, disjoint rows (or an identical in-place view). Keep padding
// untouched, and bound memory-copy participation while the GPU is also busy.
inline void vox_swap_red_blue_rows(uint8_t* destination, size_t destination_pitch,
    uint8_t const* source, size_t source_pitch, size_t width, size_t height)
{
    vox_raster::parallel_rows(width, height, [&](size_t begin, size_t end) {
        for (size_t row = begin; row < end; ++row)
            vox_swap_red_blue_serial(destination + row * destination_pitch,
                source + row * source_pitch, width);
    }, "channel-swap-rows", 4);
}

inline void vox_copy_backdrop_pixels(uint8_t* destination, uint8_t const* source, size_t pitch,
    size_t width, size_t height, size_t left, size_t top, size_t right, size_t bottom)
{
    auto copy_rows = [&](size_t begin, size_t end) {
        for (size_t y = begin; y < end; ++y) {
            auto copy = [&](size_t x, size_t count) {
                vox_swap_red_blue_serial(destination + (y * width + x) * 4,
                    source + y * pitch + x * 4, count);
            };
            if (y >= top && y < bottom) {
                copy(0, left);
                copy(right, width - right);
            } else copy(0, width);
        }
    };
    // An opaque center can remove almost all of a large rectangle's actual
    // work. Size the admission check by bytes copied, not the skipped hole.
    auto copied = width * height - (right - left) * (bottom - top);
    if (copied < 2 * vox_raster::minimum_pixels_per_lane) copy_rows(0, height);
    else vox_raster::parallel_rows(width, height, copy_rows, "backdrop-copy");
}
