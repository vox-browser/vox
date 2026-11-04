// Diagnostic only. Per-call process counters include observer overhead and
// concurrent threads. Nested API totals overlap and must not be added together.
#include <CoreGraphics/CoreGraphics.h>
#include <libproc.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

struct Counter { uint64_t calls, instructions; };
static int counter_failed;
static uint64_t current_instructions(void) {
    struct rusage_info_v4 usage = {0};
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&usage))
        counter_failed = 1;
    return usage.ri_instructions;
}
static void finish(struct Counter *counter, uint64_t before) {
    uint64_t after = current_instructions();
    if (after < before) counter_failed = 1;
    else counter->instructions += after - before;
    ++counter->calls;
}

#define WRAP(name, parameters, arguments) \
    static struct Counter count_##name; \
    static void counted_##name parameters { \
        uint64_t before = current_instructions(); \
        name arguments; \
        finish(&count_##name, before); \
    }

WRAP(CGContextClipToRect, (CGContextRef ctx, CGRect rect), (ctx, rect))
WRAP(CGContextClipToRects, (CGContextRef ctx, const CGRect *rects, size_t count), (ctx, rects, count))
WRAP(CGContextClip, (CGContextRef ctx), (ctx))
WRAP(CGContextEOClip, (CGContextRef ctx), (ctx))
WRAP(CGContextDrawImage, (CGContextRef ctx, CGRect rect, CGImageRef image), (ctx, rect, image))
WRAP(CGContextFillRect, (CGContextRef ctx, CGRect rect), (ctx, rect))
WRAP(CGContextDrawPath, (CGContextRef ctx, CGPathDrawingMode mode), (ctx, mode))

#define REPORT(name) \
    fprintf(stderr, "VOXPROBE_CG api=%s calls=%llu instructions=%llu counter_failed=%d\n", \
        #name, (unsigned long long)count_##name.calls, \
        (unsigned long long)count_##name.instructions, counter_failed)
static void report(void) {
    REPORT(CGContextClipToRect); REPORT(CGContextClipToRects);
    REPORT(CGContextClip); REPORT(CGContextEOClip); REPORT(CGContextDrawImage);
    REPORT(CGContextFillRect); REPORT(CGContextDrawPath);
}
__attribute__((constructor)) static void initialize(void) { atexit(report); }
#define INTERPOSE(name) {(const void *)counted_##name, (const void *)name}
__attribute__((used)) static struct { const void *replacement, *replacee; }
interposers[] __attribute__((section("__DATA,__interpose"))) = {
    INTERPOSE(CGContextClipToRect), INTERPOSE(CGContextClipToRects),
    INTERPOSE(CGContextClip), INTERPOSE(CGContextEOClip), INTERPOSE(CGContextDrawImage),
    INTERPOSE(CGContextFillRect), INTERPOSE(CGContextDrawPath),
};
