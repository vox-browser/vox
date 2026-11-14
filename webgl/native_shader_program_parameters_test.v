// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_shader_program_parameters_query_native_status_and_preserve_source_enum_order() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut vertex := owner.create_shader(vertex_shader) or { panic('vertex') }
		mut fragment := owner.create_shader(fragment_shader) or { panic('fragment') }
		vertex_source := if version == .webgl1 {
			'void main(){gl_Position=vec4(0.0);}'
		} else {
			'#version 300 es\nvoid main(){gl_Position=vec4(0.0);}'
		}
		fragment_source := if version == .webgl1 {
			'precision mediump float;void main(){gl_FragColor=vec4(1.0);}'
		} else {
			'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1.0);}'
		}
		owner.shader_source(mut vertex, vertex_source)
		owner.shader_source(mut fragment, fragment_source)
		owner.compile_shader(mut vertex)
		owner.compile_shader(mut fragment)
		mut program := owner.create_program()
		owner.attach_shader(mut program, vertex)
		owner.attach_shader(mut program, fragment)
		owner.link_program(mut program)
		owner.use_program(program)
		assert owner.get_shader_parameter(vertex, shader_type).integer == vertex_shader
		assert owner.get_shader_parameter(vertex, compile_status).boolean
		assert owner.get_program_parameter(program, link_status).boolean
		assert !owner.get_shader_parameter(vertex, delete_status).boolean
		assert !owner.get_program_parameter(program, delete_status).boolean
		// GL defers these deletions while the shader is attached/program current.
		owner.native.make_current()
		C.vox_gl_delete_shader(vertex.object.native_handle_)
		C.vox_gl_delete_program(program.object.native_handle_)
		assert !vertex.object.invalidated()
		assert !program.object.invalidated()
		other.native.make_current()
		assert owner.get_shader_parameter(vertex, delete_status).boolean
		other.native.make_current()
		assert owner.get_program_parameter(program, delete_status).boolean
		assert owner.get_error() == no_error
		// Source asks GL before its pname switch. Unknown GL pnames therefore
		// retain both the driver error and the source fallback error.
		shader_unknown := owner.get_shader_parameter(vertex, GLenum(0xbad))
		assert shader_unknown.kind == .none
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		program_unknown := owner.get_program_parameter(program, GLenum(0xbad))
		assert program_unknown.kind == .none
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		// A valid native pname outside the source table adds only its fallback.
		unsupported := owner.get_shader_parameter(vertex, GLenum(0x8b84))
		assert unsupported.kind == .none
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		foreign_shader := other.create_shader(vertex_shader) or { panic('foreign shader') }
		foreign_program := other.create_program()
		invalid_shader := owner.get_shader_parameter(foreign_shader, GLenum(0xbad))
		assert invalid_shader.kind == .none
		assert owner.get_error() == invalid_operation
		assert owner.get_error() == no_error
		other.native.make_current()
		// Source's foreign handle return precedes any actual sync owner selection.
		mut other_current_program := i32(0)
		C.vox_gl_int_parameter(current_program, &other_current_program)
		invalid_program := owner.get_program_parameter(foreign_program, GLenum(0xbad))
		mut current := i32(0)
		C.vox_gl_int_parameter(current_program, &current)
		assert current == other_current_program
		assert invalid_program.kind == .none
		assert owner.get_error() == invalid_operation
		assert owner.get_error() == no_error
		assert other.get_error() == no_error
	}
}
