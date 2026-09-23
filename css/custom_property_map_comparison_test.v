module css

import dom

fn custom_property_comparison_data(text string, important bool) &dom.CSSCustomPropertyData_ {
	return dom.CSSCustomPropertyData_.create({
		'--value': dom.CSSCustomProperty_{
			important: important
			value: &dom.CSSStyleValue_{
				css_text: text
			}
		}
	}, none)
}

fn test_custom_property_map_comparison_uses_shared_empty_cases() {
	empty := dom.CSSCustomPropertyData_.create(map[string]dom.CSSCustomProperty_{}, none)
	assert custom_property_own_values_equal(none, none)
	assert custom_property_own_values_equal(empty, none)
	assert custom_property_own_values_equal(none, empty)
	assert !custom_property_own_values_equal(custom_property_comparison_data('red', false), none)
}

fn test_custom_property_map_comparison_checks_values_and_importance() {
	red := custom_property_comparison_data('red', false)
	assert custom_property_own_values_equal(red, custom_property_comparison_data('red', false))
	assert !custom_property_own_values_equal(red, custom_property_comparison_data('blue', false))
	assert !custom_property_own_values_equal(red, custom_property_comparison_data('red', true))
}

fn test_custom_property_change_reporting_compares_environment_below_animation_overlay() {
	old_base := custom_property_comparison_data('10px', false)
	new_base := custom_property_comparison_data('20px', false)
	animated_value := dom.CSSCustomProperty_{
		value: &dom.CSSStyleValue_{
			css_text: '0'
		}
	}
	old_overlay := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': animated_value
	}, old_base)
	new_overlay := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': animated_value
	}, new_base)
	assert report_custom_property_change(old_overlay, new_overlay)

	same_base_overlay := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': animated_value
	}, old_base)
	assert !report_custom_property_change(old_overlay, same_base_overlay)
	changed_animation_overlay := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{
				css_text: '1'
			}
		}
	}, old_base)
	assert report_custom_property_change(old_overlay, changed_animation_overlay)
	assert report_custom_property_change(old_base, old_overlay)
}
