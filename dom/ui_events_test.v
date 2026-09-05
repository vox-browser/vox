module dom

import math

struct EventRealmObservation {
mut:
	saw_callback_realm_event bool
}

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

	esc := KeyboardEvent.create('keydown', KeyboardEventInit{
		key_code: key_code_escape
		key:      'Escape'
	})
	esc_event := unsafe { &Event(esc) }
	assert event_is_keyboard_event(esc_event)
	assert !event_is_mouse_event(esc_event)
	assert keyboard_event_key_code_is_escape(esc_event)
	assert esc.key() == 'Escape'

	key_a := KeyboardEvent.create('keydown', KeyboardEventInit{ key_code: u32(65) })
	assert !keyboard_event_key_code_is_escape(unsafe { &Event(key_a) })

	pointer := PointerEvent.create('pointerdown', PointerEventInit{
		pointer_type: 'mouse'
		is_primary:   true
	})
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

	error := ErrorEvent.create('error', ErrorEventInit{
		message:  'boom'
		filename: 'a.js'
		lineno:   12
	})
	error_event := unsafe { &Event(error) }
	assert event_is_error_event(error_event)
	assert !event_is_before_unload_event(error_event)
	assert error.message() == 'boom'
	assert error.lineno() == 12
	assert error.is_trusted()
	constructed_error := ErrorEvent.construct_impl('error', ErrorEventInit{
		message: 'script error'
	}) or { panic(err) }
	assert constructed_error.message() == 'script error'
	assert !constructed_error.is_trusted()

	plain := Event.new('custom')
	assert !event_is_before_unload_event(plain)
	assert !event_is_error_event(plain)
}

fn test_beforeunload_event_handler_return_value_is_retained() {
	mut target := EventTarget.new()
	callback := &CallbackType{
		handle_event: fn (_ &Event, _ ?&EventTarget) JSValue {
			return js_string('leave this page')
		}
	}
	target.set_event_handler_attribute('beforeunload', callback)
	before_unload := BeforeUnloadEvent.create('beforeunload', EventInit{ cancelable: true })
	assert !event_target_dispatch_event(target, unsafe { &Event(before_unload) })
	assert before_unload.return_value() == 'leave this page'

	// The processing algorithm must not overwrite a value assigned by script before dispatch.
	mut preset := BeforeUnloadEvent.create('beforeunload', EventInit{ cancelable: true })
	preset.set_return_value('already set')
	assert !event_target_dispatch_event(target, unsafe { &Event(preset) })
	assert preset.return_value() == 'already set'
}

fn test_event_dispatch_uses_callback_realm_instead_of_current_target_realm() {
	target := EventTarget.new()
	callback_window := &Window{}
	observation := &EventRealmObservation{}
	callback := &CallbackType{
		associated_window: callback_window
		handle_event: fn [callback_window, observation] (event &Event, _ ?&EventTarget) JSValue {
			mut mutable_observation := unsafe { &EventRealmObservation(observation) }
			mutable_observation.saw_callback_realm_event = callback_window.current_event() or {
				return js_undefined()
			} == event
			return js_undefined()
		}
	}
	target.add_event_listener_without_options('cross-realm', IDLEventListener.create(callback))
	event := Event.create('cross-realm', EventInit{})
	assert event_target_dispatch_event(target, event)
	assert observation.saw_callback_realm_event
	assert callback_window.current_event() == none
}

fn test_ui_event_constructors_legacy_initializers_and_modifiers() {
	mut ui := UIEvent.construct_impl('load', UIEventInit{ detail: 7 }) or { panic(err) }
	assert !ui.is_trusted()
	assert ui.detail() == 7
	assert ui.which() == 0
	ui.init_ui_event('legacy', true, true, unsafe { nil }, 9)
	assert ui.type_name() == 'legacy'
	assert ui.bubbles()
	assert ui.cancelable()
	assert ui.detail() == 9
	ui.dispatched_ = true
	ui.init_ui_event('ignored', false, false, unsafe { nil }, 0)
	assert ui.type_name() == 'legacy'

	mut mouse := MouseEvent.construct_impl('click', MouseEventInit{
		client_x:           -1.2
		client_y:           4.9
		button:             2
		ctrl_key:           true
		modifier_caps_lock: true
	}) or { panic(err) }
	assert !mouse.is_trusted()
	assert mouse.client_x() == -2
	assert mouse.client_y() == 4
	assert mouse.page_x() == -2
	assert mouse.offset_y() == 4
	assert mouse.x() == mouse.client_x()
	assert mouse.which() == 3
	assert mouse.get_modifier_state('Control')
	assert mouse.get_modifier_state('CapsLock')
	assert !mouse.get_modifier_state('Unknown')
	mouse.init_mouse_event('mousedown', true, true, unsafe { nil }, 2, 1, 2, 3, 4, false, true,
		false, true, 1, none)
	assert mouse.type_name() == 'mousedown'
	assert mouse.alt_key()
	assert mouse.meta_key()
}

fn test_keyboard_and_pointer_observable_state() {
	mut keyboard := KeyboardEvent.construct_impl('keydown', KeyboardEventInit{
		key:                  'A'
		code:                 'KeyA'
		location:             dom_key_location_left
		shift_key:            true
		modifier_symbol_lock: true
		repeat:               true
		is_composing:         true
		key_code:             65
		char_code:            97
	}) or { panic(err) }
	assert keyboard.key() == 'A'
	assert keyboard.code() == 'KeyA'
	assert keyboard.location() == dom_key_location_left
	assert keyboard.shift_key()
	assert keyboard.repeat()
	assert keyboard.is_composing()
	assert keyboard.which() == 65
	assert keyboard.char_code() == 97
	assert keyboard.get_modifier_state('SymbolLock')
	keyboard.init_keyboard_event('keyup', true, true, unsafe { nil }, 'B', dom_key_location_numpad,
		false, false, false, true)
	assert keyboard.key() == 'B'
	assert keyboard.location() == dom_key_location_numpad
	assert keyboard.meta_key()

	coalesced := PointerEvent.create('pointermove', PointerEventInit{ pointer_id: 8 })
	click := PointerEvent.construct_impl('click', PointerEventInit{
		client_x:             -3.2
		pointer_id:           4
		pointer_type:         pointer_type_pen
		persistent_device_id: 22
		coalesced_events:     [coalesced]
	}) or { panic(err) }
	assert click.client_x() == -4
	assert click.pointer_id() == 4
	assert click.width() == 1
	assert click.height() == 1
	assert click.altitude_angle() == math.pi / 2.0
	assert click.pointer_type() == 'pen'
	assert click.persistent_device_id() == 22
	assert click.get_coalesced_events().len == 1
	move := PointerEvent.construct_impl('pointermove', PointerEventInit{ client_x: -3.2 }) or {
		panic(err)
	}
	assert move.client_x() == -3.2
	assert mouse_button_to_button_code(.middle) == 1
	assert button_code_to_mouse_button(4) == .forward
}

fn test_mouse_and_pointer_platform_creation_and_cloning() {
	mouse := MouseEvent.create_from_platform_event(unsafe { nil }, 'mousedown', CSSPixelPoint_{
		x_: 11.5
		y_: 12.5
	}, CSSPixelPoint_{
		x_: 21.5
		y_: 22.5
	}, CSSPixelPoint_{
		x_: 31.5
		y_: 32.5
	}, CSSPixelPoint_{
		x_: 41.5
		y_: 42.5
	}, CSSPixelPoint_{
		x_: 2.0
		y_: -3.0
	}, .secondary, 2, modifier_ctrl | modifier_alt, 3)
	assert mouse.is_trusted()
	assert mouse.bubbles() && mouse.cancelable() && mouse.composed()
	assert mouse.page_x() == 21.5
	assert mouse.offset_y() == 42.5
	assert mouse.movement_x() == 2
	assert mouse.button() == 2
	assert mouse.ctrl_key() && mouse.alt_key()
	cloned_mouse := mouse.clone()
	assert !cloned_mouse.is_trusted()
	assert cloned_mouse.page_x_ == 21.5
	assert cloned_mouse.detail() == 3

	pointer := PointerEvent.create_from_platform_event(unsafe { nil }, 'pointerdown', CSSPixelPoint_{}, CSSPixelPoint_{
		x_: 7.25
	}, CSSPixelPoint_{
		x_: 2.25
	}, CSSPixelPoint_{
		x_: 1.25
	}, none, .primary, 1, modifier_shift)
	assert pointer.is_trusted()
	assert pointer.page_x() == 7.25
	assert pointer.shift_key()
	cloned_pointer := pointer.clone()
	assert !cloned_pointer.is_trusted()
	assert cloned_pointer.page_x() == 7.25
}

fn test_composition_focus_input_text_and_wheel_events() {
	composition := CompositionEvent.construct_impl('compositionupdate', CompositionEventInit{
		data: 'λ'
	}) or { panic(err) }
	assert composition.data() == 'λ'
	assert composition.interface_ == .composition_event

	target := &EventTarget{}
	focus := FocusEvent.construct_impl('focusout', FocusEventInit{ related_target: target }) or {
		panic(err)
	}
	assert focus.related_target() or { panic('missing related target') } == target

	document := Document.create(url_about_blank())
	text := document.create_text_node('abc')
	range := StaticRange.new(text.as_node(), 0, text.as_node(), 1)
	input := InputEvent.create_from_platform_event('beforeinput', InputEventInit{
		data:       'x'
		input_type: input_type_insert_text
	}, [range])
	assert input.is_trusted()
	assert input.bubbles()
	assert input.cancelable()
	assert input.data() or { '' } == 'x'
	assert input.input_type() == 'insertText'
	mut returned_ranges := input.get_target_ranges()
	returned_ranges.clear()
	assert input.get_target_ranges().len == 1

	mut text_event := TextEvent.create('textInput')
	text_event.init_text_event('textInput', true, true, unsafe { nil }, 'hello')
	assert text_event.data() == 'hello'

	wheel := WheelEvent.construct_impl('wheel', WheelEventInit{
		client_x:   1.9
		delta_x:    2
		delta_y:    -3
		delta_z:    4
		delta_mode: dom_delta_line
	}) or { panic(err) }
	assert wheel.interface_ == .wheel_event
	assert wheel.client_x() == 1
	assert wheel.delta_x() == 2
	assert wheel.delta_y() == -3
	assert wheel.delta_z() == 4
	assert wheel.delta_mode() == dom_delta_line
}

fn test_key_code_and_keyboard_platform_translation() {
	assert key_code_from_string('Escape') == .escape
	assert key_code_from_string('A') == .a
	assert key_code_from_string('?') == .question_mark
	assert code_point_to_key_code(u32(`a`)) == .a
	assert code_point_to_key_code(u32(`1`)) == .key_1
	assert code_point_to_key_code(0x03bb) == .invalid
	assert determine_key_code(.exclamation_point, u32(`!`)) == u32(`1`)
	assert determine_key_code(.a, u32(`a`)) == u32(`A`)
	assert determine_char_code('keypress', u32(`x`)) == u32(`x`)
	assert determine_char_code('keydown', u32(`x`)) == 0
	assert get_event_named_key(.left_shift)? == 'Shift'
	assert get_event_named_key(.a) == none
	assert get_event_key_string(u32(`λ`))? == 'λ'
	assert get_event_key_string(10) == none
	assert is_glyph_modifier_key(.caps_lock)
	assert !is_glyph_modifier_key(.left_control)
	assert remove_non_glyph_modifier_keys(modifier_shift | modifier_ctrl | modifier_alt) ==
		modifier_shift | modifier_alt
	assert get_event_key(.left, 0, 0) == 'ArrowLeft'
	assert get_event_key(.a, u32(`A`), modifier_shift) == 'A'
	assert get_event_code(.exclamation_point, 0) == 'Digit1'
	assert get_event_code(.key_7, modifier_keypad) == 'Numpad7'
	assert get_event_location(.right_alt, 0) == dom_key_location_right
	assert get_event_location(.key_1, modifier_keypad) == dom_key_location_numpad

	keyboard := KeyboardEvent.create_from_platform_event('keypress', .a,
		modifier_ctrl | modifier_shift, u32(`A`), true)
	assert keyboard.is_trusted()
	assert keyboard.bubbles() && keyboard.cancelable() && keyboard.composed()
	assert keyboard.key() == 'A'
	assert keyboard.code() == 'KeyA'
	assert keyboard.key_code() == u32(`A`)
	assert keyboard.char_code() == u32(`A`)
	assert keyboard.ctrl_key() && keyboard.shift_key()
	assert keyboard.repeat()
}

fn test_exact_mouse_pointer_and_wheel_entry_points() {
	target := &EventTarget{}
	mut mouse := MouseEvent.create('click', MouseEventInit{
		ctrl_key:       true
		meta_key:       true
		related_target: target
	})
	assert mouse.platform_ctrl_key()
	assert mouse.related_target()? == target
	mouse.set_offset_x(4.5)
	mouse.set_offset_y(5.5)
	assert mouse.offset_x() == 4.5
	assert mouse.offset_y() == 5.5
	assert mouse.is_mouse_event()
	pointer := PointerEvent.create('pointermove', PointerEventInit{})
	assert pointer.is_pointer_event()

	wheel := WheelEvent.create_from_platform_event(unsafe { nil }, 'wheel', CSSPixelPoint_{
		x_: 1
		y_: 2
	}, CSSPixelPoint_{
		x_: 3
		y_: 4
	}, CSSPixelPoint_{
		x_: 5
		y_: 6
	}, CSSPixelPoint_{
		x_: 7
		y_: 8
	}, 9, -10, 1, 2, modifier_alt)
	assert wheel.is_trusted()
	assert wheel.page_x() == 3 && wheel.offset_y() == 8
	assert wheel.delta_x() == 9 && wheel.delta_y() == -10
	assert wheel.delta_mode() == dom_delta_pixel
	assert wheel.alt_key()
}
