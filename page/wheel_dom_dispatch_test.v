module page

import dom

@[heap]
struct WheelDOMFixture {
	model     &Page
	document  &dom.Document
	window    &dom.Window
	root      &dom.Element
	child     &dom.Element
	text      &dom.Text
	navigable &dom.Navigable
}

@[heap]
struct WheelDOMObservation {
mut:
	events          []&dom.Event
	labels          []string
	targets         []voidptr
	current_targets []voidptr
	phases          []u16
	passive         []bool
	cancel          bool
}

fn wheel_dom_fixture() !&WheelDOMFixture {
	mut model := Page.create(1)!
	mut document := dom.Document.create_for_fragment_parsing()
	window := &dom.Window{}
	document.set_window(window)
	mut navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	navigable.set_active_document(document)
	document.set_page(unsafe { &dom.Page(model) })
	model.set_local_root_navigable(navigable)!
	document.set_viewport_rect(dom.Rect{ x: 11.25, y: 22.5, width: 800, height: 600 })
	root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	text := document.create_text_node('wheel hit')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	mut child_node := child.as_node()
	child_node.append_child(text.as_node())!
	fixture := &WheelDOMFixture{model, document, window, root, child, text, navigable}
	wheel_dom_commit_layout(fixture)
	return fixture
}

// Public DOM/layout boundary stubs retain committed node identity and paint
// geometry without introducing another layout engine into this package test.
fn wheel_dom_commit_layout(fixture &WheelDOMFixture) {
	mut document := fixture.document
	root_layout := &dom.LayoutNode{
		is_viewport_: true
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.set_layout_node(root_layout)
	mut root_node := fixture.root.as_node()
	root_node.set_layout_node(&dom.LayoutNode{})
	mut child_node := fixture.child.as_node()
	child_node.set_layout_node(&dom.LayoutNode{})
	child_node.set_paintable(&dom.Paintable{
		is_box:                              true
		repaint_callback_target:             voidptr(child_node)
		box_type_agnostic_position_callback: fn (_ voidptr, _ voidptr) dom.CSSPixelPoint_ {
			return dom.CSSPixelPoint_{
				x_: 2.5
				y_: 3.25
			}
		}
	})
	mut text_node := fixture.text.as_node()
	text_node.set_layout_node(&dom.LayoutNode{ is_text_node_: true })
	text_node.set_paintable(&dom.Paintable{
		repaint_callback_target:             voidptr(text_node)
		box_type_agnostic_position_callback: fn (_ voidptr, _ voidptr) dom.CSSPixelPoint_ {
			return dom.CSSPixelPoint_{
				x_: 7
				y_: 8
			}
		}
	})
	document.set_layout_viewport(&dom.LayoutViewport{ root_node: root_layout })
	document.set_viewport_paintable(&dom.ViewportPaintable{})
	document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{
		target:   voidptr(root_layout)
		callback: fn (target voidptr, _ &dom.Document, _ f64, _ f64, _ bool) voidptr {
			return target
		}
	})
	// The fragment has no CSS/browsing-context adapter; consume its style
	// invalidations through the public boundary before committing the stub.
	document.set_needs_full_style_update(false)
	document_node.for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update(false)
		mutable_node.set_child_needs_style_update(false)
		return .@continue
	})
	document.update_layout(.event_handler_handle_mouse_wheel)
	assert document.layout_is_up_to_date()
}

fn wheel_dom_observe(node &dom.Node, state &WheelDOMObservation, label string,
	capture bool, passive bool) &dom.IDLEventListener {
	callback := &dom.CallbackType{
		handle_event: fn [state, label] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut recorder := unsafe { &WheelDOMObservation(state) }
			recorder.events << event
			recorder.labels << label
			recorder.targets << voidptr(event.target() or { panic('missing wheel target') })
			recorder.current_targets << voidptr(event.current_target() or {
				panic('missing current target')
			})
			recorder.phases << event.event_phase()
			recorder.passive << event.in_passive_listener()
			if recorder.cancel {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}
	listener := dom.IDLEventListener.create(callback)
	target := unsafe { &dom.EventTarget(node) }
	target.add_event_listener('wheel', listener, dom.AddEventListenerOptions{
		capture: capture
		passive: passive
	})
	return listener
}

fn wheel_dom_event(state &WheelDOMObservation, index int) &dom.WheelEvent {
	assert state.events.len > index
	event := state.events[index]
	assert event.interface_ == .wheel_event
	return unsafe { &dom.WheelEvent(event) }
}

fn test_page_wheel_dom_dispatch_normalizes_text_and_preserves_trusted_platform_payload() {
	fixture := wheel_dom_fixture()!
	state := &WheelDOMObservation{}
	wheel_dom_observe(fixture.child.as_node(), state, 'child', false, false)
	mut handler := fixture.model.event_handler
	handler.platform_mouse_position_ = PixelPoint{-100, -200}
	handler.platform_mouse_screen_ = PixelPoint{-1000, -2000}
	modifiers := dom.modifier_shift | dom.modifier_ctrl | dom.modifier_alt | dom.modifier_super
	assert handler.handle_mousewheel_with_parameters(InputTarget.from_node(fixture.text.as_node()), PixelPoint{3.75, 4.25}, PixelPoint{30.5, -40.75},
		2, 5, modifiers, 2.5, -3.5, .precise, .changed, false) == .accepted
	assert state.events.len == 1
	event := wheel_dom_event(state, 0)
	assert event.is_trusted() && event.bubbles() && event.composed() && event.cancelable()
	assert event.view() == voidptr(fixture.window) && event.detail() == 0
	assert state.targets == [voidptr(fixture.child.as_node())]
	assert state.current_targets == state.targets && state.phases == [u16(2)]
	assert event.screen_x() == 30.5 && event.screen_y() == -40.75
	assert event.client_x() == 3.75 && event.client_y() == 4.25
	assert event.page_x() == 15 && event.page_y() == 26.75
	assert event.offset_x() == 12.5 && event.offset_y() == 23.5
	assert event.button() == 2 && event.buttons() == 5
	assert event.ctrl_key() && event.shift_key() && event.alt_key() && event.meta_key()
	assert event.delta_x() == -3.5 && event.delta_y() == 2.5 && event.delta_z() == 0
	assert event.delta_mode() == dom.dom_delta_pixel
	assert event.wheel_delta_x() == 4 && event.wheel_delta_y() == -2
	metadata := handler.last_wheel_event() or { panic('missing wheel metadata') }
	assert metadata.delta_x == -3.5 && metadata.delta_y == 2.5
	visual := handler.last_known_mouse_visual_position_ or {
		panic('missing retained visual position')
	}
	screen := handler.last_known_mouse_screen_position_ or {
		panic('missing retained screen position')
	}
	assert visual == PixelPoint{3.75, 4.25} && screen == PixelPoint{30.5, -40.75}
	assert event.current_target() == none && event.event_phase() == 0
}

fn test_page_wheel_dom_dispatch_captures_bubbles_and_returns_actual_dom_cancellation() {
	fixture := wheel_dom_fixture()!
	state := &WheelDOMObservation{}
	wheel_dom_observe(fixture.root.as_node(), state, 'capture', true, false)
	wheel_dom_observe(fixture.child.as_node(), state, 'target', false, false)
	wheel_dom_observe(fixture.root.as_node(), state, 'bubble', false, false)
	mut handler := fixture.model.event_handler
	target := InputTarget.from_node(fixture.text.as_node())
	assert handler.dispatch_wheel_event(target, PixelPoint{1, 2}, PixelPoint{10, 20}, 0, 0, 0, 1,
		2, true) == .accepted
	assert state.events.len == 3
	assert state.labels == ['capture', 'target', 'bubble'] && state.phases == [u16(1), 2, 3]
	assert state.targets == [voidptr(fixture.child.as_node()), voidptr(fixture.child.as_node()),
		voidptr(fixture.child.as_node())]
	assert state.current_targets == [voidptr(fixture.root.as_node()),
		voidptr(fixture.child.as_node()), voidptr(fixture.root.as_node())]
	assert voidptr(state.events[0]) == voidptr(state.events[1])
		&& voidptr(state.events[1]) == voidptr(state.events[2])
	mut mutable_state := unsafe { &WheelDOMObservation(state) }
	mutable_state.cancel = true
	assert handler.handle_mousewheel_with_parameters(target, PixelPoint{}, PixelPoint{}, 0, 0, 0,
		0, 4, .discrete, .changed, false) == .cancelled
	assert state.events.len == 6 && wheel_dom_event(state, 3).default_prevented()
	assert state.labels[3..] == ['capture', 'target', 'bubble']
}

fn test_page_wheel_dom_dispatch_respects_passive_and_noncancelable_gates_but_handles_late_false() {
	fixture := wheel_dom_fixture()!
	state := &WheelDOMObservation{
		cancel: true
	}
	listener := wheel_dom_observe(fixture.child.as_node(), state, 'passive', false, true)
	mut handler := fixture.model.event_handler
	target := InputTarget.from_node(fixture.child.as_node())
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 5, true) == .accepted
	assert state.events.len == 1
	assert state.passive == [true] && !wheel_dom_event(state, 0).default_prevented()
	event_target := unsafe { &dom.EventTarget(fixture.child.as_node()) }
	event_target.remove_event_listener_without_options('wheel', listener)
	wheel_dom_observe(fixture.child.as_node(), state, 'ordinary', false, false)
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 5, false) == .accepted
	assert state.events.len == 2 && !wheel_dom_event(state, 1).cancelable()
	assert !wheel_dom_event(state, 1).default_prevented() && !state.passive[1]
	event_target.set_event_handler_attribute('wheel', &dom.CallbackType{
		associated_window: fixture.window
		handle_event:      fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			return dom.js_bool(false)
		}
	})
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 5, false) == .cancelled
	assert state.events.len == 3 && wheel_dom_event(state, 2).default_prevented()
	assert handler.handle_mousewheel_with_parameters(target, PixelPoint{}, PixelPoint{}, 0, 0, 0,
		0, 5, .precise, .momentum, true) == .handled
	assert state.events.len == 4 && !wheel_dom_event(state, 3).cancelable()
	assert wheel_dom_event(state, 3).default_prevented()
}

fn test_page_wheel_dom_pinch_and_disabled_inactive_or_missing_paint_targets() {
	fixture := wheel_dom_fixture()!
	state := &WheelDOMObservation{}
	wheel_dom_observe(fixture.child.as_node(), state, 'pinch', false, false)
	mut handler := fixture.model.event_handler
	mut target := InputTarget.from_node(fixture.text.as_node())
	assert handler.dispatch_synthetic_pinch_wheel_event(target, PixelPoint{7, 8}, PixelPoint{70, 80},
		dom.modifier_alt, -12.5) == .accepted
	assert state.events.len == 1
	event := wheel_dom_event(state, 0)
	assert event.is_trusted() && event.cancelable() && event.ctrl_key() && event.alt_key()
	assert event.delta_x() == 0 && event.delta_y() == -12.5
	assert event.client_x() == 7 && event.screen_x() == 70
	mut button := fixture.document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	button.set_attribute_value('disabled', '')
	mut root_node := fixture.root.as_node()
	root_node.append_child(button.as_node())!
	mut button_node := button.as_node()
	button_node.append_child(fixture.child.as_node())!
	wheel_dom_commit_layout(fixture)
	target = InputTarget.from_node(fixture.text.as_node())
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 1
	button.remove_attribute('disabled')
	wheel_dom_commit_layout(fixture)
	target = InputTarget.from_node(fixture.text.as_node())
	handler.active_document = false
	assert handler.dispatch_synthetic_pinch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 1) == .dropped
	assert state.events.len == 1
	handler.active_document = true
	handler.paint_root_available = false
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 1
	handler.paint_root_available = true
	assert handler.dispatch_wheel_event(InputTarget{
		id:                   target.id
		node:                 fixture.text.as_node()
		layout_is_up_to_date: false
	}, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 1
	assert handler.dispatch_synthetic_pinch_wheel_event(none, PixelPoint{}, PixelPoint{}, 0, 1) == .dropped
	assert state.events.len == 1
	mut navigable := fixture.navigable
	navigable.set_active_document(none)
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 1
}

fn test_page_wheel_dom_unboxed_parent_uses_hit_geometry_and_rejects_stale_or_uncommitted_layout() {
	fixture := wheel_dom_fixture()!
	state := &WheelDOMObservation{}
	wheel_dom_observe(fixture.child.as_node(), state, 'target', false, false)
	mut handler := fixture.model.event_handler
	target := InputTarget.from_node(fixture.text.as_node())
	assert handler.dispatch_wheel_event(target, PixelPoint{3.75, 4.25}, PixelPoint{}, 0, 0, 0, 1,
		2, true) == .accepted
	assert state.events.len == 1
	assert wheel_dom_event(state, 0).offset_x() == 12.5
	mut child_node := fixture.child.as_node()
	child_node.set_paintable(&dom.Paintable{})
	assert handler.dispatch_wheel_event(target, PixelPoint{3.75, 4.25}, PixelPoint{}, 0, 0, 0, 1,
		2, true) == .accepted
	assert state.events.len == 2
	event := wheel_dom_event(state, 1)
	assert event.offset_x() == 8 && event.offset_y() == 18.75
	assert state.targets[1] == voidptr(fixture.child.as_node())
	mut text_node := fixture.text.as_node()
	text_node.set_layout_node(&dom.LayoutNode{ is_text_node_: true })
	assert handler.dispatch_wheel_event(target, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 2
	fresh := InputTarget.from_node(text_node)
	assert handler.dispatch_wheel_event(fresh, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .accepted
	assert state.events.len == 3
	mut document_node := unsafe { &dom.Node(fixture.document) }
	document_node.set_needs_layout_tree_update(true, .style_change)
	assert !fixture.document.layout_is_up_to_date()
	assert handler.dispatch_wheel_event(fresh, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 3
	wheel_dom_commit_layout(fixture)
	current := InputTarget.from_node(text_node)
	mut document := fixture.document
	document.set_viewport_paintable(none)
	assert handler.dispatch_wheel_event(current, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 3
	document.set_viewport_paintable(&dom.ViewportPaintable{})
	document.set_layout_viewport(none)
	assert handler.dispatch_wheel_event(current, PixelPoint{}, PixelPoint{}, 0, 0, 0, 0, 1, true) == .dropped
	assert state.events.len == 3
}
