module page

import dom

@[heap]
struct MediaClickReceiptObservation {
mut:
	outer_events []&dom.Event
	inner_events []&dom.Event
	reports      int
	throw        bool
}

fn media_click_receipt_tree() (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create_for_fragment_parsing()
	root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	video := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video') or { panic(err) }
	audio := document.create_element_ns('http://www.w3.org/1999/xhtml', 'audio') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(video.as_node()) or { panic(err) }
	root_node.append_child(audio.as_node()) or { panic(err) }
	return document, video, audio
}

fn test_media_click_receipt_publishes_outer_owner_after_nested_click_and_double_click() {
	mut document, video, audio := media_click_receipt_tree()
	defer { document.finalize() }
	mut handler := &EventHandler{}
	state := &MediaClickReceiptObservation{}
	video_target := unsafe { &dom.EventTarget(video) }
	audio_target := unsafe { &dom.EventTarget(audio) }
	audio_input := InputTarget.from_node(audio.as_node())
	audio_target.set_event_handler_attribute('click', &dom.CallbackType{
		handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &MediaClickReceiptObservation(state) }
			observation.inner_events << event
			return dom.js_undefined()
		}
	})
	video_target.set_event_handler_attribute('click', &dom.CallbackType{
		handle_event: fn [handler, state, audio_input, video] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &MediaClickReceiptObservation(state) }
			observation.outer_events << event
			mut nested_handler := unsafe { &EventHandler(handler) }
			assert nested_handler.fire_click_events(audio_input) == .handled
			mut element := unsafe { &dom.Element(video) }
			element.set_attribute_value('onclick', 'globalThis.rawReceiptClickRuns++')
			return dom.js_undefined()
		}
	})
	video_target.add_event_listener_without_options('dblclick', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [handler, audio_input] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut nested_handler := unsafe { &EventHandler(handler) }
			assert nested_handler.fire_click_events(audio_input) == .handled
			return dom.js_undefined()
		}
	}))
	input := InputTarget.from_node(video.as_node())
	assert handler.handle_platform_pointer_event('pointerdown', input, PixelPoint{}, PixelPoint{}, 0, 1, 0, 2) == .handled
	assert handler.handle_platform_pointer_event('pointerup', input, PixelPoint{}, PixelPoint{}, 0, 0, 0, 2) == .handled
	assert handler.last_click_allowed()
	assert state.outer_events.len == 1 && state.inner_events.len == 2
	receipt := handler.take_last_click_event() or {
		assert false, 'missing outer click receipt'
		return
	}
	assert voidptr(receipt) == voidptr(state.outer_events[0])
	assert receipt.type_ == 'click' && receipt.is_trusted()
	assert receipt.current_target() == none
	assert receipt.did_process_click_handler(video_target)
	assert !receipt.did_process_click_handler(audio_target)
	for inner in state.inner_events {
		assert inner.did_process_click_handler(audio_target)
		assert !inner.did_process_click_handler(video_target)
	}
	assert handler.take_last_click_event() == none
	raw := video_target.data.event_handler_map['click'] or {
		assert false, 'missing raw replacement'
		return
	}
	assert raw.value.kind == .string
	// A redispatch starts a fresh receipt on the same Event object. The raw
	// element handler has no compiler and must not inherit its prior marker.
	assert dom.event_target_dispatch_event(video_target, receipt)
	assert !receipt.did_process_click_handler(video_target)
	assert !receipt.did_process_click_handler(audio_target)
}

fn test_media_click_receipt_records_self_clearing_throw_and_cancellation_then_clears_on_empty_release() {
	mut document, video, audio := media_click_receipt_tree()
	defer { document.finalize() }
	mut handler := &EventHandler{}
	state := &MediaClickReceiptObservation{ throw: true }
	target := unsafe { &dom.EventTarget(video) }
	other_target := unsafe { &dom.EventTarget(audio) }
	callback := &dom.CallbackType{
		report_exception:            fn [state] (exception IError) {
			assert exception.msg() == 'click receipt callback failed'
			mut observation := unsafe { &MediaClickReceiptObservation(state) }
			observation.reports++
		}
		handle_event_with_exception: fn [state, target] (event &dom.Event, _ ?&dom.EventTarget) !dom.JSValue {
			mut observation := unsafe { &MediaClickReceiptObservation(state) }
			observation.outer_events << event
			target.set_event_handler_attribute('click', none)
			if observation.throw { return error('click receipt callback failed') }
			return dom.js_bool(false)
		}
	}
	target.set_event_handler_attribute('click', callback)
	input := InputTarget.from_node(video.as_node())
	assert handler.handle_platform_pointer_event('pointerdown', input, PixelPoint{}, PixelPoint{}, 0, 1, 0, 1) == .handled
	assert handler.handle_platform_pointer_event('pointerup', input, PixelPoint{}, PixelPoint{}, 0, 0, 0, 1) == .handled
	assert handler.last_click_allowed()
	assert state.reports == 1 && state.outer_events.len == 1
	thrown_receipt := handler.take_last_click_event() or {
		assert false, 'missing thrown callback receipt'
		return
	}
	assert voidptr(thrown_receipt) == voidptr(state.outer_events[0])
	assert thrown_receipt.did_process_click_handler(target)
	assert !thrown_receipt.did_process_click_handler(other_target)
	assert thrown_receipt.current_target() == none
	assert 'click' !in target.data.event_handler_map
	mut observation := unsafe { &MediaClickReceiptObservation(state) }
	observation.throw = false
	target.set_event_handler_attribute('click', callback)
	assert handler.handle_platform_pointer_event('pointerdown', input, PixelPoint{}, PixelPoint{}, 0, 1, 0, 1) == .handled
	assert handler.handle_platform_pointer_event('pointerup', input, PixelPoint{}, PixelPoint{}, 0, 0, 0, 1) == .handled
	assert !handler.last_click_allowed()
	assert state.outer_events.len == 2 && state.reports == 1
	assert state.outer_events[1].default_prevented()
	assert state.outer_events[1].did_process_click_handler(target)
	// Leave the canceled click unconsumed. A release without a new press must
	// clear that receipt rather than authorize replay using a previous event.
	assert handler.handle_mouseup(input) == .dropped
	assert handler.take_last_click_event() == none
	mut element := unsafe { &dom.Element(video) }
	element.set_attribute_value('onclick', 'globalThis.rawReceiptClickRuns++')
	assert handler.handle_platform_pointer_event('pointerdown', input, PixelPoint{}, PixelPoint{}, 0, 1, 0, 1) == .handled
	assert handler.handle_platform_pointer_event('pointerup', input, PixelPoint{}, PixelPoint{}, 0, 0, 0, 1) == .handled
	raw_receipt := handler.take_last_click_event() or {
		assert false, 'missing raw-owner click receipt'
		return
	}
	assert !raw_receipt.did_process_click_handler(target)
	assert !raw_receipt.did_process_click_handler(other_target)
	assert handler.take_last_click_event() == none
	// No-hit release still delivers pointerup at the document root, but it
	// does not publish a click receipt or retain a preceding owner's marker.
	assert handler.handle_platform_pointer_event('pointerdown', input, PixelPoint{}, PixelPoint{}, 0, 1, 0, 1) == .handled
	assert handler.handle_platform_pointer_event('pointerup', none, PixelPoint{}, PixelPoint{}, 0, 0, 0, 1) == .handled
	assert handler.take_last_click_event() == none
}
