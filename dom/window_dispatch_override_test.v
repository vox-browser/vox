module dom

fn test_source_window_virtual_dispatch_keeps_current_target_but_overrides_target_with_document() {
	document := Document.create(URL{value: 'https://window-dispatch.example/'})
	mut window := &Window{}
	window.set_associated_document(document)
	target := unsafe { &EventTarget(window) }
	document_target := unsafe { &EventTarget(document) }
	target.add_event_listener('load', IDLEventListener.create(&CallbackType{
		handle_event: fn [target, document_target] (event &Event, current ?&EventTarget) JSValue {
			assert voidptr(event.target() or { panic('missing target') }) == voidptr(document_target)
			assert voidptr(event.current_target() or { panic('missing current target') }) == voidptr(target)
			assert voidptr(current or { panic('missing callback target') }) == voidptr(target)
			assert event.event_phase() == u16(EventPhase.at_target)
			return js_undefined()
		}
	}), AddEventListenerOptions{})
	event := Event.create('load', EventInit{})
	assert target.dispatch_event(event)
	assert voidptr(event.target()?) == voidptr(document_target)
	assert event.current_target() == none
}

fn test_source_window_binding_dispatch_preserves_legacy_target_override_and_untrusted_state() {
	document := Document.create(url_about_blank())
	mut window := &Window{}
	window.set_associated_document(document)
	target := unsafe { &EventTarget(window) }
	event := Event.create('custom', EventInit{})
	assert event.is_trusted()
	assert target.dispatch_event_binding(event)!
	assert !event.is_trusted()
	assert voidptr(event.target()?) == voidptr(document)
}

fn test_source_window_virtual_dispatch_bypasses_base_user_activation_processing() {
	document := Document.create(url_about_blank())
	mut window := &Window{}
	window.set_associated_document(document)
	target := unsafe { &EventTarget(window) }
	before := window.last_activation_timestamp
	event := Event.create('mousedown', EventInit{})
	assert target.dispatch_event(event)
	assert window.last_activation_timestamp == before
	assert voidptr(event.target()?) == voidptr(document)
}
