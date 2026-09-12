module html

import dom

fn test_stylesheet_link_adoption_transfers_document_load_event_delay() {
	mut old_document := dom.Document.create(dom.URL{ value: 'https://old.example/' })
	mut new_document := dom.Document.create(dom.URL{ value: 'https://new.example/' })
	link_element := old_document.create_element_ns(dom.namespace_html_uri, 'link')!
	link := unsafe { &dom.HTMLLinkElement(link_element) }
	mut model := unsafe {
		&HTMLLinkElementModel(html_link_element_model_for_dom_element(link))
	}
	model.set_rel('stylesheet')
	mut request := LinkRequest{
		url: dom.url_about_blank()
	}

	assert model.stylesheet_linked_resource_fetch_setup_steps(mut request)
	assert old_document.anything_is_delaying_the_load_event()
	assert !new_document.anything_is_delaying_the_load_event()

	new_document.adopt_node(link_element.as_node())
	assert voidptr(link_element.document()) == voidptr(new_document)
	assert model.base_url_.serialize() == 'https://new.example/'
	assert !old_document.anything_is_delaying_the_load_event()
	assert new_document.anything_is_delaying_the_load_event()
	assert model.document_load_event_delaying_

	model.finished_loading_critical_style_subresources(false)
	assert !new_document.anything_is_delaying_the_load_event()
}

fn test_removing_stylesheet_link_releases_document_load_event_delay() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	link_element := document.create_element_ns(dom.namespace_html_uri, 'link')!
	link := unsafe { &dom.HTMLLinkElement(link_element) }
	mut model := unsafe {
		&HTMLLinkElementModel(html_link_element_model_for_dom_element(link))
	}
	model.set_rel('stylesheet')
	mut request := LinkRequest{
		url: dom.url_about_blank()
	}
	assert model.stylesheet_linked_resource_fetch_setup_steps(mut request)
	assert document.anything_is_delaying_the_load_event()

	model.removed()
	assert !document.anything_is_delaying_the_load_event()
}
