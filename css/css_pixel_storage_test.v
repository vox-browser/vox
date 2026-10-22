module css

fn test_css_pixel_geometry_uses_upstream_32_bit_storage() {
	assert sizeof(CSSPixels) == 4
	assert sizeof(CSSPixelPoint) == 8
	assert sizeof(CSSPixelSize) == 8
	assert sizeof(CSSPixelRect) == 16
	assert sizeof(CSSPixelFraction) == 8
}

fn test_css_pixel_storage_preserves_signed_raw_boundaries() {
	for raw in [css_pixels_raw_min, css_pixels_raw_min + 1, -65, -64, -1, 0,
		1, 63, 64, css_pixels_raw_max - 1, css_pixels_raw_max] {
		pixel := CSSPixels.from_raw(raw)
		assert pixel.raw_value() == raw
		assert pixel.to_double() == f64(raw) / 64
		assert pixel.to_int() == raw / 64
	}
}

fn test_css_pixel_storage_widens_arithmetic_before_saturation() {
	assert CSSPixels.max().plus(CSSPixels.max()) == CSSPixels.max()
	assert CSSPixels.min().plus(CSSPixels.min()) == CSSPixels.min()
	assert CSSPixels.max().minus(CSSPixels.min()) == CSSPixels.max()
	assert CSSPixels.min().minus(CSSPixels.max()) == CSSPixels.min()
	assert CSSPixels.min().negated() == CSSPixels.max()
	assert CSSPixels.max().times(CSSPixels.max()) == CSSPixels.max()
	assert css_pixels_floor(CSSPixels.min()) == CSSPixels.min()
	assert css_pixels_ceil(CSSPixels.max()) == CSSPixels.max()
	assert css_pixels_floor(CSSPixels.from_raw(-1)).raw_value() == -64
	assert css_pixels_ceil(CSSPixels.from_raw(-1)).raw_value() == 0
}
