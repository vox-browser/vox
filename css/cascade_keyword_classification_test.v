module css

import dom

fn keyword_cascade_fixture() (&StyleComputer, dom.AbstractElement, &ComputedProperties) {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element('div') or { panic(err) }
	parent.set_attribute_value('style', 'color: red; width: 37px; visibility: hidden; font-size: 20px; font-weight: 400')
	child := document.create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	computer.recompute_style(mut parent_abstract)
	computed := computed_properties_from_dom(parent_abstract.computed_properties() or {
		panic('missing parent style')
	}) or { panic('missing typed parent style') }
	return computer, dom.AbstractElement.new(child, none), computed
}

fn keyword_cascade_value(property_id PropertyID, text string, typed bool) &dom.StyleValue {
	if typed {
		return parse_css_value(ParsingParams{}, text, property_id) or { panic(text) }
	}
	return &dom.StyleValue{css_text: ' \t${text.to_upper()}\n '}
}

fn test_cascade_classification_preserves_inherit_initial_and_unset() {
	computer, child, parent := keyword_cascade_fixture()
	for typed in [false, true] {
		for keyword in ['inherit', 'initial', 'unset'] {
			mut cascaded := CascadedProperties.new()
			for property_id in [PropertyID.color, .width, .visibility, .font_size] {
				cascaded.set_property(property_id, keyword_cascade_value(property_id, keyword, typed),
					.yes, .author, none, unsafe { nil }, none)
			}
			computed := computer.compute_properties(child, mut cascaded)
			inherited := keyword != 'initial'
			assert computed.is_property_inherited(.color) == inherited
			assert computed.is_property_inherited(.visibility) == inherited
			assert computed.is_property_inherited(.font_size) == inherited
			assert computed.is_property_inherited(.width) == (keyword == 'inherit')
			assert computed.is_property_important(.width)
			assert computed.visibility() == if inherited { Visibility.hidden } else { Visibility.visible }
			assert computed.font_size().to_double() == if inherited { f64(20) } else { f64(16) }
			width := computed.property(.width, .no)?
			assert width.css_text == if keyword == 'inherit' { '37px' } else { 'auto' }
			if inherited {
				assert computed.property(.color, .no)?.css_text == parent.property(.color, .no)?.css_text
			}
		}
	}
}

fn test_cascade_classification_preserves_currentcolor_and_missing_parent_defaults() {
	computer, child, parent := keyword_cascade_fixture()
	for typed in [false, true] {
		mut cascaded := CascadedProperties.new()
		for property_id in [PropertyID.color, .background_color] {
			cascaded.set_property(property_id, keyword_cascade_value(property_id, 'currentcolor',
				typed || property_id == .background_color),
				.no, .author, none, unsafe { nil }, none)
		}
		computed := computer.compute_properties(child, mut cascaded)
		assert computed.is_property_inherited(.color)
		assert !computed.is_property_inherited(.background_color)
		assert computed.property(.color, .no)?.css_text == parent.property(.color, .no)?.css_text
		assert computed_interpolation_style_value_keyword(computed.property(.background_color, .no)?)? == .currentcolor
	}
	document := dom.Document.create(dom.url_about_blank())
	orphan := dom.AbstractElement.new(document.create_element('span')!, none)
	for keyword in ['inherit', 'unset'] {
		mut cascaded := CascadedProperties.new()
		for property_id in [PropertyID.width, .font_size] {
			cascaded.set_property(property_id, keyword_cascade_value(property_id, keyword, true),
				.no, .author, none, unsafe { nil }, none)
		}
		computed := StyleComputer.new(document).compute_properties(orphan, mut cascaded)
		assert computed.property(.width, .no)?.css_text == 'auto'
		assert computed.font_size().to_double() == 16
		assert !computed.is_property_inherited(.width)
		assert !computed.is_property_inherited(.font_size)
	}
}

fn test_cascade_classification_preserves_relative_font_and_length_dependencies() {
	computer, child, _ := keyword_cascade_fixture()
	for weight, expected in {'bolder': f64(700), 'lighter': f64(100)} {
		mut cascaded := CascadedProperties.new()
		for property_id, text in {
			PropertyID.font_weight: weight
			.font_size: 'larger'
			.width: '2em'
			.opacity: '0.6'
		} {
			value := parse_css_value(ParsingParams{}, text, property_id)?
			cascaded.set_property(property_id, value, .no, .author, none, unsafe { nil }, none)
		}
		computed := computer.compute_properties(child, mut cascaded)
		dependencies := computed.inheritance_dependent_specified_values()
		assert (dependencies[.font_weight] or { panic('missing relative weight') }).css_text == weight
		assert (dependencies[.font_size] or { panic('missing relative font size') }).css_text == 'larger'
		assert (dependencies[.width] or { panic('missing relative length') }).css_text == '2em'
		assert PropertyID.opacity !in dependencies
		assert computed.font_weight() == expected
		assert computed.font_size().to_double() > 20
		assert !computed.is_property_inherited(.font_weight)
	}
}

fn test_cascade_classification_uses_retained_types_instead_of_spoofed_keyword_text() {
	computer, child, _ := keyword_cascade_fixture()
	mut cascaded := CascadedProperties.new()
	for property_id, text in {
		PropertyID.width: '25px'
		.font_size: '18px'
		.font_weight: '700'
		.color: 'blue'
	} {
		mut value := parse_css_value(ParsingParams{}, text, property_id)?
		value.css_text = 'inherit'
		cascaded.set_property(property_id, value, .no, .author, none, unsafe { nil }, none)
	}
	computed := computer.compute_properties(child, mut cascaded)
	for property_id in [PropertyID.width, .font_size, .font_weight, .color] {
		assert !computed.is_property_inherited(property_id)
		assert property_id !in computed.inheritance_dependent_specified_values()
	}
	assert computed.font_size().to_double() == 18
	assert computed.font_weight() == 700
	assert LengthPercentageOrAuto.from_style_value(computed.property(.width, .no)?).to_px_or_zero(
		LengthResolutionContext.default(), CSSPixels.new(100)).to_double() == 25
}

fn test_cascade_classification_refreshes_after_inherited_value_replacement() {
	computer, child, parent := keyword_cascade_fixture()
	mut mutable_parent := unsafe { &ComputedProperties(parent) }
	// Exercise the boundary directly: a parent-supplied value must be checked
	// afresh rather than reusing the child's original `inherit` classification.
	for typed in [false, true] {
		mutable_parent.set_property(.width, keyword_cascade_value(.width, 'initial', typed), .no, .no)
		mut cascaded := CascadedProperties.new()
		cascaded.set_property(.width, keyword_cascade_value(.width, 'inherit', typed),
			.no, .author, none, unsafe { nil }, none)
		computed := computer.compute_properties(child, mut cascaded)
		assert computed.property(.width, .no)?.css_text == 'auto'
		assert computed.is_property_inherited(.width)
	}
}
