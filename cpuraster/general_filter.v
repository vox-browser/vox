module cpuraster

import math

// Canvas filter lists as LibGfx's SkiaUtils describes them, and a device-space
// evaluator for the draws the exact SkImageFilter ports decline: filters under
// rotated or skewed transforms, SVG reference graphs, color matrices that
// change transparent black and filter positions the ports do not reproduce.
// It follows the original graph's semantics: the unfiltered draw into a decal
// layer around the clip, each filter in order, then a restore through the
// clip with the blender. Results are faithful, not bit-identical to Skia;
// every draw the exact ports cover keeps using them.

// Acyclic SVG filter inputs use -1 for the preceding CSS filter's output.
// Node order and repeated inputs are significant (in particular for feMerge).
pub enum SvgFilterNodeKind {
	blur
	erode
	dilate
	merge
	offset
	to_linear_rgb
	to_srgb
	color_matrix
}

pub struct SvgFilterNode {
pub:
	kind   SvgFilterNodeKind
	inputs []int
	x      f32
	y      f32
	matrix [20]f32
}

pub struct SvgFilterGraph {
pub:
	nodes            []SvgFilterNode
	root             int = -1
	region           [4]f32
	object_bounds    bool = true
	primitive_bounds bool
}

// One canvas filter function: kind 0 blur, 1 drop-shadow, 2 color matrix,
// 3 SVG reference graph and 4 opacity (a matrix outside Chromium's table).
pub struct CanvasFilterSpec {
pub:
	kind     int
	radius   f32
	offset_x f32
	offset_y f32
	color    u32
	matrix   [20]f32
	clamp    bool
	graph    SvgFilterGraph
}

// Stroke geometry for draw_general_canvas_path(); none fills.
pub struct CanvasStrokeSpec {
pub:
	width       f32
	cap         StrokeCap
	join        StrokeJoin
	miter       f32 = 4
	dashes      []f32
	dash_offset f32
}

// How filter parameters reach device space. CSS functions on ordinary
// draws map through the drawing transform; Chromium's composited image
// layers and SVG references use bitmap coordinates.
struct GeneralFilterSpace {
	map_params bool
	m          SkAffine
	chromium   bool
	// The canvas bitmap: SVG references resolve object bounding boxes
	// and primitive units against it.
	width  int
	height int
}

fn (s GeneralFilterSpace) sigmas(sigma f32) (f32, f32) {
	if !s.map_params {
		return sigma, sigma
	}
	return sigma * general_axis_scale(s.m.sx, s.m.kx), sigma * general_axis_scale(s.m.ky, s.m.sy)
}

fn (s GeneralFilterSpace) offset(dx f32, dy f32) (f32, f32) {
	if !s.map_params {
		return dx, dy
	}
	// Each product is its own statement: Skia's arithmetic is unfused.
	xx := s.m.sx * dx
	xy := s.m.kx * dy
	yx := s.m.ky * dx
	yy := s.m.sy * dy
	return xx + xy, yx + yy
}

// The device length of a parameter-space unit along one output axis. For
// a similarity transform an isotropic Gaussian maps exactly; otherwise the
// diagonal of the mapped covariance approximates it.
fn general_axis_scale(a f32, b f32) f32 {
	aa := f64(a) * f64(a)
	bb := f64(b) * f64(b)
	return f32(math.sqrt(aa + bb))
}

// Device pixels a filter list can move content by, before any layer cap.
fn general_filter_outset(specs []CanvasFilterSpec, space GeneralFilterSpace) int {
	mut pad := f64(0)
	for spec in specs {
		match spec.kind {
			0, 1 {
				sx, sy := space.sigmas(general_clamped_sigma(spec.radius))
				kernel := 3 * math.max(f64(sx), f64(sy))
				pad += kernel + 1
				if spec.kind == 1 {
					dx, dy := space.offset(spec.offset_x, spec.offset_y)
					pad += math.max(math.abs(f64(dx)), math.abs(f64(dy)))
				}
			}
			3 {
				px, py := general_primitive_scale(spec.graph, space)
				for node in spec.graph.nodes {
					x := math.abs(f64(node.x) * px)
					y := math.abs(f64(node.y) * py)
					extent := match node.kind {
						.blur { 3 * math.max(x, y) }
						.erode, .dilate, .offset { math.max(x, y) }
						else { f64(-1) }
					}
					pad += extent + 1
				}
			}
			else {}
		}
	}
	if !math.is_finite(pad) {
		return 1024
	}
	return int(math.min(pad, 1024))
}

fn general_clamped_sigma(sigma f32) f32 {
	if !is_finite_f32(sigma) || sigma <= 0 {
		return 0
	}
	return if sigma < 532 { sigma } else { f32(532) }
}

fn general_primitive_scale(graph SvgFilterGraph, space GeneralFilterSpace) (f64, f64) {
	if graph.primitive_bounds {
		return f64(space.width), f64(space.height)
	}
	return 1, 1
}

// draw_general_filter_layer draws content into a premultiplied layer around
// the clip, applies specs (then tint, a SrcIn color) in device space and
// restores the result through the clip with mode. Returns false, without
// changing pixels, for devices Skia would tile and content that declines.
fn draw_general_filter_layer(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, specs []CanvasFilterSpec, space GeneralFilterSpace, tint ?u32, mode BlendMode, content LayerContent) bool {
	if !untiled_device(pixels, width, height, pitch) || !transform[..].all(is_finite_f32(it)) {
		return false
	}
	rc := canvas_raster_clip(width, height, clips)
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	if rc.is_empty {
		return target.ready()
	}
	output := rc.bounds()
	mut pad := general_filter_outset(specs, space)
	limit := max_untiled_dimension - math_max_int(output.width(), output.height())
	if limit < 0 {
		return false
	}
	if 2 * pad > limit {
		pad = limit / 2
	}
	layer := skif_outset(output, pad, pad)
	lw, lh := layer.width(), layer.height()
	mut layer_pixels := []u8{len: lw * lh * 4}
	m := canvas_affine(transform)
	layer_transform := [m.sx, m.ky, m.kx, m.sy, m.tx - f32(layer.left), m.ty - f32(layer.top)]!
	if !content(mut layer_pixels, lw, lh, layer_transform, []Path{}) {
		return false
	}
	mut image := BlurImage{layer_pixels, lw, lh}
	for spec in specs {
		image = apply_general_filter(image, spec, layer, space)
	}
	if color := tint {
		general_tint(mut image, color)
	}
	target.ready()
	draw_filter_bitmap(mut pixels, pitch, CanvasBitmap{
		pixels:        image.pixels
		width:         lw
		height:        lh
		pitch:         lw * 4
		premultiplied: true
		native_n32:    canvas_rgba_uses_legacy()
	}, layer.left, layer.top, &rc, mode, 1)
	return true
}

fn apply_general_filter(image BlurImage, spec CanvasFilterSpec, layer IRect, space GeneralFilterSpace) BlurImage {
	match spec.kind {
		0 {
			sx, sy := space.sigmas(general_clamped_sigma(spec.radius))
			return general_blur(image, sx, sy)
		}
		1 {
			// DropShadow: Blur -> SrcIn color -> offset, merged under the input.
			sx, sy := space.sigmas(general_clamped_sigma(spec.radius))
			mut shadow := general_blur(image, sx, sy)
			general_tint(mut shadow, spec.color)
			dx, dy := space.offset(spec.offset_x, spec.offset_y)
			shadow = general_offset(shadow, dx, dy)
			return general_merge([shadow, image], image.width, image.height)
		}
		2 {
			return general_color_matrix(image, MatrixColorFilter{
				matrix: spec.matrix
				clamp:  spec.clamp
			})
		}
		3 {
			return general_svg_graph(image, spec.graph, layer, space)
		}
		4 {
			if space.chromium {
				// Blink's FEComponentTransfer: an 8-bit alpha table from the
				// double-precision interpolation of its float opacity.
				mut table := [256]u8{}
				for j in 0 .. 256 {
					table[j] = u8(math.min(255.0, math.max(0.0, f64(j) * f64(spec.matrix[18]))))
				}
				return general_alpha_table(image, table)
			}
			return general_color_matrix(image, MatrixColorFilter{
				matrix: spec.matrix
				clamp:  spec.clamp
			})
		}
		else {
			return image
		}
	}
}

// SkImageFilters::Blur with decal tiling over the whole layer; sigmas over
// 135 take the raster blur engine's downsampled path.
fn general_blur(image BlurImage, sigma_x f32, sigma_y f32) BlurImage {
	sx := general_clamped_sigma(sigma_x)
	sy := general_clamped_sigma(sigma_y)
	if blur_layer_sigma(sx) == 0 && blur_layer_sigma(sy) == 0 {
		return image
	}
	full := IRect{0, 0, image.width, image.height}
	blurred, x, y := image_with_blur_filter(image, full, full, sx, sy) or {
		return BlurImage{[]u8{len: image.pixels.len}, image.width, image.height}
	}
	return general_place(blurred, x, y, image.width, image.height)
}

// The part of src at (x, y) inside a width x height transparent image.
fn general_place(src BlurImage, x int, y int, width int, height int) BlurImage {
	mut out := BlurImage{[]u8{len: width * height * 4}, width, height}
	for row in 0 .. src.height {
		dy := y + row
		if dy < 0 || dy >= height {
			continue
		}
		left := math_max_int(x, 0)
		right := if x + src.width < width { x + src.width } else { width }
		if left >= right {
			continue
		}
		start := (row * src.width + (left - x)) * 4
		copy(mut out.pixels[(dy * width + left) * 4..(dy * width + right) * 4], src.pixels[start..start +
			(right - left) * 4])
	}
	return out
}

// SrcIn with a constant SkColor: the color, premultiplied, scaled by the
// pixel's coverage.
fn general_tint(mut image BlurImage, color u32) {
	ca := f32(color >> 24) * inv_255
	rgb := [f32((color >> 16) & 255) * ca, f32((color >> 8) & 255) * ca, f32(color & 255) * ca]!
	for i := 0; i + 3 < image.pixels.len; i += 4 {
		a := f32(image.pixels[i + 3]) * inv_255
		image.pixels[i] = general_byte(rgb[0] * a)
		image.pixels[i + 1] = general_byte(rgb[1] * a)
		image.pixels[i + 2] = general_byte(rgb[2] * a)
		image.pixels[i + 3] = general_byte(f32(255) * ca * a)
	}
}

@[inline]
fn general_byte(v f32) u8 {
	if !(v > 0) {
		return 0
	}
	if v >= 255 {
		return 255
	}
	return u8(v + f32(0.5))
}

// SkImageFilters::Offset: whole-pixel translations copy; fractional ones
// sample bilinearly, as the deferred transform does.
fn general_offset(image BlurImage, dx f32, dy f32) BlurImage {
	if !is_finite_f32(dx) || !is_finite_f32(dy) {
		return BlurImage{[]u8{len: image.pixels.len}, image.width, image.height}
	}
	if dx == f32(math.round(dx)) && dy == f32(math.round(dy)) {
		return general_place(image, int(dx), int(dy), image.width, image.height)
	}
	w, h := image.width, image.height
	mut out := BlurImage{[]u8{len: image.pixels.len}, w, h}
	for y in 0 .. h {
		sy := f32(y) - dy
		y0 := int(math.floor(sy))
		fy := sy - f32(y0)
		for x in 0 .. w {
			sx := f32(x) - dx
			x0 := int(math.floor(sx))
			fx := sx - f32(x0)
			for c in 0 .. 4 {
				p00 := general_sample(image, x0, y0, c)
				p10 := general_sample(image, x0 + 1, y0, c)
				p01 := general_sample(image, x0, y0 + 1, c)
				p11 := general_sample(image, x0 + 1, y0 + 1, c)
				top_step := (p10 - p00) * fx
				bottom_step := (p11 - p01) * fx
				top := p00 + top_step
				bottom := p01 + bottom_step
				vertical := (bottom - top) * fy
				out.pixels[(y * w + x) * 4 + c] = general_byte(top + vertical)
			}
		}
	}
	return out
}

@[inline]
fn general_sample(image BlurImage, x int, y int, c int) f32 {
	if x < 0 || y < 0 || x >= image.width || y >= image.height {
		return 0
	}
	return f32(image.pixels[(y * image.width + x) * 4 + c])
}

// SkImageFilters::Merge: each input source-over the preceding ones.
fn general_merge(inputs []BlurImage, width int, height int) BlurImage {
	mut out := BlurImage{[]u8{len: width * height * 4}, width, height}
	for input in inputs {
		for i := 0; i + 3 < out.pixels.len; i += 4 {
			sa := u32(input.pixels[i + 3])
			if sa == 0 {
				continue
			}
			inv := 255 - sa
			for c in 0 .. 4 {
				out.pixels[i + c] = u8(math.min(u32(255), u32(input.pixels[i + c]) +
					(u32(out.pixels[i + c]) * inv + 127) / 255))
			}
		}
	}
	return out
}

// SkColorFilters::Matrix on premultiplied pixels through the ported
// color filter: unpremultiply, the matrix, clamping, premultiply.
fn general_color_matrix(image BlurImage, matrix MatrixColorFilter) BlurImage {
	filter := new_color_filter([matrix]) or { return image }
	mut out := BlurImage{[]u8{len: image.pixels.len}, image.width, image.height}
	for i := 0; i + 3 < image.pixels.len; i += 4 {
		c := filter.apply([f32(image.pixels[i]) * inv_255, f32(image.pixels[i + 1]) * inv_255, f32(image.pixels[i + 2]) * inv_255,
			f32(image.pixels[i + 3]) * inv_255]!, false)
		a := general_byte(c[3] * 255)
		out.pixels[i + 3] = a
		for k in 0 .. 3 {
			v := general_byte(c[k] * 255)
			out.pixels[i + k] = if v > a { a } else { v }
		}
	}
	return out
}

fn general_alpha_table(image BlurImage, table [256]u8) BlurImage {
	mut out := BlurImage{[]u8{len: image.pixels.len}, image.width, image.height}
	for i := 0; i + 3 < image.pixels.len; i += 4 {
		a := image.pixels[i + 3]
		if a == 0 {
			continue
		}
		na := table[a]
		for k in 0 .. 3 {
			unpremul := f32(image.pixels[i + k]) * 255 / f32(a)
			out.pixels[i + k] = general_byte(unpremul * f32(na) * inv_255)
		}
		out.pixels[i + 3] = na
	}
	return out
}

// SRGBToLinearGamma and LinearToSRGBGamma on unpremultiplied channels.
fn general_transfer(image BlurImage, to_linear bool) BlurImage {
	mut table := [256]f32{}
	for v in 0 .. 256 {
		x := f64(v) / 255
		table[v] = f32(if to_linear {
			if x <= 0.04045 { x / 12.92 } else { math.pow((x + 0.055) / 1.055, 2.4) }
		} else {
			if x <= 0.0031308 { x * 12.92 } else { general_encode_srgb(x) }
		})
	}
	mut out := BlurImage{[]u8{len: image.pixels.len}, image.width, image.height}
	for i := 0; i + 3 < image.pixels.len; i += 4 {
		a := image.pixels[i + 3]
		if a == 0 {
			continue
		}
		fa := f32(a) * inv_255
		for k in 0 .. 3 {
			unpremul := int(math.min(255.0, math.round(f64(image.pixels[i + k]) * 255 / f64(a))))
			out.pixels[i + k] = general_byte(table[unpremul] * fa * 255)
		}
		out.pixels[i + 3] = a
	}
	return out
}

fn general_encode_srgb(x f64) f64 {
	scaled := 1.055 * math.pow(x, 1 / 2.4)
	return scaled - 0.055
}

// SkImageFilters::Erode/Dilate: the per-channel minimum or maximum over a
// (2rx+1) x (2ry+1) window, decal outside the layer.
fn general_morphology(image BlurImage, rx_in int, ry_in int, dilate bool) BlurImage {
	if rx_in <= 0 && ry_in <= 0 {
		return image
	}
	// Larger radii cover the whole layer before this cap matters.
	rx := if rx_in > 256 { 256 } else if rx_in < 0 { 0 } else { rx_in }
	ry := if ry_in > 256 { 256 } else if ry_in < 0 { 0 } else { ry_in }
	w, h := image.width, image.height
	mut horizontal := BlurImage{[]u8{len: image.pixels.len}, w, h}
	for y in 0 .. h {
		for x in 0 .. w {
			for c in 0 .. 4 {
				mut v := if dilate { u8(0) } else { u8(255) }
				for k in -rx .. rx + 1 {
					s := if x + k < 0 || x + k >= w { u8(0) } else { image.pixels[(y * w + x + k) * 4 + c] }
					v = if dilate { if s > v { s } else { v } } else { if s < v { s } else { v } }
				}
				horizontal.pixels[(y * w + x) * 4 + c] = v
			}
		}
	}
	mut out := BlurImage{[]u8{len: image.pixels.len}, w, h}
	for y in 0 .. h {
		for x in 0 .. w {
			for c in 0 .. 4 {
				mut v := if dilate { u8(0) } else { u8(255) }
				for k in -ry .. ry + 1 {
					s := if y + k < 0 || y + k >= h { u8(0) } else { horizontal.pixels[((y + k) * w + x) * 4 + c] }
					v = if dilate { if s > v { s } else { v } } else { if s < v { s } else { v } }
				}
				out.pixels[(y * w + x) * 4 + c] = v
			}
		}
	}
	return out
}

// make_svg_filter(): nodes evaluated in order, inputs -1 for the source,
// the root cropped to the filter region with decal tiling. Invalid graphs
// pass the source through, as the native builder did.
fn general_svg_graph(source BlurImage, graph SvgFilterGraph, layer IRect, space GeneralFilterSpace) BlurImage {
	px, py := general_primitive_scale(graph, space)
	mut outputs := []BlurImage{}
	for i, node in graph.nodes {
		mut inputs := []BlurImage{}
		for id in node.inputs {
			if id < -1 || id >= i {
				return source
			}
			inputs << if id == -1 { source } else { outputs[id] }
		}
		input := if inputs.len == 0 { source } else { inputs[0] }
		x := f32(f64(node.x) * px)
		y := f32(f64(node.y) * py)
		outputs << match node.kind {
			.blur {
				if node.x < 0 || node.y < 0 { input } else { general_blur(input, x, y) }
			}
			.erode, .dilate {
				if node.x < 0 || node.y < 0 {
					input
				} else {
					general_morphology(input, int(math.round(x)), int(math.round(y)), node.kind == .dilate)
				}
			}
			.merge {
				general_merge(inputs, source.width, source.height)
			}
			.offset {
				general_offset(input, x, y)
			}
			.to_linear_rgb {
				general_transfer(input, true)
			}
			.to_srgb {
				general_transfer(input, false)
			}
			.color_matrix {
				general_color_matrix(input, MatrixColorFilter{
					matrix: node.matrix
					clamp:  true
				})
			}
		}
	}
	if graph.root < -1 || graph.root >= graph.nodes.len {
		return source
	}
	result := if graph.root == -1 { source } else { outputs[graph.root] }
	r := graph.region
	crop := if graph.object_bounds {
		Rect{r[0] * f32(space.width), r[1] * f32(space.height), (r[0] + r[2]) * f32(space.width), (r[1] +
			r[3]) * f32(space.height)}
	} else {
		Rect{r[0], r[1], r[0] + r[2], r[1] + r[3]}
	}
	if !(crop.left < crop.right) || !(crop.top < crop.bottom) {
		return BlurImage{[]u8{len: source.pixels.len}, source.width, source.height}
	}
	return general_crop(result, crop, layer)
}

// Crop with decal tiling: pixels whose centers fall outside the device rect
// become transparent.
fn general_crop(image BlurImage, crop Rect, layer IRect) BlurImage {
	mut out := BlurImage{image.pixels.clone(), image.width, image.height}
	for y in 0 .. image.height {
		cy := f32(layer.top + y) + f32(0.5)
		row_inside := cy >= crop.top && cy < crop.bottom
		for x in 0 .. image.width {
			cx := f32(layer.left + x) + f32(0.5)
			if !row_inside || cx < crop.left || cx >= crop.right {
				i := (y * image.width + x) * 4
				out.pixels[i] = 0
				out.pixels[i + 1] = 0
				out.pixels[i + 2] = 0
				out.pixels[i + 3] = 0
			}
		}
	}
	return out
}

// draw_general_canvas_path is the Skia-free fallback for a Canvas2D fill or
// stroke the exact ports decline. A blurred solid shadow takes the mask
// filter instead of the image filters, as CanvasCommandPlayer selects it.
pub fn draw_general_canvas_path(mut pixels []u8, width int, height int, pitch int, alpha_type int, path Path, transform [6]f32, color u32, style ?CanvasPaintStyle, global_alpha f32, mode BlendMode, stroke ?CanvasStrokeSpec, blur f32, clips []Path, specs []CanvasFilterSpec) bool {
	if blur > 0 && style == none {
		return general_path_content(mut pixels, width, height, pitch, alpha_type, path, transform,
			color, style, global_alpha, mode, stroke, blur, clips)
	}
	if specs.len == 0 {
		return general_path_content(mut pixels, width, height, pitch, alpha_type, path, transform,
			color, style, global_alpha, mode, stroke, 0, clips)
	}
	space := GeneralFilterSpace{
		map_params: true
		m:          canvas_affine(transform)
		width:      width
		height:     height
	}
	return draw_general_filter_layer(mut pixels, width, height, pitch, alpha_type, transform, clips,
		specs, space, none, mode, fn [path, color, style, global_alpha, stroke] (mut layer []u8, w int, h int, t [6]f32, layer_clips []Path) bool {
		return general_path_content(mut layer, w, h, w * 4, 2, path, t, color, style, global_alpha,
			.src_over, stroke, 0, layer_clips)
	})
}

fn general_path_content(mut pixels []u8, width int, height int, pitch int, alpha_type int, path Path, transform [6]f32, color u32, style ?CanvasPaintStyle, global_alpha f32, mode BlendMode, stroke ?CanvasStrokeSpec, blur f32, clips []Path) bool {
	if s := stroke {
		return stroke_canvas_path(mut pixels, width, height, pitch, alpha_type, path, transform,
			color, style, global_alpha, mode, blur, s.width, s.cap, s.join, s.miter, s.dashes,
			s.dash_offset, clips, none)
	}
	return fill_canvas_path(mut pixels, width, height, pitch, alpha_type, path, transform, color,
		style, global_alpha, mode, blur, clips, none)
}

// draw_general_canvas_glyphs is the fallback for fillText() runs. Faces the
// glyph ports cannot open and non-finite positions draw nothing, as Skia's
// font manager and drawTextBlob()'s bounds check do.
pub fn draw_general_canvas_glyphs(mut pixels []u8, width int, height int, pitch int, alpha_type int, run CanvasGlyphRun, transform [6]f32, color u32, style ?CanvasPaintStyle, global_alpha f32, mode BlendMode, clips []Path, specs []CanvasFilterSpec) bool {
	if specs.len == 0 {
		if fill_canvas_glyphs(mut pixels, width, height, pitch, alpha_type, run, transform, color,
			style, global_alpha, mode, clips, none) {
			return true
		}
		if !untiled_device(pixels, width, height, pitch) {
			return false
		}
		// Nothing is drawn, but the caller records a premultiplied surface.
		mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
		return target.ready()
	}
	space := GeneralFilterSpace{
		map_params: true
		m:          canvas_affine(transform)
		width:      width
		height:     height
	}
	return draw_general_filter_layer(mut pixels, width, height, pitch, alpha_type, transform, clips,
		specs, space, none, mode, fn [run, color, style, global_alpha] (mut layer []u8, w int, h int, t [6]f32, layer_clips []Path) bool {
		fill_canvas_glyphs_surface(mut layer, w, h, w * 4, 2, run, t, color, style, global_alpha,
			.src_over, layer_clips, none, true)
		return true
	})
}

// draw_general_canvas_image is the fallback for filtered drawImage().
// Chromium's composited draws filter a layer in bitmap coordinates after
// the drawing transform has placed the image.
pub fn draw_general_canvas_image(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, specs []CanvasFilterSpec, chromium bool) bool {
	if specs.len == 0 {
		return draw_canvas_image(mut pixels, width, height, pitch, alpha_type, transform, image,
			source, destination, smoothing, global_alpha, mode, clips)
	}
	space := GeneralFilterSpace{
		map_params: !chromium
		m:          canvas_affine(transform)
		chromium:   chromium
		width:      width
		height:     height
	}
	return draw_general_filter_layer(mut pixels, width, height, pitch, alpha_type, transform, clips,
		specs, space, none, mode, fn [image, source, destination, smoothing, global_alpha] (mut layer []u8, w int, h int, t [6]f32, layer_clips []Path) bool {
		return draw_canvas_image(mut layer, w, h, w * 4, 2, t, image, source, destination, smoothing,
			global_alpha, .src_over, layer_clips)
	})
}
