module page

import dom

struct PointerEventObservation {
mut:
	events     []string
	cancel     string
	client_x   f64
	page_x     f64
	offset_x   f64
	buttons    u16
	is_trusted bool
}

fn pointer_event_test_listener(target &dom.Node, observation &PointerEventObservation, names []string) {
	mut event_target := unsafe { &dom.EventTarget(target) }
	for name in names {
		callback := &dom.CallbackType{
			handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut state := unsafe { &PointerEventObservation(observation) }
				state.events << event.type_
				state.is_trusted = event.is_trusted()
				if dom.event_is_mouse_event(event) {
					mouse := unsafe { &dom.MouseEvent(event) }
					state.client_x = mouse.client_x()
					state.page_x = mouse.page_x()
					state.offset_x = mouse.offset_x()
					state.buttons = mouse.buttons()
				}
				if state.cancel == event.type_ {
					mut mutable_event := unsafe { &dom.Event(event) }
					mutable_event.prevent_default()
				}
				return dom.js_undefined()
			}
		}
		event_target.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn pointer_event_test_tree() (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create_for_fragment_parsing()
	root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	return document, root, child
}

fn test_real_pointer_cancellation_suppresses_compatibility_until_release_but_preserves_click() {
	_, _, child := pointer_event_test_tree()
	state := &PointerEventObservation{ cancel: 'pointerdown' }
	pointer_event_test_listener(child.as_node(), state, ['pointerdown', 'mousedown', 'pointerup',
		'mouseup', 'click', 'dblclick'])
	mut handler := EventHandler{}
	target := InputTarget.from_node(child.as_node())
	assert handler.handle_platform_pointer_event('pointerdown', target, PixelPoint{10, 20}, PixelPoint{110, 220}, 0, 1, 0, 2) == .cancelled
	assert state.events == ['pointerdown']
	assert child.is_being_activated()
	assert handler.handle_platform_pointer_event('pointerup', target, PixelPoint{12, 22}, PixelPoint{112, 222}, 0, 0, 0, 2) == .handled
	assert state.events == ['pointerdown', 'pointerup', 'click', 'dblclick']
	assert !child.is_being_activated()
	assert state.is_trusted
	assert handler.last_click_allowed()
	assert handler.mousedown_node_ == none
	assert !handler.prevent_mouse_event
	assert state.client_x == 12
	assert state.buttons == 0
}

fn test_real_pointermove_cancellation_does_not_suppress_mousemove_and_click_cancellation_blocks_activation() {
	_, _, child := pointer_event_test_tree()
	state := &PointerEventObservation{ cancel: 'pointermove' }
	pointer_event_test_listener(child.as_node(), state, ['pointermove', 'mousemove', 'pointerdown',
		'mousedown', 'pointerup', 'mouseup', 'click'])
	mut handler := EventHandler{}
	target := InputTarget.from_node(child.as_node())
	assert handler.handle_platform_pointer_event('pointermove', target, PixelPoint{2, 3}, PixelPoint{20, 30}, 0, 0, 0, 0) == .handled
	assert state.events == ['pointermove', 'mousemove']
	mut mutable_state := unsafe { &PointerEventObservation(state) }
	mutable_state.cancel = 'click'
	handler.handle_platform_pointer_event('pointerdown', target, PixelPoint{2, 3}, PixelPoint{20, 30}, 0, 1, 0, 1)
	handler.handle_platform_pointer_event('pointerup', target, PixelPoint{2, 3}, PixelPoint{20, 30}, 0, 0, 0, 1)
	assert !handler.last_click_allowed()
	assert 'activate' !in handler.event_log.map(it.name)
	mutable_state.cancel = 'mouseup'
	handler.handle_platform_pointer_event('pointerdown', target, PixelPoint{}, PixelPoint{}, 0, 1, 0, 1)
	handler.handle_platform_pointer_event('pointerup', target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 1)
	assert handler.last_click_allowed()
	assert handler.event_log.last().name == 'activate'
}

fn test_real_release_outside_the_hit_tree_dispatches_at_document_root_and_clears_tracking() {
	_, root, child := pointer_event_test_tree()
	state := &PointerEventObservation{}
	pointer_event_test_listener(root.as_node(), state, ['pointerup', 'mouseup', 'click'])
	mut handler := EventHandler{}
	handler.handle_platform_pointer_event('pointerdown', InputTarget.from_node(child.as_node()), PixelPoint{}, PixelPoint{}, 0, 1, 0, 1)
	assert handler.handle_platform_pointer_event('pointerup', none, PixelPoint{-5, -5}, PixelPoint{}, 0, 0, 0, 1) == .handled
	assert state.events == ['pointerup', 'mouseup']
	assert handler.mousedown_node_ == none
	assert !handler.last_click_allowed()
	assert !child.is_being_activated()
}

fn test_real_auxiliary_click_uses_auxclick_and_preserves_platform_fields() {
	_, _, child := pointer_event_test_tree()
	state := &PointerEventObservation{}
	pointer_event_test_listener(child.as_node(), state, ['click', 'auxclick'])
	mut handler := EventHandler{}
	target := InputTarget.from_node(child.as_node())
	handler.handle_platform_pointer_event('pointerdown', target, PixelPoint{5, 6}, PixelPoint{50, 60}, 1, 4, dom.modifier_shift, 1)
	handler.handle_platform_pointer_event('pointerup', target, PixelPoint{5, 6}, PixelPoint{50, 60}, 1, 0, dom.modifier_shift, 1)
	assert state.events == ['auxclick']
	assert state.is_trusted
}
