module libjs

// Runtime/ArrayBuffer.{h,cpp}: buffer records and storage/detach operations.
// The VM's existing ArrayBuffer interface names its host-resize contract, so
// the concrete translated record uses ArrayBufferObject. Host-created buffers
// select their prototype explicitly; AllocateArrayBuffer uses the realm graph.
pub enum BufferOrder {
	seq_cst
	unordered
}

@[heap]
pub struct ArrayBufferObject {
pub:
	object &Object
mut:
	block DataBlock
pub mut:
	maximum_byte_length ?uint
	detach_key          Value = js_undefined()
}

pub fn ArrayBufferObject.create(mut vm VM, realm &Realm, size uint, prototype &Object) !&ArrayBufferObject {
	owner := OwnedPrimitiveBackingStore.create_zeroed(size) or {
		return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, size.str())
	}
	block := DataBlock.from_owned_store(owner, false)
	return ArrayBufferObject.create_with_data_block(realm, block, prototype)
}

pub fn ArrayBufferObject.create_from_bytes(realm &Realm, bytes []u8, is_shared bool, prototype &Object) &ArrayBufferObject {
	return ArrayBufferObject.create_with_data_block(realm, DataBlock.from_bytes(bytes, is_shared), prototype)
}

pub fn ArrayBufferObject.create_from_host_buffer(realm &Realm, storage &ByteBufferStorage, is_shared bool, prototype &Object) &ArrayBufferObject {
	return ArrayBufferObject.create_with_data_block(realm, DataBlock.from_host_buffer(storage, is_shared), prototype)
}

pub fn ArrayBufferObject.create_with_data_block(realm &Realm, block DataBlock, prototype &Object) &ArrayBufferObject {
	mut object := Object.create(realm, prototype)
	object.class_name = 'ArrayBuffer'
	buffer := &ArrayBufferObject{object: object, block: block}
	object.array_buffer = buffer
	return buffer
}

pub fn (buffer &ArrayBufferObject) byte_length() uint { return buffer.block.size() }

pub fn (buffer &ArrayBufferObject) external_memory_size() uint { return buffer.block.external_memory_size() }

pub fn (buffer &ArrayBufferObject) is_detached() bool { return buffer.block.is_empty() }

pub fn (buffer &ArrayBufferObject) is_fixed_length() bool { return buffer.maximum_byte_length == none }

pub fn (buffer &ArrayBufferObject) max_byte_length() uint {
	return buffer.maximum_byte_length or { panic('fixed buffer has no maximum byte length slot') }
}

pub fn (buffer &ArrayBufferObject) is_shared_array_buffer() bool {
	return !buffer.is_detached() && buffer.block.is_shared
}

pub fn (buffer &ArrayBufferObject) data_block() DataBlock { return buffer.block }

pub fn (mut buffer ArrayBufferObject) set_data_block(block DataBlock) {
	buffer.block.destroy()
	buffer.block = block
}

pub fn (mut buffer ArrayBufferObject) try_resize(size uint, zero_fill_new_bytes bool) bool {
	return buffer.block.try_resize(size, zero_fill_new_bytes)
}

pub fn (mut buffer ArrayBufferObject) try_ensure_capacity(capacity uint) bool {
	return buffer.block.try_ensure_capacity(capacity)
}

pub fn (buffer &ArrayBufferObject) shares_storage_with(other &ArrayBufferObject) bool {
	return buffer.block.shares_storage_with(other.block)
}

pub fn (buffer &ArrayBufferObject) read_bytes(offset uint, count uint) []u8 {
	return buffer.block.read_bytes(offset, count)
}

pub fn (mut buffer ArrayBufferObject) overwrite(offset uint, bytes []u8) {
	buffer.block.overwrite(offset, bytes)
}

// ArrayBuffer.h::move_data forwards to the owned DataBlock operation.
pub fn (mut buffer ArrayBufferObject) move_data(destination_offset uint, source_offset uint, count uint) {
	buffer.block.move_data(destination_offset, source_offset, count)
}

pub fn (buffer &ArrayBufferObject) copy_data_to(mut destination ArrayBufferObject, source_offset uint, destination_offset uint, count uint) {
	buffer.block.copy_to(mut destination.block, source_offset, destination_offset, count)
}

pub fn (mut buffer ArrayBufferObject) detach_buffer() {
	buffer.block.destroy()
}

pub fn (mut buffer ArrayBufferObject) detach_and_take_data_block(mut vm VM) !DataBlock {
	assert !buffer.is_shared_array_buffer()
	if !same_value(buffer.detach_key, js_undefined()) {
		return vm.throw_error_type(.type_error, .detach_key_mismatch, js_undefined().str(), buffer.detach_key.str())
	}
	block := buffer.block
	// Source move(m_data_block) transfers its owner before clearing the variant.
	buffer.block = DataBlock{is_shared: block.is_shared}
	return block
}

pub fn detach_array_buffer(mut vm VM, mut buffer ArrayBufferObject, key ?Value) ! {
	assert !buffer.is_shared_array_buffer()
	supplied_key := key or { js_undefined() }
	if !same_value(buffer.detach_key, supplied_key) {
		return vm.throw_error_type(.type_error, .detach_key_mismatch, supplied_key.str(), buffer.detach_key.str())
	}
	buffer.detach_buffer()
}

pub fn array_buffer_byte_length(buffer &ArrayBufferObject, order BufferOrder) uint {
	// The pinned source's shared-length event-record branch is a FIXME. Its
	// active body reads the retained byte length after checking detachment.
	assert !buffer.is_detached()
	return buffer.byte_length()
}
