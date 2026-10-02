// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_empty_extension_flags_filter_enable_and_cache_like_factories() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [
		'GL_OES_texture_float_linear',
		'GL_EXT_float_blend',
		'GL_EXT_frag_depth',
	])
	for name in ['OES_texture_float_linear', 'EXT_float_blend'] {
		assert name in context.get_supported_extensions(false)
		first := context.get_extension(name.to_upper_ascii(), false) or { panic(name) }
		second := context.get_extension(name, false) or { panic(name) }
		assert first == second
		assert first.name == name
		assert first.creates_empty_object
		assert first.context_id == context.identity()
		assert context.extension_enabled(name)
	}
	assert context.native.requested_extensions_ == ['GL_OES_texture_float_linear', 'GL_EXT_float_blend']
	assert context.get_extension('OES_texture_float_linearé', false) == none
	assert context.get_extension('EXT_float_blend\x00', false) == none
	assert 'EXT_frag_depth' !in context.get_supported_extensions(false)
	assert 'EXT_frag_depth' in context.get_supported_extensions(true)
	assert context.get_extension('EXT_frag_depth', true) == none
	mut unsupported := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [
		'GL_EXT_frag_depth',
	])
	assert 'OES_texture_float_linear' !in unsupported.get_supported_extensions(false)
	assert 'EXT_float_blend' !in unsupported.get_supported_extensions(false)
	assert unsupported.get_extension('EXT_float_blend', false) == none
}

fn test_source_empty_extensions_preserve_driver_support_on_both_webgl_versions() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		native := context.native.get_supported_opengl_extensions()
		for pair in [['OES_texture_float_linear', 'GL_OES_texture_float_linear'],
			['EXT_float_blend', 'GL_EXT_float_blend']] {
			if pair[1] !in native {
				assert context.get_extension(pair[0], false) == none
				continue
			}
			extension := context.get_extension(pair[0], false) or { panic(pair[0]) }
			assert extension.creates_empty_object
			assert pair[1] in context.native.requested_extensions_
		}
		assert context.get_error() == no_error
	}
}
