// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine.h ArgumentsStaticSize and AK::Vector<Value, 3> operations.
module webassembly

#include <stdlib.h>

pub const binary_arguments_static_size = uint(3)

// Actual inline storage moves with its owner; outline allocations transfer
// ownership. The native system allocator uses the exact-size branch of
// AK/kmalloc.cpp (allocator-instrumented source builds).
pub struct BinaryMachineArguments {
mut:
	inline_values [3]BinaryMachineValue
	outline       &BinaryMachineValue = unsafe { nil }
	size_         uint
	capacity_     uint = binary_arguments_static_size
}

pub fn BinaryMachineArguments.from_values(values []BinaryMachineValue) BinaryMachineArguments {
	mut arguments := BinaryMachineArguments{}
	arguments.ensure_capacity(uint(values.len))
	for value in values { arguments.unchecked_append(value) }
	return arguments
}

pub fn (arguments &BinaryMachineArguments) size() uint { return arguments.size_ }

pub fn (arguments &BinaryMachineArguments) capacity() uint { return arguments.capacity_ }

pub fn (mut arguments BinaryMachineArguments) data() &BinaryMachineValue {
	if arguments.outline != unsafe { nil } { return arguments.outline }
	return unsafe { &arguments.inline_values[0] }
}

pub fn (mut arguments BinaryMachineArguments) at(index uint) &BinaryMachineValue {
	assert index < arguments.size_
	return unsafe { arguments.data() + index }
}

// HostFunction receives the source Span<Value>: borrow the actual inline or
// outline slots, preserving size_t length without a V array copy or header.
pub fn (mut arguments BinaryMachineArguments) span() BinaryMachineValueSpan {
	return BinaryMachineValueSpan{ data: arguments.data(), size: arguments.size_ }
}

pub fn (mut arguments BinaryMachineArguments) ensure_capacity(needed uint) {
	if arguments.capacity_ >= needed { return }
	if needed > ~uint(0) / uint(sizeof(BinaryMachineValue)) {
		panic('Source MUST: argument allocation size overflow')
	}
	allocation := unsafe { C.malloc(needed * uint(sizeof(BinaryMachineValue))) }
	if allocation == unsafe { nil } { panic('Source MUST: argument allocation failed') }
	mut next := unsafe { &BinaryMachineValue(allocation) }
	previous := arguments.data()
	for index in uint(0) .. arguments.size_ {
		unsafe { next[index] = previous[index] }
	}
	if arguments.outline != unsafe { nil } { unsafe { C.free(arguments.outline) } }
	arguments.outline = next
	arguments.capacity_ = needed
}

pub fn (mut arguments BinaryMachineArguments) unchecked_append(value BinaryMachineValue) {
	assert arguments.size_ < arguments.capacity_
	unsafe { arguments.data()[arguments.size_] = value }
	arguments.size_++
}

pub fn (mut arguments BinaryMachineArguments) clear_with_capacity() { arguments.size_ = 0 }

pub fn BinaryMachineArguments.move_construct(mut other BinaryMachineArguments) BinaryMachineArguments {
	result := other
	other = BinaryMachineArguments{}
	return result
}

pub fn (mut arguments BinaryMachineArguments) move_assign(mut other BinaryMachineArguments) {
	if unsafe { voidptr(&arguments) == voidptr(&other) } { return }
	arguments.destroy()
	arguments = BinaryMachineArguments.move_construct(mut other)
}

pub fn (mut arguments BinaryMachineArguments) destroy() {
	if arguments.outline != unsafe { nil } { unsafe { C.free(arguments.outline) } }
	arguments = BinaryMachineArguments{}
}

// Configuration.h:178-209. The freelist's outer storage is a V vector header;
// the source limit of sixteen prevents any growth beyond its initial reserve.
pub fn (mut configuration BinaryMachineConfiguration) get_arguments_allocation_if_possible(mut arguments BinaryMachineArguments, max_size uint) {
	if arguments.capacity() != binary_arguments_static_size || max_size <= binary_arguments_static_size {
		return
	}
	for index in 0 .. configuration.call_argument_freelist_.len {
		if configuration.call_argument_freelist_[index].capacity() >= max_size {
			arguments.move_assign(mut configuration.call_argument_freelist_[index])
			configuration.call_argument_freelist_.delete(index)
			return
		}
	}
	if configuration.call_argument_freelist_.len > 0 {
		index := configuration.call_argument_freelist_.len - 1
		arguments.move_assign(mut configuration.call_argument_freelist_[index])
		configuration.call_argument_freelist_.delete(index)
	}
	minimum := configuration.frame().module().cached_minimum_call_record_allocation_size
	arguments.ensure_capacity(if max_size > minimum { max_size } else { minimum })
}

pub fn (mut configuration BinaryMachineConfiguration) release_arguments_allocation(mut arguments BinaryMachineArguments) {
	arguments.clear_with_capacity()
	if arguments.capacity() != binary_arguments_static_size {
		if configuration.call_argument_freelist_.len >= 16 { return }
		configuration.call_argument_freelist_ << BinaryMachineArguments.move_construct(mut arguments)
	}
}
