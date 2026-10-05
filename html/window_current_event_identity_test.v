module html

import dom

@[heap]
struct WindowCurrentEventObservation {
mut:
	order        []string
	reports      int
	shadow_calls int
}

fn current_event_window_fixture() !(&dom.Document, &WindowModel) {
	document := parse_document_with_url('<!doctype html><body><div id="host"></div></body>', dom.URL{value: 'https://window-event.example/'})
	window := WindowModel.create_top_level(document, none, 'current-event')!
	return document, window
}

fn test_window_model_and_native_dispatch_record_share_one_current_event_slot() {
	mut document, mut window := current_event_window_fixture()!
	defer { document.finalize() }
	mut native := document.get_window() or { panic('actual Window') }
	assert voidptr(native) == voidptr(window)
	first := dom.Event.create('first', dom.EventInit{})
	second := dom.Event.create('second', dom.EventInit{})
	window.set_current_event(first)
	assert native.current_event()? == first
	native.set_current_event(second)
	assert window.current_event()? == second
	assert window.event()? == second
	window.set_current_event(none)
	assert native.current_event() == none && window.event() == none
}

fn test_window_model_event_tracks_nested_native_dispatch_and_restores_after_listener_exception() {
	mut document, window := current_event_window_fixture()!
	defer { document.finalize() }
	native := document.get_window() or { panic('actual Window') }
	outer_target := dom.EventTarget.new()
	inner_target := dom.EventTarget.new()
	outer := dom.Event.create('outer', dom.EventInit{})
	inner := dom.Event.create('inner', dom.EventInit{})
	state := &WindowCurrentEventObservation{}
	inner_target.add_event_listener_without_options('inner', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window:           native
		report_exception:            fn [state] (reason IError) {
			assert reason.msg() == 'inner listener failure'
			mut observation := unsafe { &WindowCurrentEventObservation(state) }
			observation.reports++
		}
		handle_event_with_exception: fn [window, inner, state] (event &dom.Event, _ ?&dom.EventTarget) !dom.JSValue {
			assert event == inner && (window.event() or { panic('inner current event') }) == inner
			mut observation := unsafe { &WindowCurrentEventObservation(state) }
			observation.order << 'inner'
			return error('inner listener failure')
		}
	}))
	outer_target.add_event_listener_without_options('outer', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [window, outer, inner_target, inner, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event == outer && (window.event() or { panic('outer current event') }) == outer
			mut observation := unsafe { &WindowCurrentEventObservation(state) }
			observation.order << 'outer-before'
			assert inner_target.dispatch_event(inner)
			assert (window.event() or { panic('restored outer event') }) == outer
			observation.order << 'outer-after'
			return dom.js_undefined()
		}
	}))
	assert outer_target.dispatch_event(outer)
	assert state.order == ['outer-before', 'inner', 'outer-after']
	assert state.reports == 1
	assert native.current_event() == none && window.event() == none
}

fn test_window_model_event_preserves_outer_or_absent_current_event_inside_shadow_tree() {
	mut document, window := current_event_window_fixture()!
	defer { document.finalize() }
	native := document.get_window() or { panic('actual Window') }
	mut host := document.get_element_by_id('host')?
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut shadow_node := dom.shadow_root_as_node(shadow)
	shadow_node.append_child(child.as_node())!
	shadow_target := unsafe { &dom.EventTarget(child) }
	shadow_event := dom.Event.create('shadow', dom.EventInit{})
	outer := dom.Event.create('outer', dom.EventInit{})
	outer_target := dom.EventTarget.new()
	state := &WindowCurrentEventObservation{}
	shadow_target.add_event_listener_without_options('shadow', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [window, outer, shadow_event, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event == shadow_event
			mut observation := unsafe { &WindowCurrentEventObservation(state) }
			if observation.shadow_calls == 0 {
				assert window.event() == none
			} else {
				assert (window.event() or { panic('outer preserved in shadow') }) == outer
			}
			observation.shadow_calls++
			return dom.js_undefined()
		}
	}))
	outer_target.add_event_listener_without_options('outer', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [window, outer, shadow_target, shadow_event] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert (window.event() or { panic('outer event') }) == outer
			assert shadow_target.dispatch_event(shadow_event)
			assert (window.event() or { panic('outer after shadow') }) == outer
			return dom.js_undefined()
		}
	}))
	assert shadow_target.dispatch_event(shadow_event)
	assert outer_target.dispatch_event(outer)
	assert state.shadow_calls == 2
	assert native.current_event() == none && window.event() == none
}
