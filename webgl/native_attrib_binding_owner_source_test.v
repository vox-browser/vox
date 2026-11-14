// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn attrib_binding_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_bind_attrib_handle_gate_precedes_owner_and_preserves_real_driver_binding() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		foreign := other.create_program()
		deleted := owner.create_program()
		owner.delete_program(deleted)
		for record in [foreign, deleted] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
			owner.bind_attrib_location(record, u32(-1), 'gl_reserved')
			attrib_binding_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == invalid_enum
			assert C.vox_gl_get_error() == no_error
			assert owner.get_error() == invalid_operation
		}
		mut vertex := owner.create_shader(vertex_shader) or { panic('binding vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('binding fragment') }
		owner.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es\nin vec4 position;void main(){gl_Position=position;}'
		} else {
			'attribute vec4 position;void main(){gl_Position=position;}'
		})
		owner.shader_source(mut fragment, if version == .webgl2 {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		})
		owner.compile_shader(mut vertex)
		owner.compile_shader(mut fragment)
		owner.attach_shader(mut program, vertex)
		owner.attach_shader(mut program, fragment)
		other.native.make_current()
		owner.bind_attrib_location(program, 3, 'position')
		attrib_binding_owner([i32(1), 2, 3, 4]!)
		C.vox_gl_link_program(program.object.native_name())
		assert C.vox_gl_attrib_location(program.object.native_name(), c'position') == 3
		assert owner.get_error() == no_error
		other.native.make_current()
		owner.bind_attrib_location(program, 5, 'position\x00ignored')
		attrib_binding_owner([i32(1), 2, 3, 4]!)
		C.vox_gl_link_program(program.object.native_name())
		assert C.vox_gl_attrib_location(program.object.native_name(), c'position') == 5
		assert owner.get_error() == no_error
		for name in ['position', 'gl_reserved'] {
			C.vox_gl_bind_attrib_location(program.object.native_name(), u32(-1), name.str)
			expected := C.vox_gl_get_error()
			assert expected != no_error
			other.native.make_current()
			owner.bind_attrib_location(program, u32(-1), name)
			attrib_binding_owner([i32(1), 2, 3, 4]!)
			assert owner.get_error() == expected
		}
		assert owner.get_attached_shaders(program) or { panic('binding retains shaders') } == [
			vertex,
			fragment,
		]
	}
}
