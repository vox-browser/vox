module css

import dom

fn inherited_parent_test_color(element &dom.Element) string {
	abstract := dom.AbstractElement.new(element, none)
	style := computed_properties_from_dom(abstract.computed_properties() or { panic('missing style') }) or { panic('missing handle') }
	return (style.property(.color, .yes) or { panic('missing color') }).css_text
}

fn test_borrowed_inherited_parent_reads_live_base_animation_and_transition_stores() {
	mut parent := ComputedProperties.new()
	red := parse_css_value(ParsingParams{}, 'red', .color) or { panic('red') }
	blue := parse_css_value(ParsingParams{}, 'blue', .color) or { panic('blue') }
	parent.set_property(.color, red, .no, .no)
	assert voidptr(non_animated_inherit_value_from_parent(.color, parent)) == voidptr(red)
	assert animated_inherit_value_from_parent(.color, parent) == none
	parent.set_animated_property(.color, blue, .yes, .no)
	first := animated_inherit_value_from_parent(.color, parent) or { panic('animated value') }
	assert voidptr(first.value) == voidptr(blue) && first.is_result_of_transition == .yes
	parent.set_animated_property(.color, red, .no, .no)
	second := animated_inherit_value_from_parent(.color, parent) or { panic('animated value') }
	assert voidptr(second.value) == voidptr(red) && second.is_result_of_transition == .no
	parent.set_property(.color, blue, .no, .no)
	assert voidptr(non_animated_inherit_value_from_parent(.color, parent)) == voidptr(blue)
	parent.remove_animated_property(.color)
	assert animated_inherit_value_from_parent(.color, parent) == none
	assert animated_inherit_value_from_parent(.color, none) == none
	assert non_animated_inherit_value_from_parent(.color, none).css_text == computed_interpolation_property_initial_value(.color).css_text
}

fn test_inherited_refresh_keeps_own_animation_and_updates_inherited_transition_flags() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	parent.set_attribute_value('style', 'color:red')
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	mut source := computer.recompute_style(mut parent_abstract)
	mut target := computer.recompute_style(mut child_abstract)
	blue := parse_css_value(ParsingParams{}, 'blue', .color) or { panic('blue') }
	green := parse_css_value(ParsingParams{}, 'green', .color) or { panic('green') }
	source.set_animated_property(.color, blue, .yes, .no)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert voidptr(target.animated_property_value(.color) or { panic('animated child') }) == voidptr(blue)
	assert target.is_animated_property_inherited(.color) && target.is_animated_property_result_of_transition(.color)
	source.set_animated_property(.color, blue, .no, .no)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert target.is_animated_property_inherited(.color) && !target.is_animated_property_result_of_transition(.color)
	target.set_animated_property(.color, green, .no, .no)
	source.remove_animated_property(.color)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert voidptr(target.animated_property_value(.color) or { panic('animated child') }) == voidptr(green)
	assert !target.is_animated_property_inherited(.color)
	target.set_animated_property(.color, green, .no, .yes)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert !target.has_animated_property(.color)
}

fn test_inherited_refresh_resolves_reparenting_override_and_orphan_again_each_call() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut first := document.create_element('div')!
	first.set_attribute_value('style', 'color:red;font-size:20px')
	mut second := document.create_element('div')!
	second.set_attribute_value('style', 'color:blue;font-size:10px')
	mut child := document.create_element('span')!
	child.set_attribute_value('style', 'font-size:2em')
	mut first_node := first.as_node()
	first_node.append_child(child.as_node())!
	computer := StyleComputer.new(document)
	mut first_abstract := dom.AbstractElement.new(first, none)
	mut second_abstract := dom.AbstractElement.new(second, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	computer.recompute_style(mut first_abstract)
	computer.recompute_style(mut second_abstract)
	mut target := computer.recompute_style(mut child_abstract)
	assert inherited_parent_test_color(child) == 'rgb(255, 0, 0)' && target.font_size().to_double() == 40
	mut second_node := second.as_node()
	second_node.append_child(child.as_node())!
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert inherited_parent_test_color(child) == 'rgb(0, 0, 255)' && target.font_size().to_double() == 20
	child.set_attribute_value('style', 'font-size:inherit')
	target = computer.recompute_style(mut child_abstract)
	child_abstract.set_inheritance_override(first)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert inherited_parent_test_color(child) == 'rgb(255, 0, 0)' && target.font_size().to_double() == 20
	mut child_node := child.as_node()
	child_node.remove(false)
	child_abstract = dom.AbstractElement.new(child, none)
	computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	mut orphan := document.create_element('span')!
	orphan.set_attribute_value('style', 'font-size:inherit')
	mut orphan_abstract := dom.AbstractElement.new(orphan, none)
	reference := computer.recompute_style(mut orphan_abstract)
	assert inherited_parent_test_color(child) == inherited_parent_test_color(orphan)
	assert target.font_size().to_double() == reference.font_size().to_double()
}
