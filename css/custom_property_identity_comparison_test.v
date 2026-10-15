module css

import dom

fn test_shared_retained_custom_values_compare_across_distinct_bridge_wrappers() {
	value := parse_custom_property_value('var(--accent, rgb(10 20 30))')
	left := custom_property_bridge_value(value)
	right := custom_property_bridge_value(value)
	assert voidptr(left) != voidptr(right)
	assert left.css_value_handle == right.css_value_handle
	for _ in 0 .. 3 {
		gc_collect()
		assert custom_property_bridge_values_equal(left, right)
		assert custom_property_bridge_values_equal(left, left)
	}
}

fn test_distinct_retained_custom_values_keep_token_equality_and_changed_value_detection() {
	left :=
		custom_property_bridge_value(parse_custom_property_value('var(--accent, rgb(10 20 30))'))
	equal :=
		custom_property_bridge_value(parse_custom_property_value('var(--accent, rgb(10 20 30))'))
	changed :=
		custom_property_bridge_value(parse_custom_property_value('var(--accent, rgb(10 20 31))'))
	assert left.css_value_handle != equal.css_value_handle
	assert custom_property_bridge_values_equal(left, equal)
	assert !custom_property_bridge_values_equal(left, changed)
	assert custom_property_bridge_values_equal(&dom.CSSStyleValue_{ css_text: 'red' }, &dom.CSSStyleValue_{
		css_text: 'red'
	})
	assert !custom_property_bridge_values_equal(&dom.CSSStyleValue_{ css_text: 'red' }, &dom.CSSStyleValue_{
		css_text: 'blue'
	})
	assert !custom_property_bridge_values_equal(&dom.CSSStyleValue_{
		css_text:           ''
		guaranteed_invalid: true
	}, &dom.CSSStyleValue_{
		css_text: ''
	})
}

fn test_custom_property_map_comparison_observes_live_replacements_deletions_and_importance() {
	first := custom_property_bridge_value(parse_custom_property_value('var(--one, 10px)'))
	second := custom_property_bridge_value(parse_custom_property_value('var(--two, 20px)'))
	left := {
		'--first':  dom.CSSCustomProperty_{
			value: first
		}
		'--second': dom.CSSCustomProperty_{
			value:     second
			important: true
		}
	}
	mut right := {
		'--second': dom.CSSCustomProperty_{
			value:     second
			important: true
		}
		'--first':  dom.CSSCustomProperty_{
			value: first
		}
	}
	assert custom_property_maps_equal(left, right)
	right['--first'] = dom.CSSCustomProperty_{
		value: second
	}
	assert !custom_property_maps_equal(left, right)
	right['--first'] = dom.CSSCustomProperty_{
		value:     first
		important: true
	}
	assert !custom_property_maps_equal(left, right)
	right['--first'] = dom.CSSCustomProperty_{
		value: first
	}
	right.delete('--second')
	right['--third'] = dom.CSSCustomProperty_{
		value:     second
		important: true
	}
	assert left.len == right.len
	assert !custom_property_maps_equal(left, right)
	right.delete('--third')
	right['--second'] = dom.CSSCustomProperty_{
		value:     second
		important: true
	}
	gc_collect()
	assert custom_property_maps_equal(left, right)
}
