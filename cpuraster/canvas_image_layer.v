module cpuraster

// MakeFromImage can use a pixel-aligned subset directly. Copy its raw
// channels at the integer origin and retain alpha type and color space
// until a filter or restore needs to convert them. Fractional subsets use
// MakeFromImage's AA surface; other mappings need deferred sampling state.
fn draw_source_image_filter(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	ctm := canvas_affine(transform)
	src, dst := rect_xywh(source), rect_xywh(destination)
	if !is_finite_f32(global_alpha) || global_alpha < 0 || global_alpha > 1
		|| !affine_is_finite(ctm) || !rect_is_finite(src) || !rect_is_finite(dst)
		|| rect_is_empty(src) || rect_is_empty(dst)
		|| !rect_contains_rect(Rect{0, 0, f32(image.width), f32(image.height)}, src) { return false }
	paint_alpha := f32(u8(global_alpha * f32(255))) * inv_255
	if !source[..].all(int_cast_preserves(it)) {
		// Fractional subsets are first drawn into an AA, premultiplied sRGB
		// surface by MakeFromImage. The filter graph then consumes that image.
		if ctm.kx != 0 || ctm.ky != 0 { return false }
		return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
			transform, clips, dst, CanvasFilterStep{...step, source_image: true, source_padding: true,
				source_color_info: FilterImageInfo{alpha: paint_alpha}}, mode,
			fn [image, source, destination, smoothing] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
				return draw_canvas_image_sampled_aa(mut layer, w, h, w * 4, 2, t, image,
					source, destination, smoothing, 1, .src_over, inner_clips, false, true, true)
			}, none)
	}
	if ctm.type_mask() > affine_translate_mask || !int_cast_preserves(ctm.tx) || !int_cast_preserves(ctm.ty)
		|| !destination[..].all(int_cast_preserves(it)) || source[2] != destination[2]
		|| source[3] != destination[3] { return false }
	raw := CanvasBitmap{...image, premultiplied: true, display_p3: false}
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
		transform, clips, dst, CanvasFilterStep{...step, source_image: true,
			source_color_info: FilterImageInfo{premultiplied: image.premultiplied,
				display_p3: image.display_p3, alpha: paint_alpha}}, mode,
		fn [raw, source, destination, smoothing] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
			return draw_canvas_image_sampled(mut layer, w, h, w * 4, 2, t, raw,
				source, destination, smoothing, 1, .src_over, inner_clips, false, true)
		}, none)
}
