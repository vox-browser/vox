module cpuraster

// Filter a padded glyph mask using the same fixed-point mask filter as paths.
// Keep its canvas bounds: callers include the filter support in the padding.
pub fn blur_glyph_mask(source []u8, width int, height int, blur f32) ?[]u8 {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| source.len != width * height || source.len > 4 * 1024 * 1024
		|| !is_finite_f32(blur) || blur < 0 || blur > 3 {
		return none
	}
	filter := new_mask_blur_filter(blur * f32(.5))
	if filter.has_no_blur() { return source }
	mask := Mask{
		bounds:    IRect{0, 0, width, height}
		row_bytes: width
		image:     source
	}
	filtered := filter.blur(&mask) or { return none }
	mut result := []u8{len: source.len}
	for y in 0 .. height {
		for x in 0 .. width {
			result[y * width + x] = filtered.image[filtered.index(x, y)]
		}
	}
	return result
}
