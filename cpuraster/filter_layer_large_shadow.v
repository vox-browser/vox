module cpuraster

// A saved canvas drop shadow keeps the blur's upscale deferred through the
// SrcIn tint and linear offset. Merge then draws the original content above
// that transformed view into a surface with a transparent pixel boundary.
fn draw_large_shadow_layer(mut pixels []u8, pitch int, rc &RasterClip, mode BlendMode, layer BlurImage, origin_x int, origin_y int, sigma_x f32, sigma_y f32, offset SkAffine, step CanvasFilterStep, max_dim int, mut target CanvasTarget) bool {
	saved := new_filter_result(SpecialImage{layer, IRect{0, 0, layer.width, layer.height}}, 0, 0).inset_for_save_layer()
	source := FilterResult{...saved, color_info: step.source_color_info}
	clip := rc.bounds()
	desired := IRect{clip.left - origin_x, clip.top - origin_y, clip.right - origin_x, clip.bottom - origin_y}
	shadow_desired := skif_outset(map_filter_bounds(desired, affine_invert(offset) or { return false }), 1, 1)
	shadow := scaled_blur_filter_view(source, shadow_desired, sigma_x, sigma_y,
		new_color_filter(step.pre_color), true) or { return false }
	value := spatial_filter_merge(SpatialFilterValue{image: source, color: step.pre_color},
		SpatialFilterValue{view: if shadow.bitmap.width > 0 { ?FilterImageView(shadow) } else { none }},
		offset, desired, step.color, max_dim) or { return false }
	target.ready()
	if !value.image.has_image {
		draw_empty_filter_result(mut pixels, pitch, rc, mode)
		return true
	}
	result := value.image
	draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(result.image.bitmap()),
		origin_x + result.origin_x, origin_y + result.origin_y, rc, mode, step.post_color, 1)
	return true
}
