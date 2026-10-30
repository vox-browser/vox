module css

import dom

fn test_hyphens_parsing_and_metadata() {
	for text in ['none', 'manual', 'auto', 'AuTo'] {
		value := parse_css_value_logic(.hyphens, text) or { panic('invalid hyphens value') }
		assert value.serialize(.normal) == text.to_lower()
	}
	for text in ['normal', 'automatic', 'auto none', '1'] {
		assert parse_css_value_logic(.hyphens, text) == none
	}
	assert property_id_from_string('hyphens')? == .hyphens
	assert property_id_from_string('-webkit-hyphens') == none
	assert string_from_property_id(.hyphens) == 'hyphens'
	assert property_initial_value_string(.hyphens) == 'manual'
	assert is_inherited_property(.hyphens)
	assert property_affects_layout(.hyphens)
	assert animation_type_from_longhand_property(.hyphens) == .discrete
	assert is_animatable_property(.hyphens)
	assert PropertyID.hyphens in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.hyphens) == [PropertyID.all]
	assert property_id_from_longhand_index(354)? == .hyphens
	assert property_id_from_longhand_index(355)? == .webkit_font_smoothing
}

fn test_hyphens_inherits_and_reaches_resolved_values() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div') or { panic(err) }
	mut child := document.create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	assert computer.compute_style(dom.AbstractElement.new(child, none)).hyphens() == .manual
	parent.set_attribute_value('style', 'hyphens:auto')
	mut abstract := dom.AbstractElement.new(parent, none)
	style := computer.compute_style(abstract)
	abstract.set_computed_properties(computed_properties_to_dom(style))
	inherited := computer.compute_style(dom.AbstractElement.new(child, none))
	assert inherited.hyphens() == .auto_
	assert resolve_computed_values(inherited).hyphens() == .auto_
	child.set_attribute_value('style', 'hyphens:none')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).hyphens() == .none_
	child.set_attribute_value('style', 'hyphens:initial')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).hyphens() == .manual
	child.set_attribute_value('style', 'hyphens:unset')
	assert computer.compute_style(dom.AbstractElement.new(child, none)).hyphens() == .auto_
}

fn test_hyphens_changes_require_layout_invalidation() {
	manual := &dom.StyleValue{ css_text: 'manual' }
	auto_value := &dom.StyleValue{ css_text: 'auto' }
	assert compute_property_invalidation(.hyphens, manual, auto_value).needs_relayout()
}
