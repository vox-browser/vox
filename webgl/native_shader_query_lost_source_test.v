// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_shader_sync_preserves_initialized_outputs_and_other_actual_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		before_one := owner.create_shader(vertex_shader) or { panic('original owned shader one') }
		before_two := owner.create_shader(vertex_shader) or { panic('original owned shader two') }
		mut valid := other.create_shader(vertex_shader) or { panic('other compiled sentinel') }
		mut invalid := other.create_shader(vertex_shader) or { panic('other compiler log sentinel') }
		text := if version == .webgl2 {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		other.shader_source(mut valid, text)
		other.compile_shader(mut valid)
		other.shader_source(mut invalid, 'this is not a shader')
		other.compile_shader(mut invalid)
		assert C.vox_gl_shader_parameter(valid.object.native_name(), compile_status) == 1
		log_length := C.vox_gl_shader_parameter(invalid.object.native_name(), GLenum(0x8b84))
		assert log_length > 1
		assert before_one.object.native_name() == valid.object.native_name()
		assert before_two.object.native_name() == invalid.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		after_loss := owner.create_shader(vertex_shader) or { panic('owned proxy shader after loss') }
		assert after_loss.object.native_name() == 0
		assert owner.owns(&after_loss.object)
		for shader in [before_one, before_two, after_loss] {
			assert owner.get_shader_source(shader) or { panic('lost source string') } == ''
			assert owner.get_shader_info_log(shader) or { panic('lost log string') } == ''
			assert owner.get_shader_parameter(shader, shader_type).integer == 0
			assert !owner.get_shader_parameter(shader, compile_status).boolean
			assert !owner.get_shader_parameter(shader, delete_status).boolean
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_shader_parameter(valid.object.native_name(), compile_status) == 1
			assert C.vox_gl_shader_parameter(invalid.object.native_name(), GLenum(0x8b84)) == log_length
		}
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_shader_source(valid) or { panic('genuine untouched source') } == text
		assert other.get_error() == no_error
	}
}
