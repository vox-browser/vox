module libjs

// Runtime/ArrayBuffer.cpp::CreateSharedByteDataBlock. The pinned source uses
// OwnedBackingStore with a shared flag; its agent event records are pending.
pub fn create_shared_byte_data_block(mut vm VM, size uint, capacity ?uint) !DataBlock {
	block := create_zeroed_owned_data_block(mut vm, size, capacity or { size })!
	return DataBlock.from_owned_store(block.owned or { panic('missing shared backing store') }, true)
}
