// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_attach_lost_other_driver(program GLuint, vertex GLuint, fragment GLuint) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	mut bound := i32(-1)
	C.vox_gl_int_parameter(current_program, &bound)
	assert bound == 0
	assert C.vox_gl_program_parameter(program, attached_shaders) == 0
	assert C.vox_gl_program_parameter(program, delete_status) == 0
	for shader in [vertex, fragment] {
		assert C.vox_gl_shader_parameter(shader, compile_status) == 0
		assert C.vox_gl_shader_parameter(shader, delete_status) == 0
	}
}

fn test_source_lost_attach_shader_drops_driver_command_but_retains_actual_shader_slots() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut original := owner.create_program()
		vertex := owner.create_shader(vertex_shader) or { panic('original vertex') }
		fragment := owner.create_shader(fragment_shader) or { panic('original fragment') }
		mut sentinel := other.create_program()
		other_vertex := other.create_shader(vertex_shader) or { panic('other vertex') }
		other_fragment := other.create_shader(fragment_shader) or { panic('other fragment') }
		assert original.object.native_name() == sentinel.object.native_name()
		assert vertex.object.native_name() == other_vertex.object.native_name()
		assert fragment.object.native_name() == other_fragment.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		mut after := owner.create_program()
		after_vertex := owner.create_shader(vertex_shader) or { panic('unmapped vertex') }
		after_fragment := owner.create_shader(fragment_shader) or { panic('unmapped fragment') }
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 4
		assert after_vertex.object.native_name() == 0
		assert after_vertex.object.handle(owner.identity(), owner.context_generation())! == 5
		assert after_fragment.object.native_name() == 0
		assert after_fragment.object.handle(owner.identity(), owner.context_generation())! == 6
		shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		for shader in [fragment, vertex] {
			owner.attach_shader(mut original, shader)
			shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		}
		assert owner.get_attached_shaders(original) or { panic('original retained refs') } == [
			vertex,
			fragment,
		]
		for shader in [after_vertex, after_fragment] {
			owner.attach_shader(mut after, shader)
			shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		}
		assert owner.get_attached_shaders(after) or { panic('unmapped retained refs') } == [
			after_vertex,
			after_fragment,
		]
		for shader in [vertex, fragment, after_vertex, after_fragment, other_vertex] {
			owner.attach_shader(mut original, shader)
			assert owner.get_attached_shaders(original) or { panic('gate retains original refs') } == [
				vertex,
				fragment,
			]
			shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		}
		owner.attach_shader(mut sentinel, vertex)
		assert sentinel.attached_vertex_shader == none
		shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.delete_shader(vertex)
		assert vertex.object.invalidated()
		owner.attach_shader(mut original, vertex)
		assert owner.get_attached_shaders(original) or { panic('deleted retained shader') } == [
			vertex,
			fragment,
		]
		shader_attach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		assert !after.object.invalidated()
		assert !after_vertex.object.invalidated()
		assert !after_fragment.object.invalidated()
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
	}
}
