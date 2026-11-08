module cpuraster

// MakeFromImage retains an integer-aligned source subset and defers its
// transform, paint alpha and color filters until the final image draw.
fn draw_color_filtered_image(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, filter ColorFilter) bool {
	src := rect_xywh(source)
	dst := rect_xywh(destination)
	ctm := canvas_affine(transform)
	if !transform[..].all(is_finite_f32(it)) || !source[..].all(int_cast_preserves(it))
		|| !rect_is_finite(dst)
		|| !rect_contains_rect(Rect{0, 0, f32(image.width), f32(image.height)}, src) {
		return false
	}
	local := rect_to_rect(src, dst) or { SkAffine{} }
	// MakeFromImage concatenates SkM44 matrices before storing an SkMatrix;
	// its column dot products associate from the right in float precision.
	mapped := m44_image_concat(ctm, local)
	mut total := sk_concat(mapped, affine_translate(src.left, src.top))
	pixel_aligned := total.type_mask() <= affine_translate_mask
		&& int_cast_preserves(total.tx) && int_cast_preserves(total.ty)
	if smoothing && !pixel_aligned && blend_affects_transparent_black(mode) && !rect_stays_rect(total) {
		// Rotated layer-space decal edges require transform decomposition.
		return false
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	if rect_is_empty(src) || rect_is_empty(dst) { return target.ready() }
	rc := canvas_raster_clip(width, height, clips)
	if canvas_quick_reject(dst, affine_to_matrix(ctm), &rc) { return target.ready() }
	left := int(src.left)
	top := int(src.top)
	bitmap := CanvasBitmap{
		...image
		pixels: image.pixels[top * image.pitch + left * 4..]
		width: int(source[2])
		height: int(source[3])
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
	x_scale := if total.sx != 0 { math_abs32(total.sx) } else { math_abs32(total.ky) }
	y_scale := if total.sy != 0 { math_abs32(total.sy) } else { math_abs32(total.kx) }
	layer_decal := unbounded && smoothing && !pixel_aligned
		&& (math_abs32(x_scale - 1) > f32(.2) || math_abs32(y_scale - 1) > f32(.2))
	tile := if unbounded && !layer_decal { TileMode.decal } else { .clamp }
	// A runtime decal effect samples its child with an invalid total-matrix
	// record. SkImageShader therefore keeps the base mip level for that child.
	mut shader := if smoothing && !pixel_aligned { new_linear_mipmap_image_shader(bitmap, tile, tile, total, !layer_decal) }
		else { new_image_shader(bitmap, tile, tile, false, total) }
	if layer_decal {
		shader = CanvasShader{...shader, image: ImageShader{...shader.image, layer_decal: true, decal_bounds: dev}}
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
