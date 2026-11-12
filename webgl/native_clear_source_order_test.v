// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct SourceClearCanvasWitness {
mut:
	calls    int
	pixel    []u8
	readback bool = true
}

fn source_clear_canvas_callback(owner voidptr) {
	mut witness := unsafe { &SourceClearCanvasWitness(owner) }
	witness.calls++
	if !witness.readback { return }
	mut pixel := []u8{len: 4}
	C.vox_gl_read_pixels(0, 0, 1, 1, rgba, unsigned_byte, pixel.len, pixel.data)
	witness.pixel = pixel
}

fn test_source_clear_canvas_hook_runs_once_before_real_gl_and_remains_unconditional() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(1, 1)
		context.native.make_current()
		C.vox_gl_clear_color(0, 0, 0, 1)
		C.vox_gl_clear(0x4000)
		mut witness := &SourceClearCanvasWitness{}
		context.native.bind_canvas_content_changed(voidptr(witness), source_clear_canvas_callback)
		context.clear_color(1, 0, 0, 1)
		other.native.make_current()
		context.clear(0x4000)
		assert witness.calls == 1
		assert witness.pixel == [u8(0), 0, 0, 255]
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
		assert context.needs_to_present()
		assert context.get_error() == no_error
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		C.vox_gl_clear(0xffffffff)
		expected := C.vox_gl_get_error()
		assert expected != no_error
		context.native.present_with_preserved_buffer(true)
		assert !context.needs_to_present()
		witness.calls = 0
		other.native.make_current()
		context.clear(0xffffffff)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert witness.calls == 1
		assert context.needs_to_present()
		assert context.get_error() == expected
		witness.readback = false
		context.lose_context_from_compositor_loss()
		witness.calls = 0
		context.clear(0xffffffff)
		assert witness.calls == 1
	}
}
