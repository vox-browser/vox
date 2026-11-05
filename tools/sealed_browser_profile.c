// Main-thread diagnostic timings for Clang's after-inlining instrumentation.
// Compile this helper separately, without -finstrument-functions.
#include <dlfcn.h>
#include <inttypes.h>
#include <mach/mach_time.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define SLOTS 65536
#define DEPTH 4096
struct Row { void *function; uint64_t calls, inclusive, self, partial; };
struct Frame { struct Row *row; uint64_t start, children; };
static struct Row rows[SLOTS];
static _Thread_local struct Frame frames[DEPTH];
static _Thread_local unsigned depth;
static _Thread_local bool enabled;
static void *root_function;
static unsigned faults;
static bool started, flushed;
static mach_timebase_info_data_t timebase;

static void close_frame(uint64_t now, bool partial) {
    struct Frame frame = frames[--depth];
    uint64_t elapsed = now - frame.start;
    if (frame.children > elapsed) { ++faults; enabled = false; return; }
    ++frame.row->calls;
    frame.row->inclusive += elapsed;
    frame.row->self += elapsed - frame.children;
    frame.row->partial += partial;
    if (depth) frames[depth - 1].children += elapsed;
}

void __cyg_profile_func_enter(void *function, void *caller) {
    (void)caller;
    if (!enabled) return;
    if (depth == DEPTH) { ++faults; enabled = false; return; }
    uintptr_t address = (uintptr_t)function;
    unsigned slot = (unsigned)(((address >> 4) * UINT64_C(11400714819323198485)) >> 48);
    unsigned scanned = 0;
    while (rows[slot].function && rows[slot].function != function) {
        if (++scanned == SLOTS) { ++faults; enabled = false; return; }
        slot = (slot + 1) & (SLOTS - 1);
    }
    rows[slot].function = function;
    frames[depth++] = (struct Frame){ &rows[slot], mach_absolute_time(), 0 };
}

void __cyg_profile_func_exit(void *function, void *caller) {
    (void)caller;
    if (!enabled) return;
    if (!depth && function == root_function) { enabled = false; return; }
    if (!depth || frames[depth - 1].row->function != function) {
        ++faults; enabled = false; return;
    }
    close_frame(mach_absolute_time(), false);
}

static uint64_t ns(uint64_t ticks) {
    return (uint64_t)(((__uint128_t)ticks * timebase.numer) / timebase.denom);
}

static void quoted(const char *text) {
    putchar('"');
    for (const unsigned char *p = (const unsigned char *)text; *p; ++p) {
        if (*p == '"' || *p == '\\') putchar('\\');
        if (*p < 32) printf("\\u%04x", *p); else putchar(*p);
    }
    putchar('"');
}

void vox_cprofile_flush(void) {
    if (!started || flushed) return;
    enabled = false; flushed = true;
    unsigned unfinished = depth;
    uint64_t now = mach_absolute_time();
    while (depth) close_frame(now, true);
    printf("VOX_CPROFILE_META {\"faults\":%u,\"unfinished_frames\":%u}\n", faults, unfinished);
    for (unsigned i = 0; i < SLOTS; ++i) {
        struct Row *r = &rows[i];
        if (!r->calls) continue;
        Dl_info info = {0};
        bool resolved = dladdr(r->function, &info) && info.dli_sname && info.dli_saddr == r->function;
        printf("VOX_CPROFILE {\"calls\":%" PRIu64 ",\"inclusive_ns\":%" PRIu64
               ",\"self_ns\":%" PRIu64 ",\"partial_calls\":%" PRIu64
               ",\"address\":%" PRIuPTR ",\"offset\":%" PRIuPTR ",\"function\":",
               r->calls, ns(r->inclusive), ns(r->self), r->partial,
               (uintptr_t)r->function, (uintptr_t)r->function - (uintptr_t)info.dli_fbase);
        quoted(resolved ? info.dli_sname : "<unresolved>");
        printf(",\"image\":"); quoted(info.dli_fname ? info.dli_fname : "");
        puts("}");
    }
    fflush(stdout);
}

void vox_cprofile_start(void *root) {
    if (started) { ++faults; return; }
    started = true; root_function = root;
    mach_timebase_info(&timebase);
    atexit(vox_cprofile_flush);
    enabled = true;
}
