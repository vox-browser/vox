// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Painting/DisplayListRecordingContext.{h,cpp}.
@[has_globals]
module painting

import css

__global painting_next_paint_generation_id u64

// Gfx::Palette is owned by the native platform layer. The painting translation
// retains its immutable identity, just as the C++ Palette value retains a
// reference to its shared PaletteImpl.
pub type Palette = string

pub struct DisplayListRecordingContext {
	display_list_recorder_handle_ voidptr
	palette_                      Palette
	device_pixel_converter_       DevicePixelConverter
	chrome_metrics_               ChromeMetrics
	paint_generation_id_          u64
mut:
	device_viewport_rect_            IntRect
	should_show_line_box_borders_    bool
	should_paint_overlay_            bool = true
	draw_svg_geometry_for_clip_path_ bool
	svg_transform_                   Affine
}

pub fn new_display_list_recording_context(display_list_recorder &DisplayListRecorder,
	palette Palette, device_pixels_per_css_pixel f64,
	chrome_metrics ChromeMetrics) !DisplayListRecordingContext {
	device_pixel_converter := new_device_pixel_converter(device_pixels_per_css_pixel)!
	paint_generation_id := painting_next_paint_generation_id
	painting_next_paint_generation_id++
	return DisplayListRecordingContext{
		display_list_recorder_handle_: voidptr(display_list_recorder)
		palette_: palette
		device_pixel_converter_: device_pixel_converter
		chrome_metrics_: chrome_metrics
		paint_generation_id_: paint_generation_id
	}
}

pub fn (context &DisplayListRecordingContext) display_list_recorder() &DisplayListRecorder {
	// The source context retains a reference and requires its recorder to
	// outlive it. The opaque handle expresses that non-owning lifetime without
	// forcing every recorder allocation onto V's heap.
	return unsafe { &DisplayListRecorder(context.display_list_recorder_handle_) }
}

pub fn (context &DisplayListRecordingContext) palette() Palette {
	return context.palette_
}

pub fn (context &DisplayListRecordingContext) should_show_line_box_borders() bool {
	return context.should_show_line_box_borders_
}

pub fn (mut context DisplayListRecordingContext) set_should_show_line_box_borders(value bool) {
	context.should_show_line_box_borders_ = value
}

pub fn (context &DisplayListRecordingContext) should_paint_overlay() bool {
	return context.should_paint_overlay_
}

pub fn (mut context DisplayListRecordingContext) set_should_paint_overlay(value bool) {
	context.should_paint_overlay_ = value
}

pub fn (context &DisplayListRecordingContext) device_viewport_rect() IntRect {
	return context.device_viewport_rect_
}

pub fn (mut context DisplayListRecordingContext) set_device_viewport_rect(rect IntRect) {
	context.device_viewport_rect_ = rect
}

pub fn (context &DisplayListRecordingContext) css_viewport_rect() css.CSSPixelRect {
	scale := context.device_pixel_converter_.device_pixels_per_css_pixel()
	return css.CSSPixelRect.new(f64(context.device_viewport_rect_.x) / scale, f64(context.device_viewport_rect_.y) / scale, f64(context.device_viewport_rect_.width) / scale, f64(context.device_viewport_rect_.height) / scale)
}

pub fn (mut context DisplayListRecordingContext) set_svg_transform(transform Affine) {
	context.svg_transform_ = transform
}

pub fn (context &DisplayListRecordingContext) svg_transform() Affine {
	return context.svg_transform_
}

pub fn (context &DisplayListRecordingContext) draw_svg_geometry_for_clip_path() bool {
	return context.draw_svg_geometry_for_clip_path_
}

pub fn (mut context DisplayListRecordingContext) set_draw_svg_geometry_for_clip_path(value bool) {
	context.draw_svg_geometry_for_clip_path_ = value
}

pub fn (context &DisplayListRecordingContext) rounded_device_pixels(css_pixels css.CSSPixels) int {
	return context.device_pixel_converter_.rounded_device_pixels(css_pixels.to_double())
}

pub fn (context &DisplayListRecordingContext) enclosing_device_pixels(css_pixels css.CSSPixels) int {
	return context.device_pixel_converter_.enclosing_device_pixels(css_pixels.to_double())
}

pub fn (context &DisplayListRecordingContext) floored_device_pixels(css_pixels css.CSSPixels) int {
	return context.device_pixel_converter_.floored_device_pixels(css_pixels.to_double())
}

pub fn (context &DisplayListRecordingContext) rounded_device_point(point css.CSSPixelPoint) IntPoint {
	return context.device_pixel_converter_.rounded_device_point(Point{
		x: point.x().to_double()
		y: point.y().to_double()
	})
}

pub fn (context &DisplayListRecordingContext) floored_device_point(point css.CSSPixelPoint) IntPoint {
	return context.device_pixel_converter_.floored_device_point(Point{
		x: point.x().to_double()
		y: point.y().to_double()
	})
}

pub fn (context &DisplayListRecordingContext) enclosing_device_rect(rect css.CSSPixelRect) IntRect {
	return context.device_pixel_converter_.enclosing_device_rect(Rect{
		x: rect.x.to_double()
		y: rect.y.to_double()
		width: rect.width.to_double()
		height: rect.height.to_double()
	})
}

pub fn (context &DisplayListRecordingContext) rounded_device_rect(rect css.CSSPixelRect) IntRect {
	return context.device_pixel_converter_.rounded_device_rect(Rect{
		x: rect.x.to_double()
		y: rect.y.to_double()
		width: rect.width.to_double()
		height: rect.height.to_double()
	})
}

pub fn (context &DisplayListRecordingContext) enclosing_device_size(size css.CSSPixelSize) IntSize {
	return context.device_pixel_converter_.enclosing_device_size(Size{
		width: size.width().to_double()
		height: size.height().to_double()
	})
}

pub fn (context &DisplayListRecordingContext) rounded_device_size(size css.CSSPixelSize) IntSize {
	return context.device_pixel_converter_.rounded_device_size(Size{
		width: size.width().to_double()
		height: size.height().to_double()
	})
}

pub fn (context &DisplayListRecordingContext) scale_to_css_pixels(device_pixels int) css.CSSPixels {
	return css.CSSPixels.nearest_value_for(f64(device_pixels) / context.device_pixel_converter_.device_pixels_per_css_pixel())
}

pub fn (context &DisplayListRecordingContext) scale_to_css_point(point IntPoint) css.CSSPixelPoint {
	return css.CSSPixelPoint.new(context.scale_to_css_pixels(point.x), context.scale_to_css_pixels(point.y))
}

pub fn (context &DisplayListRecordingContext) scale_to_css_size(size IntSize) css.CSSPixelSize {
	return css.CSSPixelSize.new(context.scale_to_css_pixels(size.width), context.scale_to_css_pixels(size.height))
}

pub fn (context &DisplayListRecordingContext) scale_to_css_rect(rect IntRect) css.CSSPixelRect {
	point := context.scale_to_css_point(IntPoint{rect.x, rect.y})
	size := context.scale_to_css_size(IntSize{rect.width, rect.height})
	return css.CSSPixelRect{
		x: point.x()
		y: point.y()
		width: size.width()
		height: size.height()
	}
}

pub fn (context &DisplayListRecordingContext) clone(display_list_recorder &DisplayListRecorder) !DisplayListRecordingContext {
	mut cloned := new_display_list_recording_context(display_list_recorder, context.palette_, context.device_pixel_converter_.device_pixels_per_css_pixel(), context.chrome_metrics_)!
	cloned.device_viewport_rect_ = context.device_viewport_rect_
	cloned.should_show_line_box_borders_ = context.should_show_line_box_borders_
	cloned.should_paint_overlay_ = context.should_paint_overlay_
	return cloned
}

pub fn (context &DisplayListRecordingContext) device_pixel_converter() DevicePixelConverter {
	return context.device_pixel_converter_
}

pub fn (context &DisplayListRecordingContext) device_pixels_per_css_pixel() f64 {
	return context.device_pixel_converter_.device_pixels_per_css_pixel()
}

pub fn (context &DisplayListRecordingContext) chrome_metrics() ChromeMetrics {
	return context.chrome_metrics_
}

pub fn (context &DisplayListRecordingContext) paint_generation_id() u64 {
	return context.paint_generation_id_
}
