#ifndef VOX_ARENA_PAGE_RETIREMENT_TEST_H
#define VOX_ARENA_PAGE_RETIREMENT_TEST_H
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
static size_t vox_arena_test_resident_bytes(void *start, size_t bytes) {
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    uintptr_t lo = (uintptr_t)start / page * page;
    size_t pages = ((uintptr_t)start + bytes - lo + page - 1) / page;
    unsigned char *residency = calloc(pages, 1);
    if (!residency) abort();
#if defined(__APPLE__)
    int result = mincore((void *)lo, pages * page, (char *)residency);
#else
    int result = mincore((void *)lo, pages * page, residency);
#endif
    if (result) abort();
    size_t resident = 0;
    for (size_t i = 0; i < pages; i++) if (residency[i] & 1) resident += page;
    free(residency);
    return resident;
}
#endif
