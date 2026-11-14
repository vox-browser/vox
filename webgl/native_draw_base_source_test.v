// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct SourceBaseDrawWitness {
mut:
	calls    int
	pixel    []u8
	readback bool = true
}

fn source_base_draw_canvas_callback(owner voidptr) {
	mut witness := unsafe { &SourceBaseDrawWitness(owner) }
	witness.calls++
	if !witness.readback { return }
	mut pixel := []u8{len: 4}
	C.vox_gl_read_pixels(0, 0, 1, 1, rgba, unsigned_byte, pixel.len, pixel.data)
	witness.pixel = pixel
}

fn source_base_draw_program(mut context WebGLRenderingContext) GLuint {
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	vertex_source := if context.version == .webgl2 {
		'#version 300 es\nin vec2 position;'
	} else {
		'attribute vec2 position;'
	}
	fragment_source := if context.version == .webgl2 {
		'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1,0,0,1);}'
	} else {
		'precision mediump float;void main(){gl_FragColor=vec4(1,0,0,1);}'
	}
	context.shader_source(mut vertex, vertex_source + 'void main(){gl_Position=vec4(position,0,1);}')
	context.shader_source(mut fragment, fragment_source)
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.bind_attrib_location(program, 0, 'position')
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	vertices := context.create_buffer()
	context.bind_buffer(array_buffer, vertices)
	positions := [f32(-1), -1, 3, -1, -1, 3]
	context.buffer_data(array_buffer, unsafe { (&u8(positions.data)).vbytes(positions.len * 4).clone() }, 0x88e4)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 0)
	context.enable_vertex_attrib_array(0)
	// Genuine driver-only EAB binding; Source has never received bindBuffer.
	indices := [u8(0), 1, 2]
	name := C.vox_gl_gen_object(0)
	C.vox_gl_bind_buffer(element_array_buffer, name)
	C.vox_gl_buffer_data(element_array_buffer, indices.len, indices.data, 0x88e4)
	return name
}

fn test_source_base_draw_body_uses_real_driver_binding_and_exact_callback_order() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(1, 1)
		name := source_base_draw_program(mut context)
		assert context.get_parameter(element_array_buffer_binding).kind == .none
		mut witness := &SourceBaseDrawWitness{}
		context.native.bind_canvas_content_changed(voidptr(witness), source_base_draw_canvas_callback)
		for indexed in [false, true] {
			C.vox_gl_clear_color(0, 0, 0, 1)
			C.vox_gl_clear(0x4000)
			witness.calls = 0
			if indexed {
				context.draw_elements(4, 3, unsigned_byte, 0)
			} else {
				context.draw_arrays(4, 0, 3)
			}
			assert witness.calls == 1
			assert witness.pixel == if indexed { [u8(255), 0, 0, 255] } else { [u8(0), 0, 0, 255] }
			assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
			assert context.get_parameter(element_array_buffer_binding).kind == .none
			assert context.needs_to_present()
			assert context.get_error() == no_error
		}
		C.vox_gl_delete_object(0, name)
	}
}

fn test_source_base_draw_invalid_arguments_and_actual_loss_still_run_source_hooks() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut witness := &SourceBaseDrawWitness{ readback: false }
		context.native.bind_canvas_content_changed(voidptr(witness), source_base_draw_canvas_callback)
		for indexed in [false, true] {
			context.native.make_current()
			if indexed {
				C.vox_gl_draw_elements(0xbad, -1, 0xbad, -1)
			} else {
				C.vox_gl_draw_arrays(0xbad, -1, -1)
			}
			expected := C.vox_gl_get_error()
			assert expected != no_error
			context.native.present_with_preserved_buffer(true)
			assert !context.needs_to_present()
			witness.calls = 0
			other.native.make_current()
			if indexed {
				context.draw_elements(0xbad, -1, 0xbad, -1)
			} else {
				context.draw_arrays(0xbad, -1, -1)
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert witness.calls == 1
			assert context.needs_to_present()
			assert context.get_error() == expected
		}
		context.lose_context_from_compositor_loss()
		witness.calls = 0
		context.draw_arrays(0xbad, -1, -1)
		assert witness.calls == 1
		context.draw_elements(0xbad, -1, 0xbad, -1)
		assert witness.calls == 2
	}
}
