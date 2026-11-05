module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas
import math

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
// in a linear color space and non-scaling strokes (stroked in device space)
// are not ported yet; gg.canvas declines the other gradient draws it cannot
// reproduce.
fn path_supported(path &C.VoxGraphitePath) bool {
	if path.gradient != 0 && (path.stops == unsafe { nil } || path.stop_count < 2
		|| path.linear_color_space != 0) {
		return false
	}
	return path.segments != unsafe { nil } && path.segment_count > 0
		&& path.non_scaling_stroke == 0
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
	return canvas.Gradient.two_point_conical(canvas.Point{v[0], v[1]}, v[2], canvas.Point{v[3], v[4]},
		v[5], base)!
}

// path_from_segments mirrors vox_path_from_serialized_segments()
// (native_svg_path_segments.h): twelve floats per segment, beginning with
// the segment kind.
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

// draw_path implements vox_graphite_draw_path_pixels() for supported
// descriptors like the backend's draw_path_on_canvas(): it fills the path
// over BGRA8 premultiplied pixels (or transparency without a background) and
// returns 1, or returns 0 without touching the pixels. It runs only on the
// main thread.
pub fn draw_path(pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath) i32 {
	result := draw_path_pixels(pixels, width, height, pitch, has_background, path)
	if diagnostics && path != unsafe { nil } {
		eprintln('VOX_GG path stroke=${path.stroke} gradient=${path.gradient} even_odd=${path.even_odd} drawn=${result}')
	}
	return result
}

fn draw_path_pixels(pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath) i32 {
	if pixels == unsafe { nil } || path == unsafe { nil } || width <= 0 || height <= 0
		|| pitch < width * 4 || !path_supported(path) || C.pthread_main_np() == 0 {
		return 0
	}
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(width: int(width), height: int(height)) or { return 0 }
	defer {
		target.free()
	}
	if has_background != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	draw_descriptor(mut target, path, none) or { return 0 }
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}

// draw_descriptor adds one descriptor's draw to `target` like
// draw_path_on_canvas(): its matrix (after the SVG image's `parent`), its
// rounded clips and its paint.
fn draw_descriptor(mut target canvas.GpuSurface, path &C.VoxGraphitePath, parent ?canvas.Matrix) ! {
	clipped := path.has_clip != 0 || path.has_ancestor_clip != 0
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
	geometry := path_from_segments(path.segments, int(path.segment_count), path.even_odd != 0)
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

// The flags of vox_graphite_draw_svg_image_pixels().
const svg_backdrop = 1
const svg_force_msaa = 2

// draw_svg_image implements vox_graphite_draw_svg_image_pixels() like the
// backend's draw_svg_image_pixels(): the descriptors drawn after the SVG
// image's parent matrix and clipped to its viewport (and drawn in a layer
// inside its rounded clip), over the pixels with VOX_GRAPHITE_SVG_BACKDROP
// (or transparency), in a pass that is multisampled with
// VOX_GRAPHITE_SVG_FORCE_MSAA. Descriptors gg.canvas cannot reproduce return
// 0 without touching the pixels. It runs only on the main thread.
pub fn draw_svg_image(pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	result := draw_svg_image_pixels(pixels, width, height, pitch, flags, paths, count, parent,
		viewport, rounded_clip)
	if diagnostics {
		eprintln('VOX_GG svg paths=${count} rounded=${int(rounded_clip != unsafe { nil })} drawn=${result}')
	}
	return result
}

fn draw_svg_image_pixels(pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	if pixels == unsafe { nil } || paths == unsafe { nil } || parent == unsafe { nil }
		|| viewport == unsafe { nil } || count <= 0
		|| count > 65536 || width <= 0 || height <= 0 || pitch < width * 4
		|| C.pthread_main_np() == 0 {
		return 0
	}
	for index in 0 .. int(count) {
		if !path_supported(unsafe { &paths[index] }) {
			return 0
		}
	}
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(width: int(width), height: int(height)) or { return 0 }
	defer {
		target.free()
	}
	if flags & svg_backdrop != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	if flags & svg_force_msaa != 0 {
		target.draw_msaa_trigger()
	}
	mut parent_values := [9]f32{}
	for i in 0 .. 9 {
		parent_values[i] = unsafe { parent[i] }
	}
	parent_matrix := canvas.Matrix.values(parent_values)
	target.set_matrix(parent_matrix)
	v := unsafe { [viewport[0], viewport[1], viewport[2], viewport[3]] }
	target.clip_rect(canvas.Rect.xywh(v[0], v[1], v[2], v[3]), .intersect, true) or { return 0 }
	layered := rounded_clip != unsafe { nil }
	if layered {
		mut values := [12]f32{}
		for i in 0 .. 12 {
			values[i] = unsafe { rounded_clip[i] }
		}
		target.clip_rrect(rounded_rect(values), .intersect, true) or { return 0 }
		target.save_layer(none) or { return 0 }
	}
	for index in 0 .. int(count) {
		draw_descriptor(mut target, unsafe { &paths[index] }, parent_matrix) or { return 0 }
	}
	if layered {
		target.restore()
	}
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}
