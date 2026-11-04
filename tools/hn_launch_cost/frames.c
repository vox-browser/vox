// Diagnostic interposer: hash each large frame image at snapshot time (stderr).
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <libproc.h>
#include <unistd.h>
static uint64_t fnv(const uint8_t *p, size_t n) { uint64_t h = 1469598103934665603ull; for (size_t i = 0; i < n; ++i) { h ^= p[i]; h *= 1099511628211ull; } return h; }
static CGImageRef logged_image(CGContextRef context) {
    size_t w = CGBitmapContextGetWidth(context), h = CGBitmapContextGetHeight(context), row = CGBitmapContextGetBytesPerRow(context);
    if (w * h >= 100000 && CGBitmapContextGetData(context)) {
        struct rusage_info_v4 r; proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&r);
        const uint8_t *data = CGBitmapContextGetData(context);
        size_t nonwhite_rows = 0;
        for (size_t y = 0; y < h; ++y) for (size_t x = 0; x < w * 4; x += 4) if (data[y * row + x] != 255 || data[y * row + x + 1] != 255 || data[y * row + x + 2] != 255) { ++nonwhite_rows; break; }
        fprintf(stderr, "VOXPROBE_FRAME %zux%zu hash=%016llx nonwhite_rows=%zu at_instructions=%llu\n", w, h, fnv(data, row * h), nonwhite_rows, r.ri_instructions);
    }
    return CGBitmapContextCreateImage(context);
}
__attribute__((used)) static struct { const void *replacement, *replacee; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)logged_image, (const void *)CGBitmapContextCreateImage},
};
