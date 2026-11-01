module css

import dom
import os

const force_metric_computation_context = os.getenv('VOX_FORCE_METRIC_COMPUTATION_CONTEXT') != ''
const computation_context_diagnostics = os.getenv('VOX_COMPUTATION_CONTEXT_DIAGNOSTICS') != ''

__global metric_free_computation_reported bool

// These primitive values cannot resolve relative lengths or system colors.
// Font size, line height and math depth also consult inherited metrics or the
// document's font policy independently of the value's representation.
fn computed_value_needs_metric_context(property_id PropertyID, value &dom.StyleValue) bool {
	if property_id in [.font_size, .line_height, .math_depth]
		|| value.css_value_handle == unsafe { nil } { return true }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	return match typed.value {
		LengthStyleValue { !typed.value.length_.is_px() }
		NumberStyleValue, IntegerStyleValue, PercentageStyleValue, ColorStyleValue,
		TimeStyleValue, AngleStyleValue { false }
		KeywordStyleValue {
			property_id == .font_weight || typed.value.has_color()
				|| typed.value.keyword_ in [.initial, .inherit, .unset, .revert, .revert_layer]
		}
		else { true }
	}
}

fn (s &StyleComputer) computation_context_for_value(property_id PropertyID,
	value &dom.StyleValue, properties &ComputedProperties,
	abstract_element dom.AbstractElement) ComputationContext {
	if force_metric_computation_context || computed_value_needs_metric_context(property_id, value) {
		return s.get_computation_context_for_property(property_id, properties, abstract_element)
	}
	if computation_context_diagnostics && !metric_free_computation_reported {
		metric_free_computation_reported = true
		eprintln('Vox value computation: omitted unused metric context')
	}
	// Keep the subject available to property-specific conversion. The ordinary
	// value computation and dependency tracking still run for every property.
	return ComputationContext{abstract_element: abstract_element}
}
