// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_browser_pixel_store_state_keeps_values_without_forwarding_to_gl() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.active_texture(texture0 + 1)
		other.native.make_current()
		context.pixel_storei(unpack_colorspace_conversion_webgl, -1)
		mut texture := i32(0)
		C.vox_gl_int_parameter(active_texture, &texture)
		// Source's empty Proxy::make_current and client-only return issue no GL work.
		assert texture == int(texture0)
		assert context.get_parameter(unpack_colorspace_conversion_webgl).integer == 4294967295
		assert context.get_error() == no_error
		context.pixel_storei(unpack_colorspace_conversion_webgl, 1234)
		assert context.get_parameter(unpack_colorspace_conversion_webgl).integer == 1234
		assert context.get_error() == no_error
		context.pixel_storei(unpack_colorspace_conversion_webgl, 0)
		assert context.get_parameter(unpack_colorspace_conversion_webgl).integer == 0
		context.pixel_storei(unpack_colorspace_conversion_webgl, int(browser_default_webgl))
		assert context.get_parameter(unpack_colorspace_conversion_webgl).integer == browser_default_webgl
		context.pixel_storei(unpack_flip_y_webgl, -2)
		context.pixel_storei(unpack_premultiply_alpha_webgl, 9)
		assert context.get_parameter(unpack_flip_y_webgl).boolean
		assert context.get_parameter(unpack_premultiply_alpha_webgl).boolean
		assert context.get_error() == no_error
		assert context.get_parameter(unpack_alignment).integer == 4
		context.pixel_storei(unpack_alignment, 3)
		assert context.get_parameter(unpack_alignment).integer == 4
		assert context.get_error() == invalid_value
		assert other.get_error() == no_error
	}
}
