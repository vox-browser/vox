// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct SourceDrawCanvasWitness {
mut:
	calls    int
	pixel    []u8
	readback bool = true
}

fn source_draw_canvas_callback(owner voidptr) {
	mut witness := unsafe { &SourceDrawCanvasWitness(owner) }
	witness.calls++
	if !witness.readback { return }
	mut pixel := []u8{len: 4}
	C.vox_gl_read_pixels(0, 0, 1, 1, rgba, unsigned_byte, pixel.len, pixel.data)
	witness.pixel = pixel
}

fn source_draw_program(mut context WebGLRenderingContext) {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nvoid main(){vec2 p=gl_VertexID==0?vec2(-1,-1):gl_VertexID==1?vec2(3,-1):vec2(-1,3);gl_Position=vec4(p,0,1);}')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1,0,0,1);}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	indices := context.create_buffer()
	context.bind_buffer(element_array_buffer, indices)
	context.buffer_data(element_array_buffer, [u8(0), 1, 2], 0x88e4)
}

fn test_source_webgl2_draw_callbacks_occur_once_in_exact_order_around_real_rendering() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(1, 1)
	source_draw_program(mut context)
	mut witness := &SourceDrawCanvasWitness{}
	context.native.bind_canvas_content_changed(voidptr(witness), source_draw_canvas_callback)
	for operation in 0 .. 3 {
		C.vox_gl_clear_color(0, 0, 0, 1)
		C.vox_gl_clear(0x4000)
		witness.calls = 0
		witness.pixel = []u8{}
		match operation {
			0 { context.draw_arrays_instanced(4, 0, 3, 1) }
			1 { context.draw_elements_instanced(4, 3, unsigned_byte, 0, 1) }
			else { context.draw_range_elements(4, 0, 2, 3, unsigned_byte, 0) }
		}
		assert witness.calls == 1
		assert witness.pixel == if operation == 1 {
			[u8(255), 0, 0, 255]
		} else {
			[u8(0), 0, 0, 255]
		}
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
		assert context.needs_to_present()
		assert context.get_error() == no_error
	}
}

fn test_source_webgl2_draw_invalid_arguments_still_select_owner_notify_and_use_driver_errors() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(1, 1)
	source_draw_program(mut context)
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut witness := &SourceDrawCanvasWitness{}
	context.native.bind_canvas_content_changed(voidptr(witness), source_draw_canvas_callback)
	for operation in 0 .. 3 {
		context.native.make_current()
		match operation {
			0 { C.vox_gl_draw_arrays_instanced(0xbad, -1, -1, -1, 3) }
			1 { C.vox_gl_draw_elements_instanced(0xbad, -1, 0xbad, -1, -1, 3) }
			else { C.vox_gl_draw_range_elements(0xbad, 2, 1, -1, 0xbad, -1) }
		}
		expected := C.vox_gl_get_error()
		assert expected != no_error
		context.native.present_with_preserved_buffer(true)
		assert !context.needs_to_present()
		witness.calls = 0
		other.native.make_current()
		match operation {
			0 { context.draw_arrays_instanced(0xbad, -1, -1, -1) }
			1 { context.draw_elements_instanced(0xbad, -1, 0xbad, -1, -1) }
			else { context.draw_range_elements(0xbad, 2, 1, -1, 0xbad, -1) }
		}
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert witness.calls == 1
		assert context.needs_to_present()
		assert context.get_error() == expected
	}
}

fn test_source_webgl2_draw_canvas_hooks_remain_unconditional_after_actual_context_loss() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut witness := &SourceDrawCanvasWitness{ readback: false }
	context.native.bind_canvas_content_changed(voidptr(witness), source_draw_canvas_callback)
	context.lose_context_from_compositor_loss()
	assert context.native.is_lost()
	for operation in 0 .. 3 {
		witness.calls = 0
		match operation {
			0 { context.draw_arrays_instanced(0xbad, -1, -1, -1) }
			1 { context.draw_elements_instanced(0xbad, -1, 0xbad, -1, -1) }
			else { context.draw_range_elements(0xbad, 2, 1, -1, 0xbad, -1) }
		}
		assert witness.calls == 1
	}
}
