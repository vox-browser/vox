module html

import dom
import page

fn test_source_group_factory_creates_actual_page_window_document_and_one_native_member_owner() {
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	before := user_agent_browsing_context_group_count()
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	mut group := created.browsing_context_group
	mut document := created.document
	defer {
		document.finalize()
		group.finalize()
	}
	native := document.get_browsing_context()?
	context := browsing_context_model_for_native(native)
	window := context.active_window()?
	assert user_agent_browsing_context_group_count() == before + 1
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	assert voidptr(group.browsing_context_set()[0]) == voidptr(native)
	assert voidptr(group.model_browsing_context_set()[0]) == voidptr(context)
	assert group.legacy_pending_model_members_.len == 0
	assert native.group_handle == voidptr(group) && voidptr(context.group()?) == voidptr(group)
	assert voidptr(group.page()) == voidptr(owner) && voidptr(document.page()) == voidptr(owner)
	assert document.is_html_document() && document.get_is_initial_about_blank()
	assert document.url == dom.url_about_blank() && document.body() != none
	assert document.document_ready_for_post_load_tasks() && document.is_completely_loaded()
	assert window.environment_settings_.settings.environment_.execution_ready
	assert voidptr(window.associated_document()) == voidptr(document)
	assert voidptr(native.window_proxy().window()?) == voidptr(window)
	assert document.as_node().is_scripting_disabled()
	group.append(native)
	group.append_model(context)
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
}

fn test_source_context_constructor_leaves_group_append_to_caller_and_member_removal_uses_native_identity() {
	owner := page.Page.create(1)!
	mut group := BrowsingContextGroup.create(unsafe { &dom.Page(owner) })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(owner) }, none, none)!
	mut document := created.document
	defer {
		document.finalize()
		group.finalize()
	}
	mut context := created.browsing_context
	native := document.get_browsing_context()?
	assert context.group() == none && native.group_handle == unsafe { nil }
	assert group.browsing_context_set().len == 0 && group.model_browsing_context_set().len == 0
	group.append(native)
	assert native.group_handle == voidptr(group) && voidptr(context.group()?) == voidptr(group)
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	// Actual membership has one native owner even if the Document loses the
	// context slot before the existing context-removal adapter runs.
	document.destroy()
	assert document.get_browsing_context() == none
	context.remove()
	assert group.browsing_context_set().len == 0 && group.model_browsing_context_set().len == 0
	assert native.group_handle == unsafe { nil } && context.group() == none
	assert voidptr(browsing_context_model_for_native(native)) == voidptr(context)
}

fn test_legacy_pre_native_member_is_promoted_into_the_same_actual_native_set_at_window_construction() {
	owner := page.Page.create(1)!
	mut group := BrowsingContextGroup.create(unsafe { &dom.Page(owner) })
	mut document := dom.Document.create(dom.URL{'https://group-owner.example/pre-native'})
	document.set_origin(document.url.origin())
	defer {
		document.finalize()
		group.finalize()
	}
	context := BrowsingContextModel.create(document, none, 'pending')
	group.append_model(context)
	assert document.get_browsing_context() == none
	assert group.browsing_context_set().len == 0 && group.model_browsing_context_set().len == 1
	assert group.legacy_pending_model_members_.len == 1
	window := WindowModel.create(document, context)!
	native := document.get_browsing_context()?
	assert voidptr(window.browsing_context()) == voidptr(context)
	assert group.legacy_pending_model_members_.len == 0
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	assert voidptr(group.browsing_context_set()[0]) == voidptr(native)
	assert voidptr(group.model_browsing_context_set()[0]) == voidptr(context)
	assert native.group_handle == voidptr(group)
	group.append_model(context)
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
}

fn test_auxiliary_caller_appends_actual_created_context_before_exposing_its_group_and_opener() {
	owner := page.Page.create(1)!
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	mut group := created.browsing_context_group
	mut original := created.document
	context := browsing_context_model_for_native(original.get_browsing_context()?)
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(original.navigable()?)
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.set_top_level_traversable(traversable)
	auxiliary := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(unsafe { &dom.Page(owner) }, context)!
	mut auxiliary_document := auxiliary.document
	defer {
		original.finalize()
		auxiliary_document.finalize()
		group.finalize()
	}
	auxiliary_native := auxiliary_document.get_browsing_context()?
	assert group.browsing_context_set().len == 2 && group.model_browsing_context_set().len == 2
	assert group.legacy_pending_model_members_.len == 0
	assert voidptr(group.browsing_context_set()[1]) == voidptr(auxiliary_native)
	assert auxiliary_native.group_handle == voidptr(group)
	assert voidptr(auxiliary.browsing_context.group()?) == voidptr(group)
	assert voidptr(auxiliary.browsing_context.opener()?) == voidptr(context)
}
