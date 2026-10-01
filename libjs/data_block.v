module libjs

// Runtime/ArrayBuffer.h::DataBlock and ArrayBuffer.cpp::CreateByteDataBlock.
// Flat V byte storage replaces GC's caged OwnedBackingStore. Owned storage and
// fixed-length host storage are represented here; ExternalPrimitiveStorage and
// its cage handles remain a separate host/allocator translation.
@[heap]
pub struct ByteBufferStorage {
pub mut:
	bytes []u8
}

pub enum DataBlockKind {
	empty
	owned
	unowned_fixed
}

pub struct DataBlock {
	kind         DataBlockKind
	storage      ?&ByteBufferStorage
	fixed_length usize
pub:
	is_shared bool
}

pub fn DataBlock.from_bytes(bytes []u8, is_shared bool) DataBlock {
	return DataBlock{kind: .owned, storage: &ByteBufferStorage{bytes: bytes.clone()}, is_shared: is_shared}
}

pub fn DataBlock.from_host_buffer(storage &ByteBufferStorage, is_shared bool) DataBlock {
	return DataBlock{kind: .unowned_fixed, storage: storage, fixed_length: usize(storage.bytes.len), is_shared: is_shared}
}

pub fn (block DataBlock) is_empty() bool { return block.kind == .empty }

pub fn (block DataBlock) size() usize {
	if block.kind == .empty { return 0 }
	if block.kind == .unowned_fixed { return block.fixed_length }
	return usize((block.storage or { panic('data block without storage') }).bytes.len)
}

pub fn (block DataBlock) capacity() usize {
	if block.kind == .empty { return 0 }
	if block.kind == .unowned_fixed { return block.fixed_length }
	return usize((block.storage or { panic('data block without storage') }).bytes.cap)
}

pub fn (block DataBlock) external_memory_size() usize {
	return if block.kind == .owned { block.capacity() } else { 0 }
}

fn (block DataBlock) check_range(offset usize, count usize) {
	assert offset <= block.size() && count <= block.size() - offset
}

pub fn (block DataBlock) read_bytes(offset usize, count usize) []u8 {
	block.check_range(offset, count)
	if count == 0 { return []u8{} }
	storage := block.storage or { panic('reading empty data block') }
	return storage.bytes[int(offset)..int(offset + count)].clone()
}

pub fn (mut block DataBlock) overwrite(offset usize, bytes []u8) {
	block.check_range(offset, usize(bytes.len))
	if bytes.len == 0 { return }
	mut storage := block.storage or { panic('writing empty data block') }
	for index, byte in bytes { storage.bytes[int(offset) + index] = byte }
}

pub fn (block DataBlock) shares_storage_with(other DataBlock) bool {
	if block.is_empty() || other.is_empty() { return false }
	a := block.storage or { panic('data block without storage') }
	b := other.storage or { panic('data block without storage') }
	// The upstream test compares the current data pointer, not store identity.
	return a.bytes.data == b.bytes.data
}

pub fn (block DataBlock) copy_to(mut destination DataBlock, source_offset usize, destination_offset usize, count usize) {
	block.check_range(source_offset, count)
	destination.check_range(destination_offset, count)
	if count == 0 { return }
	destination.overwrite(destination_offset, block.read_bytes(source_offset, count))
}

pub fn (mut block DataBlock) move_data(destination_offset usize, source_offset usize, count usize) {
	block.check_range(source_offset, count)
	block.check_range(destination_offset, count)
	if count == 0 || destination_offset == source_offset { return }
	mut storage := block.storage or { panic('moving empty data block') }
	if source_offset < destination_offset && destination_offset < source_offset + count {
		for remaining := count; remaining > 0; remaining-- {
			storage.bytes[int(destination_offset + remaining - 1)] = storage.bytes[int(source_offset + remaining - 1)]
		}
	} else {
		for index := usize(0); index < count; index++ {
			storage.bytes[int(destination_offset + index)] = storage.bytes[int(source_offset + index)]
		}
	}
}

pub fn (mut block DataBlock) try_resize(size usize, zero_fill_new_bytes bool) bool {
	assert block.kind != .empty
	if size > 0x7fffffff { return false }
	mut storage := block.storage or { panic('resizing data block without storage') }
	old_size := storage.bytes.len
	if int(size) <= old_size {
		storage.bytes.trim(int(size))
	} else {
		unsafe { storage.bytes.grow_len(int(size) - old_size) }
		if zero_fill_new_bytes {
			for index in old_size .. int(size) { storage.bytes[index] = 0 }
		}
	}
	// An unowned DataBlock retains the size captured by its constructor, even
	// though the underlying host ByteBuffer can resize through this operation.
	return true
}

pub fn copy_data_block_bytes(mut destination DataBlock, destination_offset usize, source DataBlock, source_offset usize, count usize) {
	if count > 0 { assert !destination.shares_storage_with(source) }
	source.copy_to(mut destination, source_offset, destination_offset, count)
}

pub fn (mut block DataBlock) try_ensure_capacity(capacity usize) bool {
	assert block.kind != .empty
	if capacity > 0x7fffffff { return false }
	mut storage := block.storage or { panic('reserving data block without storage') }
	storage.bytes.ensure_cap(int(capacity))
	return true
}

pub fn create_byte_data_block(mut vm VM, size usize, capacity ?usize) !DataBlock {
	requested_capacity := capacity or { size }
	if size > 9007199254740991 || requested_capacity > 9007199254740991 {
		return vm.throw_error_type(.range_error, .invalid_length, 'array buffer')
	}
	return create_zeroed_owned_data_block(mut vm, size, requested_capacity)
}

// OwnedBackingStore::create_zeroed[_with_capacity] allocation boundary shared
// by CreateByteDataBlock and the direct ArrayBuffer factory.
fn create_zeroed_owned_data_block(mut vm VM, size usize, requested_capacity usize) !DataBlock {
	assert size <= requested_capacity
	// V array lengths/capacities use signed int. Reject unrepresentable backing
	// stores through the source's allocation error, before narrowing or allocating.
	if requested_capacity > 0x7fffffff {
		return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, requested_capacity.str())
	}
	return DataBlock{kind: .owned, storage: &ByteBufferStorage{
		bytes: []u8{len: int(size), cap: int(requested_capacity)}
	}}
}
