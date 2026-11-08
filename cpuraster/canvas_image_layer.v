module cpuraster

// MakeFromImage can use a pixel-aligned subset directly. Copy its raw
// channels at the integer origin and retain alpha type and color space
// until a filter or restore needs to convert them. Non-integral transforms
// and paint alpha require additional deferred sampling/filter state.
fn draw_aligned_image_filter(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	ctm := canvas_affine(transform)
	src, dst := rect_xywh(source), rect_xywh(destination)
	if global_alpha != 1
		|| ctm.type_mask() > affine_translate_mask || !int_cast_preserves(ctm.tx) || !int_cast_preserves(ctm.ty)
		|| !source[..].all(int_cast_preserves(it)) || !destination[..].all(int_cast_preserves(it))
		|| source[2] != destination[2] || source[3] != destination[3]
		|| rect_is_empty(src) || rect_is_empty(dst)
		|| !rect_contains_rect(Rect{0, 0, f32(image.width), f32(image.height)}, src) { return false }
	raw := CanvasBitmap{...image, premultiplied: true, display_p3: false}
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
		transform, clips, dst, CanvasFilterStep{...step, source_image: true,
			source_color_info: FilterImageInfo{image.premultiplied, image.display_p3}}, mode,
		fn [raw, source, destination, smoothing] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
			return draw_canvas_image_sampled(mut layer, w, h, w * 4, 2, t, raw,
				source, destination, smoothing, 1, .src_over, inner_clips, false, true)
		}, none)
}
