module cpuraster

// MakeFromImage can use a pixel-aligned subset directly. Copy its raw
// channels at the integer origin and retain alpha type and color space
// until a filter or restore needs to convert them. Fractional subsets use
// MakeFromImage's AA surface; real blurs resolve other supported mappings.
fn draw_source_image_filter(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, source [4]f32, destination [4]f32, smoothing bool, global_alpha f32, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	ctm := canvas_affine(transform)
	mut src, mut dst := rect_xywh(source), rect_xywh(destination)
	if !is_finite_f32(global_alpha) || global_alpha < 0 || global_alpha > 1
		|| !affine_is_finite(ctm) || !rect_is_finite(src) || !rect_is_finite(dst)
		|| rect_is_empty(src) || rect_is_empty(dst) { return false }
	mut prepared := step
	mut sample_source, mut sample_destination := source, destination
	image_bounds := Rect{0, 0, f32(image.width), f32(image.height)}
	if !rect_contains_rect(image_bounds, src) {
		// Canvas quick rejection uses the original draw bounds. MakeFromImage
		// subsequently clips its source and maps that subset through the
		// original source-to-destination matrix before constructing SkM44.
		prepared = CanvasFilterStep{...step, source_draw_bounds: dst}
		original := rect_to_rect(src, dst) or { return false }
		src = rect_intersect(src, image_bounds) or {
			return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
				transform, clips, dst, prepared, mode,
				fn (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool { return true }, none)
		}
		dst = InverseMatrix{original, original.type_mask()}.map_rect(src)
		sample_source = [src.left, src.top, src.right - src.left, src.bottom - src.top]!
		sample_destination = [dst.left, dst.top, dst.right - dst.left, dst.bottom - dst.top]!
	}
	geometry := CanvasImageFilterGeometry{source: sample_source, destination: sample_destination}
	paint_alpha := f32(u8(global_alpha * f32(255))) * inv_255
	if !sample_source[..].all(int_cast_preserves(it)) {
		// Fractional subsets are first drawn into an AA, premultiplied sRGB
		// surface by MakeFromImage. The filter graph then consumes that image.
		if ctm.kx != 0 || ctm.ky != 0 || rect_xywh(sample_source) != src
			|| rect_xywh(sample_destination) != dst { return false }
		return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
			transform, clips, dst, CanvasFilterStep{...prepared, source_image: true, source_padding: true, source_rescale_ready: true,
				source_color_info: FilterImageInfo{alpha: paint_alpha}}, mode,
			fn [image, geometry, smoothing] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
				return draw_canvas_image_sampled_aa(mut layer, w, h, w * 4, 2, t, image,
					geometry.source, geometry.destination, smoothing, 1, .src_over, inner_clips, false, true, true)
			}, none)
	}
	if ctm.type_mask() > affine_translate_mask || !int_cast_preserves(ctm.tx) || !int_cast_preserves(ctm.ty)
		|| !sample_destination[..].all(int_cast_preserves(it)) || sample_source[2] != sample_destination[2]
		|| sample_source[3] != sample_destination[3] {
		return draw_resampled_image_filter(mut pixels, width, height, pitch, alpha_type,
			transform, image, src, dst, smoothing, global_alpha, mode, clips, prepared)
	}
	raw := CanvasBitmap{...image, premultiplied: true, display_p3: false}
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
		transform, clips, dst, CanvasFilterStep{...prepared, source_image: true, source_rescale_ready: true,
			source_color_info: FilterImageInfo{premultiplied: image.premultiplied,
				display_p3: image.display_p3, alpha: paint_alpha}}, mode,
		fn [raw, geometry, smoothing] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
			return draw_canvas_image_sampled(mut layer, w, h, w * 4, 2, t, raw,
				geometry.source, geometry.destination, smoothing, 1, .src_over, inner_clips, false, true)
		}, none)
}
