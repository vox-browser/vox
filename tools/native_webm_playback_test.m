#import <Foundation/Foundation.h>
#include "../native/include/native_media_darwin.h"
#include <assert.h>
#include <unistd.h>

// The browser exports this converter from V (media/yuv_bridge.v). Declining
// here keeps the bridge on its swscale path; these cases need only the
// BT.601 path below.
bool vox_yuv_u8_to_rgba(uint8_t *y, uint32_t y_stride, uint8_t *u, uint32_t u_stride,
    uint8_t *v, uint32_t v_stride, uint32_t width, uint32_t height, bool subsampling_x,
    bool subsampling_y, uint8_t *output, uint32_t stride, uint8_t range, uint8_t matrix) {
    (void)y; (void)y_stride; (void)u; (void)u_stride; (void)v; (void)v_stride; (void)width;
    (void)height; (void)subsampling_x; (void)subsampling_y; (void)output; (void)stride;
    (void)range; (void)matrix;
    return false;
}

// The browser exports vox_i420_bt601_to_rgba from V (yuv/i420_bt601.v). This
// standalone copy uses the same kYuvI601Constants arithmetic.
static uint8_t test_bt601_clamp(int value) {
    value >>= 6;
    return value < 0 ? 0 : value > 255 ? 255 : (uint8_t)value;
}

bool vox_i420_bt601_to_rgba(uint8_t *y, int32_t y_stride, uint8_t *u, int32_t u_stride,
    uint8_t *v, int32_t v_stride, uint8_t *a, int32_t a_stride, uint8_t *output,
    int32_t stride, int32_t width, int32_t height) {
    if (!y || !u || !v || !output || width <= 0 || height <= 0 || stride < width * 4) return false;
    for (int row = 0; row < height; ++row) {
        const uint8_t *y_row = y + row * y_stride;
        const uint8_t *u_row = u + (row >> 1) * u_stride, *v_row = v + (row >> 1) * v_stride;
        const uint8_t *a_row = a ? a + row * a_stride : NULL;
        uint8_t *out = output + row * stride;
        for (int x = 0; x < width; ++x, out += 4) {
            int luma = (int)(((uint32_t)y_row[x] * 0x0101u * 18997u) >> 16) - 1160;
            int cb = u_row[x >> 1] - 128, cr = v_row[x >> 1] - 128;
            out[0] = test_bt601_clamp(luma + cr * 102);
            out[1] = test_bt601_clamp(luma - cb * 25 - cr * 52);
            out[2] = test_bt601_clamp(luma + cb * 128);
            out[3] = a_row ? a_row[x] : 255;
        }
    }
    return true;
}

static void checkAlpha(void *media, const char *reference) {
    int32_t width = 0, height = 0;
    uint8_t *pixels = native_media_copy_frame(media, &width, &height);
    assert(pixels && width == 16 && height == 16);
    int32_t format = 0, length = 0;
    const uint8_t *planes = native_media_frame_planes(media, &format, &length);
    assert(planes && format == 13 && length == 16 * 16 * 2 + 8 * 8 * 2);
    FILE *file = fopen(reference, "rb");
    assert(file);
    for (int pixel = 0; pixel < width * height; ++pixel) {
        unsigned char rgba[4];
        assert(fread(rgba, 1, 4, file) == 4);
        assert(pixels[pixel * 4 + 3] == rgba[3]);
        assert(planes[16 * 16 + 8 * 8 * 2 + pixel] == rgba[3]);
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
