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

static void checkOddChroma(void *media) {
    VoxFFmpegVideo *video = native_media_for_handle(media).webm;
    AVFrame frame = {0};
    uint8_t y[] = {81, 81, 81, 81, 81, 81, 81, 81, 81};
    uint8_t u[] = {90, 240, 128, 54}, v[] = {240, 110, 128, 34};
    uint8_t alpha[] = {0, 64, 255, 128, 255, 255, 255, 255, 255};
    frame.width = frame.height = 3;
    frame.format = AV_PIX_FMT_YUVA420P;
    frame.colorspace = AVCOL_SPC_UNSPECIFIED;
    frame.color_range = AVCOL_RANGE_MPEG;
    frame.data[0] = y; frame.data[1] = u; frame.data[2] = v; frame.data[3] = alpha;
    frame.linesize[0] = frame.linesize[3] = 3;
    frame.linesize[1] = frame.linesize[2] = 2;
    AVFrame *saved = video->frame;
    int width = video->width, height = video->height;
    video->frame = &frame; video->width = video->height = 3;
    uint8_t pixels[36];
    assert(vox_ffmpeg_video_convert(video, pixels));
    const uint8_t expected[] = {
        254,0,0,0, 254,0,0,64, 47,47,255,255,
        254,0,0,128, 254,0,0,255, 47,47,255,255,
        76,76,76,255, 76,76,76,255, 0,181,0,255
    };
    assert(memcmp(pixels, expected, sizeof(expected)) == 0);
    frame.format = AV_PIX_FMT_YUV420P;
    assert(vox_ffmpeg_video_convert(video, pixels));
    for (int pixel = 0; pixel < 9; ++pixel) {
        assert(memcmp(pixels + pixel * 4, expected + pixel * 4, 3) == 0);
        assert(pixels[pixel * 4 + 3] == 255);
    }
    video->frame = saved; video->width = width; video->height = height;
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
        checkOddChroma(media);
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
