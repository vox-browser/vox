module css

import dom

fn test_resolved_scalars_match_the_full_property_algorithm() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	subject := dom.AbstractElement.new(element, none)
	computer := StyleComputer.new(document)
	style := computed_properties_with_initial_values()
	source := ComputedPropertyValueSource{properties:style}
	for id, texts in {
		PropertyID.width: ['auto', '0px', '13.333px', '20%']
		PropertyID.margin_left: ['auto', '12px', '-3px', '10%']
		PropertyID.padding_top: ['0px', '1.25px', '10%']
		PropertyID.color: ['currentcolor']
		PropertyID.display: ['block', 'inline-flex']
		PropertyID.z_index: ['auto', '7']
		PropertyID.border_top_style: ['solid', 'none']
	} {
		for text in texts {
			value := parse_css_value(ParsingParams{}, text, id) or { panic(text) }
			assert computed_scalar_value_is_resolved(id, value)
			computer.clear_computation_context_caches()
			context := computer.get_computation_context_for_property(id, style, subject)
			expected := compute_value_of_property_from_source(id, value, source, context, 1)
			actual_typed := typed_style_value_logic_from_dom(value) or { panic('actual') }
			expected_typed := typed_style_value_logic_from_dom(expected) or { panic('ordinary') }
			assert actual_typed.equals(expected_typed), '${id} ${text}'
		}
	}
}

fn test_resolved_scalar_computation_keeps_contextual_values_and_special_property_algorithms() {
	for id, texts in {
		PropertyID.width: ['2em', '1rem', '2pt', '10vw', '10cqw', 'calc(1px + 2%)']
		PropertyID.color: ['CanvasText', 'rgb(12 34 56)']
		PropertyID.font_weight: ['normal', '700', 'bolder']
		PropertyID.font_size: ['13px']
		PropertyID.line_height: ['normal', '13px', '1.2']
		PropertyID.opacity: ['.5', '20%']
		PropertyID.border_top_width: ['2px', 'thin']
	} {
		for text in texts {
			value := parse_css_value(ParsingParams{}, text, id) or { panic(text) }
			assert !computed_scalar_value_is_resolved(id, value), '${id} ${text}'
		}
	}
	assert !computed_scalar_value_is_resolved(.width, &dom.StyleValue{css_text:'13px'})
}
