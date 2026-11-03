module css

import dom

fn test_scalar_font_computation_matches_full_resolver_across_parent_weight_boundaries() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut parent_element := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent_element.as_node()
	parent_node.append_child(child.as_node())!
	mut parent := dom.AbstractElement.new(parent_element, none)
	subject := dom.AbstractElement.new(child, none)
	computer := StyleComputer.new(document)
	mut inherited := computed_properties_with_initial_values()
	style := computed_properties_with_initial_values()
	source := ComputedPropertyValueSource{properties:style}
	for weight in [1.0, 99.0, 100.0, 349.99, 350.0, 549.99, 550.0, 749.99, 750.0, 899.99, 900.0, 1000.0] {
		inherited.set_property(.font_weight,
			dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(weight))), .no, .no)
		parent.set_computed_properties(computed_properties_to_dom(inherited))
		for id, texts in {
			PropertyID.font_weight: ['normal', 'bold', 'bolder', 'lighter', '327.5']
			PropertyID.font_style: ['normal', 'italic', 'oblique']
			PropertyID.font_width: ['normal', 'condensed', 'extra-expanded', '87.25%']
		} {
			for text in texts {
				value := parse_css_value(ParsingParams{}, text, id) or { panic(text) }
				actual := compute_scalar_font_property(id,value,parent) or { panic(text) }
				computer.clear_computation_context_caches()
				context := computer.get_computation_context_for_property(id,style,subject)
				expected := compute_value_of_property_from_source(id,value,source,context,1)
				a := typed_style_value_logic_from_dom(actual) or { panic('actual') }
				b := typed_style_value_logic_from_dom(expected) or { panic('ordinary') }
				assert a.equals(b), '${id} ${text}, parent ${weight}'
			}
		}
	}
}

fn test_scalar_font_computation_retains_contextual_and_compatibility_paths() {
	for id, texts in {
		PropertyID.font_weight: ['calc(350 + 50)']
		PropertyID.font_width: ['calc(80% + 5%)']
		PropertyID.font_style: ['oblique 12deg', 'oblique calc(10deg + 2deg)']
		PropertyID.font_size: ['16px']
	} {
		for text in texts {
			value := parse_css_value(ParsingParams{},text,id) or { panic(text) }
			assert compute_scalar_font_property(id,value,none) == none, '${id} ${text}'
		}
	}
	assert compute_scalar_font_property(.font_weight,&dom.StyleValue{css_text:'bold'},none) == none
}

fn test_plain_font_family_lists_are_unchanged_by_full_absolutization() {
	for text in ['Arial, sans-serif', '"Family with spaces", serif', 'monospace'] {
		value := parse_css_value(ParsingParams{},text,.font_family) or { panic(text) }
		typed := typed_style_value_logic_from_dom(value) or { panic(text) }
		assert computed_scalar_value_is_resolved(.font_family,value)
		assert typed.equals(typed.absolutized(ComputationContext{}))
	}
}
