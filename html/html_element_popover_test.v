module html

import dom

fn active_popover_document() &dom.Document {
	mut document := dom.Document.create(dom.URL{
		value: 'https://example.test/'
	})
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut document_node := unsafe { &dom.Node(document) }
	html_root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	document_node.append_child(html_root.as_node()) or { panic(err) }
	return document
}

fn append_popover_element(document &dom.Document, parent &dom.Node, id string, mode string) &dom.HTMLElement {
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut mutable_element := element
	mutable_element.set_attribute_value('id', id)
	mutable_element.set_attribute_value('popover', mode)
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return unsafe { &dom.HTMLElement(element) }
}

fn test_popover_reflection_and_validity() {
	assert html_element_popover_value_to_state(none) == none
	assert html_element_popover_value_to_state('') or { '' } == 'auto'
	assert html_element_popover_value_to_state('AUTO') or { '' } == 'auto'
	assert html_element_popover_value_to_state('hint') or { '' } == 'hint'
	assert html_element_popover_value_to_state('anything') or { '' } == 'manual'

	document := active_popover_document()
	detached := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut mutable_detached := detached
	mutable_detached.set_attribute_value('popover', 'auto')
	if _ := html_element_check_popover_validity(unsafe { &dom.HTMLElement(detached) }, .no, .yes, none, .no) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}

fn test_auto_hint_and_manual_popover_stacks() {
	document := active_popover_document()
	root := document.document_element() or { panic('missing root') }
	first := append_popover_element(document, root.as_node(), 'first', 'auto')
	second := append_popover_element(document, root.as_node(), 'second', 'auto')

	html_element_show_popover(first, .yes, none)!
	assert first.popover_visibility_state() == .showing
	assert popover_element(first).in_top_layer()
	assert document.showing_auto_popover_list().len == 1
	assert html_element_popover_stack_position(first) == 1

	// A new unrelated auto popover closes the existing auto stack.
	html_element_show_popover(second, .yes, none)!
	assert first.popover_visibility_state() == .hidden
	assert second.popover_visibility_state() == .showing
	assert document.showing_auto_popover_list().len == 1
	assert voidptr(document.showing_auto_popover_list().last()) == voidptr(second)

	// A hint nested inside the open auto popover is appended to that auto stack.
	hint := append_popover_element(document, popover_element(second).as_node(), 'hint', 'hint')
	html_element_show_popover(hint, .yes, none)!
	assert second.popover_visibility_state() == .showing
	assert hint.popover_visibility_state() == .showing
	assert document.showing_auto_popover_list().len == 2
	assert document.showing_hint_popover_list().len == 0
	assert html_element_popover_stack_position(hint) == 2

	html_element_hide_popover_for_bindings(hint)!
	assert hint.popover_visibility_state() == .hidden
	assert document.showing_auto_popover_list().len == 1

	manual := append_popover_element(document, root.as_node(), 'manual', 'manual')
	html_element_show_popover(manual, .yes, none)!
	assert manual.popover_visibility_state() == .showing
	assert popover_element(manual).in_top_layer()
	assert document.showing_auto_popover_list().len == 1
	assert html_element_toggle_popover(manual, TogglePopoverOptions{ force: false })! == false
	assert manual.popover_visibility_state() == .hidden
}

fn test_popover_ancestor_and_light_dismiss_helpers() {
	document := active_popover_document()
	root := document.document_element() or { panic('missing root') }
	popover := append_popover_element(document, root.as_node(), 'menu', 'auto')
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut popover_node := unsafe { &dom.Node(popover_element(popover)) }
	popover_node.append_child(child.as_node()) or { panic(err) }
	html_element_show_popover(popover, .yes, none)!

	assert voidptr(html_element_nearest_inclusive_open_popover(unsafe { &dom.HTMLElement(child) }) or {
		panic('missing open popover')}) == voidptr(popover)
	assert voidptr(html_element_topmost_clicked_popover(child.as_node()) or {
		panic('missing clicked popover')}) == voidptr(popover)

	down := dom.PointerEvent.create('pointerdown', dom.PointerEventInit{})
	up := dom.PointerEvent.create('pointerup', dom.PointerEventInit{})
	html_element_light_dismiss_open_popovers(down, root.as_node())
	html_element_light_dismiss_open_popovers(up, root.as_node())
	assert popover.popover_visibility_state() == .hidden
}
