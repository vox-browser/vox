// Main-thread diagnostic timings for Clang's after-inlining instrumentation.
// Compile this helper separately, without -finstrument-functions.
#include <dlfcn.h>
#include <inttypes.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define SLOTS 65536
#define DEPTH 4096
struct Row {
    void *function;
    uint64_t calls, inclusive, self, partial, instructions, self_instructions;
    bool selected;
};
struct Frame { struct Row *row; uint64_t start, children, instructions, child_instructions; };
static struct Row rows[SLOTS];
static _Thread_local struct Frame frames[DEPTH];
static _Thread_local unsigned depth;
static _Thread_local bool enabled;
static void *root_function;
static unsigned faults;
static bool started, flushed;
static mach_timebase_info_data_t timebase;
static const char *instruction_functions;
static uint64_t instructions_at_start;

static uint64_t instructions(void) {
    struct rusage_info_v4 usage = {0};
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&usage) || !usage.ri_instructions) {
        ++faults; enabled = false; return 0;
    }
    return usage.ri_instructions;
}

static bool selected_function(void *function) {
    if (!instruction_functions) return true;
    Dl_info info = {0};
    if (!dladdr(function, &info) || !info.dli_sname || info.dli_saddr != function) return false;
    size_t length = strlen(info.dli_sname);
    const char *item = instruction_functions;
    while (*item) {
        const char *end = strchr(item, ',');
        size_t size = end ? (size_t)(end - item) : strlen(item);
        if (size == length && !memcmp(item, info.dli_sname, size)) return true;
        if (!end) break;
        item = end + 1;
    }
    return false;
}

static struct Row *row_for(void *function) {
    uintptr_t address = (uintptr_t)function;
    unsigned slot = (unsigned)(((address >> 4) * UINT64_C(11400714819323198485)) >> 48);
    unsigned scanned = 0;
    while (rows[slot].function && rows[slot].function != function) {
        if (++scanned == SLOTS) { ++faults; enabled = false; return NULL; }
        slot = (slot + 1) & (SLOTS - 1);
    }
    if (!rows[slot].function) {
        rows[slot].function = function;
        rows[slot].selected = selected_function(function);
    }
    return &rows[slot];
}

static void close_frame(uint64_t now, bool partial) {
    struct Frame frame = frames[--depth];
    uint64_t elapsed = now - frame.start;
    if (frame.children > elapsed) { ++faults; enabled = false; return; }
    uint64_t delta = 0;
    if (instruction_functions) {
        uint64_t end = instructions();
        if (end < frame.instructions || end - frame.instructions < frame.child_instructions) {
            ++faults; enabled = false; return;
        }
        delta = end - frame.instructions;
    }
    ++frame.row->calls;
    frame.row->inclusive += elapsed;
    frame.row->self += elapsed - frame.children;
    frame.row->partial += partial;
    frame.row->instructions += delta;
    frame.row->self_instructions += delta - frame.child_instructions;
    if (depth) {
        frames[depth - 1].children += elapsed;
        frames[depth - 1].child_instructions += delta;
    }
}

void __cyg_profile_func_enter(void *function, void *caller) {
    (void)caller;
    if (!enabled) return;
    struct Row *row = row_for(function);
    if (!row || !row->selected) return;
    if (depth == DEPTH) { ++faults; enabled = false; return; }
    uint64_t count = instruction_functions ? instructions() : 0;
    if (enabled) frames[depth++] = (struct Frame){ row, mach_absolute_time(), 0, count, 0 };
}

void __cyg_profile_func_exit(void *function, void *caller) {
    (void)caller;
    if (!enabled) return;
    if (!depth && function == root_function) { enabled = false; return; }
    struct Row *row = row_for(function);
    if (!row || !row->selected) return;
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
    uint64_t end = instruction_functions ? instructions() : 0;
    if (end < instructions_at_start) ++faults;
    uint64_t total = end >= instructions_at_start ? end - instructions_at_start : 0;
    printf("VOX_CPROFILE_META {\"faults\":%u,\"unfinished_frames\":%u,\"pid\":%d,"
           "\"instruction_mode\":%s,\"process_instructions\":%" PRIu64 "}\n",
           faults, unfinished, getpid(), instruction_functions ? "true" : "false", total);
    for (unsigned i = 0; i < SLOTS; ++i) {
        struct Row *r = &rows[i];
        if (!r->calls) continue;
        Dl_info info = {0};
        bool resolved = dladdr(r->function, &info) && info.dli_sname && info.dli_saddr == r->function;
        printf("VOX_CPROFILE {\"calls\":%" PRIu64 ",\"inclusive_ns\":%" PRIu64
               ",\"self_ns\":%" PRIu64 ",\"partial_calls\":%" PRIu64
               ",\"inclusive_instructions\":%" PRIu64 ",\"self_instructions\":%" PRIu64
               ",\"address\":%" PRIuPTR ",\"offset\":%" PRIuPTR ",\"function\":",
               r->calls, ns(r->inclusive), ns(r->self), r->partial,
               r->instructions, r->self_instructions,
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
    instruction_functions = getenv("VOX_CPROFILE_INSTRUCTIONS");
    if (instruction_functions && !*instruction_functions) instruction_functions = NULL;
    if (instruction_functions) instructions_at_start = instructions();
    atexit(vox_cprofile_flush);
    enabled = faults == 0;
}
