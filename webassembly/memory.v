// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Memory.{h,cpp}.
module webassembly

pub const page_size = 65_536
pub const maximum_pages = 65_536

pub struct MemoryDescriptor {
pub:
	initial u32
	maximum ?u32
	shared  bool
}

pub struct MemoryBuffer {
pub:
	bytes               []u8
	shared              bool
	resizable           bool
	max_byte_length     u64
	detached_generation u64
}

@[heap]
pub struct Memory {
pub:
	maximum ?u32
	shared  bool
mut:
	data             []u8
	resizable_buffer bool
	generation       u64
}

pub fn Memory.construct(descriptor MemoryDescriptor) !&Memory {
	if descriptor.initial > maximum_pages {
		return error('RangeError: Initial exceeds the WebAssembly memory limit')
	}
	if maximum := descriptor.maximum {
		if maximum < descriptor.initial {
			return error('RangeError: Initial is larger than maximum')
		}
		if maximum > maximum_pages {
			return error('RangeError: Maximum exceeds the WebAssembly memory limit')
		}
	} else if descriptor.shared {
		return error('TypeError: Maximum has to be specified for shared memory')
	}
	return &Memory{
		maximum: descriptor.maximum
		shared:  descriptor.shared
		data:    []u8{len: int(descriptor.initial) * page_size}
	}
}

pub fn (memory &Memory) size_pages() u32 {
	return u32(memory.data.len / page_size)
}

pub fn (mut memory Memory) grow(delta u32) !u32 {
	previous := memory.size_pages()
	new_pages := u64(previous) + u64(delta)
	limit := u64(memory.maximum or { maximum_pages })
	if new_pages > limit || new_pages > maximum_pages {
		return error('RangeError: Memory.grow() grows past the stated limit of the memory instance')
	}
	memory.data << []u8{len: int(delta) * page_size}
	memory.generation++
	return previous
}

pub fn (memory &Memory) buffer() MemoryBuffer {
	return memory.make_buffer(memory.resizable_buffer)
}

pub fn (mut memory Memory) to_fixed_length_buffer() MemoryBuffer {
	memory.resizable_buffer = false
	return memory.make_buffer(false)
}

pub fn (mut memory Memory) to_resizable_buffer() MemoryBuffer {
	memory.resizable_buffer = true
	return memory.make_buffer(true)
}

fn (memory &Memory) make_buffer(resizable bool) MemoryBuffer {
	max_pages := memory.maximum or { maximum_pages }
	return MemoryBuffer{
		bytes:               memory.data.clone()
		shared:              memory.shared
		resizable:           resizable
		max_byte_length:     u64(max_pages) * page_size
		detached_generation: memory.generation
	}
}
