module ggshape

import gg.canvas
import math

#include "@DIR/../native/include/native_graphite_bridge.h"

@[typedef]
pub struct C.VoxGraphitePath {
pub mut:
	matrix             [9]f32
	segments           &f32
	segment_count      i32
	even_odd           i32
	red                u8
	green              u8
	blue               u8
	alpha              u8
	stroke             i32
	line_cap           i32
	line_join          i32
	non_scaling_stroke i32
	stroke_width       f32
	miter_limit        f32
	gradient           i32
	tile_mode          i32
	linear_color_space i32
	stop_count         i32
	gradient_points    [6]f32
	gradient_matrix    [9]f32
	opacity            f32
	stops              &f32
	has_float_alpha    i32
	has_clip           i32
	clip               [12]f32
	has_ancestor_clip  i32
	ancestor_clip      [12]f32
	has_float_color    i32
	float_color        [4]f32
	gradient_premul    i32
}

// path_supported reports whether gg.canvas may reproduce the descriptor:
// solid or gradient fills and strokes with optional rounded clips. Gradients
// in a linear color space are not ported yet; gg.canvas declines the other
// gradient draws it cannot reproduce. Non-scaling strokes transform their
// geometry before stroking, while preserving the original device-space clips.
fn path_supported(path &C.VoxGraphitePath) bool {
	if path.gradient != 0 && (path.stops == unsafe { nil } || path.stop_count < 2
		|| path.linear_color_space != 0) {
		return false
	}
	return path.segments != unsafe { nil } && path.segment_count > 0
}

// path_gradient mirrors the shader draw_path_on_canvas() makes: five floats
// (R G B A position) per stop, a linear gradient from (P0, P1) to (P2, P3) or
// a two-point conical one from (P0, P1) with radius P2 to (P3, P4) with
// radius P5, and the gradient's local matrix.
fn path_gradient(path &C.VoxGraphitePath) !canvas.Gradient {
	mut colors := []canvas.Color4f{cap: int(path.stop_count)}
	mut positions := []f32{cap: int(path.stop_count)}
	for index in 0 .. int(path.stop_count) {
		stop := unsafe { &path.stops[index * 5] }
		colors << unsafe { canvas.Color4f{stop[0], stop[1], stop[2], stop[3]} }
		positions << unsafe { stop[4] }
	}
	tile := match path.tile_mode {
		0 { canvas.TileMode.clamp }
		1 { .repeat }
		2 { .mirror }
		3 { .decal }
		else { return error('invalid tile mode') }
	}
	base := canvas.Gradient{
		colors:       colors
		positions:    positions
		tile_mode:    tile
		premul:       path.gradient_premul != 0
		local_matrix: canvas.Matrix.values(path.gradient_matrix)
	}
	v := path.gradient_points
	if path.gradient == 1 {
		return canvas.Gradient{
			...base
			kind: .linear
			p0:   canvas.Point{v[0], v[1]}
			p1:   canvas.Point{v[2], v[3]}
		}
	}
	start := canvas.Point{v[0], v[1]}
	end := canvas.Point{v[3], v[4]}
	return canvas.Gradient.two_point_conical(start, v[2], end, v[5], base) or {
		if tile != .clamp || start.x != end.x || start.y != end.y || !(v[2] > 0 && v[5] > v[2])
			|| !is_finite(v[5]) {
			return err
		}
		// For a concentric pad gradient, map each stop to its distance from
		// the common center divided by the outer radius. The radial shader's
		// implicit first stop extends the first color inside the inner circle.
		inner := v[2] / v[5]
		for mut position in positions {
			p := clamp_unit(position)
			position = p + (1 - p) * inner
		}
		canvas.Gradient{
			...base
			kind:      .radial
			p0:        start
			radius:    v[5]
			positions: positions
		}
	}
}

// path_from_segments decodes the browser's twelve-float SVG segments,
// beginning with the segment kind.
fn path_from_segments(data &f32, count int, even_odd bool) canvas.Path {
	mut b := canvas.PathBuilder{}
	mut last_move_x := f32(0)
	mut last_move_y := f32(0)
	mut has_move := false
	for index in 0 .. count {
		s := unsafe { &data[index * 12] }
		match unsafe { int(s[0]) } {
			0 {
				unsafe { b.move_to(s[1], s[2]) }
				last_move_x = unsafe { s[1] }
				last_move_y = unsafe { s[2] }
				has_move = true
			}
			1 {
				unsafe { b.line_to(s[1], s[2]) }
			}
			2 {
				unsafe { b.quad_to(s[3], s[4], s[1], s[2]) }
			}
			3 {
				unsafe { b.cubic_to(s[3], s[4], s[5], s[6], s[1], s[2]) }
			}
			4 {
				// segment[9] * 180.0f / static_cast<float>(M_PI)
				degrees := unsafe { s[9] * f32(180) } / f32(math.pi)
				unsafe {
					b.arc_to_svg(abs_f32(s[7]), abs_f32(s[8]), degrees, s[10] != 0, if s[11] != 0 {
						canvas.PathDirection.cw
					} else {
						canvas.PathDirection.ccw
					}, s[1], s[2])
				}
			}
			5 {
				b.close()
				if has_move {
					b.move_to(last_move_x, last_move_y)
				}
			}
			6 {
				l, t, r, bt := unsafe { s[1] }, unsafe { s[2] }, unsafe { s[3] }, unsafe { s[4] }
				if is_finite(l) && is_finite(t) && is_finite(r) && is_finite(bt) && r > l && bt > t {
					b.add_oval(canvas.Rect.ltrb(l, t, r, bt), .cw, 1)
				}
			}
			else {}
		}
	}
	if even_odd {
		b.set_fill_type(.even_odd)
	}
	return b.detach()
}

// clamp_unit pins an alpha to [0, 1] like SkPaint::setAlphaf().
fn clamp_unit(v f32) f32 {
	return if v < 0 {
		f32(0)
	} else if v > 1 {
		f32(1)
	} else {
		v
	}
}

fn abs_f32(v f32) f32 {
	return if v < 0 { -v } else { v }
}

fn is_finite(v f32) bool {
	return !math.is_nan(f64(v)) && !math.is_inf(f64(v), 0)
}

@[inline]
fn path_pixels_supported(pixels &u8, width i32, height i32, pitch i32, path &C.VoxGraphitePath) bool {
	return pixels != unsafe { nil } && path != unsafe { nil } && width > 0 && height > 0
		&& pitch >= width * 4 && path_supported(path)
}

// draw_path_with_context rasterizes a serialized SVG path into premultiplied
// BGRA8. Use the context on its owning thread. A nonzero background flag
// uses the input pixels as a backdrop. Returns 1 on success.
pub fn draw_path_with_context(mut ctx canvas.GpuContext, pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath, multisampled bool) i32 {
	if !path_pixels_supported(pixels, width, height, pitch, path) {
		return 0
	}
	return draw_supported_path(mut ctx, pixels, width, height, pitch, has_background, path, multisampled)
}

fn draw_supported_path(mut ctx canvas.GpuContext, pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath, multisampled bool) i32 {
	mut target := ctx.new_surface(width: int(width), height: int(height)) or { return 0 }
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	if multisampled { target.draw_msaa_trigger() }
	draw_descriptor(mut target, path, none, none) or { return 0 }
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}

// record_svg_path records a standalone descriptor on a caller-owned surface.
pub fn record_svg_path(mut target canvas.GpuSurface, path &C.VoxGraphitePath, dash ?SVGPathDash) ! {
	if path == unsafe { nil } || !path_supported(path) {
		return error('unsupported SVG path descriptor')
	}
	draw_descriptor(mut target, path, none, dash)!
}

// draw_descriptor adds one descriptor's draw to `target` like
// draw_path_on_canvas(): its matrix (after the SVG image's `parent`), its
// rounded clips and its paint.
fn draw_descriptor(mut target canvas.GpuSurface, path &C.VoxGraphitePath, parent ?canvas.Matrix,
	dash ?SVGPathDash) ! {
	clipped := path.has_clip != 0 || path.has_ancestor_clip != 0
	non_scaling := path.stroke != 0 && path.non_scaling_stroke != 0
	if non_scaling && !non_scaling_matrix_is_affine(path.matrix) {
		return error('non-scaling strokes require a finite affine matrix')
	}
	inverse := if non_scaling && parent != none {
		non_scaling_inverse(path.matrix)
	} else {
		none
	}
	if non_scaling && parent != none && inverse == none {
		// The original SVG image bridge skips a stroke whose local matrix
		// cannot be inverted, including any clips installed for that path.
		return
	}
	if non_scaling && clipped {
		x := f64(path.matrix[0]) * f64(path.matrix[4])
		y := f64(path.matrix[1]) * f64(path.matrix[3])
		if x == y {
			// An intersecting clip collapsed to a line has no area. Skia
			// clips the draw out before resetting the stroke's matrix.
			return
		}
	}
	if clipped {
		target.save()
	}
	if p := parent {
		// setMatrix(parent) followed by concat(SkM44(matrix)).
		target.set_matrix(p)
		target.concat(canvas.Matrix.values(path.matrix))
	} else {
		target.set_matrix(canvas.Matrix.values(path.matrix))
	}
	if path.has_clip != 0 {
		target.clip_rrect(rounded_rect(path.clip), .intersect, true)!
	}
	if path.has_ancestor_clip != 0 {
		target.clip_rrect(rounded_rect(path.ancestor_clip), .intersect, true)!
	}
	mut geometry := path_from_segments(path.segments, int(path.segment_count), path.even_odd != 0)
	if non_scaling {
		geometry = transform_non_scaling_path(geometry, path.matrix)!
		if cancel := inverse {
			// The bridge cancels only the path's user-space transform. Keep
			// SkMatrix's inverse and the two SkM44 concatenations, including
			// their rounding, instead of replacing the matrix by `parent`.
			target.concat(cancel)
		} else {
			target.set_matrix(canvas.Matrix.identity())
		}
	}
	if pattern := dash {
		geometry = dash_svg_geometry(geometry, pattern, path.matrix, non_scaling)!
	}
	mut color := shape_color([path.red, path.green, path.blue, path.alpha]!, path.has_float_color != 0,
		path.float_color)
	if path.has_float_alpha != 0 {
		color = canvas.Color4f{color.r, color.g, color.b, clamp_unit(path.opacity)}
	}
	mut paint := canvas.Paint{
		color:      color
		anti_alias: true
	}
	if path.gradient != 0 {
		paint.gradient = path_gradient(path)!
		// Blink dithers gradient paints; the opacity becomes the paint alpha.
		paint.dither = true
		paint.color = canvas.Color4f{color.r, color.g, color.b, clamp_unit(path.opacity)}
	}
	if path.stroke != 0 {
		paint = canvas.Paint{
			...paint
			style:        .stroke
			stroke_width: path.stroke_width
			cap:          match path.line_cap {
				1 { canvas.StrokeCap.round }
				2 { .square }
				else { .butt }
			}
			join:         match path.line_join {
				1 { canvas.StrokeJoin.round }
				2 { .bevel }
				else { .miter }
			}
			miter_limit:  if path.miter_limit > 1 { path.miter_limit } else { f32(1) }
		}
	}
	target.draw_path(geometry, paint)!
	if clipped {
		target.restore()
	}
}

// rounded_rect converts x, y, width, height and four radius pairs, like the
// backend's SkRRect::setRectRadii(SkRect::MakeXYWH(...)).
fn rounded_rect(v [12]f32) canvas.RRect {
	return canvas.RRect.rect_radii(canvas.Rect.xywh(v[0], v[1], v[2], v[3]), [
		canvas.Point{v[4], v[5]},
		canvas.Point{v[6], v[7]},
		canvas.Point{v[8], v[9]},
		canvas.Point{v[10], v[11]},
	]!)
}

fn shape_color(rgba [4]u8, has_float bool, float [4]f32) canvas.Color4f {
	if has_float {
		return canvas.Color4f{float[0], float[1], float[2], float[3]}
	}
	return canvas.Color4f.from_rgba8(rgba[0], rgba[1], rgba[2], rgba[3])
}
