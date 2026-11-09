// SPDX-License-Identifier: BSD-2-Clause
#include "../native/include/native_ffmpeg_darwin.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    uint8_t y[18], u[8], v[10], pixels[57];
    for (int i = 0; i < 18; ++i) y[i] = (uint8_t)(i * 73);
    for (int i = 0; i < 8; ++i) u[i] = (uint8_t)(i * 37);
    for (int i = 0; i < 10; ++i) v[i] = (uint8_t)(i * 91);
    memset(pixels, 0xa5, sizeof(pixels));
    AVFrame frame = {0};
    frame.width = frame.height = 3;
    frame.format = AV_PIX_FMT_YUV420P;
    frame.color_range = AVCOL_RANGE_MPEG;
    frame.colorspace = AVCOL_SPC_BT709;
    frame.data[0] = y; frame.data[1] = u; frame.data[2] = v;
    frame.linesize[0] = 6; frame.linesize[1] = 4; frame.linesize[2] = 5;
    // A null fallback API makes this fail if the V path is not actually used.
    assert(native_ffmpeg_convert_frame(NULL, &frame, pixels, 19));
#if defined(__aarch64__)
    // Captured from the removed Rust library, before translating the converter.
    const uint8_t expected[] = {
        0,95,0,255, 0,162,0,255, 86,191,0,255,
        0,255,0,255, 50,255,9,255, 0,104,0,255,
        234,65,149,255, 255,151,235,255, 109,255,255,255
    };
    for (int row = 0; row < 3; ++row)
        assert(memcmp(pixels + row * 19, expected + row * 12, 12) == 0);
#endif
    for (int row = 0; row < 3; ++row) {
        for (int x = 0; x < 3; ++x) assert(pixels[row * 19 + x * 4 + 3] == 255);
        for (int x = 12; x < 19; ++x) assert(pixels[row * 19 + x] == 0xa5);
    }
    uint8_t saved[57];
    memcpy(saved, pixels, sizeof(saved));
    assert(!vox_yuv_u8_to_rgba(y, 6, u, 4, v, 5, 3, 3, true, true, pixels, 11, 0, 0));
    assert(memcmp(saved, pixels, sizeof(saved)) == 0);
    assert(!vox_yuv_u8_to_rgba(NULL, 6, u, 4, v, 5, 3, 3, true, true, pixels, 19, 0, 0));
    puts("V YUV: native FFmpeg route, odd dimensions, independent strides, padding and invalid input pass");
}
