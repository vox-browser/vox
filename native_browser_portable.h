#pragma once
#include <glib.h>

// The portable GG shell has a continuous frame callback. GLib sources are
// drained there, and also by synchronous translated event-loop spins.
static void native_wake_browser(void) { g_main_context_wakeup(g_main_context_default()); }

// Video frame decoding currently belongs to the macOS media adapter.
static unsigned char *native_decode_video_frame(const char *path, double seconds,
    int *width, int *height, int *pitch) {
    (void)path; (void)seconds; (void)width; (void)height; (void)pitch;
    return NULL;
}
static void native_free_video_frame(unsigned char *pixels) { g_free(pixels); }
