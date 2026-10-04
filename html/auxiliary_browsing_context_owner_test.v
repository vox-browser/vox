module html

import dom
import page

fn test_source_auxiliary_owner_uses_logical_top_level_active_context_instead_of_cached_typed_ancestry() {
	owner := page.Page.create(1)!
	other_owner := page.Page.create(1)!
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	stale := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(other_owner) })!
	mut top_document := created.document
	mut stale_document := stale.document
	mut group := created.browsing_context_group
	mut stale_group := stale.browsing_context_group
	mut top_native := top_document.get_browsing_context()?
	mut stale_native := stale_document.get_browsing_context()?
	top_context := browsing_context_model_for_native(top_native)
	stale_context := browsing_context_model_for_native(stale_native)
	assert top_context.virtual_browsing_context_group_id() == 0
	assert top_context.opener_origin_at_creation() == none
	top_native.virtual_browsing_context_group_id_ = u64(0xfedcba9876543210)
	stale_native.virtual_browsing_context_group_id_ = u64(0x1122334455667788)
	url := dom.URL{'https://auxiliary-owner.example/child'}
	mut opener_document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(opener_document.get_window()?) }
	mut opener := window.browsing_context()
	mut opener_navigable := opener_document.navigable()?
	opener_navigable.parent_ = top_document.navigable()?
	opener_navigable.is_top_level_traversable_ = false
	// Preserve a genuine but different typed ancestry cache. Source selection
	// follows the Document's logical native navigable tree.
	opener.parent_ = stale_context
	assert voidptr(opener.top_level_browsing_context()?) == voidptr(stale_context)
	group.append(opener_document.get_browsing_context()?)
	original_origin := opener_document.origin()
	auxiliary := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(unsafe { &dom.Page(owner) }, opener)!
	mut auxiliary_document := auxiliary.document
	defer {
		top_document.finalize()
		stale_document.finalize()
		opener_document.finalize()
		auxiliary_document.finalize()
		group.finalize()
		stale_group.finalize()
	}
	native := auxiliary_document.get_browsing_context()?
	assert voidptr(auxiliary.browsing_context.group()?) == voidptr(group)
	assert native.group_handle == voidptr(group)
	assert group.browsing_context_set().len == 3 && stale_group.browsing_context_set().len == 1
	assert voidptr(group.browsing_context_set()[2]) == voidptr(native)
	assert voidptr(auxiliary.browsing_context.opener()?) == voidptr(opener)
	assert native.virtual_browsing_context_group_id_ == u64(0xfedcba9876543210)
	assert auxiliary.browsing_context.virtual_browsing_context_group_id() == u64(0xfedcba9876543210)
	assert auxiliary.browsing_context.opener_origin_at_creation()?.is_same_origin(original_origin)
	assert native.opener_origin_at_creation_?.is_same_origin(original_origin)
	assert auxiliary_document.origin().is_same_origin(original_origin)
	assert auxiliary_document.is_completely_loaded() && auxiliary_document.document_ready_for_post_load_tasks()
	opener_document.set_origin(dom.URL{'https://changed-opener.example/after'}.origin())
	assert auxiliary.browsing_context.opener_origin_at_creation()?.is_same_origin(original_origin)
	assert !auxiliary.browsing_context.opener_origin_at_creation()?.is_same_origin(opener_document.origin())
	// Context-owned metadata stays on the retained actual native identity when
	// Document destruction clears its current browsing-context slot.
	auxiliary_document.destroy()
	assert auxiliary_document.get_browsing_context() == none
	assert auxiliary.browsing_context.virtual_browsing_context_group_id() == u64(0xfedcba9876543210)
	assert auxiliary.browsing_context.opener_origin_at_creation()?.is_same_origin(original_origin)
}

fn test_source_auxiliary_owner_rereads_actual_top_level_active_document_and_rejects_missing_active_context() {
	owner := page.Page.create(1)!
	first := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	second := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	mut first_document := first.document
	mut second_document := second.document
	mut first_group := first.browsing_context_group
	mut second_group := second.browsing_context_group
	first_native := first_document.get_browsing_context()?
	mut second_native := second_document.get_browsing_context()?
	first_context := browsing_context_model_for_native(first_native)
	second_native.virtual_browsing_context_group_id_ = u64(0x100000001)
	url := dom.URL{'https://auxiliary-owner.example/replaced-top'}
	mut opener_document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(opener_document.get_window()?) }
	mut opener := window.browsing_context()
	mut top_navigable := first_document.navigable()?
	mut opener_navigable := opener_document.navigable()?
	opener_navigable.parent_ = top_navigable
	opener_navigable.is_top_level_traversable_ = false
	opener.parent_ = first_context
	first_group.append(opener_document.get_browsing_context()?)
	top_navigable.set_active_document(second_document)
	assert voidptr(first_context.active_document()?) == voidptr(first_document)
	assert voidptr(top_navigable.active_browsing_context()?) == voidptr(second_native)
	auxiliary := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(unsafe { &dom.Page(owner) }, opener)!
	mut auxiliary_document := auxiliary.document
	defer {
		first_document.finalize()
		second_document.finalize()
		opener_document.finalize()
		auxiliary_document.finalize()
		first_group.finalize()
		second_group.finalize()
	}
	assert voidptr(auxiliary.browsing_context.group()?) == voidptr(second_group)
	assert auxiliary.browsing_context.virtual_browsing_context_group_id() == u64(0x100000001)
	assert first_group.browsing_context_set().len == 2 && second_group.browsing_context_set().len == 2
	top_navigable.set_active_document(none)
	before := user_agent_browsing_context_group_count()
	if _ := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(unsafe { &dom.Page(owner) }, opener) {
		panic('missing actual top-level active Document must not select a cached context')
	} else {
		assert err.msg() == 'InvalidStateError: opener has no active top-level browsing context'
	}
	assert user_agent_browsing_context_group_count() == before
	assert first_group.browsing_context_set().len == 2 && second_group.browsing_context_set().len == 2
}

fn test_source_context_metadata_getter_uses_retained_native_owner_and_source_u64_default() {
	owner := page.Page.create(1)!
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	mut document := created.document
	mut group := created.browsing_context_group
	defer {
		document.finalize()
		group.finalize()
	}
	mut native := document.get_browsing_context()?
	context := browsing_context_model_for_native(native)
	assert context.virtual_browsing_context_group_id() == 0
	assert native.virtual_browsing_context_group_id_ == 0
	assert context.opener_origin_at_creation() == none
	native.virtual_browsing_context_group_id_ = u64(0x8877665544332211)
	assert context.virtual_browsing_context_group_id() == u64(0x8877665544332211)
	document.set_browsing_context(unsafe { nil })
	assert context.virtual_browsing_context_group_id() == u64(0x8877665544332211)
	context.register_native_identity(native)
	assert context.virtual_browsing_context_group_id() == u64(0x8877665544332211)
}
