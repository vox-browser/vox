module cpuraster

// MakeFromImage retains an integer-aligned source subset and defers its
// transform, paint alpha and color filters until the final image draw.
fn draw_color_filtered_image(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, filter ColorFilter) bool {
	mut src := rect_xywh(source)
	mut dst := rect_xywh(destination)
	ctm := canvas_affine(transform)
	if !transform[..].all(is_finite_f32(it)) || !source[..].all(int_cast_preserves(it))
		|| !rect_is_finite(src) || !rect_is_finite(dst) {
		return false
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	if rect_is_empty(src) || rect_is_empty(dst) { return target.ready() }
	rc := canvas_raster_clip(width, height, clips)
	if canvas_quick_reject(dst, affine_to_matrix(ctm), &rc) { return target.ready() }
	affine_invert(ctm) or { return target.ready() }
	image_bounds := Rect{0, 0, f32(image.width), f32(image.height)}
	if !rect_contains_rect(image_bounds, src) {
		// MakeFromImage clips the source first and maps the smaller source
		// through the original src-to-dst matrix before constructing SkM44.
		original := rect_to_rect(src, dst) or { return target.ready() }
		src = rect_intersect(src, image_bounds) or {
			target.ready()
			draw_empty_filter_result(mut pixels, pitch, &rc, mode)
			return true
		}
		dst = InverseMatrix{original, original.type_mask()}.map_rect(src)
	}
	local := rect_to_rect(src, dst) or { SkAffine{} }
	// MakeFromImage concatenates SkM44 matrices before storing an SkMatrix;
	// its column dot products associate from the right in float precision.
	mapped := m44_image_concat(ctm, local)
	mut total := sk_concat(mapped, affine_translate(src.left, src.top))
	pixel_aligned := total.type_mask() <= affine_translate_mask
		&& int_cast_preserves(total.tx) && int_cast_preserves(total.ty)
	left := int(src.left)
	top := int(src.top)
	bitmap := CanvasBitmap{
		...image
		pixels: image.pixels[top * image.pitch + left * 4..]
		width: int(src.right - src.left)
		height: int(src.bottom - src.top)
	}
	ix := int(saturate_to_i32(floor_f32(total.tx + f32(.5))))
	iy := int(saturate_to_i32(floor_f32(total.ty + f32(.5))))
	sprite := !blend_affects_transparent_black(mode) && bitmap.premultiplied
		&& treat_as_aa_sprite(total, bitmap.width, bitmap.height)
		&& (!smoothing || pixel_aligned)
		&& (rc.is_bw || rc.aa.quick_contains(ix, iy, ix + bitmap.width, iy + bitmap.height))
	if sprite {
		total = affine_translate(floor_f32(total.tx + f32(.5)), floor_f32(total.ty + f32(.5)))
	}
	dev := InverseMatrix{total, total.type_mask()}.map_rect(Rect{0, 0, f32(bitmap.width), f32(bitmap.height)})
	bounds := round_out(dev)
	// A clearing blender samples outside the transformed image through a
	// decal shader. Its destination is the clip, including rotated corners.
	unbounded := blend_affects_transparent_black(mode)
	min_scale, max_scale := image_filter_minmax_scales(total)
	layer_decal := unbounded && smoothing && !pixel_aligned
		&& (math_abs32(min_scale - 1) > f32(.2) || math_abs32(max_scale - 1) > f32(.2))
	mut pre_decal := total
	mut decal_inverse := SkAffine{}
	mut decal_bounds := dev
	if layer_decal && !rect_stays_rect(total) {
		// Factor the column scales out of the transform. The runtime effect
		// evaluates the decal after the scale and before the remaining affine
		// transform, so both matrix stages keep their separate float rounding.
		sx := point_length(total.sx, total.ky)
		sy := point_length(total.kx, total.sy)
		if nearly_zero(sx, scalar_nearly_zero) || nearly_zero(sy, scalar_nearly_zero) { return false }
		ox, oy := f32(1)/sx, f32(1)/sy
		post := SkAffine{sx: total.sx * ox, ky: total.ky * ox,
			kx: total.kx * oy, sy: total.sy * oy, tx: total.tx, ty: total.ty}
		decal_inverse = affine_invert(post) or { return false }
		pre_decal = affine_scale(sx, sy)
		decal_bounds = Rect{0, 0, f32(bitmap.width) * sx, f32(bitmap.height) * sy}
	}
	tile := if unbounded && !layer_decal { TileMode.decal } else { .clamp }
	// A runtime decal effect samples its child with an invalid total-matrix
	// record. SkImageShader therefore keeps the base mip level for that child.
	mut shader := if smoothing && !pixel_aligned { new_linear_mipmap_image_shader(bitmap, tile, tile, pre_decal, !layer_decal) }
		else { new_image_shader(bitmap, tile, tile, false, total) }
	if layer_decal {
		shader = CanvasShader{...shader, image: ImageShader{...shader.image, layer_decal: true,
			decal_bounds: decal_bounds, decal_matrix: decal_inverse}}
	}
	alpha := f32(u8(global_alpha * f32(255))) * inv_255
	mut blitter := canvas_filtered_blitter(mut pixels, pitch, 0xff000000, shader, alpha, mode,
		Rect{f32(bounds.left), f32(bounds.top), f32(bounds.right), f32(bounds.bottom)}, filter,
		canvas_rgba_uses_legacy()) or { return target.ready() }
	target.ready()
	if unbounded || sprite {
		fill_irect(if unbounded { rc.bounds() } else { bounds }, &rc, mut blitter)
		return true
	}
	if rect_stays_rect(total) {
		anti_fill_rect(dev, &rc, mut blitter)
		return true
	}
	device := rect_path(Rect{0, 0, f32(bitmap.width), f32(bitmap.height)}).transform(affine_to_matrix(total))
	return anti_fill_path_clip(device, false, &rc, mut blitter)
}

// SkMatrix::getMinMaxScales(): singular values of the affine 2x2 matrix.
fn image_filter_minmax_scales(m SkAffine) (f32, f32) {
	if m.type_mask() & affine_affine_mask == 0 {
		return fmin_std(math_abs32(m.sx), math_abs32(m.sy)), fmax_std(math_abs32(m.sx), math_abs32(m.sy))
	}
	a0, a1 := m.sx * m.sx, m.ky * m.ky
	b0, b1 := m.sx * m.kx, m.sy * m.ky
	c0, c1 := m.kx * m.kx, m.sy * m.sy
	a, b, c := a0 + a1, b0 + b1, c0 + c1
	b_squared := b * b
	mut lo, mut hi := a, c
	if b_squared <= scalar_nearly_zero * scalar_nearly_zero {
		lo, hi = fmin_std(a, c), fmax_std(a, c)
	} else {
		difference := a - c
		mean := (a + c) * f32(.5)
		squared := difference * difference
		four_b := f32(4) * b_squared
		radius := C.sqrtf(squared + four_b) * f32(.5)
		lo, hi = mean - radius, mean + radius
	}
	return C.sqrtf(fmax_std(lo, 0)), C.sqrtf(fmax_std(hi, 0))
}

fn m44_image_concat(a SkAffine, b SkAffine) SkAffine {
	combine := fn (x f32, bx f32, y f32, by f32, t f32, w f32) f32 {
		p0 := x * bx
		p1 := y * by
		p3 := t * w
		inner := p1 + (f32(0) + p3)
		return p0 + inner
	}
	return SkAffine{
		sx: combine(a.sx, b.sx, a.kx, b.ky, a.tx, 0)
		ky: combine(a.ky, b.sx, a.sy, b.ky, a.ty, 0)
		kx: combine(a.sx, b.kx, a.kx, b.sy, a.tx, 0)
		sy: combine(a.ky, b.kx, a.sy, b.sy, a.ty, 0)
		tx: combine(a.sx, b.tx, a.kx, b.ty, a.tx, 1)
		ty: combine(a.ky, b.tx, a.sy, b.ty, a.ty, 1)
	}
}

// SkTreatAsSprite with the image-filter restore paint's AA flag: compare
// mapped edges with the integer sprite at four subpixel bits.
fn treat_as_aa_sprite(m SkAffine, width int, height int) bool {
	if m.type_mask() & affine_affine_mask != 0 || m.sx < 0 || m.sy < 0 { return false }
	dst := InverseMatrix{m, m.type_mask()}.map_rect(Rect{0, 0, f32(width), f32(height)})
	x := int(saturate_to_i32(floor_f32(m.tx + f32(.5))))
	y := int(saturate_to_i32(floor_f32(m.ty + f32(.5))))
	return IRect{x * 16, y * 16, (x + width) * 16, (y + height) * 16}
		== round_rect(Rect{dst.left * 16, dst.top * 16, dst.right * 16, dst.bottom * 16})
}
