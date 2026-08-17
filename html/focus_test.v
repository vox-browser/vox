module html

import dom

fn focus_test_find(node &dom.Node, id string) ?&dom.Element {
	if element := node.as_element() {
		if element.get_attribute_value('id') == id {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := focus_test_find(child, id) {
			return element
		}
	}
	return none
}

fn test_focusing_and_unfocusing_updates_document_and_fires_events() {
	document :=
		parse_document('<button id="one" tabindex="0"></button><button id="two" tabindex="0"></button>')
	one := focus_test_find(unsafe { &dom.Node(document) }, 'one')?
	two := focus_test_find(unsafe { &dom.Node(document) }, 'two')?
	mut manager := FocusManager.create()
	run_focusing_steps(mut manager, one.as_node(), none, .click)
	assert document.focused_area()? == one.as_node()
	assert manager.events.map(it.type_) == ['focus', 'focusin']
	run_focusing_steps(mut manager, two.as_node(), none, .key)
	assert document.focused_area()? == two.as_node()
	assert manager.events.map(it.type_) == ['focus', 'focusin', 'blur', 'focusout', 'focus',
		'focusin']
	assert manager.events[2].related_target_id? == two.as_node().unique_id().value()
	run_unfocusing_steps(mut manager, two.as_node())
	assert document.focused_area() == none
	assert manager.events.last().type_ == 'focusout'
}

fn test_focusing_ignores_inert_and_uses_fallback() {
	document :=
		parse_document('<button id="inert" inert tabindex="0"></button><button id="fallback" tabindex="0"></button>')
	inert := focus_test_find(unsafe { &dom.Node(document) }, 'inert')?
	fallback := focus_test_find(unsafe { &dom.Node(document) }, 'fallback')?
	mut manager := FocusManager.create()
	run_focusing_steps(mut manager, inert.as_node(), fallback.as_node(), .focus)
	assert manager.currently_focused_area == none
	run_focusing_steps(mut manager, none, fallback.as_node(), .focus)
	assert manager.currently_focused_area? == fallback.as_node()
}
