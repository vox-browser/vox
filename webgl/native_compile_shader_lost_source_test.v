// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_compile_shader_drops_command_without_other_shader_mutation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut original := owner.create_shader(vertex_shader) or { panic('owned source shader') }
		mut sentinel := other.create_shader(vertex_shader) or { panic('other source shader') }
		assert original.object.native_name() == sentinel.object.native_name()
		text := if version == .webgl2 {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		other.shader_source(mut sentinel, text)
		assert C.vox_gl_shader_parameter(sentinel.object.native_name(), compile_status) == 0
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		mut after := owner.create_shader(vertex_shader) or { panic('owned source shader after loss') }
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 2
		owner.compile_shader(mut original)
		owner.compile_shader(mut after)
		owner.compile_shader(mut sentinel)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		length := C.vox_gl_shader_parameter(sentinel.object.native_name(), GLenum(0x8b88))
		mut bytes := []u8{len: length}
		C.vox_gl_get_shader_source(sentinel.object.native_name(), length, bytes.data)
		assert bytes[..length - 1].bytestr() == text
		assert C.vox_gl_shader_parameter(sentinel.object.native_name(), compile_status) == 0
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_error() == no_error
	}
}
