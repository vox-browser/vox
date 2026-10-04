module html

import dom
import math
import page

fn activation_consumption_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn activation_consumption_connect(parent &dom.Document, insertion_parent &dom.Node, child &dom.Document) !&dom.Element {
	container := parent.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe')!
	mut insertion := unsafe { &dom.Node(insertion_parent) }
	insertion.append_child(container.as_node())!
	mut navigable := child.navigable() or { return error('missing child navigable') }
	navigable.parent_ = parent.navigable() or { return error('missing parent navigable') }
	navigable.is_top_level_traversable_ = false
	navigable.container_ = container.as_node()
	navigable.container_document_ = parent
	return container
}

fn test_native_activation_consumption_follows_logical_navigable_and_shadow_inclusive_document_tree() {
	mut top, top_window := activation_consumption_document('https://activation-consume.example/top')!
	mut child, mut child_window := activation_consumption_document('https://activation-consume.example/child')!
	mut outside, outside_window := activation_consumption_document('https://activation-consume.example/outside')!
	defer {
		top.finalize()
		child.finalize()
		outside.finalize()
	}
	mut host := top.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut top_node := top.as_node()
	top_node.append_child(host.as_node())!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	_ := activation_consumption_connect(top, shadow.as_node(), child)!
	assert child_window.browsing_context().parent() == none
	assert child_window.navigable()?.parent()? == top.navigable()?
	assert top.inclusive_descendant_navigables() == [top.navigable()?, child.navigable()?]
	mut top_native := top.get_window()?
	mut child_native := child.get_window()?
	mut outside_native := outside.get_window()?
	top_native.set_last_activation_timestamp(42)
	child_native.set_last_activation_timestamp(84)
	outside_native.set_last_activation_timestamp(126)
	child_native.consume_user_activation()
	assert math.is_inf(top_native.last_activation_timestamp, -1)
	assert math.is_inf(child_native.last_activation_timestamp, -1)
	assert math.is_inf(top_window.last_activation_timestamp(), -1)
	assert math.is_inf(child_window.last_activation_timestamp(), -1)
	assert outside_window.last_activation_timestamp() == 126

	top_native.set_last_activation_timestamp(42)
	child_native.set_last_activation_timestamp(84)
	child_native.set_last_history_action_activation_timestamp(1)
	assert child_window.last_history_action_activation_timestamp() == 1
	child_window.set_last_history_action_activation_timestamp(2)
	assert child_native.last_history_action_activation_timestamp == 2
	child_window.consume_history_action_user_activation()
	assert top_native.last_history_action_activation_timestamp == 42
	assert child_native.last_history_action_activation_timestamp == 84
	assert !top_window.has_history_action_activation() && !child_window.has_history_action_activation()
	assert math.is_inf(outside_window.last_history_action_activation_timestamp(), 1)
}

fn test_consumption_uses_navigable_actual_window_proxy_instead_of_document_window() {
	mut top, _ := activation_consumption_document('https://activation-consume.example/top-proxy')!
	mut child, mut child_window := activation_consumption_document('https://activation-consume.example/child-proxy')!
	mut other, _ := activation_consumption_document('https://activation-consume.example/other-proxy')!
	defer {
		top.finalize()
		child.finalize()
		other.finalize()
	}
	_ := activation_consumption_connect(top, top.as_node(), child)!
	mut top_native := top.get_window()?
	mut child_native := child.get_window()?
	mut other_native := other.get_window()?
	context := child.get_browsing_context()?
	proxy := context.window_proxy()
	proxy.set_window(other_native)
	defer { proxy.set_window(child_native) }
	assert child.get_window()? == child_native
	assert child.navigable()?.active_browsing_context()? == context
	assert child.navigable()?.active_window_proxy()? == proxy
	assert child.navigable()?.active_window()? == other_native
	top_native.set_last_activation_timestamp(42)
	child_native.set_last_activation_timestamp(84)
	other_native.set_last_activation_timestamp(126)
	child_window.consume_user_activation()
	assert math.is_inf(top_native.last_activation_timestamp, -1)
	assert math.is_inf(other_native.last_activation_timestamp, -1)
	assert child_native.last_activation_timestamp == 84
	top_native.set_last_activation_timestamp(42)
	other_native.set_last_activation_timestamp(126)
	child_native.consume_history_action_user_activation()
	assert top_native.last_history_action_activation_timestamp == 42
	assert other_native.last_history_action_activation_timestamp == 126
	assert math.is_inf(child_native.last_history_action_activation_timestamp, 1)
}

fn test_consumption_returns_without_current_navigable_despite_retained_browsing_context() {
	mut document, mut window := activation_consumption_document('https://activation-consume.example/no-navigable')!
	defer { document.finalize() }
	mut navigable := document.navigable()?
	mut native := document.get_window()?
	native.set_last_activation_timestamp(42)
	native.set_last_history_action_activation_timestamp(7)
	navigable.set_active_document(none)
	defer { navigable.set_active_document(document) }
	assert document.navigable() == none
	assert document.get_browsing_context() != none
	assert window.browsing_context().active_document() != none
	assert native.navigable() == none
	assert navigable.active_browsing_context() == none
	assert navigable.active_window_proxy() == none
	assert navigable.active_window() == none
	window.consume_user_activation()
	native.consume_history_action_user_activation()
	assert native.last_activation_timestamp == 42
	assert window.last_history_action_activation_timestamp() == 7
}

fn test_consumption_excludes_inactive_and_disconnected_container_documents() {
	mut top, mut top_window := activation_consumption_document('https://activation-consume.example/top-filter')!
	mut active, _ := activation_consumption_document('https://activation-consume.example/active')!
	mut inactive, _ := activation_consumption_document('https://activation-consume.example/inactive')!
	mut disconnected, _ := activation_consumption_document('https://activation-consume.example/disconnected')!
	defer {
		top.finalize()
		active.finalize()
		inactive.finalize()
		disconnected.finalize()
	}
	root := top.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut top_node := top.as_node()
	top_node.append_child(root.as_node())!
	_ := activation_consumption_connect(top, root.as_node(), active)!
	_ := activation_consumption_connect(top, root.as_node(), inactive)!
	container := activation_consumption_connect(top, root.as_node(), disconnected)!
	mut inactive_navigable := inactive.navigable()?
	inactive_navigable.set_active_document(none)
	defer { inactive_navigable.set_active_document(inactive) }
	mut container_node := container.as_node()
	container_node.remove(false)
	assert top.inclusive_descendant_navigables() == [top.navigable()?, active.navigable()?]
	mut top_native := top.get_window()?
	mut active_native := active.get_window()?
	mut inactive_native := inactive.get_window()?
	mut disconnected_native := disconnected.get_window()?
	top_native.set_last_activation_timestamp(42)
	active_native.set_last_activation_timestamp(84)
	inactive_native.set_last_activation_timestamp(126)
	disconnected_native.set_last_activation_timestamp(168)
	top_window.consume_user_activation()
	assert math.is_inf(top_native.last_activation_timestamp, -1)
	assert math.is_inf(active_native.last_activation_timestamp, -1)
	assert inactive_native.last_activation_timestamp == 126
	assert disconnected_native.last_activation_timestamp == 168
	top_native.set_last_activation_timestamp(42)
	active_native.set_last_activation_timestamp(84)
	inactive_native.set_last_history_action_activation_timestamp(7)
	disconnected_native.set_last_history_action_activation_timestamp(8)
	top_native.consume_history_action_user_activation()
	assert top_native.last_history_action_activation_timestamp == 42
	assert active_native.last_history_action_activation_timestamp == 84
	assert inactive_native.last_history_action_activation_timestamp == 7
	assert disconnected_native.last_history_action_activation_timestamp == 8
}
