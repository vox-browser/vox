module css

import dom

fn custom_state_test_element(document &dom.Document, id string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'state-widget') or {
		panic(err)
	}
	element.set_attribute_value('id', id)
	element.set_custom_element_state(.custom)
	return element
}

fn test_custom_state_set_matches_state_pseudo_class() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := custom_state_test_element(document, 'root')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }

	assert !element_matches_selector(root, ':state(--active)')
	mut states := root.ensure_custom_state_set()
	states.add_state('--active')
	assert element_matches_selector(root, ':state(--active)')
	assert !element_matches_selector(root, ':state(--inactive)')
	assert states.set_size() == 1
	assert states.states() == ['--active']
	assert states.element()? == root

	assert states.remove_state('--active')
	assert !element_matches_selector(root, ':state(--active)')
}

fn test_custom_state_selector_participates_in_dom_queries() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut first := custom_state_test_element(document, 'first')
	mut second := custom_state_test_element(document, 'second')
	first.ensure_custom_state_set().add_state('--selected')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic(err) }
	root_node.append_child(second.as_node()) or { panic(err) }

	matched := query_selector(root.as_node(), ':state(--selected)') or {
		panic('custom-state selector did not match')
	}
	assert matched == first
	first.ensure_custom_state_set().clear_states()
	assert query_selector(root.as_node(), ':state(--selected)') == none
}
