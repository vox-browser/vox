module css

import dom

fn test_inline_baseline_controls_parse_compute_and_keep_their_animation_types() {
	for value in ['baseline', 'text-bottom', 'alphabetic', 'ideographic', 'middle', 'central',
		'mathematical', 'hanging', 'text-top'] {
		assert parse_css_value_logic(.alignment_baseline, value) != none, value
	}
	for value in ['auto', 'first', 'last'] {
		assert parse_css_value_logic(.baseline_source, value) != none, value
	}
	for property in [PropertyID.alignment_baseline, .baseline_source] {
		assert !is_inherited_property(property)
		assert animation_type_from_longhand_property(property) == .discrete
		assert parse_css_value_logic(property, 'first last') == none
	}
	for value in ['-10px', '20%', 'calc(2em + 3ex)', '0', 'sub', 'super', 'top', 'center', 'bottom'] {
		assert parse_css_value_logic(.baseline_shift, value) != none, value
	}
	assert parse_css_value_logic(.baseline_shift, 'auto') == none
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font-size:40px;baseline-shift:calc(10px - .5em);baseline-source:first;alignment-baseline:central')
	style := css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	value := typed_style_value_logic_from_dom(style.property(.baseline_shift, .no) or { panic('shift') }) or { panic('typed shift') }
	assert value is CalculatedStyleValue
	calculated := value as CalculatedStyleValue
	assert (calculated.resolve_length(CalculationResolutionContext{}) or { panic('computed shift') }).absolute_length_to_px_without_rounding() == -10
	assert (style.property(.baseline_source, .no) or { panic('source') }).css_text == 'first'
}
