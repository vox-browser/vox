module dom

// The DOM's UIEvents predicates now identify the real MouseEvent/KeyboardEvent/PointerEvent subclasses
// via the Event.interface_ tag, and downcast to read subclass fields.
fn test_ui_events_predicates() {
	mouse := MouseEvent.create('click', MouseEventInit{ button: 1, client_x: 10.0 })
	mouse_event := unsafe { &Event(mouse) }
	assert event_is_mouse_event(mouse_event)
	assert !event_is_keyboard_event(mouse_event)
	assert !event_is_pointer_event(mouse_event)
	assert mouse_event.type_ == 'click'
	assert mouse.button() == 1
	assert mouse.client_x() == 10.0

	esc := KeyboardEvent.create('keydown', KeyboardEventInit{ key_code: key_code_escape, key: 'Escape' })
	esc_event := unsafe { &Event(esc) }
	assert event_is_keyboard_event(esc_event)
	assert !event_is_mouse_event(esc_event)
	assert keyboard_event_key_code_is_escape(esc_event)
	assert esc.key() == 'Escape'

	key_a := KeyboardEvent.create('keydown', KeyboardEventInit{ key_code: u32(65) })
	assert !keyboard_event_key_code_is_escape(unsafe { &Event(key_a) })

	pointer := PointerEvent.create('pointerdown', PointerEventInit{ pointer_type: 'mouse', is_primary: true })
	pointer_event := unsafe { &Event(pointer) }
	assert event_is_pointer_event(pointer_event)
	// PointerEvent IS a MouseEvent (subclass).
	assert event_is_mouse_event(pointer_event)
	assert pointer_event_pointer_type(pointer_event) == 'mouse'
	assert pointer.is_primary()

	// A plain base Event is none of these.
	plain := Event.new('custom')
	assert !event_is_mouse_event(plain)
	assert !event_is_keyboard_event(plain)
	assert !event_is_pointer_event(plain)
}

// BeforeUnloadEvent / ErrorEvent (HTML events extending DOM::Event) are also identified via the tag.
fn test_html_events_predicates() {
	mut before_unload := BeforeUnloadEvent.create('beforeunload', EventInit{ cancelable: true })
	before_unload_event := unsafe { &Event(before_unload) }
	assert event_is_before_unload_event(before_unload_event)
	assert !event_is_error_event(before_unload_event)
	before_unload.set_return_value('are you sure?')
	assert before_unload.return_value() == 'are you sure?'

	error := ErrorEvent.create('error', ErrorEventInit{ message: 'boom', filename: 'a.js', lineno: 12 })
	error_event := unsafe { &Event(error) }
	assert event_is_error_event(error_event)
	assert !event_is_before_unload_event(error_event)
	assert error.message() == 'boom'
	assert error.lineno() == 12

	plain := Event.new('custom')
	assert !event_is_before_unload_event(plain)
	assert !event_is_error_event(plain)
}
