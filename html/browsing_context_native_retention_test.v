module html

import dom
import page

fn test_navigation_replacement_and_repeated_actual_window_creation_retain_one_native_context_and_proxy() {
	owner := page.Page.create(1)!
	url := dom.URL{'https://native-context-retention.example/first'}
	mut first := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	first_window := unsafe { &WindowModel(first.get_window()?) }
	context := first_window.browsing_context()
	native := first.get_browsing_context()?
	proxy := native.window_proxy()
	url2 := dom.URL{'https://native-context-retention.example/second'}
	mut second := create_navigation_document_for_page(url2, url2.origin(), first, unsafe { &dom.Page(owner) })!
	defer {
		first.finalize()
		second.finalize()
	}
	second_window := unsafe { &WindowModel(second.get_window()?) }
	assert voidptr(second_window) != voidptr(first_window)
	assert voidptr(second_window.browsing_context()) == voidptr(context)
	assert voidptr(second.get_browsing_context()?) == voidptr(native)
	assert voidptr(context.native_browsing_context_?) == voidptr(native)
	assert voidptr(native.window_proxy()) == voidptr(proxy)
	repeated_window := WindowModel.create(second, context)!
	assert voidptr(repeated_window) != voidptr(second_window)
	assert voidptr(second.get_browsing_context()?) == voidptr(native)
	assert voidptr(native.window_proxy()) == voidptr(proxy)
	assert voidptr(proxy.window()?) == voidptr(repeated_window)
	assert voidptr(repeated_window.associated_document()) == voidptr(second)
	assert voidptr(native.active_document()?) == voidptr(second)
}

fn test_missing_document_context_slot_reuses_actual_owner_after_document_destruction() {
	owner := page.Page.create(1)!
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(unsafe { &dom.Page(owner) })!
	mut first := created.document
	mut group := created.browsing_context_group
	native := first.get_browsing_context()?
	context := browsing_context_model_for_native(native)
	proxy := native.window_proxy()
	first.destroy()
	assert first.get_browsing_context() == none
	assert voidptr(context.native_browsing_context_?) == voidptr(native)
	group.append_model(context)
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	assert group.legacy_pending_model_members_.len == 0
	url := dom.URL{'https://native-context-retention.example/missing-slot'}
	mut replacement := dom.Document.create(url)
	replacement.set_origin(url.origin())
	defer {
		first.finalize()
		replacement.finalize()
		group.finalize()
	}
	assert replacement.get_browsing_context() == none
	window := WindowModel.create(replacement, context)!
	assert voidptr(replacement.get_browsing_context()?) == voidptr(native)
	assert voidptr(context.native_browsing_context_?) == voidptr(native)
	assert voidptr(native.window_proxy()) == voidptr(proxy)
	assert voidptr(proxy.window()?) == voidptr(window)
	assert voidptr(context.active_document()?) == voidptr(replacement)
	assert group.browsing_context_set().len == 1 && group.model_browsing_context_set().len == 1
	assert voidptr(group.browsing_context_set()[0]) == voidptr(native)
	assert native.group_handle == voidptr(group)
}

fn test_actual_navigation_population_reuses_context_for_new_and_preexisting_history_documents() {
	owner := page.Page.create(1)!
	url := dom.URL{'https://native-context-retention.example/active'}
	mut original := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(original.get_window()?) }
	context := window.browsing_context()
	native := original.get_browsing_context()?
	proxy := native.window_proxy()
	mut model := navigable_model_for_host(original.navigable()?)?
	entry := &SessionHistoryEntry{
		url:            dom.URL{'https://native-context-retention.example/populated'}
		document_state: &DocumentState{
			origin:   original.origin()
			resource: '<!doctype html><html><body>populated</body></html>'
		}
	}
	model.populate_session_history_entry_document(entry, SourceSnapshotParams{}, TargetSnapshotParams{}, .none, none, none, none)
	mut populated := entry.document()?
	assert populated.body() != none
	assert voidptr(populated.get_browsing_context()?) == voidptr(native)
	assert voidptr(native.window_proxy()) == voidptr(proxy)
	assert voidptr(browsing_context_model_for_native(native)) == voidptr(context)
	mut preexisting := dom.Document.create(dom.URL{'https://native-context-retention.example/preexisting'})
	preexisting.set_origin(preexisting.url.origin())
	preexisting.populate_with_html_head_and_body()!
	defer {
		original.finalize()
		populated.finalize()
		preexisting.finalize()
	}
	assert preexisting.get_browsing_context() == none
	existing_entry := &SessionHistoryEntry{
		url:            preexisting.url
		document_state: &DocumentState{
			document:       preexisting
			origin:         preexisting.origin()
			ever_populated: true
		}
	}
	model.populate_session_history_entry_document(existing_entry, SourceSnapshotParams{}, TargetSnapshotParams{}, .none, none, none, none)
	assert voidptr(existing_entry.document()?) == voidptr(preexisting)
	assert voidptr(preexisting.get_browsing_context()?) == voidptr(native)
	assert voidptr(context.native_browsing_context_?) == voidptr(native)
	assert voidptr(native.window_proxy()) == voidptr(proxy)
	assert voidptr(context.active_document()?) == voidptr(preexisting)
}
