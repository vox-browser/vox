module cpuraster

// vox_skia_canvas_path()'s bitmap commands (skia/canvas_raster.cpp's
// draw_canvas_command() operations 1 and 2): clearRect() as a hard rect
// clip and SkCanvas::clear(), and drawImage().

// SkScan::FillIRect(): blitRect() of the rect within a hard clip's rect, or
// within an anti-aliased clip's bounds through its SkAAClipBlitterWrapper.
fn fill_irect(r IRect, rc &RasterClip, mut blitter Blitter) {
	if rc.is_empty || r.is_empty() {
		return
	}
	bounds := rc.bounds()
	rect := if bounds.contains(r) { r } else { bounds.intersect(r) or { return } }
	if rc.is_bw {
		blitter.blit_rect(rect.left, rect.top, rect.width(), rect.height())
		return
	}
	mut wrapper := new_aaclip_blitter(blitter, &rc.aa)
	wrapper.blit_rect(rect.left, rect.top, rect.width(), rect.height())
}

// SkRect::makeSorted().
fn make_sorted(r Rect) Rect {
	return Rect{fmin_std(r.left, r.right), fmin_std(r.top, r.bottom), fmax_std(r.left, r.right), fmax_std(r.top,
		r.bottom)}
}

// SkRect::MakeXYWH() of a command's destination or source.
fn rect_xywh(v [4]f32) Rect {
	return Rect{v[0], v[1], v[0] + v[2], v[1] + v[3]}
}

fn rect_is_finite(r Rect) bool {
	return is_finite_f32(r.left) && is_finite_f32(r.top) && is_finite_f32(r.right)
		&& is_finite_f32(r.bottom)
}

fn canvas_affine(transform [6]f32) SkAffine {
	return SkAffine{
		sx: transform[0]
		ky: transform[1]
		kx: transform[2]
		sy: transform[3]
		tx: transform[4]
		ty: transform[5]
	}
}

// clear_canvas_rect is operation 1: under the clip paths and transform,
// clipRect(destination) without anti-aliasing, then clear(color), which is
// drawColor(color, kSrc) over the device. color is an SkColor. A transform
// that is not a scale and translation clips with the rect's path, filled
// into a region by SkScan::FillPath. The call returns false without
// changing pixels for devices Skia would tile.
pub fn clear_canvas_rect(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, destination [4]f32, color u32, clips []Path) bool {
	if !untiled_device(pixels, width, height, pitch) {
		return false
	}
	ctm := canvas_affine(transform)
	mask := ctm.type_mask()
	local := rect_xywh(destination)
	// SkCanvas::clipRect() ignores a rect that is not finite.
	finite := rect_is_finite(local)
	mut rc := canvas_raster_clip(width, height, clips)
	path_clip := finite && mask & affine_affine_mask != 0
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	mut region := ?[]IRect(none)
	if path_clip {
		// SkRasterClip::op(path): SkRegion::setPath() within the clip's
		// bounds; an anti-aliased clip intersects SkAAClip::setRegion() of it.
		mut collector := SpanCollector{}
		if !rc.is_empty {
			matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
			device := rect_path(make_sorted(local)).transform(matrix)
			fill_path_region(device, device.convexity() != .concave, rc.bounds(), mut collector)
		}
		if rc.is_bw {
			region = collector.spans
		} else {
			mut region_clip := AAClip{}
			region_clip.set_spans(collector.spans)
			rc.aa.op_clip(&region_clip)
			rc.update_cache(true)
		}
	} else if finite {
		dev := InverseMatrix{ctm, mask}.map_rect(make_sorted(local))
		rc.op_device_rect(dev, false)
	}
	target.ready()
	// SkCanvas::internalDrawPaint() skips an empty clip.
	if rc.is_empty {
		return true
	}
	mut blitter := canvas_blitter(mut pixels, pitch, color, f32(color >> 24) * inv_255, .src) or {
		return true
	}
	if spans := region {
		// SkScan::FillIRect() through the region's rects.
		for span in spans {
			blitter.blit_h(span.left, span.top, span.width())
		}
		return true
	}
	fill_irect(IRect{0, 0, width, height}, &rc, mut blitter)
	return true
}

// SkMatrix::Rect2Rect() with kFill_ScaleToFit: none for an empty src.
fn rect_to_rect(src Rect, dst Rect) ?SkAffine {
	if rect_is_empty(src) {
		return none
	}
	sx := (dst.right - dst.left) / (src.right - src.left)
	sy := (dst.bottom - dst.top) / (src.bottom - src.top)
	lx := src.left * sx
	ly := src.top * sy
	return SkAffine{
		sx: sx
		sy: sy
		tx: dst.left - lx
		ty: dst.top - ly
	}
}

// SkMatrix::preTranslate() for an affine matrix.
fn pre_translate(m SkAffine, dx f32, dy f32) SkAffine {
	if m.type_mask() <= affine_translate_mask {
		return SkAffine{
			...m
			tx: m.tx + dx
			ty: m.ty + dy
		}
	}
	xa := m.sx * dx
	xb := m.kx * dy
	ya := m.ky * dx
	yb := m.sy * dy
	return SkAffine{
		...m
		tx: m.tx + (xa + xb)
		ty: m.ty + (ya + yb)
	}
}

// SkMatrix's kRectStaysRect_Mask.
fn rect_stays_rect(m SkAffine) bool {
	if m.kx != 0 || m.ky != 0 {
		return m.sx == 0 && m.sy == 0 && m.kx != 0 && m.ky != 0
	}
	return m.sx != 0 && m.sy != 0
}

// SkRect::intersect().
fn rect_intersect(a Rect, b Rect) ?Rect {
	l := if a.left > b.left { a.left } else { b.left }
	t := if a.top > b.top { a.top } else { b.top }
	r := if a.right < b.right { a.right } else { b.right }
	bt := if a.bottom < b.bottom { a.bottom } else { b.bottom }
	if !(l < r && t < bt) {
		return none
	}
	return Rect{l, t, r, bt}
}

// SkMatrix::mapPoints() of a rect's two corners, then SkRect::sort().
fn map_rect_corners(m SkAffine, r Rect) Rect {
	lt := m.map(Point{r.left, r.top})
	rb := m.map(Point{r.right, r.bottom})
	return Rect{fmin_std(lt.x, rb.x), fmin_std(lt.y, rb.y), fmax_std(lt.x, rb.x), fmax_std(lt.y,
		rb.y)}
}

// SkTreatAsSprite() without anti-aliasing: a translation (integral for
// linear sampling), or a positive scale and translation whose mapped bounds
// round to the translated bounds.
fn treat_as_sprite(m SkAffine, width int, height int, linear bool) bool {
	mask := m.type_mask()
	if mask & affine_affine_mask != 0 {
		return false
	}
	if linear && (!int_cast_preserves(m.tx) || !int_cast_preserves(m.ty)) {
		return false
	}
	if mask & ~affine_translate_mask == 0 {
		return true
	}
	if m.sx < 0 || m.sy < 0 {
		return false
	}
	dst := InverseMatrix{m, mask}.map_rect(Rect{0, 0, f32(width), f32(height)})
	ix := int(saturate_to_i32(floor_f32(m.tx + f32(0.5))))
	iy := int(saturate_to_i32(floor_f32(m.ty + f32(0.5))))
	return IRect{ix, iy, ix + width, iy + height} == round_rect(dst)
}

// SkSpriteBlitter_Memcpy and Sprite_D32_S32: rows of the source at
// (left, top), copied or blended with blit_row_s32a_opaque/blend.
struct SpriteBlitter {
	source    CanvasBitmap
	left      int
	top       int
	row_bytes int
	copy      bool
	alpha     u32
mut:
	pixels []u8
	span   []u32
}

fn (mut b SpriteBlitter) blit_rect(x int, y int, width int, height int) {
	if b.span.len < width {
		b.span = []u32{len: width}
	}
	for row in 0 .. height {
		dst := (y + row) * b.row_bytes + x * 4
		src := (y + row - b.top) * b.source.pitch + (x - b.left) * 4
		if b.copy {
			for i in 0 .. width * 4 {
				b.pixels[dst + i] = b.source.pixels[src + i]
			}
			continue
		}
		for i in 0 .. width {
			b.span[i] = load32(b.source.pixels, src + i * 4)
		}
		blit_row_s32a(mut b.pixels, dst, b.span, width, b.alpha)
	}
}

// SkSpriteBlitter's fallbacks: spans as one-row rects; anti-aliased runs
// draw nothing.
fn (mut b SpriteBlitter) blit_h(x int, y int, width int) {
	b.blit_rect(x, y, width, 1)
}

fn (mut b SpriteBlitter) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {}

fn (mut b SpriteBlitter) blit_v(x int, y int, height int, alpha u8) {
	if alpha == 255 {
		b.blit_rect(x, y, 1, height)
	}
}

fn (mut b SpriteBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

fn (mut b SpriteBlitter) blit_mask(mask &Mask, clip IRect) {}

fn (mut b SpriteBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {}

fn (mut b SpriteBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {}

// SkBlitter::ChooseSprite() for source at (left, top): none for an
// unpremultiplied source; Memcpy for Src at full alpha and Sprite_D32_S32
// for source-over in sRGB; otherwise SkRasterPipelineSpriteBlitter, whose
// load_8888, color space steps and scale_1_float are the image shader's
// nearest sampling at that offset, scaled by the paint's float alpha.
fn choose_sprite(mut pixels []u8, row_bytes int, source CanvasBitmap, left int, top int, alpha_byte int, paint_alpha f32, mode BlendMode) ?Blitter {
	if !source.premultiplied {
		return none
	}
	if !source.display_p3 {
		if mode == .src && alpha_byte == 255 {
			return SpriteBlitter{
				source:    source
				left:      left
				top:       top
				row_bytes: row_bytes
				copy:      true
				pixels:    pixels
			}
		}
		if mode == .src_over {
			return SpriteBlitter{
				source:    source
				left:      left
				top:       top
				row_bytes: row_bytes
				alpha:     u32(alpha_byte)
				pixels:    pixels
			}
		}
	}
	if mode == .clear {
		// The clear stage stores transparent black, as Src of it does.
		return canvas_blitter(mut pixels, row_bytes, 0, 0, .clear)
	}
	shader := new_image_shader(source, .clamp, .clamp, false, affine_translate(f32(left),
		f32(top)))
	return new_image_blitter(mut pixels, row_bytes, shader.image, paint_alpha, mode)
}

// draw_canvas_image is operation 2, drawImage(): the paint carries the blend
// mode and the global alpha truncated to a byte, and
// SkCanvas::drawImageRect() draws image's source rect into the destination
// rect with the kStrict_SrcRectConstraint, sampling linearly when smoothing
// (strict drops the mipmaps) and nearest otherwise. Through
// SkBitmapDevice::drawImageRect(): the source clipped to the image, a
// subset extracted for a source inside it, then Draw::drawBitmap()'s sprite
// blitters, or a clamped image shader through Draw::drawRect() and
// SkScan::FillRect(), or Draw::drawPath() of the rect under a transform that
// does not keep rects rects or outside the 16.16 range. It returns false
// without changing pixels for devices Skia would tile and images it cannot
// install.
pub fn draw_canvas_image(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path) bool {
	return draw_canvas_image_sampled(mut pixels, width, height, pitch, alpha_type, transform, image, source, destination, smoothing, global_alpha, mode, clips, false)
}

fn draw_canvas_image_sampled(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, mipmap bool) bool {
	if !untiled_device(pixels, width, height, pitch) || !image.installs() {
		return false
	}
	ctm := canvas_affine(transform)
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	// paint.setAlpha(static_cast<uint8_t>(global_alpha * 255)).
	scaled_alpha := global_alpha * f32(255)
	alpha_byte := int(u8(scaled_alpha))
	paint_alpha := f32(alpha_byte) * inv_255
	src := rect_xywh(source)
	dst := rect_xywh(destination)
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	// SkCanvas::drawImageRect(): fillable() rects, then internalQuickReject().
	if !rect_is_finite(dst) || rect_is_empty(dst) || !rect_is_finite(src) || rect_is_empty(src)
		|| blend_draws_nothing(mode, alpha_byte) {
		return target.ready()
	}
	rc := canvas_raster_clip(width, height, clips)
	if canvas_quick_reject(dst, matrix, &rc) {
		return target.ready()
	}
	// SkBitmapDevice::drawImageRect().
	bounds := Rect{0, 0, f32(image.width), f32(image.height)}
	mut tmp_src := src
	mut m := rect_to_rect(src, dst) or { SkAffine{} }
	mut dst_rect := dst
	if !rect_contains_rect(bounds, src) {
		tmp_src = rect_intersect(src, bounds) or { return target.ready() }
		dst_rect = InverseMatrix{m, m.type_mask()}.map_rect(tmp_src)
		if !rect_is_finite(dst_rect) {
			return target.ready()
		}
	}
	src_is_subset := !rect_contains_rect(tmp_src, bounds)
	mut bitmap := image
	mut draw_bitmap := !src_is_subset
	if src_is_subset {
		// SkBitmap::extractSubset() of the rounded-out source.
		ir := round_out(tmp_src)
		bitmap = CanvasBitmap{
			...image
			pixels: image.pixels[ir.top * image.pitch + ir.left * 4..]
			width:  ir.width()
			height: ir.height()
		}
		dx := if ir.left > 0 { f32(ir.left) } else { f32(0) }
		dy := if ir.top > 0 { f32(ir.top) } else { f32(0) }
		if dx != 0 || dy != 0 {
			m = pre_translate(m, dx, dy)
		}
		draw_bitmap = Rect{0, 0, f32(bitmap.width), f32(bitmap.height)} == tmp_src
	}
	linear := smoothing
	total := sk_concat(ctm, m)
	// Draw::drawBitmap() and Draw::drawRect() draw nothing in an empty clip.
	if rc.is_empty {
		return target.ready()
	}
	if draw_bitmap {
		// Draw::drawBitmap(): clipped_out(), then the sprite blitters.
		mapped := InverseMatrix{total, total.type_mask()}.map_rect(Rect{0, 0, f32(bitmap.width), f32(bitmap.height)})
		if !irect_intersects(rc.bounds(), round_out(mapped)) {
			return target.ready()
		}
		if treat_as_sprite(total, bitmap.width, bitmap.height, linear) {
			ix := int(saturate_to_i32(floor_f32(total.tx + f32(0.5))))
			iy := int(saturate_to_i32(floor_f32(total.ty + f32(0.5))))
			if rc.is_bw || rc.aa.quick_contains(ix, iy, ix + bitmap.width, iy + bitmap.height) {
				if mut sprite := choose_sprite(mut pixels, pitch, bitmap, ix, iy, alpha_byte,
					paint_alpha, mode)
				{
					target.ready()
					fill_irect(IRect{ix, iy, ix + bitmap.width, iy + bitmap.height}, &rc, mut
						sprite)
					return true
				}
			}
		}
	}
	// Draw::drawRect() of the destination with the clamped image shader:
	// a fill under a CTM that keeps rects rects, unless the destination
	// leaves the 16.16 range; otherwise draw_rect_as_path().
	shader := if mipmap { new_mipmap_image_shader(bitmap, .clamp, .clamp, linear, total) }
		else { new_image_shader(bitmap, .clamp, .clamp, linear, total) }
	if rect_stays_rect(ctm) {
		dev := map_rect_corners(ctm, dst_rect)
		if too_big_for_math(dev) {
			return target.ready()
		}
		mut fits := true
		for v in [dev.left, dev.top, dev.right, dev.bottom] {
			magnitude := if v < 0 { -v } else { v }
			if !(magnitude <= 32767) {
				fits = false
			}
		}
		if fits {
			target.ready()
			if !irect_intersects(rc.bounds(), round_out(dev)) {
				return true
			}
			mut blitter := canvas_paint_blitter(mut pixels, pitch, 0xff000000, shader, paint_alpha,
				mode, dev) or { return true }
			// SkScan::FillRect(): an empty rect draws nothing; others are
			// rounded.
			if rect_is_empty(dev) {
				return true
			}
			fill_irect(round_rect(dev), &rc, mut blitter)
			return true
		}
	}
	// draw_rect_as_path(): Draw::drawPath() of the rect, the bitmap's bounds
	// under the total matrix or the destination under the CTM, filled
	// without anti-aliasing.
	device := if draw_bitmap {
		rect_path(Rect{0, 0, f32(bitmap.width), f32(bitmap.height)}).transform(affine_to_matrix(total))
	} else {
		rect_path(dst_rect).transform(matrix)
	}
	target.ready()
	device_bounds := device.bounds() or { return true }
	if too_big_for_math(device_bounds) {
		return true
	}
	mut blitter := canvas_paint_blitter(mut pixels, pitch, 0xff000000, shader, paint_alpha, mode,
		device_bounds) or { return true }
	return fill_path_clip(device, false, &rc, mut blitter)
}

// SkIRect::Intersects().
fn irect_intersects(a IRect, b IRect) bool {
	l := if a.left > b.left { a.left } else { b.left }
	t := if a.top > b.top { a.top } else { b.top }
	r := if a.right < b.right { a.right } else { b.right }
	bt := if a.bottom < b.bottom { a.bottom } else { b.bottom }
	return l < r && t < bt
}
