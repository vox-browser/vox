module layout

import css
import os

const precise_transform_origin_diagnostic = os.getenv('VOX_DIAGNOSTIC_PRECISE_TRANSFORM_ORIGIN') == '1'

// A percentage of a fixed-point reference box can lie between layout units.
// Preserve that position until the transform matrix is built.
fn resolved_transform_origin_offset(value css.LengthPercentage, context css.LengthResolutionContext,
	reference f64, precise bool) f64 {
	quantized := value.to_px(context, css.CSSPixels.nearest_value_for(reference)).to_double()
	if precise && context.use_chromium_geometry && value.is_percentage() {
		result := reference * value.percentage().as_fraction()
		if result != quantized {
			eprintln('VOX_PRECISE_TRANSFORM_ORIGIN reference=${reference} percentage=${value.percentage().value()} quantized=${quantized} precise=${result}')
		}
		return result
	}
	return quantized
}
