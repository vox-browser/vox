#import <Foundation/Foundation.h>
#include "../native_media_darwin.h"
#include <assert.h>

static void pump(double seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
static BOOL waitFor(BOOL (^condition)(void), double seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0) {
        if (condition()) return YES;
        pump(0.01);
    }
    return condition();
}
static uint64_t frameHash(void *media) {
    int32_t w = 0, h = 0;
    uint8_t *frame = native_media_copy_frame(media, &w, &h);
    if (!frame) return 0;
    assert(w == 160 && h == 90);
    uint64_t hash = 1469598103934665603ULL;
    for (int i = 0; i < w * h * 4; ++i) hash = (hash ^ frame[i]) * 1099511628211ULL;
    native_media_free_frame(frame);
    return hash;
}
static void checkPlayback(const char *url) {
    void *media = native_media_open(url);
    assert(media);
    assert(waitFor(^BOOL{ return native_media_status(media) != 0; }, 25));
    if (native_media_status(media) < 0) fprintf(stderr, "Media error: %s\n", native_media_error(media));
    assert(native_media_status(media) == 1);
    assert(native_media_width(media) == 160 && native_media_height(media) == 90);
    assert(native_media_audio(media));
    assert(native_media_duration(media) >= 3.9 && native_media_duration(media) < 5);
    native_media_volume(media, 0);
    native_media_play(media, 1);
    __block uint64_t first = 0, last = 0;
    assert(waitFor(^BOOL{ first = frameHash(media); return first != 0; }, 10));
    assert(waitFor(^BOOL{ last = frameHash(media); return last && last != first && native_media_time(media) > 0.4; }, 10));
    assert(native_media_buffer_count(media) > 0);
    assert(native_media_buffer_edge(media, 0, 1) > native_media_buffer_edge(media, 0, 0));
    native_media_pause(media);
    pump(0.1);
    double paused = native_media_time(media);
    pump(0.3);
    assert(fabs(native_media_time(media) - paused) < 0.04);
    native_media_seek(media, 2.5, 0);
    BOOL seekFinished = waitFor(^BOOL{ return !native_media_buffering(media) && fabs(native_media_time(media) - 2.5) < 0.12; }, 10);
    if (!seekFinished) {
        VoxMediaPlayback *state = media;
        fprintf(stderr, "Seek state: time=%f seeking=%d empty=%d likely=%d ranges=%s\n",
            native_media_time(media), state.seeking, state.player.currentItem.playbackBufferEmpty,
            state.player.currentItem.playbackLikelyToKeepUp, state.player.currentItem.loadedTimeRanges.description.UTF8String);
    }
    assert(seekFinished);
    assert(waitFor(^BOOL{ return frameHash(media) != 0; }, 10));
    native_media_play(media, 1);
    assert(waitFor(^BOOL{ return native_media_time(media) > 2.8; }, 10));
    printf("PASS playback, changing frames, audio track, pause, seek, resume: %s\n", url);
    native_media_seek(media, 0.5, 0);
    native_media_close(media); // An in-flight completion must not touch freed state.
    pump(0.2);
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        assert(argc == 3);
        void *loaded = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
            RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD);
        assert((loaded != NULL) == (getenv("VOX_EAGER_AVFOUNDATION") != NULL));
        if (loaded) dlclose(loaded);
        checkPlayback(argv[1]);
        checkPlayback(argv[2]);
        assert(!native_media_open("javascript:alert(1)"));
        void *bad = native_media_open("file:///nonexistent/vox-media-test.mp4");
        assert(waitFor(^BOOL{ return native_media_status(bad) < 0; }, 10));
        assert(native_media_error(bad));
        native_media_close(bad);
        native_media_close(NULL);
        puts("PASS unsupported scheme, decoder failure and cancellation");
    }
}
