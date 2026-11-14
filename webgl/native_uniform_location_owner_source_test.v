// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn uniform_location_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_uniform_location_handle_gate_precedes_driver_and_fresh_owned_record_creation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := owner.create_program()
		mut foreign := other.create_program()
		mut deleted := owner.create_program()
		owner.delete_program(deleted)
		mut gated_records := [foreign, deleted]
		for mut record in gated_records {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
			assert owner.get_uniform_location(mut record, 'first') == none
			uniform_location_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == invalid_enum
			assert C.vox_gl_get_error() == no_error
			assert owner.get_error() == invalid_operation
		}
		mut vertex := owner.create_shader(vertex_shader) or { panic('uniform vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('uniform fragment') }
		owner.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es\nuniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
		} else {
			'uniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
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
		owner.link_program(mut program)
		assert C.vox_gl_program_parameter(program.object.native_name(), link_status) == 1
		for name in ['first', 'second', 'first\x00ignored'] {
			expected := C.vox_gl_uniform_location(program.object.native_name(), name.str)
			assert expected >= 0
			other.native.make_current()
			first := owner.get_uniform_location(mut program, name) or { panic('first owned location') }
			uniform_location_owner([i32(1), 2, 3, 4]!)
			other.native.make_current()
			second := owner.get_uniform_location(mut program, name) or { panic('fresh owned location') }
			uniform_location_owner([i32(1), 2, 3, 4]!)
			assert voidptr(first) != voidptr(second)
			assert first.handle(program)! == u32(expected)
			assert second.handle(program)! == u32(expected)
			assert first.parent_program or { panic('actual parent pointer') } == program
			assert first.relevant_global_impl() or { panic('owning global') } == owner.identity()
			assert owner.current_program == none
			assert owner.get_error() == no_error
		}
		for name in ['missing', 'gl_reserved'] {
			assert C.vox_gl_uniform_location(program.object.native_name(), name.str) == -1
			other.native.make_current()
			assert owner.get_uniform_location(mut program, name) == none
			uniform_location_owner([i32(1), 2, 3, 4]!)
			assert owner.get_error() == no_error
		}
		mut unlinked := owner.create_program()
		assert C.vox_gl_uniform_location(unlinked.object.native_name(), c'first') == -1
		expected := C.vox_gl_get_error()
		assert expected != no_error
		other.native.make_current()
		assert owner.get_uniform_location(mut unlinked, 'first') == none
		uniform_location_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == expected
	}
}
