module main

import gg
import html
import math
import os
import platform

fn test_profiled_half_upload_owns_pixels_and_preserves_larger_upload_history() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
	path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies/fbe3994f267a5bfabc1f8856b9adcce31ba8350b3853265605ecbeadc6a52d12')
	bytes := os.read_bytes(path)!
	image := app.create_image_from_resource_bytes(path, bytes)!
	previous := png_decode_scope.scope
	defer { set_chromium_image_decode_scope(previous) }
	set_chromium_image_decode_scope(0)
	first := app.sampled_profiled_webp_decode(path, &image, 269, 151) or { panic('half upload') }
	assert first.image.width == 390 && first.image.height == 219 && !first.gpu_mips
	before := unsafe { (&u8(first.image.data)).vbytes(390 * 219 * 4).clone() }
	mut scratch := platform.begin_thread_scratch('profiled WebP upload lifetime regression')
	_ = []u8{len: 1024 * 1024, init: 197}
	scratch.finish()
	assert unsafe { (&u8(first.image.data)).vbytes(before.len) } == before
	reused := app.sampled_profiled_webp_decode(path, &image, 300, 180) or { panic('reuse') }
	assert reused.image.id == first.image.id && !reused.gpu_mips
	full := app.sampled_profiled_webp_decode(path, &image, 780, 438) or { panic('larger upload') }
	assert full.image.id == image.id && full.gpu_mips
	after := app.sampled_profiled_webp_decode(path, &image, 269, 151) or { panic('full reuse') }
	assert after.image.id == image.id && after.gpu_mips
	set_chromium_image_decode_scope(1)
	separate := app.sampled_profiled_webp_decode(path, &image, 269, 151) or { panic('new scope') }
	assert separate.image.id != first.image.id && separate.image.id != image.id
	assert !separate.gpu_mips
	assert unsafe { (&u8(separate.image.data)).vbytes(before.len) } == before
}

fn test_profiled_upload_rejects_invalid_targets_and_retains_stronger_reduction() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
	path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572')
	bytes := os.read_bytes(path)!
	image := app.create_image_from_resource_bytes(path, bytes)!
	for size in [[f64(0), 102], [f64(-1), 102], [math.nan(), 102], [f64(180), math.inf(1)]] {
		assert app.sampled_profiled_webp_decode(path, &image, size[0], size[1]) == none
	}
	strong := app.sampled_profiled_webp_decode(path, &image, 104, 59) or { panic('existing upload') }
	assert strong.image.id == image.id && strong.gpu_mips
	mut invalid := image
	invalid.nr_channels = 6
	assert app.sampled_profiled_webp_decode(path, &invalid, 180, 102) == none
}
