// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_shader_deletion_invalidates_records_and_preserves_other_driver_shader() {
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
		other.compile_shader(mut sentinel)
		assert C.vox_gl_shader_parameter(sentinel.object.native_name(), compile_status) == 1
		mut program := owner.create_program()
		owner.attach_shader(mut program, original)
		source_id := original.object.handle(owner.identity(), owner.context_generation())!
		native_name := original.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		mut after := owner.create_shader(vertex_shader) or { panic('owned source shader after loss') }
		assert after.object.native_name() == 0
		assert after.object.handle(owner.identity(), owner.context_generation())! == 3
		owner.delete_shader(none)
		owner.delete_shader(original)
		owner.delete_shader(after)
		owner.delete_shader(original)
		owner.delete_shader(sentinel)
		assert original.object.invalidated()
		assert after.object.invalidated()
		assert !sentinel.object.invalidated()
		assert original.object.source_handle_ == source_id
		assert original.object.native_name() == native_name
		assert owner.get_attached_shaders(program) or { panic('retained lost attachment') } == [original]
		assert C.vox_gl_is_object(9, sentinel.object.native_name()) == 1
		assert C.vox_gl_shader_parameter(sentinel.object.native_name(), delete_status) == 0
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		length := C.vox_gl_shader_parameter(sentinel.object.native_name(), GLenum(0x8b88))
		mut bytes := []u8{len: length}
		C.vox_gl_get_shader_source(sentinel.object.native_name(), length, bytes.data)
		assert bytes[..length - 1].bytestr() == text
		assert C.vox_gl_shader_parameter(sentinel.object.native_name(), compile_status) == 1
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.get_error() == no_error
	}
}
