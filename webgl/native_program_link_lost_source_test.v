// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_program_linking_drops_command_and_preserves_other_unlinked_program() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut original := owner.create_program()
		mut sentinel := other.create_program()
		assert original.object.native_name() == sentinel.object.native_name()
		mut vertex := other.create_shader(vertex_shader) or { panic('other vertex') }
		mut fragment := other.create_shader(fragment_shader) or { panic('other fragment') }
		other.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		})
		other.shader_source(mut fragment, if version == .webgl2 {
			'#version 300 es
precision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		})
		other.compile_shader(mut vertex)
		other.compile_shader(mut fragment)
		other.attach_shader(mut sentinel, vertex)
		other.attach_shader(mut sentinel, fragment)
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), link_status) == 0
		source_id := original.object.handle(owner.identity(), owner.context_generation())!
		native_name := original.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		mut after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		owner.link_program(mut original)
		owner.link_program(mut after)
		owner.link_program(mut original)
		owner.link_program(mut sentinel)
		assert !original.object.invalidated()
		assert !after.object.invalidated()
		assert !sentinel.object.invalidated()
		assert original.object.handle(owner.identity(), owner.context_generation())! == source_id
		assert original.object.native_name() == native_name

		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_is_object(10, sentinel.object.native_name()) == 1
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), delete_status) == 0
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), link_status) == 0
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), attached_shaders) == 2
		mut native_current := i32(0)
		C.vox_gl_int_parameter(current_program, &native_current)
		assert native_current == 0
		assert C.vox_gl_shader_parameter(vertex.object.native_name(), compile_status) == 1
		assert C.vox_gl_shader_parameter(fragment.object.native_name(), compile_status) == 1
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_parameter(current_program).program == none
		assert other.get_error() == no_error
	}
}
