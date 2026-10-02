module html

import math
import dom

fn test_canvas_glyph_text_retains_filter_alpha_and_device_clip() {
	mut canvas := OffscreenCanvas.create(48, 48)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.set_font('24px sans-serif')
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(canvas_color_black())
	context.set_filter('invert(100%)')
	context.set_global_alpha(.5)
	mut clip := CanvasGfxPath{}
	clip.move_to(FloatPoint{8, 0})
	clip.line_to(FloatPoint{20, 0})
	clip.line_to(FloatPoint{20, 48})
	clip.line_to(FloatPoint{8, 48})
	clip.close()
	context.clip_internal(clip, 'nonzero')
	context.fill_text('OO', 0, 30, none)
	pixels := (context.get_image_data(0, 0, 48, 48, none)!).data()
	mut painted := 0
	for y in 0 .. 48 {
		for x in 0 .. 48 {
			index := (y * 48 + x) * 4
			if x < 8 || x >= 20 { assert pixels[index + 3] == 0 }
			if pixels[index + 3] == 0 { continue }
			painted++
			assert pixels[index] == 255
			assert pixels[index + 1] == 255
			assert pixels[index + 2] == 255
			assert pixels[index + 3] <= 128
		}
	}
	assert painted > 30
}

fn test_canvas_text_nonfinite_arguments_and_nonpositive_max_width_draw_nothing() {
	mut canvas := OffscreenCanvas.create(32, 32)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.fill_text('O', math.nan(), 20, none)
	context.fill_text('O', 0, math.inf(1), none)
	context.fill_text('O', 0, 20, math.nan())
	context.stroke_text('O', 0, 20, math.inf(1))
	context.stroke_text('O', math.inf(1), 20, none)
	context.fill_text('O', 0, 20, 0)
	context.stroke_text('O', 0, 20, -1)
	assert (context.get_image_data(0, 0, 32, 32, none)!).data() == []u8{len: 32 * 32 * 4}
}

fn test_canvas_text_shadow_retains_combined_outline_and_source_offset() {
	mut canvas := OffscreenCanvas.create(48, 48)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.set_font('20px sans-serif')
	context.set_shadow_color('red')
	context.set_shadow_offset_x(20)
	context.fill_text('I', 0, 24, none)
	pixels := (context.get_image_data(0, 0, 48, 48, none)!).data()
	mut red := 0
	mut black := 0
	for index := 0; index < pixels.len; index += 4 {
		if pixels[index + 3] == 0 { continue }
		if pixels[index] == 255 { red++ } else if pixels[index] == 0 { black++ }
	}
	assert red > 20
	assert black > 20
}

fn test_html_canvas_text_uses_same_glyph_pixels_and_presentation_as_offscreen() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	mut html_context := html_canvas_element_get_context(canvas, '2d', none)!
	mut offscreen := OffscreenCanvas.create(300, 150)!
	mut offscreen_context := offscreen.get_context(.canvas_2d, none)!
	html_context.set_font('24px sans-serif')
	offscreen_context.set_font('24px sans-serif')
	html_context.fill_text('Canvas', 10, 30, none)
	offscreen_context.fill_text('Canvas', 10, 30, none)
	html_pixels := (html_context.get_image_data(0, 0, 100, 48, none)!).data()
	assert html_pixels == (offscreen_context.get_image_data(0, 0, 100, 48, none)!).data()
	assert html_pixels.any(it != 0)
	source := html_canvas_element_ensure_external_content_source(canvas)
	html_canvas_element_present(canvas)
	frame := source.current_frame() or { panic('presented glyph frame') }
	assert frame.bitmap().data == (html_canvas_element_surface(canvas) or { panic('surface') }).data
}
