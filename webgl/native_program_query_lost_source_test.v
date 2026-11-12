// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_program_sync_keeps_initialized_outputs_and_other_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		first := owner.create_program()
		second := owner.create_program()
		mut valid := other.create_program()
		invalid := other.create_program()
		assert first.object.native_name() == valid.object.native_name()
		assert second.object.native_name() == invalid.object.native_name()
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
		other.attach_shader(mut valid, vertex)
		other.attach_shader(mut valid, fragment)
		other.link_program(mut valid)
		other.native.make_current()
		C.vox_gl_link_program(invalid.object.native_name())
		assert C.vox_gl_program_parameter(valid.object.native_name(), link_status) == 1
		log_length := C.vox_gl_program_parameter(invalid.object.native_name(), GLenum(0x8b84))
		assert log_length > 1
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		after := owner.create_program()
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 3
		mut numeric := [attached_shaders, active_attributes, active_uniforms]
		if version == .webgl2 {
			numeric << [transform_feedback_buffer_mode, transform_feedback_varyings,
				active_uniform_blocks]
		}
		for program in [first, second, after] {
			assert owner.get_program_info_log(program) or { panic('owned lost program log') } == ''
			for pname in numeric {
				result := owner.get_program_parameter(program, pname)
				assert result.kind == .integer
				assert result.integer == 0
			}
			for pname in [link_status, delete_status, validate_status] {
				result := owner.get_program_parameter(program, pname)
				assert result.kind == .boolean
				assert !result.boolean
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_program_parameter(valid.object.native_name(), link_status) == 1
			assert C.vox_gl_program_parameter(invalid.object.native_name(), GLenum(0x8b84)) == log_length
		}
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_program_parameter(valid, link_status).boolean
		assert other.get_program_info_log(invalid) or { panic('genuine untouched Other log') } != ''
		assert other.get_error() == no_error
	}
}
