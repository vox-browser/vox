module css

import dom

fn test_absolute_font_size_computation_matches_full_document_policy_resolver() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns(dom.namespace_html_uri, 'span')!
	subject := dom.AbstractElement.new(element, none)
	computer := StyleComputer.new(document)
	mut style := computed_properties_with_initial_values()
	style.set_property(.math_depth, dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(2))), .no, .no)
	source := ComputedPropertyValueSource{properties:style}
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		document.set_font_rendering_policy(policy)
		for keyword_policy in [dom.FontSizeKeywordPolicy.libweb, .chromium] {
			document.set_font_size_keyword_policy(keyword_policy)
			for text in ['0px','0.001px','0.999px','13.333333px','7pt','10pt','2.54cm','1.25in','3q'] {
				value := parse_css_value(ParsingParams{}, text, .font_size) or { panic(text) }
				actual := compute_absolute_font_size(value, document) or { panic(text) }
				computer.clear_computation_context_caches()
				context := computer.get_computation_context_for_property(.font_size,style,subject)
				expected := compute_value_of_property_from_source(.font_size,value,source,context,1)
				first := computed_interpolation_length_from_dom_style_value(actual) or { panic('absolute result') }
				second := computed_interpolation_length_from_dom_style_value(expected) or { panic('ordinary result') }
				assert first.unit_ == second.unit_
				assert first.value_ == second.value_, text
			}
		}
	}
}

fn test_absolute_font_size_computation_keeps_context_dependent_and_untyped_inputs_on_resolver() {
	document := dom.Document.create(dom.url_about_blank())
	for text in ['1em','1rem','10vw','10cqw','120%','medium','inherit','larger','math','calc(1px + 1em)'] {
		value := parse_css_value(ParsingParams{}, text, .font_size) or { panic(text) }
		assert compute_absolute_font_size(value,document) == none
	}
	assert compute_absolute_font_size(&dom.StyleValue{css_text:'13px'},document) == none
}
