// Native document geometry drawn by V gg.canvas, without linking Skia.
module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas
import os
import platform

// diagnostics (VOX_GG_DIAGNOSTICS=1) prints one line per descriptor offered
// to gg.canvas with whether it was drawn, for coverage counts from captures.
const diagnostics = os.getenv('VOX_GG_DIAGNOSTICS') == '1'

#include <pthread.h>
#include "@DIR/../native/include/native_graphite_bridge.h"

fn C.pthread_main_np() i32

@[typedef]
pub struct C.VoxGraphiteShape {
pub mut:
	matrix                   [9]f32
	rect                     [12]f32
	thickness                f32
	red                      u8
	green                    u8
	blue                     u8
	alpha                    u8
	fill                     i32
	anti_alias               i32
	force_msaa               i32
	clip_outs                &f32
	clip_out_count           i32
	has_underlay             i32
	underlay_rect            [12]f32
	underlay_rgba            [4]u8
	has_float_color          i32
	float_color              [4]f32
	border_widths            [4]f32
	has_float_underlay_color i32
	underlay_float_color     [4]f32
	contour_parameters       [4]f32
	contour_reference        [12]f32
	has_contour_reference    i32
}

struct GpuState {
mut:
	ctx &canvas.GpuContext = unsafe { nil }
}

const gpu = &GpuState{}

// context returns the shared gg.canvas context. The context, sokol.gfx's
// pools (allocated through V's allocator) and every pipeline outlive the
// paint scope of the first draw, so they are created in Vox's persistent
// arena; draws themselves allocate in the caller's scope.
fn context() !&canvas.GpuContext {
	mut state := unsafe { gpu }
	if state.ctx == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer {
			platform.leave_persistent(persistent)
		}
		mut ctx := canvas.new_gpu_context()!
		ctx.precompile()
		state.ctx = ctx
	}
	return state.ctx
}

// supported reports whether gg.canvas may reproduce the descriptor's kind:
// rounded-rect fills and strokes with an optional underlay and clip-outs,
// uniform elliptical rings (modes 6 and 7, the latter sharing a layer with
// its background), single border sides with or without a background (modes
// 2..5) and equal sides (mode 8).
fn supported(shape &C.VoxGraphiteShape) bool {
	kind_ok := match shape.fill {
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 { true }
		else { false }
	}
	return kind_ok && (shape.clip_out_count == 0 || shape.clip_outs != unsafe { nil })
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

// draw implements vox_graphite_draw_shape_pixels() for supported descriptors:
// it draws the shape over BGRA8 premultiplied pixels (or transparency without
// a background) like the backend's Graphite surface and returns 1, or returns
// 0 without touching the pixels. It runs only on the main thread: it uses
// the application's sokol.gfx context, or sets up a headless Metal one (the
// macOS browser renders natively and never sets one up).
pub fn draw(pixels &u8, width i32, height i32, pitch i32, has_background i32, shape &C.VoxGraphiteShape) i32 {
	result := draw_shape_pixels(pixels, width, height, pitch, has_background, shape)
	if diagnostics && shape != unsafe { nil } {
		eprintln('VOX_GG shape fill=${shape.fill} msaa=${shape.force_msaa} drawn=${result}')
		eprintln('VOX_GG geometry rect=${shape.rect} matrix=${shape.matrix} widths=${shape.border_widths} rgba=${shape.red},${shape.green},${shape.blue},${shape.alpha} float=${shape.float_color} underlay=${shape.has_underlay} underlay_rect=${shape.underlay_rect} underlay_color=${shape.underlay_float_color}')
	}
	return result
}

fn draw_shape_pixels(pixels &u8, width i32, height i32, pitch i32, has_background i32, shape &C.VoxGraphiteShape) i32 {
	if pixels == unsafe { nil } || shape == unsafe { nil } || width <= 0 || height <= 0
		|| pitch < width * 4 || !supported(shape)
		|| C.pthread_main_np() == 0 {
		return 0
	}
	samples := if shape.force_msaa != 0 { 4 } else { 1 }
	mut ctx := context() or { return 0 }
	// A fresh surface per draw: it and its draw lists belong to the caller's
	// scope. sokol.gfx releases its Metal objects after the commits that
	// owned contexts make on every readback.
	mut target := ctx.new_surface(width: int(width), height: int(height), sample_count: samples) or {
		return 0
	}
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	if samples == 4 {
		target.draw_msaa_trigger()
	}
	target.set_matrix(canvas.Matrix.values(shape.matrix))
	// Rectangles clipped out without antialiasing, in local coordinates.
	for i in 0 .. int(shape.clip_out_count) {
		c := unsafe { &shape.clip_outs[4 * i] }
		rect := unsafe { canvas.Rect.ltrb(c[0], c[1], c[2], c[3]) }
		target.clip_rect(rect, .difference, false) or { return 0 }
	}
	anti_alias := shape.anti_alias != 0
	// The backend draws the underlay first only for rrects and rings; the
	// border modes use it as their own background.
	if shape.has_underlay != 0 && (shape.fill < 2 || shape.fill == 6) {
		underlay := canvas.Paint{
			color:      shape_color(shape.underlay_rgba, shape.has_float_underlay_color != 0,
				shape.underlay_float_color)
			anti_alias: anti_alias
		}
		target.draw_rrect(rounded_rect(shape.underlay_rect), underlay) or { return 0 }
	}
	stroke := shape.fill == 0
	paint := canvas.Paint{
		color:        shape_color([shape.red, shape.green, shape.blue, shape.alpha]!,
			shape.has_float_color != 0, shape.float_color)
		anti_alias:   anti_alias
		style:        if stroke { .stroke } else { .fill }
		stroke_width: if stroke && shape.thickness > 0 { shape.thickness } else { 0 }
	}
	if shape.fill in [11, 12, 13] {
		draw_contoured_shape(mut target, shape, paint, int(width), int(height)) or { return 0 }
	} else if shape.fill == 10 {
		mask := capsule_shadow_mask(shape, int(width), int(height)) or { return 0 }
		target.clip_rrect(rounded_rect(shape.underlay_rect), .difference, true) or { return 0 }
		target.set_matrix(canvas.Matrix.identity())
		target.draw_alpha_mask(mask, int(width), int(height), paint) or { return 0 }
	} else if shape.fill == 9 {
		// An unblurred outer shadow is the source rounded rectangle with its
		// content rounded rectangle clipped out, both with analytic coverage.
		target.clip_rrect(rounded_rect(shape.underlay_rect), .difference, true) or { return 0 }
		target.draw_rrect(rounded_rect(shape.rect), paint) or { return 0 }
	} else if shape.fill >= 2 {
		background := if shape.has_underlay != 0 {
			?canvas.Paint(canvas.Paint{
				color:      shape_color(shape.underlay_rgba, shape.has_float_underlay_color != 0,
					shape.underlay_float_color)
				anti_alias: anti_alias
			})
		} else {
			none
		}
		draw_border(mut target, rounded_rect(shape.rect), paint, int(shape.fill), shape.border_widths,
			background) or {
			$if ggshape_debug ? {
				eprintln('ggshape: ${err}')
			}
			return 0
		}
	} else {
		target.draw_rrect(rounded_rect(shape.rect), paint) or { return 0 }
	}
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}

// draw_border mirrors vox_draw_rounded_single_border()
// (native/include/native_rounded_single_border.h): a uniform
// elliptical ring (modes 6 and 7) as a double rounded rect, or with mode 7's
// background in a layer with the inverse inner contour, a single side (modes
// 2..5: top, right, bottom, left) as a rectangle clipped to the border area,
// with difference quadrilaterals for adjacent borders (drawn with the
// background in a layer clipped to the outer contour), and equal opaque sides
// with missing ones (mode 8) as one clipped fill or, for a three-sided
// rounded label, per-side miter clips.
fn draw_border(mut target canvas.GpuSurface, outer canvas.RRect, paint canvas.Paint, mode int, widths [4]f32, background ?canvas.Paint) ! {
	if mode == 6 || mode == 7 {
		half := widths[0] / 2
		fill := canvas.Paint{
			...paint
			style: .fill
		}
		outside := outer.outset(half, half)
		inside := outer.inset(half, half)
		if bg := background {
			if mode == 7 {
				// Blink's background bleed avoidance: one layer clipped to the
				// outer contour holds the background and the inverse of the
				// inner contour.
				target.save()
				target.clip_rrect(outside, .intersect, paint.anti_alias)!
				if paint.color.a == 0 {
					target.draw_rect(outside.rect, bg)!
					target.restore()
					return
				}
				target.save_layer(none)!
				target.draw_rect(outside.rect, bg)!
				mut b := canvas.PathBuilder{}
				b.add_rrect(inside, .cw, 6)
				b.set_fill_type(.inverse_winding)
				target.draw_path(b.detach(), fill)!
				target.restore()
				target.restore()
				return
			}
		}
		target.draw_drrect(outside, inside, fill)!
		return
	}
	if mode < 2 || mode > 8 {
		return error('ggshape: border mode ${mode} is not ported')
	}
	top, right, bottom, left := widths[0], widths[1], widths[2], widths[3]
	mut radii := [4]canvas.Point{}
	for i in 0 .. 4 {
		radius := outer.radii[i]
		x := radius.x - (if i == 0 || i == 3 { left } else { right })
		y := radius.y - (if i < 2 { top } else { bottom })
		radii[i] = canvas.Point{max_or_zero(x), max_or_zero(y)}
	}
	bounds := outer.rect
	inner := canvas.RRect.rect_radii(canvas.Rect.ltrb(bounds.left() + left, bounds.top() + top,
		bounds.right() - right, bounds.bottom() - bottom), radii)
	if mode == 8 {
		draw_equal_sides(mut target, outer, inner, paint, widths)!
		return
	}
	side := mode - 2
	mut isolated_side := true
	for i in 0 .. 4 {
		if i != side && widths[i] > 0 {
			isolated_side = false
		}
	}
	target.save()
	has_background := background != none
	if bg := background {
		// The side and its background share a layer clipped to the outer
		// contour, like Blink's background bleed avoidance.
		target.clip_rrect(outer, .intersect, true)!
		target.save_layer(bounds)!
		target.draw_rect(bounds, bg)!
	}
	if isolated_side && !has_background {
		// Only Blink's corner-extent rectangle, after the rounded clips.
		target.clip_rrect(outer, .intersect, true)!
		target.clip_rrect(inner, .difference, true)!
		ul := outer.radii[0]
		ur := outer.radii[1]
		lr := outer.radii[2]
		ll := outer.radii[3]
		side_bounds := match side {
			0 {
				canvas.Rect.ltrb(bounds.left(), bounds.top(), bounds.right(), bounds.top() +
					max3(top, ul.y, ur.y))
			}
			1 {
				canvas.Rect.ltrb(bounds.right() - max3(right, ur.x, lr.x), bounds.top(),
					bounds.right(), bounds.bottom())
			}
			2 {
				canvas.Rect.ltrb(bounds.left(), bounds.bottom() - max3(bottom, ll.y, lr.y),
					bounds.right(), bounds.bottom())
			}
			else {
				canvas.Rect.ltrb(bounds.left(), bounds.top(), bounds.left() +
					max3(left, ul.x, ll.x), bounds.bottom())
			}
		}
		target.save()
		target.clip_rect(side_bounds, .intersect, true)!
		target.draw_rect(bounds, paint)!
		target.restore()
		target.restore()
		return
	}
	// Exclude the opposite pair of corners for transparent adjacent borders.
	center_x := midpoint(bounds.left(), bounds.right())
	center_y := midpoint(bounds.top(), bounds.bottom())
	side_bounds := match side {
		0 { canvas.Rect.ltrb(bounds.left(), bounds.top(), bounds.right(), center_y) }
		1 { canvas.Rect.ltrb(center_x, bounds.top(), bounds.right(), bounds.bottom()) }
		2 { canvas.Rect.ltrb(bounds.left(), center_y, bounds.right(), bounds.bottom()) }
		else { canvas.Rect.ltrb(bounds.left(), bounds.top(), center_x, bounds.bottom()) }
	}
	target.clip_rect(side_bounds, .intersect, false)!
	if !has_background {
		target.clip_rrect(outer, .intersect, true)!
	}
	target.clip_rrect(inner, .difference, true)!
	// Each differently colored adjacent side is clipped out with its own
	// difference quadrilateral.
	corners := [canvas.Point{bounds.left(), bounds.top()}, canvas.Point{bounds.right(), bounds.top()},
		canvas.Point{bounds.right(), bounds.bottom()}, canvas.Point{bounds.left(), bounds.bottom()}]!
	offsets := [canvas.Point{left, top}, canvas.Point{-right, top}, canvas.Point{-right, -bottom},
		canvas.Point{left, -bottom}]!
	ends := [side, (side + 1) % 4]!
	adjacent_widths := [widths[(side + 3) % 4], widths[(side + 1) % 4]]!
	for end in 0 .. 2 {
		if !(adjacent_widths[end] > 0) {
			continue
		}
		corner := ends[end]
		adjacent := (corner + (if end == 0 { 3 } else { 1 })) % 4
		outer_corner := corners[corner]
		offset := offsets[corner]
		extent := if side == 0 || side == 2 { bounds.height() } else { bounds.width() }
		side_width := widths[side]
		sum := extent + side_width
		scale := sum / side_width
		ox := offset.x * scale
		oy := offset.y * scale
		intersection := canvas.Point{outer_corner.x + ox, outer_corner.y + oy}
		a := corners[adjacent]
		mut miter := canvas.PathBuilder{}
		miter.move_to(outer_corner.x - offset.x, outer_corner.y - offset.y)
		miter.line_to(intersection.x, intersection.y)
		miter.line_to(a.x + offset.x, a.y + offset.y)
		miter.line_to(a.x - offset.x, a.y - offset.y)
		miter.close()
		target.clip_path(miter.detach(), .difference, true)!
	}
	target.draw_rect(bounds, paint)!
	if has_background {
		target.restore()
	}
	target.restore()
}

// draw_equal_sides is mode 8 of vox_draw_rounded_single_border(): opaque
// sides of one color with some sides missing.
fn draw_equal_sides(mut target canvas.GpuSurface, outer canvas.RRect, inner canvas.RRect, paint canvas.Paint, widths [4]f32) ! {
	top, right, bottom, left := widths[0], widths[1], widths[2], widths[3]
	bounds := outer.rect
	missing_left := left == 0 && top > 0 && top == right && top == bottom
	missing_right := right == 0 && top > 0 && top == left && top == bottom
	upper := outer.radii[if missing_left { 1 } else { 0 }]
	lower := outer.radii[if missing_left { 2 } else { 3 }]
	square_upper := outer.radii[if missing_left { 0 } else { 1 }]
	square_lower := outer.radii[if missing_left { 3 } else { 2 }]
	if (missing_left || missing_right) && upper == lower && upper.x == upper.y && upper.x > top
		&& upper.x * 2 <= bounds.height() && upper.x <= bounds.width() && square_upper.x == 0
		&& square_upper.y == 0 && square_lower.x == 0 && square_lower.y == 0 {
		// A square-ended, three-sided rounded label paints each side
		// separately, with a soft missing-side clip and a hard corner miter.
		l, r, t, b := bounds.left(), bounds.right(), bounds.top(), bounds.bottom()
		half := (upper.x - top) / 2
		depth := top + half
		// Blink extends the miter by 0.1 CSS pixels along its edge.
		extension := f32(0.1)
		mut top_path := canvas.PathBuilder{}
		mut bottom_path := canvas.PathBuilder{}
		mut end_path := canvas.PathBuilder{}
		if missing_left {
			top_path.move_to(l, t)
			top_path.line_to(l, t + depth)
			top_path.line_to(r - depth + extension, t + depth)
			top_path.line_to(r + extension, t)
			bottom_path.move_to(r + extension, b)
			bottom_path.line_to(r - depth + extension, b - depth)
			bottom_path.line_to(l, b - depth)
			bottom_path.line_to(l, b)
			end_path.move_to(r, t)
			end_path.line_to(r - depth, t + depth)
			end_path.line_to(r - depth, b - depth)
			end_path.line_to(r, b)
		} else {
			top_path.move_to(l - extension, t)
			top_path.line_to(l + depth - extension, t + depth)
			top_path.line_to(r, t + depth)
			top_path.line_to(r, t)
			bottom_path.move_to(r, b)
			bottom_path.line_to(r, b - depth)
			bottom_path.line_to(l + depth - extension, b - depth)
			bottom_path.line_to(l - extension, b)
			end_path.move_to(l, b)
			end_path.line_to(l + depth, b - depth)
			end_path.line_to(l + depth, t + depth)
			end_path.line_to(l, t)
		}
		top_clip := canvas.Rect.ltrb(l - (if missing_left { extension } else { f32(0) }), t,
			r + (if missing_right { extension } else { f32(0) }), t + depth)
		bottom_clip := canvas.Rect.ltrb(top_clip.left(), b - depth, top_clip.right(), b)
		top_miter := top_path.detach()
		bottom_miter := bottom_path.detach()
		end_miter := end_path.detach()
		target.save()
		target.clip_rrect(outer, .intersect, true)!
		target.clip_rrect(inner, .difference, true)!
		for side in [0, 2, 1] {
			target.save()
			if side == 1 {
				target.clip_path(end_miter, .intersect, false)!
			} else {
				clip := if side == 0 { top_clip } else { bottom_clip }
				miter := if side == 0 { top_miter } else { bottom_miter }
				soft_first := (side == 0) == missing_left
				if soft_first {
					target.clip_rect(clip, .intersect, true)!
				}
				target.clip_path(miter, .intersect, false)!
				if !soft_first {
					target.clip_rect(clip, .intersect, true)!
				}
			}
			target.draw_rect(bounds, paint)!
			target.restore()
		}
		target.restore()
		return
	}
	// The present sides share an opaque solid color; their union is the
	// border area, drawn as one clipped fill.
	target.save()
	target.clip_rrect(outer, .intersect, true)!
	target.clip_rrect(inner, .difference, true)!
	target.draw_rect(bounds, paint)!
	target.restore()
}

// max_or_zero is std::max(0.f, v).
fn max_or_zero(v f32) f32 {
	return if f32(0) < v { v } else { f32(0) }
}

// max3 is std::max({a, b, c}).
fn max3(a f32, b f32, c f32) f32 {
	mut m := a
	if m < b {
		m = b
	}
	if m < c {
		m = c
	}
	return m
}

// midpoint is SkRect::centerX()/centerY() (sk_float_midpoint).
fn midpoint(a f32, b f32) f32 {
	return f32(0.5 * (f64(a) + f64(b)))
}
