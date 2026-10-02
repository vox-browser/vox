// CanvasCommandPlayer.cpp/PainterSkia.cpp: translate complete path commands.
module html

import css
import math
import dom
import skia

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
	command := skia.Command{
		path:         canvas_skia_path(path, fill_rule)
		style:        canvas_skia_style(style)
		transform:    canvas_skia_transform(transform)
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
		filters:      state.filter_functions.map(canvas_skia_filter(it))
	}
	assert skia.draw_path(mut mutable_bitmap.data, bitmap.width, bitmap.height, bitmap.pitch,
		int(bitmap.alpha_type), command)
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
		kind:   2
		matrix: matrix
		clamp:  function.color_operation in [
			css.ColorFilterType.grayscale,
			.invert,
			.opacity,
			.sepia,
		]
	}
}
