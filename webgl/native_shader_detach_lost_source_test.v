// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_detach_lost_other_driver(program GLuint, vertex GLuint, fragment GLuint) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	assert C.vox_gl_program_parameter(program, attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, delete_status) == 0
	for shader in [vertex, fragment] {
		assert C.vox_gl_shader_parameter(shader, compile_status) == 0
		assert C.vox_gl_shader_parameter(shader, delete_status) == 0
	}
}

fn test_source_lost_detach_shader_drops_driver_command_then_clears_actual_typed_retained_slot() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut original := owner.create_program()
		vertex := owner.create_shader(vertex_shader) or { panic('original vertex') }
		fragment := owner.create_shader(fragment_shader) or { panic('original fragment') }
		unattached := owner.create_shader(vertex_shader) or { panic('unattached vertex') }
		owner.attach_shader(mut original, vertex)
		owner.attach_shader(mut original, fragment)
		mut sentinel := other.create_program()
		other_vertex := other.create_shader(vertex_shader) or { panic('other vertex') }
		other_fragment := other.create_shader(fragment_shader) or { panic('other fragment') }
		other.attach_shader(mut sentinel, other_vertex)
		other.attach_shader(mut sentinel, other_fragment)
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
		owner.attach_shader(mut after, after_vertex)
		owner.attach_shader(mut after, after_fragment)
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 5
		assert after_vertex.object.native_name() == 0
		assert after_vertex.object.handle(owner.identity(), owner.context_generation())! == 6
		assert after_fragment.object.native_name() == 0
		assert after_fragment.object.handle(owner.identity(), owner.context_generation())! == 7
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.detach_shader(mut original, other_vertex)
		assert owner.get_attached_shaders(original) or { panic('foreign keeps slots') } == [
			vertex,
			fragment,
		]
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.detach_shader(mut sentinel, vertex)
		assert other.get_attached_shaders(sentinel) or { panic('foreign program slots') } == [
			other_vertex,
			other_fragment,
		]
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.delete_shader(vertex)
		owner.detach_shader(mut original, vertex)
		assert vertex.object.invalidated()
		assert owner.get_attached_shaders(original) or { panic('invalidated keeps retained ref') } == [
			vertex,
			fragment,
		]
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		// Source clears the type slot even though this shader was never attached.
		owner.detach_shader(mut original, unattached)
		assert owner.get_attached_shaders(original) or { panic('unattached clears vertex slot') } == [fragment]
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.detach_shader(mut original, fragment)
		assert (owner.get_attached_shaders(original) or { panic('original empty slots') }).len == 0
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		owner.detach_shader(mut after, after_vertex)
		assert owner.get_attached_shaders(after) or { panic('unmapped fragment remains') } == [after_fragment]
		shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		for _ in 0 .. 2 {
			owner.detach_shader(mut after, after_fragment)
			assert (owner.get_attached_shaders(after) or { panic('unmapped empty slots') }).len == 0
			shader_detach_lost_other_driver(sentinel.object.native_name(), other_vertex.object.native_name(), other_fragment.object.native_name())
		}
		assert !after.object.invalidated() && !after_vertex.object.invalidated() && !after_fragment.object.invalidated()
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
	}
}
