/* SPDX-License-Identifier: BSD-2-Clause
 * Native thread-local slot and virtual-memory calls for LibWasm ValueStack. */
#ifndef VOX_WASM_VALUE_STACK_HOST_H
#define VOX_WASM_VALUE_STACK_HOST_H
#if defined(_WIN32)
#include <windows.h>
static __declspec(thread) void* vox_wasm_region_pool_slot;
static void* vox_wasm_stack_map(size_t size) { return VirtualAlloc(NULL, size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE); }
static void vox_wasm_stack_unmap(void* region, size_t size) { (void)size; VirtualFree(region, 0, MEM_RELEASE); }
#else
#include <sys/mman.h>
static _Thread_local void* vox_wasm_region_pool_slot;
static void* vox_wasm_stack_map(size_t size) { return mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0); }
static void vox_wasm_stack_unmap(void* region, size_t size) { munmap(region, size); }
#endif
static void* vox_wasm_region_pool_get(void) { return vox_wasm_region_pool_slot; }
static void vox_wasm_region_pool_set(void* pool) { vox_wasm_region_pool_slot = pool; }
#endif
