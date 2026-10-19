module layout

import css
import dom

// Blink resolves SVG geometry in floating user units. CSS box dimensions
// still use layout precision, but rounding a small ellipse radius to 1/64px
// changes its painted coverage after an SVG transform.
fn svg_ellipse_length(node &Node, property_id css.PropertyID, basis f64) ?f64 {
	computed := node.computed_values()
	if node.document().font_rendering_policy() != .chromium {
		return computed.length_percentage_to_px(property_id, basis)
	}
	value := computed.typed_property_value(property_id) or { return none }
	resolved := match value {
		css.LengthStyleValue {
			value.length().to_px_without_rounding(computed.length_resolution_context())
		}
		css.PercentageStyleValue { basis * value.percentage().as_fraction() }
		css.CalculatedStyleValue {
			value.resolve_raw_length(css.CalculationResolutionContext{
				percentage_basis: css.CalculationPercentageBasis(css.Length.make_px(basis))
				length_resolution_context: computed.length_resolution_context()
			}) or { return none }
		}
		else { return none }
	}
	return f64(f32(resolved))
}
