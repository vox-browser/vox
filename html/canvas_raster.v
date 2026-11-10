// CanvasCommandPlayer.cpp/PainterSkia.cpp: translate complete path commands
// into the Skia-free rasterizer. The exact cpuraster ports reproduce Skia's
// pixels for every draw they cover; the remaining draws use cpuraster's
// device-space filter, glyph and image fallbacks.
module html

import cpuraster
import css
import math
import dom
import platform

// The paint style of a canvas command: kind 0 solid, 1 linear, 2 radial
// and 3 conic gradients, 4 a pattern.
struct CanvasRasterStyle {
	kind                int
	color               u32
	x0                  f32
	y0                  f32
	r0                  f32
	x1                  f32
	y1                  f32
	r1                  f32
	angle               f32
	stops               []f32
	pattern             []u8
	pattern_width       int
	pattern_height      int
	pattern_pitch       int
	pattern_alpha       int
	pattern_color_space int
	repetition          int
	pattern_transform   [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
}

fn canvas_packed_path(path CanvasGfxPath, fill_rule string) cpuraster.PackedPath {
	mut segments := []f32{cap: path.length() * 12}
	for segment in path.segments() {
		segments << [f32(int(segment.kind)), f32(segment.point.x), f32(segment.point.y),
			f32(segment.control_point_0.x), f32(segment.control_point_0.y),
			f32(segment.control_point_1.x), f32(segment.control_point_1.y), f32(segment.radii.width),
			f32(segment.radii.height), f32(segment.x_axis_rotation), f32(int(segment.large_arc)),
			f32(int(segment.sweep))]
	}
	return cpuraster.PackedPath{
		segments: segments
		even_odd: fill_rule == 'evenodd'
	}
}

fn canvas_raster_transform(transform CanvasAffineTransform) [6]f32 {
	return [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d), f32(transform.e),
		f32(transform.f)]!
}

fn canvas_raster_style(style CanvasGfxPaintStyle) CanvasRasterStyle {
	if gradient := style.gradient {
		mut stops := []f32{}
		for stop in gradient.color_stops_for_painting() {
			stops << [f32(stop.offset), f32(stop.color.r) / 255, f32(stop.color.g) / 255,
				f32(stop.color.b) / 255, f32(stop.color.a) / 255]
		}
		return CanvasRasterStyle{
			kind:  1 + int(gradient.kind)
			x0:    f32(gradient.x0)
			y0:    f32(gradient.y0)
			r0:    f32(gradient.r0)
			x1:    f32(gradient.x1)
			y1:    f32(gradient.y1)
			r1:    f32(gradient.r1)
			angle: f32(gradient.start_angle)
			stops: stops
		}
	}
	if pattern := style.pattern {
		bitmap := pattern.bitmap()
		return CanvasRasterStyle{
			kind:                4
			pattern:             bitmap.data
			pattern_width:       bitmap.width
			pattern_height:      bitmap.height
			pattern_pitch:       bitmap.pitch
			pattern_alpha:       int(bitmap.alpha_type)
			pattern_color_space: int(pattern.frame().color_space())
			repetition:          int(pattern.repetition())
			pattern_transform:   canvas_raster_transform(pattern.transform())
		}
	}
	color := style.color
	return CanvasRasterStyle{
		kind:  0
		color: (u32(color.a) << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b)
	}
}

fn (style CanvasGfxPaintStyle) is_visible() bool {
	if gradient := style.gradient { return gradient.color_stops_for_painting().any(it.color.a > 0) }
	if style.pattern != none { return true }
	return style.color.a > 0
}

fn (mut context OffscreenCanvasRenderingContext2D) paint_canvas_path(path CanvasGfxPath, style CanvasGfxPaintStyle, fill_rule string, stroke bool, blur f64, alpha f64, transform CanvasAffineTransform) {
	bitmap := context.canvas_.bitmap() or { return }
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	state := context.drawing_state
	clips := state.clip_paths.map(canvas_packed_path(it.path, it.fill_rule).path())
	cpu_path := canvas_packed_path(path, fill_rule).path()
	native_style := canvas_raster_style(style)
	native_transform := canvas_raster_transform(transform)
	filters := context.canvas_filter_specs()
	// Solid, gradient and pattern fills and strokes use the exact Skia
	// ports: dashes from SkDashPathEffect, then hairlines for strokes at most
	// a device pixel wide and SkStroke outlines for wider ones, inside the
	// anti-aliased clip, with any composite operation, including the
	// runtime-effect plus-darker and plus-lighter blenders. A blurred shadow
	// takes Skia's blur mask filter, which replaces the canvas filters;
	// filter lists of color matrices become the paint's color filter, and
	// blur and drop-shadow lists draw through image filter layers. Draws the
	// ports decline take the device-space fallback.
	solid := native_style.kind == 0
	cpu_style := canvas_cpu_style(native_style)
	mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) or {
		return
	}
	stroke_spec := if stroke {
		?cpuraster.CanvasStrokeSpec(cpuraster.CanvasStrokeSpec{
			width:       f32(state.line_width)
			cap:         cpu_stroke_cap(state.line_cap)
			join:        cpu_stroke_join(state.line_join)
			miter:       f32(state.miter_limit)
			dashes:      state.dash_list.map(f32(it))
			dash_offset: f32(state.line_dash_offset)
		})
	} else {
		none
	}
	supported, color_filter := canvas_cpu_filter(filters)
	mut painted := false
	if native_style.kind <= 4 && ((solid && f32(blur) > 0) || supported) {
		painted = if s := stroke_spec {
			cpuraster.stroke_canvas_path(mut mutable_bitmap.data, bitmap.width, bitmap.height,
				bitmap.pitch, int(bitmap.alpha_type), cpu_path, native_transform, native_style.color,
				cpu_style, f32(alpha), mode, f32(blur), s.width, s.cap, s.join, s.miter, s.dashes,
				s.dash_offset, clips, color_filter)
		} else {
			cpuraster.fill_canvas_path(mut mutable_bitmap.data, bitmap.width, bitmap.height,
				bitmap.pitch, int(bitmap.alpha_type), cpu_path, native_transform, native_style.color,
				cpu_style, f32(alpha), mode, f32(blur), clips, color_filter)
		}
	}
	if !painted {
		painted = cpuraster.draw_general_canvas_path(mut mutable_bitmap.data, bitmap.width,
			bitmap.height, bitmap.pitch, int(bitmap.alpha_type), cpu_path, native_transform,
			native_style.color, cpu_style, f32(alpha), mode, stroke_spec, f32(blur), clips, filters)
	}
	if painted {
		mutable_bitmap.alpha_type = 2
		mutable_bitmap.native_rows_are_top_down = true
	}
}

// canvas_cpu_filter reports whether cpuraster can take the filter list:
// blurs (kind 0) and color matrices (kind 2, and opacity's kind 4 outside
// Chromium's table) with their clamp flags, in order. The filter is none
// for an empty list. cpuraster itself declines the lists and draws it
// does not reproduce yet.
fn canvas_cpu_filter(filters []cpuraster.CanvasFilterSpec) (bool, ?cpuraster.CanvasFilter) {
	mut steps := []cpuraster.CanvasFilterStep{}
	for filter in filters {
		match filter.kind {
			0 {
				steps << cpuraster.CanvasFilterStep{
					kind:  .blur
					sigma: filter.radius
				}
			}
			1 {
				steps << cpuraster.CanvasFilterStep{
					kind: .drop_shadow
					sigma: filter.radius
					offset_x: filter.offset_x
					offset_y: filter.offset_y
					color: filter.color
				}
			}
			2, 4 {
				steps << cpuraster.CanvasFilterStep{
					kind:   .matrix
					matrix: cpuraster.MatrixColorFilter{
						matrix: filter.matrix
						clamp:  filter.clamp
					}
				}
			}
			else {
				return false, none
			}
		}
	}
	return true, cpuraster.new_canvas_filter(steps)
}

// The cpuraster style for a native style of kind 0 to 4: none for the solid
// color, a gradient or a pattern.
fn canvas_cpu_style(native_style CanvasRasterStyle) ?cpuraster.CanvasPaintStyle {
	return match native_style.kind {
		1, 2, 3 {
			?cpuraster.CanvasPaintStyle(cpuraster.CanvasGradient{
				kind:  native_style.kind
				x0:    native_style.x0
				y0:    native_style.y0
				r0:    native_style.r0
				x1:    native_style.x1
				y1:    native_style.y1
				r1:    native_style.r1
				angle: native_style.angle
				stops: native_style.stops
			})
		}
		4 {
			?cpuraster.CanvasPaintStyle(cpuraster.CanvasPattern{
				pixels:        native_style.pattern
				width:         native_style.pattern_width
				height:        native_style.pattern_height
				pitch:         native_style.pattern_pitch
				premultiplied: native_style.pattern_alpha == 2
				display_p3:    native_style.pattern_color_space == 1
				repetition:    native_style.repetition
				transform:     native_style.pattern_transform
			})
		}
		else {
			?cpuraster.CanvasPaintStyle(none)
		}
	}
}

fn cpu_stroke_cap(cap CanvasLineCap) cpuraster.StrokeCap {
	return match cap {
		.butt { .butt }
		.round { .round }
		.square { .square }
	}
}

fn cpu_stroke_join(join CanvasLineJoin) cpuraster.StrokeJoin {
	return match join {
		.round { .round }
		.bevel { .bevel }
		.miter { .miter }
	}
}

fn (mut context OffscreenCanvasRenderingContext2D) paint_canvas_glyph_run(run &platform.GlyphRun, translation FloatPoint) bool {
	bitmap := context.canvas_.bitmap() or { return false }
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	state := context.drawing_state
	style := state.fill_style.to_gfx_paint_style()
	if !style.is_visible() && state.current_compositing_and_blending_operator == .source_over { return false }
	font_path := if run.face() == .emoji {
		platform.emoji_font_path() or { return false }
	} else {
		run.font().font_path() or { return false }
	}
	clips := state.clip_paths.map(canvas_packed_path(it.path, it.fill_rule).path())
	native_style := canvas_raster_style(style)
	native_transform := canvas_raster_transform(state.transform)
	filters := context.canvas_filter_specs()
	cpu_run := cpuraster.CanvasGlyphRun{
		font_path:   font_path
		face_index:  run.font().face_index()
		font_size:   run.font().point_size
		glyphs:      run.glyph_indices()
		positions:   run.glyph_positions().map(f32(it))
		translation: [f32(translation.x), f32(translation.y)]!
	}
	mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) or {
		return false
	}
	// Unfiltered solid, gradient and pattern runs take the exact glyph
	// masks: CoreText (FreeType on Linux) rasterizes each glyph as Skia's
	// unhinted A8 strike does, with its quarter-pixel positions and mask
	// gamma, and the masks blit with the paint inside the anti-aliased clip.
	// Glyphs over 256 pixels per em fill their 64-point outlines instead, and
	// color glyphs are premultiplied images drawn as sprites. Filter lists of
	// color matrices become the paint's color filter, and blur and
	// drop-shadow lists draw through image filter layers. Runs the ports
	// decline take the device-space fallback.
	supported, color_filter := canvas_cpu_filter(filters)
	cpu_style := canvas_cpu_style(native_style)
	mut painted := native_style.kind <= 4 && supported
		&& cpuraster.fill_canvas_glyphs(mut mutable_bitmap.data, bitmap.width, bitmap.height,
		bitmap.pitch, int(bitmap.alpha_type), cpu_run, native_transform, native_style.color, cpu_style,
		f32(state.global_alpha), mode, clips, color_filter)
	if !painted {
		painted = cpuraster.draw_general_canvas_glyphs(mut mutable_bitmap.data, bitmap.width,
			bitmap.height, bitmap.pitch, int(bitmap.alpha_type), cpu_run, native_transform,
			native_style.color, cpu_style, f32(state.global_alpha), mode, clips, filters)
	}
	if painted {
		mutable_bitmap.alpha_type = 2
		mutable_bitmap.native_rows_are_top_down = true
	}
	return painted
}

// LibGfx SkiaUtils.cpp: CSS filter matrices, including each source clamp policy.
fn canvas_filter_spec(function CanvasFilterFunction) cpuraster.CanvasFilterSpec {
	if function.kind == .blur { return cpuraster.CanvasFilterSpec{ kind: 0, radius: function.amount } }
	if function.kind == .drop_shadow {
		color := function.color
		return cpuraster.CanvasFilterSpec{ kind: 1, radius: function.amount, offset_x: function.offset_x, offset_y: function.offset_y, color: (u32(color.a) << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b) }
	}
	a := function.amount
	if function.kind == .hue_rotate {
		radians := f32(a * f32(math.pi) / 180)
		c := f32(math.cos(radians))
		s := f32(math.sin(radians))
		return cpuraster.CanvasFilterSpec{
			kind:   2
			matrix: [
				f32(.213) + c * .787 - s * .213,
				.715 - c * .715 - s * .715,
				.072 - c * .072 + s * .928,
				0,
				0,
				.213 - c * .213 + s * .143,
				.715 + c * .285 + s * .140,
				.072 - c * .072 - s * .283,
				0,
				0,
				.213 - c * .213 - s * .787,
				.715 - c * .715 + s * .715,
				.072 + c * .928 + s * .072,
				0,
				0,
				0,
				0,
				0,
				1,
				0,
			]!
		}
	}
	matrix := match function.color_operation {
		.brightness { [a, f32(0), 0, 0, 0, 0, a, 0, 0, 0, 0, 0, a, 0, 0, 0, 0, 0, 1, 0]! }
		.contrast {
			intercept := f32(-(.5 * a) + .5)
			[a, f32(0), 0, 0, intercept, 0, a, 0, 0, intercept, 0, 0, a, 0, intercept, 0, 0, 0,
				1, 0]!
		}
		.invert {
			[f32(1) - 2 * a, 0, 0, 0, a, 0, 1 - 2 * a, 0, 0, a, 0, 0, 1 - 2 * a, 0, a, 0, 0, 0,
				1, 0]!
		}
		.opacity { [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, a, 0]! }
		.grayscale {
			[
				f32(.2126) + .7874 * (1 - a),
				.7152 - .7152 * (1 - a),
				.0722 - .0722 * (1 - a),
				0,
				0,
				.2126 - .2126 * (1 - a),
				.7152 + .2848 * (1 - a),
				.0722 - .0722 * (1 - a),
				0,
				0,
				.2126 - .2126 * (1 - a),
				.7152 - .7152 * (1 - a),
				.0722 + .9278 * (1 - a),
				0,
				0,
				0,
				0,
				0,
				1,
				0,
			]!
		}
		.sepia {
			[
				f32(.393) + .607 * (1 - a),
				.769 - .769 * (1 - a),
				.189 - .189 * (1 - a),
				0,
				0,
				.349 - .349 * (1 - a),
				.686 + .314 * (1 - a),
				.168 - .168 * (1 - a),
				0,
				0,
				.272 - .272 * (1 - a),
				.534 - .534 * (1 - a),
				.131 + .869 * (1 - a),
				0,
				0,
				0,
				0,
				0,
				1,
				0,
			]!
		}
		.saturate {
			[
				f32(.213) + .787 * a,
				.715 - .715 * a,
				.072 - .072 * a,
				0,
				0,
				.213 - .213 * a,
				.715 + .285 * a,
				.072 - .072 * a,
				0,
				0,
				.213 - .213 * a,
				.715 - .715 * a,
				.072 + .928 * a,
				0,
				0,
				0,
				0,
				0,
				1,
				0,
			]!
		}
	}
	return cpuraster.CanvasFilterSpec{
		kind:   if function.color_operation == .opacity { 4 } else { 2 }
		matrix: matrix
		clamp:  function.color_operation in [
			css.ColorFilterType.grayscale,
			.invert,
			.opacity,
			.sepia,
		]
	}
}

// CanvasCommands::ClearRect and DrawBitmap retain the upstream operation.
fn (mut context OffscreenCanvasRenderingContext2D) paint_canvas_bitmap_command(operation int, source ?&dom.DecodedImageFrame_, source_rect CanvasFloatRect, destination_rect CanvasFloatRect) {
	bitmap := context.canvas_.bitmap() or { return }
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	state := context.drawing_state
	clips := state.clip_paths.map(canvas_packed_path(it.path, it.fill_rule).path())
	transform := canvas_raster_transform(state.transform)
	destination := [f32(destination_rect.x), f32(destination_rect.y), f32(destination_rect.width),
		f32(destination_rect.height)]!
	mut painted := false
	if operation == 1 {
		color := if context.context_attributes.alpha { u32(0) } else { u32(0xff000000) }
		painted = cpuraster.clear_canvas_rect(mut mutable_bitmap.data, bitmap.width, bitmap.height,
			bitmap.pitch, int(bitmap.alpha_type), transform, destination, color, clips)
	} else if frame := source {
		image := frame.bitmap()
		cpu_image := cpuraster.CanvasBitmap{
			pixels:        image.data.clone()
			width:         image.width
			height:        image.height
			pitch:         image.pitch
			premultiplied: int(image.alpha_type) == 2
			display_p3:    int(frame.color_space()) == 1
		}
		filters := context.canvas_filter_specs()
		chromium := if document := context.font_resolution_document() {
			document.font_rendering_policy() == .chromium
		} else {
			false
		}
		source_values := [f32(math.round(source_rect.x)), f32(math.round(source_rect.y)),
			f32(math.round(source_rect.width)), f32(math.round(source_rect.height))]!
		mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) or {
			return
		}
		// Image filters retain their drawing-space or bitmap-space semantics:
		// on macOS, Chromium filters its composited image draws in bitmap
		// coordinates after the drawing transform has placed the image.
		supported, cpu_filter := canvas_cpu_filter(filters)
		bitmap_filter := $if macos { chromium && filters.len > 0 } $else { false }
		if supported {
			painted = cpuraster.draw_canvas_image_filtered(mut mutable_bitmap.data, bitmap.width,
				bitmap.height, bitmap.pitch, int(bitmap.alpha_type), transform, cpu_image,
				source_values, destination, state.image_smoothing_enabled, f32(state.global_alpha),
				mode, clips, cpu_filter, bitmap_filter)
		}
		if !painted {
			painted = cpuraster.draw_general_canvas_image(mut mutable_bitmap.data, bitmap.width,
				bitmap.height, bitmap.pitch, int(bitmap.alpha_type), transform, cpu_image,
				source_values, destination, state.image_smoothing_enabled, f32(state.global_alpha),
				mode, clips, filters, bitmap_filter)
		}
	}
	if painted {
		mutable_bitmap.alpha_type = 2
		mutable_bitmap.native_rows_are_top_down = true
	}
}
