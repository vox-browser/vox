// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_diagnostic_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_shader_diagnostics_keep_cpu_handle_returns_before_actual_sync_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut shader := owner.create_shader(vertex_shader) or { panic('owned diagnostic shader') }
		foreign := other.create_shader(vertex_shader) or { panic('foreign diagnostic shader') }
		for info_log in [false, true] {
			other.native.make_current()
			C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
			result := if info_log {
				owner.get_shader_info_log(foreign)
			} else {
				owner.get_shader_source(foreign)
			}
			assert result == none
			shader_diagnostic_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == invalid_value
			assert owner.get_error() == invalid_operation
			other.native.make_current()
			empty := if info_log {
				owner.get_shader_info_log(shader)
			} else {
				owner.get_shader_source(shader)
			}
			assert empty or { panic('owned empty diagnostic') } == ''
			shader_diagnostic_owner([i32(1), 2, 3, 4]!)
			assert owner.get_error() == no_error
		}
		// Driver mutation supplies the source and compiler log independently of V.
		actual_source := 'this is not a shader'
		owner.native.make_current()
		C.vox_gl_shader_source(shader.object.native_name(), actual_source.str, actual_source.len)
		C.vox_gl_compile_shader(shader.object.native_name())
		assert C.vox_gl_shader_parameter(shader.object.native_name(), compile_status) == 0
		length := C.vox_gl_shader_parameter(shader.object.native_name(), GLenum(0x8b84))
		assert length > 1
		mut bytes := []u8{len: length}
		C.vox_gl_shader_log(shader.object.native_name(), length, bytes.data)
		actual_log := bytes[..length - 1].bytestr()
		other.native.make_current()
		assert owner.get_shader_source(shader) or { panic('driver source') } == actual_source
		shader_diagnostic_owner([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert owner.get_shader_info_log(shader) or { panic('driver compiler log') } == actual_log
		shader_diagnostic_owner([i32(1), 2, 3, 4]!)
		assert owner.get_error() == no_error
		owner.delete_shader(shader)
		for info_log in [false, true] {
			other.native.make_current()
			deleted := if info_log {
				owner.get_shader_info_log(shader)
			} else {
				owner.get_shader_source(shader)
			}
			assert deleted == none
			shader_diagnostic_owner([i32(9), 10, 11, 12]!)
			assert owner.get_error() == invalid_operation
		}
	}
}
