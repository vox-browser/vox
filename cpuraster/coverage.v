module cpuraster

// fill_opaque_coverage composites an antialiased path into a packed alpha
// plane. Successive fills union the coverage with the same rounding as
// opaque white source-over on the platform's Canvas2D RGBA surface.
pub fn fill_opaque_coverage(mut pixels []u8, width int, height int, path Path, transform [6]f32) bool {
	return fill_opaque_coverage_surface(mut pixels, width, height, path, transform, canvas_rgba_uses_legacy())
}

fn fill_opaque_coverage_surface(mut pixels []u8, width int, height int, path Path, transform [6]f32, legacy bool) bool {
	if path.is_inverse_fill() || width <= 0 || height <= 0 || width > max_untiled_dimension
		|| height > max_untiled_dimension || width * height > pixels.len {
		return false
	}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	mut blitter := A8Blitter{
		width:         width
		height:        height
		row_bytes:     width
		src:           255
		legacy_opaque: legacy
		pixels:        pixels
	}
	return anti_fill_path(path.transform(matrix), IRect{0, 0, width, height}, mut blitter)
}
