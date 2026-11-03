module css

import math

fn test_semantic_scalar_equality_matches_ordinary_typed_equality() {
	mut values := []StyleValue{}
	for property, sources in {
		PropertyID.color: ['red', 'rgb(1 2 3)', 'rgba(1, 2, 3, .5)']
		PropertyID.width: ['auto', '0px', '1px', '1cm', '10%', 'calc(1px + 2%)']
		PropertyID.font_family: ['Arial, sans-serif', '"Arial", serif']
		PropertyID.font_style: ['normal', 'oblique 12deg']
		PropertyID.background_repeat: ['repeat', 'repeat no-repeat']
		PropertyID.display: ['block', 'inline-flex']
		PropertyID.border_top_left_radius: ['2px 3px', '10%']
		PropertyID.grid_auto_flow: ['row', 'column dense']
		PropertyID.corner_top_left_shape: ['superellipse(1)', 'superellipse(2)']
	} {
		for source in sources { values << parse_css_value_logic(property, source) or { panic(source) } }
	}
	values << StyleValue(NumberStyleValue.create(math.nan()))
	values << StyleValue(NumberStyleValue.create(-0.0))
	values << StyleValue(IntegerStyleValue.create(0))
	values << StyleValue(StyleValueList.create([StyleValue(KeywordStyleValue.create(.auto))], .space, .yes))
	values << StyleValue(StyleValueList.create([StyleValue(KeywordStyleValue.create(.auto))], .space, .no))
	for index in 0 .. values.len {
		for other in 0 .. values.len {
			assert unsafe { scalar_style_values_equal(&values[index], &values[other]) } == style_values_equal_using_union(values[index], values[other]), '${index} ${other}'
		}
	}
}
