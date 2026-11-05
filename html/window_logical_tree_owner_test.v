module html

import dom
import page

fn window_logical_tree_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn window_logical_tree_parent(document &dom.Document, parent &dom.Document) {
	mut navigable := document.navigable() or { panic('missing actual navigable') }
	navigable.parent_ = parent.navigable() or { panic('missing actual logical parent') }
	navigable.is_top_level_traversable_ = false
}

fn test_window_top_and_parent_use_actual_logical_chain_across_independent_contexts() {
	mut top, top_window := window_logical_tree_document('https://window-logical-top.example/')!
	mut parent, parent_window := window_logical_tree_document('https://window-logical-parent.example/')!
	mut child, child_window := window_logical_tree_document('https://window-logical-child.example/')!
	mut unrelated, unrelated_window := window_logical_tree_document('https://window-logical-unrelated.example/')!
	defer {
		top.finalize()
		parent.finalize()
		child.finalize()
		unrelated.finalize()
	}
	window_logical_tree_parent(parent, top)
	window_logical_tree_parent(child, parent)
	mut native := child.navigable()?
	native.container_document_ = unrelated
	// Both cached local owners deliberately disagree with the logical parent.
	mut context := child_window.browsing_context()
	context.parent_ = unrelated_window.browsing_context()
	assert parent_window.browsing_context().parent() == none
	assert child_window.Window.top()? == top.get_browsing_context()?.window_proxy()
	assert child_window.Window.parent()? == parent.get_browsing_context()?.window_proxy()
	assert child_window.top()? == top_window.window()
	assert child_window.parent()? == parent_window.window()
	assert parent_window.top()? == top_window.window()
	assert top_window.top()? == top_window.window()
	assert top_window.parent()? == top_window.window()
	foreign := dom.URL{value: 'https://outside-logical-window.example/'}.origin()
	assert child_window.window().get_own_property(foreign, 'top')!.descriptor.value.object_data == voidptr(top_window.window())
	assert child_window.window().get_own_property(foreign, 'parent')!.descriptor.value.object_data == voidptr(parent_window.window())
}

fn test_window_root_parent_uses_active_native_proxy_slot_and_stable_proxy_identity() {
	mut top, window := window_logical_tree_document('https://window-logical-retarget.example/')!
	mut replacement, replacement_window := window_logical_tree_document('https://replacement-logical-slot.example/')!
	defer {
		top.finalize()
		replacement.finalize()
	}
	proxy := window.window()
	native_proxy := top.get_browsing_context()?.window_proxy()
	replacement_native := replacement.get_window()?
	native_proxy.set_window(replacement_native)
	assert proxy.window() == replacement_window
	assert window.Window.parent()? == native_proxy
	assert window.Window.top()? == native_proxy
	assert window.parent()? == proxy
	assert window.top()? == proxy
	// Retargeting the slot does not change which proxy the navigable owns.
	assert window.parent()? != replacement_window.window()
}

fn test_window_logical_getters_follow_actual_document_swap_then_restore_original_tree() {
	mut original, mut window := window_logical_tree_document('https://window-logical-swap.example/original')!
	mut replacement, _ := window_logical_tree_document('https://replacement-logical-swap.example/current')!
	mut top, top_window := window_logical_tree_document('https://new-logical-swap-top.example/')!
	mut parent, parent_window := window_logical_tree_document('https://new-logical-swap-parent.example/')!
	defer {
		original.finalize()
		replacement.finalize()
		top.finalize()
		parent.finalize()
	}
	window_logical_tree_parent(parent, top)
	window_logical_tree_parent(replacement, parent)
	assert window.top()? == window.window()
	assert window.parent()? == window.window()
	window.set_associated_document(replacement)
	assert window.browsing_context().parent() == none
	assert window.top()? == top_window.window()
	assert window.parent()? == parent_window.window()
	window.set_associated_document(original)
	assert window.top()? == window.window()
	assert window.parent()? == window.window()
}

fn test_window_logical_getters_return_none_without_navigable_or_active_parent_proxy() {
	mut top, top_window := window_logical_tree_document('https://window-logical-missing.example/top')!
	mut child, child_window := window_logical_tree_document('https://window-logical-missing.example/child')!
	defer {
		top.finalize()
		child.finalize()
	}
	window_logical_tree_parent(child, top)
	mut parent_navigable := top.navigable()?
	parent_navigable.set_active_document(none)
	assert child.navigable() != none
	assert child_window.Window.top() == none && child_window.Window.parent() == none
	assert child_window.top() == none && child_window.parent() == none
	assert top_window.Window.top() == none && top_window.Window.parent() == none
	assert top_window.top() == none && top_window.parent() == none
	assert child_window.window().get_own_property(child.origin(), 'top')!.descriptor.value.kind == .null_
	assert child_window.window().get_own_property(child.origin(), 'parent')!.descriptor.value.kind == .null_
	child.set_navigable(none)
	assert child_window.Window.top() == none && child_window.Window.parent() == none
	assert child_window.top() == none && child_window.parent() == none
}
