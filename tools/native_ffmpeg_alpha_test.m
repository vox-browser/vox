#include "../native_ffmpeg_darwin.h"
#include <assert.h>
#include <stdio.h>

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
