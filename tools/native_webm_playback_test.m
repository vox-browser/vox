#import <Foundation/Foundation.h>
#include "../native_media_darwin.h"
#include <assert.h>
#include <unistd.h>

static void checkAlpha(void *media, const char *reference) {
    int32_t width = 0, height = 0;
    uint8_t *pixels = native_media_copy_frame(media, &width, &height);
    assert(pixels && width == 16 && height == 16);
    FILE *file = fopen(reference, "rb");
    assert(file);
    for (int pixel = 0; pixel < width * height; ++pixel) {
        unsigned char rgba[4];
        assert(fread(rgba, 1, 4, file) == 4);
        assert(pixels[pixel * 4 + 3] == rgba[3]);
    }
    fclose(file);
    native_media_free_frame(pixels);
    assert(!native_media_copy_frame(media, &width, &height));
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        assert(argc == 5 && native_media_supports_webm());
        void *media = native_media_open_webm(argv[1]);
        assert(media && native_media_status(media) == 1);
        assert(native_media_width(media) == 16 && native_media_height(media) == 16);
        assert(!native_media_audio(media));
        assert(fabs(native_media_duration(media) - 1) < 0.01);
        assert(native_media_buffer_count(media) == 1);
        assert(native_media_buffer_edge(media, 0, 0) == 0);
        assert(native_media_buffer_edge(media, 0, 1) == native_media_duration(media));
        checkAlpha(media, argv[2]);
        native_media_seek(media, 0.5, 0);
        assert(!native_media_buffering(media) && fabs(native_media_time(media) - 0.5) < 0.001);
        checkAlpha(media, argv[3]);
        native_media_seek(media, 0, 0);
        checkAlpha(media, argv[2]);
        native_media_play(media, 1);
        usleep(100000);
        assert(native_media_time(media) >= 0.09);
        native_media_pause(media);
        double paused = native_media_time(media);
        usleep(30000);
        assert(native_media_time(media) == paused);
        native_media_seek(media, 0.9, 0);
        native_media_play(media, 2);
        usleep(70000);
        assert(native_media_time(media) == native_media_duration(media));
        assert(native_media_ended(media) && native_media_take_ended(media));
        assert(!native_media_take_ended(media));
        // Looping seeks retain the requested rate after reaching the endpoint.
        native_media_seek(media, 0, 0);
        assert(!native_media_ended(media));
        usleep(30000);
        assert(native_media_time(media) > 0.04);
        native_media_pause(media);
        native_media_seek(media, 1, 0);
        assert(native_media_ended(media) && native_media_take_ended(media));
        native_media_seek(media, 0, 0);
        checkAlpha(media, argv[2]);
        native_media_close(media);
        assert(!native_media_open_webm("/nonexistent/vox-webm-test.webm"));
        assert(!native_media_open_webm(argv[4])); // Audio needs a supported sink.
        native_media_close(NULL);
        puts("PASS transparent WebM preview, persistent frames, pause, seek, rates, endpoints, loop and unsupported audio");
    }
}
