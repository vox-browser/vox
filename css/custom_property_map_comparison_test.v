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
