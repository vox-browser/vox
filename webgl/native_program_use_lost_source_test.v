// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn program_use_lost_other_driver(name GLuint) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	mut actual := i32(-1)
	C.vox_gl_int_parameter(current_program, &actual)
	assert actual == int(name)
	assert C.vox_gl_program_parameter(name, link_status) == 1
	assert C.vox_gl_program_parameter(name, delete_status) == 0
}

fn test_source_lost_use_program_drops_native_call_but_assigns_retained_record_after_command() {
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
		other.use_program(sentinel)
		assert other.get_error() == no_error
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		owner.use_program(none)
		assert owner.current_program == none
		program_use_lost_other_driver(sentinel.object.native_name())
		owner.use_program(original)
		assert owner.current_program or { panic('original after dropped command') } == original
		program_use_lost_other_driver(sentinel.object.native_name())
		owner.use_program(after)
		assert owner.current_program or { panic('unmapped owned source record') } == after
		program_use_lost_other_driver(sentinel.object.native_name())
		owner.use_program(sentinel)
		assert owner.current_program or { panic('foreign keeps unmapped source record') } == after
		program_use_lost_other_driver(sentinel.object.native_name())
		owner.delete_program(original)
		assert original.object.invalidated()
		owner.use_program(original)
		assert owner.current_program or { panic('deleted keeps unmapped source record') } == after
		program_use_lost_other_driver(sentinel.object.native_name())
		owner.use_program(none)
		assert owner.current_program == none
		program_use_lost_other_driver(sentinel.object.native_name())
		assert !after.object.invalidated()
		assert !sentinel.object.invalidated()
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_parameter(current_program).program or { panic('other source current') } == sentinel
		assert other.get_error() == no_error
	}
}
