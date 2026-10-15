module page

import dom

fn click_target_test_tree() (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	left := document.create_element_ns('http://www.w3.org/1999/xhtml', 'strong') or { panic(err) }
	right := document.create_element_ns('http://www.w3.org/1999/xhtml', 'small') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(left.as_node()) or { panic(err) }
	root_node.append_child(right.as_node()) or { panic(err) }
	return document, root, left, right
}

fn test_click_targets_the_shared_ancestor_while_pointerup_keeps_its_hit_target() {
	mut document, root, left, right := click_target_test_tree()
	defer { document.finalize() }
	mut handler := EventHandler{}
	mut root_target := unsafe { &dom.EventTarget(root) }
	root_target.add_event_listener_without_options('pointerup', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [right] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			target := event.target() or { panic('pointerup has no target') }
			assert voidptr(target) == voidptr(right)
			return dom.js_undefined()
		}
	}))
	root_target.add_event_listener_without_options('click', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [root] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			target := event.target() or { panic('click has no target') }
			assert voidptr(target) == voidptr(root)
			return dom.js_undefined()
		}
	}))
	handler.handle_platform_pointer_event('pointerdown', InputTarget.from_node(left.as_node()), PixelPoint{}, PixelPoint{}, 0, 1, 0, 1)
	handler.handle_platform_pointer_event('pointerup', InputTarget.from_node(right.as_node()), PixelPoint{}, PixelPoint{}, 0, 0, 0, 1)
	assert handler.last_click_allowed()
	assert voidptr(handler.last_click_target_node()?) == voidptr(root)
	// Reading the target must preserve the receipt for native media replay.
	assert voidptr(handler.take_last_click_event()?.target()?) == voidptr(root)
	assert handler.last_click_target_node() == none
}

fn test_click_cancellation_at_the_common_ancestor_blocks_activation() {
	mut document, root, left, right := click_target_test_tree()
	defer { document.finalize() }
	mut target := unsafe { &dom.EventTarget(root) }
	target.add_event_listener_without_options('click', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
	mut handler := EventHandler{}
	handler.handle_mousedown(InputTarget.from_node(left.as_node()), 1)
	handler.handle_mouseup(InputTarget.from_node(right.as_node()))
	assert !handler.last_click_allowed()
	assert 'activate' !in handler.event_log.map(it.name)
	assert handler.take_last_click_event()?.default_prevented()
}

fn test_detached_press_target_does_not_click_the_release_target() {
	mut document, _, left, right := click_target_test_tree()
	defer { document.finalize() }
	mut handler := EventHandler{}
	handler.handle_mousedown(InputTarget.from_node(left.as_node()), 1)
	mut node := left.as_node()
	node.remove(false)
	handler.handle_mouseup(InputTarget.from_node(right.as_node()))
	assert !handler.last_click_allowed()
	assert handler.last_click_target_node() == none
}
