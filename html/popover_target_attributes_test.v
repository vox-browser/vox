module html

import dom

fn test_popover_target_resolution_and_activation() {
	mut document := &dom.Document{}
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	button := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or { panic(err) }
	popover_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut mutable_button := button
	mut mutable_popover_element := popover_element
	mutable_button.set_attribute_value('popovertarget', 'menu')
	mutable_popover_element.set_attribute_value('id', 'menu')
	mutable_popover_element.set_attribute_value('popover', 'auto')
	mut root_node := root.as_node()
	root_node.append_child(button.as_node()) or { panic(err) }
	root_node.append_child(popover_element.as_node()) or { panic(err) }

	resolved := PopoverTargetAttributes.get_the_popover_target_element(button.as_node()) or {
		panic('target not resolved')
	}
	assert voidptr(resolved) == voidptr(popover_element)
	PopoverTargetAttributes.popover_target_activation_behaviour(button.as_node(), button.as_node())
	assert resolved.popover_visibility_state() == .showing
	PopoverTargetAttributes.popover_target_activation_behaviour(button.as_node(), button.as_node())
	assert resolved.popover_visibility_state() == .hidden
}

fn test_explicit_popover_target_is_cleared_by_attribute_change() {
	document := &dom.Document{}
	button := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or { panic(err) }
	target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut attributes := PopoverTargetAttributes.create(button)
	attributes.set_popover_target_element(target)
	assert attributes.popover_target_element() or { panic('missing target') } == target
	attributes.associated_attribute_changed('id', none)
	assert attributes.popover_target_element() != none
	attributes.associated_attribute_changed('popovertarget', none)
	assert attributes.popover_target_element() == none
}
