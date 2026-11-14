#include "../native/include/native_ffmpeg_darwin.h"
#include <assert.h>
#include <stdio.h>

// The browser exports this converter from V (media/yuv_bridge.v). Declining
// here keeps the bridge on its swscale path; this test checks alpha only.
bool vox_yuv_u8_to_rgba(uint8_t *y, uint32_t y_stride, uint8_t *u, uint32_t u_stride,
    uint8_t *v, uint32_t v_stride, uint32_t width, uint32_t height, bool subsampling_x,
    bool subsampling_y, uint8_t *output, uint32_t stride, uint8_t range, uint8_t matrix) {
    (void)y; (void)y_stride; (void)u; (void)u_stride; (void)v; (void)v_stride; (void)width;
    (void)height; (void)subsampling_x; (void)subsampling_y; (void)output; (void)stride;
    (void)range; (void)matrix;
    return false;
}

int main(int argc, char **argv) {
    assert(argc == 5);
    bool transparent = false, translucent = false, opaque = false;
    for (int index = 0; index < 2; ++index) {
        int width = 0, height = 0, pitch = 0;
        uint8_t *pixels = native_decode_video_frame(argv[1], index * 0.5,
            &width, &height, &pitch);
        assert(pixels && width == 16 && height == 16 && pitch == 64);
        FILE *reference = fopen(argv[index + 2], "rb");
        assert(reference);
        for (int pixel = 0; pixel < width * height; ++pixel) {
            unsigned char rgba[4];
            assert(fread(rgba, 1, 4, reference) == 4);
            assert(pixels[pixel * 4 + 3] == rgba[3]);
            transparent |= rgba[3] == 0;
            translucent |= rgba[3] > 0 && rgba[3] < 255;
            opaque |= rgba[3] == 255;
        }
        assert(fgetc(reference) == EOF);
        fclose(reference);
        native_free_video_frame(pixels);
    }
    assert(transparent && translucent && opaque);
    // Unmarked VP9 keeps its ordinary decoder and fully opaque conversion.
    int width = 0, height = 0, pitch = 0;
    uint8_t *pixels = native_decode_video_frame(argv[4], 0, &width, &height, &pitch);
    assert(pixels && width == 16 && height == 16 && pitch == 64);
    for (int pixel = 0; pixel < width * height; ++pixel) assert(pixels[pixel * 4 + 3] == 255);
    native_free_video_frame(pixels);
    puts("WebM alpha: exact decoded alpha before/after seek; opaque VP9 preserved");
}
