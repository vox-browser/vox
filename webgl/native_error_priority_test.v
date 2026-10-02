// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_error_queries_current_driver_between_pending_and_translation_errors() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_error(invalid_value)
		context.native.set_pending_local_error(out_of_memory)
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		assert context.get_error() == out_of_memory
		assert context.get_error() == invalid_enum
		assert context.get_error() == invalid_value
		assert context.get_error() == no_error
		assert other.get_error() == no_error
		// The source loss branch reports its stored error once and skips GL queries.
		context.lose_context('test')
		assert context.get_error() == context_lost_webgl
		assert context.get_error() == no_error
		assert other.get_error() == no_error
	}
}
