module cpuraster

// A drop shadow keeps the blur's upscale deferred through the
// SrcIn tint and linear offset. Merge then draws the original content above
// that transformed view into a surface with a transparent pixel boundary.
// Source images retain global layer coordinates and their RGBA context.
fn draw_large_shadow_layer(mut pixels []u8, pitch int, rc &RasterClip, mode BlendMode, layer BlurImage, origin_x int, origin_y int, sigma_x f32, sigma_y f32, offset SkAffine, step CanvasFilterStep, max_dim int, mut target CanvasTarget) bool {
	saved := new_filter_result(SpecialImage{layer, IRect{0, 0, layer.width, layer.height}}, 0, 0).inset_for_save_layer()
	mut source := FilterResult{...saved, color_info: step.source_color_info,
		transparent_boundary: !step.source_image || step.source_padding}
	clip := rc.bounds()
	base_x, base_y := if step.source_image { 0 } else { origin_x }, if step.source_image { 0 } else { origin_y }
	if step.source_image { source = source.translated(origin_x, origin_y) }
	desired := IRect{clip.left - base_x, clip.top - base_y, clip.right - base_x, clip.bottom - base_y}
	shadow_desired := skif_outset(map_filter_bounds(desired, affine_invert(offset) or { return false }), 1, 1)
	shadow := scaled_blur_filter_view(source, shadow_desired, sigma_x, sigma_y,
		new_color_filter(step.pre_color), !step.source_image) or { return false }
	foreground := if view := step.source_foreground { SpatialFilterValue{view: view} } else {
		SpatialFilterValue{image: source, color: step.pre_color} }
	value := spatial_filter_merge(foreground,
		SpatialFilterValue{view: if shadow.bitmap.width > 0 { ?FilterImageView(shadow) } else { none }},
		offset, desired, step.color, max_dim) or { return false }
	target.ready()
	if !value.image.has_image {
		draw_empty_filter_result(mut pixels, pitch, rc, mode)
		return true
	}
	result := value.image
	draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(result.image.bitmap()),
		base_x + result.origin_x, base_y + result.origin_y, rc, mode, step.post_color, 1)
	return true
}
