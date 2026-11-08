#import <Foundation/Foundation.h>
#include "../native_media_darwin.h"
#include "../native_graphite_bridge.h"
#include <assert.h>
#include <stdio.h>

int main(int argc, const char **argv) {
    @autoreleasepool {
        assert(argc == 4);
        void *library = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
        assert(library);
        __typeof__(&vox_graphite_draw_image_pixels) draw = dlsym(library, "vox_graphite_draw_image_pixels");
        assert(draw);
        void *media = native_media_open_webm(argv[1]);
        assert(media && native_media_status(media) == 1);
        int32_t width = 0, height = 0, format = 0, length = 0;
        uint8_t *rgba = native_media_copy_frame(media, &width, &height);
        assert(rgba && width == 65 && height == 65);
        native_media_free_frame(rgba);
        const uint8_t *planes = native_media_frame_planes(media, &format, &length);
        assert(planes && format == 13 && length == 65 * 65 * 2 + 33 * 33 * 2);
        uint32_t *pixels = malloc(800 * 600 * 4);
        assert(pixels);
        for (int index = 0; index < 800 * 600; ++index) pixels[index] = 0xff20242f;
        for (int index = 0; index < 2; ++index) {
            int size = index ? 65 : 34;
            VoxGraphiteImage image = {0};
            image.width = image.height = 65; image.pitch = 260; image.pixels = planes;
            image.flags = 4 | VOX_GRAPHITE_IMAGE_YUVA_ALPHA | VOX_GRAPHITE_IMAGE_VIDEO_FRAME;
            image.opacity = 1;
            image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
            image.source[2] = image.source[3] = 65;
            image.destination[0] = image.clip[0] = index ? 300 : 200;
            image.destination[1] = image.clip[1] = 8;
            image.destination[2] = image.destination[3] = image.clip[2] = image.clip[3] = size;
            assert(draw((uint8_t *)pixels, 800, 600, 3200, 1, &image));
        }
        FILE *output = fopen(argv[3], "wb");
        assert(output && fwrite(pixels, 4, 800 * 600, output) == 800 * 600);
        fclose(output);
        free(pixels);
        native_media_close(media);
        puts("PASS WebM decode and retained YUVA GPU draws at natural and reduced sizes");
    }
}
