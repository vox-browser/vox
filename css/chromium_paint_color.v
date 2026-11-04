module css

import math

// Computed legacy RGB values can still contain fractional channels. Keep
// those values available to the Chromium painter before Color quantizes them.
pub fn (value StyleValue) srgb_paint_components() ?[4]f64 {
	if value !is RGBColorStyleValue { return none }
	mut components := style_value_to_color_components(value, CalculationResolutionContext{})?.values
	// Chromium compresses comma-separated RGB alpha to eight bits while
	// retaining fractional alpha for the modern space-separated syntax.
	if value.color_syntax() == .legacy && !value.preserve_float_alpha_ {
		components[3] = math.round(components[3] * 255) / 255
	}
	return components
}
