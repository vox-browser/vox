module html

import dom
import page

fn window_child_tree_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.populate_with_html_head_and_body()!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn window_child_tree_container(document &dom.Document) !&dom.Element {
	element := document.create_element_ns(namespace_html, 'iframe')!
	body := document.body() or { return error('missing actual body') }
	mut body_node := body.as_node()
	body_node.append_child(element.as_node())!
	return element
}

fn window_child_tree_child(parent &dom.Document, container &dom.Element, address string) !(&dom.Document, &WindowModel) {
	document, window := window_child_tree_document(address)!
	mut navigable := document.navigable() or { return error('missing actual child navigable') }
	navigable.parent_ = parent.navigable() or { return error('missing actual parent navigable') }
	navigable.is_top_level_traversable_ = false
	navigable.container_ = container.as_node()
	navigable.container_document_ = parent
	return document, window
}

fn window_child_tree_proxy_value(proxy &WindowProxyModel, origin dom.Origin, key string) !voidptr {
	result := proxy.get_own_property(origin, key)!
	assert result.found && result.descriptor.value.kind == .object
	assert !result.descriptor.writable && result.descriptor.enumerable && result.descriptor.configurable
	return result.descriptor.value.object_data
}

fn test_window_child_length_and_indexed_proxy_follow_live_document_tree_order_and_removal() {
	mut top, window := window_child_tree_document('https://window-child-tree.example/')!
	first := window_child_tree_container(top)!
	second := window_child_tree_container(top)!
	// Register the second child first; Source sorts by actual container tree order.
	mut second_document, second_window := window_child_tree_child(top, second, 'https://foreign-window-child.example/second')!
	mut first_document, first_window := window_child_tree_child(top, first, 'https://window-child-tree.example/first')!
	defer {
		top.finalize()
		first_document.finalize()
		second_document.finalize()
	}
	assert window.browsing_context().children().len == 0
	assert window.length() == 2 && window.Window.length() == 2
	proxy := window.window()
	foreign := dom.URL{value: 'https://outside-window-child.example/'}.origin()
	assert window_child_tree_proxy_value(proxy, top.origin(), '0')! == voidptr(first_window.window())
	assert window_child_tree_proxy_value(proxy, foreign, '1')! == voidptr(second_window.window())
	keys := proxy.own_property_keys(top.origin())
	assert keys[0] == '0' && keys[1] == '1'
	assert !proxy.delete(top.origin(), '0')!
	assert proxy.delete(top.origin(), '2')!
	assert proxy.get_own_property(top.origin(), 'length')!.descriptor.value.number_data == 2

	body := top.body()?
	mut body_node := body.as_node()
	_ = body_node.pre_insert(second.as_node(), first.as_node())!
	assert window_child_tree_proxy_value(proxy, foreign, '0')! == voidptr(second_window.window())
	assert window_child_tree_proxy_value(proxy, top.origin(), '1')! == voidptr(first_window.window())
	mut first_node := first.as_node()
	first_node.remove(false)
	assert window.length() == 1
	assert window_child_tree_proxy_value(proxy, foreign, '0')! == voidptr(second_window.window())
	assert !proxy.get_own_property(top.origin(), '1')!.found
	assert proxy.delete(top.origin(), '1')!
	assert '1' !in proxy.own_property_keys(top.origin())
	if _ := proxy.get_own_property(foreign, '1') {
		assert false, 'Source missing cross-origin index must throw'
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
}

fn test_indexed_child_uses_native_active_proxy_slot_and_null_value_without_active_document() {
	mut top, window := window_child_tree_document('https://window-child-native.example/')!
	container := window_child_tree_container(top)!
	mut child, child_window := window_child_tree_child(top, container, 'https://window-child-native.example/child')!
	mut replacement, replacement_window := window_child_tree_document('https://retargeted-window-child.example/')!
	defer {
		top.finalize()
		child.finalize()
		replacement.finalize()
	}
	child_proxy := child_window.window()
	native := child.get_browsing_context()?.window_proxy()
	replacement_native := replacement.get_window()?
	native.set_window(replacement_native)
	assert child_proxy.window() == replacement_window
	assert window_child_tree_proxy_value(window.window(), top.origin(), '0')! == voidptr(child_proxy)
	assert window.length() == 1
	mut child_navigable := child.navigable()?
	child_navigable.set_active_document(none)
	assert child_navigable.active_window_proxy() == none
	assert window.length() == 1
	result := window.window().get_own_property(top.origin(), '0')!
	assert result.found && result.descriptor.value.kind == .null_
	assert !result.descriptor.writable && result.descriptor.enumerable && result.descriptor.configurable
	assert !window.window().delete(top.origin(), '0')!
}

fn test_window_child_tree_reads_actual_associated_document_after_swap_and_restoration() {
	mut original, mut window := window_child_tree_document('https://window-child-swap.example/original')!
	mut replacement, _ := window_child_tree_document('https://replacement-child-swap.example/current')!
	original_container := window_child_tree_container(original)!
	mut original_child, original_child_window := window_child_tree_child(original, original_container, 'https://window-child-swap.example/child')!
	first := window_child_tree_container(replacement)!
	second := window_child_tree_container(replacement)!
	mut first_child, first_window := window_child_tree_child(replacement, first, 'https://replacement-child-swap.example/first')!
	mut second_child, second_window := window_child_tree_child(replacement, second, 'https://replacement-child-swap.example/second')!
	defer {
		original.finalize()
		replacement.finalize()
		original_child.finalize()
		first_child.finalize()
		second_child.finalize()
	}
	proxy := window.window()
	assert window.length() == 1
	assert window_child_tree_proxy_value(proxy, original.origin(), '0')! == voidptr(original_child_window.window())
	window.set_associated_document(replacement)
	assert window.length() == 2 && window.Window.length() == 2
	assert window_child_tree_proxy_value(proxy, replacement.origin(), '0')! == voidptr(first_window.window())
	assert window_child_tree_proxy_value(proxy, original.origin(), '1')! == voidptr(second_window.window())
	window.set_associated_document(original)
	assert window.length() == 1
	assert window_child_tree_proxy_value(proxy, original.origin(), '0')! == voidptr(original_child_window.window())
}

fn test_window_without_navigable_has_no_document_tree_child_indices_despite_cached_children() {
	mut top, window := window_child_tree_document('https://window-child-no-navigable.example/')!
	container := window_child_tree_container(top)!
	mut child, _ := window_child_tree_child(top, container, 'https://window-child-no-navigable.example/child')!
	mut cached_document, _ := window_child_tree_document('https://cached-window-child.example/')!
	defer {
		top.finalize()
		child.finalize()
		cached_document.finalize()
	}
	cached_context := BrowsingContextModel.create(cached_document, window.browsing_context(), 'cached')
	assert cached_context.parent()? == window.browsing_context()
	assert window.browsing_context().children().len == 1
	assert window.length() == 1
	top.set_navigable(none)
	assert window.length() == 0 && window.Window.length() == 0
	assert !window.window().get_own_property(top.origin(), '0')!.found
	assert '0' !in window.window().own_property_keys(top.origin())
	assert window.window().delete(top.origin(), '0')!
}
