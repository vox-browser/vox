#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <mach-o/dyld.h>
#include "../native/include/native_ffmpeg_darwin.h"

static bool codecs_loaded(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *path = _dyld_get_image_name(i);
        if (path && (strstr(path, "/libavcodec.") || strstr(path, "/libavformat."))) return true;
    }
    return false;
}
static uint64_t checksum(const uint8_t *bytes, size_t length) {
    uint64_t value = UINT64_C(1469598103934665603);
    for (size_t i = 0; i < length; ++i) { value ^= bytes[i]; value *= UINT64_C(1099511628211); }
    return value;
}
int main(int argc, char **argv) {
    assert(argc == 2);
    assert(!codecs_loaded());
    int width = 99, height = 99, pitch = 99;
    assert(!native_decode_video_frame(NULL, 0, &width, &height, &pitch));
    assert(!codecs_loaded() && width == 0 && height == 0 && pitch == 0);
    uint8_t *pixels = native_decode_video_frame(argv[1], 0, &width, &height, &pitch);
    assert(pixels && codecs_loaded() && width == 160 && height == 120 && pitch == width * 4);
    uint64_t first = checksum(pixels, (size_t)pitch * height);
    native_free_video_frame(pixels);
    const VoxFFmpegAPI *api = native_ffmpeg_api();
    assert(api && api->ready && api == native_ffmpeg_api());
    assert(api->avcodec_find_decoder(AV_CODEC_ID_VP9));
    assert(!native_decode_video_frame("/vox-test-missing-video.webm", 0, &width, &height, &pitch));
    assert(width == 0 && height == 0 && pitch == 0);
    pixels = native_decode_video_frame(argv[1], 0.02, &width, &height, &pitch);
    assert(pixels && first == checksum(pixels, (size_t)pitch * height));
    native_free_video_frame(pixels);
    printf("PASS codecs absent until first decode, complete API loading, VP9 playback/seek/reuse, missing-file cleanup; frame checksum=%llu\n", (unsigned long long)first);
}
