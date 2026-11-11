module html

import dom
import geometry

fn canvas_raster_pixel(mut context OffscreenCanvasRenderingContext2D, x int, y int) []u8 {
	return (context.get_image_data(x, y, 1, 1, none) or { panic(err) }).data()
}

fn test_canvas_raster_uses_sorted_live_gradient_stops_and_all_gradient_kinds() {
	mut canvas := OffscreenCanvas.create(32, 32) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	mut gradient := CanvasGradient.create_linear(0, 0, 32, 0)
	context.drawing_state.fill_style = FillOrStrokeStyle.from_gradient(gradient)
	// The state refers to the gradient object; additions after assignment are live.
	gradient.add_color_stop(1, 'blue') or { panic(err) }
	gradient.add_color_stop(0, 'red') or { panic(err) }
	context.fill_rect(0, 0, 32, 8)
	left := canvas_raster_pixel(mut context, 0, 3)
	right := canvas_raster_pixel(mut context, 31, 3)
	assert left[0] > 240 && left[2] < 15 && left[3] == 255
	assert right[2] > 240 && right[0] < 15 && right[3] == 255
	assert gradient.color_stops_for_painting().map(it.offset) == [f64(0), 1]
	mut radial := CanvasGradient.create_radial(16, 16, 0, 16, 16, 12) or { panic(err) }
	radial.add_color_stop(0, 'red') or { panic(err) }
	radial.add_color_stop(1, 'blue') or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_gradient(radial)
	context.fill_rect(0, 8, 32, 24)
	center := canvas_raster_pixel(mut context, 16, 16)
	edge := canvas_raster_pixel(mut context, 28, 16)
	assert center[0] > 230 && center[2] < 25
	assert edge[2] > 240 && edge[0] < 15
	mut conic := CanvasGradient.create_conic(0, 16, 16)
	conic.add_color_stop(0, 'red') or { panic(err) }
	conic.add_color_stop(1, 'blue') or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_gradient(conic)
	context.fill_rect(0, 0, 32, 32)
	start := canvas_raster_pixel(mut context, 28, 16)
	before_start := canvas_raster_pixel(mut context, 28, 15)
	assert start[0] > 240 && start[2] < 15
	assert before_start[2] > 240 && before_start[0] < 15
}

fn test_canvas_raster_pattern_repetition_and_live_transform() {
	mut image := ImageBitmap.create()
	image.set_bitmap(&dom.Bitmap_{
		width:      2
		height:     1
		pitch:      8
		alpha_type: 1
		data:       [
			u8(255),
			0,
			0,
			255,
			0,
			255,
			0,
			255,
		]
	})
	result := CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: image }), 'repeat-x') or { panic(err) }
	mut pattern := result.pattern or { panic('missing pattern') }
	mut canvas := OffscreenCanvas.create(8, 3) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_pattern(pattern)
	context.fill_rect(0, 0, 8, 3)
	assert canvas_raster_pixel(mut context, 4, 0) == [u8(255), 0, 0, 255]
	assert canvas_raster_pixel(mut context, 5, 0) == [u8(0), 255, 0, 255]
	assert canvas_raster_pixel(mut context, 4, 2)[3] == 0
	no_repeat_result := CanvasPattern.create(CanvasImageSource(ImageBitmapCanvasSource{ value: image }), 'no-repeat') or { panic(err) }
	pattern = no_repeat_result.pattern or { panic('missing pattern') }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_pattern(pattern)
	mut transform := geometry.DOMMatrix2DInit{ e: 2, f: 1 }
	pattern.set_transform(mut transform) or { panic(err) }
	context.clear_rect(0, 0, 8, 3)
	context.fill_rect(0, 0, 8, 3)
	assert canvas_raster_pixel(mut context, 0, 1)[3] == 0
	assert canvas_raster_pixel(mut context, 2, 1) == [u8(255), 0, 0, 255]
	assert canvas_raster_pixel(mut context, 3, 1) == [u8(0), 255, 0, 255]
	assert canvas_raster_pixel(mut context, 4, 1)[3] == 0
}

fn test_canvas_raster_stroke_caps_joins_miter_and_dashes() {
	mut canvas := OffscreenCanvas.create(32, 32) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.line_width = 8
	mut line := CanvasGfxPath{}
	line.move_to(FloatPoint{8, 8})
	line.line_to(FloatPoint{24, 8})
	context.stroke_internal(line)
	assert canvas_raster_pixel(mut context, 4, 8)[3] == 0
	context.drawing_state.line_cap = .square
	context.stroke_internal(line)
	assert canvas_raster_pixel(mut context, 4, 8)[3] == 255
	context.clear_rect(0, 0, 32, 32)
	context.drawing_state.line_cap = .round
	context.stroke_internal(line)
	assert canvas_raster_pixel(mut context, 4, 8)[3] > 0
	assert canvas_raster_pixel(mut context, 4, 4)[3] == 0
	mut angle := CanvasGfxPath{}
	angle.move_to(FloatPoint{4, 24})
	angle.line_to(FloatPoint{16, 8})
	angle.line_to(FloatPoint{28, 24})
	context.clear_rect(0, 0, 32, 32)
	context.drawing_state.line_cap = .butt
	context.drawing_state.line_join = .miter
	context.stroke_internal(angle)
	miter := canvas_raster_pixel(mut context, 16, 2)[3]
	context.clear_rect(0, 0, 32, 32)
	context.drawing_state.line_join = .bevel
	context.stroke_internal(angle)
	assert miter > 0 && canvas_raster_pixel(mut context, 16, 2)[3] == 0
	context.clear_rect(0, 0, 32, 32)
	context.drawing_state.line_join = .miter
	context.drawing_state.miter_limit = 1
	context.stroke_internal(angle)
	assert canvas_raster_pixel(mut context, 16, 2)[3] == 0
	context.clear_rect(0, 0, 32, 32)
	context.drawing_state.line_width = 2
	context.drawing_state.dash_list = [f64(4), 4]
	mut dashed := CanvasGfxPath{}
	dashed.move_to(FloatPoint{4, 24})
	dashed.line_to(FloatPoint{28, 24})
	context.stroke_internal(dashed)
	assert canvas_raster_pixel(mut context, 5, 24)[3] == 255
	assert canvas_raster_pixel(mut context, 9, 24)[3] == 0
	assert canvas_raster_pixel(mut context, 13, 24)[3] == 255
	context.drawing_state.line_dash_offset = 4
	context.clear_rect(0, 0, 32, 32)
	context.stroke_internal(dashed)
	assert canvas_raster_pixel(mut context, 5, 24)[3] == 0
	assert canvas_raster_pixel(mut context, 9, 24)[3] == 255
}

fn test_canvas_raster_shadows_use_output_offsets_blur_and_source_alpha() {
	mut canvas := OffscreenCanvas.create(24, 20) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.drawing_state.shadow_color = dom.Color{ b: 255, a: 255 }
	context.drawing_state.shadow_offset_x = 6
	context.drawing_state.global_alpha = .5
	context.drawing_state.transform = CanvasAffineTransform{ a: 2, d: 2 }
	context.fill_rect(1, 2, 1, 1)
	shadow := canvas_raster_pixel(mut context, 8, 4)
	assert shadow[0] == 0 && shadow[2] == 255 && shadow[3] == 128
	assert canvas_raster_pixel(mut context, 14, 4)[3] == 0
	context.clear_rect(0, 0, 12, 10)
	context.drawing_state.transform = CanvasAffineTransform{}
	context.drawing_state.global_alpha = 1
	context.drawing_state.shadow_offset_x = 0
	context.drawing_state.shadow_blur = 4
	context.fill_rect(8, 8, 4, 4)
	blurred := canvas_raster_pixel(mut context, 6, 9)
	assert blurred[2] > 0 && blurred[3] > 0 && blurred[3] < 255
	// Upstream's stroke shadow obtains opacity from fill_style, not stroke_style.
	context.clear_rect(0, 0, 24, 20)
	context.drawing_state.shadow_blur = 0
	context.drawing_state.shadow_offset_y = 6
	context.drawing_state.line_width = 2
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 64 })
	mut line := CanvasGfxPath{}
	line.move_to(FloatPoint{4, 4})
	line.line_to(FloatPoint{12, 4})
	context.stroke_internal(line)
	assert canvas_raster_pixel(mut context, 8, 10)[3] == 64
}

fn test_canvas_raster_filter_chain_failure_reset_save_and_blurred_shadow_overload() {
	mut canvas := OffscreenCanvas.create(24, 20) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.set_filter('invert(1)')
	context.fill_rect(0, 0, 4, 4)
	assert canvas_raster_pixel(mut context, 1, 1) == [u8(0), 255, 255, 255]
	context.save()
	context.set_filter('brightness(0)')
	context.restore()
	context.fill_rect(4, 0, 4, 4)
	assert canvas_raster_pixel(mut context, 5, 1) == [u8(0), 255, 255, 255]
	context.set_filter('invalid(')
	assert context.filter() == 'invert(1)'
	assert context.drawing_state.filter_functions.len == 0
	context.fill_rect(8, 0, 4, 4)
	assert canvas_raster_pixel(mut context, 9, 1) == [u8(255), 0, 0, 255]
	context.set_filter('blur(1em)')
	assert context.drawing_state.filter_functions[0].amount == 10
	context.set_filter('blur(calc(sibling-index() * 1px))')
	assert context.drawing_state.filter_functions.len == 0
	context.set_filter('blur(random(1px, 2px))')
	assert context.drawing_state.filter_functions.len == 0
	context.set_filter('blur(2px)')
	context.fill_rect(8, 8, 4, 4)
	assert canvas_raster_pixel(mut context, 6, 9)[3] > 0
	context.clear_rect(0, 0, 24, 20)
	context.set_filter('invert(1)')
	context.drawing_state.shadow_color = dom.Color{ r: 255, a: 255 }
	context.drawing_state.shadow_offset_x = 8
	context.drawing_state.shadow_blur = 4
	context.fill_rect(2, 8, 4, 4)
	shadow := canvas_raster_pixel(mut context, 12, 10)
	assert shadow[0] > 0 && shadow[1] == 0 && shadow[2] == 0
	context.set_filter('drop-shadow(4px 0px 0px blue)')
	context.drawing_state.shadow_color = canvas_color_transparent()
	context.fill_rect(0, 0, 2, 2)
	assert canvas_raster_pixel(mut context, 4, 0) == [u8(0), 0, 255, 255]
}

fn test_canvas_raster_executes_each_source_color_filter_and_chain_order() {
	mut canvas := OffscreenCanvas.create(2, 2) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	filters := ['brightness(0)', 'contrast(0)', 'invert(100%)', 'opacity(50%)', 'grayscale(1)',
		'sepia(1)', 'saturate(0)', 'hue-rotate(180deg)', 'brightness(.5) contrast(0)',
		'contrast(0) brightness(.5)']
	expected := [[u8(0), 0, 0, 255], [u8(128), 128, 128, 255], [u8(0), 255, 255, 255],
		[u8(255), 0, 0, 128], [u8(54), 54, 54, 255], [u8(100), 89, 69, 255], [u8(54), 54, 54, 255],
		[u8(0), 109, 109, 255], [u8(128), 128, 128, 255], [u8(64), 64, 64, 255]]
	for i, filter in filters {
		context.clear_rect(0, 0, 2, 2)
		context.set_filter(filter)
		context.fill_rect(0, 0, 2, 2)
		assert canvas_raster_pixel(mut context, 0, 0) == expected[i], filter
	}
}

fn test_canvas_readback_unpremultiplies_native_pixels_and_image_data_write_keeps_straight_alpha() {
	mut canvas := OffscreenCanvas.create(2, 1) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	mut bitmap := canvas.bitmap() or { panic('missing bitmap') }
	bitmap.alpha_type = 2
	bitmap.data = [u8(128), 0, 0, 128, 0, 64, 0, 128]
	assert canvas_raster_pixel(mut context, 0, 0) == [u8(255), 0, 0, 128]
	assert canvas_raster_pixel(mut context, 1, 0) == [u8(0), 128, 0, 128]
	image := ImageData.create_with_data([u8(0), 0, 255, 64], 1, 1, none) or { panic(err) }
	context.put_image_data(image, 0, 0)
	assert bitmap.alpha_type == 1
	assert canvas_raster_pixel(mut context, 0, 0) == [u8(0), 0, 255, 64]
	assert canvas_raster_pixel(mut context, 1, 0) == [u8(0), 128, 0, 128]
}

fn test_canvas_bitmap_command_uses_transform_clip_filter_and_source_alpha_truncation() {
	mut image := ImageBitmap.create()
	image.set_bitmap(&dom.Bitmap_{ width: 2, height: 1, pitch: 8, alpha_type: 1, data: [
		u8(255),
		0,
		0,
		255,
		0,
		0,
		255,
		255,
	] })
	mut canvas := OffscreenCanvas.create(8, 4) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.image_smoothing_enabled = false
	context.drawing_state.transform = CanvasAffineTransform{ e: 2, f: 1 }
	context.rect(0, 0, 1, 1)
	context.clip('nonzero')
	context.begin_path()
	context.set_filter('invert(100%)')
	context.set_global_alpha(.5)
	context.draw_image_internal(CanvasDrawImageRequest{ image: ImageBitmapCanvasSource{ value: image }, source_width: 2, source_height: 1, destination_width: 2, destination_height: 1 }) or { panic(err) }
	assert canvas_raster_pixel(mut context, 2, 1) == [u8(0), 255, 255, 127]
	assert canvas_raster_pixel(mut context, 3, 1) == [u8(0), 0, 0, 0]
	assert canvas_raster_pixel(mut context, 0, 0) == [u8(0), 0, 0, 0]
	context.set_filter('blur(2px)')
	context.set_global_alpha(0)
	context.clear_rect(0, 0, 2, 1)
	assert canvas_raster_pixel(mut context, 2, 1) == [u8(0), 0, 0, 0]
}

fn test_canvas_bitmap_command_normalizes_negative_rectangles_and_clear_alpha_false() {
	mut image := ImageBitmap.create()
	image.set_bitmap(&dom.Bitmap_{ width: 2, height: 1, pitch: 8, alpha_type: 1, data: [
		u8(255),
		0,
		0,
		255,
		0,
		0,
		255,
		255,
	] })
	mut canvas := OffscreenCanvas.create(4, 2) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.image_smoothing_enabled = false
	context.draw_image_internal(CanvasDrawImageRequest{ image: ImageBitmapCanvasSource{ value: image }, source_x: 2, source_width: -2, source_height: 1, destination_x: 3, destination_width: -2, destination_height: 1 }) or { panic(err) }
	assert canvas_raster_pixel(mut context, 1, 0) == [u8(255), 0, 0, 255]
	assert canvas_raster_pixel(mut context, 2, 0) == [u8(0), 0, 255, 255]
	mut opaque_canvas := OffscreenCanvas.create(2, 2) or { panic(err) }
	mut opaque := opaque_canvas.get_context(.canvas_2d, {
		'alpha': dom.js_bool(false)
	}) or { panic(err) }
	opaque.clear_rect(0, 0, 2, 2)
	assert canvas_raster_pixel(mut opaque, 0, 0) == [u8(0), 0, 0, 255]
}
