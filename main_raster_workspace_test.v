module main

import os
import platform

fn test_raster_workspace_retains_only_final_pixels_and_survives_reuse() {
	bytes := os.read_bytes('Tests/Browser/Brave/expected/fallback-text-items.png')!
	first := browser_decode_stb_raster_bytes(bytes)!
	assert first.width > 0 && first.height > 0
	// Compare repeated decodes after decoder initialization, with input already
	// owned. Inflated scanlines and the stb output must leave with the workspace.
	before := platform.thread_arena_usage().used
	second := browser_decode_stb_raster_bytes(bytes)!
	after := platform.thread_arena_usage().used
	$if prealloc { assert after - before < i64(second.data.len) + 4096 }
	assert first.width == second.width && first.height == second.height
	assert first.native_rows_are_top_down && second.native_rows_are_top_down
	assert first.data == second.data
	assert first.data.any(it != 0)
}

fn test_raster_workspace_exports_readable_decode_errors() {
	mut message := ''
	_ = browser_decode_stb_raster_bytes('invalid image'.bytes()) or {
		message = err.msg()
		unsafe { nil }
	}
	assert message.len > 0
	_ = browser_decode_stb_raster_bytes(os.read_bytes('Tests/Browser/Brave/expected/fallback-text-items.png')!)!
	assert message.len > 0 && message.bytes().all(it >= 32)
}
