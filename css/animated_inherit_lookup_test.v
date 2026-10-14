module css

import dom

fn test_inherited_animation_lookup_keeps_transition_flags_and_missing_values() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	mut computed := ComputedProperties.new()
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	parent_abstract.set_computed_properties(computed_properties_to_dom(computed))
	subject := dom.AbstractElement.new(child, none)
	assert StyleComputer.get_animated_inherit_value(.color, subject) == none
	color := parse_css_value(ParsingParams{}, 'red', .color) or { panic('invalid test color') }
	computed.set_animated_property(.color, color, .yes, .no)
	animated := StyleComputer.get_animated_inherit_value(.color, subject) or { panic('missing animated inheritance') }
	assert voidptr(animated.value) == voidptr(color)
	assert animated.is_result_of_transition == .yes
	assert StyleComputer.get_animated_inherit_value(.opacity, subject) == none
}
