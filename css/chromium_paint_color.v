module css

// Computed legacy RGB values can still contain fractional channels. Keep
// those values available to the Chromium painter before Color quantizes them.
pub fn (value StyleValue) srgb_paint_components() ?[4]f64 {
	if value !is RGBColorStyleValue { return none }
	return style_value_to_color_components(value, CalculationResolutionContext{})?.values
}
