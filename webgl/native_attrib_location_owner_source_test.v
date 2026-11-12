// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_attrib_location_preserves_source_handle_gate_and_actual_named_query_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		foreign := other.create_program()
		context.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		assert context.get_attrib_location(foreign, 'position') == -1
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_value
		assert context.get_error() == invalid_operation
		mut program := context.create_program()
		context.native.make_current()
		name := 'position'
		expected_unlinked := C.vox_gl_attrib_location(program.object.native_handle_, name.str)
		expected_error := C.vox_gl_get_error()
		other.native.make_current()
		assert context.get_attrib_location(program, name) == expected_unlinked
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_error
		mut vertex := context.create_shader(vertex_shader) or { panic('attribute vertex') }
		mut fragment := context.create_shader(fragment_shader) or { panic('attribute fragment') }
		context.shader_source(mut vertex, if version == .webgl1 {
			'attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}'
		} else {
			'#version 300 es\nin vec2 position;void main(){gl_Position=vec4(position,0,1);}'
		})
		context.shader_source(mut fragment, if version == .webgl1 {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		} else {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		})
		context.compile_shader(mut vertex)
		context.compile_shader(mut fragment)
		context.attach_shader(mut program, vertex)
		context.attach_shader(mut program, fragment)
		context.link_program(mut program)
		assert context.get_program_parameter(program, link_status).boolean
		for query_name in ['position', 'absent', 'gl_reserved', 'position\x00ignored'] {
			context.native.make_current()
			expected := C.vox_gl_attrib_location(program.object.native_handle_, query_name.str)
			expected_query_error := C.vox_gl_get_error()
			other.native.make_current()
			assert context.get_attrib_location(program, query_name) == expected
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == expected_query_error
		}
		context.delete_program(program)
		other.native.make_current()
		assert context.get_attrib_location(program, name) == -1
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_operation
		assert context.get_error() == no_error
	}
}
