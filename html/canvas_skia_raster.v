// CanvasCommandPlayer.cpp/PainterSkia.cpp: translate complete path commands.
module html

import cpuraster
import css
import math
import dom
import skia
import platform

fn canvas_skia_path(path CanvasGfxPath, fill_rule string) skia.Path {
	mut segments := []f32{cap: path.length() * 12}
	for segment in path.segments() {
		segments << [f32(int(segment.kind)), f32(segment.point.x), f32(segment.point.y),
			f32(segment.control_point_0.x), f32(segment.control_point_0.y),
			f32(segment.control_point_1.x), f32(segment.control_point_1.y), f32(segment.radii.width),
			f32(segment.radii.height), f32(segment.x_axis_rotation), f32(int(segment.large_arc)),
			f32(int(segment.sweep))]
	}
	return skia.Path{
		segments: segments
		even_odd: fill_rule == 'evenodd'
	}
}

fn canvas_skia_transform(transform CanvasAffineTransform) [6]f32 {
	return [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d), f32(transform.e),
		f32(transform.f)]!
}

fn canvas_skia_style(style CanvasGfxPaintStyle) skia.Style {
	if gradient := style.gradient {
		mut stops := []f32{}
		for stop in gradient.color_stops_for_painting() {
			stops << [f32(stop.offset), f32(stop.color.r) / 255, f32(stop.color.g) / 255,
				f32(stop.color.b) / 255, f32(stop.color.a) / 255]
		}
		return skia.Style{
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
		return skia.Style{
			kind:                4
			pattern:             bitmap.data
			pattern_width:       bitmap.width
			pattern_height:      bitmap.height
			pattern_pitch:       bitmap.pitch
			pattern_alpha:       int(bitmap.alpha_type)
			pattern_color_space: int(pattern.frame().color_space())
			repetition:          int(pattern.repetition())
			pattern_transform:   canvas_skia_transform(pattern.transform())
		}
	}
	color := style.color
	return skia.Style{
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
	mut clips := []skia.Path{}
	for clip in state.clip_paths {
		clips << canvas_skia_path(clip.path, clip.fill_rule)
	}
	native_path := canvas_skia_path(path, fill_rule)
	native_style := canvas_skia_style(style)
	native_transform := canvas_skia_transform(transform)
	filters := context.canvas_skia_filters()
	// Solid, gradient and pattern fills and strokes use the Skia-free
	// rasterizer, which reproduces Skia's pixels: dashes from
	// SkDashPathEffect, then hairlines for strokes at most a device pixel wide
	// and SkStroke outlines for wider ones, inside the anti-aliased clip, with
	// any composite operation, including the runtime-effect plus-darker and
	// plus-lighter blenders. A blurred shadow takes Skia's blur mask filter,
	// which replaces the canvas filters; filter lists of color matrices
	// become the paint's color filter, a lone blur() draws through Skia's
	// image filter layer, and other filtered draws stay on Skia.
	solid := native_style.kind == 0
	supported, color_filter := canvas_cpu_filter(filters)
	if native_style.kind <= 4 && ((solid && f32(blur) > 0) || supported) {
		cpu_style := canvas_cpu_style(native_style)
		if mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) {
			cpu_path := cpuraster.canvas_path(native_path.segments, native_path.even_odd)
			cpu_clips := clips.map(cpuraster.canvas_path(it.segments, it.even_odd))
			painted := if stroke {
				cpuraster.stroke_canvas_path(mut mutable_bitmap.data, bitmap.width, bitmap.height,
					bitmap.pitch, int(bitmap.alpha_type), cpu_path, native_transform, native_style.color,
					cpu_style, f32(alpha), mode, f32(blur), f32(state.line_width), cpu_stroke_cap(state.line_cap), cpu_stroke_join(state.line_join),
					f32(state.miter_limit), state.dash_list.map(f32(it)), f32(state.line_dash_offset),
					cpu_clips, color_filter)
			} else {
				cpuraster.fill_canvas_path(mut mutable_bitmap.data, bitmap.width, bitmap.height,
					bitmap.pitch, int(bitmap.alpha_type), cpu_path, native_transform, native_style.color,
					cpu_style, f32(alpha), mode, f32(blur), cpu_clips, color_filter)
			}
			if painted {
				mutable_bitmap.alpha_type = 2
				mutable_bitmap.native_rows_are_top_down = true
				return
			}
		}
	}
	command := skia.Command{
		path:         native_path
		style:        native_style
		transform:    native_transform
		clips:        clips
		stroke:       stroke
		cap:          int(state.line_cap)
		join:         int(state.line_join)
		composite:    int(state.current_compositing_and_blending_operator)
		width:        f32(state.line_width)
		miter:        f32(state.miter_limit)
		global_alpha: f32(alpha)
		blur:         f32(blur)
		dashes:       state.dash_list.map(f32(it))
		dash_offset:  f32(state.line_dash_offset)
		filters:      filters
	}
	painted := skia.draw_path(mut mutable_bitmap.data, bitmap.width, bitmap.height, bitmap.pitch,
		int(bitmap.alpha_type), command)
	assert painted
	mutable_bitmap.alpha_type = 2
	mutable_bitmap.native_rows_are_top_down = true
}

// canvas_cpu_filter reports whether cpuraster can take the filter list:
// blurs (kind 0) and color matrices (kind 2, and opacity's kind 4 outside
// Chromium's table) with their clamp flags, in order. The filter is none
// for an empty list. cpuraster itself declines the lists and draws it
// does not reproduce yet.
fn canvas_cpu_filter(filters []skia.Filter) (bool, ?cpuraster.CanvasFilter) {
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
fn canvas_cpu_style(native_style skia.Style) ?cpuraster.CanvasPaintStyle {
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
	clips := state.clip_paths.map(canvas_skia_path(it.path, it.fill_rule))
	native_style := canvas_skia_style(style)
	native_transform := canvas_skia_transform(state.transform)
	filters := context.canvas_skia_filters()
	glyphs := skia.GlyphRun{
		font_path: font_path
		face_index: run.font().face_index()
		font_size: run.font().point_size
		glyphs: run.glyph_indices()
		positions: run.glyph_positions().map(f32(it))
		translation: [f32(translation.x), f32(translation.y)]!
	}
	// Unfiltered solid, gradient and pattern runs take the Skia-free glyph
	// masks: CoreText rasterizes each glyph as Skia's unhinted A8 strike
	// does, with its quarter-pixel positions and mask gamma, and the masks
	// blit with the paint inside the anti-aliased clip. Glyphs over 256
	// pixels per em fill their 64-point outlines instead, and color glyphs
	// are CoreText's premultiplied images drawn as sprites. Filter lists of
	// color matrices become the paint's color filter and a lone blur() draws
	// through an image filter layer; other filtered draws stay on Skia.
	supported, color_filter := canvas_cpu_filter(filters)
	if native_style.kind <= 4 && supported {
		if mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) {
			cpu_run := cpuraster.CanvasGlyphRun{
				font_path:   glyphs.font_path
				face_index:  glyphs.face_index
				font_size:   glyphs.font_size
				glyphs:      glyphs.glyphs
				positions:   glyphs.positions
				translation: glyphs.translation
			}
			if cpuraster.fill_canvas_glyphs(mut mutable_bitmap.data, bitmap.width, bitmap.height,
				bitmap.pitch, int(bitmap.alpha_type), cpu_run, native_transform, native_style.color,
				canvas_cpu_style(native_style), f32(state.global_alpha), mode, clips.map(cpuraster.canvas_path(it.segments,
				it.even_odd)), color_filter) {
				mutable_bitmap.alpha_type = 2
				mutable_bitmap.native_rows_are_top_down = true
				return true
			}
		}
	}
	command := skia.Command{
		style: native_style
		transform: native_transform
		clips: clips
		composite: int(state.current_compositing_and_blending_operator)
		global_alpha: f32(state.global_alpha)
		filters: filters
	}
	painted := skia.draw_glyph_run(mut mutable_bitmap.data, bitmap.width, bitmap.height, bitmap.pitch, int(bitmap.alpha_type), command, glyphs)
	assert painted
	mutable_bitmap.alpha_type = 2
	mutable_bitmap.native_rows_are_top_down = true
	return painted
}

// SkiaUtils.cpp: CSS filter matrices, including each source clamp policy.
fn canvas_skia_filter(function CanvasFilterFunction) skia.Filter {
	if function.kind == .blur { return skia.Filter{ kind: 0, radius: function.amount } }
	if function.kind == .drop_shadow {
		color := function.color
		return skia.Filter{ kind: 1, radius: function.amount, offset_x: function.offset_x, offset_y: function.offset_y, color: (u32(color.a) << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b) }
	}
	a := function.amount
	if function.kind == .hue_rotate {
		radians := f32(a * f32(math.pi) / 180)
		c := f32(math.cos(radians))
		s := f32(math.sin(radians))
		return skia.Filter{
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
	return skia.Filter{
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

// CanvasCommands::ClearRect and DrawBitmap retain the upstream Skia operation.
fn (mut context OffscreenCanvasRenderingContext2D) paint_canvas_bitmap_command(operation int, source ?&dom.DecodedImageFrame_, source_rect CanvasFloatRect, destination_rect CanvasFloatRect) {
	bitmap := context.canvas_.bitmap() or { return }
	mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
	state := context.drawing_state
	mut clips := []skia.Path{}
	for clip in state.clip_paths { clips << canvas_skia_path(clip.path, clip.fill_rule) }
	mut style := skia.Style{ color: if context.context_attributes.alpha {
		u32(0)
	} else {
		u32(0xff000000)
	} }
	if frame := source {
		image := frame.bitmap()
		style = skia.Style{ kind: 4, pattern: image.data.clone(), pattern_width: image.width, pattern_height: image.height, pattern_pitch: image.pitch, pattern_alpha: int(image.alpha_type), pattern_color_space: int(frame.color_space()) }
	}
	filters := context.canvas_skia_filters()
	chromium := if document := context.font_resolution_document() {
		document.font_rendering_policy() == .chromium
	} else {
		false
	}
	transform := canvas_skia_transform(state.transform)
	destination := [f32(destination_rect.x), f32(destination_rect.y), f32(destination_rect.width),
		f32(destination_rect.height)]!
	source_values := [f32(math.round(source_rect.x)), f32(math.round(source_rect.y)),
		f32(math.round(source_rect.width)), f32(math.round(source_rect.height))]!
	// Image filters retain their drawing-space or bitmap-space semantics.
	supported, cpu_filter := canvas_cpu_filter(filters)
	// macOS's Chromium image bridge can replay sRGB images through Dawn.
	// Keep that policy until its GPU comparison is complete. Linux and the
	// bridge's wide-gamut/runtime-blender fallbacks use the CPU command.
	native_gpu_filter := $if macos {
		chromium && filters.len > 0 && style.pattern_color_space == 0
			&& int(state.current_compositing_and_blending_operator) < 26
	} $else { false }
	if operation == 1 || (operation == 2 && style.kind == 4 && supported && !native_gpu_filter) {
		cpu_clips := clips.map(cpuraster.canvas_path(it.segments, it.even_odd))
		mut painted := false
		if operation == 1 {
			painted = cpuraster.clear_canvas_rect(mut mutable_bitmap.data, bitmap.width,
				bitmap.height, bitmap.pitch, int(bitmap.alpha_type), transform, destination,
				style.color, cpu_clips)
		} else if mode := cpuraster.canvas_blend_mode(int(state.current_compositing_and_blending_operator)) {
			painted = cpuraster.draw_canvas_image_filtered(mut mutable_bitmap.data, bitmap.width,
				bitmap.height, bitmap.pitch, int(bitmap.alpha_type), transform, cpuraster.CanvasBitmap{
				pixels:        style.pattern
				width:         style.pattern_width
				height:        style.pattern_height
				pitch:         style.pattern_pitch
				premultiplied: style.pattern_alpha == 2
				display_p3:    style.pattern_color_space == 1
			}, source_values, destination, state.image_smoothing_enabled, f32(state.global_alpha),
				mode, cpu_clips, cpu_filter, false)
		}
		if painted {
			mutable_bitmap.alpha_type = 2
			mutable_bitmap.native_rows_are_top_down = true
			return
		}
	}
	command := skia.Command{
		operation:    operation
		chromium:     chromium
		destination:  destination
		source:       source_values
		smoothing:    state.image_smoothing_enabled
		style:        style
		transform:    transform
		clips:        clips
		composite:    int(state.current_compositing_and_blending_operator)
		global_alpha: f32(state.global_alpha)
		filters:      filters
	}
	painted := skia.draw_path(mut mutable_bitmap.data, bitmap.width, bitmap.height, bitmap.pitch, int(bitmap.alpha_type), command)
	assert painted
	mutable_bitmap.alpha_type = 2
	mutable_bitmap.native_rows_are_top_down = true
}
