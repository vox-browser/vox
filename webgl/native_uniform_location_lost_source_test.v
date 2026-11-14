// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn uniform_location_lost_other_driver(program GLuint, location int) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	mut bound := i32(-1)
	C.vox_gl_int_parameter(current_program, &bound)
	assert bound == int(program)
	assert C.vox_gl_program_parameter(program, link_status) == 1
	assert C.vox_gl_program_parameter(program, attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, delete_status) == 0
	mut values := [f32(0), 0, 0, 0]!
	C.vox_gl_get_uniform_floats(program, location, &values[0])
	assert values == [f32(3), 4, 5, 6]!
}

fn test_source_lost_uniform_location_returns_generated_zero_in_fresh_owned_parent_records() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut original := owner.create_program()
		mut sentinel := other.create_program()
		assert original.object.native_name() == sentinel.object.native_name()
		mut vertex := other.create_shader(vertex_shader) or { panic('other vertex') }
		mut fragment := other.create_shader(fragment_shader) or { panic('other fragment') }
		other.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es\nuniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
		} else {
			'uniform vec4 first;uniform vec4 second;void main(){gl_Position=first+second;}'
		})
		other.shader_source(mut fragment, if version == .webgl2 {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		})
		other.compile_shader(mut vertex)
		other.compile_shader(mut fragment)
		other.attach_shader(mut sentinel, vertex)
		other.attach_shader(mut sentinel, fragment)
		other.link_program(mut sentinel)
		other.use_program(sentinel)
		first_native := C.vox_gl_uniform_location(sentinel.object.native_name(), c'first')
		second_native := C.vox_gl_uniform_location(sentinel.object.native_name(), c'second')
		assert first_native >= 0 && second_native >= 0 && first_native != second_native
		name := if first_native > 0 { 'first' } else { 'second' }
		positive := if first_native > 0 { first_native } else { second_native }
		assert positive > 0
		C.vox_gl_uniform4f(positive, 3, 4, 5, 6)
		assert C.vox_gl_get_error() == no_error
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		mut after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		mut owned := [original, after]
		for mut program in owned {
			for query in [name, 'missing', 'gl_reserved'] {
				first := owner.get_uniform_location(mut program, query) or { panic('lost owned zero record') }
				second := owner.get_uniform_location(mut program, query) or { panic('fresh lost zero record') }
				assert voidptr(first) != voidptr(second)
				assert first.handle(program)! == 0 && second.handle(program)! == 0
				assert first.parent_program or { panic('actual original/unmapped parent') } == program
				assert first.relevant_global_impl() or { panic('owning parent global') } == program.object.relevant_global_impl()
				uniform_location_lost_other_driver(sentinel.object.native_name(), positive)
			}
		}
		retained := owner.get_uniform_location(mut original, name) or { panic('parent retained after deletion') }
		owner.delete_program(original)
		assert owner.get_uniform_location(mut original, name) == none
		assert retained.handle(original)! == 0
		assert retained.parent_program or { panic('actual deleted parent remains retained') } == original
		assert owner.get_uniform_location(mut sentinel, name) == none
		uniform_location_lost_other_driver(sentinel.object.native_name(), positive)
		next := owner.create_program()
		assert next.object.native_name() == 0
		assert next.object.handle(owner.identity(), owner.context_generation())! == 3
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
	}
}
