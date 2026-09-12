// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Memory.{h,cpp}.
@[has_globals]
module webassembly

pub const page_size = 65_536
pub const maximum_pages = 65_536

pub struct MemoryDescriptor {
pub:
	initial u32
	maximum ?u32
	shared  bool
}

@[heap]
pub struct MemoryBuffer {
pub mut:
	bytes               []u8
	shared              bool
	resizable           bool
	max_byte_length     u64
	detached_generation u64
	detached            bool
	realm               string
}

pub struct ExternalMemoryStorage {
pub:
	bytes        []u8
	generation   u64
	fixed_length bool
}

@[heap]
pub struct MemoryBufferCache {
pub:
	memory &Memory
pub mut:
	primary_realm       string
	primary_buffer      &MemoryBuffer = unsafe { nil }
	live_buffer_objects map[string]&MemoryBuffer
}

__global memory_buffer_caches_ = map[u64]&MemoryBufferCache{}

@[heap]
pub struct Memory {
pub:
	maximum ?u32
	shared  bool
	cache_  &WebAssemblyCache
mut:
	data       []u8
	generation u64
}

pub fn Memory.construct(descriptor MemoryDescriptor) !&Memory {
	return memory_create_with_cache(get_cache(), descriptor)
}

pub fn Memory.create(descriptor MemoryDescriptor) !&Memory {
	return Memory.construct(descriptor)
}

fn memory_create_with_cache(cache &WebAssemblyCache, descriptor MemoryDescriptor) !&Memory {
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
	memory := &Memory{
		maximum: descriptor.maximum
		shared: descriptor.shared
		cache_: cache
		data: []u8{len: int(descriptor.initial) * page_size}
	}
	unsafe {
		cache.add_memory_instance(memory.address(), memory)
	}
	return memory
}

pub fn Memory.construct_impl(descriptor MemoryDescriptor) !&Memory {
	return Memory.construct(descriptor)
}

pub fn Memory.create_for_constructor(realm string, descriptor MemoryDescriptor) !&Memory {
	return memory_create_with_cache(get_cache_for_realm(realm), descriptor)
}

pub fn (memory &Memory) address() u64 {
	return u64(voidptr(memory))
}

pub fn (memory &Memory) size_pages() u32 {
	return u32(memory.data.len / page_size)
}

pub fn (memory &Memory) is_shared() bool {
	return memory.shared
}

pub fn (memory &Memory) cache() &WebAssemblyCache {
	return memory.cache_
}

pub fn (mut memory Memory) grow(delta u32) !u32 {
	previous := memory.size_pages()
	new_pages := u64(previous) + u64(delta)
	limit := u64(memory.maximum or { maximum_pages })
	if new_pages > limit || new_pages > maximum_pages {
		return error('RangeError: Memory.grow() grows past the stated limit of the memory instance')
	}
	memory.data << []u8{len: int(delta) * page_size}
	memory.refresh_the_memory_buffer()
	return previous
}

pub fn (memory &Memory) buffer() &MemoryBuffer {
	return buffer_object_for_realm('default', memory)
}

pub fn (memory &Memory) buffer_object() &MemoryBuffer {
	return memory.buffer()
}

pub fn (mut memory Memory) to_fixed_length_buffer() &MemoryBuffer {
	return memory.to_fixed_length_buffer_for_realm('default')
}

pub fn (mut memory Memory) to_fixed_length_buffer_for_realm(realm string) &MemoryBuffer {
	current := buffer_object_for_realm(realm, &memory)
	if !memory.shared && !current.resizable {
		return current
	}
	replacement := create_a_fixed_length_memory_buffer_for_realm(realm, &memory)
	if !memory.shared {
		unsafe {
			current.detached = true
		}
	}
	set_buffer_object_for_realm(realm, &memory, replacement)
	return replacement
}

pub fn (mut memory Memory) to_resizable_buffer() !&MemoryBuffer {
	return memory.to_resizable_buffer_for_realm('default')
}

pub fn (mut memory Memory) to_resizable_buffer_for_realm(realm string) !&MemoryBuffer {
	current := buffer_object_for_realm(realm, &memory)
	if current.resizable {
		return current
	}
	max_pages := memory.maximum or { maximum_pages }
	replacement := create_a_resizable_memory_buffer_for_realm(realm, &memory, u64(max_pages) * page_size)!
	if !memory.shared {
		unsafe {
			current.detached = true
		}
	}
	set_buffer_object_for_realm(realm, &memory, replacement)
	return replacement
}

fn (memory &Memory) make_buffer(realm string, resizable bool) &MemoryBuffer {
	max_pages := memory.maximum or { maximum_pages }
	return &MemoryBuffer{
		bytes: memory.data.clone()
		shared: memory.shared
		resizable: resizable
		max_byte_length: u64(max_pages) * page_size
		detached_generation: memory.generation
		realm: realm
	}
}

pub fn (mut memory Memory) refresh_the_memory_buffer() {
	memory.generation++
	refresh_buffer_objects(mut memory)
}

pub fn (memory &Memory) create_a_fixed_length_memory_buffer() &MemoryBuffer {
	return create_a_fixed_length_memory_buffer_for_realm('default', memory)
}

pub fn (memory &Memory) create_a_resizable_memory_buffer(max_size u64) !&MemoryBuffer {
	return create_a_resizable_memory_buffer_for_realm('default', memory, max_size)
}

pub fn memory_buffer_caches() map[u64]&MemoryBufferCache {
	return memory_buffer_caches_.clone()
}

pub fn prune_memory_buffer_cache(mut cache MemoryBufferCache) {
	for realm, buffer in cache.live_buffer_objects {
		if isnil(buffer) {
			cache.live_buffer_objects.delete(realm)
		}
	}
}

pub fn prune_memory_buffer_caches() {
	for address, cache in memory_buffer_caches_ {
		if isnil(cache.memory) {
			memory_buffer_caches_.delete(address)
		}
	}
}

pub fn memory_buffer_cache_for(memory &Memory) &MemoryBufferCache {
	prune_memory_buffer_caches()
	if cache := memory_buffer_caches_[memory.address()] {
		return cache
	}
	cache := &MemoryBufferCache{
		memory: memory
		live_buffer_objects: map[string]&MemoryBuffer{}
	}
	memory_buffer_caches_[memory.address()] = cache
	return cache
}

pub fn external_memory_storage(memory &Memory, fixed_length bool) ExternalMemoryStorage {
	return ExternalMemoryStorage{
		bytes: memory.data.clone()
		generation: memory.generation
		fixed_length: fixed_length
	}
}

pub fn create_a_fixed_length_memory_buffer_for_realm(realm string, memory &Memory) &MemoryBuffer {
	return memory.make_buffer(realm, false)
}

pub fn create_a_resizable_memory_buffer_for_realm(realm string, memory &Memory, max_size u64) !&MemoryBuffer {
	if max_size > u64(maximum_pages) * page_size {
		return error('RangeError: Maximum memory length exceeds 65536 * 65536 bytes')
	}
	buffer := memory.make_buffer(realm, true)
	unsafe {
		buffer.max_byte_length = max_size
	}
	return buffer
}

pub fn buffer_object_for_realm(realm string, memory &Memory) &MemoryBuffer {
	mut cache := memory_buffer_cache_for(memory)
	if cache.primary_realm == realm && !isnil(cache.primary_buffer) {
		return cache.primary_buffer
	}
	prune_memory_buffer_cache(mut cache)
	if buffer := cache.live_buffer_objects[realm] {
		return buffer
	}
	buffer := create_a_fixed_length_memory_buffer_for_realm(realm, memory)
	set_buffer_object_for_realm(realm, memory, buffer)
	return buffer
}

pub fn set_buffer_object_for_realm(realm string, memory &Memory, buffer &MemoryBuffer) {
	mut cache := memory_buffer_cache_for(memory)
	if isnil(cache.primary_buffer) || cache.primary_realm == realm {
		cache.primary_realm = realm
		cache.primary_buffer = buffer
		return
	}
	cache.live_buffer_objects[realm] = buffer
}

pub fn refresh_buffer_object(mut memory Memory, buffer &MemoryBuffer) {
	if !buffer.resizable {
		if !buffer.shared {
			unsafe {
				buffer.detached = true
			}
		}
		replacement := create_a_fixed_length_memory_buffer_for_realm(buffer.realm, &memory)
		set_buffer_object_for_realm(buffer.realm, &memory, replacement)
		return
	}
	unsafe {
		buffer.bytes = memory.data.clone()
		buffer.detached_generation = memory.generation
	}
}

pub fn refresh_buffer_objects(mut memory Memory) {
	mut cache := memory_buffer_cache_for(&memory)
	mut buffers := []&MemoryBuffer{}
	if !isnil(cache.primary_buffer) {
		buffers << cache.primary_buffer
	}
	prune_memory_buffer_cache(mut cache)
	for _, buffer in cache.live_buffer_objects {
		if !buffers.any(voidptr(it) == voidptr(buffer)) {
			buffers << buffer
		}
	}
	for buffer in buffers {
		refresh_buffer_object(mut memory, buffer)
	}
}

pub fn memory_has_buffer_object(memory &Memory, buffer &MemoryBuffer) bool {
	mut cache := memory_buffer_cache_for(memory)
	if !isnil(cache.primary_buffer) && voidptr(cache.primary_buffer) == voidptr(buffer) {
		return true
	}
	prune_memory_buffer_cache(mut cache)
	return cache.live_buffer_objects.values().any(voidptr(it) == voidptr(buffer))
}
