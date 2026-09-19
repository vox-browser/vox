module css

import dom

fn font_smoothing_serialization(text string) ?string {
	value := parse_css_value_logic(.webkit_font_smoothing, text) or { return none }
	return value.serialize(.normal)
}

fn test_webkit_font_smoothing_metadata_and_parsing() {
	assert property_id_from_string('-webkit-font-smoothing')? == .webkit_font_smoothing
	assert property_id_from_string('-WEBKIT-FONT-SMOOTHING')? == .webkit_font_smoothing
	assert string_from_property_id(.webkit_font_smoothing) == '-webkit-font-smoothing'
	assert property_initial_value_string(.webkit_font_smoothing) == 'auto'
	assert is_inherited_property(.webkit_font_smoothing)
	assert animation_type_from_longhand_property(.webkit_font_smoothing) == .discrete
	assert is_animatable_property(.webkit_font_smoothing)
	assert !property_affects_layout(.webkit_font_smoothing)
	assert PropertyID.webkit_font_smoothing in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.webkit_font_smoothing) == [
		PropertyID.all,
	]

	for valid in ['auto', 'none', 'antialiased', 'subpixel-antialiased', 'AnTiAlIaSeD'] {
		assert font_smoothing_serialization(valid)? == valid.to_lower()
	}
	for invalid in ['grayscale', 'normal', 'antialiased auto', '1'] {
		assert font_smoothing_serialization(invalid) == none, invalid
	}
}

fn test_webkit_font_smoothing_computes_and_inherits() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element('div') or { panic(err) }
	mut child := document.create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }

	computer := StyleComputer.new(document)
	initial := computer.compute_style(dom.AbstractElement.new(child, none))
	assert initial.font_smoothing() == .auto_

	parent.set_attribute_value('style', '-webkit-font-smoothing: subpixel-antialiased')
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_style := computer.compute_style(parent_abstract)
	assert parent_style.font_smoothing() == .subpixel_antialiased
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_style))

	inherited := computer.compute_style(dom.AbstractElement.new(child, none))
	assert inherited.font_smoothing() == .subpixel_antialiased

	child.set_attribute_value('style', '-webkit-font-smoothing: initial')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).font_smoothing() == .auto_
	child.set_attribute_value('style', '-webkit-font-smoothing: unset')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).font_smoothing() == .subpixel_antialiased
	child.set_attribute_value('style', '-webkit-font-smoothing: none')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).font_smoothing() == .none_
}

fn test_webkit_font_smoothing_changes_require_repaint_only() {
	auto_value := &dom.StyleValue{ css_text: 'auto' }
	antialiased := &dom.StyleValue{ css_text: 'antialiased' }
	invalidation := compute_property_invalidation(.webkit_font_smoothing, auto_value, antialiased)
	assert invalidation.needs_repaint()
	assert !invalidation.needs_relayout()
}
