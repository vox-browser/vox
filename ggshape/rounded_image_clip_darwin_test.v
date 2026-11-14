module ggshape

import crypto.sha256
import platform

#include "@DIR/rounded_image_clip_test.h"

fn C.vox_test_rounded_image_clip(pixels &u8, size int, scale int) int

fn test_rounded_image_clip_matches_brave_coverage() {
	mask := rounded_image_clip_mask(16, 16, 8) or { panic('clip mask failed') }
	// Alpha coverage recovered from the immutable black-image Brave fixture.
	assert sha256.hexhash(mask.bytestr()) == '7c7050965ded24b8529d90434c1262be465ebc48424cebbf082c5b1cbca3ea11'
	mut pixels := []u8{len: 16 * 16 * 4}
	assert C.vox_test_rounded_image_clip(pixels.data, 16, 1) == 1
	assert sha256.hexhash(pixels.bytestr()) == '8eb655522e3232c5423a82da8b59f4a95d65c283b54060f84514765fb2b28320'
}

fn test_rounded_image_clip_rejects_unbounded_allocations() {
	assert rounded_image_clip_mask(0, 16, 8) == none
	assert rounded_image_clip_mask(16, 0, 8) == none
	assert rounded_image_clip_mask(1024 * 1024 + 1, 2, 8) == none
	assert rounded_image_clip_mask(16, 16, 0) == none
}

fn test_retina_rounded_image_clip_cache_survives_frame_scratch() {
	mut first := []u8{len: 32 * 32 * 4}
	mut second := first.clone()
	mut scratch := platform.begin_thread_scratch('rounded clip construction')
	assert C.vox_test_rounded_image_clip(first.data, 32, 2) == 1
	scratch.finish()
	assert C.vox_test_rounded_image_clip(second.data, 32, 2) == 1
	assert first == second
	// Same black-image Brave fixture, captured at native scale 2.
	assert sha256.hexhash(second.bytestr()) == '81e1d706c3356e5027c40168449bf1f7a2e8d6a9cdc2b10b11896dcbd0d4d07f'
}
