module cpuraster

// rescale(scale=1) can take a raw subset at the rounded image origin when
// the transform is nearly integer and no pending effects need resolution.
// In particular, unpremultiplied sRGB storage is not premultiplied here.
fn draw_near_integer_image_blur(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, bitmap CanvasBitmap, src Rect, dst Rect, mapped SkAffine, total SkAffine, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	ctm := canvas_affine(transform)
	image_bounds := IRect{0, 0, bitmap.width, bitmap.height}
	layer_bounds := map_filter_bounds(IRect{int(src.left), int(src.top), int(src.right), int(src.bottom)}, mapped)
	// A rounding-induced layer crop can force resampling. Keep that uncommon
	// case on the existing fallback until its desired-output analysis is ported.
	if !layer_bounds.contains(map_filter_bounds(image_bounds, total)) { return false }
	x, y := floor_f32(total.tx + f32(.5)), floor_f32(total.ty + f32(.5))
	snapped := IRect{int(x), int(y), int(x) + bitmap.width, int(y) + bitmap.height}
	tight := layer_bounds.intersect(snapped) or { return false }
	inverse := affine_invert(ctm) or { return false }
	bounds := InverseMatrix{inverse, inverse.type_mask()}.map_rect(
		Rect{f32(tight.left), f32(tight.top), f32(tight.right), f32(tight.bottom)})
	fast := step.source_draw_bounds or { dst }
	raw := CanvasBitmap{...bitmap, premultiplied: true, display_p3: false}
	prepared := CanvasFilterStep{...step, source_image: true, source_padding: false,
		source_draw_bounds: fast, source_color_info: FilterImageInfo{premultiplied: bitmap.premultiplied}}
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
		transform, clips, bounds, prepared, mode,
		fn [raw, ctm, x, y] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
			left := floor_f32(ctm.tx - t[4] + f32(.5))
			top := floor_f32(ctm.ty - t[5] + f32(.5))
			ix, iy := int(x - left), int(y - top)
			shader := new_image_shader(raw, .clamp, .clamp, false,
				affine_translate(f32(ix), f32(iy)))
			mut blitter := new_image_blitter(mut layer, w * 4, shader.image, 1, .src)
			rc := canvas_raster_clip(w, h, inner_clips)
			fill_irect(IRect{ix, iy, ix + raw.width, iy + raw.height}, &rc, mut blitter)
			return true
		}, none)
}
