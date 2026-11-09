module css

import dom
import os

const disable_scalar_font_computation = os.getenv('VOX_DISABLE_SCALAR_FONT_COMPUTATION') != ''
const scalar_font_computation_diagnostics = os.getenv('VOX_SCALAR_FONT_COMPUTATION_DIAGNOSTICS') != ''
__global scalar_font_computation_reported bool

// These font values have no length to absolutize. Invoke the same property
// algorithms with the same inheritance parent, without selecting a metrics
// font or allocating a query-container/dependency context first. Calculated
// weights, widths and oblique angles retain the full computation path.
fn compute_scalar_font_property(id PropertyID, value &dom.StyleValue,
	parent ?dom.AbstractElement) ?&dom.StyleValue {
	if disable_scalar_font_computation || id !in [.font_weight, .font_width, .font_style]
		|| value.css_value_handle == unsafe { nil } { return none }
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	result := match id {
		.font_weight {
			if box.value is NumberStyleValue {
				StyleComputer.compute_font_weight(value, parent)
			} else if box.value is KeywordStyleValue
				&& box.value.keyword_ in [.normal, .bold, .bolder, .lighter] {
				StyleComputer.compute_font_weight(value, parent)
			} else { return none }
		}
		.font_width {
			if box.value is PercentageStyleValue {
				StyleComputer.compute_font_width(value)
			} else if box.value is KeywordStyleValue
				&& box.value.keyword_ in [.normal, .ultra_condensed, .extra_condensed,
					.condensed, .semi_condensed, .semi_expanded, .expanded,
					.extra_expanded, .ultra_expanded] {
				StyleComputer.compute_font_width(value)
			} else { return none }
		}
		.font_style {
			if box.value is FontStyleStyleValue && box.value.angle_value_ == unsafe { nil } {
				StyleComputer.compute_font_style(value)
			} else if box.value is KeywordStyleValue
				&& box.value.keyword_ in [.normal, .italic, .oblique] {
				StyleComputer.compute_font_style(value)
			} else { return none }
		}
		else { return none }
	}
	if scalar_font_computation_diagnostics && !scalar_font_computation_reported {
		scalar_font_computation_reported = true
		eprintln('VOX_SCALAR_FONT_COMPUTATION used ordinary font algorithm without length metrics')
	}
	return result
}

fn resolved_font_family_list(value &StyleValue) bool {
	return match value {
		StyleValueList {
			if value.values_.len == 0 { return false }
			for index, child in value.values_ {
				if child is StringStyleValue || child is CustomIdentStyleValue { continue }
				if child is KeywordStyleValue && scalar_value_is_already_absolutized(&value.values_[index]) { continue }
				return false
			}
			true
		}
		else { false }
	}
}
