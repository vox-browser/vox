module html

import dom

fn script_adoption_find_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := script_adoption_find_element(child, local_name) {
			return element
		}
	}
	return none
}

fn test_script_adoption_transfers_document_load_event_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	script_element := old_document.create_element_ns('http://www.w3.org/1999/xhtml', 'script')!
	script := unsafe { &dom.HTMLScriptElement(script_element) }
	mut model := unsafe {
		&HTMLScriptElementModel(html_script_element_model_for_dom_element(script))
	}

	model.begin_delaying_document_load_event(old_document)
	assert old_document.anything_is_delaying_the_load_event()
	assert !new_document.anything_is_delaying_the_load_event()

	new_document.adopt_node(script_element.as_node())
	assert script_element.document().url.serialize() == 'https://new.example/'
	assert model.base_url_.serialize() == 'https://new.example/'
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()
	assert model.document_load_event_delaying_

	model.stop_delaying_document_load_event()
	assert !new_document.anything_is_delaying_the_load_event()
}

fn test_parser_created_script_installs_adoption_hook() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut parser := HTMLParser.create(old_document, '<script src="/app.js"></script>')
	parser.run()
	script_element := script_adoption_find_element(unsafe { &dom.Node(old_document) }, 'script') or {
		panic('missing parser-created script')
	}
	script := unsafe { &dom.HTMLScriptElement(script_element) }
	mut model := unsafe {
		&HTMLScriptElementModel(html_script_element_model_for_dom_element(script))
	}
	model.begin_delaying_document_load_event(old_document)

	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	new_document.adopt_node(script_element.as_node())
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()

	model.stop_delaying_document_load_event()
}
