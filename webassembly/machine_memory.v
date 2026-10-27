// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.{h,cpp}: MemoryInstance.
module webassembly

import math

pub const machine_wasm32_max_pages = u64(1) << 16
// Source compiled memory64 accesses still narrow addresses to i32.
pub const machine_wasm64_max_pages = machine_wasm32_max_pages
pub const machine_default_memory_reservation_size = uint(16 * 1024 * 1024)
pub const machine_wasm32_guarded_reservation_size = u64(2) * (machine_wasm32_max_pages * u64(page_size)) + u64(page_size)

pub enum BinaryMachineGrowType {
	no
	yes
}

pub enum BinaryMachineInhibitGrowCallback {
	no
	yes
}

fn machine_size_from_page_count(pages u64) !uint {
	if pages > u64(uint(-1)) / u64(page_size) { return machine_memory_allocation_error() }
	return uint(pages) * uint(page_size)
}

fn machine_maximum_memory_size(type_ WasmLimits) !uint {
	supported_max_pages := if type_.address_type == .i32 {
		machine_wasm32_max_pages
	} else {
		machine_wasm64_max_pages
	}
	max_pages := math.min(type_.maximum or { supported_max_pages }, supported_max_pages)
	return machine_size_from_page_count(max_pages)
}

fn machine_initial_memory_reservation_size(type_ WasmLimits) !uint {
	maximum_size := machine_maximum_memory_size(type_)!
	initial_size := machine_size_from_page_count(type_.minimum)!
	if initial_size > maximum_size { return machine_memory_allocation_error() }
	if type_.address_type == .i32 { return maximum_size }
	if _ := type_.maximum { return maximum_size }
	return initial_size
}

fn machine_grown_memory_reservation_size(current_capacity uint, required_size uint, maximum_size uint) uint {
	mut new_capacity := math.max(current_capacity, machine_default_memory_reservation_size)
	for new_capacity < required_size {
		if new_capacity > maximum_size / 2 {
			new_capacity = maximum_size
			break
		}
		new_capacity *= 2
	}
	return math.min(math.max(new_capacity, required_size), maximum_size)
}

@[heap]
pub struct BinaryMachineMemoryInstance {
mut:
	type_ WasmLimits
	data_ BinaryMachineMemoryBuffer
pub mut:
	successful_grow_hook ?fn ()
}

pub fn BinaryMachineMemoryInstance.create(type_ WasmLimits) !&BinaryMachineMemoryInstance {
	mut instance := &BinaryMachineMemoryInstance{ type_: type_ }
	reserved_capacity := machine_initial_memory_reservation_size(type_)!
	mut guard_size := uint(0)
	if type_.address_type == .i32 {
		guard_size = uint(machine_wasm32_guarded_reservation_size) - reserved_capacity
	}
	instance.data_.try_reserve(reserved_capacity, guard_size) or {
		instance.destroy()
		return err
	}
	initial_size := machine_size_from_page_count(type_.minimum) or {
		instance.destroy()
		return err
	}
	if !instance.grow(initial_size, .no, .no) {
		instance.destroy()
		return error('Failed to grow to requested size')
	}
	return instance
}

pub fn (mut instance BinaryMachineMemoryInstance) destroy() { instance.data_.destroy() }

pub fn (instance &BinaryMachineMemoryInstance) type_() WasmLimits { return instance.type_ }

pub fn (instance &BinaryMachineMemoryInstance) size() uint { return instance.data_.size() }

pub fn (instance &BinaryMachineMemoryInstance) data() &BinaryMachineMemoryBuffer {
	return unsafe { &instance.data_ }
}

pub fn (instance &BinaryMachineMemoryInstance) contains_virtual_address(address voidptr) bool {
	return instance.data_.contains_virtual_address(address)
}

pub fn BinaryMachineMemoryInstance.data_offset() uint {
	return __offsetof(BinaryMachineMemoryInstance, data_)
}

// The source takes bytes, rather than pages. Its callback precedes the type
// minimum update, and zero-byte growth never calls the callback.
pub fn (mut instance BinaryMachineMemoryInstance) grow(size_to_grow uint, grow_type BinaryMachineGrowType, inhibit_callback BinaryMachineInhibitGrowCallback) bool {
	if size_to_grow == 0 { return true }
	maximum_size := machine_maximum_memory_size(instance.type_) or { return false }
	if size_to_grow > uint(-1) - instance.data_.size() { return false }
	new_size := instance.data_.size() + size_to_grow
	if new_size > maximum_size { return false }
	mut new_capacity := instance.data_.capacity()
	if new_size > new_capacity {
		if _ := instance.type_.maximum {
			new_capacity = maximum_size
		} else {
			new_capacity = machine_grown_memory_reservation_size(new_capacity, new_size, maximum_size)
		}
	}
	instance.data_.try_resize_with_capacity(new_size, new_capacity) or { return false }
	if inhibit_callback == .no {
		if hook := instance.successful_grow_hook { hook() }
	}
	if grow_type == .yes {
		instance.type_ = WasmLimits{ address_type: instance.type_.address_type, minimum: instance.type_.minimum + u64(size_to_grow) / u64(page_size), maximum: instance.type_.maximum }
	}
	return true
}
