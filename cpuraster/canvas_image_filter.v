module cpuraster

// The pixel-aligned MakeFromImage route: the original image subset remains
// deferred through the paint alpha and color filters until the final blend.
// General transforms and image-filter source resampling are separate routes.
fn draw_translated_color_filtered_image(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, global_alpha f32, mode BlendMode, clips []Path, filter ColorFilter) bool {
	src := rect_xywh(source)
	dst := rect_xywh(destination)
	ctm := canvas_affine(transform)
	if ctm.sx != 1 || ctm.sy != 1 || ctm.kx != 0 || ctm.ky != 0
		|| !transform[..].all(int_cast_preserves(it))
		|| !source[..].all(int_cast_preserves(it)) || !destination[..].all(int_cast_preserves(it))
		|| source[2] != destination[2] || source[3] != destination[3]
		|| !rect_contains_rect(Rect{0, 0, f32(image.width), f32(image.height)}, src) {
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
	x := dst.left + ctm.tx
	y := dst.top + ctm.ty
	bounds := IRect{int(x), int(y), int(x) + bitmap.width, int(y) + bitmap.height}
	unbounded := blend_affects_transparent_black(mode) && !bounds.contains(rc.bounds())
	shader := new_image_shader(bitmap, if unbounded { TileMode.decal } else { .clamp },
		if unbounded { TileMode.decal } else { .clamp }, false, affine_translate(x, y))
	alpha := f32(u8(global_alpha * f32(255))) * inv_255
	mut blitter := canvas_filtered_blitter(mut pixels, pitch, 0xff000000, shader, alpha, mode,
		Rect{f32(bounds.left), f32(bounds.top), f32(bounds.right), f32(bounds.bottom)}, filter,
		canvas_rgba_uses_legacy()) or { return target.ready() }
	target.ready()
	fill_irect(if unbounded { rc.bounds() } else { bounds }, &rc, mut blitter)
	return true
}
