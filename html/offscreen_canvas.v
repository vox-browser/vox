// Copyright (c) 2025, Ladybird contributors
// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of OffscreenCanvas.{h,cpp} and
// OffscreenCanvasRenderingContext2D.{h,cpp}. The bitmap is an RGBA8888 byte
// buffer; operations which do not need a platform font or GPU painter are
// implemented directly.
module html

import cpuraster
import dom
import math

pub enum OffscreenRenderingContextID {
	canvas_2d
	bitmap_renderer
	webgl
	webgl2
}

pub struct ImageEncodeOptions {
pub:
	type_   string = 'image/png'
	quality ?f64
}

$if test {
	fn options_convert_or_default(options ?ImageEncodeOptions) ImageEncodeOptions {
		return options or { ImageEncodeOptions{} }
	}
}

@[heap]
pub struct OffscreenCanvas {
	dom.EventTarget
mut:
	width_             u32
	height_            u32
	bitmap_            ?&dom.Bitmap_
	context_           ?&OffscreenCanvasRenderingContext2D
	detached           bool
	oncontextlost_     ?&dom.CallbackType
	oncontextrestored_ ?&dom.CallbackType
}

fn create_transparent_canvas_bitmap(width u32, height u32) !&dom.Bitmap_ {
	if width == 0 || height == 0 {
		return error('zero-sized canvases do not have a bitmap')
	}
	byte_length := u64(width) * u64(height) * 4
	if byte_length > u64(max_int) {
		return error('InvalidStateError: canvas bitmap is too large')
	}
	return &dom.Bitmap_{
		width: int(width)
		height: int(height)
		pitch: int(width) * 4
		format: 0
		// The compact software renderer composites straight-alpha RGBA bytes.
		// Native retained-glyph replay changes this to premultiplied when it
		// installs a Skia-rendered canvas snapshot.
		alpha_type: 1
		data: []u8{len: int(byte_length)}
	}
}

pub fn OffscreenCanvas.create(width u32, height u32) !&OffscreenCanvas {
	mut bitmap := ?&dom.Bitmap_(none)
	if width > 0 && height > 0 {
		bitmap = create_transparent_canvas_bitmap(width, height)!
	}
	return &OffscreenCanvas{
		width_: width
		height_: height
		bitmap_: bitmap
	}
}

pub fn OffscreenCanvas.construct_impl(width u32, height u32) !&OffscreenCanvas {
	return OffscreenCanvas.create(width, height)
}

pub fn (canvas &OffscreenCanvas) width() u32 {
	return canvas.width_
}

pub fn (canvas &OffscreenCanvas) height() u32 {
	return canvas.height_
}

pub fn (canvas &OffscreenCanvas) bitmap() ?&dom.Bitmap_ {
	return canvas.bitmap_
}

fn (mut canvas OffscreenCanvas) set_new_bitmap_size(width u32, height u32) ! {
	canvas.width_ = width
	canvas.height_ = height
	canvas.bitmap_ = none
	if width > 0 && height > 0 {
		canvas.bitmap_ = create_transparent_canvas_bitmap(width, height)!
	}
	if context := canvas.context_ {
		mut mutable_context := unsafe { &OffscreenCanvasRenderingContext2D(context) }
		mutable_context.set_size(width, height)
		mutable_context.reset_to_default_state()
	}
}

pub fn (mut canvas OffscreenCanvas) set_width(width u32) ! {
	canvas.set_new_bitmap_size(width, canvas.height_)!
}

pub fn (mut canvas OffscreenCanvas) set_height(height u32) ! {
	canvas.set_new_bitmap_size(canvas.width_, height)!
}

pub fn (mut canvas OffscreenCanvas) reset_context_to_default_state() {
	if context := canvas.context_ {
		mut mutable_context := unsafe { &OffscreenCanvasRenderingContext2D(context) }
		mutable_context.reset_to_default_state()
	}
}

pub fn (canvas &OffscreenCanvas) bitmap_size_for_canvas() (u32, u32) {
	return canvas.width_, canvas.height_
}

pub fn (mut canvas OffscreenCanvas) set_oncontextlost(callback ?&dom.CallbackType) {
	canvas.oncontextlost_ = callback
}

pub fn (canvas &OffscreenCanvas) oncontextlost() ?&dom.CallbackType {
	return canvas.oncontextlost_
}

pub fn (mut canvas OffscreenCanvas) set_oncontextrestored(callback ?&dom.CallbackType) {
	canvas.oncontextrestored_ = callback
}

pub fn (canvas &OffscreenCanvas) oncontextrestored() ?&dom.CallbackType {
	return canvas.oncontextrestored_
}

pub fn (mut canvas OffscreenCanvas) create_2d_context(options ?map[string]dom.JSValue) !&OffscreenCanvasRenderingContext2D {
	return canvas.get_context(.canvas_2d, options)
}

pub fn (mut canvas OffscreenCanvas) get_context(context_id OffscreenRenderingContextID, options ?map[string]dom.JSValue) !&OffscreenCanvasRenderingContext2D {
	if canvas.detached {
		return error('InvalidStateError: OffscreenCanvas is detached')
	}
	if context_id != .canvas_2d {
		return unsafe { nil }
	}
	if context := canvas.context_ {
		return context
	}
	settings := CanvasRenderingContext2DSettings.from_js_value(options)!
	context := OffscreenCanvasRenderingContext2D.create(&canvas, settings)
	canvas.context_ = context
	return context
}

pub fn (mut canvas OffscreenCanvas) transfer_to_image_bitmap() !&ImageBitmap {
	if canvas.detached {
		return error('InvalidStateError: OffscreenCanvas is detached')
	}
	mut image_bitmap := ImageBitmap.create()
	image_bitmap.set_bitmap(canvas.bitmap_)
	canvas.bitmap_ = none
	if canvas.width_ > 0 && canvas.height_ > 0 {
		canvas.bitmap_ = create_transparent_canvas_bitmap(canvas.width_, canvas.height_)!
	}
	return image_bitmap
}

pub fn (canvas &OffscreenCanvas) convert_to_blob(options ImageEncodeOptions, encode_png PNGEncodeCallback, encode_jpeg JPEGEncodeCallback) !SerializeBitmapResult {
	if canvas.detached {
		return error('InvalidStateError: OffscreenCanvas is detached')
	}
	bitmap := canvas.bitmap_ or { return error('IndexSizeError: canvas has no pixels') }
	return serialize_bitmap(bitmap, options.type_, options.quality, encode_png, encode_jpeg)
}

pub fn (mut canvas OffscreenCanvas) transfer_steps() []u8 {
	mut bitmap := ImageBitmap.create()
	bitmap.set_bitmap(canvas.bitmap_)
	mut output := bitmap.transfer_steps()
	canvas.bitmap_ = none
	canvas.width_ = 0
	canvas.height_ = 0
	canvas.detached = true
	return output
}

pub fn offscreen_canvas_transfer_receiving_steps(data []u8) !&OffscreenCanvas {
	image_bitmap := image_bitmap_transfer_receiving_steps(data)!
	mut canvas := OffscreenCanvas.create(image_bitmap.width(), image_bitmap.height())!
	canvas.bitmap_ = image_bitmap.bitmap()
	return canvas
}

pub fn (_ &OffscreenCanvas) primary_interface() TransferType {
	return .offscreen_canvas
}

@[heap]
pub struct OffscreenCanvasRenderingContext2D {
	CanvasState
	CanvasPath
pub:
	canvas_            &OffscreenCanvas
	context_attributes CanvasRenderingContext2DSettings
mut:
	width_  u32
	height_ u32
	// fillText()'s glyph masks, made on the first glyph run.
	glyph_cache &cpuraster.GlyphCache = unsafe { nil }
}

fn offscreen_canvas_state_reset(target voidptr) {
	mut context := unsafe { &OffscreenCanvasRenderingContext2D(target) }
	context.reset_to_default_state()
}

pub fn OffscreenCanvasRenderingContext2D.create(canvas &OffscreenCanvas, settings CanvasRenderingContext2DSettings) &OffscreenCanvasRenderingContext2D {
	mut context := &OffscreenCanvasRenderingContext2D{
		canvas_: canvas
		context_attributes: settings
		width_: canvas.width()
		height_: canvas.height()
	}
	context.CanvasPath.canvas_state_ = &context.CanvasState
	context.CanvasState.set_reset_callback(voidptr(context), offscreen_canvas_state_reset)
	if !settings.alpha { context.clear_rect(0, 0, f64(canvas.width()), f64(canvas.height())) }
	return context
}

pub fn (context &OffscreenCanvasRenderingContext2D) canvas() &OffscreenCanvas {
	return context.canvas_
}

pub fn (context &OffscreenCanvasRenderingContext2D) get_context_attributes() CanvasRenderingContext2DSettings {
	return context.context_attributes
}

pub fn (context &OffscreenCanvasRenderingContext2D) painter_for_canvas_state() voidptr {
	_ = context
	return unsafe { nil }
}

pub fn (mut context OffscreenCanvasRenderingContext2D) path_for_canvas_state() &CanvasGfxPath {
	return context.CanvasPath.mutable_path_storage()
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_size(width u32, height u32) {
	context.width_ = width
	context.height_ = height
}

pub fn (mut context OffscreenCanvasRenderingContext2D) reset_to_default_state() {
	context.clear_rect(0, 0, f64(context.width_), f64(context.height_))
	context.CanvasState.reset_drawing_state()
	context.CanvasState.clear_drawing_state_stack()
	context.CanvasPath.path_ = CanvasGfxPath{}
}

fn canvas_clamped_rectangle(x f64, y f64, width f64, height f64, bounds_width int, bounds_height int) (int, int, int, int) {
	mut x0 := x
	mut y0 := y
	mut x1 := x + width
	mut y1 := y + height
	if x1 < x0 {
		x0, x1 = x1, x0
	}
	if y1 < y0 {
		y0, y1 = y1, y0
	}
	left := int(math.max(0.0, math.floor(x0)))
	top := int(math.max(0.0, math.floor(y0)))
	right := int(math.min(f64(bounds_width), math.ceil(x1)))
	bottom := int(math.min(f64(bounds_height), math.ceil(y1)))
	return left, top, right, bottom
}

pub fn (mut context OffscreenCanvasRenderingContext2D) fill_rect(x f64, y f64, width f64, height f64) {
	if !is_finite(x) || !is_finite(y) || !is_finite(width) || !is_finite(height) {
		return
	}
	context.fill_internal(context.rect_path(x, y, width, height), 'evenodd')
}

pub fn (mut context OffscreenCanvasRenderingContext2D) clear_rect(x f64, y f64, width f64, height f64) {
	if !is_finite(x) || !is_finite(y) || !is_finite(width) || !is_finite(height) {
		return
	}
	context.paint_canvas_bitmap_command(1, none, CanvasFloatRect{}, CanvasFloatRect{x, y, width, height})
}

pub fn (mut context OffscreenCanvasRenderingContext2D) stroke_rect(x f64, y f64, width f64, height f64) {
	if !is_finite(x) || !is_finite(y) || !is_finite(width) || !is_finite(height) {
		return
	}
	if context.drawing_state.line_width <= 0 || !is_finite(context.drawing_state.line_width) {
		return
	}
	context.stroke_internal(context.rect_path(x, y, width, height))
}

pub fn (mut context OffscreenCanvasRenderingContext2D) begin_path() {
	context.CanvasPath.path_ = CanvasGfxPath{}
}

pub fn (context &OffscreenCanvasRenderingContext2D) create_image_data(width int, height int, settings ?ImageDataSettings) !&ImageData {
	if width == 0 || height == 0 {
		return error('IndexSizeError: width and height must be non-zero')
	}
	return ImageData.create(u32(if width < 0 { -width } else { width }), u32(if height < 0 {
		-height
	} else {
		height
	}), settings)
}

pub fn (context &OffscreenCanvasRenderingContext2D) create_image_data_from(source &ImageData) !&ImageData {
	return ImageData.create(source.width(), source.height(), ImageDataSettings{
		color_space: source.color_space()
	})
}

pub fn (context &OffscreenCanvasRenderingContext2D) get_image_data(x int, y int, width int, height int, settings ?ImageDataSettings) !&ImageData {
	if width == 0 || height == 0 {
		return error('IndexSizeError: width and height must be non-zero')
	}
	if !context.origin_clean() {
		return error('SecurityError: CanvasRenderingContext2D is not origin-clean')
	}
	actual_x := if width < 0 { x + width } else { x }
	actual_y := if height < 0 { y + height } else { y }
	actual_width := if width < 0 { -width } else { width }
	actual_height := if height < 0 { -height } else { height }
	mut result := ImageData.create(u32(actual_width), u32(actual_height), settings)!
	bitmap := context.canvas_.bitmap() or { return result }
	mut result_pixels := result.data()
	// Canvas2DContextBase.cpp: ImageData receives unpremultiplied pixels.
	if bitmap.alpha_type == 2 {
		cpuraster.read_pixels(bitmap.data, bitmap.width, bitmap.height, bitmap.pitch, int(bitmap.alpha_type), mut result_pixels, actual_width, actual_height, actual_width * 4, actual_x, actual_y)
		return result
	}
	for row := 0; row < actual_height; row++ {
		for column := 0; column < actual_width; column++ {
			source_x := actual_x + column
			source_y := actual_y + row
			if source_x < 0 || source_y < 0 || source_x >= bitmap.width || source_y >= bitmap.height {
				continue
			}
			source_offset := source_y * bitmap.pitch + source_x * 4
			destination_offset := (row * actual_width + column) * 4
			for channel := 0; channel < 4; channel++ {
				result_pixels[destination_offset + channel] = bitmap.data[source_offset + channel]
			}
		}
	}
	return result
}

pub fn (mut context OffscreenCanvasRenderingContext2D) put_image_data(image_data &ImageData, x int, y int) {
	context.put_image_data_dirty(image_data, x, y, 0, 0, int(image_data.width()), int(image_data.height()))
}

pub fn (mut context OffscreenCanvasRenderingContext2D) put_image_data_dirty(image_data &ImageData, x int, y int, dirty_x int, dirty_y int, dirty_width int, dirty_height int) {
	bitmap := context.canvas_.bitmap() or { return }
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	if mutable_bitmap.alpha_type == 2 {
		mut straight_pixels := []u8{len: mutable_bitmap.data.len}
		if cpuraster.read_pixels(mutable_bitmap.data, mutable_bitmap.width, mutable_bitmap.height, mutable_bitmap.pitch, 2, mut straight_pixels, mutable_bitmap.width, mutable_bitmap.height, mutable_bitmap.pitch, 0, 0) {
			mutable_bitmap.data = straight_pixels
			mutable_bitmap.alpha_type = 1
		}
	}
	source := image_data.data()
	left, top, right, bottom := canvas_clamped_rectangle(f64(dirty_x), f64(dirty_y), f64(dirty_width), f64(dirty_height), int(image_data.width()), int(image_data.height()))
	for source_y := top; source_y < bottom; source_y++ {
		for source_x := left; source_x < right; source_x++ {
			destination_x := x + source_x
			destination_y := y + source_y
			if destination_x < 0 || destination_y < 0 || destination_x >= bitmap.width || destination_y >= bitmap.height {
				continue
			}
			source_offset := (source_y * int(image_data.width()) + source_x) * 4
			destination_offset := destination_y * mutable_bitmap.pitch + destination_x * 4
			for channel := 0; channel < 4; channel++ {
				mutable_bitmap.data[destination_offset + channel] = source[source_offset + channel]
			}
		}
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) draw_image_internal(request CanvasDrawImageRequest) ! {
    if ![request.source_x, request.source_y, request.source_width, request.source_height, request.destination_x, request.destination_y, request.destination_width, request.destination_height].all(is_finite(it)) { return }
    if check_usability_of_image(request.image) == .bad { return }
    mut sx := request.source_x
    mut sy := request.source_y
    mut sw := request.source_width
    mut sh := request.source_height
    mut dx := request.destination_x
    mut dy := request.destination_y
    mut dw := request.destination_width
    mut dh := request.destination_height
    if sw < 0 { sx += sw; sw = -sw }
    if sh < 0 { sy += sh; sh = -sh }
    if dw < 0 { dx += dw; dw = -dw }
    if dh < 0 { dy += dh; dh = -dh }
    if sw == 0 || sh == 0 { return }
    frame := canvas_image_source_frame(request.image) or { return }
    context.paint_canvas_bitmap_command(2, frame, CanvasFloatRect{sx, sy, sw, sh}, CanvasFloatRect{dx, dy, dw, dh})
    if image_is_not_origin_clean(request.image) { context.set_origin_clean(false) }

}

pub fn (context &OffscreenCanvasRenderingContext2D) measure_text(text string) &TextMetrics {
	mut metrics := TextMetrics.create()
	replaced := text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ').replace('\f', ' ')
	run := canvas_text_run_for_canvas_state(&context.CanvasState, replaced, 0)
	font_metrics := run.font().pixel_metrics()
	baseline_offset := canvas_text_baseline_offset(context.drawing_state.text_baseline, font_metrics)
	em_ascent, em_descent := canvas_em_square_ascent_and_descent(font_metrics)
	metrics.set_width(f64(run.width()))
	metrics.set_font_bounding_box_ascent(f64(font_metrics.ascent) - baseline_offset)
	metrics.set_font_bounding_box_descent(f64(font_metrics.descent) + baseline_offset)
	metrics.set_em_height_ascent(em_ascent - baseline_offset)
	metrics.set_em_height_descent(em_descent + baseline_offset)
	metrics.set_hanging_baseline(f64(font_metrics.ascent) * 0.8 - baseline_offset)
	metrics.set_alphabetic_baseline(-baseline_offset)
	metrics.set_ideographic_baseline(-f64(font_metrics.descent) - baseline_offset)
	return metrics
}

pub fn (context &OffscreenCanvasRenderingContext2D) font() string {
	return context.drawing_state.font_string
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_font(font string) {
	mut styles := CanvasTextDrawingStyles.create(&context.CanvasState)
	styles.set_font(font)
}

pub fn (context &OffscreenCanvasRenderingContext2D) image_smoothing_enabled() bool {
	return context.drawing_state.image_smoothing_enabled
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_image_smoothing_enabled(value bool) {
	context.drawing_state.image_smoothing_enabled = value
}

pub fn (context &OffscreenCanvasRenderingContext2D) image_smoothing_quality() ImageSmoothingQuality {
	return context.drawing_state.image_smoothing_quality
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_image_smoothing_quality(value ImageSmoothingQuality) {
	context.drawing_state.image_smoothing_quality = value
}

pub fn (context &OffscreenCanvasRenderingContext2D) global_alpha() f64 {
	return context.drawing_state.global_alpha
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_global_alpha(value f64) {
	if is_finite(value) && value >= 0 && value <= 1 {
		context.drawing_state.global_alpha = value
	}
}

pub fn (context &OffscreenCanvasRenderingContext2D) shadow_offset_x() f64 {
	return context.drawing_state.shadow_offset_x
}

pub fn (context &OffscreenCanvasRenderingContext2D) shadow_offset_y() f64 {
	return context.drawing_state.shadow_offset_y
}

pub fn (context &OffscreenCanvasRenderingContext2D) shadow_blur() f64 {
	return context.drawing_state.shadow_blur
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_shadow_offset_x(value f64) {
	if is_finite(value) {
		context.drawing_state.shadow_offset_x = value
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_shadow_offset_y(value f64) {
	if is_finite(value) {
		context.drawing_state.shadow_offset_y = value
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_shadow_blur(value f64) {
	if is_finite(value) && value >= 0 {
		context.drawing_state.shadow_blur = value
	}
}

fn canvas_transform_multiply(left CanvasAffineTransform, right CanvasAffineTransform) CanvasAffineTransform {
	return CanvasAffineTransform{
		a: left.a * right.a + left.c * right.b
		b: left.b * right.a + left.d * right.b
		c: left.a * right.c + left.c * right.d
		d: left.b * right.c + left.d * right.d
		e: left.a * right.e + left.c * right.f + left.e
		f: left.b * right.e + left.d * right.f + left.f
	}
}

pub fn (mut context OffscreenCanvasRenderingContext2D) transform(transform CanvasAffineTransform) {
	if ![transform.a, transform.b, transform.c, transform.d, transform.e, transform.f].all(is_finite(it)) {
		return
	}
	context.drawing_state.transform = canvas_transform_multiply(context.drawing_state.transform, transform)
}

pub fn (mut context OffscreenCanvasRenderingContext2D) set_transform(transform CanvasAffineTransform) {
	if ![transform.a, transform.b, transform.c, transform.d, transform.e, transform.f].all(is_finite(it)) {
		return
	}
	context.drawing_state.transform = transform
}

pub fn (mut context OffscreenCanvasRenderingContext2D) reset_transform() {
	context.drawing_state.transform = CanvasAffineTransform{}
}
