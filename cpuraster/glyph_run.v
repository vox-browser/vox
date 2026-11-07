module cpuraster

import math

// Canvas2D fillText() glyph runs, as skia/canvas_raster.cpp's
// vox_skia_canvas_glyphs() draws them with LibWeb Skia: an SkFont at the
// run's size (subpixel positioning, no hinting, no baseline snap) in a
// positioned SkTextBlob, drawn through SkCanvas::drawTextBlob() under the
// clips and transform. On a raster surface that is
// skcpu::GlyphRunListPainter::drawForBitmapDevice(): glyphs whose text
// matrix stays at most 256 pixels per em become A8 masks of an unhinted
// SkScalerContext_Mac strike, positioned to a quarter pixel and blitted with
// the paint (Draw::paintMasks()). Larger glyphs are filled as paths: the
// outlines of a 64-point strike, scaled to the font size and placed at
// their positions (SkStrikeSpec::MakePath()).

// CanvasGlyphRun is a positioned glyph run: the font file and face, its
// size, glyph IDs, x and y per glyph, and the blob's origin.
pub struct CanvasGlyphRun {
pub:
	font_path   string
	face_index  int
	font_size   f32
	glyphs      []u16
	positions   []f32
	translation [2]f32
}

// fill_canvas_glyphs fills run with color (an SkColor), or the gradient or
// pattern style when there is one, at global_alpha through transform and
// the device-space clip paths, as for fill_canvas_path(). Returns false
// without changing pixels for a draw it does not cover: devices Skia would
// tile, faces Skia cannot open, color glyphs too wide for SkGlyph, and
// non-finite glyph positions.
pub fn fill_canvas_glyphs(mut pixels []u8, width int, height int, pitch int, alpha_type int, run CanvasGlyphRun, transform [6]f32, color u32, style ?CanvasPaintStyle, global_alpha f32, mode BlendMode, clips []Path) bool {
	if run.glyphs.len == 0 {
		return true
	}
	if !untiled_device(pixels, width, height, pitch) || !canvas_style_installs(style)
		|| run.positions.len < run.glyphs.len * 2 {
		return false
	}
	for v in run.positions[..run.glyphs.len * 2] {
		if !is_finite_f32(v) {
			return false
		}
	}
	// SkTypeface_Mac::MakeFromStream() only opens the first face.
	if run.face_index != 0 {
		return false
	}
	face := open_glyph_face(run.font_path) or { return false }
	defer {
		face.release()
	}
	ctm := canvas_affine(transform)
	origin := Point{run.translation[0], run.translation[1]}
	position_matrix := pre_translate(ctm, origin.x, origin.y)
	routes := glyph_routes(face, run.glyphs, glyphs_draw_as_paths(run.font_size, position_matrix)) or {
		return false
	}
	paint_color, _ := canvas_paint_source(color, style, 0)
	alpha := canvas_paint_alpha(paint_color, global_alpha)
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	shader := canvas_paint_shader(style, matrix)
	// The mask strike: A8 with the paint's mask gamma, or ARGB for a color
	// typeface, whose glyphs CoreText draws in the paint's opaque color.
	mut strike := new_glyph_strike(face, run.font_size, position_matrix, paint_luminance(paint_color,
		shader)) or { GlyphStrike{} }
	defer {
		strike.release()
	}
	if face.color_glyphs {
		strike.color = true
		strike.foreground = paint_color & 0xffffff
	}
	// prepare_for_direct_mask_drawing(): device positions plus half the
	// quarter-pixel sample frequency, floored, with the fraction packed into
	// the glyph's subpixel position.
	rounding := SkAffine{
		...position_matrix
		tx: position_matrix.tx + glyph_subpixel_round
		ty: position_matrix.ty + glyph_subpixel_round
	}
	if face.color_glyphs && strike.font != unsafe { nil } {
		// Color glyphs too wide for SkGlyph go to a bitmap fallback that is
		// not ported.
		for i, id in run.glyphs {
			if routes[i].kind == .mask {
				mapped := map_point_affine(rounding, Point{run.positions[i * 2], run.positions[i * 2 + 1]})
				if strike.glyph_bounds(id, packed_subpixel(mapped.x), packed_subpixel(mapped.y)).width >= glyph_max_width {
					return false
				}
			}
		}
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	target.ready()
	// SkCanvas::drawTextBlob(): the blob's bounds at the origin must be
	// finite, and at most 2^21 glyphs are drawn.
	if !is_finite_f32(origin.x) || !is_finite_f32(origin.y) || run.glyphs.len > 1 << 21 {
		return true
	}
	if blend_draws_nothing(mode, paint_alpha_byte(alpha)) {
		return true
	}
	rc := canvas_raster_clip(width, height, clips)
	// SkCanvas::onDrawGlyphRunList()'s quick reject with the blob's
	// conservative bounds: the glyph positions expanded by the typeface's
	// bounds at the font size. Empty typeface bounds take the glyphs' own
	// bounds instead, which cannot reject a glyph that would touch the clip.
	if font_bounds := face.font_bounds(run.font_size) {
		mut bounds := glyph_positions_bounds(run.positions[..run.glyphs.len * 2])
		bounds = Rect{bounds.left + font_bounds.left, bounds.top + font_bounds.top, bounds.right +
			font_bounds.right, bounds.bottom + font_bounds.bottom}
		blob := if bounds.left < bounds.right && bounds.top < bounds.bottom { bounds } else { Rect{} }
		local := Rect{blob.left + origin.x, blob.top + origin.y, blob.right + origin.x, blob.bottom +
			origin.y}
		if canvas_quick_reject(local, matrix, &rc) {
			return true
		}
	}
	if rc.is_empty {
		return true
	}
	fill_glyph_outlines(mut pixels, pitch, run, routes, ctm, &rc, paint_color, shader, alpha, mode)
	if strike.font == unsafe { nil } {
		// A singular matrix zeroes fTransform: every mask is empty.
		return true
	}
	// SkBlitter::Choose() for the A8 masks. Color glyphs are sprites with
	// blitters of their own, so a paint that leaves the masks an
	// SkNullBlitter still draws them.
	if strike.color {
		fill_color_glyphs(mut pixels, pitch, run, routes, mut strike, rounding, &rc, paint_color,
			alpha, mode)
		return true
	}
	blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, alpha, mode, Rect{}) or {
		return true
	}
	mut wrapped, clip_bounds := clip_wrapper(&rc, blitter)
	for i, id in run.glyphs {
		if routes[i].kind != .mask {
			continue
		}
		mapped := map_point_affine(rounding, Point{run.positions[i * 2], run.positions[i * 2 + 1]})
		glyph := strike.glyph(id, packed_subpixel(mapped.x), packed_subpixel(mapped.y))
		if glyph.width == 0 || glyph.height == 0 || glyph.width >= glyph_max_width {
			// Empty glyphs are dropped; A8 images too wide for SkGlyph are
			// rejected to a fallback that only draws color glyphs.
			continue
		}
		pos := Point{floor_f32(mapped.x), floor_f32(mapped.y)}
		if !check_glyph_position(pos) {
			continue
		}
		x := float_saturate2int(pos.x)
		y := float_saturate2int(pos.y)
		mask := Mask{
			bounds:    IRect{glyph.left + x, glyph.top + y, glyph.left + x + glyph.width, glyph.top + y +
				glyph.height}
			row_bytes: glyph.width
			image:     glyph.image
		}
		mut bounds := mask.bounds
		if !(clip_bounds.left <= bounds.left && clip_bounds.top <= bounds.top
			&& clip_bounds.right >= bounds.right && clip_bounds.bottom >= bounds.bottom) {
			bounds = bounds.intersect(clip_bounds) or { continue }
		}
		wrapped.blit_mask(&mask, bounds)
	}
	return true
}

// Draw::paintMasks() for an ARGB32 strike: each glyph that survives the
// position check and touches the clip bounds is drawn whole as a sprite.
fn fill_color_glyphs(mut pixels []u8, pitch int, run CanvasGlyphRun, routes []GlyphRoute, mut strike GlyphStrike, rounding SkAffine, rc &RasterClip, color u32, alpha f32, mode BlendMode) {
	clip_bounds := rc.bounds()
	for i, id in run.glyphs {
		if routes[i].kind != .mask {
			continue
		}
		mapped := map_point_affine(rounding, Point{run.positions[i * 2], run.positions[i * 2 + 1]})
		glyph := strike.glyph(id, packed_subpixel(mapped.x), packed_subpixel(mapped.y))
		if glyph.width == 0 || glyph.height == 0 {
			continue
		}
		pos := Point{floor_f32(mapped.x), floor_f32(mapped.y)}
		if !check_glyph_position(pos) {
			continue
		}
		x := float_saturate2int(pos.x) + glyph.left
		y := float_saturate2int(pos.y) + glyph.top
		if !irect_intersects(clip_bounds, IRect{x, y, x + glyph.width, y + glyph.height}) {
			continue
		}
		draw_glyph_sprite(mut pixels, pitch, glyph, x, y, rc, color, alpha, mode)
	}
}

// Draw::drawSprite() of a color glyph's N32 premultiplied image at (x, y)
// with the text paint: SkBlitter::ChooseSprite() when the clip handles the
// sprite, otherwise Draw::drawRect() with the image as a nearest, clamped
// shader translated to (x, y).
fn draw_glyph_sprite(mut pixels []u8, pitch int, glyph StrikeGlyph, x int, y int, rc &RasterClip, color u32, alpha f32, mode BlendMode) {
	bounds := IRect{x, y, x + glyph.width, y + glyph.height}
	if !irect_intersects(rc.bounds(), bounds) {
		return
	}
	bitmap := CanvasBitmap{
		pixels:        glyph.image
		width:         glyph.width
		height:        glyph.height
		pitch:         glyph.width * 4
		premultiplied: true
	}
	if rc.is_bw || rc.aa.quick_contains(bounds.left, bounds.top, bounds.right, bounds.bottom) {
		if mut sprite := choose_sprite(mut pixels, pitch, bitmap, x, y, paint_alpha_byte(alpha),
			alpha, mode)
		{
			fill_irect(bounds, rc, mut sprite)
			return
		}
	}
	shader := new_image_shader(bitmap, .clamp, .clamp, false, affine_translate(f32(x), f32(y)))
	dev := Rect{f32(x), f32(y), f32(bounds.right), f32(bounds.bottom)}
	mut blitter := canvas_paint_blitter(mut pixels, pitch, color, shader, alpha, mode, dev) or {
		return
	}
	fill_irect(bounds, rc, mut blitter)
}

enum GlyphRouteKind {
	mask
	path
	drop
}

struct GlyphRoute {
	kind    GlyphRouteKind
	outline Path
}

// SkFontPriv::kCanonicalTextSizeForPaths.
const glyph_path_size = f32(64)

// drawForBitmapDevice()'s routes for each glyph. Below the path size every
// glyph is a mask. Otherwise the 64-point path strike decides: glyphs that
// are empty there are dropped, glyphs with outlines are filled as paths,
// and glyphs without (every glyph of a color typeface) become masks at the
// full size.
fn glyph_routes(face GlyphFace, ids []u16, as_paths bool) ?[]GlyphRoute {
	if !as_paths {
		return []GlyphRoute{len: ids.len}
	}
	mut strike := new_glyph_strike(face, glyph_path_size, SkAffine{}, 0) or { return none }
	defer {
		strike.release()
	}
	mut routes := []GlyphRoute{}
	mut cache := map[u16]GlyphRoute{}
	for id in ids {
		if route := cache[id] {
			routes << route
			continue
		}
		bounds := strike.glyph_bounds(id, 0, 0)
		route := if bounds.width == 0 || bounds.height == 0 {
			GlyphRoute{
				kind: .drop
			}
		} else if face.color_glyphs {
			GlyphRoute{}
		} else if outline := glyph_outline(strike.font, id, strike.transform) {
			GlyphRoute{
				kind:    .path
				outline: outline
			}
		} else {
			GlyphRoute{}
		}
		cache[id] = route
		routes << route
	}
	return routes
}

// SkScalerContext_Mac::generatePath() for an unsnapped subpixel strike:
// CoreText's path at four times the size, through SkCTPathGeometrySink
// (moves deferred to the next segment, segments that stay at the current
// point dropped, y flipped), scaled back by a quarter.
fn glyph_outline(font voidptr, id u16, transform [6]f64) ?Path {
	elements := glyph_path(font, id, transform, 4, 4)?
	mut b := PathBuilder{}
	mut started := false
	mut cx := f64(0)
	mut cy := f64(0)
	for i := 0; i + 6 < elements.len; i += 7 {
		e := elements[i..i + 7]
		match int(e[0]) {
			0 {
				started = false
				cx = e[1]
				cy = e[2]
			}
			1 {
				if cx != e[1] || cy != e[2] {
					if !started {
						started = true
						b.move_to(f32(cx), f32(-cy))
					}
					cx, cy = e[1], e[2]
					b.line_to(f32(e[1]), f32(-e[2]))
				}
			}
			2 {
				if cx != e[1] || cy != e[2] || cx != e[3] || cy != e[4] {
					if !started {
						started = true
						b.move_to(f32(cx), f32(-cy))
					}
					cx, cy = e[3], e[4]
					b.quad_to(f32(e[1]), f32(-e[2]), f32(e[3]), f32(-e[4]))
				}
			}
			3 {
				if cx != e[1] || cy != e[2] || cx != e[3] || cy != e[4] || cx != e[5] || cy != e[6] {
					if !started {
						started = true
						b.move_to(f32(cx), f32(-cy))
					}
					cx, cy = e[5], e[6]
					b.cubic_to(f32(e[1]), f32(-e[2]), f32(e[3]), f32(-e[4]), f32(e[5]), f32(-e[6]))
				}
			}
			4 {
				if started {
					b.close()
				}
			}
			else {}
		}
	}
	// SkPathBuilder::transform() with the inverse scale.
	quarter := f32(1) / f32(4)
	for mut p in b.points {
		p = Point{p.x * quarter, p.y * quarter}
	}
	return b.detach()
}

// The path branch of drawForBitmapDevice(): each glyph's outline at
// (origin + position) scaled from 64 points to the font size, filled
// anti-aliased like SkCanvas::drawPath(). Without a shader the scale and
// translation are concatenated onto the canvas matrix (SkCanvas::concat(),
// in SkM44's float arithmetic); with one the outline's points are mapped
// first so the shader keeps the canvas matrix.
fn fill_glyph_outlines(mut pixels []u8, pitch int, run CanvasGlyphRun, routes []GlyphRoute, ctm SkAffine, rc &RasterClip, color u32, shader ?CanvasShader, alpha f32, mode BlendMode) {
	scale := run.font_size / glyph_path_size
	exact_ctm := if s := shader { s.kind != .null_ } else { false }
	ctm_matrix := Matrix{ctm.sx, ctm.ky, ctm.kx, ctm.sy, ctm.tx, ctm.ty}
	for i, route in routes {
		if route.kind != .path {
			continue
		}
		outline := route.outline
		tx := run.translation[0] + run.positions[i * 2]
		ty := run.translation[1] + run.positions[i * 2 + 1]
		device := if exact_ctm {
			placed := if (scale == 1 && tx == 0 && ty == 0) || outline.verbs.len == 0 {
				outline
			} else {
				outline.transform(Matrix{scale, 0, 0, scale, tx, ty})
			}
			placed.transform(ctm_matrix)
		} else {
			m := if scale == 1 && tx == 0 && ty == 0 {
				ctm
			} else {
				m44_pre_concat_scale_translate(ctm, scale, tx, ty)
			}
			outline.transform(Matrix{m.sx, m.ky, m.kx, m.sy, m.tx, m.ty})
		}
		mut blitter := canvas_paint_blitter(mut pixels, pitch, color, shader, alpha, mode,
			device.bounds() or { Rect{} }) or { continue }
		anti_fill_path_clip(device, false, rc, mut blitter)
	}
}

// SkM44::preConcat() of the canvas matrix with a scale-translate, as
// SkM44's columns: c0 * r0 + (c1 * r1 + (c2 * r2 + c3 * r3)) per column.
fn m44_pre_concat_scale_translate(c SkAffine, s f32, tx f32, ty f32) SkAffine {
	z := f32(0)
	one := f32(1)
	sx := m44_column(c.sx, c.kx, c.tx, s, z, z, z)
	ky := m44_column(c.ky, c.sy, c.ty, s, z, z, z)
	kx := m44_column(c.sx, c.kx, c.tx, z, s, z, z)
	sy := m44_column(c.ky, c.sy, c.ty, z, s, z, z)
	ntx := m44_column(c.sx, c.kx, c.tx, tx, ty, z, one)
	nty := m44_column(c.ky, c.sy, c.ty, tx, ty, z, one)
	return SkAffine{
		sx: sx
		kx: kx
		tx: ntx
		ky: ky
		sy: sy
		ty: nty
	}
}

// One row of a column: a * r0 + (b * r1 + (0 * r2 + t * r3)).
fn m44_column(a f32, b f32, t f32, r0 f32, r1 f32, r2 f32, r3 f32) f32 {
	p0 := a * r0
	p1 := b * r1
	p2 := f32(0) * r2
	p3 := t * r3
	inner := p2 + p3
	middle := p1 + inner
	return p0 + middle
}

// SkPackedGlyphID::kSubpixelRound: half of a quarter pixel.
const glyph_subpixel_round = f32(1) / f32(8)

// SkGlyph::kMaxGlyphWidth.
const glyph_max_width = 1 << 13

// SkPackedGlyphID::PackIDSkPoint()'s two-bit field for one axis.
fn packed_subpixel(v f32) int {
	f := v - floor_f32(v)
	shifted := f + f32(1)
	return int(shifted * f32(4)) & 3
}

// sk_float_saturate2int().
fn float_saturate2int(v f32) int {
	max_fits := f32(2147483520)
	min_fits := f32(-2147483520)
	mut x := if v < max_fits { v } else { max_fits }
	x = if x > min_fits { x } else { min_fits }
	return int(x)
}

// check_glyph_position(): keeps glyphs off the edges of device space.
fn check_glyph_position(p Point) bool {
	high := f32(i64(max_i32) - (32767 + 65535))
	low := f32(i64(min_i32) + 32768)
	return p.x <= high && p.x >= low && p.y <= high && p.y >= low
}

// SkMatrix::mapPointAffine().
fn map_point_affine(m SkAffine, p Point) Point {
	xx := p.x * m.sx
	xy := p.y * m.kx
	ux := xx + xy
	yx := p.x * m.ky
	yy := p.y * m.sy
	uy := yx + yy
	return Point{ux + m.tx, uy + m.ty}
}

// SkMatrix::setConcat(a, b), including its identity shortcuts.
fn affine_set_concat(a SkAffine, b SkAffine) SkAffine {
	if a.type_mask() == 0 {
		return b
	}
	if b.type_mask() == 0 {
		return a
	}
	return affine_concat(a, b)
}

// SkStrikeSpec::ShouldDrawAsPath(): the text matrix (the font size, then
// the position matrix) maps an axis to more than 256 pixels.
fn glyphs_draw_as_paths(size f32, position_matrix SkAffine) bool {
	text := affine_set_concat(position_matrix, SkAffine{
		sx: size
		sy: size
	})
	x0 := text.sx * text.sx
	x1 := text.ky * text.ky
	y0 := text.kx * text.kx
	y1 := text.sy * text.sy
	limit := f32(256 * 256)
	return x0 + x1 > limit || y0 + y1 > limit
}

// SkRect::BoundsOrEmpty() of the glyph positions.
fn glyph_positions_bounds(positions []f32) Rect {
	mut r := Rect{positions[0], positions[1], positions[0], positions[1]}
	for i := 2; i + 1 < positions.len; i += 2 {
		r = Rect{fmin_std(positions[i], r.left), fmin_std(positions[i + 1], r.top), fmax_std(positions[i],
			r.right), fmax_std(positions[i + 1], r.bottom)}
	}
	return r
}

// sk_t_scale255<3>().
fn scale255_3(base u32) u32 {
	b := base << 5
	return b | (b >> 3) | (b >> 6)
}

// SkComputeLuminance().
fn compute_luminance(r u32, g u32, b u32) u32 {
	return (r * 54 + g * 183 + b * 19) >> 8
}

// The rec's luminance color for the paint (SkPaintPriv::
// ComputeLuminanceColor(): the paint color, the shader's luminance color,
// or 50% gray for a shader without one), canonicalized and reduced to gray
// for A8 masks by SkScalerContext::PreprocessRec(); the mask gamma table it
// selects.
fn paint_luminance(color u32, shader ?CanvasShader) int {
	mut c := color & 0xffffff
	if s := shader {
		c = match s.kind {
			.null_ { c }
			.color { color4f_byte(s.color[0]) << 16 | color4f_byte(s.color[1]) << 8 | color4f_byte(s.color[2]) }
			.gradient { s.gradient.luminance & 0xffffff }
			else { u32(0x808080) }
		}
	}
	r := scale255_3((c >> 16 & 0xff) >> 5)
	g := scale255_3((c >> 8 & 0xff) >> 5)
	b := scale255_3((c & 0xff) >> 5)
	return int(compute_luminance(r, g, b) >> 5)
}

// SkSRGBColorSpaceLuminance.
fn srgb_to_luma(luminance f32) f32 {
	if luminance <= f32(0.04045) {
		return luminance / f32(12.92)
	}
	shifted := luminance + f32(0.055)
	return math.powf(shifted / f32(1.055), f32(2.4))
}

fn srgb_from_luma(luma f32) f32 {
	if luma <= f32(0.0031308) {
		return luma * f32(12.92)
	}
	inverse := f32(1) / f32(2.4)
	scaled := f32(1.055) * math.powf(luma, inverse)
	return scaled - f32(0.055)
}

// The default SkMaskGamma, SkTMaskGamma<3, 3, 3>(SK_GAMMA_CONTRAST 0.5,
// SK_GAMMA_EXPONENT 0 (sRGB)), as the rec stores them: eight 256-entry
// tables from SkTMaskGamma_build_correcting_lut().
const mask_gamma_tables = build_mask_gamma_tables()

fn build_mask_gamma_tables() [][]u8 {
	contrast := f32(128) / f32(255)
	mut tables := [][]u8{}
	for i in u32(0) .. 8 {
		tables << correcting_lut(scale255_3(i), contrast)
	}
	return tables
}

fn correcting_lut(src_i u32, contrast f32) []u8 {
	mut table := []u8{len: 256}
	src := f32(src_i) / f32(255)
	lin_src := srgb_to_luma(src)
	dst := f32(1) - src
	lin_dst := srgb_to_luma(dst)
	adjusted_contrast := contrast * lin_dst
	near := f64(math.abs(src - dst)) < f64(f32(1) / f32(256))
	mut ii := f32(0)
	for i in 0 .. 256 {
		raw := ii / f32(255)
		// apply_contrast(): srca + ((1 - srca) * contrast * srca).
		inv := f32(1) - raw
		boost0 := inv * adjusted_contrast
		boost := boost0 * raw
		srca := raw + boost
		if near {
			scaled := f32(255) * srca
			table[i] = u8(float_saturate2int(f32(math.floor(f64(scaled) + 0.5))))
		} else {
			dsta := f32(1) - srca
			src_part := lin_src * srca
			dst_part := dsta * lin_dst
			lin_out := src_part + dst_part
			out := srgb_from_luma(lin_out)
			num := out - dst
			den := src - dst
			result := num / den
			scaled := f32(255) * result
			table[i] = u8(float_saturate2int(f32(math.floor(f64(scaled) + 0.5))))
		}
		ii += f32(1)
	}
	return table
}

// sk_relax(): rounds to 1/1024.
fn sk_relax(x f32) f32 {
	scaled := x * f32(1024)
	n := f32(math.floor(f64(scaled) + 0.5))
	return n / f32(1024)
}

// SkComputeGivensRotation() as the rotation's (sin, cos).
fn givens_rotation(a f32, b f32) (f32, f32) {
	if b == 0 {
		return f32(0), copysign_f32(1, a)
	}
	if a == 0 {
		return -copysign_f32(1, b), f32(0)
	}
	if f32(math.abs(b)) > f32(math.abs(a)) {
		t := a / b
		tt := t * t
		u := copysign_f32(C.sqrtf(f32(1) + tt), b)
		s := f32(-1) / u
		c := -s * t
		return s, c
	}
	t := b / a
	tt := t * t
	u := copysign_f32(C.sqrtf(f32(1) + tt), a)
	c := f32(1) / u
	s := -c * t
	return s, c
}

fn copysign_f32(magnitude f32, sign f32) f32 {
	return f32(math.copysign(f64(magnitude), f64(sign)))
}

// GlyphStrikeMatrices is SkScalerContextRec::computeMatrices(kVertical) for
// the rec of a mask strike: the text size CoreText draws at (s.y) and the
// remaining transform sA, as SkScalerContext_Mac turns it into fTransform.
struct GlyphStrikeMatrices {
	text_size  f32
	remaining  SkAffine
	invertible bool
}

fn glyph_strike_matrices(size f32, device SkAffine) GlyphStrikeMatrices {
	// MakeRecAndEffects(): the device matrix's 2x2, relaxed.
	mask := device.type_mask()
	mut post := SkAffine{}
	if mask & affine_scale_mask != 0 {
		post = SkAffine{
			...post
			sx: sk_relax(device.sx)
			sy: sk_relax(device.sy)
		}
	}
	if mask & affine_affine_mask != 0 {
		post = SkAffine{
			...post
			kx: sk_relax(device.kx)
			ky: sk_relax(device.ky)
		}
	}
	// getSingleMatrix(): the text matrix, then the 2x2.
	local := SkAffine{
		sx: size
		sy: size
	}
	a := if post.type_mask() == 0 { local } else { affine_set_concat(post, local) }
	skewed_or_flipped := a.kx != 0 || a.ky != 0 || a.sx < 0 || a.sy < 0
	mut ga := a
	if skewed_or_flipped {
		h := map_point_affine(a, Point{1, 0})
		s, c := givens_rotation(h.x, h.y)
		g := SkAffine{
			sx: c
			kx: -s
			ky: s
			sy: c
		}
		ga = affine_set_concat(g, a)
	}
	near_zero := f32(1) / f32(1 << 12)
	if f32(math.abs(ga.sx)) <= near_zero || f32(math.abs(ga.sy)) <= near_zero
		|| !affine_is_finite(ga) {
		return GlyphStrikeMatrices{
			text_size: 1
			remaining: SkAffine{
				sx: 0
				sy: 0
			}
		}
	}
	y_scale := f32(math.abs(ga.sy))
	mut remaining := SkAffine{}
	if !skewed_or_flipped && a.sx == a.sy {
		remaining = SkAffine{}
	} else if !skewed_or_flipped {
		remaining = SkAffine{
			sx: a.sx / y_scale
		}
	} else {
		inv := f32(1) / y_scale
		remaining = a
		if inv != 1 {
			remaining = SkAffine{
				...a
				sx: a.sx * inv
				ky: a.ky * inv
				kx: a.kx * inv
				sy: a.sy * inv
			}
		}
	}
	return GlyphStrikeMatrices{
		text_size:  y_scale
		remaining:  remaining
		invertible: true
	}
}

fn affine_is_finite(m SkAffine) bool {
	return is_finite_f32(m.sx) && is_finite_f32(m.kx) && is_finite_f32(m.tx) && is_finite_f32(m.ky)
		&& is_finite_f32(m.sy) && is_finite_f32(m.ty)
}

// StrikeGlyph is an SkGlyph of the strike: its saturated bounds and A8 image.
struct StrikeGlyph {
	left   int
	top    int
	width  int
	height int
	image  []u8
}

// GlyphStrike is an unhinted A8 SkScalerContext_Mac strike for one draw:
// CoreText's font at the text size, fTransform (MatrixToCGAffineTransform()
// of the remaining matrix) and the rec's pre-blend table.
struct GlyphStrike {
	font       voidptr
	transform  [6]f64
	invertible bool
	table      []u8
mut:
	// An ARGB32 strike of a color typeface, and its foreground color.
	color      bool
	foreground u32
	glyphs     map[u32]StrikeGlyph
}

fn new_glyph_strike(face GlyphFace, size f32, device SkAffine, luminance int) ?GlyphStrike {
	m := glyph_strike_matrices(size, device)
	if !m.invertible {
		// A singular matrix zeroes fTransform: every glyph is empty.
		return none
	}
	r := m.remaining
	font := face.exact_copy(f64(m.text_size)) or { return none }
	return GlyphStrike{
		font:       font
		transform:  [f64(r.sx), -f64(r.ky), -f64(r.kx), f64(r.sy), f64(r.tx), f64(r.ty)]!
		invertible: m.invertible
		table:      mask_gamma_tables[luminance]
	}
}

fn (mut s GlyphStrike) release() {
	if s.font != unsafe { nil } {
		release_glyph_font(s.font)
	}
}

fn (mut s GlyphStrike) glyph(id u16, sub_x int, sub_y int) StrikeGlyph {
	key := u32(id) << 4 | u32(sub_x) << 2 | u32(sub_y)
	if g := s.glyphs[key] {
		return g
	}
	g := s.make_glyph(id, sub_x, sub_y)
	s.glyphs[key] = g
	return g
}

// SkScalerContext::internalMakeGlyph() with SkScalerContext_Mac's
// generateMetrics() and generateImage().
fn (s &GlyphStrike) make_glyph(id u16, sub_x_field int, sub_y_field int) StrikeGlyph {
	g := s.glyph_bounds(id, sub_x_field, sub_y_field)
	if g.width == 0 || g.height == 0 || g.width >= glyph_max_width {
		return g
	}
	sub_x := f32(sub_x_field) / f32(4)
	sub_y := f32(sub_y_field) / f32(4)
	g_left, g_top, g_width, g_height := g.left, g.top, g.width, g.height
	// Offscreen::getCG(): the glyph drawn at its subpixel offset from the
	// bottom-left of a power-of-two context.
	context_width := next_pow2(g_width)
	context_height := next_pow2(g_height)
	x := f32(-g_left) + sub_x
	y := f32(g_top + g_height) - sub_y
	cg := draw_glyph(s.font, id, s.transform, s.invertible, f64(x), f64(y), context_width,
		context_height, g_width, g_height, s.color, s.foreground) or { return StrikeGlyph{} }
	first := (context_height - g_height) * context_width
	if s.color {
		// cgpixels_to_pmcolor(): SkPackARGB32() of the premultiplied pixel,
		// RGBA in memory.
		mut image := []u8{len: g_width * g_height * 4}
		for row in 0 .. g_height {
			for column in 0 .. g_width {
				p := cg[first + row * context_width + column]
				o := (row * g_width + column) * 4
				image[o] = u8(p >> 16)
				image[o + 1] = u8(p >> 8)
				image[o + 2] = u8(p)
				image[o + 3] = u8(p >> 24)
			}
		}
		return StrikeGlyph{g_left, g_top, g_width, g_height, image}
	}
	// RGBToA8<true>(): luminance of the inverted pixel through the table.
	mut image := []u8{len: g_width * g_height}
	for row in 0 .. g_height {
		for column in 0 .. g_width {
			p := cg[first + row * context_width + column]
			red := 255 - (p >> 16 & 0xff)
			green := 255 - (p >> 8 & 0xff)
			blue := 255 - (p & 0xff)
			image[row * g_width + column] = s.table[compute_luminance(red, green, blue)]
		}
	}
	return StrikeGlyph{g_left, g_top, g_width, g_height, image}
}

// generateMetrics()'s bounds, rounded out, outset and saturated; zero for
// an empty glyph.
fn (s &GlyphStrike) glyph_bounds(id u16, sub_x_field int, sub_y_field int) StrikeGlyph {
	metrics := glyph_metrics(s.font, id, s.transform) or { return StrikeGlyph{} }
	// SkFixedToFloat() of the subpixel field.
	sub_x := f32(sub_x_field) / f32(4)
	sub_y := f32(sub_y_field) / f32(4)
	bx := f32(metrics.x)
	by := f32(-metrics.y - metrics.height)
	bw := f32(metrics.width)
	bh := f32(metrics.height)
	mut right := bx + bw
	mut bottom := by + bh
	right += sub_x
	bottom += sub_y
	// roundOut(), the one-pixel outset, then SaturateGlyphBounds().
	left := i64(float_saturate2int(floor_f32(bx))) - 1
	top := i64(float_saturate2int(floor_f32(by))) - 1
	r := i64(float_saturate2int(ceil_f32(right))) + 1
	b := i64(float_saturate2int(ceil_f32(bottom))) + 1
	g_left := saturate_i16(left)
	g_top := saturate_i16(top)
	g_width := saturate_u16(r - left)
	g_height := saturate_u16(b - top)
	if g_width == 0 || g_height == 0 {
		return StrikeGlyph{}
	}
	return StrikeGlyph{g_left, g_top, g_width, g_height, []u8{}}
}

fn saturate_i16(v i64) int {
	return int(if v < -32768 {
		i64(-32768)
	} else if v > 32767 {
		i64(32767)
	} else {
		v
	})
}

fn saturate_u16(v i64) int {
	return int(if v < 0 {
		i64(0)
	} else if v > 65535 {
		i64(65535)
	} else {
		v
	})
}

// SkNextPow2().
fn next_pow2(v int) int {
	mut p := 1
	for p < v {
		p <<= 1
	}
	return p
}
