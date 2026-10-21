#ifndef VOX_ARENA_PAGE_RETIREMENT_H
#define VOX_ARENA_PAGE_RETIREMENT_H
#include <stdint.h>
#include <stddef.h>
#include <sys/mman.h>
#include <unistd.h>

// The arena has already invalidated every allocation in this mapping. Preserve
// its address reservation and allocator metadata, but discard complete payload
// pages. Darwin's MADV_DONTNEED alone leaves dirty pages physically charged.
static int vox_retire_empty_arena_pages(void *start, size_t bytes) {
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0 || !start) return 0;
    uintptr_t page = (uintptr_t)page_size;
    uintptr_t lo = ((uintptr_t)start + page - 1) / page * page;
    uintptr_t hi = ((uintptr_t)start + bytes) / page * page;
    if (hi <= lo) return 0;
#if defined(__APPLE__)
    return mmap((void *)lo, hi - lo, PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) == MAP_FAILED ? -1 : 0;
#elif defined(__linux__)
    return madvise((void *)lo, hi - lo, MADV_DONTNEED);
#else
    return 0;
#endif
}
#endif
