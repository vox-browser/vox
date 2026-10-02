// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_is_enabled_reads_actual_driver_state_and_rejects_non_capability_enums() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		assert context.is_enabled(dither)
		assert !context.is_enabled(blend)
		context.native.dispatch('enable', blend)
		assert blend !in context.enabled_capabilities
		other.native.make_current()
		assert context.is_enabled(blend)
		assert !other.is_enabled(blend)
		context.enable(blend)
		context.native.dispatch('disable', blend)
		assert blend in context.enabled_capabilities
		assert !context.is_enabled(blend)
		assert context.get_error() == no_error
		assert other.get_error() == no_error
		// COLOR_CLEAR_VALUE is a valid getParameter pname but not a capability.
		assert !context.is_enabled(color_clear_value)
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
		context.enable(GLenum(0xbad))
		assert context.get_error() == invalid_enum
		assert !context.is_enabled(GLenum(0xbad))
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
	}
}
