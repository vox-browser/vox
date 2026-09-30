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

fn test_design_mode_resets_selection_once_and_runs_focusing_steps() {
	document := parse_document('<input id="control"><p id="text">hello</p>')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{})
	root := document.document_element() or { panic('missing document element') }
	control := document.get_element_by_id('control') or { panic('missing control') }
	paragraph := document.get_element_by_id('text') or { panic('missing paragraph') }
	text := paragraph.as_node().first_child() or { panic('missing text') }
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.set_base_and_extent(text, 1, text, 4)!
	mut manager := FocusManager.create()
	run_focusing_steps(mut manager, control.as_node(), none, .key)
	mutable_document.set_design_mode('on')!
	assert selection.is_collapsed()
	assert selection.anchor_node() or { panic('missing anchor') } == document.as_node()
	assert selection.anchor_offset() == 0
	assert document.focused_area() or { panic('missing focus') } == root.as_node()
	assert document.last_focus_trigger_() == .other

	selection.set_base_and_extent(text, 1, text, 4)!
	mutable_document.set_design_mode('ON')!
	assert selection.to_string() == 'ell'
	mutable_document.set_design_mode('off')!
	assert selection.to_string() == 'ell'
}
