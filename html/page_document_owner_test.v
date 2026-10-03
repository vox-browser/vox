module html

import dom
import page

fn test_source_browsing_context_constructor_retains_its_own_page_before_initial_document() {
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	other := page.Page.create(1)!
	group := BrowsingContextGroup.create(unsafe { &dom.Page(other) })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(owner) }, none, none, group)!
	assert voidptr(created.browsing_context.page()?) == voidptr(owner)
	assert voidptr(created.document.page()) == voidptr(owner)
	assert created.document.as_node().is_scripting_disabled()
	assert created.document.get_window() != none
	assert created.document.relevant_settings_object() != unsafe { nil }
}

fn test_source_navigation_preserves_previous_context_page_when_group_and_requested_owner_differ() {
	mut nested_owner := page.Page.create(1)!
	top_owner := page.Page.create(1)!
	group := BrowsingContextGroup.create(unsafe { &dom.Page(top_owner) })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(nested_owner) }, none, none, group)!
	nested_owner.set_is_scripting_enabled(false)
	url := dom.URL{'https://nested.example/next'}
	replacement := create_navigation_document_for_page(url, url.origin(), created.document, unsafe { &dom.Page(top_owner) })!
	assert voidptr(replacement.page()) == voidptr(nested_owner)
	assert voidptr(created.browsing_context.page()?) == voidptr(nested_owner)
	assert replacement.as_node().is_scripting_disabled()
	assert voidptr(replacement.get_browsing_context()?) == voidptr(created.document.get_browsing_context()?)
}

fn test_source_navigation_inherits_actual_previous_page_through_existing_entry_point() {
	owner := page.Page.create(1)!
	url := dom.URL{'https://owner.example/first'}
	first := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	second_url := dom.URL{'https://owner.example/second'}
	second := create_navigation_document(second_url, second_url.origin(), first)!
	assert voidptr(first.page()) == voidptr(owner)
	assert voidptr(second.page()) == voidptr(owner)
	assert first.relevant_settings_object() != second.relevant_settings_object()
}
