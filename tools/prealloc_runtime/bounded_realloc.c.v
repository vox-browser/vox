// Bounded copy used by V's prealloc v_realloc. Measure before allocating the
// destination, since that allocation can advance or replace the current block.
module builtin

fn prealloc_realloc_copy_size(old_data &u8, new_size int) int {
	if old_data == unsafe { nil } || new_size <= 0 {
		return 0
	}
	unsafe {
		mut block := g_memory_block
		for block != nil {
			if old_data >= block.start && old_data < block.current {
				available := int(i64(block.current) - i64(old_data))
				return if available < new_size { available } else { new_size }
			}
			block = block.previous
		}
	}
	// Preserve V's handling of pointers not owned by the current block chain.
	return new_size
}
