module html

import dom
import page

fn test_source_top_level_creation_returns_actual_first_context_and_same_loaded_document() {
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	before := user_agent_browsing_context_group_count()
	created := create_a_new_top_level_browsing_context_and_document(unsafe { &dom.Page(owner) })!
	context := created.browsing_context
	mut document := created.document
	mut group := context.group()?
	defer {
		document.finalize()
		group.finalize()
	}
	native := document.get_browsing_context()?
	window := context.active_window()?
	assert user_agent_browsing_context_group_count() == before + 1
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	assert voidptr(group.browsing_context_set()[0]) == voidptr(native)
	assert voidptr(group.model_browsing_context_set()[0]) == voidptr(context)
	assert native.html_model_handle_ == voidptr(context)
	assert voidptr(context.active_document()?) == voidptr(document)
	assert voidptr(window.associated_document()) == voidptr(document)
	assert voidptr(native.window_proxy().window()?) == voidptr(window)
	assert voidptr(group.page()) == voidptr(owner) && voidptr(document.page()) == voidptr(owner)
	assert document.is_html_document() && document.get_is_initial_about_blank()
	assert document.url == dom.url_about_blank() && document.body() != none
	assert document.document_ready_for_post_load_tasks() && document.is_completely_loaded()
	assert window.environment_settings_.settings.environment_.execution_ready
	assert document.as_node().is_scripting_disabled()
}

fn test_source_top_level_creation_returns_independent_context_owners_for_each_new_group_on_same_page() {
	owner := page.Page.create(1)!
	before := user_agent_browsing_context_group_count()
	first := create_a_new_top_level_browsing_context_and_document(unsafe { &dom.Page(owner) })!
	second := create_a_new_top_level_browsing_context_and_document(unsafe { &dom.Page(owner) })!
	mut first_document := first.document
	mut second_document := second.document
	mut first_group := first.browsing_context.group()?
	mut second_group := second.browsing_context.group()?
	defer {
		first_document.finalize()
		second_document.finalize()
		first_group.finalize()
		second_group.finalize()
	}
	assert user_agent_browsing_context_group_count() == before + 2
	assert voidptr(first_group) != voidptr(second_group)
	assert voidptr(first.browsing_context) != voidptr(second.browsing_context)
	assert voidptr(first_document) != voidptr(second_document)
	assert voidptr(first_group.browsing_context_set()[0]) == voidptr(first_document.get_browsing_context()?)
	assert voidptr(second_group.browsing_context_set()[0]) == voidptr(second_document.get_browsing_context()?)
	assert voidptr(first.browsing_context.active_window()?) != voidptr(second.browsing_context.active_window()?)
	assert voidptr(first.browsing_context.active_document()?) == voidptr(first_document)
	assert voidptr(second.browsing_context.active_document()?) == voidptr(second_document)
	assert voidptr(first_document.page()) == voidptr(owner) && voidptr(second_document.page()) == voidptr(owner)
}
