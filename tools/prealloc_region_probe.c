// Diagnostic only: successful anonymous RW mapping capacities and unmaps.
// These are virtual mapping events, not malloc samples or resident-byte counts.
// Inject into a production browser with DYLD_INSERT_LIBRARIES. The default
// process basename is Vox, so an inheriting Python memory guard cannot claim
// the output file before the browser starts. Override VOX_REGION_SAMPLE_PROCESS
// only for another explicit diagnostic target. MAP_FIXED arena discards are
// excluded; mapping capacities do not establish live allocations or RSS.
// VOX_REGION_SAMPLE_OUT is required. VOX_REGION_SAMPLE_TRIGGER optionally gates
// events on an existing file; VOX_REGION_MIN_BYTES defaults to 256 KiB.
#include <sys/mman.h>
#include <sys/stat.h>
#include <mach-o/dyld.h>
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

static int output = -1;
static size_t minimum = 256 * 1024;
static const char *trigger;
static __thread int busy;

static void image_added(const struct mach_header *header, intptr_t slide) {
    (void)slide;
    if (output < 0) return;
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        if (_dyld_get_image_header(i) != header) continue;
        char line[4096];
        int n = snprintf(line, sizeof(line), "# image %p %s\n", (void *)header, _dyld_get_image_name(i));
        if (n > 0 && n < (int)sizeof(line)) write(output, line, (size_t)n);
        break;
    }
}

__attribute__((constructor)) static void initialize(void) {
    const char *path = getenv("VOX_REGION_SAMPLE_OUT");
    if (!path) return;
    char executable[PATH_MAX];
    uint32_t executable_size = sizeof(executable);
    if (_NSGetExecutablePath(executable, &executable_size)) return;
    const char *basename = strrchr(executable, '/');
    basename = basename ? basename + 1 : executable;
    const char *target = getenv("VOX_REGION_SAMPLE_PROCESS");
    if (!target) target = "Vox";
    if (strcmp(basename, target)) return;
    const char *bytes = getenv("VOX_REGION_MIN_BYTES");
    if (bytes && strtoull(bytes, 0, 10)) minimum = strtoull(bytes, 0, 10);
    trigger = getenv("VOX_REGION_SAMPLE_TRIGGER");
    busy = 1;
    output = open(path, O_CREAT | O_EXCL | O_WRONLY | O_APPEND, 0600);
    if (output >= 0) {
        char line[PATH_MAX + 80];
        int n = snprintf(line, sizeof(line), "# executable %d %s\n", getpid(), executable);
        if (n > 0 && n < (int)sizeof(line)) write(output, line, (size_t)n);
        _dyld_register_func_for_add_image(image_added);
    }
    busy = 0;
}

static int enabled(void) {
    if (output < 0 || busy) return 0;
    if (trigger) {
        struct stat info;
        if (stat(trigger, &info)) return 0;
    }
    return 1;
}

static void *traced_mmap(void *address, size_t size, int protection, int flags, int descriptor, off_t offset) {
    void *result = mmap(address, size, protection, flags, descriptor, offset);
    if (result == MAP_FAILED || size < minimum || !(flags & MAP_ANON)
        || flags & MAP_FIXED || !(protection & PROT_WRITE) || !enabled()) return result;
    busy = 1;
    void *frames[32];
    int count = backtrace(frames, 32);
    char line[2048];
    int n = snprintf(line, sizeof(line), "M %p %zu %p", result, size, (void *)pthread_self());
    for (int i = 1; i < count && n > 0 && n < (int)sizeof(line) - 32; ++i)
        n += snprintf(line + n, sizeof(line) - (size_t)n, " %p", frames[i]);
    if (n > 0 && n < (int)sizeof(line) - 1) {
        line[n++] = '\n';
        write(output, line, (size_t)n);
    }
    busy = 0;
    return result;
}

static int traced_munmap(void *address, size_t size) {
    int result = munmap(address, size);
    if (result || size < minimum || !enabled()) return result;
    busy = 1;
    char line[128];
    int n = snprintf(line, sizeof(line), "U %p %zu\n", address, size);
    if (n > 0 && n < (int)sizeof(line)) write(output, line, (size_t)n);
    busy = 0;
    return result;
}

__attribute__((used)) static struct { const void *replacement, *original; } replacements[]
    __attribute__((section("__DATA,__interpose"))) = {
        { (const void *)traced_mmap, (const void *)mmap },
        { (const void *)traced_munmap, (const void *)munmap },
    };
