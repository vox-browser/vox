// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/ValueStack.{h,cpp}.
module webassembly

import math

pub const binary_value_stack_reservation_size = uint(64 * 1024 * 1024)
pub const binary_value_stack_max_values = binary_value_stack_reservation_size / uint(sizeof(BinaryMachineValue))
const binary_value_stack_scan_slack = uint(8)
const binary_value_stack_max_pooled_regions = 4

struct BinaryStackRegionPool {
mut:
	regions [4]&BinaryMachineValue
	count   int
}

pub struct BinaryMachineValueSpan {
pub:
	data &BinaryMachineValue
	size uint
}

pub fn (span BinaryMachineValueSpan) at(index uint) &BinaryMachineValue {
	assert index < span.size
	return unsafe { span.data + index }
}

@[heap]
pub struct BinaryMachineValueStack {
mut:
	base  &BinaryMachineValue
	top   &BinaryMachineValue
	limit &BinaryMachineValue
}

pub fn BinaryMachineValueStack.create() &BinaryMachineValueStack {
	mut pool := binary_stack_region_pool()
	mut region := unsafe { &BinaryMachineValue(nil) }
	if pool.count == 0 {
		region = allocate_binary_stack_region()
	} else {
		pool.count--
		region = pool.regions[pool.count]
	}
	return &BinaryMachineValueStack{ base: region, top: region, limit: unsafe { region + binary_value_stack_max_values } }
}

// V owners call this at their destructor boundary. As upstream, only the four
// pooled mappings are retained and all excess mappings are immediately freed.
pub fn (stack &BinaryMachineValueStack) destroy() {
	mut pool := binary_stack_region_pool()
	if pool.count < binary_value_stack_max_pooled_regions {
		pool.regions[pool.count] = stack.base
		pool.count++
	} else {
		free_binary_stack_region(stack.base)
	}
}

pub fn (stack &BinaryMachineValueStack) size() uint {
	return (uint(stack.top) - uint(stack.base)) / uint(sizeof(BinaryMachineValue))
}

pub fn (stack &BinaryMachineValueStack) is_empty() bool {
	return voidptr(stack.top) == voidptr(stack.base)
}

pub fn (mut stack BinaryMachineValueStack) append(value BinaryMachineValue) {
	assert voidptr(stack.top) != voidptr(stack.limit)
	stack.unchecked_append(value)
}

pub fn (mut stack BinaryMachineValueStack) unchecked_append(value BinaryMachineValue) {
	unsafe {
		*stack.top = value
		stack.top = stack.top + 1
	}
}

pub fn (mut stack BinaryMachineValueStack) take_last() BinaryMachineValue {
	assert voidptr(stack.top) != voidptr(stack.base)
	return stack.unsafe_take_last()
}

pub fn (mut stack BinaryMachineValueStack) unsafe_take_last() BinaryMachineValue {
	unsafe {
		stack.top = stack.top - 1
		return *stack.top
	}
}

pub fn (stack &BinaryMachineValueStack) last() &BinaryMachineValue {
	return unsafe { stack.top - 1 }
}

pub fn (stack &BinaryMachineValueStack) unsafe_last() &BinaryMachineValue { return stack.last() }

pub fn (stack &BinaryMachineValueStack) data() &BinaryMachineValue { return stack.base }

pub fn (stack &BinaryMachineValueStack) begin() &BinaryMachineValue { return stack.base }

pub fn (stack &BinaryMachineValueStack) end() &BinaryMachineValue { return stack.top }

pub fn (stack &BinaryMachineValueStack) span() BinaryMachineValueSpan {
	return BinaryMachineValueSpan{ data: stack.base, size: stack.size() }
}

pub fn (mut stack BinaryMachineValueStack) shrink(new_size uint, _ bool) {
	assert new_size <= stack.size()
	stack.top = unsafe { stack.base + new_size }
}

pub fn (mut stack BinaryMachineValueStack) restore_size(size uint) {
	assert size <= binary_value_stack_max_values
	stack.top = unsafe { stack.base + size }
}

pub fn (mut stack BinaryMachineValueStack) reset_and_clear() {
	stack.top = stack.base
	for i in uint(0) .. binary_value_stack_scan_slack {
		unsafe { stack.base[i] = BinaryMachineValue.from_i32(0) }
	}
}

pub fn (mut stack BinaryMachineValueStack) remove(index uint, count uint) {
	assert index + count <= stack.size()
	unsafe {
		C.memmove(stack.base + index, stack.base + index + count, (stack.size() - index - count) * uint(sizeof(BinaryMachineValue)))
		stack.top = stack.top - count
	}
}

pub fn (stack &BinaryMachineValueStack) ensure_capacity(total uint) {
	assert total <= binary_value_stack_max_values
}

pub fn (mut stack BinaryMachineValueStack) allocate(count uint) &BinaryMachineValue {
	assert (uint(stack.limit) - uint(stack.top)) / uint(sizeof(BinaryMachineValue)) >= count
	result := stack.top
	stack.top = unsafe { stack.top + count }
	return result
}

pub fn (stack &BinaryMachineValueStack) mark() &BinaryMachineValue { return stack.top }

pub fn (mut stack BinaryMachineValueStack) release_to(mark &BinaryMachineValue) {
	assert uint(mark) >= uint(stack.base) && uint(mark) <= uint(stack.top)
	stack.top = unsafe { mark }
}

pub fn (stack &BinaryMachineValueStack) conservative_scan_size() uint {
	return math.min(stack.size() + binary_value_stack_scan_slack, binary_value_stack_max_values)
}

// The source compiler reads these pointer members by ABI offset.
pub fn BinaryMachineValueStack.base_offset() uint {
	return __offsetof(BinaryMachineValueStack, base)
}

pub fn BinaryMachineValueStack.top_offset() uint {
	return __offsetof(BinaryMachineValueStack, top)
}
