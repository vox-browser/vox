// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_program_deletion_drops_driver_command_but_clears_actual_retained_slot() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		original := owner.create_program()
		owner.use_program(original)
		assert owner.get_error() == invalid_operation
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
		other.link_program(mut sentinel)
		assert other.get_program_parameter(sentinel, link_status).boolean
		other.use_program(sentinel)
		source_id := original.object.handle(owner.identity(), owner.context_generation())!
		native_name := original.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		owner.delete_program(none)
		owner.delete_program(sentinel)
		assert owner.current_program or { panic('retained original after CPU gates') } == original
		owner.delete_program(after)
		assert after.object.invalidated()
		assert owner.current_program or { panic('identity keeps distinct original') } == original
		owner.delete_program(original)
		assert original.object.invalidated()
		assert original.object.source_handle_ == source_id
		assert original.object.native_name() == native_name
		assert owner.current_program == none
		owner.delete_program(original)
		assert !sentinel.object.invalidated()
		assert owner.get_parameter(current_program).kind == .none
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_is_object(10, sentinel.object.native_name()) == 1
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), delete_status) == 0
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), link_status) == 1
		assert C.vox_gl_program_parameter(sentinel.object.native_name(), attached_shaders) == 2
		mut native_current := i32(0)
		C.vox_gl_int_parameter(current_program, &native_current)
		assert native_current == int(sentinel.object.native_name())
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_parameter(current_program).program or { panic('other retained current') } == sentinel
		assert other.get_error() == no_error
	}
}
