// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_draw_buffer_state_does_not_dirty_canvas_presentation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{
			preserve_drawing_buffer: true
		}, [])
		context.set_size(2, 2)
		context.clear_color(1, 0, 0, 1)
		context.clear(GLenum(0x4000))
		assert context.native.needs_to_present()
		assert context.native.present_with_preserved_buffer(true)
		assert !context.native.needs_to_present()
		before := context.native.painting_surface() or { panic('surface') }
		framebuffer_object := context.create_framebuffer()
		context.bind_framebuffer(framebuffer, framebuffer_object)
		if version == .webgl2 {
			context.draw_buffers([color_attachment0])
		} else {
			extension := context.get_extension('WEBGL_draw_buffers', false) or { panic('draw buffers') }
			extension.draw_buffers_webgl(mut context, [color_attachment0])
		}
		assert context.get_error() == no_error
		assert !context.native.needs_to_present()
		after := context.native.painting_surface() or { panic('surface') }
		assert after.pixels == before.pixels
		context.bind_framebuffer(framebuffer, none)
		context.clear(GLenum(0x4000))
		assert context.native.needs_to_present()
		assert context.get_error() == no_error
	}
}
