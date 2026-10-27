// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Memory.{h,cpp}.
@[has_globals]
module webassembly

import libgc

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
	storage             ExternalMemoryStorage
	shared              bool
	resizable           bool
	max_byte_length     u64
	detached_generation u64
	detached            bool
	realm               string
	frozen              bool
	detach_key          string
}

pub struct ExternalMemoryStorage {
pub:
	owner        &Memory = unsafe { nil }
	handle       libgc.ExternalEntityTableHandle
	fixed_size   ?uint
	generation   u64
	fixed_length bool
}

// LibJS DataBlock::ExternalPrimitiveStorage: the handle resolves the current
// caged allocation; fixed buffers retain their captured byte length.
pub fn (storage ExternalMemoryStorage) data() &u8 {
	return libgc.PrimitiveStorage.the().data(storage.handle)
}

pub fn (storage ExternalMemoryStorage) byte_length() uint {
	return storage.fixed_size or { libgc.PrimitiveStorage.the().size(storage.handle) }
}

pub fn (storage ExternalMemoryStorage) capacity() uint {
	return libgc.PrimitiveStorage.the().capacity(storage.handle)
}

pub fn (storage ExternalMemoryStorage) offset() uint {
	return libgc.PrimitiveStorage.the().offset(storage.handle)
}

pub fn (storage ExternalMemoryStorage) bytes() BinaryMachineBytes {
	return BinaryMachineBytes{ data: storage.data(), size: storage.byte_length() }
}

pub fn (buffer &MemoryBuffer) bytes() BinaryMachineBytes {
	if buffer.detached { return BinaryMachineBytes{} }
	return buffer.storage.bytes()
}

pub fn (buffer &MemoryBuffer) byte_length() uint { return buffer.bytes().size }

pub fn (buffer &MemoryBuffer) read_bytes(offset uint, count uint) []u8 {
	bytes := buffer.bytes()
	assert offset <= bytes.size && count <= bytes.size - offset
	// A V byte-vector result uses int lengths; the memory span itself uses size_t.
	assert count <= uint(max_int)
	mut result := []u8{len: int(count)}
	if count > 0 { unsafe { C.memcpy(result.data, bytes.data + offset, count) } }
	return result
}

@[heap]
pub struct MemoryBufferCache {
pub:
	memory &Memory
pub mut:
	primary_realm       string
	primary_buffer      &MemoryBuffer = unsafe { nil }
	live_buffer_objects []&MemoryBuffer
}

__global memory_buffer_caches_ = []&MemoryBufferCache{}

@[heap]
pub struct Memory {
pub:
	maximum          ?u32
	shared           bool
	cache_           &WebAssemblyCache
	address_type_    AddressType
	declared_maximum ?u64
mut:
	address_   u64
	generation u64
}

pub fn Memory.construct(descriptor MemoryDescriptor) !&Memory {
	return memory_create_with_cache(get_cache(), descriptor)
}

pub fn Memory.create(descriptor MemoryDescriptor) !&Memory {
	return Memory.construct(descriptor)
}

fn memory_create_with_cache(cache &WebAssemblyCache, descriptor MemoryDescriptor) !&Memory {
	if maximum := descriptor.maximum {
		if maximum < descriptor.initial {
			return error('RangeError: Initial is larger than maximum.')
		}
	} else if descriptor.shared {
		return error('TypeError: Maximum has to be specified for shared memory.')
	}
	limits := WasmLimits{
		minimum: descriptor.initial
		maximum: if maximum := descriptor.maximum {
			?u64(u64(maximum))
		} else {
			none
		}
	}
	mut store := cache.abstract_machine_.store()
	address := store.allocate_memory(limits) or { return error('TypeError: Wasm Memory allocation failed') }
	return memory_wrap_store_address(cache, address, descriptor.shared)
}

fn memory_wrap_store_address(cache &WebAssemblyCache, address u64, is_shared bool) &Memory {
	instance := cache.abstract_machine_.store().get_memory(address) or { panic('missing actual memory instance') }
	limits := instance.type_()
	mut runtime_maximum := ?u32(none)
	if maximum := limits.maximum {
		limit := if maximum > u64(maximum_pages) {
			u64(maximum_pages)
		} else {
			maximum
		}
		runtime_maximum = u32(limit)
	}
	memory := &Memory{
		maximum:          runtime_maximum
		shared:           is_shared
		cache_:           cache
		address_type_:    limits.address_type
		declared_maximum: limits.maximum
		address_:         address
	}
	assert cache.get_memory_instance(address) == none
	unsafe {
		cache.add_memory_instance(address, memory)
	}
	mut actual := unsafe { &BinaryMachineMemoryInstance(instance) }
	cache_handle := voidptr(cache)
	actual.successful_grow_hook = fn [cache_handle, address] () {
		cache := unsafe { &WebAssemblyCache(cache_handle) }
		mut object := cache.get_memory_instance(address) or { panic('missing source memory wrapper') }
		object.refresh_the_memory_buffer()
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
	return memory.address_
}

pub fn (memory &Memory) machine_instance() &BinaryMachineMemoryInstance {
	return memory.cache_.abstract_machine_.store().get_memory(memory.address()) or { panic('missing actual memory instance') }
}

pub fn (memory &Memory) size_pages() u32 {
	return u32(memory.machine_instance().size() / uint(page_size))
}

pub fn (memory &Memory) wasm_type() WasmLimits {
	return memory.machine_instance().type_()
}

pub fn (memory &Memory) is_shared() bool {
	return memory.shared
}

pub fn (memory &Memory) cache() &WebAssemblyCache {
	return memory.cache_
}

pub fn (mut memory Memory) grow(delta u32) !u32 {
	previous := memory.size_pages()
	mut instance := memory.machine_instance()
	if !instance.grow(uint(delta) * uint(page_size), .no, .yes) {
		return error('RangeError: Memory.grow() grows past the stated limit of the memory instance')
	}
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
	if memory.shared {
		canonical := memory.cache().get_memory_instance(memory.address()) or { panic('missing source shared memory wrapper') }
		buffer := buffer_object_for_realm(realm, canonical)
		set_buffer_object_for_realm(realm, &memory, buffer)
		return buffer
	}
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
	max_pages := memory.machine_instance().type_().maximum or { u64(maximum_pages) }
	assert max_pages <= u64(-1) / u64(page_size)
	replacement := create_a_resizable_memory_buffer_for_realm(realm, &memory, max_pages * u64(page_size))!
	if !memory.shared {
		unsafe {
			current.detached = true
		}
	}
	set_buffer_object_for_realm(realm, &memory, replacement)
	return replacement
}

fn (memory &Memory) make_buffer(realm string, resizable bool) &MemoryBuffer {
	return &MemoryBuffer{
		storage:             external_memory_storage(memory, !resizable)
		shared:              memory.shared
		resizable:           resizable
		max_byte_length:     0
		detached_generation: memory.generation
		realm:               realm
		frozen:              memory.shared
		detach_key:          if !memory.shared || resizable { 'WebAssembly.Memory' } else { '' }
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

pub fn memory_buffer_caches() []&MemoryBufferCache {
	return memory_buffer_caches_.clone()
}

pub fn prune_memory_buffer_cache(mut cache MemoryBufferCache) {
	cache.live_buffer_objects = cache.live_buffer_objects.filter(!isnil(it))
}

pub fn prune_memory_buffer_caches() {
	memory_buffer_caches_ = memory_buffer_caches_.filter(!isnil(it.memory))
}

pub fn memory_buffer_cache_for(memory &Memory) &MemoryBufferCache {
	prune_memory_buffer_caches()
	for cache in memory_buffer_caches_ {
		if voidptr(cache.memory) == voidptr(memory) { return cache }
	}
	cache := &MemoryBufferCache{
		memory: memory
	}
	memory_buffer_caches_ << cache
	return cache
}

pub fn external_memory_storage(memory &Memory, fixed_length bool) ExternalMemoryStorage {
	return ExternalMemoryStorage{
		owner:        memory
		handle:       memory.machine_instance().data().primitive_storage_handle()
		fixed_size:   if fixed_length { ?uint(memory.machine_instance().size()) } else { none }
		generation:   memory.generation
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
	for buffer in cache.live_buffer_objects {
		if buffer.realm == realm { return buffer }
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
	prune_memory_buffer_cache(mut cache)
	for index, existing in cache.live_buffer_objects {
		if existing.realm == realm {
			cache.live_buffer_objects[index] = buffer
			return
		}
	}
	cache.live_buffer_objects << buffer
}

pub fn refresh_buffer_object(mut memory Memory, buffer &MemoryBuffer) {
	if !buffer.resizable {
		if !buffer.shared {
			unsafe {
				buffer.detached = true
				buffer.storage = ExternalMemoryStorage{}
			}
		}
		replacement := create_a_fixed_length_memory_buffer_for_realm(buffer.realm, &memory)
		set_buffer_object_for_realm(buffer.realm, &memory, replacement)
		return
	}
	unsafe {
		buffer.storage = external_memory_storage(&memory, false)
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
	for buffer in cache.live_buffer_objects {
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
	return cache.live_buffer_objects.any(voidptr(it) == voidptr(buffer))
}
