/* SPDX-License-Identifier: BSD-2-Clause
 * LibCore/System.cpp virtual-memory syscall boundary for PrimitiveStorage. */
#ifndef VOX_GC_PRIMITIVE_STORAGE_HOST_H
#define VOX_GC_PRIMITIVE_STORAGE_HOST_H
#include <errno.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include "../platform/native_state.h"
VOX_NATIVE_STATE uintptr_t vox_gc_primitive_storage_cage_base;
static void vox_gc_set_primitive_storage_cage_base(void* value) { vox_gc_primitive_storage_cage_base = (uintptr_t)value; }
static uintptr_t vox_gc_get_primitive_storage_cage_base(void) { return vox_gc_primitive_storage_cage_base; }
static size_t vox_gc_storage_page_size(void) { return (size_t)sysconf(_SC_PAGESIZE); }
static int vox_gc_storage_errno(void) { return errno; }
static const char* vox_gc_storage_error(int code) { return strerror(code); }
static void* vox_gc_reserve_address_space(size_t size) {
    int flags = MAP_PRIVATE | MAP_ANONYMOUS;
#ifdef MAP_NORESERVE
    flags |= MAP_NORESERVE;
#endif
    return mmap(NULL, size, PROT_NONE, flags, -1, 0);
}
static void* vox_gc_commit_memory(void* address, size_t size) {
    return mmap(address, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
}
static void* vox_gc_decommit_memory(void* address, size_t size) {
    int flags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED;
#ifdef MAP_NORESERVE
    flags |= MAP_NORESERVE;
#endif
    return mmap(address, size, PROT_NONE, flags, -1, 0);
}
static int vox_gc_release_address_space(void* address, size_t size) { return munmap(address, size); }
#endif
