module css

fn test_css_pixels_arithmetic_and_saturation() {
	assert CSSPixels.new(10).plus(CSSPixels.new(20)) == CSSPixels.new(30)
	assert CSSPixels.new(30).minus(CSSPixels.new(10)) == CSSPixels.new(20)
	assert CSSPixels.new(3).times(CSSPixels.new(4)) == CSSPixels.new(12)
	assert CSSPixels.max().plus(CSSPixels.new(1)) == CSSPixels.max()
	assert CSSPixels.min().minus(CSSPixels.new(1)) == CSSPixels.min()
	assert CSSPixels.max().might_be_saturated()
	assert CSSPixels.min().might_be_saturated()
}

fn test_css_pixels_conversion_rounds_ties_to_even() {
	assert CSSPixels.nearest_value_for(1.0 / 128.0).raw_value() == 0
	assert CSSPixels.nearest_value_for(3.0 / 128.0).raw_value() == 2
	assert CSSPixels.nearest_value_for(-3.0 / 128.0).raw_value() == -2
}

fn test_css_pixels_multiplication_rounds_to_even() {
	assert CSSPixels.from_raw(0b01_0000011).times(CSSPixels.from_raw(0b00_010000)) == CSSPixels.from_raw(0b00_0100001)
	assert CSSPixels.from_raw(0b01_0000111).times(CSSPixels.from_raw(0b00_010000)) == CSSPixels.from_raw(0b00_0100010)
}

fn test_css_pixels_rounding() {
	assert css_pixels_ceil(CSSPixels.nearest_value_for(1.3)) == CSSPixels.new(2)
	assert css_pixels_ceil(CSSPixels.nearest_value_for(-1.7)) == CSSPixels.new(-1)
	assert css_pixels_floor(CSSPixels.nearest_value_for(1.7)) == CSSPixels.new(1)
	assert css_pixels_floor(CSSPixels.nearest_value_for(-1.3)) == CSSPixels.new(-2)
	assert css_pixels_round(CSSPixels.nearest_value_for(1.5)) == CSSPixels.new(2)
	assert css_pixels_round(CSSPixels.nearest_value_for(-1.5)) == CSSPixels.new(-2)
}

fn test_css_pixel_fraction_preserves_ratio() {
	ratio := CSSPixelFraction.new(CSSPixels.new(10), CSSPixels.new(4))
	assert ratio.to_double() == 2.5
	assert ratio.to_css_pixels() == CSSPixels.nearest_value_for(2.5)
	assert CSSPixels.new(12).times_fraction(ratio) == CSSPixels.new(30)
	assert CSSPixels.new(10).divided_by(CSSPixels.new(4)).compare(ratio) == 0
}

fn test_default_sizing_uses_single_step_aspect_ratio_division() {
	ratio := CSSPixelFraction.new(CSSPixels.new(600), CSSPixels.new(1670))
	result := run_default_sizing_algorithm(CSSPixels.new(800), none, SizeWithAspectRatio{
		aspect_ratio: ratio
	}, CSSPixelSize.from_values(300, 150))
	assert result.width().raw_value() == 51_200
	assert result.height().raw_value() == 142_506
}

fn test_css_pixel_geometry_helpers() {
	rect := CSSPixelRect.new(10, 20, 30, 40)
	assert rect.right() == CSSPixels.new(40)
	assert rect.bottom() == CSSPixels.new(60)
	point := css_pixel_point_constrained(CSSPixelPoint.from_values(50, 10), rect)
	assert point.x() == CSSPixels.new(39)
	assert point.y() == CSSPixels.new(20)
}

fn test_device_pixel_ipc_component_order_round_trips() {
	rect := DevicePixelRect.new(DevicePixelPoint.new(DevicePixels.new(1), DevicePixels.new(2)), DevicePixelSize.new(DevicePixels.new(30),
		DevicePixels.new(40)))
	components := encode_device_pixel_rect(rect)
	assert components == [1, 2, 30, 40]
	decoded := decode_device_pixel_rect(components) or { panic(err) }
	assert decoded.location().x().value() == 1
	assert decoded.location().y().value() == 2
	assert decoded.size().width().value() == 30
	assert decoded.size().height().value() == 40
}

fn test_css_pixel_point_ipc_uses_raw_fixed_point_components() {
	point := CSSPixelPoint.new(CSSPixels.from_raw(123), CSSPixels.from_raw(-456))
	components := encode_css_pixel_point(point)
	assert components == [123, -456]
	decoded := decode_css_pixel_point(components) or { panic(err) }
	assert decoded.x().raw_value() == 123
	assert decoded.y().raw_value() == -456
}
