// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn attrib_binding_lost_other_driver(program GLuint) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	// Relinking exposes pending glBindAttribLocation changes, so a later reset cannot hide them.
	C.vox_gl_link_program(program)
	assert C.vox_gl_program_parameter(program, link_status) == 1
	assert C.vox_gl_attrib_location(program, c'position') == 2
	assert C.vox_gl_program_parameter(program, attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, delete_status) == 0
}

fn test_source_lost_bind_attrib_drops_actual_command_and_preserves_other_pending_binding() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		original := owner.create_program()
		mut sentinel := other.create_program()
		assert original.object.native_name() == sentinel.object.native_name()
		mut vertex := other.create_shader(vertex_shader) or { panic('other vertex') }
		mut fragment := other.create_shader(fragment_shader) or { panic('other fragment') }
		other.shader_source(mut vertex, if version == .webgl2 {
			'#version 300 es\nin vec4 position;void main(){gl_Position=position;}'
		} else {
			'attribute vec4 position;void main(){gl_Position=position;}'
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
		C.vox_gl_bind_attrib_location(sentinel.object.native_name(), 2, c'position')
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		for record in [original, after, sentinel] {
			for name in ['position', 'position\x00ignored', 'gl_reserved'] {
				owner.bind_attrib_location(record, 6, name)
				attrib_binding_lost_other_driver(sentinel.object.native_name())
			}
		}
		owner.delete_program(original)
		owner.bind_attrib_location(original, 6, 'position')
		attrib_binding_lost_other_driver(sentinel.object.native_name())
		assert !after.object.invalidated()
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
	}
}
