// SPDX-License-Identifier: BSD-2-Clause
module webassembly

#include "@DIR/value_stack_host.h"

fn C.vox_wasm_stack_map(uint) voidptr
fn C.vox_wasm_stack_unmap(voidptr, uint)
fn C.vox_wasm_region_pool_get() voidptr
fn C.vox_wasm_region_pool_set(voidptr)

// The pinned pool is intentionally leaked at thread exit. Keep its record
// outside the V GC as well; it owns only OS mappings, never managed cells.
fn binary_stack_region_pool() &BinaryStackRegionPool {
	pointer := C.vox_wasm_region_pool_get()
	if pointer != unsafe { nil } {
		return unsafe { &BinaryStackRegionPool(pointer) }
	}
	pool := unsafe { &BinaryStackRegionPool(C.calloc(1, sizeof(BinaryStackRegionPool))) }
	assert pool != unsafe { nil }
	C.vox_wasm_region_pool_set(pool)
	return pool
}

fn allocate_binary_stack_region() &BinaryMachineValue {
	region := C.vox_wasm_stack_map(binary_value_stack_reservation_size)
	$if windows {
		assert region != unsafe { nil }
	} $else {
		assert u64(region) != u64(-1)
	}
	return unsafe { &BinaryMachineValue(region) }
}

fn free_binary_stack_region(region &BinaryMachineValue) {
	C.vox_wasm_stack_unmap(region, binary_value_stack_reservation_size)
}
