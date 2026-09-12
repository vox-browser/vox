module css

import dom

fn test_text_decoration_skip_ink_parsing_and_metadata() {
	for value in ['auto', 'all', 'none', 'AuTo'] {
		parsed := parse_css_value_logic(.text_decoration_skip_ink, value) or {
			panic('${value} did not parse')
		}
		assert parsed.serialize(.normal) == value.to_lower()
	}
	assert parse_css_value_logic(.text_decoration_skip_ink, 'always') == none
	assert property_id_from_string('text-decoration-skip-ink')? == .text_decoration_skip_ink
	assert string_from_property_id(.text_decoration_skip_ink) == 'text-decoration-skip-ink'
	assert property_initial_value_string(.text_decoration_skip_ink) == 'auto'
	assert is_inherited_property(.text_decoration_skip_ink)
	assert animation_type_from_longhand_property(.text_decoration_skip_ink) == .discrete
	assert is_animatable_property(.text_decoration_skip_ink)
	assert PropertyID.text_decoration_skip_ink in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.text_decoration_skip_ink) == [
		PropertyID.all,
	]
	assert pseudo_element_supports_property(.selection, .text_decoration_skip_ink)
}

fn test_text_decoration_skip_ink_computes_and_inherits() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	parent.set_attribute_value('style', 'text-decoration-skip-ink: none')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_style := computer.compute_style(parent_abstract)
	assert parent_style.text_decoration_skip_ink() == .none_
	parent_abstract.set_computed_properties(computed_properties_to_dom(parent_style))
	child_style := computer.compute_style(dom.AbstractElement.new(child, none))
	assert child_style.text_decoration_skip_ink() == .none_
	assert resolve_computed_values(child_style).text_decoration_skip_ink() == .none_

	child.set_attribute_value('style', 'text-decoration-skip-ink: all')
	all_style := computer.compute_style(dom.AbstractElement.new(child, none))
	assert all_style.text_decoration_skip_ink() == .all
}
