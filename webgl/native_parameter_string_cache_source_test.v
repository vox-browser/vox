// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn string_cache_selected_driver(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_parameter_strings_cache_actual_driver_values_and_share_debug_aliases() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut actual := map[GLenum]string{}
		for pname in [GLenum(0x1f00), 0x1f01, 0x1f02, 0x8b8c] {
			other.native.make_current()
			result := owner.get_parameter(pname)
			assert result.kind == .string_ && result.text.len > 0
			string_cache_selected_driver([i32(1), 2, 3, 4]!)
			assert result.text == native_gl_string(pname)
			actual[pname] = result.text
		}
		owner.get_extension('WEBGL_debug_renderer_info', false) or { panic('actual debug renderer extension') }
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		for pname, expected in actual {
			assert owner.get_parameter(pname).text == expected
			string_cache_selected_driver([i32(9), 10, 11, 12]!)
		}
		assert owner.get_parameter(unmasked_vendor_webgl).text == actual[GLenum(0x1f00)]
		string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert owner.get_parameter(unmasked_renderer_webgl).text == actual[GLenum(0x1f01)]
		string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == no_error
	}
}

fn test_source_string_cache_survives_loss_but_cold_strings_are_empty_until_restore() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		vendor := owner.get_parameter(GLenum(0x1f00)).text
		assert vendor.len > 0
		owner.get_extension('WEBGL_debug_renderer_info', false) or { panic('actual lost debug extension') }
		owner.lose_context_from_compositor_loss()
		other.native.make_current()
		assert native_gl_string(GLenum(0x1f01)).len > 0
		mut unused := i32(0)
		C.vox_gl_int_parameter(GLenum(0xffff_ffff), &unused)
		assert owner.get_parameter(GLenum(0x1f00)).text == vendor
		assert owner.get_parameter(unmasked_vendor_webgl).text == vendor
		for pname in [GLenum(0x1f01), 0x1f02, 0x8b8c, unmasked_renderer_webgl] {
			result := owner.get_parameter(pname)
			assert result.kind == .string_ && result.text == ''
			string_cache_selected_driver([i32(9), 10, 11, 12]!)
		}
		assert C.vox_gl_get_error() == invalid_enum
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		owner.request_context_restore()
		assert owner.restore_context_after_compositor_reconnect()
		owner.viewport(1, 2, 3, 4)
		other.native.make_current()
		assert owner.get_parameter(GLenum(0x1f00)).text == vendor
		string_cache_selected_driver([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert owner.get_parameter(GLenum(0x1f01)).text.len > 0
		string_cache_selected_driver([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert owner.get_parameter(GLenum(0x1f00)).text == vendor
		string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert owner.get_error() == no_error
	}
}

fn test_source_get_string_caches_an_actual_empty_driver_reply() {
	mut owner := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	owner.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	// HostWebGLContext.cpp:282-292 encodes a null driver pointer as one NUL,
	// yielding a successful empty cache value rather than a lost transport.
	assert owner.native.get_string(GLenum(0xffff_ffff)) == ''
	string_cache_selected_driver([i32(1), 2, 3, 4]!)
	assert C.vox_gl_get_error() == invalid_enum
	assert C.vox_gl_get_error() == no_error
	other.native.make_current()
	C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
	assert owner.native.get_string(GLenum(0xffff_ffff)) == ''
	string_cache_selected_driver([i32(9), 10, 11, 12]!)
	assert C.vox_gl_get_error() == invalid_value
	assert C.vox_gl_get_error() == no_error
}
