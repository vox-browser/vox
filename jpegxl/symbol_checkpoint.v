// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct SymbolCheckpoint {
	lz77_enabled   bool
	window         []u32
	decoded        u32
	copy_position  u32
	to_copy        u32
	ans_state      u32
	repeat_error   bool
	overflow_error bool
}

// Save only the ring positions a bounded speculative read may overwrite. The
// BitReader cursor is checkpointed separately by its caller.
pub fn (symbols &SymbolReader) checkpoint(max_rewind int) !SymbolCheckpoint {
	if max_rewind < 0 || max_rewind > lz77_window_size {
		return error('Invalid JPEG XL entropy checkpoint bound')
	}
	mut window := []u32{}
	if symbols.lz77_enabled {
		window = []u32{len: max_rewind}
		for i in 0 .. max_rewind {
			offset := int((symbols.lz77.decoded + u32(i)) & lz77_window_mask)
			if offset < symbols.lz77.window.len { window[i] = symbols.lz77.window[offset] }
		}
	}
	return SymbolCheckpoint{
		lz77_enabled:   symbols.lz77_enabled
		window:         window
		decoded:        symbols.lz77.decoded
		copy_position:  symbols.lz77.copy_position
		to_copy:        symbols.lz77.to_copy
		ans_state:      symbols.ans.state
		repeat_error:   symbols.repeat_error
		overflow_error: symbols.overflow_error
	}
}

pub fn (mut symbols SymbolReader) restore(checkpoint SymbolCheckpoint) ! {
	if symbols.lz77_enabled != checkpoint.lz77_enabled {
		return error('JPEG XL entropy checkpoint type mismatch')
	}
	if symbols.lz77_enabled {
		rewind := symbols.lz77.decoded - checkpoint.decoded
		if u64(rewind) > u64(checkpoint.window.len) {
			return error('JPEG XL entropy checkpoint rewind exceeds bound')
		}
		for i in 0 .. int(rewind) {
			offset := int((checkpoint.decoded + u32(i)) & lz77_window_mask)
			if offset >= symbols.lz77.window.len {
				return error('JPEG XL entropy checkpoint history mismatch')
			}
		}
		for i in 0 .. int(rewind) {
			offset := int((checkpoint.decoded + u32(i)) & lz77_window_mask)
			symbols.lz77.window[offset] = checkpoint.window[i]
		}
		symbols.lz77.decoded = checkpoint.decoded
		symbols.lz77.copy_position = checkpoint.copy_position
		symbols.lz77.to_copy = checkpoint.to_copy
	}
	symbols.ans.state = checkpoint.ans_state
	symbols.repeat_error = checkpoint.repeat_error
	symbols.overflow_error = checkpoint.overflow_error
}
