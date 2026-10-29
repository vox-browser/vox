module main

fn test_prealloc_realloc_nil_allocates_writable_storage() {
	$if !prealloc { panic('This regression requires -prealloc') }
	unsafe {
		memory := v_realloc(nil, 128)
		assert memory != nil
		for i in 0 .. 128 { memory[i] = u8(i) }
		for i in 0 .. 128 { assert memory[i] == u8(i) }
	}
}

fn test_prealloc_realloc_growth_preserves_the_old_prefix() {
	unsafe {
		old := malloc(16)
		for i in 0 .. 16 { old[i] = u8(i + 91) }
		grown := v_realloc(old, 8192)
		for i in 0 .. 16 { assert grown[i] == u8(i + 91) }
		grown[8191] = 47
		assert grown[8191] == 47
	}
}

fn test_prealloc_realloc_shrink_preserves_the_retained_prefix() {
	unsafe {
		old := malloc(64)
		for i in 0 .. 64 { old[i] = u8(i + 11) }
		shrunk := v_realloc(old, 7)
		for i in 0 .. 7 { assert shrunk[i] == u8(i + 11) }
	}
}

fn test_prealloc_realloc_reads_from_a_previous_arena_block() {
	unsafe {
		old := malloc(16)
		for i in 0 .. 16 { old[i] = u8(i + 31) }
		// Force a larger block than the allocator's 16 MiB default before
		// reallocating the pointer from the preceding block.
		padding := malloc(24 * 1024 * 1024)
		padding[0] = 9
		grown := v_realloc(old, 24 * 1024 * 1024)
		for i in 0 .. 16 { assert grown[i] == u8(i + 31) }
		assert padding[0] == 9
	}
}
