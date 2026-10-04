module html

import dom
import page

fn test_source_initial_top_level_context_finishes_about_blank_and_marks_actual_settings_execution_ready() {
	owner := page.Page.create(1)!
	mut group := BrowsingContextGroup.create(unsafe { &dom.Page(owner) })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(owner) }, none, none)!
	group.append(created.document.get_browsing_context()?)
	mut document := created.document
	defer {
		document.finalize()
		group.finalize()
	}
	window := created.browsing_context.active_window()?
	assert document.url == dom.url_about_blank() && document.get_is_initial_about_blank()
	assert document.document_ready_for_post_load_tasks() && document.is_completely_loaded()
	assert !document.document_completely_loaded_deferred()
	assert document.document_element() != none && document.head() != none && document.body() != none
	assert document.supported_color_schemes()? == ['light', 'dark']
	assert !document.supported_color_schemes_are_only()
	assert window.environment_settings_.settings.environment_.execution_ready
	assert voidptr(document.get_window()?) == voidptr(window)
	assert voidptr(document.get_browsing_context()?.window_proxy().window()?) == voidptr(window)
	assert voidptr(window.associated_document()) == voidptr(document)
	assert voidptr(document.page()) == voidptr(owner)
}

fn test_source_embedded_initial_context_finishes_without_top_level_supported_color_scheme_defaults() {
	owner := page.Page.create(1)!
	url := dom.URL{'https://initial-context-completion.example/parent'}
	mut parent := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	parent.populate_with_html_head_and_body()!
	iframe := parent.create_element_ns(namespace_html, 'iframe')!
	body := parent.body()?
	mut body_node := body.as_node()
	body_node.append_child(iframe.as_node())!
	mut group := BrowsingContextGroup.create(unsafe { &dom.Page(owner) })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(owner) }, parent, iframe)!
	group.append(created.document.get_browsing_context()?)
	mut document := created.document
	defer {
		parent.finalize()
		document.finalize()
		group.finalize()
	}
	window := created.browsing_context.active_window()?
	assert document.document_ready_for_post_load_tasks() && document.is_completely_loaded()
	assert !document.document_completely_loaded_deferred()
	assert window.environment_settings_.settings.environment_.execution_ready
	assert document.supported_color_schemes() == none
	assert document.body() != none && document.get_is_initial_about_blank()
	assert voidptr(document.page()) == voidptr(owner)
	assert document.origin().is_same_origin(parent.origin())
}
