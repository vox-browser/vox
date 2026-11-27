#ifndef VOX_ARENA_PAGE_RETIREMENT_TEST_H
#define VOX_ARENA_PAGE_RETIREMENT_TEST_H
#include <errno.h>
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
static size_t vox_arena_test_unused_resident_bytes(void *start, size_t bytes) {
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    uintptr_t lo = ((uintptr_t)start + page - 1) / page * page;
    uintptr_t hi = ((uintptr_t)start + bytes) / page * page;
    return hi > lo ? vox_arena_test_resident_bytes((void *)lo, hi - lo) : 0;
}
#if defined(__linux__)
static int vox_arena_test_read_is_blocked(const void *start) {
    int descriptors[2];
    if (pipe(descriptors) != 0) abort();
    // Pipe writes ask the kernel to read the address, without faulting the
    // test process or changing protection on the mapping.
    int blocked = write(descriptors[1], start, 1) == -1 && errno == EFAULT;
    close(descriptors[0]);
    close(descriptors[1]);
    return blocked;
}
#endif
#endif
