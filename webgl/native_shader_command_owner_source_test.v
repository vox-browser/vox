// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_command_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_shader_commands_validate_before_native_owner_and_preserve_real_shader_state() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut shader := owner.create_shader(vertex_shader) or { panic('source owned shader') }
		mut foreign := other.create_shader(vertex_shader) or { panic('source foreign shader') }
		text := if version == .webgl2 {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		other.shader_source(mut foreign, text)
		assert C.vox_gl_shader_parameter(foreign.object.native_name(), compile_status) == 0
		owner.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		owner.shader_source(mut foreign, 'rejected foreign source')
		shader_command_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_value
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		owner.compile_shader(mut foreign)
		shader_command_owner([i32(9), 10, 11, 12]!)
		assert C.vox_gl_shader_parameter(foreign.object.native_name(), compile_status) == 0
		assert owner.get_error() == invalid_operation
		assert other.get_shader_source(foreign) or { panic('genuine foreign source') } == text
		other.native.make_current()
		owner.shader_source(mut shader, text)
		shader_command_owner([i32(1), 2, 3, 4]!)
		assert owner.get_shader_source(shader) or { panic('actual owned source') } == text
		other.native.make_current()
		owner.compile_shader(mut shader)
		shader_command_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_shader_parameter(shader.object.native_name(), compile_status) == 1
		assert owner.get_error() == no_error
		owner.delete_shader(shader)
		other.native.make_current()
		owner.shader_source(mut shader, 'deleted source')
		shader_command_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		other.native.make_current()
		owner.compile_shader(mut shader)
		shader_command_owner([i32(9), 10, 11, 12]!)
		assert owner.get_error() == invalid_operation
		assert other.get_error() == no_error
	}
}
