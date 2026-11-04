// Diagnostic interposer: log CGBitmapContextCreate sizes (stderr). Not used for counts.
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <libproc.h>
#include <unistd.h>
static CGContextRef logged_create(void *data, size_t w, size_t h, size_t bpc, size_t row, CGColorSpaceRef space, uint32_t info) {
    struct rusage_info_v4 r; proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&r);
    if (w * h >= 100000) fprintf(stderr, "VOXPROBE_BITMAP %zux%zu data=%s row=%zu at_instructions=%llu\n", w, h, data ? "caller" : "fresh", row, r.ri_instructions);
    return CGBitmapContextCreate(data, w, h, bpc, row, space, info);
}
__attribute__((used)) static struct { const void *replacement, *replacee; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)logged_create, (const void *)CGBitmapContextCreate},
};
